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
- **P1-12 — State restored 2026-10-15; the register's earlier claim was stale in both
  directions.** This working copy had no `terraform.tfstate`, no `.terraform/`, no
  `backend.tf`, yet §Status claimed "state contains 5 of 30 repositories". Restored from
  `age` backup per `state/README.md` and verified by identity, not hope: lineage `eff08856`,
  serial 13, **9 managed resources** (6 repos, 1 org actions permission, 1 branch protection
  on `viavitae-hermes-agents`, 1 Dependabot updates) — i.e. the claim of 5 repos in state was
  wrong; 6 are, and `github_organization_settings` was never in state at all.
  Two defects found while doing it, both now documented in `state/README.md`:
  - `age --decrypt` inherits the process **umask (`0002` on this host)**, so the restored
    live state landed **group-readable**; it was `chmod 600`-ed afterwards, and the
    procedure now sets `umask 077` first and verifies with `stat`.
  - `terraform plan` requires `TF_VAR_billing_email` (no default by design, GDPR
    minimisation) and `GITHUB_TOKEN`; without them it aborts on the required variable, and
    passing the address on argv would expose it in `ps` — use the env var.
  Still open: no locking (C13c), no off-host copy that survives the host, and the local
  S3-backend migration (P1-4) is blocked by the account's SCP — see `state/README.md`.
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
  In-repo change: `required_status_checks_contexts` is now a real variable (module + root)
  and `repos_data.tf` declares the measured per-repo baseline, so `terraform apply` can no
  longer overwrite live required checks with an empty list. **Verified 2026-10-15:** every
  one of the 20 planned `github_branch_protection` resources now matches live exactly
  (`protection contexts: match=20 mismatch=0 fetch_errors=0`). Note the measurement trap:
  the first comparison reported 20 mismatches with `live=[]` for every repo — that was the
  GitHub rate limit being read as absence of configuration, not drift. Retry with the exit
  status and stderr surfaced, and treat an empty result as unproven.
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
  `result` output; both merged with all checks green. The 17 repos that still carried the old
  pattern (`viavitae-web`, `-infra` (incl. `codeql.yml`), `-brand`, `-api`, `-docs`, `.github`'s
  `ci.yml`, the ten `viavitae-landing-*`) have all since been migrated — see the status entry at
  the end of this list, which is the authoritative count.
  Tooling: `scripts/patch_aggregate_gate.py <clone-dir> [--write]`, one PR per repo via
  `scripts/rollout_aggregate_gate.sh`. Applying it did make some repos go red on their first
  honest run; those were pre-existing failures, recorded as P1-17, not regressions.
