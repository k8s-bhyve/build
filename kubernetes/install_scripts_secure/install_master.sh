#!/bin/bash
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}

source $INSTALL_PATH/../config
. /kubernetes/tools.subr
. /kubernetes/time.subr
. /kubernetes/ansiicolor.subr

MY_SHORT_HOSTNAME=$( hostname -s )

if [ $ENABLE_DEBUG == 'true' ]
then
	[[ "TRACE" ]] && set -x
fi

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_binaries.sh
if [  $? -ne 0 ]
then
	exit 1
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_binaries done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

#st_time=$( ${DATE_CMD} +%s )
#/bin/bash $INSTALL_PATH/install_kubeconfig.sh
#if [  $? -ne 0 ]
#then
#	exit 1
#fi
#end_time=$( ${DATE_CMD} +%s )
#diff_time=$(( end_time - st_time ))
#diff_time=$( displaytime ${diff_time} )
#${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_kubeconfig done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

#file -s /var/lib/kubelet/kubeconfig
# copy kubeconfig for nodes
#cp -a /var/lib/kubelet/kubeconfig /export/kubeconfig

if [ "${INIT_ROLE}" = "supermaster" ]; then
	date > /export/etcd.init
fi

st_time=$( ${DATE_CMD} +%s )
if [ -r $INSTALL_PATH/install_etcd-${ETCD_VER}.sh ]; then
	/bin/bash $INSTALL_PATH/install_etcd-${ETCD_VER}.sh
	ret=$?
else
	/bin/bash $INSTALL_PATH/install_etcd.sh
	ret=$?
fi
[ ${ret} -ne 0 ] && exit ${ret}
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_etcd done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

st_time=$( ${DATE_CMD} +%s )
if $INSTALL_PATH/install_kube_api_server-${K8S_VER}.sh; then
	/bin/bash $INSTALL_PATH/install_kube_api_server-${K8S_VER}.sh
	ret=$?
else
	/bin/bash $INSTALL_PATH/install_kube_api_server.sh
	ret=$?
fi
if [ ${ret} -ne 0 ]
then
	echo "kube_api_server err"
	exit 1
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_kube_api_server done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_kube_controller_manager.sh
if [  $? -ne 0 ]
then
	echo "kube_controller_manager err"
	exit 1
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_kube_controller_manager done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_kube_scheduler.sh
if [  $? -ne 0 ]
then
	exit 1
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_kube_scheduler done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

/home/ubuntu/kubernetes/install_scripts_secure/kubelet-auth.sh || true

#if [[ $INSTALL_KUBELET_ON_MASTER == 'true' ]]
#then
	st_time=$( ${DATE_CMD} +%s )
	/bin/bash $INSTALL_PATH/install_nodes.sh
	if [  $? -ne 0 ]; then
		exit 1
	fi

	end_time=$( ${DATE_CMD} +%s )
	diff_time=$(( end_time - st_time ))
	diff_time=$( displaytime ${diff_time} )
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_nodes done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

#fi

ln -sf /opt/kubernetes/server/bin/kubectl /usr/bin/kubectl

# install on each master node

st_time=$( ${DATE_CMD} +%s )
/bin/bash $INSTALL_PATH/install_haproxy.sh
if [  $? -ne 0 ]; then
	exit 1
fi
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: install_haproxy done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

# waiting for kube-api
maxwait=300
api_stable=0

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
	[ ${api_stable} -eq 3 ] && break
	sleep 1
done

timeout 5 kubectl get nodes > /dev/null 2>&1
ret=$?
if [ ${ret} -ne 0 ]; then
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: error: kubernetes-api not ready${N0_COLOR}"
	exit 1
fi
${ECHO} "${N1_COLOR}${MY_APP}: ${N2_COLOR}kubernetes-api ready${N0_COLOR}"

if [ "${INIT_ROLE}" = "supermaster" ]; then
	st_time=$( ${DATE_CMD} +%s )
	kubectl create -f $INSTALL_PATH/admin.yaml
	if [ $? -ne 0 ]; then
		echo "kubectl create -f $INSTALL_PATH/admin.yaml"
	fi
	end_time=$( ${DATE_CMD} +%s )
	diff_time=$(( end_time - st_time ))
	diff_time=$( displaytime ${diff_time} )
	${ECHO} "${N1_COLOR}${MY_APP}: kubectl admin.yaml done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

	if [[ $INSTALL_DASHBOARD == 'true' ]]
	then
		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_dashboard.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_dashboard done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
	fi


	if [[ $INSTALL_SKYDNS == 'true' ]]
	then
		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_skydns.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_skydns done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
	fi

	if [[ $INSTALL_COREDNS == 'true' ]]
	then
		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_coredns.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_coredns done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
	fi

	if [[ $INSTALL_INGRESS == 'true' ]]
	then
		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_ingress.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_ingress done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
	fi

	if [[ $INSTALL_HEAPSTER == 'true' ]]
	then
		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_cadvisor.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_cadvisor done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

		st_time=$( ${DATE_CMD} +%s )
		/bin/bash $INSTALL_PATH/install_heapster.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}: install_heapster done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
	fi
fi

# waiting for master kube before can go next
if [ "${INIT_ROLE}" = "master" ]; then
	maxwait=120
	supermaster_hostname=
	for i in $( seq 1 ${maxwait} ); do
		if [ -z "${supermaster_hostname}" ]; then
			echo "${MY_SHORT_HOSTNAME}: waiting for kubectl get nodes master: [${i}/${maxwait}]..."
			[ -r /export/master/supermaster ] && supermaster_hostname=$( cat /export/master/supermaster | awk '{printf $1}' )
			if [ -n "${supermaster_hostname}" ]; then
				kubectl get nodes ${supermaster_hostname} > /dev/null 2>&1
				ret=$?
				[ ${ret} -eq 0 ] && break
			fi
		fi
		sleep 1
	done
	# re-register if necessary
	systemctl stop kube-controller-manager || true
	systemctl start kube-controller-manager
	systemctl stop kubelet || true
	systemctl start kubelet
fi

# test
if [ "${INSTALL_KUBELET_ON_MASTER}" = "true" ]; then
	maxwait=120
	for i in $( seq 1 ${maxwait} ); do
		echo "${MY_SHORT_HOSTNAME}: waiting for kubectl get nodes ${MY_SHORT_HOSTNAME}: [${i}/${maxwait}]..."
		kubectl get nodes ${MY_SHORT_HOSTNAME} > /dev/null 2>&1
		ret=$?
		[ ${ret} -eq 0 ] && break
		sleep 1
	done

	kubectl get nodes ${MY_SHORT_HOSTNAME} > /dev/null 2>&1
	ret=$?
	if [ ${ret} -ne 0 ]; then
		echo "kubectl get nodes ${MY_SHORT_HOSTNAME} failed.."
		exit ${ret}
	fi
fi

[ ! -d /export/rpc ] && mkdir -p /export/rpc
cat > /export/rpc/task.$$ << EOF
#!/bin/sh
kubectl get nodes ${MY_SHORT_HOSTNAME}
ret=\$?
[ \${ret} -ne 0 ] && exit \${ret}
kubectl label node ${MY_SHORT_HOSTNAME} node-role.kubernetes.io/master=
ret=\$?
exit \${ret}
EOF

if [ "${INIT_ROLE}" = "supermaster" ]; then
	systemctl restart keepalived || true
fi

exit $?
