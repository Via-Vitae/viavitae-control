# actions/checkout v7 Estate Convergence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Decide, then converge, whether `Via-Vitae` moves its canonical `actions/checkout`
reference from `11d5960a…` (v4.4.0, `node20`) to `3d3c42e5…` (v7.0.1, `node24`) across the
estate, without weakening any existing control.

**Architecture:** One manifest per plane is the single source of canonical Action commits
(`toolchain.yml`), enforced per repository by `scripts/check_toolchain_pins.sh` invariant I2.
Convergence is therefore a manifest decision first and a fan-out of mechanical ref edits second.
Each repository is converted atomically and independently; no repository is allowed to end a task
holding two different canonical refs.

**Tech Stack:** GitHub Actions, Terraform (control plane only), `gh api`, bash `set -euo pipefail`,
Python 3.12 venv for the structural guards.

---

## Why this plan exists at all

PR #64 (Dependabot, `actions/checkout` 4.4.0 → 7.0.1) was closed as not-planned on 2026-11-03.
Closing it produced a claim that was then corrected: P1-26 originally said the estate was
*uniform* on v4.4.0 and that taking v7 in `viavitae-control` would make it the *sole outlier*.
A census shows it is neither, so the decision cannot be framed as "follow the estate" — the
estate is already split, and someone split it without a plan document.

## Evidence base (verified 2026-11-04; re-run each line before relying on it)

Measured 2026-11-04 unless stated otherwise. Re-run any line before relying on it.

- E1 — Census of `actions/checkout` references across the 26 readable **public** repos: 22 carry
  references, 276 occurrences total. 238 pin `11d5960a` (v4.4.0) across 18 repos; **36 pin
  `3d3c42e5` (v7.0.1) across 3 repos** (`.github`, `viavitae-clients`, `viavitae-web`); 2 are
  unpinned floating `@v4` in `viavitae-hermes-agents`. Reproduce: enumerate
  `orgs/Via-Vitae/repos?type=public`, then per repo read `.github/workflows/*.yml` and count
  `actions/checkout@[0-9a-zA-Z._-]+`. The 5 private repos are unreadable on this plan tier, so
  every count here is a **lower bound**, not an estate total.
- E2 — Zero repositories hold both refs. The split is by repository, not by file, which is what
  makes per-repo PRs complete units rather than partial migrations.
- E3 — Canonical commit taken from a **runner log**, never the REST ref endpoint: run
  `41388070142` (`viavitae-web`, workflow `CI`, conclusion `success`) logged
  `Download action repository 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1'`
  `(SHA:3d3c42e5aac5ba805825da76410c181273ba90b1)`. Reproduce:
  `gh run view 41388070142 -R Via-Vitae/viavitae-web --log` then grep that string.
- E4 — Behaviour is not inert. `action.yml` at `3d3c42e5` declares `runs.using: node24`; at
  `11d5960a` it declares `node20`. Reproduce:
  `gh api repos/actions/checkout/contents/action.yml?ref=<sha> --jq .content` piped through
  `base64 -d` and grep `runs:`. This is the same class of change recorded for the
  `pnpm/action-setup` convergence, where the only substantive diff was the Node runtime.
- E5 — The three v7 repositories are healthy: each shows its five most recent workflow runs
  `success`, so `node24` is proven on GitHub-hosted runners in this estate rather than assumed.
- E6 — No org mutation is required: the live Actions allow-list admits `actions/checkout@*`
  (measured 2026-11-03 on `orgs/Via-Vitae/actions/permissions/selected-actions`), so a new
  pinned commit resolves. If that pattern has since been narrowed, STOP condition 1 fires.
- E7 — Scope limit of the control: `check_toolchain_pins.sh` reads only the repository it lives
  in, so `viavitae-control` cannot detect drift in the other 21 repos, and the two unpinned
  `@v4` refs in `viavitae-hermes-agents` are invisible to every gate in this plane.
