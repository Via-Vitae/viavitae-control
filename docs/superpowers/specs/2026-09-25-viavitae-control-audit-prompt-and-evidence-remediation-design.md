# viavitae-control — Evidence-Gated Audit Prompt & Control-Plane Remediation (Design Spec)

- **Date:** 2026-09-25
- **Owner org:** `Via-Vitae` (GitHub Free plan)
- **Target repo:** `Via-Vitae/viavitae-control`, branch `main` (PR-only, `protect-main` ruleset, `bypass_actors: []`)
- **Local working dir:** `/opt/viavitae/repos/viavitae-control`
- **Compliance targets:** SOC 2, ISO 27001, GDPR
- **Execution authority:** **PLAN-ONLY.** No `terraform apply`. No live org mutation. No push to `main`.
- **Status:** Approved design; implementation = write prompt artifact + prepare reviewable PR + capture plan evidence

> Scope boundary: this control plane manages **Via-Vitae only**. It is separate from
> `jol-control`, which manages `journeyoflife-org`. The two are never mixed.

---

## 1. Problem

`viavitae-control` is architecturally sound but its **evidence chain is broken**. The
control plane currently *asserts more compliance than it enforces*: `docs/COMPLIANCE.md`
marks controls `✅` that are declared in configuration yet demonstrably absent from
Terraform state and from the live org.

This is the highest-risk condition in an audit. A `✅` that cannot be reproduced from
state or the live API is worse than an honestly declared gap: an auditor who samples one
false `✅` will distrust the entire matrix, including the controls that are genuinely
enforced.

Two outputs follow:

1. A **reusable, evidence-gated audit prompt** that makes this class of failure
   mechanically detectable every cycle.
2. A **remediation PR** that closes the P0/P1 findings and removes the incentive for
   the documentation to diverge from reality.

---

## 2. Verified baseline (empirical, 2026-09-25)

Method: configuration read + `terraform.tfstate` inspection + `terraform providers
schema -json` + read-only `gh api` against the live org. No prior report or document
was trusted.

### 2.1 Live org facts

- **30 repositories.** 21 non-empty with a real `main` branch; 9 empty (`size == 0`).
- **Visibility:** 25 `public`, 5 `private` (`viavitae-compliance`, `viavitae-data-governance`,
  `viavitae-policies`, `viavitae-threat-model`, `viavitae-vendor-register`).
- **Empty repos (9):** the 5 private above, plus `viavitae-observability`,
  `viavitae-reusable-workflows`, `viavitae-runbooks`, `viavitae-training`.
- **Org:** plan `free`; `two_factor_requirement_enabled = false`;
  `default_repository_permission = read`; `members_can_create_repositories = true`.
- **`protect-main` ruleset on `viavitae-control`:** live, `id 23943250`,
  `enforcement: active`, `bypass_actors: []`, `required_approving_review_count: 0`,
  `require_code_owner_review: false`, `require_extra_approval_for_unattributed_changes: true`.
- **`viavitae-control` live repo flags:** `has_wiki: true`, `has_projects: true`,
  `has_issues: true`; `secret_scanning`, `secret_scanning_push_protection` and
  `dependabot_security_updates` all `enabled`. No `CODEOWNERS` at either conventional path.
- **Toolchain:** provider `integrations/github` **6.13.0** installed (constraint `~> 6.6`
  satisfied); Terraform **1.16.1** installed; `.terraform-version` pins **1.9.8**.
- **State:** version 4, serial 6, written by Terraform **1.16.1**, containing exactly **5**
  resources — all `github_repository`, the 5 privatized compliance repos. Nothing else.

### 2.2 Provider capability verified

`two_factor_requirement_enabled` exists in provider 6.13.0 **only** as a `computed`
attribute on the `github_organization` **data source**. It is **absent** from the
`github_organization_settings` resource (full attribute list enumerated). Therefore
**org-wide 2FA cannot be enforced by Terraform** — it is permanently out-of-band and
requires a *detective* control, not a resource.

### 2.3 Findings register

