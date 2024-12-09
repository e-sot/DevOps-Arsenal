# Installation de Vault sur Windows
$vaultVersion = "1.12.0"
$vaultZip = "vault_${vaultVersion}_windows_amd64.zip"
$vaultUrl = "https://releases.hashicorp.com/vault/${vaultVersion}/${vaultZip}"

# Téléchargement et installation de Vault
Invoke-WebRequest -Uri $vaultUrl -OutFile $vaultZip
Expand-Archive -Path $vaultZip -DestinationPath C:\vault
$env:Path += ";C:\vault"

# Exécution du script principal
python vault_setup.py
