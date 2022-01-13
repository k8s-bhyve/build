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

/home/ubuntu/kubernetes/install_scripts_secure/install_haproxy.sh

# waiting for kube-api
maxwait=300
api_stable=0

if [ ! -r /export/kubecertificate/certs/admin.kubeconfig ]; then
	echo "No such /export/kubecertificate/certs/admin.kubeconfig"
	exit 1
fi

if [ ! -d /root/.kube ]; then
	mkdir /root/.kube
	chmod 0700 /root/.kube
	ln -sf /export/kubecertificate/certs/admin.kubeconfig /root/.kube/config
fi


for i in $( seq 1 ${maxwait} ); do
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: waiting for kubernetes-api [${i}/${maxwait}]...${N0_COLOR}"
	timeout 5 kubectl get nodes > /dev/null 2>&1
	ret=$?
	case "${ret}" in
		0)
			api_stable=$(( api_stable + 1 ))
			;;
		*)
			api_stable=0
			;;
	esac

	# when three times in succession - we consider that it is stable
	[ ${api_stable} -eq 1 ] && break
	sleep 1
done

cat <<EOF | kubectl apply --kubeconfig /export/kubecertificate/certs/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

cat <<EOF | kubectl apply --kubeconfig /export/kubecertificate/certs/admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

kubectl create clusterrolebinding apiserver-kubelet-api-admin --clusterrole system:kubelet-api-admin --user kube-apiserver
