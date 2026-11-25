locals {
  # One Teleport role per access level. Each maps to a Postgres user whose
  # grants (postgres/init) decide what it can do.
  db_access_levels = {
    read = {
      db_user     = "db_read"
      description = "Read the Cucumber PostgreSQL database"
    }
    write = {
      db_user     = "db_writer"
      description = "Read and change data in the Cucumber PostgreSQL database"
    }
  }

  db_role_names = [for role in teleport_role.cucumber_db : role.metadata.name]
}

resource "teleport_role" "cucumber_db" {
  for_each = local.db_access_levels

  version = "v7"

  metadata = {
    name        = "cucumber-db-${each.key}"
    description = each.value.description
  }

  spec = {
    options = {
      # Only from an enrolled device (devices.tf).
      device_trust_mode = "required"

      # 1 = SESSION: MFA on every database connection. Needs WebAuthn, such as
      # Touch ID; authenticator app codes are not accepted.
      require_session_mfa = 1
    }

    allow = {
      db_labels = { for key, value in local.db_labels : key => [value] }
      db_names  = ["cucumber"]
      db_users  = [each.value.db_user]
    }
  }
}

# Standing access goes through an access list, so Terraform never has to own a
# human account.
resource "teleport_access_list" "cucumber_db_access" {
  header = {
    version = "v1"
    metadata = {
      name = "cucumber-db-access"
    }
  }

  spec = {
    # "static": managed as code, no periodic review in the UI.
    type        = "static"
    title       = "Cucumber database access"
    description = "Members can read and change the Cucumber PostgreSQL database without asking"

    owners = [
      {
        name        = var.admin_user
        description = "Owner"
      }
    ]

    grants = {
      roles = local.db_role_names
    }
  }
}

resource "teleport_access_list_member" "cucumber_db_access" {
  for_each = toset(local.db_access_users)

  header = {
    version = "v1"
    metadata = {
      name = each.value
    }
  }

  spec = {
    access_list     = teleport_access_list.cucumber_db_access.id
    membership_kind = 1 # MEMBERSHIP_KIND_USER
  }
}
