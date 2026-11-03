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

  # The org profile `email` and `name` are set out-of-band (P1-7 / gh api) and are
  # intentionally NOT declared here. Without ignore_changes a full plan proposes to
  # null them, which on apply would wipe the public contact address and display name.
  #
  # `billing_email` joins that list for the same reason with a different trigger. It is
  # a REQUIRED provider argument with deliberately no default (GDPR Art. 5(1)(c)), so
  # every caller has to pass something: `audit.yml` passes `ci-placeholder-not-applied`
  # and a local plan needs an explicit stand-in. Live `billing_email` is non-null
  # (measured 2026-11-03: `GET /orgs/Via-Vitae` returns the key with a value) and the
  # address it holds is the published `viavitae.github` plus-address listed in
  # `README.md`. So an apply fed any placeholder would silently overwrite the org's
  # real billing contact with a string that cannot receive mail — GitHub billing and
  # security notifications included. No error is raised; the plan looks surgical.
  # Trade-off, stated plainly: Terraform no longer manages this attribute, so
  # out-of-band drift on it is INVISIBLE to a plan. Set it deliberately and verify with
  # `gh api orgs/Via-Vitae --jq .billing_email`; the value is a published contact
  # channel, not a secret, so reading it live is free and proves it is not null.
  lifecycle {
    ignore_changes = [email, name, billing_email]
  }
}
