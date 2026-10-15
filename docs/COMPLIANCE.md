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
| C1 | Repositories declared as code (single source of truth) | CC8.1 | A.14.2 | Art. 25 | `repos_data.tf`, `repos.tf` | `declared-not-applied` |
| C2 | No shadow repos (drift detection) | CC8.1 | A.12.4 | Art. 32 | `scripts/detect_drift.sh` | `declared-not-applied` |
| C3 | Secret scanning (public repos) | CC7.1 | A.12.6 | Art. 32 | `modules/repo` security_and_analysis | `declared-not-applied` |
| C4 | Secret-scanning push protection (public) | CC7.1 | A.12.6 | Art. 32 | `modules/repo` security_and_analysis | `declared-not-applied` |
| C5 | Dependabot security updates | CC7.1 | A.12.6 | Art. 32 | `github_repository_dependabot_security_updates` | `declared-not-applied` |
| C6 | Branch protection (public repos): PR workflow, no force-push/delete, strict checks, admins enforced | CC8.1 | A.14.2 | Art. 32 | `modules/repo/branch_protection.tf` | `declared-not-applied` |
| C7 | CODEOWNERS (accountable reviewers) | CC1.4, CC8.1 | A.6.1 | Art. 24 | `modules/repo/files.tf` | `declared-not-applied` |
| C8 | Baseline security workflow (CodeQL) | CC7.1 | A.14.2 | Art. 32 | `modules/repo/files.tf` | `declared-not-applied` |
| C9 | Allowed-actions allow-list (supply chain) | CC6.6, CC7.1 | A.15.1 | Art. 28 | `org_actions_policy.tf` | `declared-not-applied` |
| C10 | Least-privilege repo features (wiki/projects off) | CC6.1 | A.9.4 | Art. 25 | `modules/repo/main.tf` | `declared-not-applied` |
| C11 | Org member permission baseline | CC6.1 | A.9.2 | Art. 32 | `org_settings.tf` | `declared-not-applied` |
| C12 | Org-wide 2FA requirement | CC6.1 | A.9.4 | Art. 32 | `policies/enforce_sso.sh` | `out-of-band` (not IaC-settable in provider 6.13.0; detective control only) |
| C13 | State encryption + locking | CC6.1 | A.10.1 | Art. 32 | `state/` (local now, S3 target) | `out-of-band` |
| C14 | Private-repo branch protection | CC8.1 | A.14.2 | Art. 32 | gated in module | `gap-plan-tier` |
| C15 | Advanced Security on private repos | CC7.1 | A.12.6 | Art. 32 | gated in module | `gap-plan-tier` |
| C16 | SAML SSO / SCIM provisioning | CC6.1 | A.9.2 | Art. 32 | `policies/sso_saml.md` | `gap-plan-tier` |
| C17 | Pre-commit secret scanning (gitleaks + hygiene hooks) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.pre-commit-config.yaml`) | `declared-not-applied` |
| C18 | CI-based secret scanning (gitleaks CLI, license-free) | CC7.1 | A.12.6 | Art. 32 | `modules/repo/files.tf` (`.github/workflows/gitleaks.yml`) | `declared-not-applied` |

### 1.1 Control status vocabulary

| Status | Meaning | Required citation |
|---|---|---|
| `enforced-verified` | Declared, in state, and confirmed against the live API | live API response |
| `declared-not-applied` | Present in config, absent from state — will enforce on next apply | state listing |
| `deferred-empty-repo` | Cannot apply because the target ref does not exist yet | repo `size == 0` |
| `gap-plan-tier` | Requires a paid GitHub plan the org does not have | plan tier + provider gating |
| `out-of-band` | Not IaC-settable; enforced by script, API or human process | provider schema evidence |

A control may not be marked `enforced-verified` without a cited live observation.
This single rule would have prevented F2, F5, F6 and F11.

## 2. P0 / P1 findings (require human action — not auto-remediated)

The scope agreed for this control plane is **non-destructive**: it will not flip
repo visibility or rotate credentials automatically. The following need explicit action.

- **P0-1 — All 30 repos are PUBLIC**, including compliance-sensitive ones:
  `viavitae-compliance`, `viavitae-data-governance` (records of processing, DPIAs),
  `viavitae-vendor-register` (GDPR Art. 28 sub-processors), `viavitae-threat-model`
  (STRIDE/risk), `viavitae-policies`. Exposing DPIAs, threat models, and vendor/
  sub-processor data publicly is itself a GDPR Art. 32 security failure and hands
  attackers a roadmap. Review each and schedule **staged privatization**.
- **P1-1 — 2FA enforced org-wide — CLOSED (re-verified 2026-10-15).**
  `gh api orgs/Via-Vitae --jq .two_factor_requirement_enabled` → `true` (this register
  previously recorded `false`). Consequence, measured while trying to provision a second
  reviewer: a GitHub account without 2FA **cannot accept any invitation into this org** —
  `PATCH /user/repository_invitations/{id}` returns
  `403 "The Via Vitae organization requires all members to have two-factor authentication
  enabled."` See P1-10.
  `policies/enforce_sso.sh --apply` remains the IaC-less path for re-asserting it.
