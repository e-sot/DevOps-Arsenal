#!/bin/bash
set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

# Ensure log directory exists
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

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Required commands
    local required_commands=(
        "docker" "docker-compose" "kubectl" "helm"
        "ansible" "python3" "pip3" "openssl" "git"
    )
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" &> /dev/null; then
            error "${cmd} is required but not installed"
        fi
    done
    
    # Check minimum versions
    local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
    local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
    local kubectl_version=$(kubectl version --client -o json | jq -r '.clientVersion.gitVersion')
    local python_version=$(python3 --version | awk '{print $2}')
    
    [[ "${docker_version}" < "20.10.0" ]] && error "Docker version must be >= 20.10.0"
    [[ "${compose_version}" < "2.0.0" ]] && error "Docker Compose version must be >= 2.0.0"
    [[ "${python_version}" < "3.11.0" ]] && error "Python version must be >= 3.11.0"
}

setup_python_environment() {
    log "Setting up Python environment..."
    
    python3 -m venv "${PROJECT_ROOT}/venv"
    source "${PROJECT_ROOT}/venv/bin/activate"
    
    pip install --upgrade pip
    pip install -r "${PROJECT_ROOT}/docker/eto-webapp/requirements.txt"
    pip install -r "${PROJECT_ROOT}/requirements-dev.txt"
}

setup_kubernetes() {
    log "Setting up Kubernetes..."
    
    # Create namespaces
    kubectl apply -f "${PROJECT_ROOT}/k8s/namespace.yml"
    
    # Setup cert-manager
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm upgrade --install cert-manager jetstack/cert-manager \
        --namespace cert-manager \
        --create-namespace \
        --set installCRDs=true
    
    # Setup ingress-nginx
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace
}

setup_monitoring() {
    log "Setting up monitoring stack..."
    
    # Setup Prometheus
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values "${PROJECT_ROOT}/k8s/monitoring/prometheus/values.yml"
    
    # Setup Grafana dashboards
    kubectl apply -f "${PROJECT_ROOT}/k8s/monitoring/grafana/configmaps.yml"
}

setup_vault() {
    log "Setting up Vault..."
    
    helm repo add hashicorp https://helm.releases.hashicorp.com
    helm upgrade --install vault hashicorp/vault \
        --namespace vault \
        --create-namespace \
        --values "${PROJECT_ROOT}/k8s/vault/values.yml"
    
    # Wait for Vault to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=vault \
        --namespace vault --timeout=300s
}

deploy_applications() {
    log "Deploying applications..."
    
    # Deploy secrets and configmaps
    kubectl apply -f "${PROJECT_ROOT}/k8s/secrets.yml"
    kubectl apply -f "${PROJECT_ROOT}/k8s/configmaps.yml"
    
    # Deploy applications
    kubectl apply -f "${PROJECT_ROOT}/k8s/odoo/"
    kubectl apply -f "${PROJECT_ROOT}/k8s/pgadmin/"
    kubectl apply -f "${PROJECT_ROOT}/k8s/eto-webapp/"
    
    # Apply ingress rules
    kubectl apply -f "${PROJECT_ROOT}/k8s/ingress.yml"
}

verify_deployment() {
    log "Verifying deployment..."
    
    # Wait for all pods to be ready
    kubectl wait --for=condition=ready pod \
        --all --all-namespaces \
        --timeout=300s
    
    # Check services
    local services=(
        "odoo:8069/web/health"
        "pgadmin:80/misc/ping"
        "eto-webapp:8080/healthcheck"
    )
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port path <<< "${service}"
        kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never \
            -- -s "http://${name}.eto.svc.cluster.local:${port}${path}"
    done
}

cleanup() {
    log "Cleaning up..."
    deactivate || true
    rm -rf "${PROJECT_ROOT}/.pytest_cache"
    find "${PROJECT_ROOT}" -type d -name "__pycache__" -exec rm -rf {} +
}

main() {
    log "Starting setup process..."
    
    check_prerequisites
    setup_python_environment
    setup_kubernetes
    setup_monitoring
    setup_vault
    deploy_applications
    verify_deployment
    cleanup
    
    log "Setup completed successfully"
}

trap cleanup EXIT
main "$@"
