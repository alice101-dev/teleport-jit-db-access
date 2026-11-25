# Trusted devices: machines allowed to prove themselves to Teleport, required
# by the database roles (access.tf). Listing a machine here is step one; step
# two, `tsh device enroll --current-device`, runs on the machine itself.
resource "teleport_trusted_device" "inventory" {
  for_each = var.trusted_devices

  version = "v1"

  spec = {
    asset_tag = each.value.asset_tag
    os_type   = each.value.os_type
  }
}
