# Slack alerts: Teleport audit log -> event handler -> Fluentd -> Slack webhook.
# The containers are in docker-compose.yml; the alert rules are in fluentd/.

resource "local_sensitive_file" "slack_alert_webhook_url" {
  filename        = "${local.repo_root}/fluentd/slack-webhook-url"
  content         = "${trimspace(var.slack_alert_webhook_url)}\n"
  file_permission = "0600"
}

# --- Identity the event handler uses to read the audit log -------------------

resource "teleport_role" "audit_export" {
  version = "v7"

  metadata = {
    name        = "cucumber-audit-export"
    description = "Read audit events for export to the alert pipeline"
  }

  spec = {
    allow = {
      rules = [
        {
          resources = ["event", "session"]
          verbs     = ["list", "read"]
        }
      ]
    }
  }
}

resource "teleport_bot" "audit_export" {
  metadata = {
    name = "cucumber-audit-export"
  }

  spec = {
    roles = [teleport_role.audit_export.metadata.name]
  }
}

resource "random_password" "audit_export_registration" {
  length  = 48
  special = false
}

# The bot registers once with the secret, then uses a keypair kept in the
# tbot-data volume. If that volume is lost, re-register with:
#   terraform apply -replace=teleport_provision_token.audit_export_bot
resource "teleport_provision_token" "audit_export_bot" {
  version = "v2"

  metadata = {
    name        = "cucumber-audit-export-bot"
    description = "Join token for the audit event handler bot"
  }

  spec = {
    roles       = ["Bot"]
    bot_name    = teleport_bot.audit_export.metadata.name
    join_method = "bound_keypair"

    bound_keypair = {
      onboarding = {
        registration_secret = random_password.audit_export_registration.result
      }

      # A laptop sleeps, so the bot's certificates expire and it has to rejoin
      # with its keypair. "relaxed" allows that without a limit.
      recovery = {
        mode  = "relaxed"
        limit = 1
      }
    }
  }
}

resource "local_sensitive_file" "audit_export_registration_secret" {
  filename        = "${local.repo_root}/teleport/tbot-registration-secret"
  content         = random_password.audit_export_registration.result
  file_permission = "0600"
}

resource "local_file" "tbot_config" {
  filename = "${local.repo_root}/teleport/tbot.yaml"
  content = templatefile("${local.repo_root}/teleport/tbot.yaml.tftpl", {
    proxy_host = var.teleport_proxy_host
    bot_token  = teleport_provision_token.audit_export_bot.metadata.name
  })
  file_permission = "0644"
}

resource "local_file" "event_handler_config" {
  filename = "${local.repo_root}/teleport/event-handler.toml"
  content = templatefile("${local.repo_root}/teleport/event-handler.toml.tftpl", {
    proxy_host = var.teleport_proxy_host
  })
  file_permission = "0644"
}

# --- Mutual TLS between the event handler and Fluentd ------------------------

resource "tls_private_key" "fluentd_ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_self_signed_cert" "fluentd_ca" {
  private_key_pem       = tls_private_key.fluentd_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses          = ["cert_signing", "crl_signing"]

  subject {
    common_name = "cucumber fluentd CA"
  }
}

resource "tls_private_key" "fluentd_server" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "fluentd_server" {
  private_key_pem = tls_private_key.fluentd_server.private_key_pem
  # Compose service name the event handler connects to.
  dns_names = ["fluentd"]

  subject {
    common_name = "fluentd"
  }
}

resource "tls_locally_signed_cert" "fluentd_server" {
  cert_request_pem      = tls_cert_request.fluentd_server.cert_request_pem
  ca_private_key_pem    = tls_private_key.fluentd_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.fluentd_ca.cert_pem
  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}

resource "tls_private_key" "fluentd_client" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "tls_cert_request" "fluentd_client" {
  private_key_pem = tls_private_key.fluentd_client.private_key_pem

  subject {
    common_name = "teleport-event-handler"
  }
}

resource "tls_locally_signed_cert" "fluentd_client" {
  cert_request_pem      = tls_cert_request.fluentd_client.cert_request_pem
  ca_private_key_pem    = tls_private_key.fluentd_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.fluentd_ca.cert_pem
  validity_period_hours = 8760 # 1 year
  early_renewal_hours   = 720
  allowed_uses          = ["digital_signature", "key_encipherment", "client_auth"]
}

resource "local_file" "fluentd_ca_crt" {
  filename        = "${local.repo_root}/fluentd/certs/ca.crt"
  content         = tls_self_signed_cert.fluentd_ca.cert_pem
  file_permission = "0644"
}

resource "local_file" "fluentd_server_crt" {
  filename        = "${local.repo_root}/fluentd/certs/server.crt"
  content         = tls_locally_signed_cert.fluentd_server.cert_pem
  file_permission = "0644"
}

resource "local_sensitive_file" "fluentd_server_key" {
  filename        = "${local.repo_root}/fluentd/certs/server.key"
  content         = tls_private_key.fluentd_server.private_key_pem
  file_permission = "0600"
}

resource "local_file" "fluentd_client_crt" {
  filename        = "${local.repo_root}/fluentd/certs/client.crt"
  content         = tls_locally_signed_cert.fluentd_client.cert_pem
  file_permission = "0644"
}

resource "local_sensitive_file" "fluentd_client_key" {
  filename        = "${local.repo_root}/fluentd/certs/client.key"
  content         = tls_private_key.fluentd_client.private_key_pem
  file_permission = "0600"
}
