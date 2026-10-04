# Drift Adoption and Control Staging — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** make `terraform apply` safe and reviewable in this control plane by separating state adoption, repository hardening, and merge-control changes into individually verifiable stages, and by adopting live branch protection through **import** instead of create-overwrite.

**Architecture:** today one plan bundles four unrelated intentions (`26 to import, 51 to add, 27 to change, 0 to destroy`) and `-target` cannot separate them because import blocks are evaluated regardless. The fix is temporal, not structural: repair state, then make adoption non-destructive, then land hardening, then onboard controls one repo at a time — each stage with a stated expected plan delta and a live assertion afterwards. Non-destructive because every adoption is an import of what already exists, never a PUT that replaces it.

**Tech Stack:** Terraform 1.16.1, `integrations/github` provider 6.13.0, `gh` CLI (GET only), `jq`, Bash. Org: `Via-Vitae`, plan: **free**.

**Authority boundary:** plan-only per `policies/AI_WORKFLOW_POLICY.md` §3.13/§4. `terraform apply` (including `-refresh-only`), `gh api` write verbs, and `git push` to `main` are **prohibited** until the owner authorizes each one explicitly, per stage.

**Related spec:** [`docs/superpowers/specs/2026-09-24-viavitae-control-github-control-plane-design.md`](../specs/2026-09-24-viavitae-control-github-control-plane-design.md)
(control-plane design) and
[`docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md`](../specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md)
(defines the `VV-2026-09-*` register this plan closes)
**Related findings:** VV-2026-09-002 (protection overwrite), VV-2026-09-003 (state is not the system of record), VV-2026-09-005 (drift detection compares names only)
**Related changes:** PR #7 (per-repo `required_status_checks_contexts`), PR #8 (`manage_org_settings` gate), PR #9 (`scripts/assert_live_controls.sh`)

---

## Plan metadata

| Field | Value |
|---|---|
| Plan author tier | top |
| Execution tier(s) | mid (Terraform edits), cheap (mechanical file changes), **never** for apply decisions |
| Review tier | human (owner) — single-member org |
| Expected plan delta | per task, stated in each task; no task may apply a delta it did not state |
| Blast radius | org-wide if bundled; single-resource when staged as written |

---

## Evidence base (measured 2026-10-04, not inferred)

All of the following were reproduced on `ec3456b` with read-only commands.

- Plan summary on `main`: `Plan: 26 to import, 51 to add, 27 to change, 0 to destroy.`
- The 51 adds decompose into **20 `github_branch_protection`** + **30 `github_repository_dependabot_security_updates`** + **1 `github_organization_settings`**.
- The 27 changes decompose into `has_projects = true -> false` ×25, `delete_branch_on_merge = false -> true` ×25, `has_wiki = true -> false` ×22, plus 1 `description`, 1 `patterns_allowed`, 1 `managed_repositories`. Every direction is a tightening.
- `imports.tf` contains exactly one import target: `module.repo[each.key].github_repository.this`. **Zero import blocks for branch protection or dependabot** (`grep -c` → 0). This is the mechanism that turns "adopt" into "replace".
- `terraform plan -target=module.repo["viavitae-hermes-agents"].github_branch_protection.this` still yielded `25 to import, 0 to add, 26 to change` → targeting does not isolate.
- `terraform plan -refresh-only` exits 0 with import blocks present and reports `module.repo["viavitae-hermes-agents"].github_branch_protection.this[0] has changed`.
- `terraform.tfstate` serial 13, 9 resources; the single `github_branch_protection` has **every attribute null**.
- Live `viavitae-hermes-agents`: `{contexts: [], strict: true, admins: true, linear: true, force: false, delete: false}`. PR #7 declares `["test","scan"]`.
- Live `viavitae-web`: 5 contexts (`Analyze (javascript-typescript)`, `Action SHA pinning`, `CI status`, `Compliance status`, `Governance files`) and `required_linear_history = false`.
- Private repos return HTTP 403 on protection reads; `github_repository_dependabot_security_updates` is gated on a **global** var, not on visibility.
- No Terraform backend is configured (`grep -rn 'backend '` → only a commented `state/backend_s3.tf.example`); state is a local file with one `.backup` generation.

