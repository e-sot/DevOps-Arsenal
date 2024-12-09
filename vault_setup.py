#!/usr/bin/env python3
import os
import sys
import hvac
import subprocess
from pathlib import Path
from typing import Dict, Optional

class VaultSetup:
    def __init__(self):
        self.vault_addr = "http://localhost:8200"
        self.config_dir = Path("/opt/vault/config")
        self.data_dir = Path("/opt/vault/data")
        self.tls_dir = Path("/opt/vault/tls")

    def create_directories(self) -> None:
        for directory in [self.config_dir, self.data_dir, self.tls_dir]:
            directory.mkdir(parents=True, exist_ok=True)

    def get_platform_specific_commands(self) -> Dict[str, str]:
        if sys.platform == "win32":
            return {
                "vault_download": "powershell -Command \"Invoke-WebRequest -Uri 'https://releases.hashicorp.com/vault/1.12.0/vault_1.12.0_windows_amd64.zip' -OutFile 'vault.zip'\"",
                "vault_extract": "powershell -Command \"Expand-Archive -Path vault.zip -DestinationPath C:\\vault\"",
                "vault_path": "setx PATH \"%PATH%;C:\\vault\""
            }
        else:
            return {
                "vault_download": "curl -o vault.zip https://releases.hashicorp.com/vault/1.12.0/vault_1.12.0_linux_amd64.zip",
                "vault_extract": "unzip vault.zip -d /usr/local/bin/",
                "vault_path": "export PATH=$PATH:/usr/local/bin"
            }

    def setup_vault(self) -> None:
        commands = self.get_platform_specific_commands()
        for cmd in commands.values():
            subprocess.run(cmd, shell=True, check=True)

class EnvToVault:
    def __init__(self, env_file: str = '.env'):
        self.env_file = env_file
        self.vault_client = hvac.Client(url="http://localhost:8200")
        self.sections = {
            'database': {},
            'redis': {},
            'security': {},
            'monitoring': {},
            'docker': {},
            'smtp': {}
        }

    def parse_env_file(self) -> None:
        current_section = 'default'
        with open(self.env_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('# '):
                    current_section = line[2:].lower().replace(' ', '_')
                    continue
                if '=' in line:
                    key, value = line.split('=', 1)
                    if self._is_secret(key.strip()):
                        self.sections.setdefault(current_section, {})[key.strip()] = value.strip()

    def _is_secret(self, key: str) -> bool:
        sensitive_terms = ['password', 'secret', 'key', 'token', 'api', 'credential']
        return any(term in key.lower() for term in sensitive_terms)

    def migrate_to_vault(self) -> None:
        for section, secrets in self.sections.items():
            if secrets:
                self.vault_client.secrets.kv.v2.create_or_update_secret(
                    path=f'secret/eto-webapp/{section}',
                    secret=secrets
                )

def main():
    try:
        # Installation et configuration de Vault
        vault_setup = VaultSetup()
        vault_setup.create_directories()
        vault_setup.setup_vault()

        # Migration des secrets
        env_to_vault = EnvToVault()
        env_to_vault.parse_env_file()
        env_to_vault.migrate_to_vault()

        print("Migration des secrets vers Vault terminée avec succès")

    except Exception as e:
        print(f"Erreur lors de la migration: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
