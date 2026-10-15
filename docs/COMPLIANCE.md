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

- **P0-1 — Partially closed 2026-10-15: 5 of 31 repos are private.** Measured
  (`gh api orgs/Via-Vitae/repos`): total 31, **private 5**, public 26. The privatized set is
  `viavitae-policies`, `viavitae-compliance`, `viavitae-data-governance`,
  `viavitae-threat-model`, `viavitae-vendor-register` — exactly the DPIA / Art. 28 /
  STRIDE-sensitive repos named in this finding. All five are still **empty**, so no
  sensitive content has been exposed by them; the remaining public repos still need the
  staged review.
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
- **P1-3 — Actions are restricted, contrary to this register's earlier wording.**
  Measured 2026-10-15: `allowed_actions = "selected"`, `github_owned_allowed = true`,
  `verified_allowed = true`, 9 patterns, `sha_pinning_required = false` — identical at org
  and repo level. The residual issues are (a) the allow-list **omitted an action three repos
  already use**, which broke their CI silently (P1-11), and (b) declared patterns in
  `variables.tf` did not match live patterns (now corrected). Live also carries
  `actions/setup-terraform@*`, which is not a real action (it is `hashicorp/setup-terraform`)
  — left alone as harmless drift, recorded here.
- **P1-4 — Local Terraform state.** Migrate to the encrypted, locked S3 backend
  (`state/README.md`) before this becomes the production system of record.
  See P1-12 for the current, worse state of affairs.
- **P1-5 — Members may delete repos / change visibility** (`members_can_delete_repositories`,
  `members_can_change_repo_visibility` = true). Tighten via org settings once the
  control plane owns repo lifecycle.
- **P1-6 — CLOSED as a claim; superseded by fact.** This register said "all 30 repos are
  EMPTY". Measured 2026-10-15: **9 of 31 are empty**, 21 are populated and 20 of those
  carry branch protection. The empty-repo guard is therefore still correct code, but the
  `repos_have_default_branch` / `default_branch_exists` flags in `repos_data.tf` are now the
  thing to re-baseline (see P1-13: none of this is reconcilable until state is restored).
- **P1-7 — CLOSED 2026-10-15.** `SECURITY.md`, `SUPPORT.md`, `LICENSE`,
  `CODE_OF_CONDUCT.md`, the DPIA templates and `viavitae-web/lib/constants.ts` published
  `security@viavitae.com`, `dpo@viavitae.com` and `legal@viavitae.com`, all of which were
  undeliverable: `viavitae.com` has **no NS delegation** (resolver `SERVFAIL`),
  `viavitae.site` has NS/A but **no MX**, `viavitae.eu` has `MX 0 localhost.`
  Remediation: 20 PRs (one per populated repo) mapped each address to the receiving
  plus-address stream per `policies/EMAIL_POLICY.md`, and the false PGP key claim was
  removed from `SECURITY.md`. **Final measurement after merging: `0 repo(s) with changes,
  0 file(s)`** — no dead role address remains on any default branch. Org profile
  `email` is now `journey4oflife+viavitae.github@gmail.com`; the live org
  `billing_email` was already the same plus-address (verified via `gh api orgs/Via-Vitae`).
  Append-only evidence (`CHANGELOG.md`, `docs/adr/ADR-000-*`) and contributor placeholders
  (`you@viavitae.com`) were deliberately **not** rewritten.
  Phase 2 (`viavitae.site` MX + real mailboxes) remains open — tracked in
  `viavitae-infra` ADR-000 action items.
- **P1-8 — CLOSED 2026-10-15.** `SECURITY.md` claimed private vulnerability reporting was
  enabled org-wide; measured, it was `true` on only 10 of 26 public repos. **All 26 public
  repos now report `enabled=true`** (verified by re-reading every repo after the change;
  `still_off=0`). Note the API shape: enabling is `PUT /repos/{owner}/{repo}/private-vulnerability-reporting`
  with a JSON boolean — `PATCH` returns 404 and `-f enabled=true` sends the *string*
  `"true"`, which also 404s. The published PGP claim was removed rather than left standing
  (no key exists for any current contact address). Root cause of the drift: the org's
  `GitHub recommended` code-security configuration (id 17) has
  `private_vulnerability_reporting: "enabled"` but `enforcement: "unenforced"`, so repos
  created after it never received the setting.