- **P1-2 — Single-member org** (`JourneyOfLife` only). Peer review and code-owner
  review cannot be enforced without locking out the sole admin. Add a second
  member/team, then raise `branch_required_approving_review_count = 1` and
  `branch_require_code_owner_reviews = true`.
- **P1-3 — Actions unrestricted** today. `org_actions_policy.tf` defaults to a
  `selected` allow-list; review `actions_allowed_patterns` and pin to commit SHAs.
- **P1-4 — Local Terraform state.** Migrate to the encrypted, locked S3 backend
  (`state/README.md`) before this becomes the production system of record.
  See P1-12 for the current, worse state of affairs.
- **P1-5 — Members may delete repos / change visibility** (`members_can_delete_repositories`,
  `members_can_change_repo_visibility` = true). Tighten via org settings once the
  control plane owns repo lifecycle.
- **P1-6 — All 30 repos are EMPTY** (no `main` branch), so branch protection (C6) is
  **deferred** by the empty-repo guard — it cannot be applied to a non-existent branch.
  Deferred repos are listed in the `branch_protection_deferred` output. Once repos have
  content, set `repos_have_default_branch = true` (or per-repo `default_branch_exists`)
  and re-apply to activate protection.
- **P1-7 — Published contact channels were undeliverable.** `SECURITY.md`,
  `SUPPORT.md`, `LICENSE`, `CODE_OF_CONDUCT.md`, the DPIA templates and
  `viavitae-web/lib/constants.ts` published `security@viavitae.com`,
  `dpo@viavitae.com` and `legal@viavitae.com`. Measured 2026-10-15: `viavitae.com`
  has **no NS delegation** (resolver `SERVFAIL`), `viavitae.site` has NS/A but
  **no MX**, `viavitae.eu` has `MX 0 localhost.`. A vulnerability report or a
  GDPR Art. 15/17 request sent to any of them is lost, and the published 24-hour
  acknowledgement SLA cannot start. Remediation: repoint to the plus-addressed
  streams via `scripts/update_contact_emails.sh` (clean-clone dry-run: 20 populated
  repos / 134 files, 9 repos skipped as empty); Phase 2 (`viavitae.site` MX) is tracked in
  `viavitae-infra` ADR-000 action items.
- **P1-8 — `SECURITY.md` asserted controls that were not enabled.** It claimed
  "private vulnerability reporting is enabled on repositories in the `Via-Vitae`
  organisation" and that a PGP key was published on the key servers. Measured:
  PVR `enabled=true` on 10 repos, `false` on **12 populated repos** (the 10
  `viavitae-landing-*` repos plus `viavitae-control` and `viavitae-hermes-agents`),
  `false` on 4 empty repos, and `404` on the 5 empty private repos (Free plan).
  No PGP key exists for any current contact address. Enable PVR on the populated
  repos and drop the PGP claim until a key with a published fingerprint exists.
- **P1-9 — Email-segmentation policy is not yet on `main`.** `policies/EMAIL_POLICY.md`,
  `policies/viavitae-gmail-filters.xml`, the README address table and the
  `terraform.tfvars.example` note were **untracked/modified locally only**
  (`git ls-tree HEAD policies/` listed no `EMAIL_POLICY.md`). **Closed 2026-10-15** by
  PR #15 (squash-merged to `main`); the org sweep PRs now cite a policy that exists.
