# Routes requests for Cucumber database access to Slack. The hosted Slack
# integration is enrolled in the web UI (it needs an OAuth approval); until
# then this rule has no effect.
resource "teleport_access_monitoring_rule" "cucumber_db_requests_to_slack" {
  version = "v1"

  metadata = {
    name        = "cucumber-db-requests-to-slack"
    description = "Notify reviewers in Slack about requests for Cucumber database access"
  }

  spec = {
    subjects  = ["access_request"]
    condition = "access_request.spec.roles.contains_any(set(${join(", ", formatlist("\"%s\"", local.db_role_names))}))"

    notification = {
      name = local.slack_integration

      # The channel needs the Teleport Cloud app invited; email addresses get a DM.
      recipients = concat([local.slack_channel], local.db_reviewers)
    }
  }
}
