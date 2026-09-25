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
  description = "Immediate-action security findings surfaced by the control plane."
  value = [
    "P0: All 30 Via-Vitae repositories are PUBLIC, including compliance-sensitive ones (viavitae-compliance, viavitae-data-governance, viavitae-vendor-register, viavitae-threat-model, viavitae-policies). Review each for GDPR Art. 9 personal data and schedule staged privatization.",
    "P1: Org-wide 2FA is NOT enforced (two_factor_requirement_enabled=false). Run policies/enforce_sso.sh --apply (free on all plans).",
    "P1: SINGLE-MEMBER ORG (only JourneyOfLife). Peer-review and code-owner enforcement are disabled by default to avoid locking out the sole admin; add a second member/team, then raise branch_required_approving_review_count to 1 and set branch_require_code_owner_reviews=true.",
    "P1: SAML SSO not available on the Free plan (requires Enterprise). See policies/sso_saml.md for compensating controls.",
  ]
}

output "drift_hint" {
  description = "Reminder to keep the inventory in sync with the live org."
  value       = "Run scripts/detect_drift.sh in CI: it fails if any live org repo is missing from repos_data.tf."
}
