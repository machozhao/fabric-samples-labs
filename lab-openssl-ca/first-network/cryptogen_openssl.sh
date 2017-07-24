#!/bin/bash

# Generate CA self sign certificate
# 1. Setup parameters
# MSP base directory, will output all certificates in this base directory
CRYPTO_CONFIG_DIR=./crypto-config

PEER_ORG_DOMAIN_NAMES="org1.example.com org2.example.com org3.example.com org4.example.com org5.example.com org6.example.com"
PEER_NAMES="peer0 peer1 peer2 peer3 peer4 peer5 peer6"
PEER_ADMIN_USERS="Admin Super"
PEER_USERS="User1 User2 User3 User4 User5 User6"
ORDERER_ORG_DOMAIN_NAMES="example.com"
ORDERER_NAMES="orderer"

# Delete old crypto-config
rm -rf $CRYPTO_CONFIG_DIR

# ---------------------------- #
TOP_NODES="peerOrganizations ordererOrganizations"
for TOP_NODE in $TOP_NODES
do
    if [[ "$TOP_NODE" == "peerOrganizations" ]];
    then
       # For peer
       ORG_DOMAIN_NAMES="$PEER_ORG_DOMAIN_NAMES"
       PREFIX_NAMES="$PEER_NAMES"
       NODE="peers"
    else
       # For orderer
       ORG_DOMAIN_NAMES="$ORDERER_ORG_DOMAIN_NAMES"
       PREFIX_NAMES="$ORDERER_NAMES"
       NODE="orderers"
    fi
    # Generating msp for TOP_NODES
	for ORG_DOMAIN_NAME in $ORG_DOMAIN_NAMES
		do
		# CA parameters
		CA_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/ca"
		CA_CERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}"
		CA_CERT_SUBJECT="${CA_CERT_BASE_SUBJECT}/CN=ca.${ORG_DOMAIN_NAME}"
		CA_CERT_FILE="${CA_CERT_OUTPUT_DIR}/ca.${ORG_DOMAIN_NAME}-cert.pem"
		CA_PRIVATE_KEY_FILE="${CA_CERT_OUTPUT_DIR}/private-key-pem_sk"
		CA_OPENSSL_CFG="${CA_CERT_OUTPUT_DIR}/openssl.cnf"

		# ##########################################################
		# 3. CA generation and build MSP output
		# ##########################################################

		# A. Create output directory
		mkdir -p "${CA_CERT_OUTPUT_DIR}"

		# B. Generate private key
		openssl ecparam -name prime256v1 -genkey -out "${CA_PRIVATE_KEY_FILE}"
		openssl ecparam -name prime256v1 -in "${CA_PRIVATE_KEY_FILE}" -text -noout
		# C. Generate self-signed cetificates
		openssl req -new -x509 -key "${CA_PRIVATE_KEY_FILE}" -out ${CA_CERT_FILE} -days 730 -subj "${CA_CERT_SUBJECT}"
		openssl x509 -in ${CA_CERT_FILE} -noout -text
		# D. copy to msp
		mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp"
		mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/cacerts/"
		mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/tlscacerts/"
		mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/admincerts/"
		cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/cacerts/"
		# E. Create OpenSSL CA config and work directory
		mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl"
		mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/certs"
		mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/crl"
		mkdir -p "${CA_CERT_OUTPUT_DIR}/openssl/newcerts"
		more openssl.cnf.template | sed "s/DemoCA_Dir/$(echo "${CA_CERT_OUTPUT_DIR}/openssl" | sed -e 's/\\/\\\\/g; s/\//\\\//g; s/&/\\\&/g')/g" > ${CA_OPENSSL_CFG}
		touch "${CA_CERT_OUTPUT_DIR}/openssl/index.txt"
		echo 01 > "${CA_CERT_OUTPUT_DIR}/openssl/serial"

		# Generate certificate for each peer
		for PEER_NAME in $PREFIX_NAMES
		do
			# ##########################################################
			# 3. Peer ECert
			# ##########################################################
			#PEER_NAME=peer0
			PEER_ECERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/${NODE}/${PEER_NAME}.${ORG_DOMAIN_NAME}"
			PEER_ECERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}"
			PEER_ECERT_SUBJECT="${PEER_ECERT_BASE_SUBJECT}/CN=${PEER_NAME}.${ORG_DOMAIN_NAME}"
			PEER_ECERT_FILE="${PEER_ECERT_OUTPUT_DIR}/msp/signcerts/${PEER_NAME}.${ORG_DOMAIN_NAME}-cert.pem"
			PEER_ECERT_CSR_FILE="${PEER_ECERT_OUTPUT_DIR}/msp/keystore/${PEER_NAME}.${ORG_DOMAIN_NAME}-cert.csr"
			PEER_ECERT_PRIVATE_KEY_FILE="${PEER_ECERT_OUTPUT_DIR}/msp/keystore/private-key-pem_sk"

			# A. Create output directory
			mkdir -p "${PEER_ECERT_OUTPUT_DIR}/msp/signcerts"
			mkdir -p "${PEER_ECERT_OUTPUT_DIR}/msp/keystore"
			mkdir -p "${PEER_ECERT_OUTPUT_DIR}/msp/admincerts"
			mkdir -p "${PEER_ECERT_OUTPUT_DIR}/msp/cacerts"
			mkdir -p "${PEER_ECERT_OUTPUT_DIR}/msp/tlscacerts"

			# B. Generate private key
			openssl ecparam -genkey -name prime256v1 -out "${PEER_ECERT_PRIVATE_KEY_FILE}_p1"
			openssl pkcs8 -topk8 -nocrypt -in "${PEER_ECERT_PRIVATE_KEY_FILE}_p1" -out "${PEER_ECERT_PRIVATE_KEY_FILE}"
			openssl ecparam -name prime256v1 -in "${PEER_ECERT_PRIVATE_KEY_FILE}" -text -noout

			# C. Generate CSR
			openssl req -new -sha256 -key "${PEER_ECERT_PRIVATE_KEY_FILE}" -out "${PEER_ECERT_CSR_FILE}" -subj "${PEER_ECERT_SUBJECT}"
			openssl req -verify -in ${PEER_ECERT_CSR_FILE} -noout -text

			# D. Sign by CA
			openssl ca -batch -policy policy_anything -days 3650 -out "${PEER_ECERT_FILE}" -in "${PEER_ECERT_CSR_FILE}" -keyfile "${CA_PRIVATE_KEY_FILE}" -cert "${CA_CERT_FILE}" -config ${CA_OPENSSL_CFG}
			openssl x509 -in ${PEER_ECERT_FILE} -noout -text

			# E. Copy files, build msp structure
			cp "${CA_CERT_FILE}" "${PEER_ECERT_OUTPUT_DIR}/msp/cacerts"
			cp "${CA_CERT_FILE}" "${PEER_ECERT_OUTPUT_DIR}/msp/tlscacerts/tlsca.${ORG_DOMAIN_NAME}-cert.pem"


	        # ##########################################################
			# 3. Peer TLS Cert
			# ##########################################################
			PEER_TLS_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/${NODE}/${PEER_NAME}.${ORG_DOMAIN_NAME}"
			PEER_TLS_CERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}/OU=TLS"
			PEER_TLS_CERT_SUBJECT="${PEER_TLS_CERT_BASE_SUBJECT}/CN=${PEER_NAME}.${ORG_DOMAIN_NAME}"
			PEER_TLS_CERT_FILE="${PEER_TLS_CERT_OUTPUT_DIR}/tls/server.crt"
			PEER_TLS_CERT_CSR_FILE="${PEER_TLS_CERT_OUTPUT_DIR}/tls/server.csr"
			PEER_TLS_CERT_PRIVATE_KEY_FILE="${PEER_TLS_CERT_OUTPUT_DIR}/tls/server.key"

			# A. Create output directory
			mkdir -p "${PEER_TLS_CERT_OUTPUT_DIR}/tls"
			
			# B. Generate private key
			openssl ecparam -genkey -name prime256v1 -out "${PEER_TLS_CERT_PRIVATE_KEY_FILE}"
			openssl pkcs8 -topk8 -nocrypt -in "${PEER_TLS_CERT_PRIVATE_KEY_FILE}_p1" -out "${PEER_TLS_CERT_PRIVATE_KEY_FILE}"
			openssl ecparam -name prime256v1 -in "${PEER_TLS_CERT_PRIVATE_KEY_FILE}" -text -noout

			# C. Generate CSR
			openssl req -new -sha256 -key "${PEER_TLS_CERT_PRIVATE_KEY_FILE}" -out "${PEER_TLS_CERT_CSR_FILE}" -subj "${PEER_TLS_CERT_SUBJECT}"
			openssl req -verify -in ${PEER_TLS_CERT_CSR_FILE} -noout -text

			# D. Sign by CA
			openssl ca -batch -policy policy_anything -days 3650 -out "${PEER_TLS_CERT_FILE}" -in "${PEER_TLS_CERT_CSR_FILE}" -keyfile "${CA_PRIVATE_KEY_FILE}" -cert "${CA_CERT_FILE}" -config ${CA_OPENSSL_CFG}
			openssl x509 -in ${PEER_TLS_CERT_FILE} -noout -text

			# E. Copy into ca cert
			cp "${CA_CERT_FILE}" "${PEER_TLS_CERT_OUTPUT_DIR}/tls/ca.crt"
			cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/tlscacerts/tlsca.${ORG_DOMAIN_NAME}-cert.pem"

		done # End of each peers


		# ##########################################################
		# 4. Generate certs for org administrators
		# ##########################################################
		for PEER_ADMIN_USER in $PEER_ADMIN_USERS
		do
			PEER_ADMIN_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}"
			PEER_ADMIN_CERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}"
			PEER_ADMIN_CERT_SUBJECT="${PEER_ADMIN_CERT_BASE_SUBJECT}/CN=${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}"
			PEER_ADMIN_CERT_FILE="${PEER_ADMIN_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}-cert.pem"
			PEER_ADMIN_CERT_CSR_FILE="${PEER_ADMIN_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}-csr.pem"
			PEER_ADMIN_CERT_PRIVATE_KEY_FILE="${PEER_ADMIN_CERT_OUTPUT_DIR}/msp/keystore/private_sk"

			# A. Create output directory
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/admincerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/cacerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/keystore"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/signcerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/tlscacerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/tls"
			
			# B. Generate private key
			openssl ecparam -genkey -name prime256v1 -out "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}_p1"
			openssl pkcs8 -topk8 -nocrypt -in "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}_p1" -out "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}"
			openssl ecparam -name prime256v1 -in "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}" -text -noout

			# C. Generate CSR
			openssl req -new -sha256 -key "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}" -out "${PEER_ADMIN_CERT_CSR_FILE}" -subj "${PEER_ADMIN_CERT_SUBJECT}"
			openssl req -verify -in ${PEER_ADMIN_CERT_CSR_FILE} -noout -text

			# D. Sign by CA
			openssl ca -batch -policy policy_anything -days 3650 -out "${PEER_ADMIN_CERT_FILE}" -in "${PEER_ADMIN_CERT_CSR_FILE}" -keyfile "${CA_PRIVATE_KEY_FILE}" -cert "${CA_CERT_FILE}" -config ${CA_OPENSSL_CFG}
			openssl x509 -in ${PEER_ADMIN_CERT_FILE} -noout -text

			# E. Copy into ca cert
			cp "${PEER_ADMIN_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/admincerts"
			cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/cacerts"

			cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_ADMIN_USER}@${ORG_DOMAIN_NAME}/msp/tlscacerts/tlsca.${ORG_DOMAIN_NAME}-cert.pem"
            cp "${PEER_ADMIN_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/msp/admincerts/"
			# F. Copy into tls
			cp "${CA_CERT_FILE}" "${PEER_ADMIN_CERT_OUTPUT_DIR}/tls/ca.crt"
			cp "${PEER_ADMIN_CERT_PRIVATE_KEY_FILE}" "${PEER_ADMIN_CERT_OUTPUT_DIR}/tls/server.key"
			cp "${PEER_ADMIN_CERT_FILE}" "${PEER_ADMIN_CERT_OUTPUT_DIR}/tls/server.crt"

			# G. Copy to peer msp
			for PEER_NAME in $PREFIX_NAMES
			do
				PEER_ECERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/${NODE}/${PEER_NAME}.${ORG_DOMAIN_NAME}"
				cp "${PEER_ADMIN_CERT_FILE}" "${PEER_ECERT_OUTPUT_DIR}/msp/admincerts"
			done

	    done	


		# ##########################################################
		# 5. Generate certs for org users
		# ##########################################################
		for PEER_USER in $PEER_USERS
		do
			PEER_USER_CERT_OUTPUT_DIR="${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}"
			PEER_USER_CERT_BASE_SUBJECT="/C=CN/ST=BJ/L=BJ/O=${ORG_DOMAIN_NAME}"
			PEER_USER_CERT_SUBJECT="${PEER_USER_CERT_BASE_SUBJECT}/CN=${PEER_USER}@${ORG_DOMAIN_NAME}"
			PEER_USER_CERT_FILE="${PEER_USER_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_USER}@${ORG_DOMAIN_NAME}-cert.pem"
			PEER_USER_CERT_CSR_FILE="${PEER_USER_CERT_OUTPUT_DIR}/msp/signcerts/${PEER_USER}@${ORG_DOMAIN_NAME}-csr.pem"
			PEER_USER_CERT_PRIVATE_KEY_FILE="${PEER_USER_CERT_OUTPUT_DIR}/msp/keystore/private_sk"

			# A. Create output directory
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/admincerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/cacerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/keystore"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/signcerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/tlscacerts"
			mkdir -p "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/tls"
			
			# B. Generate private key
			openssl ecparam -genkey -name prime256v1 -out "${PEER_USER_CERT_PRIVATE_KEY_FILE}_p1"
			openssl pkcs8 -topk8 -nocrypt -in "${PEER_USER_CERT_PRIVATE_KEY_FILE}_p1" -out "${PEER_USER_CERT_PRIVATE_KEY_FILE}"
			openssl ecparam -name prime256v1 -in "${PEER_USER_CERT_PRIVATE_KEY_FILE}" -text -noout

			# C. Generate CSR
			openssl req -new -sha256 -key "${PEER_USER_CERT_PRIVATE_KEY_FILE}" -out "${PEER_USER_CERT_CSR_FILE}" -subj "${PEER_USER_CERT_SUBJECT}"
			openssl req -verify -in ${PEER_USER_CERT_CSR_FILE} -noout -text

			# D. Sign by CA
			openssl ca -batch -policy policy_anything -days 3650 -out "${PEER_USER_CERT_FILE}" -in "${PEER_USER_CERT_CSR_FILE}" -keyfile "${CA_PRIVATE_KEY_FILE}" -cert "${CA_CERT_FILE}" -config ${CA_OPENSSL_CFG}
			openssl x509 -in ${PEER_USER_CERT_FILE} -noout -text

			# E. Copy into ca cert
			cp "${PEER_USER_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/admincerts"
			cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/cacerts"
			cp "${CA_CERT_FILE}" "${CRYPTO_CONFIG_DIR}/${TOP_NODE}/${ORG_DOMAIN_NAME}/users/${PEER_USER}@${ORG_DOMAIN_NAME}/msp/tlscacerts/tlsca.${ORG_DOMAIN_NAME}-cert.pem"

			# F. Copy into tls
			cp "${CA_CERT_FILE}" "${PEER_USER_CERT_OUTPUT_DIR}/tls/ca.crt"
			cp "${PEER_USER_CERT_PRIVATE_KEY_FILE}" "${PEER_USER_CERT_OUTPUT_DIR}/tls/server.key"
			cp "${PEER_USER_CERT_FILE}" "${PEER_USER_CERT_OUTPUT_DIR}/tls/server.crt"

	    done  # End of foreach PEER_USER

	done # End of each org_domain

done # End of foreach TOP_NODE

	
