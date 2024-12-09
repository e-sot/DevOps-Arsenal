#!/bin/bash
set -euo pipefail

# Configuration
CERT_DIR="$(dirname "$0")"
CA_DIR="${CERT_DIR}/ca"
WEBAPP_DIR="${CERT_DIR}/webapp"
LOG_FILE="${CERT_DIR}/cert-verification.log"
REPORT_DIR="${CERT_DIR}/reports/$(date +%Y%m%d_%H%M%S)"
WARNING_DAYS=30

# Logging configuration
mkdir -p "$(dirname "${LOG_FILE}")" "${REPORT_DIR}"
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
    command -v jq >/dev/null 2>&1 || error "jq is required"
}

verify_ca_cert() {
    log "Verifying CA certificate..."
    local ca_cert="${CA_DIR}/ca.crt"
    local ca_key="${CA_DIR}/ca.key"
    
    # Check CA certificate existence
    [ -f "${ca_cert}" ] || error "CA certificate not found: ${ca_cert}"
    [ -f "${ca_key}" ] || error "CA private key not found: ${ca_key}"
    
    # Verify CA certificate
    openssl x509 -in "${ca_cert}" -text -noout > "${REPORT_DIR}/ca_cert_details.txt"
    
    # Check CA certificate validity
    local end_date=$(openssl x509 -enddate -noout -in "${ca_cert}" | cut -d= -f2)
    local end_epoch=$(date -d "${end_date}" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( (end_epoch - now_epoch) / 86400 ))
    
    if [ "${days_left}" -lt "${WARNING_DAYS}" ]; then
        log "WARNING: CA certificate expires in ${days_left} days"
    fi
    
    # Verify CA key matches certificate
    local cert_modulus=$(openssl x509 -noout -modulus -in "${ca_cert}" | sha256sum)
    local key_modulus=$(openssl rsa -noout -modulus -in "${ca_key}" | sha256sum)
    
    if [ "${cert_modulus}" != "${key_modulus}" ]; then
        error "CA certificate and private key do not match"
    fi
}

verify_webapp_cert() {
    log "Verifying webapp certificate..."
    local webapp_cert="${WEBAPP_DIR}/webapp.crt"
    local webapp_key="${WEBAPP_DIR}/webapp.key"
    
    # Check webapp certificate existence
    [ -f "${webapp_cert}" ] || error "Webapp certificate not found: ${webapp_cert}"
    [ -f "${webapp_key}" ] || error "Webapp private key not found: ${webapp_key}"
    
    # Verify webapp certificate
    openssl x509 -in "${webapp_cert}" -text -noout > "${REPORT_DIR}/webapp_cert_details.txt"
    
    # Verify certificate chain
    openssl verify -CAfile "${CA_DIR}/ca.crt" "${webapp_cert}" > "${REPORT_DIR}/chain_verification.txt"
    
    # Check webapp certificate validity
    local end_date=$(openssl x509 -enddate -noout -in "${webapp_cert}" | cut -d= -f2)
    local end_epoch=$(date -d "${end_date}" +%s)
    local now_epoch=$(date +%s)
    local days_left=$(( (end_epoch - now_epoch) / 86400 ))
    
    if [ "${days_left}" -lt "${WARNING_DAYS}" ]; then
        log "WARNING: Webapp certificate expires in ${days_left} days"
    fi
    
    # Verify key matches certificate
    local cert_modulus=$(openssl x509 -noout -modulus -in "${webapp_cert}" | sha256sum)
    local key_modulus=$(openssl rsa -noout -modulus -in "${webapp_key}" | sha256sum)
    
    if [ "${cert_modulus}" != "${key_modulus}" ]; then
        error "Webapp certificate and private key do not match"
    }
}

verify_cert_permissions() {
    log "Verifying certificate permissions..."
    
    # Check CA directory permissions
    if [ "$(stat -c %a ${CA_DIR})" != "700" ]; then
        error "Invalid CA directory permissions: ${CA_DIR}"
    fi
    
    # Check CA key permissions
    if [ "$(stat -c %a ${CA_DIR}/ca.key)" != "400" ]; then
        error "Invalid CA key permissions: ${CA_DIR}/ca.key"
    fi
    
    # Check webapp directory permissions
    if [ "$(stat -c %a ${WEBAPP_DIR})" != "700" ]; then
        error "Invalid webapp directory permissions: ${WEBAPP_DIR}"
    fi
    
    # Check webapp key permissions
    if [ "$(stat -c %a ${WEBAPP_DIR}/webapp.key)" != "400" ]; then
        error "Invalid webapp key permissions: ${WEBAPP_DIR}/webapp.key"
    fi
}

generate_report() {
    log "Generating verification report..."
    
    cat > "${REPORT_DIR}/verification_summary.txt" << EOF
Certificate Verification Report
Generated: $(date)

CA Certificate:
- Validity: $(openssl x509 -enddate -noout -in "${CA_DIR}/ca.crt")
- Subject: $(openssl x509 -subject -noout -in "${CA_DIR}/ca.crt")
- Issuer: $(openssl x509 -issuer -noout -in "${CA_DIR}/ca.crt")

Webapp Certificate:
- Validity: $(openssl x509 -enddate -noout -in "${WEBAPP_DIR}/webapp.crt")
- Subject: $(openssl x509 -subject -noout -in "${WEBAPP_DIR}/webapp.crt")
- Issuer: $(openssl x509 -issuer -noout -in "${WEBAPP_DIR}/webapp.crt")

Verification Results:
- Certificate Chain: $(cat "${REPORT_DIR}/chain_verification.txt")
- Permission Checks: Passed
- Key Pair Matches: Confirmed
EOF
}

main() {
    log "Starting certificate verification process..."
    
    check_dependencies
    verify_ca_cert
    verify_webapp_cert
    verify_cert_permissions
    generate_report
    
    log "Certificate verification completed successfully"
    log "Report generated at: ${REPORT_DIR}/verification_summary.txt"
}

main "$@"
