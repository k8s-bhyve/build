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

#    --master=127.0.0.1:8080 \\

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
User=root
ExecStart=/usr/local/bin/kube-controller-manager \\
    --bind-address=0.0.0.0 \\
#    --allocate-node-cidrs=true \\
    --attach-detach-reconcile-sync-period=1m0s \\
    --cluster-cidr=${FLANNEL_NET} \\
    --cluster-name=${CLUSTER} \\
    --leader-elect=true \\
    --use-service-account-credentials=true \\
    --cluster-signing-cert-file=$CERTIFICATE_MOUNT_PATH/ca.pem \\
    --cluster-signing-key-file=$CERTIFICATE_MOUNT_PATH/ca-key.pem \\
    --service-cluster-ip-range=$CLUSTERIPRANGE \\
    --configure-cloud-routes=false \\
    --root-ca-file=$CERTIFICATE_MOUNT_PATH/ca.pem \\
    --service-account-private-key-file=$CERTIFICATE_MOUNT_PATH/server-key.pem \\
    --kubeconfig=/export/kubecertificate/certs/kube-controller-manager.kubeconfig \\
    --pod-eviction-timeout=30s \\
    --node-monitor-grace-period=20s \\
    --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl start kube-controller-manager
#systemctl status kube-controller-manager
