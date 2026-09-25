locals {
  # A branch can only be protected once it exists. auto_init creates the default
  # branch on a new repo; otherwise the operator must signal it via
  # default_branch_exists. Without this, protection on an empty repo errors at apply.
  branch_exists = var.default_branch_exists || var.auto_init

  # Branch protection is applied when enabled AND the branch exists AND (the repo
  # is not private OR private branch protection is permitted by the org plan tier).
  # The visibility check prevents an apply-time API error for private repos on Free.
  branch_protection_enabled = var.enable_branch_protection && local.branch_exists && (
    var.visibility != "private" || var.apply_private_branch_protection
  )

  # True when protection was requested but is being deferred (branch missing or
  # plan tier insufficient). Surfaced as an output so the gap is never silent.
  branch_protection_deferred = var.enable_branch_protection && !local.branch_protection_enabled

  # The security_and_analysis block is only emitted when at least one sub-control
  # is requested; advanced_security is Enterprise-only and stays disabled otherwise.
  security_block_enabled = var.enable_secret_scanning || var.enable_push_protection || var.enable_advanced_security
}

resource "github_repository" "this" {
  name        = var.name
  description = var.description
  visibility  = var.visibility

  # NOTE: `default_branch` on github_repository is deprecated in provider v6+.
  # GitHub initializes new repos to the org default branch (`main`). To change
  # an existing repo's default branch, use the `github_branch_default` resource.
  auto_init              = var.auto_init
  license_template       = var.license_template != "" ? var.license_template : null
  delete_branch_on_merge = true

  # Disable legacy/attack-surface features by default (least privilege).
  has_issues   = true
  has_projects = false
  has_wiki     = false

  # Security & analysis (secret scanning / push protection / GHAS).
  dynamic "security_and_analysis" {
    for_each = local.security_block_enabled ? [1] : []

    content {
      dynamic "advanced_security" {
        for_each = var.enable_advanced_security ? [1] : []
        content {
          status = "enabled"
        }
      }
      dynamic "secret_scanning" {
        for_each = var.enable_secret_scanning ? [1] : []
        content {
          status = "enabled"
        }
      }
      dynamic "secret_scanning_push_protection" {
        for_each = var.enable_push_protection ? [1] : []
        content {
          status = "enabled"
        }
      }
    }
  }
}

# Dependabot security updates (free tier capable).
resource "github_repository_dependabot_security_updates" "this" {
  count = var.enable_dependabot_security_updates ? 1 : 0

  repository = github_repository.this.name
  enabled    = true
}