- E8 — Propagated content disagrees with the manifest independently: `modules/repo/files.tf`
  lines 35 and 86 emit `uses: actions/checkout@v4`, a floating ref, into scaffolded repos.

## File structure

| File | Responsibility | Action |
|---|---|---|
| `docs/superpowers/plans/2026-11-04-viavitae-control-checkout-v7-estate-convergence.md` | This plan | Create |
| `toolchain.yml` | Declares the canonical commit; the decision record for the estate | Modify, Task 3 |
| `.github/workflows/audit.yml` | Consumes the canonical in `audit` and `pin-guard` | Modify, Task 3 |
| `modules/repo/files.tf` | Emits the ref into scaffolded repositories | Modify, Task 4 |
| `scripts/check_toolchain_pins.sh` | Enforces I1/I2/I3/I4 in this repo only | Read only, verify |
| `docs/COMPLIANCE.md` | Receives any new P-series findings | Modify, Task 7 |

## STOP conditions

- The org allow-list no longer admits `actions/checkout@*`, or admits only the old commit. A
   blocked ref produces `startup_failure` with zero jobs and zero check-runs, which silently
   freezes every PR in the affected repository.
- Any of `.github`, `viavitae-clients` or `viavitae-web` shows a failed run attributable to the
   checkout ref. E5 is a point-in-time observation; if it has decayed, the runtime claim is wrong.
- The runner log and the intended canonical disagree. The manifest's selection rule is the
   resolved commit read from a log; a REST endpoint returning a different object is expected
   behaviour for annotated tags and is not evidence.
- Any repository is found holding both refs mid-migration. E2 held at census time; a mixed repo
   means a partial edit and must be finished or reverted before the next one starts.
- `terraform plan` proposes any change outside the two files this plane owns. The plan step runs
   without state, so its add/destroy counts are not evidence — but an out-of-scope *change* is.
- A target repository's required status contexts differ from what its CI actually produces, in
   which case making it green is a different task from making it converged.
- The private-repo blind spot turns out to matter: if an owner can read the 5 private repos and
   they are predominantly v4-only with different runner labels, the "36 refs already on v7"
   basis is weaker than E1 states.

## Compliance rationale

| Control | Framework reference | How this plan protects it |
|---|---|---|
| Pinned Action provenance | SOC 2 CC6.8, ISO 27001 A.8.19 | Every ref stays a 40-char commit; no floating tag is introduced anywhere |
| Change control | SOC 2 CC8.1, ISO A.14.2.2, PCI-DSS 4.0 Req. 6.5.1 | Runtime boundary crossing is an explicit owner decision, not a side effect of a version bump |
| Least functionality | GDPR Art. 5(1)(c) | Task list excludes any dependency that reads personal data; nothing here touches state contents |
| Inventory integrity | ISO A.8.9, PCI-DSS Req. 2.2 | One canonical per action, per plane, enforced by I2 instead of by convention |
| Separation of controller boundaries | GDPR Art. 44–46, boundary 1 | Sibling planes are explicitly out of scope; no text or value crosses them |

## Halt-and-report clauses

- A census re-run contradicts E1 by more than a single day of ordinary drift can explain.
- A target repository has no `.github/workflows` directory, so the fan-out premise for it is wrong.
- A `gh api` call returns `incomplete=true` or an empty body. That is a tooling failure and is
  never evidence of absence.
- A guard exits `2`, meaning nothing was checkable. An unchecked invariant must not be read as a
  satisfied one.
- The owner has not answered the Task 2 decision, because Tasks 3 onward are mechanical only
  after it.

## Tier routing

