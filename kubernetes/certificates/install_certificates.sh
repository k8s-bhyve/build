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

for i in server.csr server-key.pem server.pem; do
	if [ -r ${i} ]; then
		chattr -i ${i}
		rm -f ${i}
	fi
done

#Create a private key
echo "Generate server-key.pem: openssl genrsa -out server-key.pem ${CERT_KEY_BIT}"
openssl genrsa -out server-key.pem ${CERT_KEY_BIT}
chattr +i server-key.pem

#Create CSR for the server
#openssl req -new -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf
#https://medium.com/@oleg.pershin/kubernetes-from-scratch-certificates-53a1a16b5f03
#openssl req -new -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=system:masters/CN=kubernetes-admin/OU=${CA_ORGU}/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf
openssl req -new -nodes -sha256 -key server-key.pem -subj "/C=${CA_COUNTRY}/ST=${CA_STATE}/L=${CA_LOCALITY}/O=${CA_ORGANIZATION}/OU=${CA_ORGU}/CN=kube-apiserver/emailAddress=${CA_EMAIL}" -out server.csr -config server-openssl.cnf

##Create a self signed certificate
echo "Generate server.pem: openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -days 10000 -extensions v3_req -extfile server-openssl.cnf"
openssl x509 -req -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -days 10000 -extensions v3_req -extfile server-openssl.cnf
chattr +i server.pem

#Verify a Private Key Matches a Certificate
openssl x509 -noout -text -in server.pem

echo "gen: admin kube-proxy kubelet kube-controller-manager kube-scheduler ${MASTER_HOSTNAME}"
for user in admin kube-proxy kubelet kube-controller-manager kube-scheduler ${MASTER_HOSTNAME}; do
	if [ ! -r ${user}-key.pem ]; then
		openssl genrsa -out ${user}-key.pem ${CERT_KEY_BIT}
		chattr +i ${user}-key.pem
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
		chattr +i ${user}.pem
	else
		echo "install_certificates: ${user}.pem already exist"
	fi

	echo " :: ${user} done"
done

# kubernetesapi req for /export/kubecertificate/certs//master1.k8s-bhyve.io-etcd-client.pem
if [ "${INSTALL_KUBELET_ON_MASTER}" = "false" ]; then
	#Install worker nodes
	IFS=','
	for worker in $SERVERS; do
		oifs=$IFS
		IFS=':'
		read -r ip node <<< "$worker"
		echo "The node $node"
		$INSTALL_PATH/../certificates/install_node.sh -i $ip -h $node
		$INSTALL_PATH/../certificates/install_peercert.sh -i $ip -h $node -t client -f etcd
		IFS=$oifs
	done
	unset IFS
fi

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
