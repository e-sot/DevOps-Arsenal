storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  tls_disable     = 0
  tls_cert_file   = "/vault/tls/vault.crt"
  tls_key_file    = "/vault/tls/vault.key"
  tls_min_version = "tls12"
}

api_addr = "https://vault.eto.local:8200"
cluster_addr = "https://vault.eto.local:8201"

ui = true

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}

seal "shamir" {
}

log_level = "INFO"

default_lease_ttl = "168h"  # 7 days
max_lease_ttl = "720h"      # 30 days