| ID | Finding | Evidence | Sev |
|---|---|---|---|
| F1 | `protect-main` is live and active but **not in Terraform state**. The control repo's own protection is unmanaged. `COMPLIANCE.md` §4 asserts "No ruleset drift." | state has 5 `github_repository` only; ruleset match count 0 | **P0** |
| F2 | Live `viavitae-control` has `has_wiki: true`, `has_projects: true`; module declares both `false`. Control **C10 not applied to the control plane itself**. | `gh api repos/Via-Vitae/viavitae-control` vs `modules/repo/main.tf#L37-L38` | **P1** |
| F3 | `repo_rulesets.tf` and `policies/restore_peer_review.md` **untracked**; 13 further files modified but uncommitted. System of record on `main` ≠ working tree. | `git status`; `origin/main...main = 0 0` | **P0** |
| F4 | `repos_have_default_branch = false` is **stale**. 21 of 30 repos have a real `main`. Branch protection (C6) is deferred on 21 public repos that could be protected today — force-push and deletion are currently possible. `COMPLIANCE.md` P1-6 "All 30 repos are EMPTY" is false. | live `size`/`default_branch` per repo | **P0** |
| F5 | No `.github/` directory → **no CI**. `detect_drift.sh` never runs automatically, yet C2 is marked `✅`. | `ls .github` → not found | **P1** |
| F6 | Org-wide 2FA still **not enforced**; P1-1 open. Not IaC-settable (§2.2). | `gh api orgs/Via-Vitae` | **P1** |
| F7 | `README.md` §Status says "**Not pushed, not applied**". It is pushed (`main` == `origin/main`) and partially applied (5 resources in state). | git log / state | **P2** |
| F8 | Lockout-rollback runbook contains an **invalid jq expression** (`select(.name=="protect-main").id`, missing `|`) and a placeholder body (`--input <(jq ... ...)`). This is the emergency exit from a self-inflicted lockout. | `policies/restore_peer_review.md#L93-L95` | **P1** |
| F9 | Personal email address hardcoded as the `billing_email` default in a **public** repo, in two files, and present in immutable public git history (`48bb2ef`). | `git grep -n <billing_email value> HEAD` and `git log --all -S <billing_email value>` — the value is deliberately **not reproduced** in this spec, since the spec is itself committed to a public repo and copying it would extend the disclosure | **P2** |
| F10 | `.terraform-version` pins 1.9.8; toolchain in use is 1.16.1. Nothing enforces the pin. | file vs `terraform version` | **P2** |
| F11 | `outputs.tf` `p0_security_alerts` is a **hardcoded static list** still asserting "All 30 Via-Vitae repositories are PUBLIC, including compliance-sensitive ones" — false since `cf48dd5`. The control plane's auditor-facing alert output actively lies. | `outputs.tf#L37-L45` vs live visibility | **P1** |

### 2.4 Answer to the originating question

**`viavitae-control` is already correctly declared and must not be re-added.** It is in
the inventory (`repos_data.tf#L36-L45`, `tier = "control"`, `enable_branch_protection =
false`), and its protection is the `protect-main` ruleset rather than the module's classic
branch protection — a deliberate, documented choice that avoids two overlapping mechanisms
on one branch. Adding a second entry, or enabling classic branch protection alongside the
ruleset, would be a regression. What is wrong is not the declaration but its **application
and evidence** (F1, F2, F3).

---

## 3. Decisions

### D1 — Prompt architecture: staged evidence gates (Approach B)

Three approaches were considered.

- **A — Monolithic mega-prompt.** Rejected: no checkpoint at which a failed precondition
  stops the run; findings flatten into one list, burying P0 state drift beside a stale
  README line.
- **B — Staged evidence gates + fixed findings contract.** **Chosen.** Gates run in
  dependency order, because whether a control is *enforced* cannot be judged until it is
  known whether the config is committed and present in state. Each gate has exact
  commands, a required evidence artifact, explicit pass/fail criteria, and a hard STOP.
- **C — Machine-readable control catalogue.** Rejected: it would create a **third** source
  of truth beside `repos_data.tf` and `docs/COMPLIANCE.md`. Divergent duplicate catalogues
  are the root cause of F7/F11; adding one would worsen the disease.

