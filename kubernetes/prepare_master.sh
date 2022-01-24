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

MY_SHORT_HOSTNAME=$( hostname -s )
INIT_ROLE="${1}"
echo "INIT_ROLE=\"${INIT_ROLE}\"" >> /home/ubuntu/bootstrap.config

if [ "${1}" != "gold" ]; then
	[ -r /kubernetes/config ] && . /kubernetes/config
	. /home/ubuntu/bootstrap.config
	. /kubernetes/tools.subr
	. /kubernetes/time.subr
	. /kubernetes/ansiicolor.subr

	echo "CONFIG TIME"
	st_time=$( ${DATE_CMD} +%s )
	systemctl stop chrony || true

	for i in ${NTP_SERVERS}; do
		${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: initial ntpdate from: ${N2_COLOR}${i}${N0_COLOR}"
		ntpdate ${i}
		break
	done
	diff_time=$( displaytime ${diff_time} )
	diff_time=$(( end_time - st_time ))
	${ECHO} "${N1_COLOR}${MY_APP}:${MY_SHORT_HOSTNAME}: config time done ${N2_COLOR}in ${diff_time}${N0_COLOR}"
fi

config_swap()
{
	cp -a /etc/fstab /etc/fstab.bak
	swapoff -a
	sed -i  '/swap/d' /etc/fstab
	diff -ruN /etc/fstab.bak /etc/fstab
}

config_swap

if [ "${INIT_ROLE}" = "gold" ]; then
	rm -rf /kubernetes
	cd /
	ln -s ~ubuntu/kubernetes /kubernetes
	# fixes for "debconf: unable to initialize frontend: Dialog"
	#apt -y install dialog
	sed -i "s/^GRUB_TIMEOUT.*\$/GRUB_TIMEOUT=0/g" /etc/default/grub
	grub-mkconfig

	export DEBIAN_FRONTEND="noninteractive"

	# sleep 30 seconds to let Ubuntu/apt boot ready
	# (apt-get update doesn't pass ASAP, need for pause

#	for i in $( seq 10 10 100 ); do
#		echo "sleep 100 for apt ready ${i}/100"
#		sleep 10
#	done

	#sleep 120
	echo "disable automatic updates"
	cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
APT::Periodic::Unattended-Upgrade "0";
EOF

	dpkg-reconfigure unattended-upgrades

	for i in unattended-upgrades.service snapd.socket snapd.service; do
		systemctl stop ${i}
		systemctl disable ${i}
	done

	echo "update"
	apt-get update
	echo "upgrade"
	apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
	echo "install"
	apt install -y git net-tools haproxy mc lsyncd keepalived rsync socat nfs-common haproxy ntpdate chrony
	cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
	apt clean -y
	rm -f /etc/keepalived/keepalived.conf
	dd if=/dev/urandom of=/home/ubuntu/.rnd bs=256 count=1
	[ ! -d export ] && mkdir export
	cd export
	ln -sf /kubernetes
	echo "upgrade"
	apt-get upgrade -y
	apt clean -y
	set +o xtrace
else
	FULL_ST_TIME=$( ${DATE_CMD} +%s )
	st_time="${FULL_ST_TIME}"
	# save absolute st_time
	echo "FULL_ST_TIME=\"${FULL_ST_TIME}\"" >> /home/ubuntu/bootstrap.config
	${ECHO} "${N1_COLOR}${MY_APP} generate new k8s cluster ssh pair...${N0_COLOR}"
	[ -r /root/.ssh/id_ed25519 ] && rm -f /root/.ssh/id_ed25519
	[ -r /root/.ssh/authorized_keys ] && rm -f /root/.ssh/authorized_keys
	[ ! -r /home/ubuntu/id_ed25519 ] && err 1 "${N1_COLOR}${MY_APP} no such /home/ubuntu/id_ed25519${N0_COLOR}"
	[ ! -r /home/ubuntu/authorized_keys ] && err 1 "${N1_COLOR}${MY_APP} no such /home/ubuntu/authorized_keys${N0_COLOR}"
	mv /home/ubuntu/id_ed25519 /root/.ssh/
	mv /home/ubuntu/authorized_keys /root/.ssh/
	chown root:root /root/.ssh/id_ed25519 /root/.ssh/authorized_keys
	chmod 0400 /root/.ssh/id_ed25519
	time_stats "${N1_COLOR}${MY_APP}: ${MY_SHORT_HOSTNAME}: generate ssh pair"
fi

/home/ubuntu/kubernetes/prepare_pup.sh ${1}

systemctl stop puppet.service || true
systemctl disable puppet.service || true