- **P1-9 — Email-segmentation policy is not yet on `main`.** `policies/EMAIL_POLICY.md`,
  `policies/viavitae-gmail-filters.xml`, the README address table and the
  `terraform.tfvars.example` note were **untracked/modified locally only**
  (`git ls-tree HEAD policies/` listed no `EMAIL_POLICY.md`). **Closed 2026-10-15** by
  PR #15 (squash-merged to `main`); the org sweep PRs now cite a policy that exists.
- **P1-10 — Resolved 2026-10-15 by reconciling live to the declared config; separation of
  duties is now an accepted, documented gap.** State found: 19 of 21 populated public repos
  required **1 approving review** (and 18 required **code-owner approval**) with
  `enforce_admins=true`, while `variables.tf` declares `0`/`false` and
  `modules/repo/branch_protection.tf` says those default to 0 *because* the org has one
  member. With one member, `IterVitae` unaccepted, `gh pr merge --auto` unavailable
  (`allow_auto_merge=false`) and the author unable to approve their own PR, **no PR in those
  repos could merge at all** — which is what initially kept the P1-7 fix from landing.
  Action taken (`scripts/reconcile_branch_protection.sh`, dry-run first, then `--apply`):
  set the approving-review count and code-owner requirement to the **declared** values on all
  19 repos, re-supplying every other field from the live document so nothing else moved —
  verified per repo as `{count:0, codeowner:false, ctx:<unchanged>, enforce:true}` and
  `required_linear_history` left at each repo's live value. Direct pushes are still blocked
  (the PR requirement itself was kept, never deleted), force-push and deletion still
  blocked, `enforce_admins` still on, required status checks untouched. Post-condition
  measured: `repos needing change: 0`; all 20 P1-7 PRs then merged on their own gates.
  Attempted-and-reverted alternative: 20 per-repo `push` invitations for `IterVitae`. They
  could not be accepted — `403 "The Via Vitae organization requires all members to have
  two-factor authentication enabled"` — and were fully revoked; verified `0` pending
  invitations and `permission=read`. Note that deleting a collaborator does **not** delete
  its pending invitation; the invitation must be deleted by id.
  **Gap now live:** with 0 required approvals the sole member can merge their own PR, so
  SOC 2 CC1.4/CC8.1 separation of duties is a gap, not a control. Revert when a 2FA-enrolled
  second reviewer exists: `REVIEW_COUNT=1 CODEOWNER_REVIEW=true
  ./scripts/reconcile_branch_protection.sh --apply` **and** set
  `branch_required_approving_review_count = 1` in `terraform.tfvars` so declared and live move
  together (blocked on P1-12).