B borrows only C's **fixed output schema**, so results are diffable cycle-over-cycle
without introducing a new authoritative document.

### D2 — Audience: AI agent, evidence-gated

The prompt is written to be pasted verbatim into an AI coding agent. It contains concrete
`gh` / `terraform` / `jq` verification commands, mandatory evidence capture, hard
pass/fail gates, and an explicit prohibition on trusting `README.md` or `COMPLIANCE.md`
claims. It is not a human audit programme.

### D3 — Authority: plan-only

The prompt binds the executing agent to read-only operations. `terraform plan`,
`gh api` GET, `terraform providers schema`, `git` inspection: permitted. `terraform
apply`, `gh api` PATCH/PUT/POST/DELETE, `git push` to `main`, visibility changes,
membership changes, 2FA changes: **prohibited**, with explicit stop-and-ask triggers.

### D4 — R8 and R10 in scope; R9 deferred and re-scoped

- **R8 (F7) — IN.** Same root cause as R7. Shipping a truth-in-documentation PR while a
  known-false statement sits in the README front door would be self-defeating.
- **R10 (F10) — IN.** R4 creates `.github/workflows/audit.yml`; the pin assertion is one
  step in a file that does not yet exist. Cheaper now than as a second PR.
- **R9 (F9) — DEFERRED to a follow-up PR, re-scoped.** A HEAD-only removal cannot
  remediate a disclosure already in immutable public history, and history rewrite is
  forbidden by `protect-main` (`non_fast_forward`, `required_linear_history`,
  `bypass_actors: []`). Presenting the removal as a GDPR fix would reproduce exactly the
  claim-vs-evidence divergence this spec exists to eliminate. The residual decision is
  human/legal, not technical. See §7.

### D5 — Root-cause fix: replace bare `✅` with a fixed status vocabulary

`docs/COMPLIANCE.md` currently uses `✅` / `⚠️` / `❌` where `✅` conflates *"declared in
config"* with *"enforced and verified live"*. This ambiguity is the mechanism by which
F2, F5, F6 and F11 became invisible. Every control row adopts one of exactly five
statuses, defined in §6.3.

---

## 4. Deliverable 1 — `policies/AUDIT_PROMPT.md`

Placed in `policies/` alongside `allowed_actions.md`, `sso_saml.md`,
`restore_peer_review.md`; registered in `policies/README.md`. Committed, therefore itself
under PR change control and re-runnable every audit cycle.

### 4.1 Document structure

| § | Section | Purpose |
|---|---|---|
| 0 | How to use | Paste verbatim; one full cycle; where evidence lands |
| 1 | Role & stance | Paranoid compliance-driven architect, 30+ years. SOC 2 / ISO 27001 / GDPR. Default posture: *documentation is a claim, not evidence* |
| 2 | Non-negotiable rules | Evidence or it did not happen · never trust repo docs — re-derive from state + live API · read-only · cite `file:line` **and** raw command output for every finding · **never reproduce personal data, tokens or secret material into a committed artifact** — reference by location and by a redacted placeholder, never by value |
| 3 | Scope | Org `Via-Vitae`; all 30 repos; the control-plane repo; 6 teams; Free plan |
| 4 | Authority boundary | Plan-only. Stop-and-ask triggers enumerated |
| 5 | Gates 0–5 | See §4.2 |
| 6 | Output contract | Findings JSON schema + report template |
| 7 | Severity rubric | P0/P1/P2 tied to exploitability and framework breach, not judgement |
| 8 | Anti-patterns | Doc-trust · sample-of-one generalization · silent gaps · deferred-reported-as-satisfied |

### 4.2 Gate definitions

Each gate specifies: **commands**, **required evidence**, **pass criteria**, **on-fail
action**. A gate that fails does not silently continue — it records a finding and, where
marked, STOPs the run.