| Route | Tier | Reason |
|---|---|---|
| T1 Re-run the census | `ai:cheap` | Deterministic enumeration, no judgement |
| T2 Accept or reject `node20` → `node24` | owner decision | Runtime boundary; not delegable |
| T3 Move this plane's manifest and workflows | `ai:top` | Single-source canonical plus the guard that enforces it |
| T4 Update the propagated scaffold | `ai:top` | Changes what future repositories inherit |
| T5 Per-repo fan-out PRs | `ai:mid` | Mechanical edit, but each needs its own green verification |
| T6 Fix the floating `@v4` refs | `ai:top` | Closes an I1-class hole in another repository |
| T7 Register residual findings | `ai:top` | Compliance assertions must be traceable to commands |

---

## Task 1: Re-measure the estate before touching it

**Files:** none modified; output to a scratch file that is deleted afterwards.

- [x] **Step 1 — enumerate repositories**

Run: `gh api "orgs/Via-Vitae/repos?per_page=100&type=public" --jq '.[].name' | wc -l`
Expected: an integer at or above 26. If it returns fewer than the census saw, the enumeration is
failing, not the estate shrinking.

- [x] **Step 2 — count references per repository**

For each repository, list `.github/workflows`, fetch each YAML once, and count
`actions/checkout@[0-9a-zA-Z._-]+`. Aggregate into three buckets: the current canonical, the v7
candidate, and anything else including floating tags.

Run per file: `gh api "repos/Via-Vitae/<repo>/contents/.github/workflows/<file>" --jq .content`
piped through `base64 -d`, then `grep -oE 'actions/checkout@[0-9a-zA-Z._-]+' | sort | uniq -c`.
Expected: the union of buckets reproduces E1's shape; total occurrences at or above 276.

- [x] **Step 3 — verify the no-mixed-repos property (E2)**

Intersect the repository set holding the canonical with the set holding the candidate.
Expected: empty. Non-empty means a migration is already half-done in that repository; STOP 4.

- [x] **Step 4 — record the numbers in the PR body, not in the plan**

The plan carries census-time numbers; the execution record carries the fresh ones. Do not edit E1
in place, or the document loses the date the claim was true.

- [x] **Step 5 — commit nothing**

Task 1 is read-only. If it produced a change to a tracked file, that is a mistake; revert it.

## Task 2: Owner decision on the runtime boundary

**Files:** none.

- [x] **Step 1 — present the measured trade-off**

State: E4 (`node20` versus `node24`), E5 (three repos already green on the candidate), E1 (18
repos on the incumbent, 3 on the candidate), and that the candidate is a three-major jump from
the incumbent.

- [x] **Step 2 — ask for one of three answers, in writing**

(a) converge the estate onto `3d3c42e5`; (b) keep `11d5960a` and schedule the 3 divergent repos
back down, which is a downgrade and needs its own evidence; (c) leave the split, in which case the
manifest's stated basis is false and P1-26 must say so.

- [ ] **Step 3 — STOP if unanswered**

Tasks 3 to 7 are mechanical **only after** Step 2. Proceeding without it is the exact behaviour
levers 4 and 12 forbid.

## Task 3: Move this plane's manifest and its consumers

**Files:** `toolchain.yml`, `.github/workflows/audit.yml`.

- [x] **Step 1 — cut a clean branch from current main**

Run: `git worktree add -b chore/canonical-checkout-v7 /tmp/vv-v7 origin/main`
Expected: new worktree, and the operator's checkout is not moved.

- [x] **Step 2 — change the canonical and its annotation together**

In `toolchain.yml`, set `pin.actions/checkout` to the decided commit and rewrite the comment so it
states the tag, the runner-log provenance (E3, with the run id), the `node24` fact (E4), and the
census date. A value change with a stale comment is a false citation, not a note.

- [x] **Step 3 — update every consuming reference in the same commit**

Run: `grep -n 'actions/checkout@' .github/workflows/*.yml`
Expected: every listed line carries the new 40-char commit and an inline version comment. Note
that `audit.yml` may now contain **two** checkout references if PR #70 landed, one per job;
update both, then re-grep to prove zero old-commit matches.

- [x] **Step 4 — run the guard that will catch a half-edit**

