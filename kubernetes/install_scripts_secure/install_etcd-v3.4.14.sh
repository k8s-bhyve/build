#!/bin/bash
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

# !! FOR DEBUG ONLY, one boot !!
if [ "${ETCD_TMPFS}" = "1" ]; then
	mkdir -p /var/lib/etcd/member
	mount -t tmpfs tmpfs /var/lib/etcd/member
fi
###

proto='https'

get_etcd_cluster()
{
	#Install etcd nodes
	IFS=','
	counter=0
	cluster=""
	for worker in $ETCD_CLUSTERS; do
		oifs=$IFS
		IFS=':'
		read -r ip node <<< "$worker"
		if [ -z "$cluster" ]; then
			cluster="$node=${proto}://$ip:2380"
		else
			cluster="$cluster,$node=${proto}://$ip:2380"
		fi
		counter=$((counter+1))
		IFS=$oifs
	done
	unset IFS
	echo "$cluster"
	return 0
}

ETCD_INITIAL_CLUSTER=$(get_etcd_cluster)

cat <<EOF | sudo tee /opt/etcd/config/etcd.conf
ETCD_DATA_DIR=/var/lib/etcd
#ETCD_NAME=$(hostname -s)
ETCD_NAME=$(hostname)
ETCD_LISTEN_PEER_URLS=https://${HOSTIP}:2380
ETCD_LISTEN_CLIENT_URLS=https://${HOSTIP}:2379,https://${HOSTIP}:4001,http://127.0.0.1:2379,http://127.0.0.1:4001
ETCD_INITIAL_CLUSTER=${ETCD_INITIAL_CLUSTER}
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${HOSTIP}:2380
ETCD_ADVERTISE_CLIENT_URLS=https://${HOSTIP}:2379,https://${HOSTIP}:4001
ETCD_PEER_CERT_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname).pem
ETCD_PEER_KEY_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname)-key.pem
ETCD_PEER_TRUSTED_CA_FILE=$CERTIFICATE_MOUNT_PATH/ca.pem
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_CERT_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname).pem
ETCD_KEY_FILE=$CERTIFICATE_MOUNT_PATH/$(hostname)-key.pem
ETCD_TRUSTED_CA_FILE=$CERTIFICATE_MOUNT_PATH/ca.pem
ETCD_CLIENT_CERT_AUTH=true
ETCD_INITIAL_CLUSTER_STATE=new
##ETCD_HEARTBEAT_INTERVAL=6000
#ETCD_HEARTBEAT_INTERVAL=9000
##ETCD_ELECTION_TIMEOUT=30000
#ETCD_ELECTION_TIMEOUT=49999
GOMAXPROCS=$(nproc)
# tuning https://etcd.io/docs/v3.2.17/tuning/
ETCD_SNAPSHOT_COUNT=3000
EOF

#Set FLANNEL_NET to etcd
# Warning: FLANNELD still not support v3
# https://github.com/ubuntu/microk8s/issues/888
# needed  --enable-v2=true + ETCDCTL_API=2
cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos
After=network.target

[Service]
User=root
Type=notify
EnvironmentFile=-/opt/etcd/config/etcd.conf
ExecStart=/opt/etcd/bin/etcd --enable-v2=true --logger=zap
Restart=on-failure
RestartSec=10s
LimitNOFILE=40000

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || true
systemctl enable etcd
systemctl restart etcd || true

ln -sf /opt/etcd/bin/etcd /usr/local/bin/etcd
ln -sf /opt/etcd/bin/etcdctl /usr/local/bin/etcdctl

#Set FLANNEL_NET to etcd
# Warning: FLANNELD still not support v3
# https://github.com/ubuntu/microk8s/issues/888
# needed  --enable-v2=true + ETCDCTL_API=2

# for V3:
#env ETCDCTL_API=3 /opt/etcd/bin/etcdctl --cert $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --key $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem --cacert $CERTIFICATE_MOUNT_PATH/ca.pem put /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}' --endpoints=${ETCDSERVERS} --enable-v2=true
#echo "env ETCDCTL_API=3 /opt/etcd/bin/etcdctl --cert $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --key $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem --cacert $CERTIFICATE_MOUNT_PATH/ca.pem endpoint health --endpoints=${ETCDSERVERS}" > /root/etcd-health.sh
#env ETCDCTL_API=3 /opt/etcd/bin/etcdctl --cert $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --key $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem --cacert $CERTIFICATE_MOUNT_PATH/ca.pem endpoint health --endpoints=${ETCDSERVERS}

 # for V2:
env ETCDCTL_API=2 /opt/etcd/bin/etcdctl --cert-file $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --key-file $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem --ca-file $CERTIFICATE_MOUNT_PATH/ca.pem set /coreos.com/network/config '{"Network":"'${FLANNEL_NET}'","Backend": {"Type": "vxlan"}}'
echo "env ETCDCTL_API=2 /opt/etcd/bin/etcdctl --cert-file $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem --key-file $CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem --ca-file $CERTIFICATE_MOUNT_PATH/ca.pem cluster-health" > /root/etcd-health.sh