| Gate | Question it answers | Fails today? |
|---|---|---|
| **0 — Preconditions** | Correct identity? Token scopes sufficient (`admin:org`, `repo`, `workflow`)? Toolchain == `.terraform-version`? Plan tier as expected? Org == `Via-Vitae` (not `journeyoflife-org`)? | F10 |
| **1 — Source-of-truth integrity** | Working tree clean? All control files tracked? Is `repo_rulesets.tf` committed? State git-ignored and untracked? No `terraform.tfvars` committed? | **F3 → STOP** |
| **2 — Three-way reconciliation** | For every declared resource: does it exist in **state**? Does state match the **live API**? Catches declared-but-unmanaged and managed-but-drifted. | **F1, F2** |
| **3 — Per-repo sweep (all 30)** | Per repo: visibility, emptiness, default branch, protection mechanism and its live parameters, secret scanning, push protection, Dependabot, CODEOWNERS presence, wiki/projects. Tabular, no sampling. | F4 |
| **4 — Control-matrix truthfulness** | Every `✅`/status in `docs/COMPLIANCE.md` must resolve to live evidence. Any that cannot is downgraded to a finding and the matrix corrected. | F5, F6, F11 |
| **5 — Framework mapping** | Each finding mapped to SOC 2 CC · ISO 27001 A-clause · GDPR Article. Unmappable findings are flagged as possibly spurious. | — |

**Gate ordering is load-bearing.** Gate 1 precedes Gate 2 because reconciling state against
an uncommitted working tree produces meaningless results. Gate 2 precedes Gate 3 because a
per-repo sweep interpreted without knowing what is in state mis-attributes cause.

### 4.3 Findings JSON schema (output contract)

```json
{
  "id": "VV-2026-09-001",
  "title": "protect-main ruleset live but absent from Terraform state",
  "severity": "P0",
  "control_id": "C1",
  "framework_refs": ["SOC2:CC8.1", "ISO27001:A.14.2", "GDPR:Art.32"],
  "declared": { "source": "docs/COMPLIANCE.md#L81-L83", "claim": "No ruleset drift" },
  "actual":   { "source": "gh api repos/Via-Vitae/viavitae-control/rulesets", "observed": "id 23943250 active; state contains 5 github_repository resources, no ruleset" },
  "evidence": ["<command> -> <verbatim output>"],
  "impact": "Control repo protection is not reproducible from code; a hand edit would be undetectable.",
  "remediation": "terraform apply the existing import block in repo_rulesets.tf",
  "verification_after_fix": "terraform state list | grep protect_main returns one entry",
  "owner": "human",
  "status": "open"
}
```

Every field is mandatory. `declared` and `actual` are the load-bearing pair: a finding
without both is an opinion, not an audit result.

### 4.4 Severity rubric

| Sev | Definition |
|---|---|
| **P0** | Live, exploitable now, **or** the system of record is not reproducible from committed code. Includes: unmanaged protection on the control plane; uncommitted control files; a control documented as enforced that is not enforced and whose absence permits history rewrite or data exposure. |
| **P1** | Framework control not enforced but not immediately exploitable, **or** auditor-facing documentation/output that is factually wrong, **or** a broken emergency/rollback path. |
| **P2** | Hygiene, reproducibility and minimisation issues with no direct control impact. |

Severity is assigned from the rubric, never from impression.

---

## 5. Deliverable 2 — Remediation (plan-only)

All work on one branch `fix/control-plane-evidence-integrity` → one PR to `main`.
No direct push: `protect-main` requires a PR and has no bypass actors.

