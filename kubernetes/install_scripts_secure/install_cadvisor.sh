#!/bin/bash
[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR

mkdir -p /etc/kubernetes/manifest/
cp $INSTALL_PATH/../kube_service/cadvisor/cadvisor.manifest /etc/kubernetes/manifest/

# wrong path to config cadvisor
#check=`grep -E "ExecStart.*--config" /etc/systemd/system/kubelet.service`
#if [ -z "$check" ]
#then
# sed  -i "/ExecStart/s/$/ --config=\/etc\/kubernetes\/manifest\//" /etc/systemd/system/kubelet.service
#fi


systemctl daemon-reload
systemctl restart kubelet
#service docker restart

popd
