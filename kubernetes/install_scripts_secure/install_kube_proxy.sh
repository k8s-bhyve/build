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


cat <<EOF | tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/export/kubecertificate/certs/kube-proxy.kubeconfig"
mode: "iptables"
clusterCIDR: "${FLANNEL_NET}"
EOF

cat <<EOF | tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
ExecStart=/opt/kubernetes/server/bin/kube-proxy \\
  --hostname-override=$(hostname -s) \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

#[Service]
#--hostname-override=$(hostname -s) \
#--master=$APISERVER_HOST \
#--cluster-cidr=$FLANNEL_NET \
#--kubeconfig=/export/kubecertificate/certs/kube-proxy.kubeconfig \
#--logtostderr=true
#Restart=on-failure
#[Install]
#WantedBy=multi-user.target
#EOF

systemctl daemon-reload || true
systemctl enable kube-proxy
systemctl restart kube-proxy || true

exit 0
