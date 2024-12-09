# ETO GROUP Project - DevOps Infrastructure

## Project Architecture

eto-project/
├── docker/
│   ├── eto-webapp/
│   │   ├── Dockerfile
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── templates/
│   │       └── index.html
│   ├── odoo/
│   │   └── docker-compose.yml
│   └── pgadmin/
│       ├── docker-compose.yml
│       └── servers.json
├── k8s/
│   ├── namespace.yml
│   ├── secrets.yml
│   ├── configmaps.yml
│   ├── odoo/
│   │   ├── deployment.yml
│   │   ├── service.yml
│   │   └── pvc.yml
│   └── pgadmin/
│       ├── deployment.yml
│       ├── service.yml
│       └── pvc.yml
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml
│   ├── playbook.yml
│   └── roles/
│       ├── odoo/
│       │   ├── tasks/
│       │   ├── templates/
│       │   └── vars/
│       └── pgadmin/
│           ├── tasks/
│           ├── templates/
│           └── vars/
├── Jenkinsfile
└── releases.txt

## Overview
Enterprise-grade infrastructure project implementing a secure and scalable architecture using Docker, Kubernetes, Ansible, and Jenkins for ETO Group's internal applications.

## Features

### Core Components
- Web Application Portal (Flask)
- Odoo ERP Integration
- PgAdmin Database Management
- Vault Secret Management
- Prometheus & Grafana Monitoring

### Security Features
- SSL/TLS encryption with Let's Encrypt
- HashiCorp Vault integration
- Secure secrets management
- Network isolation
- Regular security updates

### Monitoring & Observability
- Prometheus metrics collection
- Grafana dashboards
- Health checks
- Audit logging
- Performance monitoring

### CI/CD Pipeline
- Automated testing
- Docker image building
- Kubernetes deployment
- Rolling updates
- Automated rollbacks

## Prerequisites
- Docker 20.10+
- Kubernetes 1.21+
- Ansible 2.9+
- Jenkins 2.3+
- Python 3.6+

## Installation

1. Clone the repository:
```bash
git clone https://github.com/etogroup/infrastructure.git
```
    Configure environment:

bash
cp .env.example .env
# Edit .env with your configuration

    Deploy infrastructure:

bash
make deploy-all

Configuration

    Update group_vars/all.yml for global configuration
    Modify k8s/configmaps.yml for application settings
    Edit k8s/secrets.yml for sensitive data

Usage
Access the following services:

    Web Portal: https://portal.eto.local
    Odoo ERP: https://odoo.eto.local
    PgAdmin: https://pgadmin.eto.local
    Vault: https://vault.eto.local
    Grafana: https://grafana.eto.local

Testing

bash
# Run unit tests
python -m pytest tests/unit

# Run integration tests
python -m pytest tests/integration

# Run security tests
make security-scan

Maintenance

    Regular backups configured
    Automated security updates
    Performance monitoring
    Log rotation

Security

    All passwords must be changed from defaults
    Access restricted by IP
    Regular security audits required
    SSL/TLS mandatory for all services



