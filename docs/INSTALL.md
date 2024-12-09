# ETO Group Applications - Installation Guide

## System Requirements

### Hardware Requirements
- CPU: 4 cores
- RAM: 16 GB
- Storage: 100 GB SSD
- Network: 100 Mbps

### Software Prerequisites
- Docker Engine 24.0.0+
- Docker Compose 2.20.0+
- Kubernetes 1.28+
- Helm 3.12+
- Python 3.11+
- Ansible 2.15+

### Supported Operating Systems
- Ubuntu Server 22.04 LTS
- Debian 11 Bullseye
- Red Hat Enterprise Linux 9
- Rocky Linux 9

## Installation Steps

### 1. System Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    python3-pip \
    git

2. Environment Setup

bash
# Clone repository
git clone https://github.com/your-org/eto-group-apps.git
cd eto-group-apps

# Create and configure environment file
cp .env.example .env

Edit .env file with your local configuration:

text
# Application
APP_NAME=eto-webapp
APP_VERSION=1.0.0
ENVIRONMENT=development
DEBUG=true

# Local Development URLs
ODOO_URL=http://localhost:8069
PGADMIN_URL=http://localhost:5050
VAULT_URL=http://localhost:8200

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USER=odoo
DB_PASSWORD=changeme

# Development SSL
SSL_CERT_PATH=./security/tls/dev
SSL_KEY_PATH=./security/tls/dev

3. Docker Setup

bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

4. Development Certificates

bash
# Create certificates directory
mkdir -p security/tls/dev

# Generate self-signed certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout security/tls/dev/dev.key \
    -out security/tls/dev/dev.crt \
    -subj "/CN=localhost"

5. Local Development Deployment

bash
# Build and start services
docker-compose -f docker-compose.dev.yml up -d

# Verify services
docker-compose ps

6. Application Setup
Database Initialization

bash
# Create database schema
docker-compose exec db psql -U $DB_USER -d $DB_NAME -f init/schema.sql

# Import initial data (if needed)
docker-compose exec db psql -U $DB_USER -d $DB_NAME -f init/data.sql

Odoo Configuration

    Access Odoo at http://localhost:8069
    Create database with credentials from .env
    Install required modules

PgAdmin Setup

    Access PgAdmin at http://localhost:5050
    Login with credentials from .env
    Add local database server

Development Tools
Running Tests

bash
# Unit tests
python -m pytest tests/unit

# Integration tests
python -m pytest tests/integration

Code Quality

bash
# Run linters
flake8 docker/eto-webapp
black docker/eto-webapp
mypy docker/eto-webapp

Troubleshooting
Common Issues

    Port Conflicts

bash
# Check ports in use
sudo netstat -tulpn | grep -E '8069|5050|8200'

# Change ports in .env if needed

    Permission Issues

bash
# Fix directory permissions
sudo chown -R $USER:$USER .

    Database Connection Issues

bash
# Verify database connection
docker-compose exec db pg_isready -U $DB_USER -d $DB_NAME

Support

    Source Code: ./docs/CONTRIBUTING.md
    Security Issues: ./docs/SECURITY.md
    Project Documentation: ./docs/

Local Development URLs
All services are accessible locally:

    Application: http://localhost:8080
    Odoo: http://localhost:8069
    PgAdmin: http://localhost:5050
    Vault: http://localhost:8200
