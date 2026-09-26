# Tier -> default CODEOWNERS teams. Verified against live Via-Vitae teams:
# architects, compliance, dpo, legal, platform, security.
locals {
  tier_codeowners = {
    control  = ["security", "compliance"]
    platform = ["platform", "security"]
    app      = ["architects", "platform"]
    site     = ["platform", "architects"]
    meta     = ["security", "platform"]
  }

  # Merge each inventory entry with tier/global defaults into the normalized
  # object consumed by modules/repo. Optional per-repo overrides win.
  repos = {
    for name, r in local.inventory : name => {
      name         = name
      description  = lookup(r, "description", "")
      visibility   = lookup(r, "visibility", "public")
      tier         = lookup(r, "tier", "app")
      manage_files = lookup(r, "manage_files", false)
      auto_init    = lookup(r, "auto_init", false)
      # Branch protection is deferred unless the default branch exists. Per-repo
      # `default_branch_exists` overrides the global var.repos_have_default_branch.
      default_branch_exists = lookup(r, "default_branch_exists", var.repos_have_default_branch)
      license               = lookup(r, "license_template", var.license_template)
      codeowners            = lookup(r, "codeowners_teams", local.tier_codeowners[lookup(r, "tier", "app")])
      default_branch        = var.default_branch

      # Per-repo control gating, resolved against the org plan tier below.
      enable_branch_protection = lookup(r, "enable_branch_protection", true)
    }
  }

  # --- Plan-tier capability model -------------------------------------------
  is_team       = contains(["team", "enterprise"], var.github_plan_tier)
  is_enterprise = var.github_plan_tier == "enterprise"

  # Effective controls: a paid control is active only if flag AND tier allow it.
  effective_controls = {
    secret_scanning_public      = var.enable_secret_scanning             # free for public repos
    push_protection_public      = var.enable_push_protection             # free for public repos
    dependabot_alerts           = var.enable_dependabot_alerts           # free
    dependabot_security_updates = var.enable_dependabot_security_updates # free
    branch_protection_public    = var.enable_branch_protection           # free for public repos
    advanced_security_private   = var.enable_advanced_security && local.is_enterprise
    branch_protection_private   = var.enable_private_branch_protection && local.is_team
    sso_saml                    = var.enable_sso && local.is_enterprise
    allowed_actions_policy      = var.actions_allowed_mode != "all"
    code_owner_review_enforced  = var.branch_require_code_owner_reviews && var.branch_required_approving_review_count >= 1
  }

  # Gap register: controls requested but not enforceable on the current tier or
  # org reality. Surfaced as an output and mirrored in docs/COMPLIANCE.md.
  control_gaps = compact([
    var.enable_advanced_security && !local.is_enterprise ? "advanced_security_private requires GitHub Enterprise (current tier: ${var.github_plan_tier})" : "",
    var.enable_private_branch_protection && !local.is_team ? "branch_protection_private requires GitHub Team or Enterprise (current tier: ${var.github_plan_tier})" : "",
    var.enable_sso && !local.is_enterprise ? "sso_saml requires GitHub Enterprise + policies/enforce_sso.sh (current tier: ${var.github_plan_tier})" : "",
    !local.is_enterprise ? "secret_scanning/push_protection on PRIVATE repos requires GitHub Enterprise" : "",
    var.repos_have_default_branch ? "" : "branch protection DEFERRED for empty repos (no default branch). Set repos_have_default_branch=true or per-repo default_branch_exists once repos have content.",
    var.branch_required_approving_review_count == 0 ? "peer-review requirement is 0 (single-member org). Raise branch_required_approving_review_count to >=1 once a second member/team exists." : "",
    !var.branch_require_code_owner_reviews ? "CODEOWNERS review not enforced (branch_require_code_owner_reviews=false); enable once >=2 reviewers exist." : "",
  ])
}
