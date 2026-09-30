# viavitae-control — AI-Assisted Development Workflow Policy (Design Spec)

- **Date:** 2026-09-30
- **Owner org:** `Via-Vitae` (GitHub Free plan)
- **Target repo:** `Via-Vitae/viavitae-control`, branch `fix/control-plane-evidence-integrity` (PR-only, `protect-main` ruleset, `bypass_actors: []`)
- **Local working dir:** `/opt/viavitae/repos/viavitae-control`
- **Compliance targets:** SOC 2 (CC8.1, CC2.2, CC5.2), ISO 27001 (A.14.2.1, A.14.2.2, A.12.1.2, A.12.4.1), GDPR (Art. 5(2), Art. 24, Art. 32)
- **Execution authority:** **PLAN-ONLY.** No `terraform apply`. No live org mutation. No push to `main`. No commit without explicit owner authorization.
- **Status:** Retroactive design spec — documents the rationale for `policies/AI_WORKFLOW_POLICY.md` (committed `33c4f4a`), which was implemented before this spec existed.

> Scope boundary: this control plane manages **Via-Vitae only**. It is separate from
> `jol-control`, which manages `journeyoflife-org`. The two are never mixed.

---

## 1. Problem

`viavitae-control` is developed with the assistance of AI coding agents across multiple
capability tiers (top, mid, cheap, free). This is efficient but introduces a class of
risk that the existing controls do not address: **AI-authored changes to a compliance
control plane that are merged without a documented authorization gate.**

The specific exposures:

1. **Accountability gap.** SOC 2 CC8.1 and ISO 27001 A.14.2.2 require that changes to
   systems processing controlled data be *authorized* before deployment. An AI agent
   producing a diff, and a human merging it because `terraform validate` passed, is not
   authorization — validation proves syntax, not intent. Without an explicit sign-off
   artifact, the control plane cannot demonstrate that any given change was reviewed by
   a competent authority.

2. **Provenance gap.** When an incident occurs, the first question is "what changed, and
   who authorized it?" If commits do not record which tier produced them or whether a
   human reviewed them, incident response is guesswork. ISO 27001 A.12.4.1 and GDPR
   Art. 5(2) (accountability) both require this traceability.

3. **Silent-drift gap.** A cheap-tier agent can produce a change that passes every
   deterministic gate (`fmt`, `validate`) while semantically diverging from the plan —
   e.g. setting `default_branch_exists = true` on a repo that does not yet exist. This
   is the exact failure mode documented in the repo's own inventory notes: mechanically
   valid, semantically wrong, passes `validate`, fails at `apply`. No existing control
   detects it, because the existing gates check *syntax*, not *intent*.

4. **Prompt-as-handoff gap.** The informal practice was: ask a strong model to write a
   prompt, copy the prompt to a cheap model, let it execute. A prompt transfers the
   *conclusion* and discards the *reasoning* — the rejected alternatives, the noticed
   edge cases, the constraint awareness. The cheap tier then re-derives that reasoning
   and does so poorly. There is no artifact to review, because the handoff was ephemeral
   chat text.

The 2026-09-25 spec established the principle for the *infrastructure*: **documentation
is a claim, not evidence.** This spec extends the same principle to the *development
process*: **an agent's assertion that it did the work correctly is a claim, not
evidence.** Both require the same remedy — a committed artifact that a competent
authority signs off on.

---

## 2. Verified baseline (empirical, 2026-09-30)

Method: direct file reads + `git` inspection. Bash stdout is unreliable in this
environment, so outputs were redirected to a timestamped `/tmp` file and read back.

### 2.1 Repository state facts

- **Branch:** `fix/control-plane-evidence-integrity`.
- **Policy artifact:** `policies/AI_WORKFLOW_POLICY.md`, 251 lines, tracked, committed as
  `33c4f4a` ("feat(policies): add AI workflow policy with 15 levers and mandatory review
  checklist"). Pre-commit hooks passed at commit time (gitleaks, detect-private-key,
  end-of-file, trailing-whitespace, large-files).
- **Registration:** `policies/README.md` updated in the same commit to list the policy in
  the file table and add an explanatory section.
- **Working tree is NOT clean at the time of writing.** Uncommitted, and *not authored by
  this task*: `imports.tf` (modified), `repos_data.tf` (modified), `audit-evidence/pre-apply-plan.txt`
  (untracked), `docs/superpowers/plans/2026-09-27-viavitae-control-pre-deployment-per-repo-audit.md`
  (untracked). These are pre-existing and are explicitly out of scope (§7).
