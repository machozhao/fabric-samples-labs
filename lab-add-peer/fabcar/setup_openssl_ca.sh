#!/bin/bash
# 1. Setup parameters
# MSP base directory, will output all certificates in this base directory
CRYPTO_CONFIG_DIR=${PWD}/../basic-network/crypto-config
ORG_DOMAIN_NAME="org1.example.com"

# 2. Create OpenSSL CA config and work directory
CA_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/ca"
CA_OPENSSL_CFG="${CA_CERT_OUTPUT_DIR}/openssl.cnf"

rm -rf "${CA_CERT_OUTPUT_DIR}/openssl"
mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl"
mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/certs"
mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/crl"
mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/newcerts"
mkdir -p "${CA_CERT_OUTPUT_DIR}/private"
more openssl.cnf.template | sed "s/DemoCA_Dir/$(echo "${CA_CERT_OUTPUT_DIR}/openssl" | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" > ${CA_OPENSSL_CFG}
touch "${CA_CERT_OUTPUT_DIR}/openssl/index.txt"
echo 01 > "${CA_CERT_OUTPUT_DIR}/openssl/serial"
cp ${CA_CERT_OUTPUT_DIR}/ca.${ORG_DOMAIN_NAME}-cert.pem ${CA_CERT_OUTPUT_DIR}/cacert.pem
cp ${CA_CERT_OUTPUT_DIR}/*_sk ${CA_CERT_OUTPUT_DIR}/private/cakey.pem

