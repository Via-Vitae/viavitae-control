# Toolchain Manifest and Pin-Drift Guard — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create one declared-toolchain manifest (`toolchain.yml`) and a guard (`scripts/check_toolchain_pins.sh`) that fails when this repository drifts from it — closing the two holes that the existing rule R4 cannot see: same-action-different-SHA drift and undeclared per-workflow version variables.

**Architecture:** `toolchain.yml` becomes the single place where a tool version and a canonical action commit are stated. The guard reads it with `awk` only (no `yq`, no new binary, no network, no secrets) and asserts three intra-repo invariants. It deliberately does **not** reimplement rule R4's canonical logic; it adds the identity check R4 lacks. Everything is git-tracked, so reversal is `git revert` and no Terraform state is touched anywhere.

**Tech Stack:** Terraform 1.16.1, `integrations/github` provider 6.13.0, Bash with `awk`/`sed`/`grep`, GitHub Actions, `gh` CLI (GET only, used for pre-plan verification only). Org: `Via-Vitae`, plan: **free**.

**Authority boundary:** Plan-only per `policies/AI_WORKFLOW_POLICY.md` §4. `terraform apply`, `gh api` write verbs, and `git push` to `main` are **prohibited** until the owner explicitly authorizes them.

**Related spec:** [2026-11-03-mise-toolchain-adoption-decision-package.md](../specs/2026-11-03-mise-toolchain-adoption-decision-package.md) §3.6, §6.1 Tier 1, §6.4
**Related findings:** VV-2026-11-002, VV-2026-11-004, VV-2026-11-005, VV-2026-11-008, VV-2026-11-010

---

## What this plan changes relative to the decision package

Two discoveries made during pre-plan verification materially alter Tier 1. Both are recorded here so the plan, not the spec, is the authority when executing.

**1. Rule R4 already exists and is already enforced — in 19 of 22 repos.**
`compliance-check.yml` contains an `action-pinning` job ("Action SHA pinning") that
greps every `uses:` and requires `@[0-9a-f]{40}$`. Measured 2026-11-03: 19 repos have
that workflow; **`viavitae-control`, `viavitae-hermes-agents` and `.github` do not**. So the
reason `viavitae-control` has two floating references is not an absent rule — it is a repo that
was never given the gate. This plan therefore **does not write a competing R4**. Adopting the
existing workflow into those repos is a separate, larger change (it brings the TruffleHog,
licence and governance jobs with it) and is scheduled as **Tier 2**, referenced in Out of scope
below, not implemented here.

**2. "Most-used SHA" is the wrong selection rule, and would have caused a silent downgrade.**
Frequency in Via-Vitae main checkouts:

| Action | SHA | Refs | Resolves to | Correct? |
| --- | --- | --- | --- | --- |
| `actions/checkout` | `11d5960a326750d5838078e36cf38b85af677262` | 227 | tag `v4` = `v4.4.0` | yes — and `audit.yml`'s `@v4` resolves to this same commit today |
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 36 | — | minority |
| `hashicorp/setup-terraform` | `b9cd54a3c349d3f38e8881555d616ced269862dd` | 3 | tag `v3` = `v3.1.2` | **NO — an older major** |
| `hashicorp/setup-terraform` | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | 0 in Via-Vitae | tag `v4` = `v4.0.1` | **yes** — and already pinned in `jol-control` and `jolarca-control` |

Had the manifest picked the most-used `setup-terraform` commit, `viavitae-control`'s CI would
have dropped from v4.0.1 to v3.1.2 with no reviewer intending it. **Selection rule for this plan:
the commit that the major tag resolves to today**, verified with
`gh api repos/<owner>/<repo>/git/ref/tags/<tag>`, cross-checked against `…/tags`. Both Tier 1
pins are then **behavioural no-ops** — the same commit `audit.yml` already runs.

---

## Plan metadata

| Field | Value |
|---|---|
| Plan author tier | top |
| Execution tier(s) | cheap |
| Review tier | human |
| Expected plan delta | `0 to add, 1 to change, 0 to destroy` **against the pre-change baseline this repo already carries** — see the correction in Task 7. No `.tf` file is touched, so the delta must be **identical before and after this plan**, and any *new* add, change, destroy or replace is a STOP |
| Blast radius | single repo (`viavitae-control`); no org mutation, no state mutation |
| New CI required context | **none** — the guard runs inside the existing `audit` job, so no ruleset change and no `apply` is needed |

---

## File structure

| Action | File | Responsibility |
|---|---|---|
| Create | `toolchain.yml` | Single source for declared tool versions and canonical action commits, with the evidence for each value stated inline |
| Create | `scripts/check_toolchain_pins.sh` | Guard: asserts this repo's workflows match `toolchain.yml`; exit 0 clean / 1 violation / 2 nothing checkable |
| Modify | `.github/workflows/audit.yml:33-39` | Pin the two floating refs; collapse the terraform version to one source by reading `.terraform-version` into an output |
| Modify | `.github/workflows/audit.yml:58` | Insert the guard step after `Check plan self-citations`, before any credential-dependent step |
| Modify | `policies/README.md:57-66` | Register the new guard as one row in the policy table |

No file outside this table may change. If one would, STOP.

---

## STOP conditions (required — policy §3.8)

The executing agent **halts immediately and reports** if any of the following occur:

- `terraform plan` shows **any `destroy`** or **any `replace`**.
- `terraform plan` output differs at all from the pre-change baseline, since this plan changes no `.tf` file.
- Any file outside the **File structure** table would be modified.
- The guard reports a violation on a reference the plan did not anticipate — specifically anything other than the two `@v4` refs in `audit.yml`.
- `actions/checkout@11d5960a326750d5838078e36cf38b85af677262` or `hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e` fails to resolve when checked with `gh api repos/<owner>/<repo>/git/commits/<sha>`.
- Any command returns a non-zero exit code not explicitly anticipated below.
- `check_toolchain_pins.sh` exits `2` on the real repository tree at any point after Task 3.

---

## Compliance rationale (policy §3.12)

This plan touches no `visibility`, `manage_files`, `enforce_admins` or ruleset value. It is
included anyway because it **adds and alters a change-control gate**, which is itself a
compliance decision. A cheap tier executes this rationale; it must not originate it.

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| Guard placement | after `Check plan self-citations`, before `Check CI credential` | A gate parked behind a credential failure is skipped, and a skipped check is indistinguishable from a passing one in the check list. Placement before credential steps makes its verdict independent. | SOC 2 CC7.2, ISO A.8.15 |
| Canonical selection rule | the commit the active major tag resolves to today, not the most frequent SHA | Frequency-based selection would have downgraded `setup-terraform` from v4.0.1 to v3.1.2 unintentionally. Pinning must be a decision, not a census artefact. | SOC 2 CC8.1, ISO A.8.32 |
| Guard scope | manifest-declared actions only; undeclared ones produce a notice, never a violation | Landing a gate that is red on arrival trains the operator to merge through red. Coverage is widened deliberately as the manifest grows. | SOC 2 CC8.1 |
| No new `uses:` line | the guard runs as `run:` bash | Adding a third-party action would need org allow-list admission; an unlisted action causes `startup_failure` with zero jobs and zero annotations, freezing every PR in the repo. | ISO A.5.21, SOC 2 CC9.2 |
| Exit `2` for nothing-checkable | absent rather than silent pass | An unchecked invariant must never look identical to a satisfied one. | ISO A.8.15, SOC 2 CC7.2 |

