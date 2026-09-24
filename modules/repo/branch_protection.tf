# Branch protection on the default branch.
#
# COMPLIANCE (SOC2 CC8 change management / ISO 27001 A.14): no direct pushes to
# the default branch, no force-push/deletion, required linear history, and strict
# status checks. Peer-review count and code-owner review are configurable; they
# default to 0/false because the Via-Vitae org currently has a single member
# (requiring approvals would lock out the sole admin). Raise them once a second
# reviewer exists. NOTE: the default branch must exist before protection can be
# applied; for an empty repo set auto_init = true or push an initial commit first.
#
# Private-repo branch protection requires GitHub Team or Enterprise; the root
# module resolves that via local.branch_protection_enabled.

resource "github_branch_protection" "this" {
  count = local.branch_protection_enabled ? 1 : 0

  repository_id  = github_repository.this.node_id
  pattern        = var.default_branch
  enforce_admins = var.enforce_admins

  # Block destructive git operations regardless of review policy.
  allows_force_pushes     = false
  allows_deletions        = false
  required_linear_history = true

  required_pull_request_reviews {
    required_approving_review_count = var.required_approving_review_count
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = var.require_code_owner_reviews
    require_last_push_approval      = var.require_last_push_approval
  }

  required_status_checks {
    strict   = var.required_status_checks_strict
    contexts = []
  }
}