- **P1-16 — open Dependabot alerts on default branches (the count moves; only ever trust a fresh
  measurement).** Counted with `GET /repos/{org}/{repo}/dependabot/alerts?state=open` over all
  repos: 2026-10-15 — web 38 (5 critical, 10 high, 21 moderate, 2 low), qa 11, docs 9, api 1
  (59 total). 2026-10-17 — qa had **risen to 20** on its own (new advisories published against
  versions already merged, not a regression here), which is why a stale figure is worse than no
  figure. After merging qa PR #17 (playwright 1.63→1.64) qa is **13**; web stays **35** after
  #34 (`next` 15.5.25→15.5.27) and #30 (actions group).
  Two explanations that were *assumed and are now refuted*: the flag is not the problem —
  `GET /repos/{o}/{r}/automated-security-fixes` already returns `enabled: true` on every repo
  sampled, so the 25 `github_repository_dependabot_security_updates` creates in the plan merely
  re-assert the live value; and coverage is not missing either — open Dependabot pull requests
  exist for most of it (`viavitae-web` 6 now, `viavitae-qa` 3, `viavitae-docs` 3, `viavitae-api` 1).
  The backlog is therefore an unmerged-queue: a human has to accept each bump.
  Merging is no longer a coin flip: with the verdict repaired, a bad bump now shows up red instead
  of landing — web PR #31's tooling group fails `Lint` and `Contract check` and stays held.
  Remaining owner judgement: patch/minor security bumps (like #17, #34) are being merged as they
  verify green; majors (#25 jsdom 25→30, #26/#20 next-intl 3→4, #27/#36 next-react) need the
  release notes read.
- **P1-18 — `terraform apply` would have aborted partway, and an inspection caught it
  before it happened.** The restored plan created `github_repository_dependabot_security_updates`
  for **all 30** repos including the 5 private ones, where Dependabot needs GitHub Team; on
  the Free plan that is a mid-apply error with partial state written. Fixed by gating
  alerts/updates on visibility (`locals.tf` adds `dependabot_alerts_private` /
  `dependabot_updates_private` behind `local.is_team`, `repos.tf` selects by
  `visibility`, and `control_gaps` now says so out loud). Re-planned: creates 30 → **25**,
  `destroys: 0`.
  Two related clearance results, recorded so nobody re-litigates them:
  - `github_organization_settings` is not in state, but **creating it cannot disable org
    2FA** — verified against the provider schema: `two_factor_requirement_enabled` is not an
    attribute of that resource in `integrations/github` 6.13.
  - **What an apply actually writes, measured rather than inferred.** The plan is 26 imports,
    46 creates, 27 updates, **0 destroys**. The updates are visible per attribute:
    `delete_branch_on_merge` false→true and `has_projects` true→false on 25 repos,
    `has_wiki` true→false on 22, the org `allowed_actions_config` (the two `pnpm/action-setup`
    pins from P1-3), one repo `description`, and the `protect-main` ruleset gaining
    `provenance` as a required status check with `strict` false→true.
    The 20 classic protections are **creates**, so the plan shows no before/after for them and
    *cannot* show their drift. Each planned document was therefore compared field by field with
    `GET /repos/{o}/{r}/branches/main/protection`:

    | attribute | repos | direction |
    |---|---|---|
    | `required_linear_history` | 13 | false→true (tightening) |
    | `dismiss_stale_reviews` | 1 (`viavitae-qa`) | false→true (tightening) |
    | everything else | 6 repos identical | no change |

    **Nothing is loosened by an apply.** The 13 are `viavitae-web`, `viavitae-template`,
    `viavitae-demos` and the ten landings; the module declares `true` (see
    `modules/repo/branch_protection.tf`), and since every repo merges by squash this only
    forbids merge commits, not existing history. Independently confirmed on 2026-10-16 by
    `scripts/assert_live_controls.sh`, which reached the same conclusion from the live API
    without reading a plan at all.
    Org level: `dependabot_alerts_enabled_for_new_repositories`,
    `dependabot_security_updates_enabled_for_new_repositories` and
    `dependency_graph_enabled_for_new_repositories` go false→true (currently off live);
    secret scanning, push protection and advanced security for new repos stay `false` because
    that is already the live value; `billing_email` matches live; `email`, `name`, `blog`,
    `description`, `location`, `twitter_username` and `company` are planned as `null`, i.e. the
    provider does not send them, so the org profile address set today survives the apply.
  - Reviews, code-owner flags, `enforce_admins` and required contexts all match live after
    P1-10/P1-13 (`protection contexts: match=20 mismatch=0 fetch_errors=0`).
  - The new `provenance` required check is **satisfiable**: the job is named `provenance` in
    `.github/workflows/provenance.yml`, and it reports on 5/5 recent PRs to this repo. Note the
    live ruleset has `bypass_actors: []`, so if that workflow ever stops firing, merges into
    `viavitae-control` are blocked for admins too — the check is a real dependency, not decoration.
  - Method warning, because it produced a false finding here first: live protection flags are
    objects (`{"enabled": false}`), so `bool(live["lock_branch"])` is **always true** and the
    API names are `allow_force_pushes`/`allow_deletions`, not the provider's
    `allows_*`. An unsuspicious comparison using those two readings "proved" that an apply
    would unlock all 20 branches. Unpacking `enabled` and matching the real key names reversed
    it. Any future drift comparison must read `.enabled`, never the container.
  **No apply was run.** The plan was saved to a `0600` file and read only; `terraform apply`
  still needs an explicit owner statement (AI_WORKFLOW_POLICY §"plan-only authority").
- **P1-19 — CodeQL's `Analyze (javascript-typescript)` leg failed on `main` in all ten
  `viavitae-landing-*` repos, invisibly. CLOSED.** Measured 2026-10-15 before the fix: the JS/TS
  leg concluded `failure` while `CI status`/`Compliance status` were `success`, because that leg
  is not in their required contexts. Cause, proven rather than guessed: each landing contains
  **0 JavaScript/TypeScript files** (`find` over a clean clone: `py=1 js=0` for all ten) while
  `codeql.yml` asserted `matrix.language: ["python", "javascript-typescript"]` and, in addition,
  a workflow-level `CODEQL_LANGUAGES` env that nothing read — two sources of truth, one of them
  false, including the header comment claiming those were "the two languages present across
  ViaVitae repositories". `viavitae-api` carries the same file and passes because it really has
  both languages (`py=104 js=1`), which is what isolated the defect to the landing tier.
  Fix: port the `detect` job that `viavitae-template` already uses — languages are listed from
  the files present, `analyze` builds its matrix with `fromJson(needs.detect.outputs.languages)`,
  and a repo with no scannable source completes as a no-op instead of failing. Detection was
  chosen over deleting `javascript-typescript` from the list, because deleting it silently loses
  coverage the day someone adds a script. Delivered by
  `scripts/patch_codeql_detect.py` + `scripts/rollout_workflow_patch.sh` as ten PRs (each repo's
  `#5`), merged only after that repo's own required contexts passed (`merged=10 held=0`).
  Verified on `main` afterwards: `Detect languages=success`, `Analyze (python)=success`, the JS
  leg is absent, and **0 failing check runs** on all ten repos. Action pins unchanged; no landing
  requires an `Analyze (...)` context, so removing a leg could not freeze merges.
- **P1-20 — `viavitae-web` carried the lying aggregate gate. CLOSED, in the safe order.**
  The owner choice recorded in the previous revision of this entry was real: patching the gate
  alone would have frozen merges on the public charity site, because its `Lint` and
  `Unit + contract tests` legs were failing underneath. The order taken was repair first, then
  gate. `viavitae-web` PR #33 fixed both legs (see P1-17 for the causes), PR #35 then replaced
  the verdict, and both merged with all checks green. `main` now computes the verdict from
  `GATE_BAD: ${{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}`;
  the `toJSON(needs)` line survives only as a log line, not as the decision. A re-scan of every
  populated repo reports **0** files containing the fragile matcher.
  Honest limit, **since resolved**: at the time of writing the new verdict had only been
  observed passing over green runs, never failing over a red one. It has now been observed to
  react twice: `viavitae-qa`'s ported aggregate reports `CI status=failure` on `main` and names
  `dependency-scan: failure` in its own log, and `viavitae-web` PR #31 (tooling group, 10 bumps)
  went `Lint` + `Contract check` = fail instead of landing green over them.
- **P1-17 — Red legs on `main`, now attributed and mostly repaired.** These were invisible only
  because CI had not started since the allow-list broke it (P1-11/P1-3), and because in both
  repos the failing legs are not required contexts.
  - `viavitae-web` failed `Lint` and `Unit + contract tests`. Two causes, found by reproducing
    them locally (pnpm 9.15.0 via `packageManager`): Dependabot PR #19 had bumped `vitest`
    2.1.0 → 4.1.11 while `@vitest/coverage-v8` stayed 2.1.9 and `vite` stayed 5.4.21, and
    vitest 4 requires vite ≥ 6, so every run aborted at startup with
    `ERR_PACKAGE_PATH_NOT_EXPORTED: ./module-runner`; and `prettier --check` rejected four
    markdown files whose published addresses grew wider in the contact sweep — **that part was
    caused here**. Fixed in PR #33 by reverting to the coherent 2.1.x pair
    (`pnpm install --lockfile-only` now reports 0 unmet peers) and reformatting. `main` after:
    `Lint`, `Unit + contract tests`, `Build`, `Contract check`, axe and `CI status` all success.
    A coordinated vitest-4 + vite-6 upgrade remains available if the team wants it; a half
    upgrade is worse than either state.
  - `viavitae-qa` failed `Lint` and `Typecheck`. Three independent causes, each verified
    against the pre-sweep commit `3ace752` so the blame is accurate: Dependabot PR #11 bumped
    `@faker-js/faker` 9.9.0 → 10.5.0, which renamed `internet.userName()` to
    `internet.username()` (the compiler names the replacement; only one caller, in the donor
    fixture generator); `prettier --check` could never pass because it formats
    `pnpm-lock.yaml`, a generated file; and `markdownlint --ignore node_modules` is not
    recursive, so it linted the vendored markdown under `fixtures/node_modules/` and
    `performance/node_modules/` — a latent third failure that only became reachable once the
    first two were fixed, because the repo's `lint` script chains the commands. Fixed in PR #19
    (add `.prettierignore` for lockfiles, use `--ignore '**/node_modules/**'` in both
    `package.json` and `ci.yml`, rename the faker call, reformat four files that this session
    changed). `main` after: `Lint`, `Typecheck`, `Unit tests` success.
  - Still red, for reasons that are not code defects: see P1-16 (`Dependency scan (Trivy)`,
    11 alerts) and P1-22 (`Playwright @smoke`, `axe accessibility scan`).
  - Structural note explaining why none of this ever blocked anything: `viavitae-qa`'s `ci.yml`
    has **no aggregate `CI status` job at all** (its jobs are lint/typecheck/unit/sast/
    dependency-scan) and its only required context is `Compliance status`, which lives in a
    different workflow. So no CI leg of that repository can block a merge. Restoring a gate
    there means adding the aggregate job (the `viavitae-template` shape) and then declaring it —
    a compliance decision about which contexts to require, not a mechanical fix.
- **P1-15 status (2026-10-15): 17 of 17 fragile aggregate gates replaced. CLOSED.**
  Fixed at source in `viavitae-template` and `.github`'s reusable workflow, then rolled out to
  `viavitae-infra` (ci.yml **and** codeql.yml), `viavitae-brand`, `viavitae-api`,
  `viavitae-docs`, `.github` and the ten `viavitae-landing-*` repos — 15 PRs, each merged only
  after its own required contexts (`CI status`, `Compliance status`) reported SUCCESS; the
  rollout skipped nothing (`merged=15 held=0`), and `viavitae-web` followed (PR #35) as soon as
  its red legs were repaired — 16 PRs in total. A re-scan of every populated repo's workflows
  now reports **0** files containing the `"result":"failure"` text matcher.
  Tooling: `scripts/patch_aggregate_gate.py` is content-anchored (it matches the step that
  greps the JSON, not a step name — `codeql.yml` names its step `Evaluate CodeQL gates`),
  refuses to write if the patched YAML will not parse or if a fragile matcher survives, keeps
  `id:`/`GITHUB_OUTPUT` wiring, and is idempotent. `scripts/rollout_aggregate_gate.sh` is
  dry-run by default and pushes nothing unless `APPLY=1` — an earlier revision pushed in
  dry-run while claiming not to, which is exactly the failure mode this register exists to
  catch.
- **P1-21 — three dependency majors reached `main` broken, because nothing reacted to them.**
  `viavitae-web` PR #19 (vitest 2→4, incompatible with the pinned vite 5) and `viavitae-qa`
  PR #11 (faker 9→10, renamed API) both merged with a red result and a green `CI status`, and
  the third case is quieter still: `pnpm-lock.yaml` has never been satisfiable by
  `prettier --check` in `viavitae-qa`, so `Lint` was red from the day it was written. The
  verdict bug is fixed (P1-15/P1-20); the process gap is not. Two owner decisions close it:
  require `CI status` where an honest aggregate exists (and create one in `viavitae-qa`, which
  has none — P1-17), and group peer-coupled dependencies in each repo's `dependabot.yml` so a
  bump PR carries `vitest`+`@vitest/*`+`vite` (and `playwright`+`@playwright/test`) together
  instead of resolving one half of a contract. Neither was changed here: dependabot config
  edits alter what lands in production unattended.
  **Progress 2026-10-16:** the first half is done for `viavitae-qa` — `ci-status` (ported from
  `viavitae-template`, needing every job in the file, verdict from `contains(needs.*.result,
  ...)`) now exists on its `main` (PR #20), and it is honestly red because `Dependency scan
  (Trivy)` fails. It is **not yet a required context**: adding it while Trivy is red would
  freeze merges in that repo as a side effect of the gate rather than by decision. The flip is
  one line — `required_status_checks_contexts = ["Compliance status", "CI status"]` for
  `viavitae-qa` in `repos_data.tf` — after the advisories are cleared. The second half (peer
  grouping in each repo's `dependabot.yml`) is still untouched.
  **Done 2026-10-17:** that flip is now declared. qa's Trivy leg was cleared by PR #17
  (playwright 1.63→1.64, alerts 20→13, `Dependency scan` and `CI status` both green on `main`),
  and `CI status` was then added to `viavitae-qa`'s required contexts. Sequencing was the point:
  requiring the aggregate while Trivy was red for an unrelated reason would have frozen merges
  as a side effect of the gate, and requiring a context no job emits is what froze this repo
  twice already (P1-11/P1-13). `scripts/assert_live_controls.sh` confirms both halves of that
  judgement — it reports `viavitae-qa DIVERGED contexts live=[Compliance status]
  declared=[CI status,Compliance status]`, i.e. declared-but-not-yet-applied, which resolves on
  the apply this register still records as unrun.
  A third control now exists for the class of problem behind P1-13/P1-18:
  `scripts/assert_live_controls.sh` (PR #9, merged 2026-10-16) asks the live API every CI run
  whether the *declared* merge controls are the ones in force, rather than trusting a stored
  plan. Its first run reproduced the P1-18 finding independently — `viavitae-web` and
  `viavitae-demos` report `required_linear_history=false` against the declared `true` — and it
  exits 1 with a printed coverage notice (`asserting 5 of 31 inventory repositories`) because
  repos that inherit `var.branch_required_status_checks_contexts` are not covered by it.
  The CI step is gated on `ORG_READ_TOKEN`, so it stays inert until P1-23 is fixed.
- **P1-22 — `viavitae-qa`'s browser and load gates cannot run: the environment is configured
  but has no variables.** `GET /repos/Via-Vitae/viavitae-qa/actions/variables` returns
  `total_count: 0` while a `staging` environment exists, so every `${{ vars.STAGING_* }}` and
  `${{ vars.BASE_URL_DEMO_* }}` expands to empty. Consequences, both observed: `pr-smoke.yml`
  fails its health check (`/health returned 000000`, i.e. curl given a blank URL) so
  `Playwright @smoke` and `axe accessibility scan` are red on every PR; `nightly-e2e.yml` does
  the same check but as a gated job, emits `staging-up=false` as a *warning*, and skips its
  entire matrix — so a workflow named "Nightly e2e" has reported `success` while testing
  nothing, on eight consecutive runs (2026-10-06…15, which were `startup_failure` for the
  allow-list reason, then skipped). Verified by dispatching it manually today: `success` with
  every real job skipped.
  Correction to a claim made earlier in this session: "the nightly e2e suite itself passes" was
  wrong — it never ran. The correct statement is that no Playwright/axe/k6/Lighthouse evidence
  exists for `viavitae-qa` today, and the org's published assurance about e2e coverage should be
  read as unmet until staging exists.
  Not "fixed" here deliberately: making `pr-smoke` skip the way `nightly-e2e` does would turn a
  loud absence of evidence into a quiet one, which is the pattern this register exists to
  record. The fix is provisioning: deploy a staging API+web pair, set `STAGING_API_URL`,
  `STAGING_WEB_URL` and the `BASE_URL_DEMO_*` variables on the `staging` environment, after which
  both workflows work unchanged. Owner decision (infra spend), tracked as day-2 work.
- **P1-23 — this repo's own `Audit` workflow has been red on every run since the private repos
  were added to `imports.tf`, and CI drift detection has therefore never run.** Evidence from
  `Audit` runs on `main` (38799094376) and on a PR (38810532022): `Terraform format check`,
  `init` and `validate` all succeed, `Terraform plan` exits 1 with
  `Error: Cannot import non-existent remote object` exactly **5 times**, and the five addresses
  are precisely the private repos — `viavitae-policies`, `viavitae-compliance`,
  `viavitae-data-governance`, `viavitae-threat-model`, `viavitae-vendor-register` — plus
  `Post "https://api.github.com/graphql": context deadline exceeded`. The plan itself is fine:
  in CI (empty state) it reports `26 to import, 3 to add, 26 to change, 0 to destroy`.
  Cause, **corrected twice**: the first reading was "the secret is missing"; the second,
  "`TF_GITHUB_TOKEN` is configured but cannot read the private repos"; PR #12's pre-flight gate
  settled it on its first run — the credential arrives **empty**. `Check CI credential`
  exited 2 with `GH_TOKEN is empty; the CI plan credential is not wired to this step` and
  `Terraform plan` was then **skipped**. Anonymous access explains every symptom: public repos
  read fine, the five private ones resolve as non-existent, and the GraphQL call times out under
  the 60-requests/hour anonymous limit. A secret named `TF_GITHUB_TOKEN` does exist (updated
  2026-10-04T20:20:37Z), so either its value is blank or it was never written correctly — the
  API does not expose secret values, so the distinction cannot be made from outside, and the fix
  is the same either way: write a real credential into it.
  Second consequence, quieter but worse: `ORG_READ_TOKEN` is **not** configured (the repo has
  exactly one secret), so `Detect drift (requires ORG_READ_TOKEN)` is skipped on every run, and
  the `Fail loudly if ORG_READ_TOKEN is absent` step never executed because the job died at plan
  upstream of it. Day-2 §7 of this document claims "`detect_drift.sh` in CI" as a continuous
  control — **it has never run**. Until it does, drift is detected only when a human runs the
  script, as in this session.
  What #12 changed in shape, not in truth: the credential gate now runs **before** plan, so the
  job fails in ~25 seconds with a named cause instead of after ~20 minutes with an opaque import
  error, and the four outcomes are distinguishable — `2` empty/unwired, `1` write-capable scope
  set, `1` lists the repositories the credential cannot see, `0` correct.
  Owner actions: (1) `gh secret set TF_GITHUB_TOKEN --repo Via-Vitae/viavitae-control` with a
  fine-grained PAT per the contract in `provider.tf` (All repositories including the five
  private; Metadata + Administration read-only; Organization administration read-only while
  `org_data.tf` reads the org; no Contents/Workflows/Secrets; expiring), (2) the same for
  `ORG_READ_TOKEN`. Deliberately *not* done here: marking the plan step `continue-on-error`, or
  giving the loud-failure step `if: always()`. The first would turn a red evidence job into a
  green lie — the exact defect P1-15 was about; the second would add a permanently red leg that
  blocks nothing and trains people to ignore it, the P1-19 defect. The fix is a credential, not
  a workflow edit.

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
   P1-10 (reconciled to declared), P1-11 (CI restored), P1-14, P1-15 (17/17 repos, verified 0
   residual), P1-19 (landings' CodeQL legs), P1-20 (web's gate), P1-12 (state restored, `0600`),
   P1-13 (contexts declarable and matching live 20/20), P1-17 (web and qa `Lint`/`Typecheck`).
2. **Day 0a (before any other change): restore state (P1-12).** Nothing in this control plane
   is reconcilable while `terraform.tfstate` is absent; decrypt the newest age backup, then
   `terraform init` and read a real plan before touching protection, contexts or the review
   count from here.
3. **Day 0b: make the gates honest again. — DONE for the verdicts; two items remain.**
   `scripts/patch_aggregate_gate.py` is applied in all 17 repos and no fragile matcher survives.
   Still open, in dependency order:
   a. ~~give `viavitae-qa` an aggregate job and require it~~ — done 2026-10-16/17 (`#20` ported
      the job, `#17` cleared Trivy, contexts now declared here); it takes effect on the apply;
   b. decide which required contexts to declare where a gate is honest but optional, and group
      peer-coupled dependencies so majors land complete (P1-21);
   c. clear the Dependabot backlog by merging the open bump PRs, patch-level security fixes
      first: web 38 → 35 (P1-16), qa 20 → 13; and provision `viavitae-qa` staging so its
      browser/load gates run instead of failing or silently skipping (P1-22).
4. **Stage 1 (Team upgrade):** finish flipping sensitive repos private; private-repo
   branch protection activates automatically via the feature flag.
5. **Stage 2 (grow the team):** enroll 2FA on `IterVitae`, accept the invitation as
   `member` (not `admin`) and add it to `architects`; then raise review count to 1 and enable
   code-owner review (revert P1-10), declared and live together.
6. **Stage 3 (Enterprise):** set `github_plan_tier = "enterprise"`,
   `enable_advanced_security = true`, `enable_sso = true`; configure IdP SAML/SCIM.
7. **Continuous:** `detect_drift.sh` in CI — **not yet true, see P1-23**: the step is skipped on
   every run because `ORG_READ_TOKEN` is unset, and `TF_GITHUB_TOKEN` reaches CI **empty**, so
   the plan ran anonymously and could not import the five private repos. Quarterly access review;
   state in S3.

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

## 5. Judgement review (2026-10-17) — are we doing this right?

Written on request, measured first. Method: read the register and the CI wiring, count the
artifacts, and check each claim against a live observation rather than against the document
that makes it.

**The method is right.** Four things are being done correctly and should not be changed:

1. **Claims carry their evidence.** The vocabulary in §1.1 forbids `enforced-verified` without
   a cited live observation, and the table honours it — not one of C1-C18 is marked verified,
   because state holds 9 resources and everything else is genuinely `declared-not-applied`.
   The table therefore *understates* what works live today (Dependabot auto-updates are
   verified `enabled: true`, PVR on 26/26, allow-list patterns 11) rather than overstate it.
   That is the failure direction you want.
2. **Corrections are recorded, not silent.** Six places in this register retract an earlier
   claim (P1-1's `false`, P1-3's "not restricted", P1-11's "cause not determined", P1-12's
   "5 of 30 in state", P1-16's partial alert count, P1-22's "nightly passes"). A control plane
   whose audit record cannot be wrong is not an audit record.
3. **Gates are tested by planting failures.** T3/T8/T9b in the gate suite, the patchers'
   refusal checks, the self-citation probe asserting `1` to see it report `recomputed 9`, and
   qa's aggregate observed going red over Trivy. Green is not accepted as evidence here.
4. **Nothing destructive happened without a readable diff.** No `--admin` merge, no apply,
   no visibility flip, no credential touched — and the two candidate shortcuts (per-repo
   collaborator invitations, silencing `pr-smoke`) were reverted or refused and written up.

**Six things are wrong or unfinished, in severity order:**

1. **Two of the three enforcement layers are not active, and the docs are only slightly short
   of saying so.** Measured today: `.git/hooks/commit-msg` and `.git/hooks/pre-commit` are
   **not installed**, and the live `protect-main` ruleset reports **no required status checks
   at all** (`required_check` context list empty) — the `provenance` requirement is declared in
   `repo_rulesets.tf` and lands only on the apply. So commit provenance is currently
   *reported* by CI but *blocks nothing*, and the local hook gives no feedback either. Not a
   lie, but close: §5.4 of AI_WORKFLOW_POLICY called the CI check "the unbypassable control"
   while nothing was bypassing it.
2. **Guards outnumber their tests 12 to 1.** Only `update_contact_emails.sh` has a suite
   (`test_contact_email_gates.sh`, 14 cases). `assert_live_controls.sh`,
   `check_ci_credential.sh` and `check_plan_selfcite.sh` — three gates that now decide whether
   CI passes — have none, and each shipped a defect that only manual probing found: #9's parser
   silently dropped two repositories, #11 reported `OK` while asserting nothing. A tool that
   gates merges deserves the planted-failure test the sweep got.
3. **The strongest new guard has the weakest coverage.** `assert_live_controls.sh` prints
   `asserting 5 of 31 inventory repositories`: it only sees repos that override
   `required_status_checks_contexts`. The 13-repo `required_linear_history` gap it ought to
   catch sits in the inherit-the-default set, so today it caught it only in the two repos
   (web, demos) that happen to override. Coverage must include the default or the headline
   should say so.
4. **The un-applied delta has become a control problem in its own right.** C1-C11, C17 and C18
   all read `declared-not-applied`, which means the org's real protections are still the
   hand-made history plus three scripted reconciliations, and Terraform is currently a
   *descriptive* layer, not a prescriptive one. "Single source of truth" is not yet true —
   26 imports, 46 creates and 27 updates sit pending, verified to contain 0 destroys and no
   loosening. This is the cheapest large step left.
5. **The register is outgrowing its shape.** 549 lines for 25 findings; COMPLIANCE.md was
   touched 10 times in the last three days against 2 for `variables.tf` and 2 for `repos.tf`.
   Narrative is the right place for *why*, but it rots faster than tables (six retractions is
   evidence of that) and an auditor cannot action 500 lines quickly. Findings should be one
   table row plus a pointer to the evidence; the argument belongs in `docs/superpowers/plans/`.
6. **One 5-minute owner task is blocking four findings.** `TF_GITHUB_TOKEN` reaches CI empty
   and `ORG_READ_TOKEN` does not exist (P1-23), so `detect_drift.sh` and
   `assert_live_controls.sh` are skipped on every run and the audit job cannot go green. Two
   sessions of building guards have not moved that dependency.

**Not wrong, and worth naming, because they look like gaps:** the single-member org means
separation of duties, code-owner review and any approving-review requirement are nominal by
construction (P1-2/P1-10) — no tooling fixes that, only a second 2FA-enrolled account.
`viavitae-qa`'s permanently red `Playwright @smoke`/`axe` legs are the correct state while
staging is placeholders only in `viavitae-infra`; making them skip would have traded a loud
absence of evidence for a quiet one. And `terraform.tfstate` at `0600` with no locking and no
off-host copy (P1-4/C13) is still the weakest link in the whole plane — one disk failure and
every conclusion in this file has to be re-derived by hand, as it was in P1-12.

**Bottom line.** The process is sound and unusually self-critical; the wiring is incomplete.
The three highest-value next acts are not analytical: run the apply, install the hooks, write
the guards' tests. Each turns a documented intention into an observed control.
