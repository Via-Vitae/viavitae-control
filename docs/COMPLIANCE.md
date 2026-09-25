# Compliance Control Matrix — viavitae-control

Scope: **`Via-Vitae`** org (GitHub Free). Frameworks: **SOC 2**, **GDPR**,
**ISO 27001**. Baseline verified empirically on **2026-09-24**.

> This control plane manages Via-Vitae only. It is separate from `jol-control`
> (which manages `journeyoflife-org`). The two orgs are never mixed.

This document maps each control to the Terraform resource / script that implements
it, its status on the current plan, and residual gaps. It is the audit-facing
companion to the effective-control matrix emitted by `terraform output`.

## 1. Control → implementation mapping

| # | Control | SOC 2 | ISO 27001 | GDPR | Implemented by | Free status |
|---|---|---|---|---|---|---|
| C1 | Repositories declared as code (single source of truth) | CC8.1 | A.14.2 | Art. 25 | `repos_data.tf`, `repos.tf` | ✅ |
| C2 | No shadow repos (drift detection) | CC8.1 | A.12.4 | Art. 32 | `scripts/detect_drift.sh` | ✅ |
| C3 | Secret scanning (public repos) | CC7.1 | A.12.6 | Art. 32 | `modules/repo` security_and_analysis | ✅ |
| C4 | Secret-scanning push protection (public) | CC7.1 | A.12.6 | Art. 32 | `modules/repo` security_and_analysis | ✅ |
| C5 | Dependabot security updates | CC7.1 | A.12.6 | Art. 32 | `github_repository_dependabot_security_updates` | ✅ |
| C6 | Branch protection (public repos): PR workflow, no force-push/delete, strict checks, admins enforced | CC8.1 | A.14.2 | Art. 32 | `modules/repo/branch_protection.tf` | ⚠️ deferred (empty repos) |
| C7 | CODEOWNERS (accountable reviewers) | CC1.4, CC8.1 | A.6.1 | Art. 24 | `modules/repo/files.tf` | ✅ (when manage_files) |
| C8 | Baseline security workflow (CodeQL) | CC7.1 | A.14.2 | Art. 32 | `modules/repo/files.tf` | ✅ |
| C9 | Allowed-actions allow-list (supply chain) | CC6.6, CC7.1 | A.15.1 | Art. 28 | `org_actions_policy.tf` | ✅ |
| C10 | Least-privilege repo features (wiki/projects off) | CC6.1 | A.9.4 | Art. 25 | `modules/repo/main.tf` | ✅ |
| C11 | Org member permission baseline | CC6.1 | A.9.2 | Art. 32 | `org_settings.tf` | ✅ |
| C12 | Org-wide 2FA requirement | CC6.1 | A.9.4 | Art. 32 | `policies/enforce_sso.sh` | ✅ (manual apply) |
| C13 | State encryption + locking | CC6.1 | A.10.1 | Art. 32 | `state/` (local now, S3 target) | ⚠️ local now |
| C14 | Private-repo branch protection | CC8.1 | A.14.2 | Art. 32 | gated in module | ❌ needs Team+ |
| C15 | Advanced Security on private repos | CC7.1 | A.12.6 | Art. 32 | gated in module | ❌ needs Enterprise |
| C16 | SAML SSO / SCIM provisioning | CC6.1 | A.9.2 | Art. 32 | `policies/sso_saml.md` | ❌ needs Enterprise |

## 2. P0 / P1 findings (require human action — not auto-remediated)

The scope agreed for this control plane is **non-destructive**: it will not flip
repo visibility or rotate credentials automatically. The following need explicit action.

- **P0-1 — All 30 repos are PUBLIC**, including compliance-sensitive ones:
  `viavitae-compliance`, `viavitae-data-governance` (records of processing, DPIAs),
  `viavitae-vendor-register` (GDPR Art. 28 sub-processors), `viavitae-threat-model`
  (STRIDE/risk), `viavitae-policies`. Exposing DPIAs, threat models, and vendor/
  sub-processor data publicly is itself a GDPR Art. 32 security failure and hands
  attackers a roadmap. Review each and schedule **staged privatization**.
- **P1-1 — 2FA not enforced org-wide** (`two_factor_requirement_enabled=false`).
  Run `policies/enforce_sso.sh --apply` after confirming the member has 2FA enrolled.
- **P1-2 — Single-member org** (`JourneyOfLife` only). Peer review and code-owner
  review cannot be enforced without locking out the sole admin. Add a second
  member/team, then raise `branch_required_approving_review_count = 1` and
  `branch_require_code_owner_reviews = true`.
- **P1-3 — Actions unrestricted** today. `org_actions_policy.tf` defaults to a
  `selected` allow-list; review `actions_allowed_patterns` and pin to commit SHAs.
- **P1-4 — Local Terraform state.** Migrate to the encrypted, locked S3 backend
  (`state/README.md`) before this becomes the production system of record.
- **P1-5 — Members may delete repos / change visibility** (`members_can_delete_repositories`,
  `members_can_change_repo_visibility` = true). Tighten via org settings once the
  control plane owns repo lifecycle.
- **P1-6 — All 30 repos are EMPTY** (no `main` branch), so branch protection (C6) is
  **deferred** by the empty-repo guard — it cannot be applied to a non-existent branch.
  Deferred repos are listed in the `branch_protection_deferred` output. Once repos have
  content, set `repos_have_default_branch = true` (or per-repo `default_branch_exists`)
  and re-apply to activate protection.

## 3. Staged remediation roadmap

1. **Day 0 (now, free):** Enforce 2FA; enable secret scanning + push protection +
   Dependabot on all public repos; apply the allowed-actions list; begin privatizing
   the compliance-sensitive repos (P0-1) — note private-repo branch protection needs Team.
2. **Stage 1 (Team upgrade):** finish flipping sensitive repos private; private-repo
   branch protection activates automatically via the feature flag.
3. **Stage 2 (grow the team):** add a second member/reviewer; raise review count to 1
   and enable code-owner review.
4. **Stage 3 (Enterprise):** set `github_plan_tier = "enterprise"`,
   `enable_advanced_security = true`, `enable_sso = true`; configure IdP SAML/SCIM.
5. **Continuous:** `detect_drift.sh` in CI; quarterly access review; state in S3.

## 4. Assurance notes

- **No secrets in code or state.** GitHub token via `GITHUB_TOKEN` env only.
- **Change control.** Every repo/policy change is a PR against this repo (C1/C6/C7).
- **No ruleset drift.** The `protect-main` ruleset on `viavitae-control` is declared
  in `repo_rulesets.tf` and adopted by import (plan shows import with no diff). The
  control repo's own protection is therefore reproducible and auditable, not hand-made.
- **Evidence.** `terraform output effective_control_matrix` and `control_gaps`
  provide point-in-time evidence for auditors; archive outputs per apply (see
  `viavitae-compliance`).
- **Honesty of gaps.** Controls the current plan/org cannot enforce are reported as
  gaps, never silently marked as satisfied.
