#!/bin/sh
pgm="${0##*/}"          # Program basename
progdir="${0%/*}"       # Program directory
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
[ -r ${INSTALL_PATH}/../config ] && . $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/ansiicolor.subr
. /kubernetes/time.subr

[ "${ENABLE_DEBUG}" = "true" ] && set -x

[ ! -d ${WORKDIR}/workspace ] && mkdir -p ${WORKDIR}/workspace
cd ${WORKDIR}/workspace

install_kubernetes()
{
	local DST="kubernetes-server-linux-amd64.tar.gz"

	[ -x /usr/local/bin/kubectl ] && return 0		# already exist

	[ ! -d /usr/local/bin ] && mkdir -p /usr/local/bin

	TRAP="${TRAP} rm -rf ${DST};"
	trap "${TRAP}" HUP INT ABRT BUS TERM EXIT

	if [ ! -x /usr/local/bin/kubectl ]; then
		if [ ! -r ${DST} ]; then
			wget -O ${DST} https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/kubernetes-server-linux-amd64.tar.gz
			ret=$?
			[ ${ret} -ne 0 ] && err ${ret} "${W1_COLOR}${pgm} error: ${N1_COLOR}wget ${N2_COLOR}${DST}${N0_COLOR}"
		fi
		if [ -r "${DST}" ]; then
			tar -xf ${DST} -C /opt/
			[ ${ret} -ne 0 ] && err 1 "tar ${DST}"
		else
			err 1 "tar ${DST}"
		fi
	fi

	for i in ${K8S_BIN_FILES}; do
		if [ ! -x /usr/local/bin/${i} ]; then
			echo "install_binaries: no such /usr/local/bin/${i}"
			exit 1
		fi
		mv /opt/kubernetes/server/bin/${i} /usr/local/bin/${i}
		ret=$?
		if [ ${ret} -ne 0 ]; then
			echo "error: mv /opt/kubernetes/server/bin/${i} /usr/local/bin/${i}"
			exit ${ret}
		fi
		chmod +x /usr/local/bin/${i}
	done

	[ ! -d /var/lib/kubernetes ] && mkdir -p /var/lib/kubernetes/

#	mkdir -p /var/lib/{kube-controller-manager,kubelet,kube-proxy,kube-scheduler} \
#		/etc/{kubernetes,sysconfig} \
#		/etc/kubernetes/manifests

	echo "rm -rf  /opt/kubernetes"
}

install_etcd()
{
	local DST="etcd-linux-amd64.tar.gz"

	[ -x /opt/etcd/bin/etcd ] && return 0		# already exist

	if [ ! -s ${DST} ]; then
		wget -O ${DST} https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "${W1_COLOR}${pgm} error: ${N1_COLOR}wget ${N2_COLOR}${DST}${N0_COLOR}"
	fi

	#Install ectd
	tempdir=$( mktemp -d )

	TRAP="${TRAP} rm -rf ${tempdir}; rm -f ${DST};"
	trap "${TRAP}" HUP INT ABRT BUS TERM EXIT

	tar -xf ${DST} -C ${tempdir}
	if [ $? -ne 0 ]; then
		echo "Extract etcd error $( realpath ${DST} )"
		exit 1
	fi

	mkdir -p /opt/etcd/bin /opt/etcd/config /var/lib/etcd
	mv ${tempdir}/etcd*/etcd* /opt/etcd/bin
	chmod 0700 /var/lib/etcd
}

install_flannel()
{
	local DST="flannel-linux-amd64.tar.gz"

	[ -x /opt/flannel/flanneld ] && return 0	# already exist

	if [ ! -s ${DST} ]; then
		wget -O ${DST} https://github.com/coreos/flannel/releases/download/${FLANNEL_VER}/flannel-${FLANNEL_VER}-linux-amd64.tar.gz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
	fi

	mkdir -p /opt/flannel

	TRAP="${TRAP} rm -rf ${DST};"
	trap "${TRAP}" HUP INT ABRT BUS TERM EXIT

	tar xzf ${DST} -C /opt/flannel
	if [ $? -ne 0 ]; then
		echo "${DST} extract error"
		exit 1
	fi
	mkdir -p /etc/flanneld
}

install_containerd()
{
	local DST="containerd.tar.gz"

	[ -x /bin/containerd ] && return 0		# already exist

	if [ ! -s ${DST} ]; then
		wget -O ${DST} https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
	fi

	mkdir /tmp/containerd

	TRAP="${TRAP} rm -rf ${DST};"
	trap "${TRAP}" HUP INT ABRT BUS TERM EXIT

	tar -xf ${DST} -C /tmp/containerd
	if [ $? -ne 0 ]; then
		echo "${DST} extract error"
		exit 1
	fi

	mv /tmp/containerd/bin/* /bin/
	mkdir -p /etc/containerd

}

install_cni_plugins()
{
	local DST="cni-plugins-linux-amd64.tgz"

	[ -x /opt/cni/bin/bridge ] && return 0		# already exist

	if [ ! -s ${DST} ]; then
		wget -O ${DST} https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_LINUX_VER}/cni-plugins-linux-amd64-${CNI_PLUGINS_LINUX_VER}.tgz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
	fi

	[ ! -d /opt/cni/bin ] && mkdir -p /opt/cni/bin
	echo "tar -xvf ${DST} -C /opt/cni/bin/"
	tar -xvf ${DST} -C /opt/cni/bin/
	if [ $? -ne 0 ]; then
		echo "${DST} extract error"
		exit 1
	fi
}

install_crictl()
{
	local DST="crictl-linux-amd64.tar.gz"

	[ -x /usr/local/bin/crictl ] && return 0	# already exist

	if [ ! -s ${DST} ]; then
		echo "wget -O ${DST} https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_TOOLS_VER}/crictl-${CRI_TOOLS_VER}-linux-amd64.tar.gz"
		wget -O ${DST} https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_TOOLS_VER}/crictl-${CRI_TOOLS_VER}-linux-amd64.tar.gz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
	fi

	tar -xvf ${DST}
	if [ $? -ne 0 ]; then
		echo "${DST} extract error"
		exit 1
	fi
	chmod +x crictl
	mv crictl /usr/local/bin/
}

install_runc()
{
	local DST="runc.amd64"

	[ -x /usr/local/bin/runc ] && return 0

	if [ ! -s ${DST} ]; then
		wget -O runc.amd64 https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
	fi
	mv ${DST} runc
	chmod +x runc
	mv runc /usr/local/bin/runc
}

TRAP=
install_kubernetes

case "${INIT_ROLE}" in
	master|supermaster)
		install_etcd
		if [ "${INSTALL_KUBELET_ON_MASTER}" = "true" ]; then
			install_containerd
			install_flannel
			install_cni_plugins
			install_crictl
			install_runc
		fi
		;;
	worker)
		install_containerd
		install_flannel
		install_cni_plugins
		install_crictl
		install_runc
		;;
	gold)
		date
#		install_etcd
#		install_containerd
#		install_flannel
#		install_cni_plugins
#		install_crictl
#		install_runc
		;;
esac

exit 0
