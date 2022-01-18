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

[ ! -d ${CERTIFICATE}/certs ] && err 1 "no such  $CERTIFICATE/certs"
cd $CERTIFICATE/certs

# PARALLEL ?
#Install worker kubelet
IFS=','
for worker in $WORKERS; do
	oifs=$IFS
	IFS=":"
	read -r ip instance <<< "$worker"
	echo "The node $instance"
	IFS=$oifs

	[ -r ${instance}.kubeconfig ] && continue

	kubectl config set-cluster $CLUSTER \
	--certificate-authority=ca.pem \
	--embed-certs=true \
	--server=$API_SERVER \
	--kubeconfig=${instance}.kubeconfig

	kubectl config set-credentials system:node:${instance} \
	--client-certificate=${instance}.pem \
	--client-key=${instance}-key.pem \
	--embed-certs=true \
	--kubeconfig=${instance}.kubeconfig

	kubectl config set-context default \
	--cluster=${CLUSTER} \
	--user=system:node:${instance} \
	--kubeconfig=${instance}.kubeconfig

	kubectl config use-context default --kubeconfig=${instance}.kubeconfig

	IFS=$oifs
done

# PARALLEL ?
if [ ! -r kube-proxy.kubeconfig ]; then

	kubectl config set-cluster ${CLUSTER} \
	--certificate-authority=ca.pem \
	--embed-certs=true \
	--server=$API_SERVER \
	--kubeconfig=kube-proxy.kubeconfig

	kubectl config set-credentials system:kube-proxy \
	--client-certificate=kube-proxy.pem \
	--client-key=kube-proxy-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-proxy.kubeconfig

	kubectl config set-context default \
	--cluster=${CLUSTER} \
	--user=system:kube-proxy \
	--kubeconfig=kube-proxy.kubeconfig

	kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
fi

# PARALLEL ?
if [ ! -r kube-controller-manager.kubeconfig ]; then

	kubectl config set-cluster ${CLUSTER} \
	--certificate-authority=ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=kube-controller-manager.kubeconfig

	kubectl config set-credentials system:kube-controller-manager \
	--client-certificate=kube-controller-manager.pem \
	--client-key=kube-controller-manager-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-controller-manager.kubeconfig

	kubectl config set-context default \
	--cluster=${CLUSTER} \
	--user=system:kube-controller-manager \
	--kubeconfig=kube-controller-manager.kubeconfig

	kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
fi

# PARALLEL ?
if [ ! -r kube-scheduler.kubeconfig ]; then
	kubectl config set-cluster ${CLUSTER} \
	--certificate-authority=ca.pem \
	--embed-certs=true \
	--server=https://127.0.0.1:6443 \
	--kubeconfig=kube-scheduler.kubeconfig

	kubectl config set-credentials system:kube-scheduler \
	--client-certificate=kube-scheduler.pem \
	--client-key=kube-scheduler-key.pem \
	--embed-certs=true \
	--kubeconfig=kube-scheduler.kubeconfig

	kubectl config set-context default \
	--cluster=${CLUSTER} \
	--user=system:kube-scheduler \
	--kubeconfig=kube-scheduler.kubeconfig

	kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
fi

# PARALLEL ?
if [ ! -r admin.kubeconfig ]; then
	kubectl config set-cluster ${CLUSTER} \
	--certificate-authority=ca.pem \
	--embed-certs=true \
	--server=${API_SERVER} \
	--kubeconfig=admin.kubeconfig

	kubectl config set-credentials admin \
	--client-certificate=admin.pem \
	--client-key=admin-key.pem \
	--embed-certs=true \
	--kubeconfig=admin.kubeconfig

	kubectl config set-context default \
	--cluster=${CLUSTER} \
	--user=admin \
	--kubeconfig=admin.kubeconfig

	kubectl config use-context default --kubeconfig=admin.kubeconfig
fi

exit 0
