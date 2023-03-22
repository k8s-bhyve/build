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

myrole="master"

[ -n "${1}" ] && myrole="${1}"

[ ! -d ${WORKDIR}/workspace ] && err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}no such directory: ${N2_COLOR}${WORKDIR}/workspace${N0_COLOR}"
cd ${WORKDIR}/workspace

[ ! -r /usr/local/bin/kubelet ] && err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}no such kubectl: ${N2_COLOR}/usr/local/bin/kubelet${N0_COLOR}"

# GET MY ID ( for static SERVERS list only )
xmyname=$( hostname -s )
xmyfqdn=$( hostname )
XMY_IP=$( hostname -I | awk '{printf $1}' )
counter=0
MYID=
OIFS="${IFS}"
IFS=','
for worker in ${WORKERS}; do
	oifs=${IFS}
	IFS=':'
	read -r ip node <<< "${worker}"
	counter=$(( counter+1 ))
	[ "${node}" = "${xmyfqdn}" ] && MYID="${counter}"
done
IFS="${OIFS}"

if [ -n "${MYID}" ]; then
	MYID=$(( MYID + 1 ))
	${ECHO} "${N0_COLOR}install_kubelet: my host ID is: ${N2_COLOR}${MYID}${N0_COLOR}"
else
	err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}unable to determine MYID from server list: ${N2_COLOR}${SERVERS}${N0_COLOR}"
fi

case "${CONTAINER_ENGINE}" in
	docker)
		mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy  /var/lib/kubernetes /var/run/kubernetes /opt/cni/bin
		;;
	*)
		touch /var/log/cni.log
		mkdir -p containerd /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy  /var/lib/kubernetes /var/run/kubernetes /opt/cni/bin
# 	"addIf": "eth0",

		LOCAL_POD_CIDR="172.17.${MYID}.0/24"

		cat > /export/master/${xmyfqdn}/route <<EOF
ip route add ${LOCAL_POD_CIDR} via ${XMY_IP}
EOF

		cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.4.0",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "log_level": "DEBUG",
    "mtu": 1500,
    "log_file_path": "/var/log/cni.log",
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${LOCAL_POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

		cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.4.0",
    "name": "lo",
    "type": "loopback"
}
EOF
		;;
esac

#if [ "${INSTALL_COREDNS}" = "true" ]; then
#	cluster_dns_args="--cluster-dns=${DNS_IP} --cluster_domain=${CLUSTER}"
#else
#	cluster_dns_args=
#fi

[ ! -d /var/lib/kubelet ] && mkdir /var/lib/kubelet

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "$CERTIFICATE_MOUNT_PATH/ca.pem"
authorization:
  mode: Webhook
cgroupDriver: systemd
clusterDomain: "${CLUSTER}"
clusterDNS:
  - "${DNS_IP}"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
registerNode: true
tlsCertFile: "$CERTIFICATE_MOUNT_PATH/server.pem"
tlsPrivateKeyFile: "$CERTIFICATE_MOUNT_PATH/server-key.pem"
EOF

case "${CONTAINER_ENGINE}" in
	docker)
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --pod-manifest-path=/etc/kubernetes/manifests \\
  --register-schedulable=true \\
  --cgroup-driver=systemd \\
  --docker=unix:///var/run/docker.sock \\
  --kubeconfig=/export/kubecertificate/certs/admin.kubeconfig \\
  --hostname-override=$(hostname -s) \\
  --non-masquerade-cidr=$CLUSTER_NON_MASQUEARADE_CIDR \\
  --eviction-hard=memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%,imagefs.available<10%,imagefs.inodesFree<5% \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
	;;
	*)
	# flannel CNI
	# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.13.0/Documentation/kube-flannel.yml
	# https://github.com/coreos/flannel

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --kubeconfig=/export/kubecertificate/certs/admin.kubeconfig \\
  --hostname-override=$(hostname -s) \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
	;;
esac

/bin/bash $INSTALL_PATH/install_haproxy.sh

systemctl daemon-reload || true
systemctl enable kubelet
systemctl restart kubelet || true