---

## File structure

| Action | File | Responsibility |
|---|---|---|
| Modify | `state/backend_s3.tf.example` → `backend_s3.tf` | remote state so a bad apply is recoverable (Task 1) |
| Modify | `versions.tf` | enable the backend block only in Task 1 |
| Modify | `imports.tf` | add protection-adoption import blocks, gated by a new flag (Task 3) |
| Modify | `variables.tf` | `import_existing_protections` (bool, default true) (Task 3) |
| Modify | `locals.tf` | normalise the per-repo `import_protection` lookup (Task 3) |
| Modify | `repos_data.tf` | per-repo `enable_branch_protection`, then per-repo declared controls matching live (Tasks 3–5) |
| Create | `docs/superpowers/plans/*` for each stage | a plan is required before each apply |

---

## STOP conditions (required — policy §3.8)

Halt immediately and report — do not improvise, do not re-run — if any of:

- `terraform plan` shows **any `destroy`** or **any `must be replaced`**.
- The plan delta does not match the **expected delta stated for that task**, token for token.
- A `github_branch_protection` appears as `will be created` for any repo whose live protection is **stronger** than the module default (compare with `assert_live_controls.sh` output first).
- An adoption (`will be updated in-place` after an import) reduces `required_approving_review_count`, removes any `required_status_checks.contexts` entry, or removes any `pull_request_bypassers` entry. Measured on `viavitae-web`: adoption alone would take approvals 1 -> 0 and drop `Action SHA pinning` and `/JourneyOfLife`.
- Any file outside the task's **Files** list would change.
- `enforce_admins`, `visibility`, `manage_files`, or any ruleset value moves beyond what the task states.
- The remote-state migration in Task 1 reports any resource count differing from the pre-migration `terraform state list | wc -l`.
- `ORG_READ_TOKEN` / `TF_GITHUB_TOKEN` are absent or return 401 — a stage that cannot be verified **after** apply may not be started.

---

## Compliance rationale (required if touching `visibility` / `manage_files` / `enforce_admins` / rulesets — policy §3.12)

