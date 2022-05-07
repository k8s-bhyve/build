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

: ${CA_COUNTRY:=IN}
: ${CA_STATE:=UP}
: ${CA_LOCALITY:=GN}
: ${CA_ORGANIZATION:=CloudInc}
: ${CA_ORGU:=IT}
: ${CA_EMAIL:=cloudinc.gmail.com}
: ${CA_COMMONNAME:=kube-system}
: ${CA_DAYS:="3650"}

[ ! -d $CERTIFICATE/certs ] && mkdir -p $CERTIFICATE/certs
cd $CERTIFICATE/certs

if [ -r ca.pem ]; then
	echo "CA already exist"
	exit 0
fi

#Create a self signed certificate
openssl req -new -x509 -nodes -keyout ca-key.pem -out ca.pem -days ${CA_DAYS} -passin pass:sumit \
-subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=${CA_COMMONNAME}/emailAddress=${CA_EMAIL}"

ret=$?

chattr +i ca.pem

exit ${ret}
