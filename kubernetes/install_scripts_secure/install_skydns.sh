#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

pushd $WORKDIR

cp $INSTALL_PATH/../kube_service/skydns/v1.14.1.yaml .
#cp $INSTALL_PATH/../kube_service/skydns/skydns-svc.yaml .

APISERVER_HOST="$(echo $APISERVER_HOST | sed 's/\//\\\//g')"
CERTIFICATE_MOUNT_PATH="$(echo $CERTIFICATE_MOUNT_PATH | sed 's/\//\\\//g')"

if [ $ENABLE_KUBE_SSL == 'true' ]
then
  KUBECONFIG="$(echo '/var/lib/kubelet/kubeconfig' | sed 's/\//\\\//g')"
  sed -i "s/\$KUBECONFIG/$KUBECONFIG/" $WORKDIR/v1.14.1.yaml
else
  sed -i "/\$KUBECONFIG/ s/^/#/" $WORKDIR/v1.14.1.yaml
fi



sed -i "s/\$APISERVER_HOST/$APISERVER_HOST/" $WORKDIR/v1.14.1.yaml
sed -i "s/\$CERTIFICATE_MOUNT_PATH/$CERTIFICATE_MOUNT_PATH/" $WORKDIR/v1.14.1.yaml
sed -i "s/\$SKYDNS_DOMAIN_NAME/$SKYDNS_DOMAIN_NAME/" $WORKDIR/v1.14.1.yaml
sed -i "s/\$DNS_IP/$DNS_IP/" $WORKDIR/v1.14.1.yaml


kubectl create -f $WORKDIR/v1.14.1.yaml
#kubectl create -f $WORKDIR/skydns-svc.yaml

check=`grep -E "ExecStart.*--cluster-dns.*--cluster-domain" /etc/systemd/system/kubelet.service`
if [ -z "$check" ]
then
 sed  -i "/ExecStart/s/$/ --cluster-dns=$DNS_IP --cluster-domain=$SKYDNS_DOMAIN_NAME/" /etc/systemd/system/kubelet.service
fi

systemctl daemon-reload
systemctl restart kubelet
#service docker restart
#$INSTALL_PATH/install_haproxy.sh

popd


