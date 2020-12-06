#!/bin/sh

set_hosts()
{
	local _ip="${1}"
	local _str="${2}"
	local _ret

	echo "Check ${_ip} + ${_str}"
	grep -q "^${_ip} " /etc/hosts
	_ret=$?
	if [ ${_ret} -eq 1 ]; then
		# not exist, just add
		echo "${_ip} ${_str}" >> /etc/hosts
		echo "/etc/hosts ${_ip} added"
	else
		cp -a /etc/hosts /etc/hosts.bak
		grep -v "^${_ip} " /etc/hosts.bak > /etc/hosts
		echo "${_ip} ${_str}" >> /etc/hosts
		echo "/etc/hosts ${_ip} fixed"
	fi
}

MY_HOSTNAME=$( hostname )

master_list=$( for i in $( find /export/master/ -maxdepth 1 -type d 2>/dev/null ); do
	p2=${i##*/export/master/}
	[ -z "${p2}" ] && continue
	[ "${p2}" = "${MY_HOSTNAME}" ] && continue
	printf "${p2} "
done )

worker_list=$( for i in $( find /export/worker/ -maxdepth 1 -type d 2>/dev/null ); do
	p2=${i##*/export/worker/}
	[ -z "${p2}" ] && continue
	[ "${p2}" = "${MY_HOSTNAME}" ] && continue
	printf "${p2} "
done )

[ -z "${master_list}" -a -z "${worker_list}" ] && exit 0

for i in ${master_list}; do
	[ ! -r /export/master/${i}/ip ] && continue
	ip=$( cat /export/master/${i}/ip )
	[ -z "${ip}" ] && continue
	short_name=${i%%.*}
	set_hosts $ip "$i $short_name"
done
for i in ${worker_list}; do
	[ ! -r /export/worker/${i}/ip ] && continue
	ip=$( cat /export/worker/${i}/ip )
	[ -z "${ip}" ] && continue
	short_name=${i%%.*}
	set_hosts $ip "$i $short_name"
done

exit 0
