#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="${PROJECT_ROOT}/.env"
CERT_SCRIPT="${PROJECT_ROOT}/security/tls/generate-certs.sh"

# Logging configuration
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"
exec 1> >(tee -a "${LOG_FILE}")
exec 2> >(tee -a "${LOG_FILE}" >&2)

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check required commands
    local required_commands=(
        "docker" "docker-compose" "kubectl" "openssl" 
        "python3" "pip3" "ansible" "vault"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is required but not installed"
        fi
    done

    # Check minimum versions
    local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
    local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    local kubectl_version=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    
    [[ "${docker_version}" < "20.10.0" ]] && error "Docker version must be >= 20.10.0"
    [[ "${compose_version}" < "2.0.0" ]] && error "Docker Compose version must be >= 2.0.0"
}

create_directories() {
    log "Creating project directories..."
    
    local directories=(
        "security/tls/ca"
        "security/tls/webapp"
        "security/policies"
        "monitoring/grafana/dashboards"
        "monitoring/prometheus/rules"
        "docker/eto-webapp/config"
        "k8s/manifests"
        "data/backup"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "${PROJECT_ROOT}/${dir}"
        chmod 750 "${PROJECT_ROOT}/${dir}"
    done
}

generate_secrets() {
    log "Generating secrets..."
    
    # Generate random passwords and keys
    local secrets=(
        "POSTGRES_PASSWORD=$(openssl rand -base64 32)"
        "ADMIN_PASSWORD=$(openssl rand -base64 32)"
        "JWT_SECRET=$(openssl rand -base64 64)"
        "API_KEY=$(openssl rand -hex 32)"
        "ENCRYPTION_KEY=$(openssl rand -base64 32)"
    )
    
    # Create .env file
    cat > "${ENV_FILE}" << EOF
# Generated on $(date)
# Environment Configuration
ENVIRONMENT=development
DEBUG=true

# Application
APP_NAME=eto-webapp
APP_VERSION=1.0.0
PORT=8080

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=etodb
DB_USER=etouser
$(printf '%s\n' "${secrets[@]}")

# Paths
DATA_DIR=${PROJECT_ROOT}/data
BACKUP_DIR=${PROJECT_ROOT}/data/backup
CERT_DIR=${PROJECT_ROOT}/security/tls

# Monitoring
PROMETHEUS_RETENTION_DAYS=15
GRAFANA_ADMIN_PASSWORD=${secrets[1]}
EOF

    chmod 600 "${ENV_FILE}"
}

setup_certificates() {
    log "Setting up certificates..."
    
    if [[ -x "${CERT_SCRIPT}" ]]; then
        "${CERT_SCRIPT}"
    else
        error "Certificate generation script not found or not executable"
    fi
}

initialize_vault() {
    log "Initializing Vault..."
    
    if ! vault status &>/dev/null; then
        vault operator init -key-shares=5 -key-threshold=3 > "${PROJECT_ROOT}/security/vault-init.txt"
        chmod 600 "${PROJECT_ROOT}/security/vault-init.txt"
    fi
}

deploy_monitoring() {
    log "Deploying monitoring stack..."
    
    # Deploy Prometheus and Grafana
    kubectl apply -f "${PROJECT_ROOT}/k8s/monitoring/"
    
    # Wait for pods to be ready
    kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
}

main() {
    log "Starting setup process..."
    
    check_requirements
    create_directories
    generate_secrets
    setup_certificates
    initialize_vault
    deploy_monitoring
    
    log "Setup completed successfully"
}

# Execute main function
main "$@"
