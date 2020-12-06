#!/bin/bash
pgm="${0##*/}"          # Program basename
progdir="${0%/*}"       # Program directory
: ${INSTALL_PATH:=$MOUNT_PATH/kubernetes/install_scripts_secure}
[ -r ${INSTALL_PATH}/../config ] && . $INSTALL_PATH/../config
. /home/ubuntu/bootstrap.config
. /kubernetes/tools.subr
. /kubernetes/ansiicolor.subr
. /kubernetes/time.subr

[ "${ENABLE_DEBUG}" = "true" ] && set -x

#NODE_IP=$2
#HOSTNAME=$1

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
 -i|--ip)
 NODE_IP="$2"
 shift
 shift
 ;;
 -h|--host)
 HOSTNAME="$2"
 shift
 shift
 ;;
 -f|--file)
 FILENAME="$2"
 shift
 shift
 ;;
 -t|--type)
 TYPE="$2"
 shift
 shift
 ;;
esac
done

if [ -z "$NODE_IP" ]
then
	echo "Please provide node ip"
	exit 0
fi
if [ -z "$HOSTNAME" ]
then
	echo "Please provide node hostname"
	exit 0
fi
if [ -z "$FILENAME" ]
then
	echo "Please provide node filename"
	exit 0
fi
if [ -z "$TYPE" ]
then
	echo "Please provide file type"
	exit 0
fi

: ${CA_COUNTRY:=IN}
: ${CA_STATE:=UP}
: ${CA_LOCALITY:=GN}
: ${CA_ORGANIZATION:=CloudInc}
: ${CA_ORGU:=IT}
: ${CA_EMAIL:=cloudinc.gmail.com}
: ${CA_COMMONNAME:=kube-system}

[ ! -d $CERTIFICATE/certs ] && mkdir -p $CERTIFICATE/certs
pushd $CERTIFICATE/certs

if [ $TYPE == 'server' ]
then
	keyUsage='extendedKeyUsage = clientAuth,serverAuth'
	HOSTNAME="${HOSTNAME}-${FILENAME}"
else
	keyUsage='extendedKeyUsage = clientAuth'
	FILENAME="${FILENAME}-client"
	HOSTNAME="${HOSTNAME}-$FILENAME"
fi

cat <<EOF | sudo tee ${FILENAME}-openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
$keyUsage
`
if [ $TYPE == 'server' ]
then 
echo "subjectAltName = IP:$NODE_IP, DNS:$HOSTNAME"
fi`
EOF

#Create a private key
openssl genrsa -out $HOSTNAME-key.pem ${CERT_KEY_BIT}

#Create CSR for the node
openssl req -new -key $HOSTNAME-key.pem -subj "/CN=$NODE_IP" -out $HOSTNAME.csr -config ${FILENAME}-openssl.cnf

#Create a self signed certificate
openssl x509 -req -in $HOSTNAME.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out $HOSTNAME.pem -days 10000 -extensions v3_req -extfile ${FILENAME}-openssl.cnf


#Copy ca.pem to crt
cat ca.pem >> $HOSTNAME.pem

#Verify a Private Key Matches a Certificate
openssl x509 -noout -text -in $HOSTNAME.pem

popd
