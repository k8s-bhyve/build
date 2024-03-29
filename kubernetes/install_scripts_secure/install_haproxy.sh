#!/bin/bash
pgm="${0##*/}"          # Program basename
progdir="${0%/*}"       # Program directory
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
[ -r ${INSTALL_PATH}/../config ] && . $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/ansiicolor.subr
. /kubernetes/time.subr

if [ "${HAPROXY_ENABLE}" = "0" ]; then
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: disable haproxy by HAPROXY_ENABLE${N0_COLOR}"
	systemctl stop haproxy || true
	systemctl disable haproxy
	exit 0
else
	${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: enable haproxy by HAPROXY_ENABLE${N0_COLOR}"
fi

HAPROXY_CFG="/etc/haproxy/haproxy.cfg"

VIP6=

if [ -n "${EXT_IP}" ]; then
	MYV6=$( echo ${EXT_IP} | tr "/" " " | awk '{printf $1}' )
	VIP6="bind [${MYV6}]:443"
fi

[ "${ENABLE_DEBUG}" = "true" ] && set -x

cat <<EOF > ${HAPROXY_CFG}
global
        log 127.0.0.1 local0
        log 127.0.0.1 local1 notice
        maxconn 4096
        maxpipes 1024
        daemon

defaults
        log global
        mode tcp
        option tcplog
        option dontlognull
        option redispatch
        option http-server-close
        retries 3
        timeout connect 50000
        timeout client 500000
        timeout server 500000

frontend default_frontend
        bind ${VIP}:443
        ${VIP6}
        default_backend master-cluster
backend master-cluster
`#Install master nodes
IFS=','
counter=0
cluster=""
for worker in $SERVERS; do
 oifs=$IFS
 IFS=':'
 read -r ip node <<< "$worker"
 if [ -z "$cluster" ]
 then
  cluster="$ip:6443"
 else
  cluster="$cluster,http://$ip:4001"
 fi
 counter=$((counter+1))
 IFS=$oifs
 echo "        server master-$counter ${cluster} check"
 cluster=""
done
unset IFS`
EOF

#if [ "${CONTAINER_ENGINE}" = "docker" ]; then
#	docker stop master-proxy
#	docker rm master-proxy
#	docker run --restart=always -d --name master-proxy -v ${HAPROXY_CFG}:/usr/local/etc/haproxy/haproxy.cfg:ro --net=host haproxy
#else
	systemctl enable haproxy
	systemctl restart haproxy || true
#fi

exit 0
