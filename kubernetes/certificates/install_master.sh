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

[ ! -d $CERTIFICATE/certs ] && mkdir -p $CERTIFICATE/certs
pushd $CERTIFICATE/certs

cat <<EOF | sudo tee server-openssl.cnf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
`
IFS=','
counter=1
for server in $SERVER_DNS; do
echo "DNS.$counter = $server"
counter=$((counter+1))
done
counter=1
for server in $SERVER_IP; do
echo "IP.$counter = $server"
counter=$((counter+1))
done
`
EOF

#Create a private key
openssl genrsa -out server-key.pem ${CERT_KEY_BIT}

#Create CSR for the server
#openssl req -new -key server-key.pem \
#-subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" \
#-out server.csr -config server-openssl.cnf

openssl req \
	-new \
	-nodes \
	-sha256 \
	-key server-key.pem \
	-subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" \
	-out server.csr -config server-openssl.cnf

#Create a self signed certificate
#openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem \
#-days 10000 -extensions v3_req -extfile server-openssl.cnf

openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem \
-days 10000 -extensions v3_req -extfile server-openssl.cnf

#Verify a Private Key Matches a Certificate
openssl x509 -noout -text -in server.pem

popd
