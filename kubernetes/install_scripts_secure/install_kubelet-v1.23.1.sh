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

case "${CONTAINER_ENGINE}" in
	docker)
		mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy  /var/lib/kubernetes /var/run/kubernetes /opt/cni/bin
		;;
	*)
		mkdir -p containerd /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy  /var/lib/kubernetes /var/run/kubernetes /opt/cni/bin
		cat <<EOF | tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF

		cat <<EOF | tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
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
clusterDomain: "${CLUSTER}"
clusterDNS:
  - "${DNS_IP}"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
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
  --container-runtime=docker \\
  --docker=unix:///var/run/docker.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/export/kubecertificate/certs/admin.kubeconfig \\
  --register-node=true \\
  --hostname-override=$(hostname -s) \\
  --image-pull-progress-deadline=2m \\
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
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/export/kubecertificate/certs/admin.kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --hostname-override=$(hostname -s) \\
  --image-pull-progress-deadline=2m \\
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
