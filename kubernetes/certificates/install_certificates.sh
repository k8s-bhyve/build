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

: ${CA_COUNTRY:=IN}
: ${CA_STATE:=UP}
: ${CA_LOCALITY:=GN}
: ${CA_ORGANIZATION:=CloudInc}
: ${CA_ORGU:=IT}
: ${CA_EMAIL:=cloudinc.gmail.com}
: ${CA_COMMONNAME:=kube-system}

[ ! -d $CERTIFICATE/certs ] && mkdir -p $CERTIFICATE/certs
cd $CERTIFICATE/certs

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
for server in $SERVER_IP 127.0.0.1; do
echo "IP.$counter = $server"
counter=$((counter+1))
done
`
EOF

#Create a private key
if [ ! -r server-key.pem ]; then
	openssl genrsa -out server-key.pem ${CERT_KEY_BIT}
else
	echo "install_certificates: server-key.pem already exist"
fi

#Create CSR for the server
if [ ! -r server.csr ]; then
	#openssl req -new -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf
	#https://medium.com/@oleg.pershin/kubernetes-from-scratch-certificates-53a1a16b5f03
	#openssl req -new -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=system:masters/CN=kubernetes-admin/OU=${CA_ORGU}/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf
	openssl req -new -nodes -sha256 -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf
else
	echo "install_certificates: server.csr already exist"
fi

#Create a self signed certificate
if [ ! -r server.pem ]; then
	openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -days 10000 -extensions v3_req -extfile server-openssl.cnf

#openssl req -x509 -sha256 -nodes \
#-addext "subjectAltName = DNS:$name" -subj "/CN=$name"

	#Verify a Private Key Matches a Certificate
	openssl x509 -noout -text -in server.pem
else
	echo "install_certificates: server.pem already exist"
fi

for user in admin kube-proxy kubelet kube-controller-manager kube-scheduler ${MASTER_HOSTNAME}; do
	if [ ! -r ${user}-key.pem ]; then
		openssl genrsa -out ${user}-key.pem ${CERT_KEY_BIT}
	else
		echo "install_certificates: ${user}-key.pem already exist"
	fi

	#-addext "subjectAltName = DNS:$VIP" \
	if [ ! -r ${user}.csr ]; then
		#openssl req -new -key ${user}-key.pem -out ${user}.csr -subj "/CN=${user}"
		openssl req \
			-new \
			-nodes \
			-sha256 \
			-key ${user}-key.pem \
			-out ${user}.csr \
			-subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=system:masters/CN=kubernetes-admin"
	else
		echo "install_certificates: ${user}-key.pem already exist"
	fi

	if [ ! -r ${user}.pem ]; then
		openssl x509 -req -in ${user}.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out ${user}.pem -days 7200
	else
		echo "install_certificates: ${user}.pem already exist"
	fi
done

#Install worker nodes
IFS=','
for worker in $WORKERS; do
	oifs=$IFS
	IFS=':'
	read -r ip node <<< "$worker"
	echo "The node $node"
	$INSTALL_PATH/../certificates/install_node.sh -i $ip -h $node
	IFS=$oifs
done
unset IFS

# deprecated for 1.19.+ ?
# kube-apiserver[4288]: Error: unknown flag: --basic-auth-file
# --basic-auth-file=/export/kubecertificate/certs/basic_auth.csv
#echo "admin,admin,admin" > basic_auth.csv

#Install worker nodes
IFS=','
for worker in $ETCD_CLUSTERS_CERTS; do
	oifs=$IFS
	IFS=':'
	read -r ip node <<< "$worker"
	echo "The node $node"
	$INSTALL_PATH/../certificates/install_peercert.sh -i $ip -h $node -t server -f etcd
	IFS=$oifs
done
unset IFS

#Install worker nodes
IFS=','
for worker in $NODES; do
	oifs=$IFS
	IFS=':'
	read -r ip node <<< "$worker"
	echo "The node $node"
	$INSTALL_PATH/../certificates/install_peercert.sh -i $ip -h $node -t client -f etcd
	IFS=$oifs
done
unset IFS

exit 0