<!-- This document changes none of those four fields itself. The rationale is
     originated here for the stages it prescribes, because §3.12 forbids an
     executor inferring it. -->

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| `enable_branch_protection` (temporarily `false` for repos not yet onboarded) | gate, not removal | Applying the module default over stronger live rules would *reduce* enforced controls on ~20 repos. Deferring keeps current live controls intact while adoption is fixed. A gap must be recorded, never disguised as a control. | SOC 2 CC8.1; ISO 27001 A.14.2.2, A.8.2 |
| `required_status_checks_contexts` per repo | harvested job ids from real check runs | Declared-but-unenforced checks are the defect that produced VV-2026-09-002. Names must come from observed check runs; a wrong name permanently blocks merges. | SOC 2 CC8.1 |
| `has_wiki` / `has_projects` = `false` | least privilege for repos that use neither | Reduces attack/exploit surface and org metadata, but is user-visible: confirm no consumer relies on a wiki or project board per repo **before** apply. | ISO 27001 A.8.2, GDPR Art. 5(1)(c) (minimisation) |
| `delete_branch_on_merge` = `true` | hygiene already assumed by the workflow | The PR flow relies on upstream branch deletion; today it is not actually on for 25 repos, which is why stale refs accumulated elsewhere in the estate. | SOC 2 CC8.1 |
| `manage_org_settings` stays `false` until Task 6 | opt-in | Org-wide settings would have been written from a CI placeholder value (PR #8). | GDPR Art. 5(1)(c), Art. 32 |
| Remote state before bulk apply | precondition | Local state with one backup generation is not a rollback path for a 26-import apply; unrecoverable state makes every prior control unauditable. | ISO 27001 A.5.19, A.8.13 |

---

## Halt-and-report triggers (required — policy §3.15)

- Import support is **established** (plan-time, one public repo). It is *not* established for private repos, which have no classic protection on the Free plan, nor end-to-end at apply time. If an adoption plan shows a **decrease** in `required_approving_review_count`, any `- "..."` removal under `required_status_checks.contexts`, or any removal under `pull_request_bypassers`, STOP and report: the declaration has not been reconciled to live yet, and applying would silently weaken a control.
- **Corrected inference.** An earlier bullet in this plan implied private repos might reject dependabot because protection reads return 403. Measured directly: `GET /repos/Via-Vitae/{viavitae-compliance,viavitae-policies}/vulnerability-alerts` returns **HTTP 204**, i.e. the endpoint works and alerts are already enabled on private repos. So the 30 dependabot adds are expected to succeed or be near-no-ops. Residual rule kept deliberately: if a 4xx *does* appear at apply time, STOP and report the exact response — it would now be a regression against measured state, not an expected unknown.
- If any repo's wiki has non-trivial content, STOP and report before `has_wiki` flips.
- If the pre-apply and post-apply `assert_live_controls.sh` outputs differ from the task's stated expectation in any way, STOP and report.
- If the correct declared value for a repo's contexts cannot be derived from a real check run, **STOP and report** — never substitute the workflow filename or a guess.

---

## Tier routing for this plan (policy §6)

| Task | Tier | Rationale |
|---|---|---|
| Decomposition, stage ordering, STOP conditions | top | risk and cross-file coupling |
| Backend migration (Task 1) | mid + human | state identity is unrecoverable if wrong |
| `refresh-only` run (Task 2) | human-authorized | it is a state mutation |
| Import-block spike (Task 3) | top | interpretation of provider behaviour |
| Per-repo control declarations (Task 5) | mid, reviewed by human | each value must cite a real check run |
| Mechanical `repos_data.tf` edits | cheap | exact values supplied by Task 3 output |
| Interpreting any plan output | top | interpretation ≠ reading |

**Escalation:** if the same step fails twice, stop and escalate with the exact command output. Do not loop.

---

## Task 1: Make state recoverable (blocking prerequisite)

**Files:** `versions.tf`, `state/backend_s3.tf.example` → `backend_s3.tf`

- [ ] **Step 1: record the pre-migration baseline**

Run: `terraform state list | wc -l && sha256sum terraform.tfstate`
Expected: `9` and a hash that is written into the PR description.

- [ ] **Step 2: enable the backend and migrate**

Run: `terraform init -migrate-state` (owner-authorized; answers `yes` once)
Expected: `Successfully configured the backend "s3"!`, resource count unchanged.

- [ ] **Step 3: verify**

Run: `terraform state list | wc -l && terraform plan -refresh=false | tail -1`
Expected: `9`; plan summary unchanged from baseline. **Any other count → STOP.**

---

## Task 2: Repair state truthfulness (`-refresh-only`)

**Files:** none (state only)

- [ ] **Step 1: capture the refresh delta**

Run: `terraform plan -refresh-only -no-color | grep -E 'has changed|Plan:|destroy|replace'`
Expected today (measured): exactly one `module.repo["viavitae-hermes-agents"].github_branch_protection.this[0] has changed`; **no** `destroy`, **no** `replace`.

- [ ] **Step 2: apply state-only (owner-authorized)**

Run: `terraform apply -refresh-only -auto-approve`
Expected: `1 updated, 0 to add, 0 to change, 0 to destroy` style refresh summary; no API write beyond reads.

- [ ] **Step 3: confirm the stub is no longer null**

Run: `terraform show -json | jq -r '.resources[] | select(.type=="github_branch_protection") | [.module,.name]|@tsv'` then inspect attributes
Expected: real `pattern`, `enforce_admins`, `required_status_checks` values, not `null`.

---

## Task 3: Adopt live protection by import — **answered 2026-10-04, and it changed the design**

**Measured result (read-only, transient config, reverted; `imports.tf` diff after the
spike: 0 lines).** The provider accepts the identity and reads the live rule:

```
module.repo["viavitae-web"].github_branch_protection.this[0]: Preparing import... [id=viavitae-web:main]
module.repo["viavitae-web"].github_branch_protection.this[0]: Refreshing state... [id=BPR_kwDOUQkJvM4E76T1]
```

So `<repository>:<branch>` is **correct**, import blocks work for this resource, and the
ruleset-migration fallback written into an earlier draft of this plan is **not needed**.

The same plan then showed what adoption does to a repo that already has stronger rules:

```
  # module.repo["viavitae-web"].github_branch_protection.this[0] will be updated in-place
  # (imported from "viavitae-web:main")
      ~ required_linear_history         = false -> true
      ~ required_pull_request_reviews {
          ~ pull_request_bypassers      = [ - "/JourneyOfLife", ]
          ~ required_approving_review_count = 1 -> 0
      ~ required_status_checks { ~ contexts = [ - "Action SHA pinning", ... ] }
```

Two conclusions, both corrections to what this plan previously asserted:

1. **Import is necessary but not sufficient.** Adoption alone does not preserve live
   strength: the same apply would drop a required approval and remove required checks.
   The per-repo declaration must be reconciled to live values **in the same change** as
   the import, or adoption degrades protection.
2. **Fields the module does not declare are reset to provider defaults.** Live
   `pull_request_bypassers = ["/JourneyOfLife"]` disappears on adoption because
   `modules/repo/branch_protection.tf` never sets it. This is the mechanism behind
   VV-2026-09-002's "no valid approver / bypass lost" class, and it means the module
   must learn bypass actors, contexts and review counts per repo before importing any
   repo that has them. An unmanaged field is not a neutral field - it is a reset.

**Files:** `imports.tf`, `variables.tf`, `locals.tf`, one disposable repo

- [ ] **Step 1: pick a disposable target** (a repo whose live protection equals the module default, so an adoption is a no-op).

Run: `./scripts/assert_live_controls.sh`-style GET via `gh api repos/Via-Vitae/<repo>/branches/main/protection`
Expected: a repo whose live invariants match `modules/repo/branch_protection.tf` exactly. If none exists, **STOP and report** — do not proceed on a repo where it would differ.

- [ ] **Step 2: add the import block behind a new flag**

```hcl
# variables.tf
variable "import_existing_protections" {
  description = <<-EOT
    When true, existing default-branch protection is adopted into state via import
    blocks instead of being re-created. Create-over-existing is a per-branch PUT and
    silently replaces stronger live rules (VV-2026-09-002), so adoption must be an
    import. Flip false only for repos genuinely having no protection yet.
  EOT
  type    = bool
  default = true
}
```

```hcl
# imports.tf — id form <repository>:<branch_pattern> VERIFIED at plan time 2026-10-04
# (see Measured result above). Note the inventory-wide for_each below is WRONG for a
# first landing: it would import private repos, which have no classic protection on the
# Free plan (403), and repos with no protection at all. Restrict to an explicit list.
import {
  for_each = var.import_existing_protections ? { for k, v in local.inventory : k => k if lookup(v, "create_new", false) != true } : {}
  to       = module.repo[each.key].github_branch_protection.this[0]
  id       = "${each.value}:${var.default_branch}"
}
```

- [ ] **Step 3: run the deterministic gate, then the plan delta**

Run: `terraform fmt -recursive && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

Run: `terraform plan -no-color | grep -E '^Plan:|github_branch_protection'`
Expected, and observed: the target moves from `will be created` to `will be updated in-place # (imported from ...)`. **If instead it stays `will be created`, STOP and report** — the id form or the instance address is wrong for that repo.

- [ ] **Step 4: record the measured result in a follow-up spec** including whether dependabot adoption is likewise importable.

---

## Task 4: Adopt repositories + apply hardening only

**Files:** `repos_data.tf` (per-repo `enable_branch_protection = false` where not yet onboarded), `variables.tf` (`enable_dependabot_security_updates` decision)

- [ ] **Step 1: gate off undecided controls** so the plan contains nothing but adoption + tightening.

- [ ] **Step 2: capture and assert the delta**

Expected delta for this task: `26 to import, 0 to add, 27 to change, 0 to destroy`.
**Any `to add` above 0, or any `destroy`/`replace` → STOP.**

- [ ] **Step 3: human review of the 27 changes** — confirm per repo that no wiki content or project board is in use. Record the check in the PR, per repo, not as a blanket statement.

- [ ] **Step 4: apply (owner), then immediately assert**

Run: `./scripts/assert_live_controls.sh` and `./scripts/detect_drift.sh`
Expected: drift script `OK: inventory matches the live org`; assertion script reports no `DIVERGED` for adopted repos.

---

## Task 5: Onboard merge controls, one repo per PR

**Files:** `repos_data.tf`

- [ ] **Step 1:** for the target repo, declare contexts **and** the invariants it already has, applying only the delta the repo actually needs. `viavitae-hermes-agents` first, via PR #7's `["test", "scan"]`.
- [ ] **Step 2:** apply that single repo's change; re-run `assert_live_controls.sh`; expect `OK` for that repo.
- [ ] **Step 3:** only afterwards raise the control further, as its own PR. Never declare-and-strengthen in one apply.
- [ ] **Note:** between merging PR #7 and applying it, `assert_live_controls.sh` is **expected red**. That is the assertion functioning; do not silence it.

---

## Task 6: Org settings, last and only when real

Prerequisites: PR #8 merged, a genuine `billing_email`, 2FA resolved (`org_data.tf:19` currently fails: `two_factor_requirement_enabled = false`), and a plan whose only delta is that resource.

---

## Review checklist (required — policy §5)

This checklist is for **this document only** (a docs-only change). Every execution stage above carries its own, to be completed with cited output by the reviewer before that stage's apply. Bare `[x]` without a citation is not a sign-off.

### Pre-commit checklist

- [x] **Plan exists and is committed** — `docs/superpowers/plans/2026-10-04-viavitae-control-drift-adoption-and-control-staging.md`
- [x] **Plan includes STOP conditions** — section present, 8 clauses. Re-counted at this
      commit: it was 7 when the line was written, and my own later amendment added the
      adoption-degradation clause without updating the citation. A checklist that is not
      re-verified after every edit decays into exactly the claim-without-evidence it is
      meant to prevent.
- [x] **Plan includes compliance rationale** — present (6 fields incl. `enforce_admins`-adjacent gating)
- [x] **Plan includes halt-and-report triggers** — present, 5 clauses. The provider import
      form is no longer one of the unknowns: it was measured at plan time, so the
      surviving triggers are reconciliation-before-import, apply-time confirmation, and
      the per-repo wiki/content check.
- [ ] **Deterministic gates passed** — N/A for a Markdown-only change; `fmt`/`validate` not exercised by this PR
- [ ] **Diff matches plan** — n/a; this PR performs no Terraform change. Expected: documentation only
- [x] **No silent fallback** — nothing was substituted. Honest correction: the two items
      this line praised for being parked as unknowns were subsequently measured, and one
      of them contradicted the document. `GET …/vulnerability-alerts` returns HTTP 204 on
      private repos (viavitae-compliance, viavitae-policies), so the dependabot hedge in
      the earlier version was an inference from the protection 403s and was wrong; the
      import id form was confirmed as `<repository>:<branch>`. Kept visible rather than
      quietly reworded.
- [x] **Tier prefix in commit message** — `ai:top`
- [ ] **Small diff** — new file, ~200 lines; exceeds the template's <100-line mechanical guideline, justified because it is a multi-stage plan document, flagged for reviewer judgment
- [x] **No state mutation** — `terraform apply` was **not** run; only `plan`/`-refresh-only plan`/read-only `gh api`

### Post-merge checklist

- [ ] **Post-merge plan confirms no drift** — to be run by the owner: `terraform plan | tail -1` should show this document changed nothing
- [ ] **Audit trail is complete** — `git log --grep '^ai:' --oneline`
- [ ] **Review sign-off is recorded** — below, **not yet signed**

### Sign-off

```
REVIEW SIGN-OFF:
- Reviewer: [owner — not filled by the plan author]
- Date: [pending]
- Plan followed: [n/a for a docs-only change]
- Diff matches plan: [pending]
- Compliance rationale reviewed: [pending]
- Approved: [no — awaiting owner]
```
