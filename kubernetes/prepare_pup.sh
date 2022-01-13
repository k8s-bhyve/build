#!/bin/sh
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin:/opt/puppetlabs/bin"

# valid role: 'gold', 'master', 'worker'
case "${1}" in
	gold|master|worker|supermaster)
		;;
	*)
		echo "vald role: 'gold', 'master', 'supermaster', 'worker'" 2>&1
		exit 1
		;;
esac

role="${1}"

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1

echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.lo.disable_ipv6=1" >> /etc/sysctl.conf

systemctl stop ntp || true
ntpdate 1.ubuntu.pool.ntp.org
systemctl start ntp || true

gold()
{
	# in gold
	wget -O /tmp/puppet.deb https://apt.puppet.com/puppet7-release-$( lsb_release -sc ).deb
	dpkg -i  /tmp/puppet.deb
	apt update -y
	apt install -y puppet-agent
	systemctl stop puppet.service >/dev/null 2>&1 || true
	systemctl disable puppet.service >/dev/null 2>&1 || true
	cd /home/ubuntu
	tar xfz puppet.tgz
	rm -f puppet.tgz
	rm -rf /etc/puppetlabs/puppet
	mv puppet /etc/puppetlabs
	rm -rf /etc/puppetlabs/code/environments/production/modules || true
	[ ! -d /etc/puppetlabs/code/environments/production ] && mkdir -p /etc/puppetlabs/code/environments/production
	ln -sf /etc/puppetlabs/puppet/modules /etc/puppetlabs/code/environments/production/modules

	sed -Ees:%%MASTER_HOSTNAME%%:${MASTER_HOSTNAME}:g \
	-Ees:%%CONFIG_SOURCE%%:${CONFIG_SOURCE}:g \
	-Ees:%%ETCD_VER%%:${ETCD_VER}:g \
	-Ees:%%CLUSTER%%:${CLUSTER}:g \
	-Ees#%%API_SERVER%%#${API_SERVER}#g \
	-Ees#%%API_SERVERS%%#${API_SERVERS}#g \
	-Ees#%%APISERVER_HOST%%#${APISERVER_HOST}#g \
	-Ees:%%VIP%%:${VIP}:g \
	/etc/puppetlabs/puppet/data/role/k8s-master.yaml > /etc/puppetlabs/puppet/data/role/gold.yaml

	[ ! -d /etc/puppetlabs/puppet/data/nodes ] && mkdir -p /etc/puppetlabs/puppet/data/nodes

	MY_HOSTNAME=$( /opt/puppetlabs/bin/facter fqdn )

	echo "role: gold" >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml

#	/opt/puppetlabs/bin/puppet apply /etc/puppetlabs/puppet/site.pp
	/opt/puppetlabs/bin/puppet apply --show_diff --hiera_config=/etc/puppetlabs/puppet/hiera.yaml /etc/puppetlabs/puppet/site.pp
	#sed -i'' -Ees:%%ETCD_VER%%:${ETCD_VER}:g /etc/puppetlabs/puppet/data/nodes/master.yaml
	. /home/ubuntu/bootstrap.config

	/kubernetes/install_scripts_secure/install_binaries.sh
	/kubernetes/install_scripts_secure/install_haproxy.sh
	#docker pull k8s.gcr.io/kubernetes-dashboard-amd64:${DASHBOARD_VER}
	apt clean -y
	rm -rf /var/lib/cloud
	rm -f /home/ubuntu/authorized_keys /home/ubuntu/id_ed25519 /home/ubuntu/kubernetes.tgz
	rm -f /etc/puppetlabs/puppet/data/role/gold.yaml /etc/puppetlabs/puppet/data/nodes/*
	exit 0
}

master()
{
	sed -i'' -Ees:%%MASTER_HOSTNAME%%:${MASTER_HOSTNAME}:g /kubernetes/kube_service/ingress/example/ldap-ing.yaml

	# доготавливаем keepalive
	cat /etc/puppetlabs/puppet/tpl/keepalived_part_header.yaml >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml
	unicast_peers=
	for i in ${INIT_MASTERS_IPS}; do
		[ "${i}" = "${MY_IP}" ] && continue
		if [ -z "${unicast_peers}" ]; then
			unicast_peers="'${i}'"
		else
			unicast_peers="${unicast_peers}, '${i}'"
		fi
	done
	sed -Ees:%%IP%%:${MY_IP}:g \
		-Ees:%%VIP%%:${VIP}:g \
		-Ees:%%INTERFACE%%:${INTERFACE}:g \
		-Ees:%%VRID%%:${VRID}:g \
		/etc/puppetlabs/puppet/tpl/keepalived_part_body.yaml >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml
	echo "    unicast_peers: [ ${unicast_peers} ]" >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml
}

bootstrap()
{
	cat > /etc/hosts <<EOF
127.0.0.1       localhost
EOF

	echo "${VIP} ${MASTER_HOSTNAME} master" >> /etc/hosts
	echo "${MY_HOSTNAME}" > /etc/hostname
	hostname $( cat /etc/hostname )
	MY_IP=$( hostname -I | awk '{printf $1}' )
	short_name=${MY_HOSTNAME%%.*}
	echo "${MY_IP} ${MY_HOSTNAME} ${short_name}" >> /etc/hosts
}

addnode()
{
	cd /opt/puppetlabs/puppet
	/opt/puppetlabs/bin/puppet apply --show_diff --hiera_config=/etc/puppetlabs/puppet/hiera.yaml --log_level=notice /etc/puppetlabs/puppet/site.pp
	/opt/puppetlabs/bin/puppet apply --show_diff --hiera_config=/etc/puppetlabs/puppet/hiera.yaml --log_level=notice /etc/puppetlabs/puppet/site.pp
}

### MAIN
# get original FQDN
# hardcode ?
. /home/ubuntu/bootstrap.config

MY_HOSTNAME=$( /opt/puppetlabs/bin/facter fqdn )
echo "My hostname: [${MY_HOSTNAME}]"

case "${role}" in
	gold)
		gold
		exit 0
		;;
	addnode)
		echo
		;;
	master|supermaster|worker)
		bootstrap
		;;
esac

MY_IP=$( hostname -I | awk '{printf $1}' )

[ ! -d /etc/puppetlabs/puppet/data/nodes ] && mkdir -p /etc/puppetlabs/puppet/data/nodes
cp -a /etc/puppetlabs/puppet/tpl/${role}.yaml /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml

# доготавливаем динамику lsync
lsync_init=0

ALL_IPS=$( for i in ${INIT_MASTERS_IPS} ${INIT_NODES_IPS}; do
	echo $i
done | sort -u )

for i in ${ALL_IPS}; do
	[ "${i}" = "${MY_IP}" ] && continue
	lsync_init=$(( lsync_init + 1 ))
	[ ${lsync_init} -eq 1 ] && cat /etc/puppetlabs/puppet/tpl/lsync_part_header.yaml >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml
	sed -Ees:%%IP%%:${i}:g /etc/puppetlabs/puppet/tpl/lsync_part_body.yaml >> /etc/puppetlabs/puppet/data/nodes/${MY_HOSTNAME}.yaml
done

case "${role}" in
	master|supermaster)
		real_role="master"
		master
		;;
	addnode)
		real_role="addnode"
		addnode
		exit 0
		;;
	*)
		real_role="worker"
		;;
esac

sed -i'' -Ees:%%MASTER_HOSTNAME%%:${MASTER_HOSTNAME}:g \
	-Ees:%%CONFIG_SOURCE%%:${CONFIG_SOURCE}:g \
	-Ees:%%ETCD_VER%%:${ETCD_VER}:g \
	-Ees:%%CLUSTER%%:${CLUSTER}:g \
	-Ees#%%API_SERVER%%#${API_SERVER}#g \
	-Ees#%%API_SERVERS%%#${API_SERVERS}#g \
	-Ees#%%APISERVER_HOST%%#${APISERVER_HOST}#g \
	-Ees:%%VIP%%:${VIP}:g \
	/etc/puppetlabs/puppet/data/role/k8s-${real_role}.yaml

cd /opt/puppetlabs/puppet

/opt/puppetlabs/bin/puppet apply --show_diff --hiera_config=/etc/puppetlabs/puppet/hiera.yaml --log_level=notice /etc/puppetlabs/puppet/site.pp
/opt/puppetlabs/bin/puppet apply --show_diff --hiera_config=/etc/puppetlabs/puppet/hiera.yaml --log_level=notice /etc/puppetlabs/puppet/site.pp

echo "my role: ${real_role}, export /export/${real_role}/${MY_HOSTNAME}"
if [ ! -d /export/${real_role}/${MY_HOSTNAME} ]; then
	echo "Create: /export/${real_role}/${MY_HOSTNAME}"
	mkdir -p /export/${real_role}/${MY_HOSTNAME}
fi
printf "${MY_IP}" > /export/${real_role}/${MY_HOSTNAME}/ip
echo "printf \"${MY_IP}\" > /export/${real_role}/${MY_HOSTNAME}/ip"

cat /export/${real_role}/${MY_HOSTNAME}/ip


# waiting for masters
maxwait=200
max=0
st_time=$( ${DATE_CMD} +%s )
while [ ${max} -lt ${maxwait} ]; do
	_ret=0
	wait_msg="${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: sync/export role to masters node: ${N2_COLOR}[${max}/${maxwait}]${N0_COLOR}"
	echo "rsync -avz -e \"ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no\" --exclude tmp --exclude kubernetes /export/ ${i}:/export/"
	for i in ${INIT_MASTERS_IPS}; do
		_res=$( timeout 10 rsync -avz -e "ssh -oVerifyHostKeyDNS=yes -oStrictHostKeyChecking=no -oPasswordAuthentication=no" --exclude tmp --exclude kubernetes /export/ ${i}:/export/ )
		_ret=$?
		case ${_ret} in
			0|6|24|25)
				_ret=0
				;;
			*)
				wait_msg="${wait_msg} ${i}"
				_ret=1
		esac
	done
	[ ${_ret} -eq 0 ] && break
	echo "${wait_msg}"
done
end_time=$( ${DATE_CMD} +%s )
diff_time=$(( end_time - st_time ))
diff_time=$( displaytime ${diff_time} )
${ECHO} "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: export role done ${N2_COLOR}in ${diff_time}${N0_COLOR}"

bash /home/ubuntu/kubernetes/kube-up.sh