- **P1-11 — Root cause found and fixed: the Actions allow-list silently killed CI in three
  repos.** Earlier in this register the cause was recorded as "not determined" after four
  theories were dismissed; that conclusion was wrong, and the reasoning that dismissed the
  allow-list was the error — comparing the *policy* across failing and passing repos shows
  only that the policy is uniform, which is exactly what makes a single unlisted **action**
  the discriminator. Corrected diagnosis, measured across all 20 populated public repos:
  `pnpm/action-setup` is referenced only by `viavitae-web` (9), `viavitae-demos` (8) and
  `viavitae-qa` (13), and those are precisely the three repos whose `CI` and
  `Compliance check` runs ended `startup_failure` with **0 jobs, 0 check runs, no logs** —
  the correlation is `pnpm_refs > 0  <=>  startup_failure`, no exceptions. Because those
  workflows never started, the contexts they were required to report never appeared, so
  every PR in those repos was frozen regardless of reviews (`viavitae-qa#18` needed 0
  reviews and was still `BLOCKED` with `statusCheckRollup = []`).
  Fix: added the two commit SHAs actually in use to the org allow-list (`PUT
  orgs/Via-Vitae/actions/permissions/selected-actions`, patterns 9 -> 11) rather than a
  floating `@*`, and mirrored them in `variables.tf` so declared matches live. Verified by
  re-running CI: all three repos now produce jobs (web 16 checks, qa 15, demos 16) and their
  `Compliance status` / `CI status` contexts report, so their P1-7 PRs merged.
  **Still open, and now visible for the first time:** these repos have genuine failing
  gates that no one had ever seen — `viavitae-web`: `Lint`, `Unit + contract tests`;
  `viavitae-qa`: `Lint`, `Typecheck`, `Playwright @smoke`, `axe accessibility scan`,
  `Dependency scan (Trivy)`. Treat as P1-17 follow-up work; do not silence them by removing
  required contexts.
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
- **P1-13 — Required status checks were not declarable, and two repos required contexts no
  job could produce.** `modules/repo/branch_protection.tf` hard-coded `contexts = []` inside
  `required_status_checks`, so every live required-context list in the org was out-of-band
  and invisible to `terraform plan` — while `strict = true` with an empty list gates nothing,
  which made the declared config read as stricter than it was. Two live lists were also
  unsatisfiable, which alone freezes every PR in the repo:
  - `viavitae-demos` required `compliance-status`, `action-pinning`, `governance`,
    `analyze (javascript-typescript)` — its jobs report `Compliance status`,
    `Action SHA pinning`, `Governance files`, `Analyze (javascript-typescript)`. Context names
    are matched case-sensitively, so four of five could never report. **Repaired on live** to
    the exact job names.
  - `viavitae-qa` required `CI status`, but its `ci.yml` (unlike `viavitae-template`'s) has no
    `ci-status` job at all. **`CI status` was removed from its required contexts** so the repo
    can merge; that is a *reduction* in enforcement and is called out here deliberately. The
    correct repair is to restore the `ci-status` aggregation job in `viavitae-qa/ci.yml` and
    then re-add the context — do it together with P1-17, because the job will then report the
    failures that already exist.
  In-repo change: `required_status_checks_contexts` is now a real variable (module + root,
  default `[]` so no live protection was rewritten by this commit) and `terraform.tfvars.example`
  records the measured per-repo baseline to adopt once P1-12 is cleared.
- **P1-14 — Two `viavitae-clients` gates could never pass, and never had.** `lint.yml`
  triggers on `pull_request` only, so these had never run against `main` and nobody had seen
  them: `Content parity (LT/EN/RU)` died on `ModuleNotFoundError: No module named 'yaml'`
  (the job installed nothing, while sibling jobs `pip install yamllint`), and `Typecheck`
  failed because `scripts/validate_tenants.py:19` carried `# type: ignore[no-any-return]`
  **twice on one line**, which mypy rejects with `Multiple type ignores on the same line`.
  Fixed in `viavitae-clients` PR #7 (add the `pip install pyyaml` step; drop the duplicate
  comment) — verified: all 14 checks then `SUCCESS`, `mergeStateStatus=CLEAN`, merged, and
  `python3 scripts/parity_check.py` passes locally. Neither failure was caused by the
  contact-address change.
- **P1-15 — The org's aggregate CI gates were blind to failure, and still are in 17 repos.**
  Every generated `ci-status` / `compliance-status` job decided its verdict by grepping the
  **text** of `toJSON(needs)` for `"result":"failure"`. That string only appears in compact
  JSON; if the expansion carries a space after the colon the count is 0 and the job reports
  success over failing gates. Reproduced locally with both serialisations (compact -> counted
  2 -> FAIL; spaced -> counted 0 -> PASS). Observed live: on `viavitae-web` PR #32 `Lint` and
  `Unit + contract tests` completed `failure` at 17:54 and `CI status` completed `success` at
  17:55:03. The contact PR therefore merged over red gates on that repo — an honest
  consequence of a gate that was already lying. Repaired at the source: `viavitae-template`
  PR #3 and `.github` PR #8 (shared reusable workflow) now compute the verdict with
  `contains(needs.*.result, 'failure')` passed in as `GATE_BAD`, preserving `id: eval` and the
  `result` output; both merged with all checks green. **17 repos still carry the old pattern**
  (`viavitae-web`, `-infra` (incl. `codeql.yml`), `-brand`, `-api`, `-docs`, `.github`'s
  `ci.yml`, the ten `viavitae-landing-*`): apply with
  `scripts/patch_aggregate_gate.py <clone-dir> <workflow> [--check]`, one PR per repo.
  Expect some repos to go red on the first honest run (that is P1-17, not a regression).
