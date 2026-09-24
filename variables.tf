###############################################################################
# Identity
###############################################################################

variable "github_owner" {
  description = "GitHub organization that this control plane manages."
  type        = string
  default     = "Via-Vitae"
}

variable "billing_email" {
  description = "Organization billing email (required argument of github_organization_settings; org metadata, not a secret)."
  type        = string
  default     = "journey4oflife+viavitae.github@gmail.com"
}

variable "default_branch" {
  description = "Default branch name applied to managed repositories."
  type        = string
  default     = "main"
}

variable "import_existing_repos" {
  description = <<-EOT
    When true, existing org repositories listed in the inventory are adopted into
    Terraform state via import blocks (non-destructive). Set false only for a
    greenfield org with no pre-existing repos.
  EOT
  type        = bool
  default     = true
}

###############################################################################
# Plan-tier + feature flags (tier-agnostic control model)
###############################################################################

variable "github_plan_tier" {
  description = <<-EOT
    GitHub plan of the organization. Paid controls (SSO, private-repo Advanced
    Security, private-repo branch protection) are only activated when the tier
    supports them; otherwise they are recorded as documented gaps, never faked.
  EOT
  type        = string
  default     = "free"

  validation {
    condition     = contains(["free", "team", "enterprise"], var.github_plan_tier)
    error_message = "github_plan_tier must be one of: free, team, enterprise."
  }
}

variable "enable_secret_scanning" {
  description = "Enable secret scanning on managed public repos (free for public repos)."
  type        = bool
  default     = true
}

variable "enable_push_protection" {
  description = "Enable secret-scanning push protection on managed public repos."
  type        = bool
  default     = true
}

variable "enable_advanced_security" {
  description = "Enable GitHub Advanced Security (requires Enterprise; gated by plan tier)."
  type        = bool
  default     = false
}

variable "enable_branch_protection" {
  description = "Enable branch protection on the default branch of managed repos."
  type        = bool
  default     = true
}

variable "enable_private_branch_protection" {
  description = "Apply branch protection to PRIVATE repos (requires Team or Enterprise)."
  type        = bool
  default     = true
}

# --- Branch protection review model -----------------------------------------
# IMPORTANT: the Via-Vitae org currently has a SINGLE member (JourneyOfLife).
# Requiring >=1 approving review + code-owner review would LOCK OUT the sole
# admin (you cannot approve your own PR). These therefore default to a
# 1-person-safe configuration that still enforces a PR workflow, blocks force
# pushes/deletions, and requires up-to-date branches. Tighten once a second
# member/team exists: set branch_required_approving_review_count = 1 and
# branch_require_code_owner_reviews = true.

variable "branch_required_approving_review_count" {
  description = "Approving reviews required before merge. Keep 0 while the org has one member; raise to 1 when a second reviewer exists."
  type        = number
  default     = 0
}

variable "branch_require_code_owner_reviews" {
  description = "Require an approved review from a CODEOWNERS-listed team. Only meaningful when branch_required_approving_review_count >= 1."
  type        = bool
  default     = false
}

variable "branch_enforce_admins" {
  description = "Apply branch protection rules to administrators too. Prevents privileged bypass."
  type        = bool
  default     = true
}

variable "branch_require_last_push_approval" {
  description = "Require the most recent push to be approved by someone other than its author. Only meaningful with >=1 required review."
  type        = bool
  default     = false
}

variable "branch_required_status_checks_strict" {
  description = "Require branches to be up to date before merging (strict status checks)."
  type        = bool
  default     = true
}

variable "enable_dependabot_alerts" {
  description = "Enable Dependabot vulnerability alerts on managed repos."
  type        = bool
  default     = true
}

variable "enable_dependabot_security_updates" {
  description = "Enable Dependabot security updates on managed repos."
  type        = bool
  default     = true
}

variable "enable_sso" {
  description = <<-EOT
    Intent flag for SAML SSO enforcement. Requires Enterprise AND has no
    open-source Terraform resource; enforced via policies/enforce_sso.sh. This
    flag only drives the effective-control matrix / gap reporting.
  EOT
  type        = bool
  default     = false
}

###############################################################################
# Allowed Actions policy (org level)
###############################################################################

variable "actions_allowed_mode" {
  description = <<-EOT
    Which GitHub Actions are permitted org-wide:
      "all"        -> no restriction (current unsafe default)
      "selected"   -> only actions matching allowed_actions patterns
      "disabled"   -> Actions disabled org-wide
  EOT
  type        = string
  default     = "selected"

  validation {
    condition     = contains(["all", "selected", "disabled"], var.actions_allowed_mode)
    error_message = "actions_allowed_mode must be one of: all, selected, disabled."
  }
}

variable "actions_allowed_patterns" {
  description = "Allow-list patterns used when actions_allowed_mode = selected."
  type        = list(string)
  default = [
    "actions/checkout@*",
    "actions/setup-node@*",
    "actions/setup-python@*",
    "actions/upload-artifact@*",
    "actions/download-artifact@*",
    "actions/cache@*",
    "github/codeql-action@*",
    "dependabot/*",
  ]
}

variable "actions_sha_pinning_required" {
  description = "Require GitHub Actions to be pinned to full commit SHAs. Enable only after actions_allowed_patterns are SHA-pinned."
  type        = bool
  default     = false
}

###############################################################################
# Organization member permissions
###############################################################################

variable "default_repository_permission" {
  description = "Default permission members get on org repositories (none/read/write/admin)."
  type        = string
  default     = "read"
}

variable "members_can_create_repositories" {
  description = "Whether members may create repositories. Tighten to false once control plane owns creation."
  type        = bool
  default     = true
}

variable "members_can_create_public_repositories" {
  description = "Whether members may create PUBLIC repositories. Set false to stop shadow public repos."
  type        = bool
  default     = true
}

###############################################################################
# State / backend (S3 bootstrap bucket)
###############################################################################

variable "state_s3_bucket" {
  description = "S3 bucket for Terraform state (Via-Vitae bootstrap bucket). Used when the S3 backend is enabled."
  type        = string
  default     = ""
}

variable "state_s3_key" {
  description = "S3 object key for the state file."
  type        = string
  default     = "viavitae-control/terraform.tfstate"
}

variable "state_s3_region" {
  description = "AWS region of the state bucket."
  type        = string
  default     = "eu-central-1"
}

###############################################################################
# CODEOWNERS defaults
###############################################################################

variable "codeowners_default_teams" {
  description = "Fallback CODEOWNERS teams when a repo/tier has no explicit mapping. Must be existing Via-Vitae teams."
  type        = list(string)
  default     = ["security", "platform"]
}

variable "license_template" {
  description = "Default license template applied to newly created repos (empty = none)."
  type        = string
  default     = ""
}
