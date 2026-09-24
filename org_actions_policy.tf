# #############################################################################
# GitHub Actions organization policy — restricts which actions may run org-wide.
#
# Supply-chain control (SOC2 CC7 / ISO 27001 A.15): an allow-list of actions
# prevents arbitrary third-party workflow code from exfiltrating secrets.
#
# Gated by var.actions_allowed_mode. When "all", no restriction resource is
# created (matches today's unsafe default and is reported as a gap).
# #############################################################################

resource "github_actions_organization_permissions" "this" {
  count = var.actions_allowed_mode != "all" ? 1 : 0

  enabled_repositories = "all"
  allowed_actions      = var.actions_allowed_mode # "selected" | "disabled"

  # Supply-chain hardening: require actions to be pinned to a full commit SHA.
  # Off by default because the current allow-list uses tag patterns (e.g. @v4);
  # enable once actions_allowed_patterns are pinned to SHAs.
  sha_pinning_required = var.actions_sha_pinning_required

  # Only valid when allowed_actions = "selected".
  dynamic "allowed_actions_config" {
    for_each = var.actions_allowed_mode == "selected" ? [1] : []

    content {
      github_owned_allowed = true
      verified_allowed     = true
      patterns_allowed     = var.actions_allowed_patterns
    }
  }
}
