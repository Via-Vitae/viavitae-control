# AI-Assisted Development Workflow Policy

> **Mandatory for all AI-generated changes to the Via-Vitae control plane.**
> This policy defines the levers and review gates that must be applied when using AI coding agents (any tier) to modify Terraform, policies, or documentation in this repository.

---

## 1. Purpose

This policy ensures that AI-assisted development in a SOC 2 / ISO 27001 / GDPR control plane maintains:

- **Accountability**: every change is authorized by a human or top-tier review
- **Traceability**: the tier and rationale for each change are recorded
- **Correctness**: deterministic gates catch errors before they reach state
- **Compliance**: AI agents cannot reason about compliance; humans must

Without this policy, AI automation is efficient but uncontrolled. With it, AI automation is auditable.

---

## 2. Scope

This policy applies to:

- All AI-generated edits to `.tf` files, `policies/`, `docs/`, `scripts/`
- All AI-generated commits, regardless of tier (top, mid, cheap, free)
- All AI-assisted `terraform plan`, `validate`, `fmt`, or `apply` operations
- All AI-assisted `git` operations (commit, push, PR)

**Excluded:** read-only exploration (file reads, `grep`, `terraform show`), which does not require review but must still follow plan-only authority.

---

## 3. The 15 Levers

In rough order of impact on output quality and compliance posture:

### 3.1 Persistent rules/memory (highest leverage)

Project conventions, boundaries, and commands must be captured in memory or rules files. Stale rules are worse than none. Review and update memory after every significant change.

**Verification:** memory must reference actual files and commands, not assumptions.

### 3.2 Attach the right files explicitly

Don't make the agent hunt. Hunting burns tokens and invites hallucination. Attach specific files, not directories. Aim for focused context — a few hundred relevant lines beats 5,000 dumped ones.

**Verification:** the agent should reference the attached files by path, not invent new ones.

### 3.3 Use the skills as a pipeline

`brainstorming` → `spec-driven-development` → `writing-plans` → `executing-plans` / `subagent-driven-development` → `verification-before-completion` → `requesting-code-review`. Each stage produces the artifact the next stage consumes. That chain is the tier-routing mechanism: artifacts, not prompts, cross the boundary.

**Verification:** each skill's output must be committed or saved to a file before the next skill runs.

### 3.4 One task per session

Fresh session at completed task boundaries. Long conversations degrade quality — stale context, replaced drafts, and dead-end error logs fragment attention. Trim at ~75% capacity, not 100%.

**Verification:** a session should not mix unrelated work (e.g., debugging a plan failure AND adding a new repo).

### 3.5 Small diffs, frequent commits

A 40-line reviewable diff is cheap-tier-safe. A 900-line one is not, on any tier. Commit after every logical unit of work.

**Verification:** `git diff --stat` should show <100 lines per commit for mechanical changes.

### 3.6 Verify by command output, never by agent claim

"I've updated the file successfully" is not evidence. `terraform validate` returning `Success!` is. Every claim must be backed by command output.

**Verification:** the agent must paste the command and its output, not just assert success.

### 3.7 Two-attempt escalation rule

Cheap tier fails twice on the same step → stop, switch to top tier, paste the exact error output. Do not let a weak model loop; loops are where it starts "fixing" things you didn't ask it to touch.

**Verification:** if the agent retries more than twice, escalate immediately.

### 3.8 Require explicit STOP conditions in every plan

"If the plan shows any `destroy` or `replace`, halt and report." Weak models comply with explicit halt rules; they do not infer them. STOP conditions must be in the plan document itself, not just in the prompt.

**Verification:** every plan must include a "STOP conditions" section.

### 3.9 The human-or-top-tier review gate is the actual control

Everything above is engineering practice. The compliance control is the human (or top tier) reviewing the diff against the plan. Without that, you have automation without accountability. SOC 2 CC8.1 and ISO 27001 A.14.2.2 require authorization of changes.

**Verification:** the review checklist (§5) must be signed off before commit.

### 3.10 Plan-as-contract, not suggestion

