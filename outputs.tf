output "managed_repositories" {
  description = "Repositories declared and managed by this control plane."
  value       = { for k, v in module.repo : k => v.full_name }
}

output "repo_count" {
  description = "Number of repositories under management."
  value       = length(local.repos)
}

output "effective_control_matrix" {
  description = "Which controls are actually active given the current plan tier."
  value       = local.effective_controls
}

output "branch_protection_deferred" {
  description = <<-EOT
    Repos where branch protection was requested but is DEFERRED because the
    default branch does not exist yet (empty repo) or the plan tier is
    insufficient. Set default_branch_exists/auto_init, or upgrade the plan, then
    re-apply to activate protection.
  EOT
  value = sort([
    for k, m in module.repo : k if m.branch_protection_deferred
  ])
}

output "control_gaps" {
  description = <<-EOT
    Controls requested but NOT enforceable on the current GitHub plan tier.
    These are compliance gaps requiring a plan upgrade or a compensating control.
    Mirrored in docs/COMPLIANCE.md.
  EOT
  value       = local.control_gaps
}

output "p0_security_alerts" {
  description = "Immediate-action security findings derived from live org state."
  value = concat(
    # 2FA state is UNKNOWN — never "fine" — when the opt-in org read is disabled.
    local.org_2fa_requirement_enabled == null ? [
      "P1: Org-wide 2FA enforcement is UNKNOWN here — this plan reads no organization full-detail field (var.manage_org_data = false). Verify with scripts/assert_org_2fa.sh using an operator credential and record the result."
      ] : (local.org_2fa_requirement_enabled ? [] : [
        "P1: Org-wide 2FA is NOT enforced (two_factor_requirement_enabled=false). Run policies/enforce_sso.sh --apply (free on all plans). Not IaC-settable in provider 6.13.0."
    ]),
    # Single-member org
    var.branch_required_approving_review_count == 0 ? [
      "P1: SINGLE-MEMBER ORG (only JourneyOfLife). Peer-review and code-owner enforcement are disabled by default to avoid locking out the sole admin; add a second member/team, then raise branch_required_approving_review_count to 1 and set branch_require_code_owner_reviews=true."
    ] : [],
    # SAML SSO not available on Free
    local.is_enterprise ? [] : [
      "P1: SAML SSO not available on the Free plan (requires Enterprise). See policies/sso_saml.md for compensating controls."
    ],
  )
}

output "drift_hint" {
  description = "Reminder to keep the inventory in sync with the live org."
  value       = "Run scripts/detect_drift.sh in CI: it fails if any live org repo is missing from repos_data.tf."
}
