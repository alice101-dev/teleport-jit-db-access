# --- Server certificate -----------------------------------------------------
# Signed by a private CA that Teleport trusts through
# teleport_database.spec.tls.ca_cert below.

resource "tls_private_key" "postgres_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "postgres_ca" {
  private_key_pem       = tls_private_key.postgres_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "cucumber postgres CA"
  }
}

resource "tls_private_key" "postgres_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "postgres_server" {
  private_key_pem = tls_private_key.postgres_server.private_key_pem
  dns_names       = [local.postgres_host]

  subject {
    common_name = local.postgres_host
  }
}

resource "tls_locally_signed_cert" "postgres_server" {
  cert_request_pem      = tls_cert_request.postgres_server.cert_request_pem
  ca_private_key_pem    = tls_private_key.postgres_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.postgres_ca.cert_pem
  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720  # replace 30 days before expiry
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "local_file" "postgres_server_crt" {
  filename        = "${local.repo_root}/postgres/certs/server.crt"
  content         = tls_locally_signed_cert.postgres_server.cert_pem
  file_permission = "0644"
}

resource "local_sensitive_file" "postgres_server_key" {
  filename        = "${local.repo_root}/postgres/certs/server.key"
  content         = tls_private_key.postgres_server.private_key_pem
  file_permission = "0600"
}

# --- Client certificates ----------------------------------------------------
# Postgres accepts only client certificates signed by Teleport's database
# client CA (postgres/pg_hba.conf). If the cluster rotates it, re-apply and
# restart Postgres.

data "http" "teleport_db_client_ca" {
  url = "https://${var.teleport_proxy_host}/webapi/auth/export?type=db-client"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && startswith(self.response_body, "-----BEGIN CERTIFICATE-----")
      error_message = "Could not fetch the Teleport database client CA."
    }
  }
}

resource "local_file" "teleport_db_client_ca" {
  filename        = "${local.repo_root}/postgres/certs/teleport-client-ca.crt"
  content         = data.http.teleport_db_client_ca.response_body
  file_permission = "0644"
}

# --- Superuser password -----------------------------------------------------
# Required by the postgres image on first start. Nothing can log in with it:
# pg_hba.conf allows only certificate auth over the network.

resource "random_password" "postgres_superuser" {
  length  = 32
  special = false
}

resource "local_sensitive_file" "compose_env" {
  filename        = "${local.repo_root}/.env"
  content         = "POSTGRES_PASSWORD=${random_password.postgres_superuser.result}\n"
  file_permission = "0600"
}

# --- Registration in Teleport -----------------------------------------------

resource "teleport_database" "cucumber_postgres" {
  version = "v3"

  metadata = {
    name        = "cucumber-postgres"
    description = "PostgreSQL in Docker on the laptop"
    # The provider requires the origin label on databases it registers.
    labels = merge(local.db_labels, { "teleport.dev/origin" = "dynamic" })
  }

  spec = {
    protocol = "postgres"
    uri      = "${local.postgres_host}:5432"

    tls = {
      ca_cert = tls_self_signed_cert.postgres_ca.cert_pem
    }
  }
}
