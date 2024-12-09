# deploy_secure.sh

#!/bin/bash
set -euo pipefail

# Configuration variables
VAULT_ADDR="https://vault.eto.local:8200"
VAULT_TOKEN_FILE="/root/.vault-token"
CONFIG_PATH="/opt/config"
ENVIRONMENT="production"

# Logging setup
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" >&2
}

# Verify prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v vault >/dev/null 2>&1 || { 
        log_error "HashiCorp Vault is required but not installed"
        exit 1
    }
    
    command -v ansible >/dev/null 2>&1 || {
        log_error "Ansible is required but not installed"
        exit 1
    }
    
    if [ ! -f "$VAULT_TOKEN_FILE" ]; then
        log_error "Vault token not found at $VAULT_TOKEN_FILE"
        exit 1
    }
}

# Initialize Vault connection
init_vault() {
    log_info "Initializing Vault connection..."
    
    export VAULT_ADDR="$VAULT_ADDR"
    export VAULT_TOKEN=$(cat "$VAULT_TOKEN_FILE")
    
    vault status >/dev/null 2>&1 || {
        log_error "Failed to connect to Vault"
        exit 1
    }
}

# Generate and store secrets
generate_secrets() {
    log_info "Generating and storing secrets in Vault..."
    
    # Database credentials
    vault kv put secret/database/credentials \
        db_user="$(openssl rand -base64 12)" \
        db_password="$(openssl rand -base64 32)" \
        db_name="eto_production"
        
    # Application secrets
    vault kv put secret/application/secrets \
        app_key="$(openssl rand -base64 32)" \
        admin_token="$(openssl rand -hex 32)" \
        session_key="$(openssl rand -base64 32)"
        
    # API credentials
    vault kv put secret/api/keys \
        api_key="$(openssl rand -hex 32)" \
        api_secret="$(openssl rand -base64 64)"
}

# Generate configuration files
generate_configs() {
    log_info "Generating secure configuration files..."
    
    # Get secrets from Vault
    db_creds=$(vault kv get -format=json secret/database/credentials)
    app_secrets=$(vault kv get -format=json secret/application/secrets)
    
    # Generate .env file
    cat > "$CONFIG_PATH/.env" <<EOF
DB_HOST=localhost
DB_PORT=5432
DB_USER=$(echo $db_creds | jq -r '.data.data.db_user')
DB_PASSWORD=$(echo $db_creds | jq -r '.data.data.db_password')
DB_NAME=$(echo $db_creds | jq -r '.data.data.db_name')
APP_KEY=$(echo $app_secrets | jq -r '.data.data.app_key')
ADMIN_TOKEN=$(echo $app_secrets | jq -r '.data.data.admin_token')
EOF

    chmod 600 "$CONFIG_PATH/.env"
}

# Deploy with Ansible
deploy_application() {
    log_info "Deploying application with Ansible..."
    
    ANSIBLE_CONFIG="$CONFIG_PATH/ansible.cfg" ansible-playbook \
        -i inventory/production \
        --vault-password-file "$VAULT_TOKEN_FILE" \
        deploy.yml
}

# Main execution
main() {
    log_info "Starting secure deployment process..."
    
    check_prerequisites
    init_vault
    generate_secrets
    generate_configs
    deploy_application
    
    log_info "Deployment completed successfully"
}

# Execute main function
main "$@"
