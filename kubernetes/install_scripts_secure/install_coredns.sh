#!/bin/bash

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config

if [ $ENABLE_DEBUG == 'true' ]
then
[[ "TRACE" ]] && set -x
fi

[ -z "${UPSTREAMNAMESERVER}" ] && UPSTREAMNAMESERVER="1.1.1.1 8.8.8.8 8.8.4.4"

sed -i "s/CLUSTER_DNS_IP/${DNS_IP}/g" /kubernetes/kube_service/coredns/coredns.yaml
sed -i "s/CLUSTER_DOMAIN/${CLUSTER}/g" /kubernetes/kube_service/coredns/coredns.yaml
#sed -i "s/CLUSTER_DOMAIN/cluster.local/g" /kubernetes/kube_service/coredns/coredns.yaml
sed -i "s:REVERSE_CIDRS:10.254.0.0/16 172.17.0.0/16 172.18.0.0/16 100.127.64.0/18:g" /kubernetes/kube_service/coredns/coredns.yaml
sed -i "s:UPSTREAMNAMESERVER:1.1.1.1:g" /kubernetes/kube_service/coredns/coredns.yaml

kubectl create -f /kubernetes/kube_service/coredns/coredns.yaml
#kubectl create -f /kubernetes/kube_service/coredns/new.yaml
kubectl get pods -l k8s-app=kube-dns -n kube-system

exit 0