---

## Halt-and-report triggers (required — policy §3.15)

- **Do not conclude that an Action pin is broken because a REST lookup fails.** Measured 2026-11-03:
  `gh api repos/astral-sh/setup-uv/git/commits/e58605a9…` returned 404 and
  `…/commits/e58605a9…` returned 422, which looked like a broken pin. It is not:
  `openapi-diff` has run three times, all `success`, all twelve steps green including `Set up uv`,
  and the runner log records `Download action repository 'astral-sh/setup-uv@e58605a9…'`.
  REST commit endpoints are **not authoritative for Action references**. To settle whether a pin is
  real, read a run log: `gh run view <id> -R <org>/<repo> --log` and grep
  `Download action repository`. If no run exists for that workflow, **STOP and report** — absence of
  a run is not evidence of a working or a broken pin.
- Likewise **never take a canonical Action SHA from `git/ref/tags/<tag>`.** That endpoint returns the
  annotated **tag object** SHA when the tag is annotated, not the commit. For `astral-sh/setup-uv`
  it returned `e4db8464…` while the runner resolves `@v4` to `38f3f104…`. Both
  `pin.actions/checkout` and `pin.hashicorp/setup-terraform` happened to survive this because those
  tags are lightweight — that is luck, not method. Prefer the runner log; use
  `repos/<owner>/<repo>/tags` (`.commit.sha` is peeled) only as a cross-check.
- If the value of `tool.node` is ambiguous — the host has v20.20.2 while every repo declares 22 —
  **STOP and report**. This plan declares `22` because that is what 100 % of existing
  declarations state; aligning the host is a Tier 0 decision outside this plan.
- If a workflow uses `${{ }}` where the guard expects a literal version, **STOP and report** rather
  than adding a special case.
- If `awk` is unavailable on the runner, the guard exits `2`. **STOP and report** — do not install
  anything to make the step pass.

---

## Tier routing for this plan (policy §6)

| Task | Tier | Rationale |
|---|---|---|
| T1 · write `toolchain.yml` | cheap | exact content supplied; typing, not thinking |
| T2 · write the guard | cheap | exact script supplied |
| T3 · mutation proof | cheap | deterministic commands with stated expected exit codes |
| T4 · edit `audit.yml` pins | cheap | exact before/after blocks supplied |
| T5 · wire the guard step | cheap | exact insertion point and content |
| T6 · register in `policies/README.md` | cheap | one table row, all columns given |
| T7 · run deterministic gates, capture output | cheap | commands and expected output stated |
| Spec → this plan | top | decomposition, R4 discovery, selection-rule correction |
| Interpret any gate failure | top | diagnosis requires reasoning; two-attempt escalation applies |
| Review diff against this plan | top | judgment; policy §3.14 |

> **Why the rows are labelled `T1`…`T7` and not `Task 1`…`Task 7`.** The self-citation checker
> excludes the table header with the regex `/^[[:space:]]*\| Task /`, but `awk` on this host is
> **mawk 1.3.4**, which does not implement POSIX character classes — `[[:space:]]` degenerates to a
> literal set of characters. Under mawk that filter discards **every** row whose first cell begins
> with the word `Task `, not just the header. Measured 2026-11-03: a 10-row table recomputed as
> `tier_rows=3`. Writing `Task 1` here would have made the gate demand a number that is simply
> false about the document. This is a defect in `scripts/check_plan_selfcite.sh` (the same POSIX
> classes appear in `rationale_rows` and `file_rows`, so any row starting with `Field ` or `Action `
> is affected too) and is recorded as **VV-2026-11-014**. The guard-side fix — replace
> `[[:space:]]` with `[ \t]`, or run the checker under `gawk` — is deliberately **not** made here:
> it edits a CI-critical control and needs its own mutation proof. The workaround in this plan is
> visible, dated, and explained rather than silent.

**Escalation:** cheap tier fails the same step twice → stop, escalate to top tier with the exact
error output. Do not loop.

---

## Task 1: Create the toolchain manifest

**Files:**
- Create: `toolchain.yml`
- Verify: `awk` field-splitting round-trip

- [ ] **Step 1: Write `toolchain.yml` with exactly this content**

