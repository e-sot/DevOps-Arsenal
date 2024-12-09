#!/bin/bash
set -euo pipefail

# Configuration
CERT_DIR="$(dirname "$0")"
CA_DIR="${CERT_DIR}/ca"
WEBAPP_DIR="${CERT_DIR}/webapp"
OPENSSL_CONF="${CERT_DIR}/openssl.cnf"
CERTS_CONF="${CERT_DIR}/certs.conf"
BACKUP_DIR="${CERT_DIR}/backup/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${CERT_DIR}/renew-certs.log"
EXPIRY_WARNING_DAYS=30
FORCE_RENEWAL=false

# Logging configuration
exec 1> >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_dependencies() {
    log "Checking dependencies..."
    command -v openssl >/dev/null 2>&1 || error "OpenSSL is required"
    [ -f "${OPENSSL_CONF}" ] || error "OpenSSL configuration not found"
    [ -f "${CERTS_CONF}" ] || error "Certificates configuration not found"
}

backup_current_certs() {
    log "Backing up current certificates..."
    mkdir -p "${BACKUP_DIR}"
    if [ -d "${CA_DIR}" ]; then
        cp -r "${CA_DIR}" "${BACKUP_DIR}/"
    fi
    if [ -d "${WEBAPP_DIR}" ]; then
        cp -r "${WEBAPP_DIR}" "${BACKUP_DIR}/"
    fi
    chmod -R 600 "${BACKUP_DIR}"
}

check_cert_expiry() {
    local cert_file=$1
    local days_remaining
    
    if [ ! -f "${cert_file}" ]; then
        return 0
    }
    
    days_remaining=$(openssl x509 -enddate -noout -in "${cert_file}" | \
        awk -F'=' '{print $2}' | \
        xargs -I{} date -d "{}" +%s | \
        xargs -I{} echo "({} - $(date +%s))/(60*60*24)" | bc)
    
    echo "${days_remaining}"
}

renew_ca_cert() {
    if [ "${FORCE_RENEWAL}" = "true" ] || [ ! -f "${CA_DIR}/ca.crt" ]; then
        log "Generating new CA certificate..."
        mkdir -p "${CA_DIR}"
        openssl genrsa -out "${CA_DIR}/ca.key" 4096
        chmod 400 "${CA_DIR}/ca.key"
        
        openssl req -x509 -new -nodes \
            -key "${CA_DIR}/ca.key" \
            -sha512 -days 3650 \
            -out "${CA_DIR}/ca.crt" \
            -config "${OPENSSL_CONF}" \
            -extensions v3_ca
        
        chmod 444 "${CA_DIR}/ca.crt"
    else
        log "CA certificate still valid, skipping renewal"
    fi
}

renew_webapp_cert() {
    log "Renewing webapp certificate..."
    mkdir -p "${WEBAPP_DIR}"
    
    # Generate new private key
    openssl genrsa -out "${WEBAPP_DIR}/webapp.key.new" 4096
    chmod 400 "${WEBAPP_DIR}/webapp.key.new"
    
    # Generate CSR
    openssl req -new \
        -key "${WEBAPP_DIR}/webapp.key.new" \
        -out "${WEBAPP_DIR}/webapp.csr" \
        -config "${OPENSSL_CONF}"
    
    # Sign certificate
    openssl x509 -req \
        -in "${WEBAPP_DIR}/webapp.csr" \
        -CA "${CA_DIR}/ca.crt" \
        -CAkey "${CA_DIR}/ca.key" \
        -CAcreateserial \
        -out "${WEBAPP_DIR}/webapp.crt.new" \
        -days 365 \
        -sha512 \
        -extfile "${CERTS_CONF}" \
        -extensions webapp_cert
    
    # Verify new certificate
    openssl verify -CAfile "${CA_DIR}/ca.crt" "${WEBAPP_DIR}/webapp.crt.new"
    
    # Replace old certificates with new ones
    mv "${WEBAPP_DIR}/webapp.key.new" "${WEBAPP_DIR}/webapp.key"
    mv "${WEBAPP_DIR}/webapp.crt.new" "${WEBAPP_DIR}/webapp.crt"
    chmod 444 "${WEBAPP_DIR}/webapp.crt"
}

update_kubernetes_secrets() {
    log "Updating Kubernetes secrets..."
    if command -v kubectl >/dev/null 2>&1; then
        kubectl create secret tls webapp-tls \
            --cert="${WEBAPP_DIR}/webapp.crt" \
            --key="${WEBAPP_DIR}/webapp.key" \
            --dry-run=client -o yaml | \
            kubectl apply -f -
    else
        log "kubectl not found, skipping Kubernetes secret update"
    fi
}

notify_renewal() {
    local cert_type=$1
    local expiry_days=$2
    
    log "Certificate renewal notification: ${cert_type}"
    log "Days until expiry: ${expiry_days}"
    
    # Add your notification mechanism here (email, Slack, etc.)
}

main() {
    log "Starting certificate renewal process..."
    
    check_dependencies
    backup_current_certs
    
    # Check CA certificate
    ca_expiry=$(check_cert_expiry "${CA_DIR}/ca.crt")
    if [ "${ca_expiry}" -lt "${EXPIRY_WARNING_DAYS}" ]; then
        notify_renewal "CA" "${ca_expiry}"
        renew_ca_cert
    fi
    
    # Check webapp certificate
    webapp_expiry=$(check_cert_expiry "${WEBAPP_DIR}/webapp.crt")
    if [ "${webapp_expiry}" -lt "${EXPIRY_WARNING_DAYS}" ] || [ "${FORCE_RENEWAL}" = "true" ]; then
        notify_renewal "Webapp" "${webapp_expiry}"
        renew_webapp_cert
        update_kubernetes_secrets
    fi
    
    log "Certificate renewal process completed"
}

# Parse command line arguments
while getopts "f" opt; do
    case ${opt} in
        f)
            FORCE_RENEWAL=true
            ;;
        \?)
            error "Invalid option: -$OPTARG"
            ;;
    esac
done

main "$@"
