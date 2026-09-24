variable "owner" {
  description = "GitHub organization/user that owns the repository."
  type        = string
}

variable "name" {
  description = "Repository name."
  type        = string
}

variable "description" {
  description = "Repository description."
  type        = string
  default     = ""
}

variable "visibility" {
  description = "Repository visibility: public, private, or internal."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["public", "private", "internal"], var.visibility)
    error_message = "visibility must be one of: public, private, internal."
  }
}

variable "default_branch" {
  description = "Default branch name."
  type        = string
  default     = "main"
}

variable "auto_init" {
  description = "Initialize the repo with a README on creation (only for brand-new repos)."
  type        = bool
  default     = false
}

variable "license_template" {
  description = "GitHub license template key (e.g. mit, apache-2.0). Empty = no license."
  type        = string
  default     = ""
}

variable "manage_files" {
  description = <<-EOT
    When true, the module writes CODEOWNERS, a security workflow, and a README
    skeleton. Set false for pre-existing repos so Terraform never clobbers their
    content on first adoption.
  EOT
  type        = bool
  default     = false
}

variable "codeowners_teams" {
  description = "Teams listed as owners in CODEOWNERS (without the @org/ prefix)."
  type        = list(string)
  default     = []
}

# --- Control gating ----------------------------------------------------------

variable "enable_branch_protection" {
  description = "Enable branch protection on the default branch."
  type        = bool
  default     = true
}

variable "required_approving_review_count" {
  description = "Approving reviews required before merge (0 = PR workflow enforced but no approvals needed)."
  type        = number
  default     = 0
}

variable "require_code_owner_reviews" {
  description = "Require approval from a CODEOWNERS-listed team (only meaningful when review count >= 1)."
  type        = bool
  default     = false
}

variable "require_last_push_approval" {
  description = "Require the latest push to be approved by someone other than its author."
  type        = bool
  default     = false
}

variable "enforce_admins" {
  description = "Apply branch protection to administrators as well."
  type        = bool
  default     = true
}

variable "required_status_checks_strict" {
  description = "Require branches to be up to date before merging."
  type        = bool
  default     = true
}

variable "apply_private_branch_protection" {
  description = <<-EOT
    Whether branch protection may be applied to PRIVATE repos (requires GitHub
    Team or Enterprise). Resolved by the root module against the plan tier.
  EOT
  type        = bool
  default     = false
}

variable "enable_secret_scanning" {
  description = "Enable secret scanning (free for public repos)."
  type        = bool
  default     = true
}

variable "enable_push_protection" {
  description = "Enable secret-scanning push protection (free for public repos)."
  type        = bool
  default     = true
}

variable "enable_advanced_security" {
  description = "Enable GitHub Advanced Security (requires Enterprise)."
  type        = bool
  default     = false
}

variable "enable_dependabot_alerts" {
  description = "Enable Dependabot vulnerability alerts."
  type        = bool
  default     = true
}

variable "enable_dependabot_security_updates" {
  description = "Enable Dependabot security updates."
  type        = bool
  default     = true
}
