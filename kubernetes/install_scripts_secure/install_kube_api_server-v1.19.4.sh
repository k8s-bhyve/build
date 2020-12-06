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

[ ! -r /opt/kubernetes/server/bin/kubectl ] && err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}no such kubectl: ${N2_COLOR}/opt/kubernetes/server/bin/kubectl${N0_COLOR}"

etcdproto='https'

get_etcd_endpoints()
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
			cluster="$etcdproto://$ip:4001"
		else
			cluster="$cluster,$etcdproto://$ip:4001"
		fi
		counter=$((counter+1))
		IFS=$oifs
	done
	unset IFS
	echo "${cluster}"
	return 0
}

ETCD_SERVERS="--etcd-servers=$(get_etcd_endpoints)"

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/opt/kubernetes/server/bin/kube-apiserver \\
  --advertise-address=${VIP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=$CERTIFICATE/certs/ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=$CERTIFICATE_MOUNT_PATH/ca.pem \\
  --etcd-certfile=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client.pem \\
  --etcd-keyfile=$CERTIFICATE_MOUNT_PATH/$(hostname)-etcd-client-key.pem \\
  $ETCD_SERVERS \\
  --event-ttl=1h \\
  --encryption-provider-config=${CERTIFICATE_MOUNT_PATH}/encryption-config.yaml \\
  --kubelet-certificate-authority=$CERTIFICATE/certs/ca.pem \\
  --kubelet-client-certificate=$CERTIFICATE/certs/server.pem \\
  --kubelet-client-key=$CERTIFICATE/certs/server-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all=true \\
  --service-account-key-file=$CERTIFICATE/certs/server-key.pem \\
  --service-cluster-ip-range=${CLUSTERIPRANGE} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=$CERTIFICATE/certs/server.pem \\
  --tls-private-key-file=$CERTIFICATE/certs/server-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#--portal_net=10.100.0.0/26

#--portal-net=$FLANNEL_NETWORK \
systemctl daemon-reload || true
systemctl enable kube-apiserver
systemctl restart kube-apiserver || true

exit 0
