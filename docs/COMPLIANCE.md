# Compliance Control Matrix — viavitae-control

Scope: **`Via-Vitae`** org (GitHub Free). Frameworks: **SOC 2**, **GDPR**,
**ISO 27001**. Baseline verified empirically on **2026-09-24**.

> This control plane manages Via-Vitae only. It is separate from `jol-control`
> (which manages `journeyoflife-org`). The two orgs are never mixed.
>
> **Portfolio note (2026-10-13).** There are three planes, not two: `viavitae-control` ->
> `Via-Vitae` (commercial IT), `jol-control` -> `journeyoflife-org` (charity, owns its
> hardware), `jolarca-control` -> `jolarca-dev` (marketplace, PCI-DSS scope). The rule that
> governs all three pairs is that no state, token, secret, CI configuration or backup
> archive may be shared between any two of them. `jolarca-control/docs/security/isolation-model.md`
> states this for the marketplace/mission pair only; extending it to the Via-Vitae pairings
> is an amendment to that doctrine, not a change to this repo.

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
| C12 | Org-wide 2FA requirement | CC6.1 | A.9.4 | Art. 32 | Settings → Security (only setter) + `policies/check_org_security.sh` (monitor) | **live & verified 2026-10-12T15:43Z** (`two_factor_requirement_enabled=true`, read back via `gh` and `curl`). Not settable via REST, not modelable in Terraform (provider 6.13.0) → the baseline lives in `policies/org-security-baseline.json`, so the repository is the change record GitHub Free does not keep |
| C13a | State confidentiality at rest | CC6.1 | A.10.1 | Art. 5(1)(f), 32 | filesystem permissions plus the age archive in `state/` | `partial-out-of-band` — **not encrypted at rest**: `vgopt/lv_viavitae` is plain LVM and `dmsetup ls --target crypt` returns 0 devices, so no LUKS layer exists. Fixed 2026-10-13: `audit.tfplan` here was `0664` (a saved plan is state-equivalent) and is now `0600` |
| C13b | State integrity, versioning, recoverability | CC7.1, A1.2 | A.8.13 | Art. 32(1)(c) | `/opt/jol/backup/tfstate` age archives plus manifest (`state/README.md`) | `declared-partially-rehearsed` — 4 archives round-trip verified 2026-10-13 by decrypt-and-compare; **off-host copy, key custody off-host, and the tier-2 plan-from-restore drill are all still open**; the archive volume shares physical disk `nvme1n1` with `jol-control`'s state |
| C13c | State locking | CC6.1, CC8.1 | A.8.32 | Art. 32 | none — the local backend has no lock | `gap-blocked-external` — locking arrives only with a remote backend; S3 is **SCP-denied** (`p-r9i2lq77`, verified 2026-10-13) and HCP needs an ADR first. Interim: single-operator discipline, and `versions.tf` now floors Terraform at `>= 1.10` so a future `use_lockfile` cannot be silently unsupported |
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

- **P0-1 (SUPERSEDED — the claim below was untrue as of 2026-10-12)** ~~All 30 repos are PUBLIC, including
  `viavitae-compliance`, `viavitae-data-governance`, `viavitae-vendor-register`, `viavitae-threat-model`,
  `viavitae-policies`~~. Live API: **26 public / 5 private**, and those five are exactly the private ones — all
  five at `size=0` (no commits). The staged privatization this item called for has therefore already happened;
  leaving the old text in place was itself the finding (a compliance doc asserting a risk the API contradicts
  costs the whole evidence pack credibility). **What is actually exposed today:**
  1. GDPR *working material* in public repos — 22 public repos with history carry files matching
     `DPIA|sub-processor|personal data|STRIDE|threat model` (e.g. `viavitae-infra` 65, `viavitae-web` 37,
     `viavitae-api` 39). These are templates/policies, not registers, so severity is disclosure-of-method rather
     than disclosure-of-data.
  2. **`viavitae-qa` (public) `fixtures/data/donors.json`** — 2 records with keys `first_name`, `last_name`,
     `email`, `phone`, `address{street,city,postal_code}`, `total_donated_eur`, `parish_id`. Values look
     synthetic (`+370 612 34567`-shaped), but a donor dataset shape (identified person + giving history + parish
     affiliation) published in a GDPR-scoped org is a data-minimisation and template-disclosure problem, and the
     org's own scanner cannot see it (see P1-8).
  3. `secretary@parish.lt` used as a live-looking third-party contact in public `viavitae-web` tests (V-010).
