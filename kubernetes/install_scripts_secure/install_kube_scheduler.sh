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

[ ! -d /etc/kubernetes ] && mkdir -p /etc/kubernetes

# config still alpha ?
# https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/427
# apiVersion: kubescheduler.config.k8s.io/v1beta3

cat <<EOF | sudo tee /etc/kubernetes/kube-scheduler.yaml
apiVersion: kubescheduler.config.k8s.io/v1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/export/kubecertificate/certs/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

#--config=/etc/kubernetes/kube-scheduler.yaml \

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
    --config=/etc/kubernetes/kube-scheduler.yaml \\
    --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload || true
systemctl enable kube-scheduler
systemctl restart kube-scheduler || true

exit 0
