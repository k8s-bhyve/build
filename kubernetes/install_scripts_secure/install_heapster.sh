#!/bin/bash

[[ "TRACE" ]] && set -x

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts}

source $INSTALL_PATH/../config
pushd $WORKDIR
mkdir -p influxdb
pushd influxdb

cp $INSTALL_PATH/../kube_service/influxdb/* .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/influxdb/heapster-deployment.yaml

kubectl create -f $WORKDIR/influxdb/

popd
popd
