# Join token for the database agent in docker-compose.yml, used only on its
# first start. No expiry, so plans stay clean. To rotate:
#   terraform apply -replace=teleport_provision_token.db_agent
resource "teleport_provision_token" "db_agent" {
  version = "v2"

  metadata = {
    # No name: the provider generates a random one, which is the secret.
    description = "Join token for the laptop database agent"
  }

  spec = {
    roles       = ["Db"]
    join_method = "token"
  }
}

resource "local_sensitive_file" "agent_join_token" {
  filename        = "${local.repo_root}/teleport/join-token"
  content         = teleport_provision_token.db_agent.metadata.name
  file_permission = "0600"
}

resource "local_file" "agent_config" {
  filename = "${local.repo_root}/teleport/teleport.yaml"
  content = templatefile("${local.repo_root}/teleport/teleport.yaml.tftpl", {
    proxy_host = var.teleport_proxy_host
  })
  file_permission = "0644"
}