- **P1-10 — Change approval is deadlocked; every PR in 19 repos is unmergeable.**
  Measured 2026-10-15: 19 of 21 populated public repos require **1 approving review** with
  `enforce_admins=true` (`viavitae-qa` requires 0), while `variables.tf` defaults
  `branch_required_approving_review_count` to `0` and `terraform.tfvars.example` sets `0`.
  The org has one member (`gh api orgs/Via-Vitae/members` → `JourneyOfLife`). The intended
  second reviewer, `IterVitae`, cannot be provisioned: its org invitation (role `admin`,
  created 2026-10-12) is still **pending**, and the 20 per-repo `push` invitations raised on
  2026-10-15 could not be accepted because **that account has no 2FA enrolled** (403, see
  P1-1); they were revoked again, leaving `permission=read` and no pending invitations.
  Net effect: the author cannot approve their own PR, `gh pr merge --auto` is refused
  (`enablePullRequestAutoMerge` off), and no `--admin` bypass was used — the 20
  contact-address PRs stay open. Resolve in this order:
  1. enroll 2FA on `IterVitae` (human step: passkey/TOTP),
  2. accept the org invitation, then set `role=member` (not `admin`) and add it to the
     `architects` team (already `push` on 30 repos) — least privilege, keeps the gate,
  3. approve and squash-merge; **then** raise the declared count to `1` in
     `terraform.tfvars` so config matches live.
  If 2FA cannot be enrolled, the fallback is to reconcile live back to the declared `0`
  (`DELETE /repos/Via-Vitae/<repo>/branches/main/protection/required_pull_request_reviews`)
  and keep the SOC 2 CC1.4 separation-of-duties gap documented here until a real second
  reviewer exists.
- **P1-11 — Required status checks can never report in 3 repos; cause not yet known.**
  `viavitae-web`, `viavitae-demos` and `viavitae-qa` require contexts (`CI status`,
  `Compliance status`, `Action SHA pinning`, `Governance files`) whose workflows end in
  **`startup_failure`**: zero check runs, empty job list, no logs, annotations endpoint
  404. Proof that reviews are not the cause: `viavitae-qa#18` needs **0** reviews yet is
  `BLOCKED` with `statusCheckRollup = []`. Pre-existing, not caused by the sweep: a
  scheduled `Compliance check` run on 2026-10-12 failed identically. Four candidate causes
  were tested and **refuted**: (a) unresolvable action pins — only `viavitae-api` has two
  (`aquasecurity/trivy-action@a9c7b0f0…`, `astral-sh/setup-uv@e58605a9…`) and its CI passes,
  while every pin in the failing repos resolves; (b) the Actions allow-list — identical
  (`selected`, `github_owned_allowed=true`, `verified_allowed=true`, same 9 patterns) in
  failing and passing repos; (c) duplicate YAML keys or `needs:` on unknown jobs — a strict
  parse of all 21 repos' workflows is clean; (d) references to a reusable workflow in the
  empty `viavitae-reusable-workflows` repo — no such reference exists. The exact message is
  only rendered in the Actions run page (not the REST API), so this needs one browser look:
  https://github.com/Via-Vitae/viavitae-qa/actions/runs/38744206861
  Consequence until then: **any** PR in those three repos is permanently unmergeable,
  including `viavitae-web` — the public charity site, whose dead `security@`/`dpo@`
  contacts therefore stay published.
- **P1-12 — The control plane has NO state on this host; IaC reconciliation is currently
  impossible.** Verified 2026-10-15: no `terraform.tfstate`, no `.terraform/`, no
  `backend.tf`, and no `backend` block in any committed `*.tf` (the only occurrence is in
  the ignored `state/backend_s3.tf.example`) — yet §Status below claims "Terraform state
  contains 5 of 30 repositories". That state is **not here**. Recoverable: age-encrypted
  backups exist at `/opt/jol/backup/tfstate/viavitae-control-terraform.tfstate.20261013T190752Z.age`
  and `…T191400Z.age` (27,738 bytes, mode 600, X25519 recipient), key at
  `~/.config/age/state-backup-key.txt`; both predate every 2026-10-15 change.
  Rules while this holds:
  - `terraform plan` here would build state from scratch and propose **creating** ~30 repos
    plus their protections and org settings. Such a plan is invalid evidence — never apply it.
  - Consequently the P1-10 fallback (reconciling `required_approving_review_count` to the
    declared `0`) cannot be done through Terraform, and doing it out-of-band would add more
    unmanaged drift.
  - Restore first, then plan:
    `age -d -i ~/.config/age/state-backup-key.txt <newest>.age > terraform.tfstate && terraform init`
  - Do not run `terraform init -force`; do not import into a new backend as part of this
    remediation.

## 3. Staged remediation roadmap

1. **Day 0 (now, free):** Enforce 2FA; enable secret scanning + push protection +
   Dependabot on all public repos; apply the allowed-actions list; begin privatizing
   the compliance-sensitive repos (P0-1) — note private-repo branch protection needs Team;
   activate `manage_files` per repo to deploy gitleaks CI workflow + pre-commit config;
   install pre-commit hooks on developer machines (`pip install pre-commit && pre-commit install`);
   repoint the undeliverable contact addresses (P1-7) and enable PVR on the populated
   repos (P1-8).
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
