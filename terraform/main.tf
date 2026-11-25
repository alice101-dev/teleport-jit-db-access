terraform {
  required_version = ">= 1.0.0"

  required_providers {
    teleport = {
      source  = "terraform.releases.teleport.dev/gravitational/teleport"
      version = "~> 18.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# Credentials come from the environment: eval "$(tctl terraform env)"
provider "teleport" {
  addr = "${var.teleport_proxy_host}:443"
}

locals {
  # Standing database access, and who reviews requests for temporary access.
  db_access_users = [var.admin_user]
  db_reviewers    = [var.admin_user]

  # Local accounts with no standing access: they request it when needed.
  jit_users = ["cucumber-dev", "alice"]

  # Hosted Slack integration (enrolled in the web UI) and its channel.
  slack_integration = "slack-default"
  slack_channel     = "#jit-access"

  # Shared by the database, its roles, and the agent (teleport/teleport.yaml.tftpl).
  db_labels = {
    env = "cucumber"
  }

  # Compose service name of the database, and the name on its certificate.
  postgres_host = "postgres"

  repo_root = "${path.module}/.."
}
