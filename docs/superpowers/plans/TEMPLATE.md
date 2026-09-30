# Implementation Plan Template — viavitae-control

> **How to use this template**
>
> 1. Copy this file to `docs/superpowers/plans/YYYY-MM-DD-viavitae-control-<topic>.md`.
> 2. Fill in every `[bracketed placeholder]`. Delete every `<!-- instruction -->` comment.
> 3. Delete this "How to use" block — it does not belong in the committed plan.
> 4. The sections marked **(required)** implement [`policies/AI_WORKFLOW_POLICY.md`](../../../policies/AI_WORKFLOW_POLICY.md). A plan missing them fails the pre-commit review checklist.
> 5. The plan is the **cross-tier handoff artifact** (policy §3.10, plan-as-contract). Write it so a cheap tier can execute it mechanically: exact paths, exact code, exact commands, expected outputs, and explicit STOP conditions.
>
> **Authority:** plan-only. No `terraform apply`, no `git push` to `main`, no live org mutation, no commit without explicit owner authorization.

---
---

<!-- ======================= TEMPLATE STARTS BELOW ======================= -->

# [Feature Name] — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence: what this builds or fixes.]

**Architecture:** [2–3 sentences: the approach and why it is non-destructive.]

**Tech Stack:** Terraform 1.16.1, `integrations/github` provider 6.13.0, `gh` CLI (GET only), `jq`, Bash. Org: `Via-Vitae`, plan: **free**.

**Authority boundary:** Plan-only per `policies/AI_WORKFLOW_POLICY.md` §4. `terraform apply`, `gh api` write verbs, and `git push` to `main` are **prohibited** until the owner explicitly authorizes them.

**Related spec:** [`docs/superpowers/specs/[spec-file].md`](../specs/[spec-file].md)
**Related findings:** [VV-YYYY-MM-NNN, …]

---

## Plan metadata

| Field | Value |
|---|---|
| Plan author tier | [top] |
| Execution tier(s) | [cheap / mid] |
| Review tier | [top / human] |
| Expected plan delta | [e.g. `1 to import, 0 to add, 0 to change, 0 to destroy`] |
| Blast radius | [single file / single repo / org-wide] |

---

## File structure

<!-- One row per file. "Action" is Create | Modify | Delete. -->

| Action | File | Responsibility |
|---|---|---|
| [Modify] | `[exact/path.tf]` | [what changes and why] |

---

## STOP conditions (required — policy §3.8)

<!-- Hard-halt triggers. A cheap tier obeys these literally; it does not infer them. -->

The executing agent **halts immediately and reports** if any of the following occur:

- `terraform plan` shows **any `destroy`** or **any `replace`**.
- `terraform plan` delta does not match the **Expected plan delta** in Plan metadata.
- Any file outside the **File structure** table would be modified.
- A `visibility`, `manage_files`, `enforce_admins`, or ruleset value would change beyond what this plan explicitly states.
- Any command returns a non-zero exit code not explicitly anticipated below.

---

## Compliance rationale (required if touching `visibility` / `manage_files` / `enforce_admins` / rulesets — policy §3.12)

<!-- Delete this whole section if the change touches none of the above. Otherwise, a cheap tier executes this rationale but must NOT originate it. -->

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| [e.g. `visibility`] | [e.g. `public`] | [why this is the correct classification] | [e.g. GDPR Art. 5(1)(c)] |

---

## Halt-and-report triggers (required — policy §3.15)

<!-- Forbid guessing. Name every ambiguous field and what to do when its value is unknown. -->

- If the correct value of `[field]` cannot be determined from the cited source, **STOP and report** — do not substitute a default.
- If `[condition]` is ambiguous, **STOP and report**.

---

## Tier routing for this plan (policy §6)

| Task | Tier | Rationale |
|---|---|---|
| [Spec → plan] | top | decomposition, risk, cross-file coupling |
| [Mechanical edits] | cheap | typing from exact instructions |
| [Interpret `terraform plan`] | top | interpretation ≠ reading |
| [Review diff vs plan] | top | judgment |

**Escalation:** cheap tier fails the same step twice → stop, escalate to top tier with the exact error output. Do not loop.

---

## Task 1: [Component Name]

**Files:**
- [Create/Modify]: `[exact/path]`
- Test/verify: `[exact/path or command]`

- [ ] **Step 1: [Write the failing test / make the exact edit]**

```hcl
# exact code the executor should produce — no placeholders
```

- [ ] **Step 2: Run the deterministic gate**

Run: `terraform fmt -recursive && terraform init -backend=false && terraform validate`
Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Capture the plan and assert the delta**

Run: `terraform plan -out=/tmp/p.txt && grep -E 'Plan:|to import|to add|to change|to destroy' /tmp/p.txt`
Expected: `[matches Expected plan delta]`. **If it does not match, STOP per the STOP conditions.**

- [ ] **Step 4: Commit (only after the review checklist below is signed off)**

```bash
git add [exact/path]
git commit -m "[type]: [summary]

[body]

ai:[tier]"
```

<!-- Repeat Task blocks as needed. Keep each commit <100 lines for mechanical changes. -->

---

## Review checklist (required — policy §5)

<!-- The reviewer (top tier or human) completes this BEFORE commit and BEFORE merge. This is the compliance control. Copy the evidence into each line — a bare [x] with no citation is not a sign-off. -->

### Pre-commit checklist