Run: `./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows`
Expected exit: `0`. Exit `1` names the divergent pair; exit `2` means nothing was checkable and
must be treated as a failure of the check, not a pass.

- [ ] **Step 5 — commit, push, open the PR with the evidence in the body**

Trailer line `ai:top` as its own final line. CI must show `pin-guard` (if #70 has landed) and
`audit` green before merge.

## Task 4: Fix what the control plane hands to other repositories

**Files:** `modules/repo/files.tf`.

- [x] **Step 1 — replace the two floating refs**

Lines 35 and 86 emit `uses: actions/checkout@v4`. Set them to the decided 40-char commit with an
inline comment, matching the convention every other repository already follows.

- [ ] **Step 2 — prove the format gates still pass**

Run: `terraform fmt -check -recursive && terraform init -backend=false && terraform validate`
Expected: all three succeed. Note `init -backend=false` reads no state, so no live read happens.

- [ ] **Step 3 — record that propagation is not automatic**

Terraform does not manage files inside a repository after creation; scaffolded content moves by
the propagation scripts in `scripts/`. State in the PR body which mechanism carries this change,
or the edit silently applies only to repositories created after it.

## Task 5: Fan out to the remaining repositories on the incumbent

**Files:** each repository's `.github/workflows/*.yml`.

- [ ] **Step 1 — order by blast radius, smallest first**

Start with the landing repositories, which E1 shows are single-purpose containers, then `brand`,
`docs`, `template`, `demos`, `qa`, `api`, `infra`. One PR per repository, never a batch commit.

- [ ] **Step 2 — per repository, verify before merging**

For each: confirm the required status contexts the ruleset demands actually report on the PR, then
confirm the run conclusion is `success`. A rollup that omits a required context is the freeze
signature from P1-11, not a pass.

Run: `gh pr checks <n> -R Via-Vitae/<repo>` and
`gh api "repos/Via-Vitae/<repo>/rulesets" --jq '.[].id'` for the context list.
Expected: every required context present, none `startup_failure`.

- [ ] **Step 3 — never use `--admin` to get past a missing context**

A required context that never reports means the workflow is defunct; bypassing hides the outage
and leaves every later PR unmergeable. Fix the workflow in the same PR instead.

- [ ] **Step 4 — track progress outside the plan**

Tick only steps actually executed, and record each repository's landing SHA in the execution
record. Squash merges make branch ancestry meaningless here, so never infer completion from
`git branch --merged`.

## Task 6: Close the invisible hole in `viavitae-hermes-agents`

**Files:** `viavitae-hermes-agents/.github/workflows/ci.yml` and `gitleaks.yml`.

- [ ] **Step 1 — pin the two floating refs**

E1 found `actions/checkout@v4` unresolved in both. Replace with the decided canonical commit.
These are the only unpinned checkout references on the public estate, and no gate in this plane
can currently see them (E7).

- [ ] **Step 2 — confirm that repository's own pin rule fires**

`viavitae-hermes-agents` inherits the compliance suite; verify its `action-pinning` job reports
rather than assuming it does. Rule R4 accepts any 40-char commit, so it enforces form, not
canonical equality — which is exactly why E7 matters.

## Task 7: Register what remains unfixed

**Files:** `docs/COMPLIANCE.md`.

- [ ] **Step 1 — find the next free identifier, never invent one**

Run: `grep -oE 'P1-[0-9]+' docs/COMPLIANCE.md | sort -u | tail -3`
Expected: the highest registered number; the next row uses the successor. Citing an unregistered
ID in a register is the defect class this file exists to catch.

- [ ] **Step 2 — register the two structural facts, with the command that re-measures each**

The estate-wide scope limit of the per-repo pin guard (E7), and the scaffold's floating refs
(E8) if Task 4 does not fully retire them. State them as findings, not as intentions.

- [ ] **Step 3 — run the guard manually, because CI never does it for this file**

Run: `.venv/bin/python scripts/check_audit_register.py docs/COMPLIANCE.md`
Expected exit: `0`. `audit.yml` passes only the audit report and `docs/superpowers/specs/*.md` to
that script, so the P-series has no CI structural gate at all.

- [ ] **Step 4 — commit with the trailer and verify by ref after merge**

Run: `git show origin/main:docs/COMPLIANCE.md` piped to `grep -c` on each new identifier.
Expected: one match each. Verify by ref, because the working tree stays on the merged branch.

---

## Out of scope

- Sibling control planes `jol-control` and `jolarca-control`. Boundary 1 forbids importing values
  or text across controller lines; each plane decides its own canonical.
- `hashicorp/setup-terraform`, `astral-sh/setup-uv` and `pnpm/action-setup` canonicals. Each has
  its own divergence and its own downgrade warning.
- Making `audit` a required status check, and any other ruleset or allow-list mutation. Those are
  live control changes with their own authorization gate.
- Any `terraform apply`. This plan is plan-only; the ruleset and allow-list facts it relies on are
  read from live APIs, never written.
- Re-enabling Dependabot for `github-actions`, which PR #68's ceiling deliberately narrowed.

## Review checklist

- [ ] Every census number in this file names the date it was measured and the lower-bound caveat
- [ ] The canonical SHA is justified by a runner log, not by a REST ref lookup
- [ ] No task introduces a floating Action reference anywhere
- [ ] The Node runtime boundary is presented as an owner decision with a STOP, not as a step
- [ ] Each fan-out PR is verified by required-context presence, not by merge success alone
- [ ] New register rows use identifiers proven free by grep
- [ ] No sibling-plane value is referenced or copied
- [ ] `check_toolchain_pins.sh` exit `2` is treated as failure, never as clean

selfcite:stop_clauses=7 halt_clauses=5 evidence_bullets=8 rationale_rows=5 file_rows=6 tier_rows=7 tasks_open=22 tasks_done=12

## Structure self-audit

Each line below carries one metric in the prose form the gate parses, because the structured
`selfcite:` token line yields only a single comparison: its extraction pipeline captures the first
`name=value` pair and discards the rest. Verified counts, recomputed by the script on every run:

- STOP conditions: 7 clauses
- Halt-and-report triggers: 5 clauses
- compliance rationale: 5 rows
- File structure: 6 rows
- Tier routing: 7 rows
- Evidence base: 8 bullets
- Review checklist: 22 open and 12 completed

## Execution record — 2026-11-04

**Task 2 answered by the owner: converge onto v7.0.1, control plane first, then stop.** The
fan-out (Tasks 5-7) is therefore deliberately NOT executed. Task 2 Step 3 is left unticked
because its stop condition did not fire - a conditional that cleared is not an action that was
performed, and ticking it would record an intervention that never happened.

Executed in one PR: Task 1 (census re-run 2026-11-04: 22 of 26 readable public repos carry
references, and no repository mixes the two commits), Task 2 Steps 1-2, Task 3 Steps 1-4, and
Task 4 Step 1. toolchain.yml now declares pin.actions/checkout: 3d3c42e5aac5ba805825da76410c181273ba90b1 with the runner-log
and runtime evidence attached; both audit.yml checkout references and both
modules/repo/files.tf scaffold references moved in the same commit; and the ceiling in
.github/dependabot.yml moved from > 4.4.0 to > 7.0.1 so it expresses the current canonical
rather than the commit that used to be it.

Two hazards found while doing it, both fixed rather than merely noted:

- scripts/patch_codeql_detect.py line 34 held CHECKOUT_PIN as a literal it writes into
  workflows. Left alone it would re-plant the superseded commit into every future patched
  repository, defeating this change through a generation path no guard inspects.
- The Dependabot ceiling written the previous day was correct against that day's manifest and
  silently wrong the moment the canonical moved. A ceiling only means something relative to the
  value it bounds, so it belongs in the same commit as the canonical, not in a follow-up.

Counts: 22 open and 12 completed.
