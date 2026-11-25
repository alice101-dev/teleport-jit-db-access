# Just-in-time access: requesters have no database access of their own. They
# request a database role, a reviewer approves, and it is granted for a limited time.

resource "teleport_role" "cucumber_db_requester" {
  version = "v7"

  metadata = {
    name        = "cucumber-db-requester"
    description = "Request temporary access to the Cucumber PostgreSQL database"
  }

  spec = {
    allow = {
      request = {
        roles        = local.db_role_names
        max_duration = "1h"

        reason = {
          mode = "required"
        }

        # The Slack integration also messages reviewers whose name is an email
        # address known to Slack.
        suggested_reviewers = local.db_reviewers
      }
    }
  }
}

resource "teleport_role" "cucumber_db_reviewer" {
  version = "v7"

  metadata = {
    name        = "cucumber-db-reviewer"
    description = "Approve or deny requests for Cucumber database access"
  }

  spec = {
    allow = {
      review_requests = {
        roles = local.db_role_names
      }
    }
  }
}

resource "teleport_access_list" "cucumber_db_reviewers" {
  header = {
    version = "v1"
    metadata = {
      name = "cucumber-db-reviewers"
    }
  }

  spec = {
    type        = "static"
    title       = "Cucumber database reviewers"
    description = "Members review requests for temporary access to the Cucumber PostgreSQL database"

    owners = [
      {
        name        = var.admin_user
        description = "Owner"
      }
    ]

    grants = {
      roles = [teleport_role.cucumber_db_reviewer.metadata.name]
    }
  }
}

resource "teleport_access_list_member" "cucumber_db_reviewers" {
  for_each = toset(local.db_reviewers)

  header = {
    version = "v1"
    metadata = {
      name = each.value
    }
  }

  spec = {
    access_list     = teleport_access_list.cucumber_db_reviewers.id
    membership_kind = 1 # MEMBERSHIP_KIND_USER
  }
}

# Terraform cannot set credentials for a local user: run `tctl users reset <name>`
# afterwards to get a link for choosing a password and MFA device.
resource "teleport_user" "jit_users" {
  for_each = toset(local.jit_users)

  version = "v2"

  metadata = {
    name = each.value
  }

  spec = {
    roles = [teleport_role.cucumber_db_requester.metadata.name]
  }
}