- ~~**P1-1 — 2FA not enforced org-wide**~~ **CLOSED 2026-10-12T15:43Z** — `two_factor_requirement_enabled=true`
  on `Via-Vitae`, read back independently by `gh api` and `curl`. Side effects verified: sole owner still
  `active admin`, outside collaborators `0`, private repo reads still succeed → **nobody lost access**.
  Two caveats keep this honest: (1) it cannot be expressed in Terraform, so the control plane cannot see or hold
  it; (2) Free-plan `GET /orgs/Via-Vitae/audit-log` → **404** and the org payload's `updated_at` did not move, so
  **who enabled it, and when, is unrecoverable from GitHub**. Compensating control added: `check_org_security.sh`
  + `org-security-baseline.json` (24 settings, self-test 7/7) which fails on any regression. Never cite C12 as
  IaC-enforced. (Historic text of this item, kept for the audit trail:) `two_factor_requirement_enabled=false`. Not settable through the REST
- **P1-2 — Single-member org** (`JourneyOfLife` only). Peer review and code-owner
  review cannot be enforced without locking out the sole admin. Add a second
  member/team, then raise `branch_required_approving_review_count = 1` and
  `branch_require_code_owner_reviews = true`.
- **P1-3 — Actions unrestricted** today. `org_actions_policy.tf` defaults to a
  `selected` allow-list; review `actions_allowed_patterns` and pin to commit SHAs.
- **P1-4 — Local Terraform state (re-scoped 2026-10-13, still open).** The original
  instruction, "migrate to the encrypted, locked S3 backend", is **not executable**. Probed
  live: `s3:ListAllMyBuckets` and `s3:CreateBucket` both return AccessDenied **with an
  explicit deny in a service control policy**
  (`arn:aws:organizations::376896792604:policy/o-omcubugbug/service_control_policy/p-r9i2lq77`)
  for `arn:aws:iam::775093708742:user/viavitae-terraform`. No IAM change inside the member
  account can override it. Re-scoped into: (a) a written ADR choosing HCP Terraform
  (precedent and reference architecture: `jolarca-control` ADR-0006, which evaluated and
  rejected S3 plus DynamoDB on 2026-09-25) against continued local state; (b) the interim
  encrypted-archive control now documented in `state/README.md`; (c) the off-host copy and
  restore-drill items tracked under C13b. Do not mark this closed on the strength of the
  archive alone.
- **P1-5 — Members may delete repos / change visibility** (`members_can_delete_repositories`,
  `members_can_change_repo_visibility` = true). Tighten via org settings once the
  control plane owns repo lifecycle.
- **P1-6 — All 30 repos are EMPTY** (no `main` branch), so branch protection (C6) is
  **deferred** by the empty-repo guard — it cannot be applied to a non-existent branch.
  Deferred repos are listed in the `branch_protection_deferred` output. Once repos have
  content, set `repos_have_default_branch = true` (or per-repo `default_branch_exists`)
  and re-apply to activate protection.

