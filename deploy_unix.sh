#!/bin/bash
set -euo pipefail

# Installation de Vault sur Unix
VAULT_VERSION="1.12.0"
VAULT_ZIP="vault_${VAULT_VERSION}_linux_amd64.zip"
VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/${VAULT_ZIP}"

# Téléchargement et installation de Vault
curl -O $VAULT_URL
unzip $VAULT_ZIP -d /usr/local/bin/
chmod +x /usr/local/bin/vault

# Exécution du script principal
python3 vault_setup.py
