#!/bin/bash

exit 0
pgm="${0##*/}"          # Program basename
progdir="${0%/*}"       # Program directory
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
[ -r ${INSTALL_PATH}/../config ] && . $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/ansiicolor.subr
. /kubernetes/time.subr

[ "${ENABLE_DEBUG}" = "true" ] && set -x

[ ! -d ${WORKDIR}/workspace ] && err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}no such directory: ${N2_COLOR}${WORKDIR}/workspace${N0_COLOR}"
cd ${WORKDIR}/workspace

mkdir -p /opt/flannel
#tar xzf $FLANNEL_VERSION.tar.gz -C /opt/flannel
tar xzf flannel-linux-amd64.tar.gz -C /opt/flannel
if [ $? -ne 0 ]; then
	echo "Flannel extract error"
	exit 1
fi
mkdir -p /etc/flanneld
proto='https'

get_etcd_endpoints()
{
	IFS=','
	counter=0
	cluster=""
	for worker in $ETCD_CLUSTERS; do
		oifs=$IFS
		IFS=':'
		read -r ip node <<< "$worker"
		if [ -z "$cluster" ]
		then
			cluster="$proto://$ip:4001"
		else
			cluster="$cluster,$proto://$ip:4001"
		fi
		counter=$((counter+1))
		IFS=$oifs
	done
	unset IFS
	echo "${cluster}"
	return 0
}

ETCD_END_POINTS="--etcd-endpoints=$(get_etcd_endpoints)"
FLANNELD_ETCD_ENDPOINTS=$(get_etcd_endpoints)

# WARNING: Flanneld still not support etcd V3
# https://github.com/ubuntu/microk8s/issues/888
# Use: export ETCDCTL_API=2  + --enable-v2=true for etcd
cat <<EOF | sudo tee /etc/flanneld/options.env
ETCDCTL_API=2
FLANNELD_ETCD_ENDPOINTS=${FLANNELD_ETCD_ENDPOINTS}
FLANNELD_ETCD_CAFILE=$CERTIFICATE_MOUNT_PATH/ca.pem
FLANNELD_ETCD_CERTFILE=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem
FLANNELD_ETCD_KEYFILE=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem
FLANNELD_IFACE=$HOSTINTERFACE
EOF


#EnvironmentFile=/etc/flanneld/options.env
cat <<EOF | sudo tee /etc/systemd/system/flanneld.service
[Unit]
Description=Flanneld
Documentation=https://github.com/coreos/flannel
After=network.target
[Service]
User=root
LimitNOFILE=40000
LimitNPROC=1048576
#ExecStartPre=/sbin/modprobe ip_tables
#ExecStartPre=/bin/mkdir -p /run/flanneld

ExecStart=/opt/flannel/flanneld \
`if [ $ENABLE_ETCD_SSL == 'true' ]
then

 echo "--etcd-cafile=$CERTIFICATE_MOUNT_PATH/ca.pem --etcd-certfile=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --etcd-keyfile=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem "

fi
` \
$ETCD_END_POINTS \
--iface=$HOSTINTERFACE \
--ip-masq
## Updating Docker options
#ExecStartPost=/opt/flannel/mk-docker-opts.sh -d /run/flanneld/docker_opts.env -i
ExecStartPost=/bin/bash /opt/flannel/update_docker.sh
Restart=on-failure
Type=notify
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

cat <<EOF | sudo tee /opt/flannel/update_docker.sh
source /run/flannel/subnet.env
#source /run/flanneld/docker_opts.env
#sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock \${DOCKER_OPT_BIP} \${DOCKER_OPT_MTU} \${DOCKER_OPT_IPMASQ}|g" /lib/systemd/system/docker.service
sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}|g" /lib/systemd/system/docker.service
rc=0
ip link show docker0 >/dev/null 2>&1 || rc="$?"
if [[ "$rc" -eq "0" ]]; then
ip link set dev docker0 down
ip link delete docker0
fi
systemctl daemon-reload
EOF

#sed -i "s|ExecStart=.*|ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:4243 -H unix:\/\/\/var\/run\/docker.sock --bip=\${FLANNEL_SUBNET} --mtu=\${FLANNEL_MTU}|g" /lib/systemd/system/docker.service
#rc=0
#ip link show docker0 >/dev/null 2>&1 || rc="$?"
#if [[ "$rc" -eq "0" ]]; then
#ip link set dev docker0 down
#ip link delete docker0
#fi

systemctl daemon-reload && systemctl enable flanneld && systemctl start flanneld

$INSTALL_PATH/install_haproxy.sh

exit 0

