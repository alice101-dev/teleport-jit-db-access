variable "teleport_proxy_host" {
  description = "Teleport proxy host, without scheme or port."
  type        = string
}

variable "admin_user" {
  description = "Teleport user who owns the access lists, has standing database access, and reviews requests."
  type        = string
}

variable "trusted_devices" {
  description = "Machines allowed to reach the database, keyed by a label. asset_tag is the serial number printed by `tsh device asset-tag`."
  type = map(object({
    asset_tag = string
    os_type   = string
  }))
}

variable "slack_alert_webhook_url" {
  description = "Slack incoming webhook URL for the alert channel."
  type        = string
  sensitive   = true
}
