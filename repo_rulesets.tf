# #############################################################################
# protect-main — repository ruleset for the control repo, brought under IaC.
#
# This ruleset was originally created by hand (and edited via API), which is
# DRIFT: the live org had a protection rule that Terraform did not declare. It is
# now the source of truth. The existing ruleset (id 23943250) is ADOPTED via the
# import block below, so applying does not create a duplicate.
#
# WHY A RULESET (not classic github_branch_protection) for this repo:
#   - Rulesets apply to a ref PATTERN and do NOT require the branch to exist, so
#     they work even while a repo is empty (classic branch protection does not).
#   - `protect-main` is the authoritative protection for viavitae-control; the
#     module's classic github_branch_protection is disabled for this repo
#     (enable_branch_protection = false in repos_data.tf) to avoid a conflict.
#
# Review-policy fields are driven by the same variables as the module, so raising
# branch_required_approving_review_count later updates BOTH mechanisms at once.
#
# NOTE: the provider does not model `require_extra_approval_for_unattributed_changes`
# or `dismissal_restriction`; those live-API fields are outside Terraform's view.
# With 0 required approvals they have no effect.
# #############################################################################

resource "github_repository_ruleset" "protect_main" {
  name        = "protect-main"
  target      = "branch"
  repository  = "viavitae-control" # owner comes from the provider
  enforcement = "active"

  conditions {
    ref_name {
      include = ["refs/heads/${var.default_branch}"]
      exclude = []
    }
  }

  rules {
    # Block destructive history rewriting on the protected branch.
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      # Single-member org => 0 approvals (see variables.tf). Raise to 1 once a
      # second reviewer exists; this ruleset updates automatically.
      required_approving_review_count   = var.branch_required_approving_review_count
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = var.branch_require_code_owner_reviews
      require_last_push_approval        = var.branch_require_last_push_approval
      required_review_thread_resolution = false
      allowed_merge_methods             = ["merge", "squash", "rebase"]
    }
  }

  # No bypass actors: not even admins can bypass (matches the hardened live config).
}

# Adopt the pre-existing, hand-created ruleset into state (non-destructive).
# Import ID format is "<repository>:<ruleset_id>" (provider parseID2).
# This is a no-op once the ruleset is in state; safe to keep or remove after apply.
import {
  to = github_repository_ruleset.protect_main
  id = "viavitae-control:23943250"
}