If the cheap tier deviates from the plan — even if it thinks it found a "better" way — that's a failure, not an improvement. Plans are binding. The cheap tier must not improvise. If the plan needs to change mid-execution, stop, get top-tier review, update the plan, then resume.

**Verification:** the diff must match the plan's expected diff. Semantic drift (code that validates but doesn't match intent) is a failure.

### 3.11 Audit trail of tier provenance

In a compliance-controlled repo, you should know which edits were AI-generated and by which tier. This matters for incident response ("was this change reviewed by a human?"). Use a commit message prefix or PR label to indicate tier.

**Convention:**
- `ai:top` — top-tier model produced the change
- `ai:mid` — mid-tier model produced the change
- `ai:cheap` — cheap-tier model produced the change
- `ai:free` — free-tier model produced the change
- `ai:review` — top-tier or human reviewed the change

**Verification:** every AI-generated commit must include the tier prefix.

### 3.12 Don't let the agent reason about compliance

Compliance judgment is a human-or-top-tier task. The cheap tier can implement a compliance control if the spec says exactly what to do, but it cannot decide whether a control is adequate. In this repo, `visibility` changes, `manage_files` flips, and ruleset modifications are compliance decisions. The plan must state the compliance rationale; the cheap tier must not infer it.

**Verification:** the plan must include a "Compliance rationale" section for any change to `visibility`, `manage_files`, `enforce_admins`, or rulesets.

### 3.13 Don't let the agent touch state (plan-only execution authority)

The agent must never run `terraform apply` without explicit authorization. This is not just engineering practice; it's the control that prevents accidental state mutation in a repo with local state and no remote backend.

**Verification:** the agent's command history must not include `terraform apply` unless explicitly authorized in writing.

### 3.14 Verification must include the diff-vs-plan check, not just command gates

`terraform validate` can pass while the plan diverges from intent. After every cheap-tier execution, the top tier must compare the actual diff against the plan's expected diff. If the plan says `1 to add, 0 to change, 0 to destroy` and the actual plan shows `0 to add, 1 to change, 0 to destroy`, that's a failure even if `validate` passed.

**Verification:** the review checklist must include a "Diff matches plan" item.

### 3.15 The "no silent fallback" rule

If the cheap tier can't do something, it must stop and report, not silently substitute. Explicit escalation triggers in the plan: "If you cannot determine the correct value for field X, halt and report." Weak models will guess; the plan must forbid guessing.

**Verification:** the plan must include explicit "halt and report" triggers for ambiguous fields.

---

## 4. Workflow Sequence

All AI-assisted changes must follow this sequence:

```
VERIFY FIRST → COMMIT → PUSH → REVIEW → MERGE → VERIFY AGAIN
```

1. **VERIFY FIRST**: run `terraform fmt -recursive`, `terraform init -backend=false`, `terraform validate`, `terraform plan`. Capture output.
2. **COMMIT**: only if all gates pass. Include tier prefix in commit message.
3. **PUSH**: only if commit is clean.
4. **REVIEW**: top-tier or human reviews the diff against the plan using the checklist (§5).
5. **MERGE**: only after review sign-off. Use `gh pr merge --squash --auto`.
6. **VERIFY AGAIN**: post-merge, run `terraform plan` to confirm no drift.

**Plan-only authority**: `terraform apply`, `git push` to `main`, and live org mutation are prohibited until explicit owner approval.

---

## 5. Mandatory Review Checklist

Before committing any AI-generated change, the top tier (or human) must sign off on this checklist. This is the compliance control.

### 5.1 Pre-commit checklist

