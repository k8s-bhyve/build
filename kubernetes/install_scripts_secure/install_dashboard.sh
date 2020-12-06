#!/bin/bash


: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR

#DASHBOARD_VER="v1.6.3"
DASHBOARD_VER="v1.8.3"

# Counter for master nodes - set replicas
IFS=','
COUNTER=0
for worker in $SERVERS; do
	COUNTER=$(( COUNTER +1 ))
done
unset IFS

cp $INSTALL_PATH/../kube_service/dashboard/${DASHBOARD_VER}.yaml .

# есть проблемы с ресолвом/DNS, hostAliases не решает их:
# APISERVER_HOST=https://${MASTER_HOSTNAME} - в конфиге
#APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
APISERVER_HOST="https://10.0.0.100"
APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"

CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

if [ $ENABLE_KUBE_SSL == 'true' ]
then
  KUBECONFIG="$(echo '/var/lib/kubelet/kubeconfig' | sed 's/\//\\\//g')"
  sed -i "s/\$KUBECONFIG/$KUBECONFIG/" $WORKDIR/${DASHBOARD_VER}.yaml
else
  sed -i "/\$KUBECONFIG/ s/^/#/" $WORKDIR/${DASHBOARD_VER}.yaml
fi

sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/${DASHBOARD_VER}.yaml

sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/${DASHBOARD_VER}.yaml
sed -i "s/\$REPLICAS/$COUNTER/" $WORKDIR/${DASHBOARD_VER}.yaml

kubectl create -f $WORKDIR/${DASHBOARD_VER}.yaml

popd
