#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
source $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/time.subr
. /kubernetes/ansiicolor.subr

if [ $ENABLE_DEBUG == 'true' ]
then
 [[ "TRACE" ]] && set -x
fi

case "${CONTAINER_ENGINE}" in
	docker)
		systemctl docker start || true
		;;
esac

case "${INIT_ROLE}" in
	worker)
		timeout 30 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" ${VIP}:/export/kubecertificate/ /export/kubecertificate/
		timeout 30 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" ${VIP}:/export/kubeconfig /export/kubeconfig

		# дожидаемся /export/kubecertificate/certs/admin.kubeconfig
		max=0
		while [ ${max} -lt 300 ]; do
			wait_msg=
			[ ! -r /export/kubecertificate/certs/admin.kubeconfig ] && wait_msg="no such /export/kubecertificate/certs/admin.kubeconfig, waiting ${max}/300..."
			if [ -z "${wait_msg}" ]; then
				max=1000
			else
				max=$(( max + 1 ))
				echo "${wait_msg}"
				sleep 1
			fi
		done

		if [ ! -r /export/kubecertificate/certs/admin.kubeconfig ]; then
			echo "no such /export/kubecertificate/certs/admin.kubeconfig"
			exit 1
		fi

		kubelet_role="worker"
		[ ! -d /var/lib/kubelet ] && mkdir -p /var/lib/kubelet
		cp -a /export/kubecertificate/certs/admin.kubeconfig /export/kubecertificate/certs/admin.kubeconfig
		;;
	*)
		kubelet_role="master"
		;;
esac

case "${CONTAINER_ENGINE}" in
	docker)
		echo
		;;
	*)
		st_time=$( ${DATE_CMD} +%s )
		if [ -r $INSTALL_PATH/install_containerd-v${CONTAINERD_VER}.sh ]; then
			echo "containerd ${CONTAINERD_VER}"
			/bin/bash $INSTALL_PATH/install_containerd-v${CONTAINERD_VER}.sh
			ret=$?
		else
			echo "containerd ${CONTAINERD_VER}"
			/bin/bash $INSTALL_PATH/install_containerd.sh
			ret=$?
		fi
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install containerd done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
		;;
esac
st_time=$( ${DATE_CMD} +%s )
if [ -r $INSTALL_PATH/install_kubelet-${K8S_VER}.sh ]; then
	echo "kubelet for ${K8S_VER}"
	/bin/bash $INSTALL_PATH/install_kubelet-${K8S_VER}.sh ${kubelet_role}
	ret=$?
else
	echo "kubelet for ${K8S_VER}"
	/bin/bash $INSTALL_PATH/install_kubelet.sh ${kubelet_role}
	ret=$?
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: install kubelet done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

systemctl stop kubelet || true
systemctl start kubelet || true

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_kube_proxy.sh
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: install kube_proxy done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_flannel.sh
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: install_flannel done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

MY_SHORT_HOSTNAME=$( hostname -s )

case "${INIT_ROLE}" in
	worker)
		systemctl stop kubelet || true
		sleep 1
		systemctl start kubelet || true
		[ ! -d /export/rpc ] && mkdir -p /export/rpc
		cat > /export/rpc/task.$$ << EOF
#!/bin/sh
kubectl get nodes ${MY_SHORT_HOSTNAME}
ret=\$?
[ \${ret} -ne 0 ] && exit \${ret}
kubectl label node ${MY_SHORT_HOSTNAME} node-role.kubernetes.io/${kubelet_role}=
ret=\$?
exit \${ret}
EOF
		;;
esac