| ID | Finding | Change | File(s) |
|---|---|---|---|
| **R1** | F3 (P0) | Commit untracked `repo_rulesets.tf`, `policies/restore_peer_review.md` and the 13 modified files. Split into reviewable commits: spec, then ruleset+runbook, then doc corrections. | working tree |
| **R2** | F4 (P0) | Add explicit `default_branch_exists = true` **per repo** for the 21 verified non-empty repos. Leave the 9 empty repos unset so they inherit the global `false` and stay honestly deferred. Do **not** flip the global `repos_have_default_branch` — that would attempt protection on empty repos and fail at apply. | `repos_data.tf` |
| **R3** | F1, F2 (P0/P1) | Capture `terraform plan` evidence for the full import: 25 repos + `protect_main` ruleset + org settings + Actions policy. Must show **import + in-place update, 0 to destroy**, including `has_wiki true→false` and `has_projects true→false` on `viavitae-control`. **Owner applies.** | evidence artifact |
| **R4** | F5 (P1) | Add CI: `terraform fmt -check`, `terraform validate`, toolchain-pin assertion (R10), `scripts/detect_drift.sh`. Only allow-listed actions (`actions/checkout@*`, `actions/setup-*`). **Honest caveat enforced in-code:** the default workflow `GITHUB_TOKEN` is repo-scoped and cannot list org repos, so drift detection requires an org-read secret; the job must **fail loudly when that secret is absent** rather than pass vacuously. | `.github/workflows/audit.yml` |
| **R5** | F8 (P1) | Rewrite the lockout-rollback procedure with a syntactically valid, complete command sequence (correct jq pipe; real `--input` payload, not a placeholder). Syntax verified read-only before committing. | `policies/restore_peer_review.md` |
| **R6** | F6, F11 (P1) | Add `data "github_organization" "this"` in a **new `org_data.tf`** (data sources kept separate from resources, matching the existing `repos_data.tf` convention). Replace the hardcoded `p0_security_alerts` strings with values **derived** from that data source and the inventory (2FA state, public/private counts, sensitive-tier-still-public list), so alerts cannot go stale. Add a plan-time `check` block for 2FA. Reword C12 to "out-of-band; detective control only — not IaC-settable in provider 6.13.0". | new `org_data.tf`, `outputs.tf`, `docs/COMPLIANCE.md` |
| **R7** | root cause | Replace bare `✅`/`⚠️`/`❌` in the control matrix with the five-value status vocabulary (§6.3). Add the rule: *a control may only be `enforced-verified` if live evidence is cited.* | `docs/COMPLIANCE.md` |
| **R8** | F7 (P2) | Correct §Status: pushed, partially applied (5 of 30 repos in state), ruleset pending import. | `README.md` |
| **R10** | F10 (P2) | Set `.terraform-version` to **1.16.1** — not 1.9.8. Decisive reason: the existing state snapshot records `terraform_version: 1.16.1`, and Terraform refuses to operate on state written by a newer version, so pinning *down* to 1.9.8 would break every future run. `required_version = "~> 1.9"` already permits 1.16.x and is left unchanged. Assert the pin in CI (R4). | `.terraform-version`, `.github/workflows/audit.yml` |

### 5.1 R2 — exact repo partition

`default_branch_exists = true` (21, all public):
`.github`, `viavitae-api`, `viavitae-brand`, `viavitae-clients`, `viavitae-control`,
`viavitae-demos`, `viavitae-docs`, `viavitae-infra`, `viavitae-landing-basilica`,
`viavitae-landing-cathedral`, `viavitae-landing-cemetery-services`,
`viavitae-landing-churches-orthodox`, `viavitae-landing-churches-other`,
`viavitae-landing-churches-protestant`, `viavitae-landing-deaneries`,
`viavitae-landing-diocese`, `viavitae-landing-funeral-services`,
`viavitae-landing-parish-church`, `viavitae-qa`, `viavitae-template`, `viavitae-web`.

Left unset → inherit global `false` (9):
`viavitae-compliance`, `viavitae-data-governance`, `viavitae-policies`,
`viavitae-threat-model`, `viavitae-vendor-register` (private — protection needs Team+
regardless), `viavitae-observability`, `viavitae-reusable-workflows`, `viavitae-runbooks`,
`viavitae-training` (public but empty).

Net effect once applied: **20 repos gain branch protection** (21 minus `viavitae-control`,
which is covered by `protect-main` and has `enable_branch_protection = false`). The 9
remaining stay in `branch_protection_deferred` and the `control_gaps` register — reported,
never silently dropped.

The per-repo override mechanism already exists (`locals.tf#L24`:
`lookup(r, "default_branch_exists", var.repos_have_default_branch)`), so R2 uses the
designed extension point and requires no schema change.

---

## 6. Non-destructive guarantees and status vocabulary

### 6.1 Guarantees

- `import` blocks adopt existing repos → plan shows import + in-place update, **0 destroys**.
- No repo visibility is changed by this work.
- `manage_files = false` everywhere → no CODEOWNERS or workflow is written into any repo.
- No `terraform apply` is run by the implementer. Owner applies after reviewing the plan.
- No `gh api` write verb is invoked at any point.
- Nothing is pushed to `main`; all changes arrive via PR.