- **P1-8 — the PII scanner is blind by construction and was cited as proof.** `viavitae-docs/scripts/check-pii.py`
  scans **only `content/**/*.md`**, so JSON/TS/YAML fixtures (including `donors.json` above) were never opened, and
  when no `content/` directory exists it printed "No content/ directory found." and **returned 0** — a green gate
  over zero files examined. It is wired into `viavitae-docs/.github/workflows/ci.yml` and asserted in
  `.github/PULL_REQUEST_TEMPLATE.md` ("No PII in diff — `check-pii.py` reports no personal names, emails, phone
  numbers"), which the tool could not substantiate outside the docs site. Fixed 2026-10-12: that path now exits
  **2 (UNEVALUATED)** unless `PII_ALLOW_EMPTY=1` is set deliberately; verified rc=2 in `viavitae-qa`, rc=0 in
  `viavitae-docs` (unchanged). Still open, by owner decision: extend the sweep beyond `content/*.md`, and note
  the `personal_code` pattern (`LT\d{11}`) does not match a Lithuanian personal code as normally written
  (11 bare digits, no `LT` prefix), so it under-detects the most sensitive field of all.
- **P1-9 — an unaccounted seat.** `orgs/Via-Vitae` reports `plan.filled_seats=2` while every enumerable identity
  source says one person: members `[JourneyOfLife]`, outside_collaborators `0`, `collaborators: 0`, and all six
  teams have `memberCount` consistent with that one account. The billing-managers endpoint 404s and there is no
  audit log on Free, so the second seat cannot be attributed from this host. Reconcile it in the UI (Settings →
  Access: Billing managers) — a 2FA requirement covers billing managers too, and an unidentified account with
  org access is a least-privilege finding regardless of plan.
- **P1-10 — state-equivalent artifacts were group-readable (CLOSED 2026-10-13).** This
  repo's `audit.tfplan` was mode `0664`. A saved plan embeds prior state plus proposed
  attribute values, so it is state-equivalent, and `.gitignore` never protected it from
  local readers. A portfolio sweep (`find -perm /g+r` over `terraform.tfstate*`, `*.tfplan`,
  `terraform.tfvars`) found the same class in `jol-control` — its `terraform.tfstate`
  (195 KB, serial 306, 119 managed instances), two `.backup` copies and `terraform.tfvars` —
  and in `jolarca-control` (`terraform.tfvars`). All seven files are now `0600` and the
  sweep returns empty. Those two planes own their register entries; recording the fact here
  only, because the exposure was visible from this host and the fix is the same one command.
- **P1-11 — this plane has no plan-or-state safety gate.** `jol-control` ships
  `scripts/plan_gate.py` and `scripts/state_gate.py`, both fail-closed (a missing, empty or
  unparseable input exits 2 rather than passing) and both wired into its `plan.yml` and
  `apply.yml`. `jolarca-control` ships `check_plan_safety.sh` (wired into three workflows)
  and `check_workspace_execution_mode.sh` (wired into `apply.yml`). This repo ships **neither**
  — `scripts/` holds only provenance, drift and inventory tooling. Running `jol-control`'s
  gate read-only across all three roots today gave: `viavitae-control` SAFE, `jol-control`
  SAFE, `jolarca-control` **REFUSED (rc 1)** because its local `terraform.tfstate` is 0 bytes.
  Remediation must **reuse, not copy**: `jolarca-control`'s isolation doctrine already records
  that two copies of a security policy is itself an ISO 27001 A.5.2 finding, and
  `state_gate.py`'s own FIX HISTORY logs two regressions that fixtures caught. Publish one
  copy, consume it pinned by commit SHA, and add a parity check in the style of
  `jolarca-control/.github/workflows/context-parity.yml`.
- **P1-12 — a stale snapshot of a *foreign* state lineage is the only on-disk copy for the
  marketplace plane.** Captured today in `/opt/jol/backup/tfstate/manifest-20261013T190752Z.tsv`:
  `jolarca-control`'s live HCP state is serial 14, lineage `f21fa4a8`, 48 managed instances,
  while its local `terraform.tfstate.backup` is serial 151, lineage `4ef38186`, 35 instances.
  A different lineage means Terraform will not treat that file as the same history, so
  "restoring the backup" is not a rollback of 13 resources — it replaces the system of record
  with an unrelated state. ADR-0006 section 6 already lists "remove local state" as not done;
  the reason it stays open is that `state_backup.sh` reads `$REPO_ROOT/terraform.tfstate` and
  validates it as JSON, which a 0-byte stub can never satisfy, so D-02's off-host half cannot
  close until that script is made cloud-aware (`terraform state pull` -> encrypt -> verify).
  Not this repo's change to make unilaterally; recorded here so the dependency is visible.

## 3. Staged remediation roadmap

1. **Day 0 (now, free):** Enforce 2FA; enable secret scanning + push protection +
   Dependabot on all public repos; apply the allowed-actions list; begin privatizing
   the compliance-sensitive repos (P0-1) — note private-repo branch protection needs Team;
   activate `manage_files` per repo to deploy gitleaks CI workflow + pre-commit config;
   install pre-commit hooks on developer machines (`pip install pre-commit && pre-commit install`).
2. **Stage 1 (Team upgrade):** finish flipping sensitive repos private; private-repo
   branch protection activates automatically via the feature flag.
3. **Stage 2 (grow the team):** add a second member/reviewer; raise review count to 1
   and enable code-owner review.
4. **Stage 3 (Enterprise):** set `github_plan_tier = "enterprise"`,
   `enable_advanced_security = true`, `enable_sso = true`; configure IdP SAML/SCIM.
5. **Continuous:** `detect_drift.sh` in CI; quarterly access review; encrypted state archive
   re-run after every apply (`state/README.md`) until the S3-or-HCP ADR lands, and an off-host
   copy of that archive with the identity key held separately.

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