```yaml
# toolchain.yml — single source of truth for declared tool versions and canonical
# GitHub Action commits in the Via-Vitae control plane.
#
# WHY FLAT KEYS. `yq` is ABSENT on this host (verified 2026-11-03) and the guard
# must not require a new binary, so the manifest is flat `key: value` YAML: valid
# YAML for humans and tools, parseable by awk field-splitting for the guard.
# DO NOT NEST — a nested mapping breaks the guard's parser and it will exit 2,
# not silently pass.
#
# WHY THIS FILE EXISTS. Rule R4 (compliance-check.yml `action-pinning`) proves a
# reference IS a 40-char SHA. It cannot prove it is the SAME SHA the other repos
# use. Measured 2026-11-03: actions/checkout is pinned to 3 distinct commits and
# aquasecurity/trivy-action to 4, every one of them R4-green. Separately,
# NODE_VERSION and PYTHON_VERSION are re-declared per workflow file per repo
# (~40 declarations of two numbers) with no gate anywhere.
#
# Every value carries its evidence. A value without a stated source is a claim,
# not evidence, and must not be merged.

schema_version: 1
updated: 2026-11-03

# --- declared tool versions (the host and CI must agree on these) -----------
tool.node: "22"
    # Every repo that declares one declares 22: viavitae-api ci.yml:42,
    # compliance-check.yml:38, viavitae-brand ci.yml:42, viavitae-qa, viavitae-web,
    # viavitae-template and all ten landing scaffolds. viavitae-web/.nvmrc = 22.
    # Host /usr/bin/node is v20.20.2 — a live divergence (VV-2026-11-003). Fixing
    # the host is Tier 0 and is OUT OF SCOPE here; this line states the intent.
tool.python: "3.12"
    # Declared identically across the estate. Host python3 is 3.12.3, so host and
    # CI agree today by coincidence of the Ubuntu 24.04 default, not by control.
tool.terraform: "1.16.1"
    # == viavitae-control/.terraform-version, == dpkg-query -W terraform (1.16.1-1).
    # jol-control and jolarca-control have NO pin file (VV-2026-11-007).
tool.pre_commit: "4.7.0"
    # .venv/bin/pre-commit --version. Declared NOWHERE today and absent from PATH:
    # it exists only inside a git-ignored venv (VV-2026-11-008). This line is the
    # first time the estate states it. Not yet asserted by the guard.

# --- canonical action commits -----------------------------------------------
# Selection rule: the commit the ACTIVE MAJOR TAG resolves to today. Read it from a
# RUNNER LOG (`gh run view <id> --log | grep "Download action repository"`), which
# is the only source that resolves an Action reference the way Actions does.
# git/ref/tags is NOT safe: for an annotated tag it returns the tag OBJECT, not a
# commit. It happened to agree for actions/checkout and hashicorp/setup-terraform
# because those tags are lightweight.
# NOT the most-used SHA. Frequency here would have picked
# hashicorp/setup-terraform@b9cd54a3 (tag v3, v3.1.2) and silently downgraded
# this repo from v4.0.1.
#
# DOWNGRADE WARNING — the rule has a failure mode. A pinned commit can be NEWER
# than the major tag, in which case converging on the tag is a downgrade.
# Observed: astral-sh/setup-uv@v4 installs uv 0.12.17, while viavitae-api's
# explicit pin e58605a9 installs uv 0.13.6. Before moving any reference onto a
# canonical value, compare what each one INSTALLS from a runner log, not just
# the commit dates. Where the pin is newer, the move is a decision for the owner
# and belongs in Tier 3, never in a drift sweep.
#
# RESOLVED for setup-uv on 2026-11-03: the downgrade is compatible. Both locks
# declare `revision = 3` and host uv 0.12.17 validates them unchanged
# (`uv lock --check --offline` exit 0: api 78 packages, hermes-agents 55).
# So moving api from 0.13.6 down to the tag commit is safe for the lockfiles and
# additionally makes host and CI agree on uv, which they do not today.
#
# Scope note: the guard checks only actions listed here. Undeclared actions
# produce a notice, never a violation, so landing this gate is not red on
# arrival. Widen deliberately (Tier 3), never accidentally.

pin.actions/checkout: 11d5960a326750d5838078e36cf38b85af677262
    # = tag v4 = v4.4.0 (verified 2026-11-03). 227 of 266 Via-Vitae references
    # already use it. audit.yml's current `@v4` resolves to this exact commit, so
    # pinning it is a behavioural no-op.
pin.hashicorp/setup-terraform: dfe3c3f87815947d99a8997f908cb6525fc44e9e
    # = tag v4 = v4.0.1 (verified 2026-11-03). audit.yml's current `@v4` resolves
    # to this commit, so pinning is a behavioural no-op. Zero Via-Vitae refs use
    # it but jol-control and jolarca-control already pin exactly this SHA.
    # The 3 Via-Vitae refs on b9cd54a3 are v3.1.2 and are a Tier 3 CONVERGENCE
    # item, not a Tier 1 change: upgrading is a decision, not a census result.
pin.astral-sh/setup-uv: 38f3f104447c67c051c4a08e39b64a148898af3a
    # = the commit the runner resolves tag `v4` to, read from a runner log rather than from the
    # REST API: hermes-agents run 40863836724 logged
    #   Download action repository 'astral-sh/setup-uv@v4' (SHA:38f3f104447c67c051c4a08e39b64a148898af3a)
    #   Successfully installed uv version 0.12.17
    # NOTE the inversion: gh api repos/astral-sh/setup-uv/git/ref/tags/v4 returns e4db8464…, which
    # is the ANNOTATED TAG OBJECT, not a commit — /commits on it answers 422. Never take a
    # canonical Action SHA from that endpoint; take it from a run log.
    # viavitae-api pins e58605a9… instead, and installs uv 0.13.6 — a NEWER uv than tag v4 gives.
    # That makes api's reference a Tier 3 CONVERGENCE DECISION, not a drift fix: converging api onto
    # 38f3f104 would DOWNGRADE its package manager. See the DOWNGRADE WARNING above.
```

- [ ] **Step 2: Verify the guard's parser reads it correctly**

Run from `viavitae-control`:

```bash
for k in tool.node tool.python tool.terraform pin.actions/checkout pin.hashicorp/setup-terraform pin.astral-sh/setup-uv; do
  printf '%-38s [%s]\n' "$k" "$(awk -v k="$k" 'BEGIN{FS=": *"} $1==k {v=$2; sub(/[[:space:]]+#.*$/,"",v); gsub(/"/,"",v); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); print v; exit}' toolchain.yml)"
done
```

Expected — exactly six lines, no empty brackets:

```
tool.node                              [22]
tool.python                            [3.12]
tool.terraform                         [1.16.1]
pin.actions/checkout                   [11d5960a326750d5838078e36cf38b85af677262]
pin.hashicorp/setup-terraform          [dfe3c3f87815947d99a8997f908cb6525fc44e9e]
pin.astral-sh/setup-uv                 [38f3f104447c67c051c4a08e39b64a148898af3a]
```

A bracket containing `# tool.node` or an empty bracket means the indentation of a
comment line was mistaken for a value. Comments in this file must start at column 1 or use a
leading `#` with no relationship to the key — **do not restructure the file to make this pass.**

- [ ] **Step 3: Re-verify the two lightweight-tag pins still resolve, on the day of execution**

Run from anywhere:

```bash
gh api repos/actions/checkout/git/ref/tags/v4 --jq '.object.sha'
gh api repos/hashicorp/setup-terraform/git/ref/tags/v4 --jq '.object.sha'
```

Expected: `11d5960a326750d5838078e36cf38b85af677262` and
`dfe3c3f87815947d99a8997f908cb6525fc44e9e`. If either differs, **STOP and report** — upstream moved
the tag and the manifest must state the new commit, not the old one. These two are safe to read from
this endpoint because both tags are lightweight; for any annotated tag use a runner log instead
(see the halt-and-report triggers).

- [ ] **Step 4: Commit**

```bash
git add toolchain.yml
git commit -m "chore(toolchain): add single-source version and canonical-pin manifest

Flat key:value YAML because yq is absent and the guard must add no binary.
Pins are the commits the active major tags resolve to today, read from runner
logs rather than from REST, which returns a tag OBJECT for annotated tags.
Not the most-used SHA: frequency would have downgraded hashicorp/setup-terraform
from v4.0.1 to v3.1.2.

Refs: VV-2026-11-002, VV-2026-11-004, VV-2026-11-010

ai:cheap"
```

---

## Task 2: Create the guard script

**Files:**
- Create: `scripts/check_toolchain_pins.sh`
- Verify: `bash -n` and the Task 3 mutation proof

- [ ] **Step 1: Write `scripts/check_toolchain_pins.sh` with exactly this content**