- [ ] **Plan exists and is committed**: the change is guided by a plan document in `docs/superpowers/plans/` or a committed spec.
- [ ] **Plan includes STOP conditions**: explicit halt triggers for `destroy`, `replace`, or unexpected diffs.
- [ ] **Plan includes compliance rationale** (if applicable): for changes to `visibility`, `manage_files`, `enforce_admins`, or rulesets.
- [ ] **Plan includes explicit halt-and-report triggers**: for ambiguous fields or values.
- [ ] **Deterministic gates passed**: `terraform fmt -recursive`, `terraform init -backend=false`, `terraform validate`, `terraform plan` all green.
- [ ] **Diff matches plan**: the actual `terraform plan` output matches the plan's expected output (e.g., `1 to add, 0 to change, 0 to destroy`).
- [ ] **No silent fallback**: the agent did not substitute values or improvise.
- [ ] **Tier prefix in commit message**: `ai:top`, `ai:mid`, `ai:cheap`, or `ai:free`.
- [ ] **Small diff**: <100 lines for mechanical changes; <500 lines for substantive changes.
- [ ] **No state mutation**: `terraform apply` was not run without explicit authorization.

### 5.2 Post-merge checklist

- [ ] **Post-merge plan confirms no drift**: `terraform plan` shows `No changes. Your infrastructure matches the state.`
- [ ] **Audit trail is complete**: commit history includes tier prefixes for all AI-generated changes.
- [ ] **Review sign-off is recorded**: the PR description or commit message includes the reviewer's sign-off.

### 5.3 Sign-off

The reviewer (human or top tier) must append their sign-off to the PR description or commit message:

```
REVIEW SIGN-OFF:
- Reviewer: [name or "top-tier"]
- Date: [YYYY-MM-DD]
- Plan followed: [yes/no]
- Diff matches plan: [yes/no]
- Compliance rationale reviewed: [yes/no or N/A]
- Approved: [yes/no]
```

---

## 6. Tier Routing

Not all tasks require the top tier. Route by task class:

| Task class | Tier | Rationale |
|---|---|---|
| Intent → spec | **Top** | Judgment + compliance impact |
| Spec → plan | **Top** | Decomposition, risk, ordering, cross-file coupling |
| Mechanical edits from plan | **Cheap** | Typing, not thinking |
| Command execution (`fmt`, `validate`, `plan`) | **Cheap** | Deterministic |
| Interpret `terraform plan` output | **Top** | Interpretation ≠ reading |
| Review diff vs plan | **Top** | Judgment |
| Failure recovery (novel error) | **Top** | Diagnosis requires reasoning |
| Read-only exploration (`grep`, `show`) | **Free** | No cost if wrong |
| Draft commit message / docs | **Free** | Gate catches errors |

**Escalation rule**: cheap tier fails twice → stop, escalate to top tier with exact error output. Do not let a weak model loop.

---

## 7. Anti-patterns to reject

- **Prompt-as-handoff**: copying a prompt from one tier to another. Use a committed plan, not a prompt.
- **Silent drift**: the agent changes something outside the plan's scope.
- **Compliance reasoning by cheap tier**: the agent decides whether a control is adequate.
- **Looping on failure**: the agent retries more than twice without escalating.
- **Trusting agent claims**: "I've updated the file successfully" without command output.
- **Large diffs**: a 900-line change that cannot be reviewed in one sitting.
- **Skipping the review checklist**: committing without sign-off.

---

## 8. Enforcement

This policy is enforced by:

1. **CI gates**: `.github/workflows/audit.yml` runs `terraform fmt -check`, `validate`, and drift detection on every PR.
2. **PR review**: the review checklist must be completed before merge.
3. **Post-merge verification**: `terraform plan` must confirm no drift.
4. **Audit trail**: commit messages must include tier prefixes.

Violations are P1 findings in the next audit cycle.

---

## 9. References

- [`AUDIT_PROMPT.md`](AUDIT_PROMPT.md) — evidence-gated audit prompt for control-plane audits
- [`docs/superpowers/plans/TEMPLATE.md`](../docs/superpowers/plans/TEMPLATE.md) — copy-ready plan template embedding the STOP conditions, compliance rationale, and the §5 review checklist
- [`docs/superpowers/plans/`](../docs/superpowers/plans/) — implementation plans
- [`docs/COMPLIANCE.md`](../docs/COMPLIANCE.md) — findings register and control matrix
- SOC 2 CC8.1 (change management)
- ISO 27001 A.14.2.2 (change control)
- GDPR Art. 32 (security of processing)

---

**Remember:** documentation is a claim, not evidence. Verify everything. The review checklist is the control.
