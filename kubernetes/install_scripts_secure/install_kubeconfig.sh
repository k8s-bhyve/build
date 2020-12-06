#!/bin/bash

exit 0

: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
kubectl config set-cluster $CLUSTER --certificate-authority=$CA_CERTIFICATE \
  --embed-certs=true --server=$API_SERVER
kubectl config set-credentials admin --client-certificate=$CLIENT_CERTIFICATE \
  --client-key=$CLIENT_KEY --embed-certs=true --token=$TOKEN
kubectl config set-context $CLUSTER --cluster=$CLUSTER --user=admin
kubectl config use-context $CLUSTER

echo "" > $CERTIFICATE_MOUNT_PATH/known_tokens.csv

for user in kubelet kube-proxy kube-controller-manager kube-scheduler ${MASTER_HOSTNAME}; do
	TOKEN=$(dd if=/dev/urandom bs=128 count=1 2>/dev/null | base64 | tr -d "=+/" | dd bs=32 count=1 2>/dev/null)
	kubectl config set-cluster $CLUSTER --certificate-authority=$CA_CERTIFICATE --embed-certs=true --server=$API_SERVER --kubeconfig=/var/lib/${user}/kubeconfig
	kubectl config set-credentials ${user} --client-certificate=$CERTIFICATE_MOUNT_PATH/${user}.crt --client-key=$CERTIFICATE_MOUNT_PATH/${user}.key --embed-certs=true --token=$TOKEN --kubeconfig=/var/lib/${user}/kubeconfig
	kubectl config set-context $CLUSTER --cluster=$CLUSTER --user=${user} --kubeconfig=/var/lib/${user}/kubeconfig
	echo "$TOKEN,$user,$user" >> $CERTIFICATE_MOUNT_PATH/known_tokens.csv
	kubectl config use-context ${CLUSTER} --kubeconfig=/var/lib/${user}/kubeconfig
done
