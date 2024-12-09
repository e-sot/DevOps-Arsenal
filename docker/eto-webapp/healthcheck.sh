#!/bin/bash
set -euo pipefail

# Configuration
TIMEOUT=30
MAX_RETRIES=3
RETRY_INTERVAL=5
HTTP_PORT="${PORT:-8080}"
HEALTH_ENDPOINT="/healthcheck"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

# Log functions
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

log_warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARNING] $1" >&2
}

# Helper functions
check_port_open() {
    local host=$1
    local port=$2
    local service=$3
    timeout 5 bash -c ">/dev/tcp/${host}/${port}" 2>/dev/null
    if [ $? -eq 0 ]; then
        log_info "${service} connection successful (${host}:${port})"
        return 0
    else
        log_error "${service} connection failed (${host}:${port})"
        return 1
    fi
}

check_http_endpoint() {
    local url=$1
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "${url}")
    if [ "$response" -eq 200 ]; then
        log_info "HTTP endpoint check successful ($url)"
        return 0
    else
        log_error "HTTP endpoint check failed ($url) with status $response"
        return 1
    fi
}

check_disk_space() {
    local threshold=90
    local usage
    usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -lt "$threshold" ]; then
        log_info "Disk space check passed (${usage}%)"
        return 0
    else
        log_error "Disk space critical (${usage}%)"
        return 1
    fi
}

check_memory() {
    local threshold=90
    local usage
    usage=$(free | awk '/Mem:/ {print int($3/$2 * 100)}')
    if [ "$usage" -lt "$threshold" ]; then
        log_info "Memory check passed (${usage}%)"
        return 0
    else
        log_error "Memory usage critical (${usage}%)"
        return 1
    fi
}

check_python_process() {
    if pgrep -f "python.*app.py" > /dev/null; then
        log_info "Python process check passed"
        return 0
    else
        log_error "Python process not found"
        return 1
    fi
}

# Main health check function
main_health_check() {
    local failed=0

    # Check system resources
    check_disk_space || failed=1
    check_memory || failed=1

    # Check Python process
    check_python_process || failed=1

    # Check database connection
    check_port_open "$DB_HOST" "$DB_PORT" "Database" || failed=1

    # Check Redis connection if configured
    if [ -n "${REDIS_HOST:-}" ]; then
        check_port_open "$REDIS_HOST" "$REDIS_PORT" "Redis" || failed=1
    fi

    # Check application HTTP endpoint
    check_http_endpoint "http://localhost:${HTTP_PORT}${HEALTH_ENDPOINT}" || failed=1

    # Final health status
    if [ $failed -eq 0 ]; then
        log_info "All health checks passed"
        return 0
    else
        log_error "One or more health checks failed"
        return 1
    fi
}

# Retry mechanism
retry_health_check() {
    local retry_count=0
    local result=1

    while [ $retry_count -lt $MAX_RETRIES ]; do
        if main_health_check; then
            result=0
            break
        fi
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            log_warning "Retrying health check in ${RETRY_INTERVAL} seconds (attempt ${retry_count}/${MAX_RETRIES})"
            sleep "$RETRY_INTERVAL"
        fi
    done

    return $result
}

# Script execution with timeout
timeout "$TIMEOUT" bash -c retry_health_check || {
    log_error "Health check timed out after ${TIMEOUT} seconds"
    exit 1
}
