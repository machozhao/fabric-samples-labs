#!/bin/bash
# 1. Setup parameters
# MSP base directory, will output all certificates in this base directory
CRYPTO_CONFIG_DIR=${PWD}/../basic-network/crypto-config
ORG_DOMAIN_NAME="org1.example.com"
PEER_USERS="Admin2"

# 2.
# 2. Create OpenSSL CA config and work directory
CA_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/ca"
CA_OPENSSL_CFG="${CA_CERT_OUTPUT_DIR}/openssl.cnf"
CA_CERT_FILE=${CA_CERT_OUTPUT_DIR}/cacert.pem
CA_PRIVATE_KEY_FILE=${CA_CERT_OUTPUT_DIR}/private/cakey.pem

# ##########################################################
# 4. Generate certs for org users
# ##########################################################
for PEER_USER in $PEER_USERS
do
        USER_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}"
        USER_CERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}"
        USER_CERT_SUBJECT="${USER_CERT_BASE_SUBJECT}/CN=${PEER_USER}@${ORG_DOMAIN_NAME}"
        USER_CERT_FILE="${USER_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_USER}@${ORG_DOMAIN_NAME}-cert.pem"
        USER_CERT_CSR_FILE="${USER_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_USER}@${ORG_DOMAIN_NAME}-csr.pem"
        USER_CERT_PRIVATE_KEY_FILE="${USER_CERT_OUTPUT_DIR}/msp/keystore/private_sk"
        USER_CERT_PRIVATE_KEY_P8_FILE="${USER_CERT_OUTPUT_DIR}/msp/keystore/private_p8"

        # A. Create output directory
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/admincerts"
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/cacerts"
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/keystore"
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/signcerts"
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/tlscacerts"
        mkdir -p "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/tls"

        # B. Generate private key
        openssl ecparam -genkey -name prime256v1 -out "${USER_CERT_PRIVATE_KEY_FILE}"
        openssl pkcs8 -topk8 -nocrypt -in "${USER_CERT_PRIVATE_KEY_FILE}" -out "${USER_CERT_PRIVATE_KEY_P8_FILE}"
        openssl ecparam -name prime256v1 -in "${USER_CERT_PRIVATE_KEY_FILE}" -text -noout

        # C. Generate CSR
        openssl req -new -sha256 -key "${USER_CERT_PRIVATE_KEY_FILE}" -out "${USER_CERT_CSR_FILE}" -subj "${USER_CERT_SUBJECT}"
        openssl req -verify -in ${USER_CERT_CSR_FILE} -noout -text

        # D. Sign by CA
        openssl ca -batch -policy policy_anything -days 3650 -out "${USER_CERT_FILE}" -in "${USER_CERT_CSR_FILE}" -keyfile "${CA_PRIVATE_KEY_FILE}" -cert "${CA_CERT_FILE}" -config ${CA_OPENSSL_CFG}
        openssl x509 -in ${USER_CERT_FILE} -noout -text

        # E. Copy to HFC key store
        cp ${USER_CERT_PRIVATE_KEY_P8_FILE} ~/.hfc-key-store/${PEER_USER}@${ORG_DOMAIN_NAME}-priv
        cp ${USER_CERT_FILE} ~/.hfc-key-store/${PEER_USER}@${ORG_DOMAIN_NAME}.cert.pem

        USER_CERT_CONTENT=""
        while read line; do
            if [[ "$line" == "-----BEGIN CERTIFICATE-----" ]];
            then
               USER_CERT_CONTENT="$line"
            else
               USER_CERT_CONTENT="${USER_CERT_CONTENT}\\n${line}"
            fi
        done < "${USER_CERT_FILE}"

        echo "{\"name\":\"${PEER_USER}@${ORG_DOMAIN_NAME}\",\"mspid\":\"Org1MSP\",\"roles\":null,\"affiliation\":\"\",\"enrollmentSecret\":\"\",\"enrollment\":{\"signingIdentity\":\"${PEER_USER}@${ORG_DOMAIN_NAME}\",\"identity\":{\"certificate\":\"${USER_CERT_CONTENT}\"}}}" > ~/.hfc-key-store/${PEER_USER}@${ORG_DOMAIN_NAME}

        # F. Copy to creds dir
        cp ~/.hfc-key-store/${PEER_USER}@${ORG_DOMAIN_NAME} ./creds/
        cp ~/.hfc-key-store/${PEER_USER}@${ORG_DOMAIN_NAME}-priv ./creds/

        # G. fill addtional msp elements
        cp ${USER_CERT_FILE} "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/admincerts/"
        cp ${CA_CERT_FILE} "${CRYPTO_CONFIG_DIR}/peerOrganizations/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/cacerts/"
done