```bash
#!/usr/bin/env bash
# #############################################################################
# check_toolchain_pins.sh — fail when this repo drifts from toolchain.yml.
#
# WHY THIS EXISTS AND RULE R4 DOES NOT COVER IT. R4 (compliance-check.yml
# `action-pinning`) asserts a reference IS a 40-char SHA. It cannot assert the
# SHA is the one the rest of the org runs. Measured 2026-11-03, actions/checkout
# is pinned to three distinct commits and trivy-action to four, every one of them
# R4-green. And NODE_VERSION / PYTHON_VERSION are declared per workflow file with
# no gate at all. This script checks identity against a declared value, which is
# a different assertion from "is it long enough".
#
# It is NOT a full R4 replacement. Its floating-reference check exists because
# viavitae-control has no compliance-check.yml and so no R4 coverage at all.
# When Tier 2 lands compliance-check.yml here, DELETE the I1 floating-ref block
# and keep I2/I3 — that is stated inline below, not left to memory.
#
# CONTRACT (house guard contract, same as check_audit_register.py):
#   0  every applicable invariant holds
#   1  at least one violation found
#   2  unable to execute / nothing checkable — an unchecked invariant must never
#      look identical to a satisfied one
#
# No secrets. No network. Therefore it can and must run BEFORE credential gates:
# a step after a failure is skipped, and a skipped check reads as a pass.
# #############################################################################
set -uo pipefail

MANIFEST="${1:-toolchain.yml}"
WF_DIR="${2:-.github/workflows}"
# Repo root is derived from the MANIFEST path, not from cwd. Without this, the
# .terraform-version check below silently reads whatever file happens to sit in
# the working directory and reports a false pass when the guard is pointed at
# another tree. Found by mutation test D4/D5, not by reading.
ROOT="$(dirname "$MANIFEST")"   # "." when the manifest is given as a bare filename

command -v awk >/dev/null 2>&1 || { echo "awk required" >&2; exit 2; }
[[ -r "$MANIFEST" ]] || { echo "::error::manifest '$MANIFEST' unreadable — nothing verified" >&2; exit 2; }
[[ -d "$WF_DIR" ]] || { echo "::error::workflows dir '$WF_DIR' absent — nothing verified" >&2; exit 2; }

manifest_value() { # $1 = key; prints the value, or nothing if the key is absent
  awk -v k="$1" 'BEGIN{FS=": *"} $1==k {
    v=$2; sub(/[[:space:]]+#.*$/,"",v); gsub(/"/,"",v);
    gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); print v; exit
  }' "$MANIFEST"
}

violations=0
notices=0
checked=0

# Count of `uses:` lines that actually carry a reference, so a workflows
# directory full of comments cannot masquerade as a clean run.
total_refs=$(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$total_refs" == "0" ]]; then
  echo "::error::no action references found under $WF_DIR — nothing was checked" >&2
  exit 2
fi

echo "== toolchain manifest: $MANIFEST"
echo "== workflows: $WF_DIR ($total_refs reference(s) found)"
echo

# --- I1: every action reference is pinned ----------------------------------
# NOTE: overlaps rule R4 by design while viavitae-control has no
# compliance-check.yml. Delete this block when Tier 2 lands that workflow.
echo "-- I1 references must be 40-char SHAs"
while IFS=: read -r file lineno content; do
  ref=$(printf '%s' "$content" | sed -E 's/^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*//; s/[[:space:]]*#.*$//; s/[[:space:]]*$//')
  case "$ref" in ./*|docker://*) continue ;; esac
  checked=$((checked + 1))
  if [[ ! "$ref" =~ @[0-9a-f]{40}$ ]]; then
    echo "::error file=${file},line=${lineno}::floating action reference '${ref}' — must be pinned to a 40-char commit"
    violations=$((violations + 1))
  fi
done < <(grep -rnE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null)
echo

# --- I2: every pinned reference matches the manifest's canonical commit ------
echo "-- I2 pinned references must match the canonical commit in the manifest"
while IFS= read -r ref; do
  name="${ref%@*}"
  sha="${ref##*@}"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || continue
  canon="$(manifest_value "pin.$name")"
  if [[ -z "$canon" ]]; then
    echo "   notice: '$name' is pinned but not declared in $MANIFEST — not verified"
    notices=$((notices + 1))
    continue
  fi
  checked=$((checked + 1))
  if [[ "$canon" == "any" ]]; then
    echo "   ok: '$name' pinned; manifest declares 'any' (canonical commit unverified — see manifest comment)"
    continue
  fi
  if [[ "$sha" != "$canon" ]]; then
    echo "::error::'$name' is pinned to ${sha:0:12} but $MANIFEST declares ${canon:0:12} — same action, different commit across the estate"
    violations=$((violations + 1))
  fi
done < <(grep -rhoE 'uses:[[:space:]]*[^[:space:]]+' "$WF_DIR" 2>/dev/null \
          | sed -E 's/^uses:[[:space:]]*//; s/[[:space:]]*#.*$//' | sort -u)
echo

# --- I3: declared tool versions in workflows match the manifest --------------
# Deliberately uppercase-only. The lowercase `terraform_version:` input to
# hashicorp/setup-terraform is set to a steps expression by Task 4, so there is
# no literal left to reconcile; the installed-versus-declared loop is closed by
# I4 plus the existing `Assert toolchain pin` step. Do not add a lowercase rule.
echo "-- I3 declared tool versions must match the manifest"
for pair in "NODE_VERSION:tool.node" "PYTHON_VERSION:tool.python" "TERRAFORM_VERSION:tool.terraform"; do
  var="${pair%%:*}"; key="${pair##*:}"
  want="$(manifest_value "$key")"
  [[ -z "$want" ]] && continue
  while IFS=: read -r file lineno content; do
    got=$(printf '%s' "$content" | sed -E "s/^[[:space:]]*${var}:[[:space:]]*//; s/[[:space:]]*(#.*)?$//; s/\"//g")
    case "$got" in *'${{ '*) continue ;; esac   # expression, not a literal declaration
    [[ -z "$got" ]] && continue
    checked=$((checked + 1))
    if [[ "$got" != "$want" ]]; then
      echo "::error file=${file},line=${lineno}::${var} is '${got}' but $MANIFEST declares '${want}'"
      violations=$((violations + 1))
    fi
  done < <(grep -rnE "^[[:space:]]*${var}:" "$WF_DIR" 2>/dev/null)
done
echo

# --- I4: the Terraform pin file matches the manifest ------------------------
echo "-- I4 .terraform-version must match the manifest"
want_tf="$(manifest_value tool.terraform)"
if [[ -n "$want_tf" ]]; then
  if [[ -r "$ROOT/.terraform-version" ]]; then
    got_tf=$(tr -d '[:space:]' < "$ROOT/.terraform-version")
    checked=$((checked + 1))
    if [[ "$got_tf" != "$want_tf" ]]; then
      echo "::error::$ROOT/.terraform-version is '$got_tf' but $MANIFEST declares '$want_tf'"
      violations=$((violations + 1))
    fi
  else
    echo "::error::$ROOT/.terraform-version is absent but the manifest declares tool.terraform — cannot verify"
    violations=$((violations + 1))
  fi
fi
echo

# --- verdict ----------------------------------------------------------------
echo "== assertions evaluated: $checked · undeclared-action notices: $notices · violations: $violations"
if [[ "$checked" == "0" ]]; then
  echo "::error::nothing was checkable — every invariant found no subject. This is NOT a pass." >&2
  exit 2
fi
if [[ "$violations" -ne 0 ]]; then
  echo "TOOLCHAIN PIN CHECK FAILED: $violations violation(s)." >&2
  exit 1
fi
echo "OK: every declared tool version and canonical pin matches $MANIFEST."
exit 0
```