- **Existing sibling artifact:** `policies/AUDIT_PROMPT.md` (265 lines) — the evidence-gated
  audit prompt delivered by the 2026-09-25 spec, with gates 0–5, a fixed findings JSON
  schema, and a P0/P1/P2 severity rubric tied to exploitability.
- **Existing CI:** `.github/workflows/audit.yml` runs `terraform fmt -check`, `validate`,
  a toolchain-pin assertion, and `detect_drift.sh` on push/PR to `main`. It enforces
  *infrastructure* correctness, not *process* correctness.

### 2.2 The gap this spec addresses

`AUDIT_PROMPT.md` answers: *"is the control plane currently correct?"* It is a **detective**
control run against live state.

`AI_WORKFLOW_POLICY.md` answers: *"was this change authorized before it landed?"* It is a
**preventive** control applied during development.

Neither substitutes for the other. A repo can pass every audit gate and still have merged
an unauthorized AI change last week; conversely, a rigorous change-authorization process
does not guarantee the live org matches state today. Both are required, and they compose
(§4).

---

## 3. Decisions

### D1 — Encode levers as a ranked list, not an unordered checklist

Fifteen levers were considered. They are **not** equivalent, and presenting them as a flat
checklist would invite the reader to treat a nice-to-have (commit-message prefixes) as
equal to the actual control (human review sign-off). The policy therefore ranks them and
explicitly separates **engineering practice** (levers 3.1–3.8) from **compliance controls**
(levers 3.9–3.15).

Rejected alternative — *flat checklist*: simpler, but it obscures which items are
load-bearing. In an audit, "we follow 15 best practices" is weaker than "we have one
authorization control supported by fourteen quality practices."

### D2 — The review checklist is the control; everything else is supporting practice

This is the central design decision. Levers 3.1–3.8 reduce error *rate*; they do not
authorize *changes*. Only lever 3.9 (human-or-top-tier review gate) and its artifact
(the §5 checklist with a signed sign-off block) constitute the SOC 2 CC8.1 / ISO 27001
A.14.2.2 control, because only they produce a **recorded authorization decision by a
named authority**.

Consequence: the checklist is mandatory and its sign-off is a required commit/PR artifact.
The other fourteen levers are strongly recommended practice whose violation is a
finding, but whose absence does not by itself invalidate an otherwise-reviewed change.

### D3 — Plan-as-contract, with the plan as the cross-tier handoff artifact

The informal "prompt-as-handoff" practice (§1.4) is replaced by a **committed plan
document** as the only sanctioned handoff between tiers. Rationale: a plan in
`docs/superpowers/plans/` is version-controlled, reviewable, and diffable; a chat prompt
is none of these. The plan carries the exact file paths, exact code, exact verification
commands, expected outputs, and explicit STOP conditions — converting judgment into
determinism so a cheap tier can execute mechanically.

This leverages the existing plan-first infrastructure rather than inventing a parallel
one. It also means the "diff matches plan" check (lever 3.14) has a concrete reference
to check against.

Rejected alternative — *structured prompt templates*: a template is still ephemeral and
still transfers conclusions rather than a reviewable contract. Rejected for the same
reason the 2026-09-25 spec rejected a "machine-readable control catalogue" — it creates
a second, non-versioned source of truth.

### D4 — Tier provenance via commit-message prefix, not a separate ledger

Lever 3.11 requires recording which tier produced a change. The mechanism chosen is a
commit-message prefix (`ai:top`, `ai:mid`, `ai:cheap`, `ai:free`, `ai:review`) rather than
a separate provenance ledger or database.

Rationale: the prefix lives in the immutable git history, requires no new infrastructure,
is grep-able (`git log --grep '^ai:'`), and cannot silently diverge from the change it
describes. A separate ledger would be a second source of truth subject to the same
claim-vs-evidence divergence this spec exists to prevent.

Rejected alternative — *automated provenance capture*: no reliable mechanism exists to
detect which model tier authored an edit at commit time; self-declaration via prefix is
the honest, enforceable option.

### D5 — Compliance reasoning is reserved to humans and the top tier

