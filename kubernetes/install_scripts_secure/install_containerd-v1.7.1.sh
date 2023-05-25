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

[ ! -d /etc/containerd ] && mkdir /etc/containerd

containerd config default | sudo tee /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

exit 0
