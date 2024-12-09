#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "${PROJECT_ROOT}/.env"

# Restore Configuration
BACKUP_ROOT="${BACKUP_DIR:-/data/backup}"
LOG_FILE="${BACKUP_ROOT}/restore.log"
TEMP_DIR="/tmp/eto-restore-$(date +%Y%m%d-%H%M%S)"

# Logging setup
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
    local required_commands=("docker" "kubectl" "pg_restore" "tar" "gpg")
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error "$cmd is required but not installed"
        fi
    done
}

stop_services() {
    log "Stopping services..."
    docker-compose -f "${PROJECT_ROOT}/docker/docker-compose.yml" down
    kubectl scale deployment -n eto --all --replicas=0
}

decrypt_backup() {
    log "Decrypting backup..."
    if [ -z "${1:-}" ]; then
        error "Backup file not specified"
    fi
    
    if [ -z "${BACKUP_ENCRYPTION_KEY:-}" ]; then
        error "Backup encryption key not set"
    fi
    
    mkdir -p "${TEMP_DIR}"
    gpg --batch --yes --passphrase "${BACKUP_ENCRYPTION_KEY}" \
        --decrypt "$1" > "${TEMP_DIR}/backup.tar.gz"
    
    tar xzf "${TEMP_DIR}/backup.tar.gz" -C "${TEMP_DIR}"

}
restore_database() {
    log "Restoring databases..."
    local db_dumps="${TEMP_DIR}/db"
    
    for dump in "${db_dumps}"/*.dump; do
        local db_name=$(basename "${dump}" .dump)
        log "Restoring database: ${db_name}"
        
        docker exec -i postgres pg_restore \
            -U "${DB_USER}" \
            -d "${db_name}" \
            --clean \
            --if-exists \
            < "${dump}"
    done
}

restore_volumes() {
    log "Restoring volumes..."
    local volume_backups="${TEMP_DIR}/volumes"
    
    for backup in "${volume_backups}"/*.tar.gz; do
        local volume_name=$(basename "${backup}" .tar.gz)
        log "Restoring volume: ${volume_name}"
        
        docker volume rm -f "${volume_name}" || true
        docker volume create "${volume_name}"
        
        docker run --rm \
            -v "${volume_name}:/dest" \
            -v "${backup}:/backup.tar.gz" \
            alpine tar xzf /backup.tar.gz -C /dest
    done
}

restore_configs() {
    log "Restoring configurations..."
    local config_backup="${TEMP_DIR}/config"
    
    # Restore Kubernetes configs
    if [ -f "${config_backup}/k8s-resources.yaml" ]; then
        kubectl apply -f "${config_backup}/k8s-resources.yaml"
    fi
    
    # Restore application configs
    if [ -d "${config_backup}/docker" ]; then
        cp -r "${config_backup}/docker" "${PROJECT_ROOT}/"
    fi
}

verify_restore() {
    log "Verifying restoration..."
    
    # Check database connectivity
    for db in $(docker exec postgres psql -U "${DB_USER}" -l -t | cut -d'|' -f1); do
        docker exec postgres psql -U "${DB_USER}" -d "${db}" -c "\dt"
    done
    
    # Check volume restoration
    docker volume ls --format '{{.Name}}' | grep 'eto' | while read volume; do
        docker run --rm -v "${volume}:/vol" alpine ls -la /vol
    done
    
    # Check services
    kubectl get pods -n eto
    docker-compose -f "${PROJECT_ROOT}/docker/docker-compose.yml" ps
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "${TEMP_DIR}"
}

main() {
    local backup_file="${1:-}"
    if [ -z "${backup_file}" ]; then
        error "Usage: $0 <backup-file.tar.gz.gpg>"
    fi
    
    log "Starting restore process..."
    
    check_dependencies
    stop_services
    decrypt_backup "${backup_file}"
    restore_database
    restore_volumes
    restore_configs
    verify_restore
    cleanup
    
    log "Restore completed successfully"
}

trap cleanup EXIT
main "$@"
