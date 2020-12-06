#!/bin/sh
# $1 - size in bytes
conv2human()
{
	local lhal="B"
	local tmpmem="$1"
	local lval

	human_val=""

	for hval in "Kb" "Mb" "Gb"; do
		mem=$(( tmpmem / 1024 ))
		[ "${mem}" = "0" ] && break
		tmpmem=${mem}
		lval="${hval}"
	done

	human_val="${tmpmem} ${lval}"
}


name=$( hostname )

is_lsb=$( lsb_release -sd 2>/dev/null )

if [ -n "${is_lsb}" ]; then
	os="${is_lsb}"
else
	if [ -f /etc/redhat-release ]; then
		os=$( cat /etc/redhat-release | sed 's/\n \l//' | head -n 1 )
	elif [-f /etc/issue ]; then
		os=$( cat /etc/redhat-release | sed 's/\n \l//' | head -n 1 )
	fi
fi

tmp_ip=$( hostname -I )
ip=
# prune docker net
for i in ${tmp_ip}; do
	a=$( echo ${i} |grep ^172 )
	if [ $? -ne 0 ]; then
		if [ -z "${ip}" ]; then
			ip="${i}"
		else
			ip="${ip} ${i}"
		fi
	fi
done
CPUName=`cat /proc/cpuinfo | grep 'model name' | head -n 1 | awk '{print ($4, $5, $6, $8, $9, $10)}'`
NCores=$( cat /proc/cpuinfo | grep 'model name' | wc -l )
freemem_bytes=$( free -b | head -n2 | tail -n1 | awk {'print $4'} )
totalmem_bytes=$( free -b | head -n2 | tail -n1 | awk {'print $2'} )
conv2human ${totalmem_bytes}
TOTAL_MEM="${human_val}"
conv2human ${freemem_bytes}
FREE_MEM="${human_val}"
mem=$( echo $TOTAL_MEM' total / '$FREE_MEM' free' )
username=$( whoami )

[ -r /home/ubuntu/bootstrap.config ] && . /home/ubuntu/bootstrap.config

[ -z "${INIT_WORKER_NUM}" ] && INIT_WORKER_NUM=0

if [ -e /tmp/puppet.info ]; then
	puppetinfo=$(cat /tmp/puppet.info)
fi
if [ -e /etc/puppetlabs/puppet/puppet.conf ]; then
	puppetenv="\n              environment is \"$(grep 'environment' /etc/puppetlabs/puppet/puppet.conf | cut -d'=' -f2| tr -d ' ')\""
fi
echo -e "
------------------: System Data :-------------------------------
Hostname:     \033[1;33m$name\033[0m ($ip)
Kernel:       `uname -r` ($os)
Uptime:      `uptime | sed 's/.*up ([^,]*), .*/1/'`
CPU:          $CPUName ($NCores cores)
Memory(Mb):   $mem
\033[1;92mKubernetes info:\033[0m
  Cluster: ${K8S_VER}, ${CLUSTER}/${K8S_NAME} ( masters:${INIT_MASTERS_NUM}, workers:${INIT_NODES_NUM} )
  Init role: ${INIT_ROLE}
------------------------: Logged as: [\033[0;32m`whoami`\033[0m]  ------------------------------
"
if Tx=$( tmux ls 2> /dev/null ); then
	echo -e "\033[0;31mTmux Sessions:\033[0m"
	echo $Tx
fi
