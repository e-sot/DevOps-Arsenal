# ETO WebApp - Enterprise Management Platform
## Project Structure

```text
ci-cd-k8s-docker-ansible-webapp/
├── ansible/          # Infrastructure automation
├── docker/          # Container configurations
├── k8s/             # Kubernetes manifests
├── monitoring/      # Monitoring configuration
├── security/        # Security and TLS
└── tests/           # Unit and integration tests
```

## Quick Start

### Clone and setup:

```bash
git clone git@github.com:your-org/eto-webapp.git
cd eto-webapp
cp .env.example .env
```
## Start Vault:

```bash
cd docker/vault/config
docker-compose up -d
```
### Deploy Odoo:

```bash
cd docker/odoo
docker-compose up -d
```
### Deploy PgAdmin:

```bash
cd docker/pgadmin
docker-compose up -d
```
### Deploy Monitoring:

```bash
cd docker/monitoring
docker-compose up -d grafana prometheus
```
## Access URLs
| Service     | URL                     |
|------------|-------------------------|
| Odoo       | http://localhost:8069   |
| PgAdmin    | http://localhost:5050   |
| Grafana    | http://localhost:3000   |
| Prometheus | http://localhost:9090   |
| Vault      | http://localhost:8200   |

```bash
python -m venv venv
source venv/bin/activate
pip install -r docker/eto-webapp/requirements.txt
```

## Run tests:

```bash
python -m pytest tests/
```

## Maintenance
### Backup:

```bash
./scripts/backup.sh
```

### Restore:

```bash
./scripts/restore.sh <backup-file>
```
## Monitoring
The monitoring stack includes:

    Application metrics dashboard
    Database performance monitoring
    Infrastructure overview
    Real-time alerts via Prometheus