- [ ] **Plan exists and is committed** — path: `[this file]`
- [ ] **Plan includes STOP conditions** — section present above
- [ ] **Plan includes compliance rationale** (if applicable) — `[present / N/A]`
- [ ] **Plan includes explicit halt-and-report triggers** — section present above
- [ ] **Deterministic gates passed** — paste: `fmt [ok] · validate [ok] · plan [ok]`
- [ ] **Diff matches plan** — expected `[N to import, …]`; actual `[paste plan summary line]`
- [ ] **No silent fallback** — agent substituted nothing; confirmed by diff review
- [ ] **Tier prefix in commit message** — `[ai:top / ai:mid / ai:cheap / ai:free]`
- [ ] **Small diff** — `[N]` lines changed (`git diff --cached --stat`)
- [ ] **No state mutation** — `terraform apply` was **not** run

### Post-merge checklist

- [ ] **Post-merge plan confirms no drift** — paste: `No changes. Your infrastructure matches the state.`
- [ ] **Audit trail is complete** — `git log --grep '^ai:' --oneline` shows the tier prefix(es)
- [ ] **Review sign-off is recorded** — present in PR description / commit message below

### Sign-off

```
REVIEW SIGN-OFF:
- Reviewer: [name or "top-tier"]
- Date: [YYYY-MM-DD]
- Plan followed: [yes/no]
- Diff matches plan: [yes/no]
- Compliance rationale reviewed: [yes/no or N/A]
- Approved: [yes/no]
```

<!-- ======================= TEMPLATE ENDS ABOVE ======================= -->

---
---

# Worked Example (ILLUSTRATIVE ONLY)

> ⚠️ **This is a teaching example, not a compliance record.** The repo name, plan deltas,
> command outputs, dates, and reviewer below are **placeholders**. A real sign-off must cite
> the **actual** command output from your run. Never copy these values into a real plan —
> fabricating a completed checklist is exactly the "documentation as claim, not evidence"
> anti-pattern this repo exists to eliminate.

**Scenario:** add one already-existing, empty, public site-tier repo (`viavitae-landing-example`)
to the inventory and adopt it via an import block — non-destructive, `0 to destroy`.

## Example — Plan metadata

| Field | Value |
|---|---|
| Plan author tier | top |
| Execution tier(s) | cheap |
| Review tier | human |
| Expected plan delta | `1 to import, 0 to add, 0 to change, 0 to destroy` |
| Blast radius | single repo |

## Example — STOP conditions (as filled in)

Halt immediately and report if:
- `terraform plan` shows any `destroy` or `replace`.
- The delta is not exactly `1 to import, 0 to add, 0 to change, 0 to destroy`.
- Any file other than `repos_data.tf` or `imports.tf` would change.
- `visibility` for any repo other than `viavitae-landing-example` would change.

## Example — Compliance rationale (as filled in)

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| `visibility` | `public` | Marketing landing page; no personal data, no confidential taxonomy. Matches the other 10 `site`-tier entries. | GDPR Art. 5(1)(c) (minimisation — nothing sensitive published) |
| `manage_files` | `false` | Non-destructive baseline; module writes no CODEOWNERS/workflows into the repo on this change. | ISO 27001 A.14.2.2 |

## Example — Pre-commit checklist (COMPLETED)

- [x] **Plan exists and is committed** — path: `docs/superpowers/plans/2026-10-01-viavitae-control-add-landing-example.md`
- [x] **Plan includes STOP conditions** — section present
- [x] **Plan includes compliance rationale** — present (visibility, manage_files)
- [x] **Plan includes explicit halt-and-report triggers** — present (`default_branch_exists` ambiguity)
- [x] **Deterministic gates passed** — `fmt ok · validate: Success! The configuration is valid. · plan ok`
- [x] **Diff matches plan** — expected `1 to import, 0 to add, 0 to change, 0 to destroy`; actual `Plan: 0 to add, 1 to import, 0 to change, 0 to destroy.`
- [x] **No silent fallback** — executor changed only `repos_data.tf` and `imports.tf`; confirmed by `git diff --cached --stat`
- [x] **Tier prefix in commit message** — `ai:cheap` (execution), `ai:review` (human sign-off)
- [x] **Small diff** — 14 lines changed
- [x] **No state mutation** — `terraform apply` was **not** run

## Example — Post-merge checklist (COMPLETED)

- [x] **Post-merge plan confirms no drift** — `No changes. Your infrastructure matches the state.`
- [x] **Audit trail is complete** — `git log --grep '^ai:' --oneline` → `9f1c2ab feat(repos): adopt viavitae-landing-example ai:cheap`
- [x] **Review sign-off is recorded** — present in PR #NN description (below)

## Example — Sign-off (in context, as it appears in the PR description)

```
## Change
Add viavitae-landing-example to the inventory and adopt it via import block.
Plan: 0 to add, 1 to import, 0 to change, 0 to destroy. No apply performed.

REVIEW SIGN-OFF:
- Reviewer: human (owner)
- Date: 2026-10-01
- Plan followed: yes
- Diff matches plan: yes
- Compliance rationale reviewed: yes (visibility=public, manage_files=false)
- Approved: yes
```

## Why this example passes

Every checklist line carries **cited evidence** (a command output, a diff stat, a plan
summary line), not a bare `[x]`. The STOP conditions and the "diff matches plan" line are
what would catch the semantically-wrong-but-syntactically-valid case (e.g. an executor
setting `default_branch_exists = true` on a repo that has no `main` yet — `validate` passes,
`apply` fails). The compliance rationale is **originated by the plan author (top tier)** and
merely **executed** by the cheap tier, per policy §3.12.