- [ ] **Step 2: Syntax-check without executing**

Run from `viavitae-control`:

```bash
bash -n scripts/check_toolchain_pins.sh && echo "SYNTAX OK"
```

Expected: `SYNTAX OK`. A here-string or subshell quoting error appears here, not at runtime.

- [ ] **Step 3: Make it executable and commit the working tree state**

```bash
chmod +x scripts/check_toolchain_pins.sh
git add scripts/check_toolchain_pins.sh
git commit -m "feat(scripts): add toolchain pin-drift guard

Asserts what rule R4 cannot: that a pinned action commit is the canonical one
in toolchain.yml, and that declared tool versions match the manifest. House
guard contract 0 clean / 1 violation / 2 nothing-checkable. No secrets, no
network, so it can run before credential gates.

Refs: VV-2026-11-002, VV-2026-11-010

ai:cheap"
```

---

## Task 3: Prove the guard is sensitive before trusting it

A guard never observed failing is not yet a control. This task is the whole point of the tier.

**Files:**
- Test: scratch copies under `/tmp/vv-guard/` only. **Never mutate a tracked file in the repo for a
  mutation test.**

- [ ] **Step 1: Build a scratch fixture tree**

Run from `viavitae-control`:

```bash
rm -rf /tmp/vv-guard && mkdir -p /tmp/vv-guard/.github/workflows
cp toolchain.yml /tmp/vv-guard/
cp .terraform-version /tmp/vv-guard/ 2>/dev/null || echo "1.16.1" > /tmp/vv-guard/.terraform-version
cat > /tmp/vv-guard/.github/workflows/sample.yml <<'EOF'
name: sample
on: [push]
env:
  NODE_VERSION: "22"
  PYTHON_VERSION: "3.12"
jobs:
  a:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0
      - uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1
        with:
          terraform_version: 1.16.1
      - uses: astral-sh/setup-uv@38f3f104447c67c051c4a08e39b64a148898af3a
EOF
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "BASELINE_EXIT=$?"
```

Expected: ends `OK: every declared tool version and canonical pin matches …` and `BASELINE_EXIT=0`.
If this is not 0, **STOP** — the guard is wrong, not the fixture.

- [ ] **Step 2: Inject defect 1 — a floating reference**

```bash
sed -i 's|actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0|actions/checkout@v4|' /tmp/vv-guard/.github/workflows/sample.yml
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "D1_EXIT=$?"
```

Expected: `D1_EXIT=1` with an `::error …floating action reference 'actions/checkout@v4'` line.

- [ ] **Step 3: Inject defect 2 — right action, wrong commit (the hole R4 cannot see)**

```bash
sed -i 's|actions/checkout@v4|actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1|' /tmp/vv-guard/.github/workflows/sample.yml
sed -i '/NODE_VERSION: "3.99"/d' /tmp/vv-guard/.github/workflows/sample.yml
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "D2_EXIT=$?"
```

Expected: `D2_EXIT=1` with `…'actions/checkout' is pinned to 3d3c42e5aac5 but toolchain.yml declares 11d5960a3267…`. This is the decisive case: **R4 would pass this reference.**

- [ ] **Step 4: Inject defect 3 — a version literal that disagrees with the manifest**

```bash
sed -i 's|actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1|actions/checkout@11d5960a326750d5838078e36cf38b85af677262|' /tmp/vv-guard/.github/workflows/sample.yml
sed -i 's|NODE_VERSION: "22"|NODE_VERSION: "20"|' /tmp/vv-guard/.github/workflows/sample.yml
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "D3_EXIT=$?"
```

Expected: `D3_EXIT=1` with `…NODE_VERSION is '20' but toolchain.yml declares '22'`.

- [ ] **Step 5: Inject defect 4 — a `.terraform-version` that disagrees**

```bash
sed -i 's|NODE_VERSION: "20"|NODE_VERSION: "22"|' /tmp/vv-guard/.github/workflows/sample.yml
echo "1.15.9" > /tmp/vv-guard/.terraform-version
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "D4_EXIT=$?"
```

Expected: `D4_EXIT=1` with `…/scratch…/.terraform-version is '1.15.9' but toolchain.yml declares '1.16.1'`.
If this returns 0, the `ROOT` derivation at the top of the script is missing or wrong — I4 is
reading the working directory instead of the fixture. That was the first defect this plan's own
mutation test caught.

- [ ] **Step 6: Inject defect 5 — a missing `.terraform-version` while the manifest declares terraform**

```bash
echo "1.16.1" > /tmp/vv-guard/.terraform-version && rm /tmp/vv-guard/.terraform-version
bash scripts/check_toolchain_pins.sh /tmp/vv-guard/toolchain.yml /tmp/vv-guard/.github/workflows; echo "D5_EXIT=$?"
```

Expected: `D5_EXIT=1` — "absent but the manifest declares tool.terraform — cannot verify". A
missing pin file is a **violation**, not a skip.

- [ ] **Step 7: Inject defect 6 — nothing checkable must exit 2, never 0**

```bash
rm -rf /tmp/vv-guard2 && mkdir -p /tmp/vv-guard2/.github/workflows && cp toolchain.yml /tmp/vv-guard2/
printf 'name: empty\non: [push]\njobs:\n  a:\n    runs-on: ubuntu-latest\n    steps:\n      - run: echo hi\n' > /tmp/vv-guard2/.github/workflows/none.yml
bash scripts/check_toolchain_pins.sh /tmp/vv-guard2/toolchain.yml /tmp/vv-guard2/.github/workflows; echo "D6_EXIT=$?"
```

Expected: `D6_EXIT=2` with `no action references found under … — nothing was checked`. **This is
the anti-vacuous-pass case.** If it prints 0, the guard is defective — fix the `total_refs` guard
before proceeding.

- [ ] **Step 8: Inject defect 7 — unreadable manifest must exit 2**

```bash
bash scripts/check_toolchain_pins.sh /tmp/does-not-exist.yml /tmp/vv-guard/.github/workflows; echo "D7_EXIT=$?"
```

Expected: `D7_EXIT=2`.

- [ ] **Step 9: Confirm the real repository tree exits 1, for the right reason**