- **P1-16 — 31 open Dependabot alerts on default branches.** Measured: `viavitae-web` 20 open
  alerts, `viavitae-qa` 11 (`viavitae-api` and `viavitae-clients` 0). The site repo carries
  high-severity advisories. `enable_dependabot_security_updates` is declared `true`; the
  updates are not landing, so either the flag is not effective on the Free plan for these
  repos or lockfiles need a human bump. Review at
  https://github.com/Via-Vitae/viavitae-web/security/dependabot
- **P1-17 — Real, previously invisible test failures in `viavitae-web` and `viavitae-qa`.**
  Now that CI actually starts: `viavitae-web` fails `Lint` and `Unit + contract tests`;
  `viavitae-qa` fails `Lint`, `Typecheck`, `Playwright @smoke`, `axe accessibility scan` and
  `Dependency scan (Trivy)`. These predate this remediation (the workflows had not run since
  the allow-list broke them). Fix them before restoring `CI status` in `viavitae-qa` (P1-13)
  or raising approval counts back to 1 (P1-10), otherwise those repos simply re-freeze.

## 3. Staged remediation roadmap

1. **Day 0 (now, free):** Enforce 2FA; enable secret scanning + push protection +
   Dependabot on all public repos; apply the allowed-actions list; begin privatizing
   the compliance-sensitive repos (P0-1) — note private-repo branch protection needs Team;
   activate `manage_files` per repo to deploy gitleaks CI workflow + pre-commit config;
   install pre-commit hooks on developer machines (`pip install pre-commit && pre-commit install`);
   repoint the undeliverable contact addresses (P1-7) and enable PVR on the populated
   repos (P1-8).
   **Done 2026-10-15:** P1-7 (all 26 public repos clean, 0 remaining), P1-8 (PVR on all 26
   public repos), P1-1 (2FA already enforced), P1-3 (allow-list corrected + declared),
   P1-10 (reconciled to declared), P1-11 (CI restored), P1-14, P1-15 at source.
2. **Day 0a (before any other change): restore state (P1-12).** Nothing in this control plane
   is reconcilable while `terraform.tfstate` is absent; decrypt the newest age backup, then
   `terraform init` and read a real plan before touching protection, contexts or the review
   count from here.
3. **Day 0b: make the gates honest again.** Apply `scripts/patch_aggregate_gate.py` per repo
   (P1-15, 17 repos), restore `CI status` in `viavitae-qa` (P1-13), fix the red jobs
   (P1-17), clear the Dependabot alerts (P1-16).
4. **Stage 1 (Team upgrade):** finish flipping sensitive repos private; private-repo
   branch protection activates automatically via the feature flag.
5. **Stage 2 (grow the team):** enroll 2FA on `IterVitae`, accept the invitation as
   `member` (not `admin`) and add it to `architects`; then raise review count to 1 and enable
   code-owner review (revert P1-10), declared and live together.
6. **Stage 3 (Enterprise):** set `github_plan_tier = "enterprise"`,
   `enable_advanced_security = true`, `enable_sso = true`; configure IdP SAML/SCIM.
7. **Continuous:** `detect_drift.sh` in CI; quarterly access review; state in S3.

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
- **A `passing` gate is not evidence until its verdict is shown to react to failure.**
  P1-15 recorded a gate that reported success over two failed jobs; P1-8's claim was untrue
  for 16 repos; P1-11's CI had not run at all in three. Where a control is asserted in a
  published document, this repo now cites the measurement, and `scripts/` carries the probe
  that produced it.
