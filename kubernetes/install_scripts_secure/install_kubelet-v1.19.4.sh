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

[ ! -r /opt/kubernetes/server/bin/kubelet ] && err 1 "${W1_COLOR}${pgm} error: ${N1_COLOR}no such kubectl: ${N2_COLOR}/opt/kubernetes/server/bin/kubelet${N0_COLOR}"

mkdir -p containerd \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes \
  /opt/cni/bin

tar -xvf crictl-linux-amd64.tar.gz
#  tar -xvf containerd-1.3.6-linux-amd64.tar.gz -C containerd
tar -xvf cni-plugins-linux-amd64.tgz -C /opt/cni/bin/
mv runc.amd64 runc
chmod +x crictl runc
mv crictl runc /usr/local/bin/

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

#if [ "${INSTALL_COREDNS}" = "true" ]; then
#	cluster_dns_args="--cluster-dns=${DNS_IP} --cluster_domain=${CLUSTER}"
#else
#	cluster_dns_args=
#fi

DNS_IP="172.17.0.2"

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

#   --non-masquerade-cidr=$CLUSTER_NON_MASQUEARADE_CIDR \\


cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=/opt/kubernetes/server/bin/kubelet \\
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

## ?
#--non-masquerade-cidr=$CLUSTER_NON_MASQUEARADE_CIDR \
#--cgroup-driver=systemd \
#--cgroup-root=/ \
#--enable-debugging-handlers=true \
#--eviction-hard=memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%,imagefs.available<10%,imagefs.inodesFree<5% \
#--tls-cert-file=$CERTIFICATE_MOUNT_PATH/server.pem \
#--tls-private-key-file=$CERTIFICATE_MOUNT_PATH/server-key.pem \
#--node-labels=kubelet.kubernetes.io/role=${myrole},node.kubernetes.io/role=${myrole} \
#--hostname-override=$(hostname -s) \
#--logtostderr=true --fail-swap-on=false \
#--image-pull-progress-deadline=2m \
#--node-status-update-frequency=10s \
#--register-node=true \
#--kubeconfig=/export/kubecertificate/certs/admin.kubeconfig \
#--pod-manifest-path=/etc/kubernetes/manifests \
#--register-schedulable=true \
#--container-runtime=docker \
#--docker=unix:///var/run/docker.sock
#Restart=on-failure
#KillMode=process
#[Install]
#WantedBy=multi-user.target
#EOF

#ExecStart=/opt/kubernetes/server/bin/kubelet \
#--hostname-override=$(hostname -s) \
#--logtostderr=true \
#--tls-cert-file=$CERTIFICATE_MOUNT_PATH/server.pem \
#--tls-private-key-file=$CERTIFICATE_MOUNT_PATH/server-key.pem \
#--kubeconfig=/var/lib/kubelet/kubeconfig \
#--fail-swap-on=false
/bin/bash $INSTALL_PATH/install_haproxy.sh

systemctl daemon-reload || true
systemctl enable kubelet
systemctl restart kubelet || true