Run from `viavitae-control`:

```bash
bash scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "REAL_EXIT=$?"
```

Expected at this stage, observed on 2026-11-03: `REAL_EXIT=1` with exactly **two**
floating-reference errors — `actions/checkout@v4` at `audit.yml:34` and
`hashicorp/setup-terraform@v4` at `audit.yml:37` — and a verdict line of
`== assertions evaluated: 3 · undeclared-action notices: 0 · violations: 2`. The three assertions
are the two I1 pin-shape checks plus one I4 `.terraform-version` check; I2 contributes nothing
because neither floating reference is a 40-char SHA.

That is finding VV-2026-11-005 correctly detected, and Task 4 clears it. If the count differs,
**STOP and report**.

- [ ] **Step 10: Clean up the scratch fixtures and commit nothing**

```bash
rm -rf /tmp/vv-guard /tmp/vv-guard2 && echo "fixtures removed"
```

Expected: `fixtures removed`. No tracked file was modified in Task 3, confirmed by
`git status --porcelain` printing nothing.

---

## Task 4: Pin `audit.yml`'s two references and collapse the Terraform version to one source

**Files:**
- Modify: `.github/workflows/audit.yml:33-39`

Both pins are **behavioural no-ops**: each SHA is the commit the current major tag resolves to
today (verified in Task 1 Step 3). The third change removes the duplicate `1.16.1` literal.

- [ ] **Step 1: Replace this exact block**

Current `.github/workflows/audit.yml` lines 33–39:

```yaml
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v4
        with:
          terraform_version: 1.16.1
```

Replace with:

```yaml
      - name: Checkout
        uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0 (tag v4)

      - name: Read the declared Terraform pin
        id: tfpin
        run: echo "version=$(cat .terraform-version)" >> "$GITHUB_OUTPUT"

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4.0.1 (tag v4)
        with:
          terraform_version: ${{ steps.tfpin.outputs.version }}
```

- [ ] **Step 2: Confirm `terraform_version` is now stated exactly once in the repo**

Run from `viavitae-control`:

```bash
grep -rn 'terraform_version\|1\.16\.1' .github/workflows/ .terraform-version toolchain.yml
```

Expected: `1.16.1` appears only in `.terraform-version` and `toolchain.yml`, and
`terraform_version:` in `audit.yml` is the `${{ steps.tfpin.outputs.version }}` expression — never
a literal. Three statements of the number become two, one of which is asserted against the other
by the existing `Assert toolchain pin` step, which stays.

- [ ] **Step 3: Validate the workflow YAML parses**

Run from `viavitae-control`:

```bash
.venv/bin/python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/audit.yml')); print('YAML OK')"
```

Expected: `YAML OK`. If `ModuleNotFoundError: yaml`, run
`.venv/bin/pip show pyyaml` and **STOP and report** rather than installing to make the check pass.

- [ ] **Step 4: Confirm the guard now passes the real tree**

Run from `viavitae-control`:

```bash
bash scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "REAL_EXIT=$?"
```

Expected: `REAL_EXIT=0` and `== assertions evaluated: 5 · undeclared-action notices: 0 · violations: 0`.
The five assertions are: two I1 pin-shape checks, two I2 canonical-commit checks, and one I4
`.terraform-version` check. `audit.yml` declares no `NODE_VERSION`/`PYTHON_VERSION`, so I3
contributes zero. **These numbers are from an observed run, not arithmetic — if you get a
different count, STOP and report** rather than editing the expectation to match.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/audit.yml
git commit -m "ci(audit): SHA-pin the two floating refs and read the terraform pin from one source

Both pins are the commits their major tags resolve to today, verified via
git/ref/tags, so the change is behaviourally inert. Rule R4 was not enforced
here because this repo has no compliance-check.yml; that adoption is Tier 2.
terraform_version is no longer a literal duplicated from .terraform-version.

Refs: VV-2026-11-005, VV-2026-11-004

ai:cheap"
```

---

## Task 5: Wire the guard into the CI job

**Files:**
- Modify: `.github/workflows/audit.yml` — insert after the `Check plan self-citations` step

- [ ] **Step 1: Insert the step immediately after `Check plan self-citations`**

Locate this existing step (`.github/workflows/audit.yml:54-57`):

```yaml
      - name: Check plan self-citations
        run: |
          chmod +x scripts/check_plan_selfcite.sh
          ./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md
```

Insert directly after it:

```yaml
      # Manifest conformance. Placed here on purpose: no secrets, no network, and
      # ahead of every credential-dependent step, because a step after a failure
      # is skipped and a skipped docs gate is indistinguishable from a passing one
      # in the check list. Exit 2 means "could not run", surfaced as a failure,
      # never as a pass.
      - name: Check toolchain pins match the manifest
        run: |
          chmod +x scripts/check_toolchain_pins.sh
          ./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows
```

- [ ] **Step 2: Validate and confirm ordering**

Run from `viavitae-control`:

```bash
.venv/bin/python -c "
import yaml
d = yaml.safe_load(open('.github/workflows/audit.yml'))
steps = [s.get('name','<no name>') for s in d['jobs']['audit']['steps']]
for i, s in enumerate(steps): print(f'{i:2} {s}')
"
```

Expected: `Check toolchain pins match the manifest` appears **after** `Check plan self-citations`
and **before** `Check CI credential (capability + least privilege)`. Also confirm `Checkout` is
step 0, so `toolchain.yml` exists on disk when the guard runs.

- [ ] **Step 3: Prove the wired command is what CI will execute**

Run from `viavitae-control` — the exact `run:` body, extracted rather than retyped:

```bash
bash -c "$(.venv/bin/python -c "
import yaml
d = yaml.safe_load(open('.github/workflows/audit.yml'))
print([s['run'] for s in d['jobs']['audit']['steps'] if s.get('name')=='Check toolchain pins match the manifest'][0])
")"; echo "WIRED_EXIT=$?"
```

Expected: the guard's own output, then `WIRED_EXIT=0`. This validates the embedded script by
executing the text actually stored in the workflow, not a hand-copy of it.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/audit.yml
git commit -m "ci(audit): run the toolchain pin guard before credential steps

Executed from the workflow YAML itself to prove the embedded script is what CI
runs. Placement is load-bearing: a docs gate parked behind a credential failure
proves nothing.

Refs: VV-2026-11-002

ai:cheap"
```

---

## Task 6: Register the guard

**Files:**
- Modify: `policies/README.md` — one new row in the policy table

- [ ] **Step 1: Add the row**

In `policies/README.md`, in the table that begins `| File | Purpose | Plan tier | Automatable? |`,
add after the `EMAIL_POLICY.md` row:

```markdown
| `../toolchain.yml` + `../scripts/check_toolchain_pins.sh` | Declared tool versions and canonical action commits, single-sourced; guard fails on drift R4 cannot see | Free+ | yes — CI step, no secrets, no network |
```

