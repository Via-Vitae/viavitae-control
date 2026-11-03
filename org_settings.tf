# #############################################################################
# Organization settings — declarative baseline of org-level policy.
#
# NON-DESTRUCTIVE: values below default to the CURRENT live settings of the
# Via-Vitae org (verified 2026-09-24). Tightening any of these is a deliberate,
# PR-reviewed change. Fields marked [PAID] can only be set to true on the
# required plan tier; leaving them false on a Free plan avoids apply-time errors.
# #############################################################################

resource "github_organization_settings" "this" {
  # billing_email is a REQUIRED argument (org metadata, not a secret). It is supplied at
  # plan time and then IGNORED (see lifecycle below), because the value that satisfies the
  # provider is not the value that must reach GitHub: audit.yml sets
  # TF_VAR_billing_email=ci-placeholder-not-applied and an operator running a local plan
  # passes a similar stand-in. Measured 2026-11-01: with only [email, name] ignored, a plan
  # built on a placeholder proposed
  # `billing_email: "<live address>" -> "plan-only-not-applied"`, i.e. the next apply would
  # silently redirect the org's billing correspondence. Keeping the argument required by the
  # provider but ignoring its drift is the fix that does not weaken anything else.
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

  # The org profile `email` and `name` are set out-of-band (P1-7 / gh api) and are
  # intentionally NOT declared here. Without ignore_changes a full plan proposes to
  # null them, which on apply would wipe the public contact address and display name.
  # `billing_email` joins them for the mirror reason: it IS declared (the provider demands
  # it), but its declared value is a plan-time placeholder, so drifting it toward the
  # placeholder must be refused rather than applied.
  lifecycle {
    ignore_changes = [email, name, billing_email]
  }
}