Lever 3.12 forbids cheap tiers from deciding whether a control is *adequate*. In this
repo, `visibility` changes, `manage_files` flips, `enforce_admins`, and ruleset edits are
compliance decisions with org-wide blast radius (e.g. on the Free plan, making a repo
private silently disables secret scanning — documented in `repos.tf` gating and the
inventory comments). The plan must state the compliance rationale; the cheap tier executes
it but does not originate it.

This mirrors the repo's existing stance that the *owner*, not the agent, runs
`terraform apply` and makes visibility/legal decisions.

---

## 4. Integration with `policies/AUDIT_PROMPT.md`

The two artifacts are complementary halves of one evidence discipline. They integrate at
four points:

| Dimension | `AUDIT_PROMPT.md` | `AI_WORKFLOW_POLICY.md` |
|---|---|---|
| Control type | Detective (is it correct now?) | Preventive (was it authorized?) |
| Runs against | Live state + live GitHub API | The development process / a diff |
| Trigger | Each audit cycle | Every AI-generated change |
| Output | Findings JSON (`VV-YYYY-MM-NNN`) | Review checklist sign-off |
| Shared stance | *Documentation is a claim, not evidence* | *An agent's success assertion is a claim, not evidence* |

**Composition:**

1. The audit prompt's **Gate 1 (source-of-truth integrity)** should, in a future cycle,
   additionally assert that recent AI-authored commits carry a tier prefix and a recorded
   sign-off. Until then, this is a manual audit step.
2. A change that the workflow policy let through *without* a completed checklist is, by
   definition, an audit finding under SOC 2 CC8.1 — it will surface when the audit prompt
   next examines whether changes were authorized.
3. Both artifacts cite the same framework vocabulary and the same P0/P1/P2 severity
   rubric, so a process violation and an infrastructure violation are ranked on one scale.

This spec deliberately does **not** modify `AUDIT_PROMPT.md`; the integration is documented
here and the gate enhancement is deferred to §7 to keep this change non-destructive and
reviewable in isolation.

---

## 5. Compliance mapping of the 15 levers

Each lever maps to at least one framework control. Levers marked **[C]** are compliance
controls (authorization / accountability); the rest are **[P]** engineering practice.

| # | Lever | Type | SOC 2 | ISO 27001 | GDPR |
|---|---|---|---|---|---|
| 3.1 | Persistent rules/memory | [P] | CC2.2 | A.7.2.2 | — |
| 3.2 | Attach the right files explicitly | [P] | CC2.2 | A.14.2.1 | — |
| 3.3 | Skills as a pipeline | [P] | CC8.1 | A.14.2.2 | Art. 24 |
| 3.4 | One task per session | [P] | CC8.1 | A.14.2.2 | — |
| 3.5 | Small diffs, frequent commits | [P] | CC8.1 | A.12.1.2 | — |
| 3.6 | Verify by command output | [P] | CC4.1 | A.14.2.8 | Art. 32 |
| 3.7 | Two-attempt escalation | [P] | CC7.3 | A.16.1.4 | — |
| 3.8 | Explicit STOP conditions | [P] | CC8.1 | A.12.1.2 | Art. 32 |
| 3.9 | **Human/top-tier review gate** | **[C]** | **CC8.1** | **A.14.2.2** | **Art. 5(2)** |
| 3.10 | **Plan-as-contract** | **[C]** | CC8.1 | A.14.2.1 | Art. 24 |
| 3.11 | **Audit trail of tier provenance** | **[C]** | CC2.2 | A.12.4.1 | Art. 5(2) |
| 3.12 | **No compliance reasoning by cheap tier** | **[C]** | CC5.2 | A.6.1.1 | Art. 24 |
| 3.13 | **Plan-only execution authority** | **[C]** | CC8.1 | A.12.1.2 | Art. 32 |
| 3.14 | **Diff-vs-plan check** | **[C]** | CC8.1 | A.14.2.8 | Art. 32 |
| 3.15 | **No silent fallback** | **[C]** | CC7.3 | A.16.1.3 | Art. 32 |

The load-bearing control for the authorization question is **3.9**, supported by **3.11**
(provenance) and **3.14** (intent verification). The remainder reduce the probability that
the reviewer is handed something wrong to approve.

---

## 6. Trade-offs

