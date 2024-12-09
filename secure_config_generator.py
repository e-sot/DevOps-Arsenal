# secure_config_generator.py

import os
import yaml
import logging
from typing import Dict, Any, Optional
from pathlib import Path

class SecureConfigGenerator:
    """
    Generates secure configuration files by fetching secrets from Vault
    and applying them to templates
    """

    def __init__(self, secret_manager, config_path: str = "config"):
        """
        Initialize the configuration generator
        
        Args:
            secret_manager: Instance of SecureSecretManager
            config_path: Base path for configuration files
        """
        self.logger = logging.getLogger(__name__)
        self.secret_manager = secret_manager
        self.config_path = Path(config_path)
        self.config_path.mkdir(exist_ok=True)

    def generate_env_file(self, template_path: str, output_path: str) -> None:
        """
        Generate .env file from template, replacing placeholders with secure values
        
        Args:
            template_path: Path to .env template
            output_path: Path where to save generated .env file
        """
        try:
            # Read template
            with open(template_path) as f:
                template_content = f.read()

            env_vars = {}
            
            # Process each line in template
            for line in template_content.splitlines():
                if '=' in line:
                    key, default_value = line.split('=', 1)
                    key = key.strip()
                    
                    # Generate new secret for sensitive variables
                    if any(pattern in key for pattern in ['PASSWORD', 'SECRET', 'KEY', 'TOKEN']):
                        secret_path = f"env/{key.lower()}"
                        existing_secret = self.secret_manager.get_secret(secret_path)
                        
                        if existing_secret:
                            env_vars[key] = existing_secret
                        else:
                            new_secret = self.secret_manager.generate_secure_password()
                            self.secret_manager.store_secret(secret_path, {'value': new_secret})
                            env_vars[key] = new_secret
                    else:
                        env_vars[key] = default_value.strip()

            # Write generated .env file
            with open(output_path, 'w') as f:
                for key, value in env_vars.items():
                    f.write(f'{key}={value}\n')

            self.logger.info(f"Successfully generated .env file at {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to generate .env file: {str(e)}")
            raise

    def generate_ansible_vars(self, template_path: str, output_path: str) -> None:
        """
        Generate Ansible vault variables file with secure values
        
        Args:
            template_path: Path to template vars file
            output_path: Path where to save generated vars file
        """
        try:
            # Read template
            with open(template_path) as f:
                template_vars = yaml.safe_load(f)

            secure_vars = {}
            
            # Process each variable
            for key, value in template_vars.items():
                if isinstance(value, dict):
                    secure_vars[key] = self._process_nested_vars(value, f"ansible/{key}")
                else:
                    secret_path = f"ansible/{key}"
                    if any(pattern in key for pattern in ['password', 'secret', 'key', 'token']):
                        existing_secret = self.secret_manager.get_secret(secret_path)
                        if existing_secret:
                            secure_vars[key] = existing_secret
                        else:
                            new_secret = self.secret_manager.generate_secure_password()
                            self.secret_manager.store_secret(secret_path, {'value': new_secret})
                            secure_vars[key] = new_secret
                    else:
                        secure_vars[key] = value

            # Write generated vars file
            with open(output_path, 'w') as f:
                yaml.dump(secure_vars, f, default_flow_style=False)

            self.logger.info(f"Successfully generated Ansible vars file at {output_path}")
            
        except Exception as e:
            self.logger.error(f"Failed to generate Ansible vars file: {str(e)}")
            raise

    def _process_nested_vars(self, vars_dict: Dict[str, Any], prefix: str) -> Dict[str, Any]:
        """
        Process nested variables recursively
        
        Args:
            vars_dict: Dictionary of variables to process
            prefix: Prefix for the secret path
            
        Returns:
            Dictionary with processed variables
        """
        result = {}
        for key, value in vars_dict.items():
            if isinstance(value, dict):
                result[key] = self._process_nested_vars(value, f"{prefix}/{key}")
            else:
                secret_path = f"{prefix}/{key}"
                if any(pattern in key for pattern in ['password', 'secret', 'key', 'token']):
                    existing_secret = self.secret_manager.get_secret(secret_path)
                    if existing_secret:
                        result[key] = existing_secret
                    else:
                        new_secret = self.secret_manager.generate_secure_password()
                        self.secret_manager.store_secret(secret_path, {'value': new_secret})
                        result[key] = new_secret
                else:
                    result[key] = value
        return result
