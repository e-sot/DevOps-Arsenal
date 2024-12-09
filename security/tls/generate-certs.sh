#!/bin/bash
set -euo pipefail

# Configuration
CERT_DIR="$(dirname "$0")"
CA_DIR="${CERT_DIR}/ca"
WEBAPP_DIR="${CERT_DIR}/webapp"
OPENSSL_CONF="${CERT_DIR}/openssl.cnf"
CERTS_CONF="${CERT_DIR}/certs.conf"
DAYS_VALID=365
KEY_SIZE=4096
ORGANIZATION="ETO Group"
ORGANIZATIONAL_UNIT="IT Security"
COMMON_NAME="eto-group.local"
EMAIL="security@eto-group.local"

# Logging configuration
LOG_FILE="${CERT_DIR}/cert-generation.log"
exec 1> >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_requirements() {
    log "Checking requirements..."
    command -v openssl >/dev/null 2>&1 || error "OpenSSL is required but not installed"
    [ -f "${OPENSSL_CONF}" ] || error "OpenSSL configuration file not found: ${OPENSSL_CONF}"
    [ -f "${CERTS_CONF}" ] || error "Certificates configuration file not found: ${CERTS_CONF}"
}

create_directories() {
    log "Creating certificate directories..."
    mkdir -p "${CA_DIR}" "${WEBAPP_DIR}"
    chmod 700 "${CA_DIR}" "${WEBAPP_DIR}"
}

generate_ca() {
    log "Generating CA certificate..."
    if [ -f "${CA_DIR}/ca.key" ]; then
        log "CA key already exists, skipping..."
        return
    fi

    # Generate CA private key
    openssl genrsa -out "${CA_DIR}/ca.key" ${KEY_SIZE}
    chmod 400 "${CA_DIR}/ca.key"

    # Generate CA certificate
    openssl req -x509 -new -nodes \
        -key "${CA_DIR}/ca.key" \
        -sha512 -days ${DAYS_VALID} \
        -out "${CA_DIR}/ca.crt" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}" \
        -config "${OPENSSL_CONF}" \
        -extensions v3_ca

    chmod 444 "${CA_DIR}/ca.crt"
    touch "${CA_DIR}/ca.srl"
    chmod 600 "${CA_DIR}/ca.srl"
}

generate_webapp_cert() {
    log "Generating webapp certificate..."
    
    # Generate private key
    openssl genrsa -out "${WEBAPP_DIR}/webapp.key" ${KEY_SIZE}
    chmod 400 "${WEBAPP_DIR}/webapp.key"

    # Generate CSR
    openssl req -new \
        -key "${WEBAPP_DIR}/webapp.key" \
        -out "${WEBAPP_DIR}/webapp.csr" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=webapp.${COMMON_NAME}/emailAddress=${EMAIL}" \
        -config "${OPENSSL_CONF}"

    # Sign certificate with CA
    openssl x509 -req \
        -in "${WEBAPP_DIR}/webapp.csr" \
        -CA "${CA_DIR}/ca.crt" \
        -CAkey "${CA_DIR}/ca.key" \
        -CAcreateserial \
        -out "${WEBAPP_DIR}/webapp.crt" \
        -days ${DAYS_VALID} \
        -sha512 \
        -extfile "${CERTS_CONF}" \
        -extensions webapp_cert

    chmod 444 "${WEBAPP_DIR}/webapp.crt"
}

verify_certificates() {
    log "Verifying certificates..."
    
    # Verify CA certificate
    openssl x509 -noout -text -in "${CA_DIR}/ca.crt"
    openssl verify -CAfile "${CA_DIR}/ca.crt" "${CA_DIR}/ca.crt"

    # Verify webapp certificate
    openssl x509 -noout -text -in "${WEBAPP_DIR}/webapp.crt"
    openssl verify -CAfile "${CA_DIR}/ca.crt" "${WEBAPP_DIR}/webapp.crt"
}

create_chain() {
    log "Creating certificate chain..."
    cat "${WEBAPP_DIR}/webapp.crt" "${CA_DIR}/ca.crt" > "${WEBAPP_DIR}/chain.pem"
    chmod 444 "${WEBAPP_DIR}/chain.pem"
}

backup_certificates() {
    log "Backing up certificates..."
    BACKUP_DIR="${CERT_DIR}/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${BACKUP_DIR}"
    cp -r "${CA_DIR}" "${WEBAPP_DIR}" "${BACKUP_DIR}/"
    chmod -R 600 "${BACKUP_DIR}"
}

main() {
    log "Starting certificate generation process..."
    
    check_requirements
    create_directories
    generate_ca
    generate_webapp_cert
    verify_certificates
    create_chain
    backup_certificates
    
    log "Certificate generation completed successfully"
}

main "$@"
