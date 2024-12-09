#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_ROOT}/.env"

# Backup Configuration
BACKUP_ROOT="${BACKUP_DIR:-/data/backup}"
BACKUP_NAME="eto-backup-$(date +%Y%m%d-%H%M%S)"
BACKUP_PATH="${BACKUP_ROOT}/${BACKUP_NAME}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
LOG_FILE="${BACKUP_ROOT}/backup.log"

# Ensure backup directory exists
mkdir -p "${BACKUP_ROOT}"
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

check_dependencies() {
    log "Checking dependencies..."
    local required_commands=("docker" "kubectl" "pg_dump" "tar" "gpg")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is required but not installed"
        fi
    done
}

backup_database() {
    log "Backing up databases..."
    mkdir -p "${BACKUP_PATH}/db"
    
    # Get database containers
    local db_containers=$(docker ps --format '{{.Names}}' | grep '_db')
    
    for container in ${db_containers}; do
        log "Backing up database from container: ${container}"
        docker exec "${container}" pg_dump \
            -U "${DB_USER}" \
            -F c \
            "${DB_NAME}" > "${BACKUP_PATH}/db/${container}.dump"
    done
}

backup_volumes() {
    log "Backing up Docker volumes..."
    mkdir -p "${BACKUP_PATH}/volumes"
    
    # Get all volumes
    local volumes=$(docker volume ls --format '{{.Name}}' | grep 'eto')
    
    for volume in ${volumes}; do
        log "Backing up volume: ${volume}"
        docker run --rm \
            -v "${volume}:/source:ro" \
            -v "${BACKUP_PATH}/volumes:/backup" \
            alpine tar czf "/backup/${volume}.tar.gz" -C /source .
    done
}

backup_configs() {
    log "Backing up configuration files..."
    mkdir -p "${BACKUP_PATH}/config"
    
    # Backup Kubernetes configs
    if command -v kubectl &> /dev/null; then
        log "Backing up Kubernetes resources..."
        kubectl get all -n eto -o yaml > "${BACKUP_PATH}/config/k8s-resources.yaml"
        kubectl get secrets -n eto -o yaml > "${BACKUP_PATH}/config/k8s-secrets.yaml"
        kubectl get configmaps -n eto -o yaml > "${BACKUP_PATH}/config/k8s-configmaps.yaml"
    fi
    
    # Backup application configs
    cp -r "${PROJECT_ROOT}/docker" "${BACKUP_PATH}/config/"
    cp -r "${PROJECT_ROOT}/ansible" "${BACKUP_PATH}/config/"
}

encrypt_backup() {
    log "Encrypting backup..."
    if [ -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
        error "Backup encryption key not set"
    fi
    
    tar czf "${BACKUP_PATH}.tar.gz" -C "${BACKUP_ROOT}" "${BACKUP_NAME}"
    gpg --batch --yes --passphrase "${BACKUP_ENCRYPTION_KEY}" \
        --symmetric "${BACKUP_PATH}.tar.gz"
    
    rm -rf "${BACKUP_PATH}" "${BACKUP_PATH}.tar.gz"
}

cleanup_old_backups() {
    log "Cleaning up old backups..."
    find "${BACKUP_ROOT}" -name "eto-backup-*.tar.gz.gpg" -mtime "+${RETENTION_DAYS}" -delete
    find "${BACKUP_ROOT}" -name "eto-backup-*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete
}

verify_backup() {
    log "Verifying backup..."
    if [ ! -f "${BACKUP_PATH}.tar.gz.gpg" ]; then
        error "Backup file not found: ${BACKUP_PATH}.tar.gz.gpg"
    fi
    
    # Test decryption
    gpg --batch --yes --passphrase "${BACKUP_ENCRYPTION_KEY}" \
        --decrypt "${BACKUP_PATH}.tar.gz.gpg" > /dev/null
}

main() {
    log "Starting backup process..."
    
    check_dependencies
    backup_database
    backup_volumes
    backup_configs
    encrypt_backup
    verify_backup
    cleanup_old_backups
    
    log "Backup completed successfully: ${BACKUP_PATH}.tar.gz.gpg"
}

main "$@"