- [ ] **Step 2: Confirm every column is populated and the table still parses**

Run from `viavitae-control`:

```bash
awk -F'|' '/^\| `\/\.\.\/toolchain\.yml`/{print "cols=" NF-2}' policies/README.md
grep -c '^|' policies/README.md
```

Expected: `cols=4` (the table has four columns) and a row count one greater than before this edit.

- [ ] **Step 3: Commit**

```bash
git add policies/README.md
git commit -m "docs(policies): register the toolchain pin guard

New guards register as a row in the policies table, not in docs/COMPLIANCE.md,
with every column populated.

ai:cheap"
```

---

## Task 7: Deterministic gates and evidence capture

**Files:**
- Verify only. No file changes expected.

- [ ] **Step 1: Terraform gates — must be unchanged, since no `.tf` file was touched**

Run from `viavitae-control`:

```bash
terraform fmt -check -recursive && terraform init -backend=false && terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 2: Terraform plan — must show no delta **beyond the baseline this repo already carries****

First capture the baseline, then compare. Asserting a literal delta without measuring the
pre-change plan is how this plan produced a false STOP on its own first run.

```bash
TF_VAR_billing_email=ci-placeholder-not-applied terraform plan -no-color -input=false 2>&1 | tee /tmp/plan-after.txt | tail -3
grep -E '^Plan:|No changes' /tmp/plan-after.txt
```

Expected: `Plan: 0 to add, 1 to change, 0 to destroy` — the one change being
`module.repo["viavitae-template"].github_repository.is_template = false -> true`, declared by
commit `f0998f3` and never applied, which this plan does not touch.
**Any delta other than that exact resource and attribute — in particular any `destroy` or any
`replace` — is a STOP**, because this plan changes no Terraform configuration.

Measured on 2026-11-03 after Tasks 1–6: exit 0, `Plan: 0 to add, 1 to change, 0 to destroy`, the
single change being that `is_template` line, and `grep -c 'must be replaced|will be destroyed'`
returned **0**. No `.tf` file was modified by this run — confirmed with
`git diff --name-only f498b94..HEAD | grep '\.tf$'`, which returned nothing.

**`STOP — human approval required before this step`** applies to the pending
`terraform apply` that would settle `is_template`. It is **not** part of this plan and was not
run.

- [ ] **Step 3: Every markdown and provenance guard in the repo**

Run from `viavitae-control`:

```bash
./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md; echo "SELFCITE=$?"
.venv/bin/python scripts/check_audit_register.py docs/security/pre-deployment-independent-audit-2026-10-26.md docs/superpowers/specs/*.md; echo "REGISTER=$?"
./scripts/check_public_register.sh docs/SECRETS_INVENTORY.md; echo "PUBREG=$?"
```

Expected: `SELFCITE=0`, `REGISTER=0`, `PUBREG=0`. `SELFCITE` must report this plan's own
self-citations as matching; if it prints `STALE ASSERTION`, correct the number in this document —
do not delete the citation.

- [ ] **Step 4: The new guard on the real tree**

```bash
./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "TOOLCHAIN=$?"
```

Expected: `TOOLCHAIN=0`.

- [ ] **Step 5: Capture the diff-vs-plan evidence for the review checklist**

```bash
git log --oneline -6
git diff --stat HEAD~4..HEAD
```

Expected: four commits — manifest, guard, `audit.yml` pins, guard wiring, registration. Record the
line counts in the checklist below. Policy §3.5 asks for under 100 lines per commit for mechanical
changes; the guard script is the one substantive file and is exempt as non-mechanical.

- [ ] **Step 6: Do not push. Do not merge.**

**`STOP — human approval required before this step`** for `git push`, for opening the PR, and for
`gh pr merge`. Plan-only authority ends here.

---

## Out of scope for this plan

Deliberately excluded. Each has its own trigger and its own plan.

| Item | Why excluded | Trigger |
|---|---|---|
| Landing `compliance-check.yml` (rule R4 carrier) in `viavitae-control` and `viavitae-hermes-agents` | It brings the TruffleHog, licence and governance jobs too — a much larger change than pin conformance, and it needs the I1 block in this guard deleted at the same time | Tier 2 |
| Widening the manifest to all ~19 action names the estate uses | Deliberate incremental coverage; undeclared actions currently produce notices, not failures, so nothing breaks and nothing is falsely green | Tier 3, per repo batch |
| Converging the 3 Via-Vitae refs on `setup-terraform@b9cd54a3` (v3.1.2) up to v4.0.1 | A version **upgrade** is a decision with behaviour change, not a drift fix | Tier 3, with release notes read |
| Fixing host `node` v20.20.2 to match `tool.node: "22"` | Host mutation, and the 20-or-22 choice is an owner decision | Tier 0 |
| `sudo apt-mark hold terraform` | Host mutation | Tier 0 |
| `bootstrap.sh` for successor reproducibility | Depends on `tool.pre_commit` becoming authoritative | Tier 5 |
| Move `viavitae-api`'s `setup-uv@e58605a9` (uv 0.13.6) onto the canonical `v4` commit `38f3f104` (uv 0.12.17) | **Compatibility proven** — both locks are `revision = 3` and host uv 0.12.17 validates them unchanged (`uv lock --check --offline` exit 0). Out of this plan only because it edits another repository | Tier 3, now unblocked |
| Org-wide `sha_pinning_required = true` | Terraform-managed live org mutation, `apply`-gated, needs its own blast-radius assessment | Separate project |

---

## Review checklist (required — policy §5)

The reviewer (human, since there is no second identity) completes this **before commit and before
merge**, copying real command output into each line. A bare `[x]` with no citation is not a
sign-off. Metrics recomputed for this document by the checker's own expressions on 2026-11-03:
selfcite:stop_clauses=7 selfcite:halt_clauses=5 selfcite:rationale_rows=5
selfcite:file_rows=5 selfcite:tier_rows=10 selfcite:evidence_bullets=16
selfcite:tasks_open=49 selfcite:tasks_done=0

### Pre-commit checklist

- [ ] **Plan exists and is committed** — path: `docs/superpowers/plans/2026-11-03-viavitae-control-toolchain-manifest-and-pin-guard.md`
- [ ] **Plan includes STOP conditions** — 7 clauses, section present above
- [ ] **Plan includes compliance rationale** — 5 rows (placement, selection rule, scope, no new action, exit 2)
- [ ] **Plan includes explicit halt-and-report triggers** — 5 clauses, incl. the unexplained `setup-uv` 404
- [ ] **Deterministic gates passed** — paste: `fmt [ ] · validate [ ] · plan [ ]`
- [ ] **Diff matches plan** — expected `No changes. Your infrastructure matches the state.`; actual `[paste plan summary line]`
- [ ] **No silent fallback** — confirm no invented SHA, no installed package, no restructured manifest
- [ ] **Tier prefix in commit message** — `ai:cheap` on each of the four commits
- [ ] **Small diff** — `[N]` lines changed per commit (`git diff --stat HEAD~4..HEAD`)
- [ ] **No state mutation** — `terraform apply` was **not** run
- [ ] **Guard mutation proof done** — Task 3 Steps 2–6: D1–D5 each exit `1`; Step 7 nothing-checkable exits `2`; Step 8 unreadable manifest exits `2`

### Post-merge checklist

- [ ] **Post-merge plan confirms no drift** — paste: `No changes. Your infrastructure matches the state.`
- [ ] **Audit trail is complete** — `git log --grep '^ai:' --oneline` shows all four tier prefixes
- [ ] **Review sign-off is recorded** — present in the PR description below

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

---

## Execution record — 2026-11-03

Tasks 1–6 executed and committed on `docs/audit/landing-package-independent-review`. Task 7
halted at Step 2 on its own STOP condition and the halt was **correct**.

| Task | Commit | Observed evidence |
|---|---|---|
| Plan landed | `f498b94` | `check_plan_selfcite.sh` exit 0, 11 assertions recomputed |
| T1 manifest | `31db57b` | `check yaml` Passed; parser round-trip returned all six values; both tags still resolved to the declared commits on the day |
| T2 guard | `2ffa428` | `bash -n` clean; shipped file **byte-identical** to this plan's fenced script (`diff` empty) |
| T3 mutation proof | not a commit — scratch only | baseline 0; D1 1; D2 1; D3 1; D4 1; D5 1; no-references 2; unreadable manifest 2; real tree 1 with exactly 2 violations |
| T4 audit.yml pins | `c16baa8` | guard on the real tree: exit 0, **5 assertions evaluated, 0 violations** — the number this plan predicted from an observed run |
| T5 wire the step | `e73ae8f` | step index 7, after plan self-citations (6) and before the first credential step (11); the run body **extracted from the YAML** printed the verdict and exited 0 |
| T6 register | `9ac8bd6` | row added to the 3-column Script table (21 rows); `cols=3` |
| T7 gates | — | `fmt` clean · `validate` Success! · selfcite 0 · audit register 0 · public register 0 · secret inventory 0 · toolchain guard 0 · plan exit 0 |

**The halt.** Task 7 Step 2 returned `Plan: 0 to add, 1 to change, 0 to destroy`. The plan
asserted a literal `0 to change` and therefore had to fail. The change is
`viavitae-template.github_repository.is_template = false -> true`, declared in `f0998f3`, never
applied, and untouched by this run — `git diff --name-only f498b94..HEAD` lists no `.tf` file.
Two lessons were written back into this document: the plan must **capture a baseline before
editing and compare against it**, never against a remembered number; and a permanently pending
apply makes the estate's own "post-merge plan confirms no drift" checklist item unsatisfiable
(VV-2026-11-015).

**Not done, by design.** No `terraform apply`, no `git push`, no PR, no merge. Two further
things the operator should know: `audit.yml` triggers only on `push`/`pull_request` to `main`, so
this branch has **not** exercised the new guard in CI — it will run on the first PR to `main`, the
daily 06:30 UTC schedule after merge, or `workflow_dispatch`. And the step checkboxes above are
left unchecked deliberately: this document pins `selfcite:tasks_open=49` and
`selfcite:tasks_done=0`, and editing 49 boxes would make those assertions the only record of
completion instead of the commit hashes.

---

## Evidence base for the values in this plan

- `gh api repos/actions/checkout/git/ref/tags/v4` → `11d5960a326750d5838078e36cf38b85af677262`;
  `/tags` maps that commit to both `v4` and `v4.4.0`
- `gh api repos/hashicorp/setup-terraform/git/ref/tags/v4` → `dfe3c3f87815947d99a8997f908cb6525fc44e9e`;
  `/tags` maps `v4` to `v4.0.1` and `v3` to `b9cd54a3c349…` (`v3.1.2`)
- `gh api repos/astral-sh/setup-uv/git/commits/e58605a9b6da7c637471fab8847a5e5a6b8df081` →
  HTTP 404; `astral-sh/setup-uv` exists and is not archived; `/tags` lists v8.3.0 … v10.3.3 and
  none equals that commit
- `gh api repos/Via-Vitae/actions/permissions/selected-actions` → 9 floating patterns plus 2
  SHA-pinned `pnpm/action-setup`; `verified_allowed: true`; `sha_pinning_required: false`
- Workflow census, Via-Vitae main checkouts excluding `*-wt-*`: `actions/checkout` 227 refs on
  `11d5960a`, 36 on `3d3c42e5`, 3 floating; `hashicorp/setup-terraform` 3 refs on `b9cd54a3` plus
  1 floating; `aquasecurity/trivy-action` 4 distinct commits across 32 refs
- Rule R4 location: `viavitae-clients/.github/workflows/compliance-check.yml` line 10 (rule
  declaration) and lines 213–237 (the `action-pinning` job)
- R4 coverage: 19 of 22 repos with a workflows directory have `compliance-check.yml`; missing in
  `viavitae-control`, `viavitae-hermes-agents`, `.github`
- `yq` absent from the host; `awk` resolves to **mawk 1.3.4**; `sed`, `grep`, `jq` present
- `astral-sh/setup-uv@v4` resolves to `38f3f104447c67c051c4a08e39b64a148898af3a` and installs
  uv 0.12.17 (hermes-agents run 40863836724 log), while `viavitae-api` run 40863865907 logs
  `Download action repository 'astral-sh/setup-uv@e58605a9…'` and installs uv 0.13.6
- `viavitae-api/uv.lock` and `viavitae-hermes-agents/uv.lock` both declare `version = 1`,
  `revision = 3`, `requires-python = ">=3.12"`. Copied to a scratch directory, host uv 0.12.17
  runs `uv lock --check --offline` to **exit 0** on both (78 and 55 packages) — the repos were
  never touched. This is what makes the 0.13.6 → 0.12.17 convergence safe
- `openapi-diff.yml` has 3 runs, all `success`; its job reports 12 steps, every one `success`,
  including `Set up uv` and `Post Set up uv` — which falsified the earlier "broken pin" reading
  of the REST 404, and is why the halt-and-report triggers now name the runner log as authority
- `.terraform-version` = `1.16.1`; `dpkg-query -W terraform` = `1.16.1-1`; `apt-mark showhold`
  does not list terraform
- `/usr/bin/node` = v20.20.2 against `NODE_VERSION: "22"` declared across the estate
- `.venv/bin/pre-commit --version` = `pre-commit 4.7.0`; `command -v pre-commit` → absent from `PATH`
- `gh api repos/Via-Vitae/viavitae-control/rulesets/23943250` → `provenance` required, strict
  policy on, `bypass_actors: []`
- All measurements taken 2026-11-03 on host `jol`