### 6.2 Stop-and-ask triggers

The implementer and any future agent running the audit prompt must halt and ask before:
any `terraform apply`; any visibility change; enabling or altering 2FA; adding or removing
org members, teams or collaborators; raising `branch_required_approving_review_count`
above 0 (see `policies/restore_peer_review.md` — doing so with one eligible reviewer makes
`main` unmergeable and unpushable); any history rewrite; any deletion.

### 6.3 Control status vocabulary (replaces `✅`/`⚠️`/`❌`)

| Status | Meaning | Required citation |
|---|---|---|
| `enforced-verified` | Declared, in state, and confirmed against the live API | live API response |
| `declared-not-applied` | Present in config, absent from state — will enforce on next apply | state listing |
| `deferred-empty-repo` | Cannot apply because the target ref does not exist yet | repo `size == 0` |
| `gap-plan-tier` | Requires a paid GitHub plan the org does not have | plan tier + provider gating |
| `out-of-band` | Not IaC-settable; enforced by script, API or human process | provider schema evidence |

A control may not be marked `enforced-verified` without a cited live observation. This
single rule would have prevented F2, F5, F6 and F11.

---

## 7. Out of scope / follow-ups

1. **R9 — `billing_email` personal data (F9), re-scoped.** Follow-up PR containing:
   (a) remove the value from HEAD in **both** `variables.tf` and the 2026-09-24 spec;
   (b) add a `billing_email` entry to `terraform.tfvars.example` so a fresh clone can
   still plan; (c) record an explicit accepted-risk decision under GDPR Art. 5(1)(f)
   stating that the historical disclosure in commit `48bb2ef` is **irreducible** while
   `protect-main` forbids force-push and non-linear history. The choice between accepting
   the address as a published org contact and provisioning a non-personal alias is a
   human/legal decision and is **not** made here.
2. **`terraform apply` of R2/R3/R6** — owner-executed after plan review.
3. **Org-wide 2FA enforcement** — out-of-band via `policies/enforce_sso.sh`, after
   confirming the sole member has 2FA enrolled. Not IaC-settable (§2.2).
4. **Peer review restoration** — governed by `policies/restore_peer_review.md`; blocked on
   a second eligible reviewer. Explicitly not attempted here.
5. **S3 state backend migration** (`P1-4`) — separate change with its own bootstrap risk.
6. **CODEOWNERS activation** (`manage_files = true`) — writes files into 30 repos; needs
   its own staged, PR-reviewed decision.
7. **`jol-control` / `journeyoflife-org`** — different org, different control plane, never
   in scope.

---

## 8. Validation plan

Every step is read-only and its output is captured as an evidence artifact:

1. `terraform fmt -check -recursive`
2. `terraform validate`
3. `terraform providers schema -json` — re-confirm the §2.2 capability claim
4. `GITHUB_TOKEN=$(gh auth token) terraform plan -out=remediation.tfplan` — assert
   **0 to destroy**; assert the expected imports (25 repos + 1 ruleset + org settings +
   Actions policy) and the 20 new branch-protection resources from R2
5. `scripts/detect_drift.sh` — assert no shadow and no ghost repos
6. `git status --porcelain` on the branch — assert clean after R1
7. Re-run Gates 0–5 of the new audit prompt against the branch and confirm F1–F8, F10, F11
   are either closed or correctly re-classified with live evidence

**No `terraform apply`. No `git push` to `main`. No `gh api` write verb.**

---

## 9. Acceptance criteria

- `policies/AUDIT_PROMPT.md` exists, is registered in `policies/README.md`, and is
  self-contained: an agent given only that file can reproduce every finding in §2.3
  without reading this spec.
- All 11 findings are either remediated in the PR, or re-classified with an honest status
  from §6.3, or explicitly listed in §7 with a named owner.
- `terraform plan` on the branch shows **0 to destroy**.
- No control in `docs/COMPLIANCE.md` carries a bare `✅`.
- No document in the repo states anything contradicted by the live API.
- One PR, reviewable, with the plan output attached as evidence.
