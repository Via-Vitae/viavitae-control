# Instantiates one repo module per entry in the inventory (Approach A).
# for_each over local.repos means adding/removing a repo is a one-line,
# PR-reviewable change with full drift detection.

module "repo" {
  source   = "./modules/repo"
  for_each = local.repos

  owner       = var.github_owner
  name        = each.value.name
  description = each.value.description
  visibility  = each.value.visibility

  default_branch   = each.value.default_branch
  auto_init        = each.value.auto_init
  license_template = each.value.license

  # Files (CODEOWNERS / security.yml / README / LICENSE) are only written when
  # manage_files = true — false for all existing repos (non-destructive baseline).
  manage_files     = each.value.manage_files
  codeowners_teams = each.value.codeowners

  # Control gating — resolved against the org plan tier so paid-only controls
  # never attempt an operation the current plan cannot satisfy.
  enable_branch_protection        = each.value.enable_branch_protection
  apply_private_branch_protection = local.effective_controls.branch_protection_private
  required_approving_review_count = var.branch_required_approving_review_count
  require_code_owner_reviews      = var.branch_require_code_owner_reviews
  require_last_push_approval      = var.branch_require_last_push_approval
  enforce_admins                  = var.branch_enforce_admins
  required_status_checks_strict   = var.branch_required_status_checks_strict
  # Secret scanning / push protection are free for PUBLIC repos. On PRIVATE repos
  # they require Advanced Security (Enterprise), so they are gated by visibility
  # to avoid an apply-time API error on the Free plan.
  enable_secret_scanning             = each.value.visibility == "public" ? local.effective_controls.secret_scanning_public : local.effective_controls.advanced_security_private
  enable_push_protection             = each.value.visibility == "public" ? local.effective_controls.push_protection_public : local.effective_controls.advanced_security_private
  enable_advanced_security           = local.effective_controls.advanced_security_private
  enable_dependabot_alerts           = local.effective_controls.dependabot_alerts
  enable_dependabot_security_updates = local.effective_controls.dependabot_security_updates
}
