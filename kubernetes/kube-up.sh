. /kubernetes/config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/time.subr
. /kubernetes/ansiicolor.subr
cat > /root/.bashrc <<EOF
alias kcd='kubectl config set-context --current --namespace='
EOF
cat > /home/ubuntu/.bashrc <<EOF
alias kcd='kubectl config set-context --current --namespace='
EOF
MY_HOSTNAME=$( hostname )
MY_IP=$( hostname -I | awk '{printf $1}' )
MY_SHORT_HOSTNAME=$( hostname -s )

case "${INIT_ROLE}" in
	master|worker)
		date
		timeout 30 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" --exclude tmp --exclude kubernetes ${VIP}:/export/ /export/
		;;
esac

${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: reconfiguring k8s cluster...${N0_COLOR}"

# waiting for masters
maxwait=200
max=0
st_time=$( ${DATE_CMD} +%s )
while [ ${max} -lt ${maxwait} ]; do
	wait_msg=
	[ ! -r /etc/facter/facts.d/k8s_master_ips ] && wait_msg="${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: no k8s_master_ips facts, waiting ${N2_COLOR}${max}/${maxwait}${N0_COLOR}"
	[ -r /etc/facter/facts.d/k8s_master_ips ] && eval $( /etc/facter/facts.d/k8s_master_ips )

	[ "${INIT_MASTERS_NUM}" != "${k8s_master_num}" ] && wait_msg="${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: waiting for ${INIT_MASTERS_NUM} master node, current: ${k8s_master_num} ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
	if [ -z "${wait_msg}" ]; then
		max=$(( maxwait + 100 ))
	else
		max=$(( max + 1 ))
		${ECHO} "   ${wait_msg}"
		sleep 1
	fi
done
[ -r /etc/facter/facts.d/k8s_master_ips ] && eval $( /etc/facter/facts.d/k8s_master_ips )
[ "${INIT_MASTERS_NUM}" != "${k8s_master_num}" ] && err 1 "${W1_COLOR}${MY_APP} ${MY_SHORT_HOSTNAME} error: ${N1_COLOR} waiting for ${INIT_MASTERS_NUM} master node failed, current: ${k8s_master_num} ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: waiting master members done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

wait_for_workers=1

${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: init nodes ips: ${INIT_NODES_IPS}, init_nodes_num: ${INIT_NODES_NUM}${N0_COLOR}"
if [ -z "${INIT_NODES_IPS}" -o "${INIT_NODES_NUM}" = "0" ]; then
	wait_for_workers=0
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: no workers, im alone, skip waiting for workers${N0_COLOR}"
elif [ "${INIT_NODES_NUM}" = "1" ]; then
	_ip_test=$( echo "${INIT_NODES_IPS}" | awk '{printf $1}' )
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: init nodes 1, check for main IPS: [${_ip_test}]!=[${MY_IP}]${N0_COLOR}"
	if [ "${_ip_test}" = "${MY_IP}" ]; then
		wait_for_workers=0
		${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: one workers = me, im alone, skip waiting for workers${N0_COLOR}"
	fi
fi

if [ ${wait_for_workers} -eq 1 ]; then
	# waiting for workers
	maxwait=200
	max=0
	st_time=$( ${DATE_CMD} +%s )
	while [ ${max} -lt ${maxwait} ]; do
		wait_msg=
		[ ! -r /etc/facter/facts.d/k8s_worker_ips ] && wait_msg="${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: no k8s_worker_ips facts, waiting ${N2_COLOR}${max}/${maxwait}..."
		[ -r /etc/facter/facts.d/k8s_worker_ips ] && eval $( /etc/facter/facts.d/k8s_worker_ips )

		[ "${INIT_NODES_NUM}" != "${k8s_worker_num}" ] && wait_msg="${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: waiting for ${INIT_NODES_NUM} worker node, current: ${k8s_worker_num} ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
		if [ -z "${wait_msg}" ]; then
			max=$(( maxwait + 100 ))
		else
			max=$(( max + 1 ))
			${ECHO} "   ${wait_msg}"
			sleep 1
		fi
	done
fi

[ -r /etc/facter/facts.d/k8s_worker_ips ] && eval $( /etc/facter/facts.d/k8s_worker_ips )
[ ${wait_for_workers} -eq 1 -a "${INIT_NODES_NUM}" != "${k8s_worker_num}" ] && err 1 "${W1_COLOR}${MY_APP} ${MY_SHORT_HOSTNAME} error: ${N1_COLOR}waiting for ${INIT_NODES_NUM} worker node failed, current: ${k8s_worker_num} ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"

end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: waiting members done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

SERVERS=
for name in ${k8s_master_list}; do
	ip=$( cat /export/master/${name}/ip | awk '{printf $1}' )
	if [ -z "${SERVERS}" ]; then
		SERVERS="${ip}:${name}"
	else
		SERVERS="${SERVERS},${ip}:${name}"
	fi
done
${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: bootstrap config: SERVERS=\"${SERVERS}\"${N0_COLOR}"
echo "SERVERS=\"${SERVERS}\"" >> /home/ubuntu/bootstrap.config
WORKERS=
for name in ${k8s_master_list}; do
	ip=$( cat /export/master/${name}/ip | awk '{printf $1}' )
	if [ -z "${WORKERS}" ]; then
		WORKERS="${ip}:${name}"
	else
		WORKERS="${WORKERS},${ip}:${name}"
	fi
done

for name in ${k8s_worker_list}; do
	ip=$( cat /export/worker/${name}/ip | awk '{printf $1}' )
	if [ -z "${WORKERS}" ]; then
		WORKERS="${ip}:${name}"
	else
		WORKERS="${WORKERS},${ip}:${name}"
	fi
done
${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: bootstrap config: WORKERS=\"${WORKERS}\"${N0_COLOR}"
echo "WORKERS=\"${WORKERS}\"" >> /home/ubuntu/bootstrap.config
NODES=
for name in ${k8s_master_list}; do
	ip=$( cat /export/master/${name}/ip | awk '{printf $1}' )
	if [ -z "${NODES}" ]; then
		NODES="${ip}:${name}"
	else
		NODES="${NODES},${ip}:${name}"
	fi
done
k8s_worker_ips=
for name in ${k8s_worker_list}; do
	ip=$( cat /export/worker/${name}/ip | awk '{printf $1}' )
	if [ -z "${k8s_worker_ips}" ]; then
		k8s_worker_ips="${ip}"
	else
		k8s_worker_ips="${k8s_worker_ips} ${ip}"
	fi
	if [ -z "${NODES}" ]; then
		NODES="${ip}:${name}"
	else
		NODES="${NODES},${ip}:${name}"
	fi
done
${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: bootstrap config: NODES=\"${NODES}\"${N0_COLOR}"
${ECHO} "NODES=\"${NODES}\"" >> /home/ubuntu/bootstrap.config
ETCD_CLUSTERS="${SERVERS}"
${ECHO} "ETCD_CLUSTERS=\"${ETCD_CLUSTERS}\"" >> /home/ubuntu/bootstrap.config
ETCD_CLUSTERS_CERTS="${SERVERS}"
${ECHO} "ETCD_CLUSTERS_CERTS=\"${ETCD_CLUSTERS_CERTS}\"" >> /home/ubuntu/bootstrap.config
maxwait=200

. /home/ubuntu/bootstrap.config
case "${INIT_ROLE}" in
	supermaster)
		real_role="master"
		systemctl stop lsyncd.service || true
		st_time=$( ${DATE_CMD} +%s )
		/export/kubernetes/certificates/install_ca.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: install_ca done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

		st_time=$( ${DATE_CMD} +%s )
		/export/kubernetes/certificates/install_certificates.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: install_certificates done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

		st_time=$( ${DATE_CMD} +%s )
		/export/kubernetes/certificates/install_kubeconfig.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: install_kubeconfig done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

		st_time=$( ${DATE_CMD} +%s )
		/export/kubernetes/certificates/data-encryption-keys.sh
		end_time=$( ${DATE_CMD} +%s )
		diff_time=$(( end_time - st_time ))
		diff_time=$( displaytime ${diff_time} )
		${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: data-encryption-keys done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

		multi_node=1
		if [ "${k8s_master_num}" = "1" ]; then
			if [ -z "${k8s_worker_num}" ]; then
				${ECHO} "${MY_SHORT_HOSTNAME}: kube-up: master only, without worker?"
				multi_node=0
			else
				if [ "${k8s_worker_num}" = "1" ]; then
					# 1 master and 1 worker  - same node?
					t1=$( ${ECHO} ${k8s_master_ips} | awk '{printf $1}' )
					t2=$( ${ECHO} ${k8s_worker_ips} | awk '{printf $1}' )
					if [ "${t1}" = "${t2}" ]; then
						${ECHO} "${MY_SHORT_HOSTNAME}: kube-up: 1 master/1 worker: same node"
						multi_node=0
					fi
				fi
			fi
		fi
		[ ! -d "/export/${real_role}/${MY_HOSTNAME}" ] && mkdir -p /export/${real_role}/${MY_HOSTNAME}
		# save short name of supermaster
		echo "${MY_SHORT_HOSTNAME}" > /export/${real_role}/supermaster
		${ECHO} "etcd.init state ready"
		date > /export/${real_role}/${MY_HOSTNAME}/etcd.init

		${ECHO} "multi_node install: ${multi_node}"

		if [ ${multi_node} -eq 1 ]; then

			st_time=$( ${DATE_CMD} +%s )

			for i in ${k8s_master_ips}; do
				[ "${i}" = "${MY_IP}" ] && continue
				timeout 30 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" /export/kubecertificate/ ${i}:/export/kubecertificate/
			done
			for i in ${k8s_worker_ips}; do
				[ "${i}" = "${MY_IP}" ] && continue
				timeout 30 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" /export/kubecertificate/ ${i}:/export/kubecertificate/
			done
			systemctl start lsyncd.service

			end_time=$( ${DATE_CMD} +%s )
			diff_time=$(( end_time - st_time ))
			diff_time=$( displaytime ${diff_time} )
			${ECHO} "${N1_COLOR}${MY_APP} rsync for certificate to master_ips done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

			# дожидаемся, что все мастера дошли до этапа etcd init
			st_time=$( ${DATE_CMD} +%s )
			max=0
			for i in ${k8s_master_list}; do
				[ "${i}" = "${MY_HOSTNAME}" ] && continue
				while [ ${max} -lt ${maxwait} ]; do
					if [ ! -r /export/master/${i}/etcd.init ]; then
						${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: waiting for etcd ready from ${i}[/export/master/${i}/etcd.init], ${max}/${maxwait}${N0_COLOR}"
						sleep 1
					fi
					max=$(( max + 1 ))
				done
			done

			end_time=$( ${DATE_CMD} +%s )
			diff_time=$(( end_time - st_time ))
			diff_time=$( displaytime ${diff_time} )
			${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: waiting for etcd.init ready for masters done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

			st_time=$( ${DATE_CMD} +%s )
			for i in ${k8s_master_list}; do
				[ "${i}" = "${MY_HOSTNAME}" ] && continue
				if [ ! -r /export/master/${i}/etcd.init ]; then
					${ECHO} "${W1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME} error: ${N1_COLOR}waiting for etcd ready from ${i}, ${max}/${maxwait}${N0_COLOR}"
					exit 1
				fi
			done
			end_time=$( ${DATE_CMD} +%s )
			diff_time=$(( end_time - st_time ))
			diff_time=$( displaytime ${diff_time} )
			${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: waiting for etcd ready for masters done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
		fi
		;;
	master)
		# initial bootstrap on supermaster node
		systemctl stop keepalived || true
		real_role="${INIT_ROLE}"
		[ ! -d "/export/${real_role}/${MY_HOSTNAME}" ] && mkdir -p /export/${real_role}/${MY_HOSTNAME}
		date > /export/${real_role}/${MY_HOSTNAME}/etcd.init
		# waiting for supermaster first
		max=0
		while [ ${max} -lt ${maxwait} ]; do
			_reqfile="/export/etcd.init /export/kubecertificate/certs/ca.pem /export/kubecertificate/certs/$( hostname ).pem /export/kubecertificate/certs/$( hostname )-etcd-client.pem /export/kubecertificate/certs/$( hostname )-etcd.pem"
			ready=1
			for i in ${_reqfile}; do
				[ ! -r ${i} ] && ready=0 && break
			done
			if [ ${ready} -eq 1 ]; then
				max=$(( maxwait + 100 ))
			else
				${ECHO} "   ${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: no such: ${i}, waiting ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
				sleep 1
			fi
			max=$(( max + 1 ))
		done
		;;
	worker)
		real_role="${INIT_ROLE}"
		[ ! -d "/export/${real_role}/${MY_HOSTNAME}" ] && mkdir -p /export/${real_role}/${MY_HOSTNAME}
		[ "${INIT_ROLE}" = "master" ] && date > /export/${real_role}/${MY_HOSTNAME}/etcd.init
		# waiting for supermaster first
		max=0
		while [ ${max} -lt ${maxwait} ]; do
			_reqfile="/export/etcd.init /export/kubecertificate/certs/ca.pem /export/kubecertificate/certs/$( hostname ).pem /export/kubecertificate/certs/$( hostname )-etcd-client.pem"
			ready=1
			for i in ${_reqfile}; do
				[ ! -r ${i} ] && ready=0 && break
			done
			if [ ${ready} -eq 1 ]; then
				max=$(( maxwait + 100 ))
			else
				${ECHO} "   ${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: no such: ${i} file, waiting ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
				sleep 1
			fi
			max=$(( max + 1 ))
		done
		;;
esac

if [ ! -r /export/kubecertificate/certs/ca.pem ]; then
	${ECHO} "${W1_COLOR}${MY_APP} ${MY_SHORT_HOSTNAME} error: ${N1_COLOR}no such ${N2_COLOR}/export/kubecertificate/certs/ca.pem${N0_COLOR}"
	exit 1
fi

case "${real_role}" in
	master)
		/export/kubernetes/install_scripts_secure/install_master.sh
		if [ "${INIT_ROLE}" = "supermaster" ]; then
			if [ ! -r /export/kubecertificate/certs/admin.kubeconfig ]; then
				${ECHO} "error: no such /export/kubecertificate/certs/admin.kubeconfig!"
				exit 1
			fi
			# export for bscp as ubuntu user
			cp -a /export/kubecertificate/certs/admin.kubeconfig /home/ubuntu/config
			chmod 0400 /home/ubuntu/config
			chown ubuntu:ubuntu /home/ubuntu/config
		fi
		;;
	worker)
		/export/kubernetes/install_scripts_secure/install_nodes.sh
		;;
esac
iptables -t nat -A PREROUTING -p tcp --dport 30000 -j DNAT --to-destination 10.0.0.2:30000 # http
iptables -t nat -A PREROUTING -p tcp --dport 32000 -j DNAT --to-destination 10.0.0.2:32000 # nginx ui
iptables -t nat -A PREROUTING -p tcp --dport 31000 -j DNAT --to-destination 10.0.0.2:31000 # https
/export/kubernetes/set_hosts.sh
