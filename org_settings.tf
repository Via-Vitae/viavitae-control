# #############################################################################
# Organization settings — declarative baseline of org-level policy.
#
# NON-DESTRUCTIVE: values below default to the CURRENT live settings of the
# Via-Vitae org (verified 2026-09-24). Tightening any of these is a deliberate,
# PR-reviewed change. Fields marked [PAID] can only be set to true on the
# required plan tier; leaving them false on a Free plan avoids apply-time errors.
# #############################################################################

resource "github_organization_settings" "this" {
  # billing_email is a REQUIRED argument (org metadata, not a secret).
  billing_email = var.billing_email

  # --- Member permissions (current live Via-Vitae values preserved) ----------
  default_repository_permission          = var.default_repository_permission
  members_can_create_repositories        = var.members_can_create_repositories
  members_can_create_public_repositories = var.members_can_create_public_repositories
  # Current live values (verified 2026-09-24):
  members_can_create_private_repositories  = true
  members_can_create_internal_repositories = false

  members_can_fork_private_repositories = false
  web_commit_signoff_required           = false

  # --- Security defaults for NEW repositories -------------------------------
  # [PAID/Enterprise] secret scanning + push protection defaults for new repos.
  # Kept false to match the current Free-plan org and avoid apply errors.
  # On Enterprise upgrade, drive these from local.effective_controls.
  secret_scanning_enabled_for_new_repositories                 = false
  secret_scanning_push_protection_enabled_for_new_repositories = false
  advanced_security_enabled_for_new_repositories               = false

  # Dependabot / dependency graph defaults for new repos (free tier capable):
  dependabot_alerts_enabled_for_new_repositories           = var.enable_dependabot_alerts
  dependabot_security_updates_enabled_for_new_repositories = var.enable_dependabot_security_updates
  dependency_graph_enabled_for_new_repositories            = true
}