| Trade-off | Chosen | Cost | Why acceptable |
|---|---|---|---|
| Rigor vs. velocity | Mandatory checklist sign-off | Slows every AI change | A control plane for 30 repos + org policy is low-velocity, high-blast-radius by nature; the overhead is proportionate |
| Self-declared vs. auto-captured provenance | Commit-message prefix | Can be omitted by a careless author | No reliable auto-detection exists; grep-ability makes omission detectable in review and in audit |
| Policy-as-document vs. policy-as-code | Document + PR-review enforcement | Not machine-enforced yet | CI enforcement of a *process* control is hard; document-first matches the repo's existing `policies/` convention and can be hardened later (§7) |
| One spec covering both audit + workflow | Separate specs | Some conceptual overlap | Keeps each change reviewable in isolation; the 2026-09-25 spec is detective, this one is preventive |

**Rejected alternatives (summary):**

- **No policy, rely on reviewer diligence.** Rejected: undocumented diligence is not an
  auditable control and does not satisfy CC8.1's requirement for authorized changes.
- **Machine-enforce everything via CI hooks.** Rejected *for now*: tier provenance and
  plan-conformance are semantic judgments that CI cannot reliably make; forcing them into
  CI would produce vacuous green checks — the same "passing vacuously" anti-pattern the
  audit workflow explicitly avoids.
- **Fold this into `AUDIT_PROMPT.md`.** Rejected: conflates a preventive development
  control with a detective state audit; each needs a different trigger and audience.

---

## 7. Out of scope / follow-ups

1. **Pre-existing uncommitted working-tree changes** (`imports.tf`, `repos_data.tf`,
   `audit-evidence/pre-apply-plan.txt`, `docs/superpowers/plans/2026-09-27-...md`). Not
   authored by this task; must be reviewed and committed separately under their own
   authorization. This spec does not touch them.
2. **CI enforcement of tier prefixes and checklist presence.** A future
   `.github/workflows/` job could fail a PR whose AI-authored commits lack an `ai:`
   prefix or whose description lacks a sign-off block. Deferred: needs a reliable way to
   distinguish AI from human commits.
3. **`AUDIT_PROMPT.md` Gate 1 enhancement** to assert recent commits carry tier prefix +
   sign-off (§4). Deferred to keep this change isolated.
4. **A completed worked example** of the checklist applied to a real change, to serve as
   the canonical reference for future PRs. Recommended next artifact after this spec.
5. **Plan template** embedding the STOP-conditions and compliance-rationale sections that
   levers 3.8, 3.12, and 3.15 require. Recommended alongside item 4.
6. **Push + PR of this spec and the policy** — owner-executed after review; nothing is
   pushed to `main` by the implementer.

---

## 8. Validation plan

Every step is read-only and its output is captured as evidence:

1. `wc -l policies/AI_WORKFLOW_POLICY.md` — assert the artifact exists and its length
   matches the committed baseline (251 lines).
2. `git ls-files policies/AI_WORKFLOW_POLICY.md` — assert the policy is tracked (not an
   untracked claim).
3. `git log --oneline -1 -- policies/AI_WORKFLOW_POLICY.md` — assert the committing SHA
   (`33c4f4a`) and that the message carries the `ai:top` provenance prefix.
4. `git status --porcelain` — record the working-tree state honestly; confirm this task
   introduced only the new spec file.
5. Re-read §5 of the policy and confirm the checklist contains the "Diff matches plan",
   "No silent fallback", and sign-off items that §3–§5 of this spec claim are the control.
6. Cross-check the compliance mapping in §5 against the framework clauses named in the
   policy's own §9 References.

**No `terraform apply`. No `git push` to `main`. No `gh api` write verb. No commit without
explicit owner authorization.**

---

## 9. Acceptance criteria

- This spec exists at
  `docs/superpowers/specs/2026-09-30-viavitae-control-ai-workflow-policy-design.md`
  and articulates, for each of the four questions the owner posed: why the 15 levers
  matter (§3, §5), why the review checklist *is* the control (§3 D2, §5), how the policy
  integrates with `AUDIT_PROMPT.md` (§4), and the trade-offs and rejected alternatives
  (§6).
- The compliance mapping in §5 covers all 15 levers and names at least one framework
  clause per lever.
- Every empirical claim in §2 is reproducible from the read-only commands in §8.
- The spec does not assert that the policy is *enforced* — only that it is *documented*
  and *committed*. Enforcement is a §7 follow-up; claiming it now would reproduce the
  claim-vs-evidence divergence this repo exists to eliminate.
- No pre-existing uncommitted change is swept into this task's commit.
