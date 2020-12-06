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


DST="kubernetes-server-linux-amd64.tar.gz"
if [ ! -s /opt/kubernetes/server/bin/kubectl ]; then
	if [ ! -s ${DST} ]; then
		wget -O ${DST} https://storage.googleapis.com/kubernetes-release/release/${K8S_VER}/kubernetes-server-linux-amd64.tar.gz
		ret=$?
		[ ${ret} -ne 0 ] && err ${ret} "${W1_COLOR}${pgm} error: ${N1_COLOR}wget ${N2_COLOR}${DST}${N0_COLOR}"
	fi
	if [ -s "${DST}" ]; then
		tar -xf ${DST} -C /opt/
		[ ${ret} -ne 0 ] && err 1 "tar ${DST}"
	else
		err 1 "tar ${DST}"
	fi
fi

DST="etcd-linux-amd64.tar.gz"
if [ ! -s ${DST} ]; then
	wget -O ${DST} https://github.com/coreos/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "${W1_COLOR}${pgm} error: ${N1_COLOR}wget ${N2_COLOR}${DST}${N0_COLOR}"
fi

DST="flannel-linux-amd64.tar.gz"
if [ ! -s ${DST} ]; then
	wget -O ${DST} https://github.com/coreos/flannel/releases/download/${FLANNEL_VER}/flannel-${FLANNEL_VER}-linux-amd64.tar.gz
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
fi

DST="containerd.tar.gz"
if [ ! -s ${DST} ]; then
	wget -O containerd.tar.gz https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VER}/containerd-${CONTAINERD_VER}-linux-amd64.tar.gz
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
fi

DST="cni-plugins-linux-amd64.tgz"
if [ ! -s ${DST} ]; then
	wget -O cni-plugins-linux-amd64.tgz https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGINS_LINUX_VER}/cni-plugins-linux-amd64-${CNI_PLUGINS_LINUX_VER}.tgz
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
fi

DST="crictl-linux-amd64.tar.gz"
if [ ! -s ${DST} ]; then
	echo "wget -O crictl-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_TOOLS_VER}/crictl-${CRI_TOOLS_VER}-linux-amd64.tar.gz"
	wget -O crictl-linux-amd64.tar.gz https://github.com/kubernetes-sigs/cri-tools/releases/download/${CRI_TOOLS_VER}/crictl-${CRI_TOOLS_VER}-linux-amd64.tar.gz
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
fi

DST="runc.amd64"
if [ ! -s ${DST} ]; then
	wget -O runc.amd64 https://github.com/opencontainers/runc/releases/download/${RUNC_VER}/runc.amd64
	ret=$?
	[ ${ret} -ne 0 ] && err ${ret} "wget ${DST}"
fi

for i in ${K8S_BIN_FILES}; do
	if [ ! -s /opt/kubernetes/server/bin/${i} ]; then
		echo "install_binaries: no such /opt/kubernetes/server/bin/${i}"
		exit 1
	fi
	ln -sf /opt/kubernetes/server/bin/${i} /usr/local/bin/${i}
done

#cp /opt/kubernetes/server/bin/{hyperkube,kubeadm,kube-apiserver,kubelet,kube-proxy,kubectl} /usr/local/bin
mkdir -p /var/lib/{kube-controller-manager,kubelet,kube-proxy,kube-scheduler}
mkdir -p /etc/{kubernetes,sysconfig}
mkdir -p /etc/kubernetes/manifests
