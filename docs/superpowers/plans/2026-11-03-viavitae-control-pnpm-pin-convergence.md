# pnpm Action-Setup Pin Convergence — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put every Via-Vitae repository on one `pnpm/action-setup` commit that the org allow-list already admits, so `viavitae-qa` PR #14 stops being frozen and no future Dependabot bump can freeze another PR.

**Architecture:** The estate pins three different commits of the same action while the allow-list admits two of them. Convergence is done **ref-side first, allow-list-side second**: move every workflow reference onto the newest already-admitted commit, prove each repo's CI still starts, and only then retire the stale patterns. Reversing that order freezes 21 repositories.

**Tech Stack:** Terraform 1.16.1 (`variables.tf` → `github_actions_organization_permissions`), GitHub Actions, `gh` CLI, `toolchain.yml` + `scripts/check_toolchain_pins.sh` landed by PR #53.

**Authority boundary:** **Plan-only.** Task 4 is a `terraform apply` against the live org and is prohibited until the owner issues an explicit authorization. Tasks 1–3 write to repositories through PRs only; no merge, no push to `main`.

**Related spec:** [2026-11-03-mise-toolchain-adoption-decision-package.md](../specs/2026-11-03-mise-toolchain-adoption-decision-package.md) §5.5, VV-2026-11-013, VV-2026-11-016
**Related findings:** VV-2026-11-002, VV-2026-11-013, VV-2026-11-016

---

## The headline, and why it is not the obvious fix

The obvious fix is "add `pnpm/action-setup@fc06bc12…` to the allow-list so qa PR #14 can run." Measured evidence says do not do that:

| Commit | Tags pointing at it | Where used | Allow-listed? |
| --- | --- | --- | --- |
| `b906affcce14559ad1aafd4ab0e942779e9f58b1` | `v4.3.0`, `v4` | 21 refs across Via-Vitae | yes |
| `ea17c68df8912ef543352723c149a84f56e3d413` | **`v6.1.0`** | 9 refs across Via-Vitae | yes |
| `fc06bc1257f339d1d5d8b3a19a8cae5388b55320` | `v5.0.0`, `v5`, `v4.4.0` | qa PR #14 only | **no — the freeze** |

`ea17c68d` is **v6.1.0**, is **already admitted**, and is **newer than what the PR proposes**. So convergence onto the already-admitted newest commit unblocks qa **without touching the org allow-list at all**, and it retires a pattern instead of adding one.

Two further checks that removed plausible-looking alternatives:

- **`pnpm/action-setup` is not deprecated.** Its README states it continues to work with pnpm v11 and v12 alongside `actions/setup-node`; `pnpm/setup` is an *additional* action that installs a self-contained binary and optionally a JS runtime. Migrating to `pnpm/setup` would also let `actions/setup-node` go, but that is a separate redesign, not a pin fix.
- **The estate's pnpm itself is v9.** `viavitae-qa` and `viavitae-web` declare `packageManager: "pnpm@9.15.0"`, `viavitae-demos` `"pnpm@9.12.0"`. action-setup v6.1.0 supports "pnpm v12 and earlier", so v6.1.0 is compatible with every `packageManager` pin in the estate.

---

## Plan metadata

| Field | Value |
|---|---|
| Plan author tier | top |
| Execution tier(s) | cheap for Tasks 1–3, human for Task 4 |
| Review tier | human |
| Expected plan delta | Task 4 only: `0 to add, 1 to change, 0 to destroy` on `github_actions_organization_permissions.this`. Tasks 1–3 touch no Terraform. |
| Blast radius | Tasks 1–3: ~30 workflow files across Via-Vitae, one PR each. Task 4: org-wide Actions admission. |
| Freeze risk | **Ordering-dependent.** Retiring `b906affc` while any reference still uses it reproduces the exact `startup_failure` this plan fixes, across every affected repo at once. |

---

## File structure

| Action | File | Responsibility |
|---|---|---|
| Modify | `toolchain.yml` | Add `pin.pnpm/action-setup` as the single canonical commit, with its evidence |
| Modify | `variables.tf:226-240` | Retire the stale pnpm pattern once no reference uses it; keep exactly one |
| Modify | `.github/workflows/*.yml` in each consuming repo | Replace the pnpm reference with the canonical commit |
| Create | `scripts/check_startup_failures.sh` | Detectability guard: name every open PR whose workflow last concluded `startup_failure` |

---

## STOP conditions (required — policy §3.8)

The executing agent **halts immediately and reports** if any of the following occur:

- Any repo's post-change CI run concludes `startup_failure`. That means the target commit is not admitted, and continuing will freeze more repos.
- `grep` finds a `pnpm/action-setup` reference to a commit other than the canonical one **after** Task 3 is declared complete.
- Task 4 is about to run without the owner's explicit authorization sentence for a live org mutation.
- The plan delta for Task 4 is anything other than `0 to add, 1 to change, 0 to destroy`.
- Any repository would receive a direct push to `main`, or any PR would be merged without the review checklist.
- `viavitae-qa` PR #14 turns out to carry a non-pnpm update that would be lost by re-pointing it — Task 3 Step 5 measures this rather than assuming it.

---

## Compliance rationale (required — policy §3.12)

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| `actions_allowed_patterns` | one pnpm pattern, not two or three | Every additional immutable SHA pattern is a latent freeze: a bump to any commit outside the list cannot start, produces zero jobs, zero check-runs and no logs, so required contexts never report. Shrinking the list shrinks the failure surface | SOC 2 CC7.1, CC8.1; ISO A.8.32 |
| Convergence direction | onto the newest already-admitted commit | Avoids any live-org mutation to unblock a PR, and moves the estate forward rather than admitting an older release | ISO A.8.19; PCI-DSS 4.0 Req. 6.3 (jolarca precedent, not Via-Vitae scope) |
| Ordering | refs first, allow-list second, removal gated on a measured zero | Reversing the order converts a one-repo freeze into an org-wide one | SOC 2 CC8.1 change management; ISO A.8.32 |
| Detectability | add a guard for `startup_failure` on open PRs | This failure is invisible in every aggregate check list — a frozen PR reads as "no checks", not as "failed" | SOC 2 CC7.2; ISO A.8.15 |

---

## Halt-and-report triggers (required — policy §3.15)

- If `gh api orgs/Via-Vitae/actions/permissions/selected-actions` no longer lists `ea17c68df8912ef543352723c149a84f56e3d413`, **STOP and report** — the premise of this whole plan is that the target is already admitted.
- If a repo's `pnpm/action-setup` reference carries a version comment that disagrees with the tag mapping in the table above, **STOP and report** rather than trusting the comment. Version comments are annotations, not evidence.
- If any repo has no `pnpm-lock.yaml` yet still references the action, **STOP and report** — the reference may be dead scaffold inheritance and the right fix is removal, not convergence.
- Do not infer a tag from a commit SHA using `git/ref/tags`: that endpoint returns the annotated **tag object**, not the commit. Use `repos/pnpm/action-setup/tags` (peeled) or a runner log.

---

## Tier routing for this plan (policy §6)

| Task | Tier | Rationale |
|---|---|---|
| Spec → this plan | top | ordering hazard, freeze blast radius |
| T1 · manifest entry | cheap | exact content given |
| T2 · measure current references | cheap | deterministic read-only commands |
| T3 · per-repo convergence PRs | cheap | mechanical substitution, one PR per repo |
| T4 · allow-list retirement | human | live org apply |
| T5 · startup-failure guard | top then cheap | design is judgment; code is given |
| Interpret any red CI | top | diagnosis requires reasoning |

**Escalation:** the same step fails twice → stop, escalate to top tier with the exact error output.

---

## Task 1: Declare the canonical pnpm commit

**Files:**
- Modify: `toolchain.yml`

- [x] **Step 1: Append the pin, keeping the flat key format**

Add after the `pin.astral-sh/setup-uv` block:

```yaml
pin.pnpm/action-setup: ea17c68df8912ef543352723c149a84f56e3d413
    # = tag v6.1.0 (verified via repos/pnpm/action-setup/tags, which peels annotated tags to
    # their commit; git/ref/tags does NOT). Already admitted by the org allow-list, so
    # converging onto it needs no live-org mutation. Newest of the three commits in use.
    # Compatible with every packageManager pin in the estate: qa and web declare pnpm@9.15.0,
    # demos pnpm@9.12.0, and action-setup v6 supports pnpm v12 and earlier.
    # NOT fc06bc12 (v5.0.0/v5/v4.4.0) - that is what Dependabot proposed for qa and it is
    # older than v6.1.0 and not allow-listed, which is precisely why qa PR #14 is frozen.
    # NOT b906affc (v4.3.0/v4) - 21 refs use it, but it is two majors behind.
```

- [x] **Step 2: Verify the manifest still parses and the guard reads the new key**

Run from `viavitae-control`:

```bash
.venv/bin/python -c "import yaml; d=yaml.safe_load(open('toolchain.yml')); print('YAML OK, keys:', len(d)); print('pnpm pin =', d['pin.pnpm/action-setup'])"
awk -v k='pin.pnpm/action-setup' 'BEGIN{FS=": *"} $1==k {print "guard sees:", $2; exit}' toolchain.yml
```

Expected: `YAML OK, keys: 10` and `pnpm pin = ea17c68df8912ef543352723c149a84f56e3d413`, then `guard sees: ea17c68df8912ef543352723c149a84f56e3d413`.

- [x] **Step 3: Confirm the guard does not go red on arrival**

Run from `viavitae-control`:

```bash
./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "TOOLCHAIN=$?"
```

Expected: exit `0`. `viavitae-control` references no pnpm action, so adding the pin changes nothing here — this step proves that adding a pin cannot itself break the gate.

- [x] **Step 4: Commit**

```bash
git add toolchain.yml
git commit -m "chore(toolchain): declare the canonical pnpm/action-setup commit

v6.1.0 (ea17c68d) is the newest of the three commits in use and is already
admitted by the org allow-list, so converging onto it needs no live-org change.

Refs: VV-2026-11-016

ai:cheap"
```

---

## Task 2: Measure the exact convergence surface before writing anything

**Files:**
- Verify only.

- [x] **Step 1: Enumerate every pnpm reference across the org, by ref, excluding worktrees**

Run from `/opt/viavitae/repos`:

```bash
for d in viavitae-*/ .github/; do
  [ -d "$d/.github/workflows" ] || continue
  case "${d%/}" in *-wt-*) continue ;; esac
  n=$(grep -rhoE 'uses: pnpm/action-setup@[^ ]+' "$d/.github/workflows"/*.yml 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" != "0" ] && printf '%-38s %s\n' "${d%/}" "$n"
done
```

Expected: one line per consuming repo. Record the total; Task 3 opens exactly that many PRs and no more.

- [x] **Step 2: Record which commit each repo uses today**

```bash
grep -rhoE 'uses: pnpm/action-setup@[^ ]+' viavitae-*/.github/workflows/*.yml 2>/dev/null \
  | grep -v '\-wt-' | sed 's/^uses: //' | sort | uniq -c | sort -rn
```

Expected: two distinct SHAs today, `b906affc` and `ea17c68d`. If a third appears, **STOP and report** — the plan's table is then incomplete.

- [x] **Step 3: Prove each candidate repo actually uses pnpm, so a reference is not dead scaffold inheritance**

```bash
for d in viavitae-*/; do
  r=${d%/}; case "$r" in *-wt-*) continue;; esac
  grep -rq 'pnpm/action-setup' "$d/.github/workflows" 2>/dev/null || continue
  printf '%-38s lock=%s pm=%s\n' "$r" \
    "$([ -f "$d/pnpm-lock.yaml" ] && echo yes || echo NO)" \
    "$(grep -ho '"packageManager": *"[^"]*"' "$d/package.json" 2>/dev/null || echo none)"
done
```

Expected: `lock=yes` for every row. Any `lock=NO` is a halt-and-report case: the right change there is removing the reference, not converging it.

---

## Task 3: One convergence PR per repository, refs first

**Files:**
- Modify: `.github/workflows/*.yml` in each repo listed by Task 2.

- [x] **Step 1: Preview the substitution for one repository, dry-run, no writes**

Run from `/opt/viavitae/repos/viavitae-qa`:

```bash
grep -rn 'pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1' .github/workflows/ | sed 's/^/  would change: /'
```

Expected: the list of lines the PR will touch. Confirm the count matches Task 2 for this repo before proceeding.

- [x] **Step 2: Create the branch from the live default, not a stale local ref**

```bash
git fetch -q origin
git switch -q -c chore/pnpm-pin-convergence "origin/$(git remote show origin | sed -n 's/.*HEAD branch: //p')"
```

Expected: branch created at current remote `main`. A stale local base produces a behind-branch PR, which has burned this estate twice.

- [x] **Step 3: Substitute, then validate before any write leaves the machine**

```bash
sed -i 's|pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1 # v4|pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413 # v6.1.0|g' .github/workflows/*.yml
grep -c 'pnpm/action-setup@b906affc' .github/workflows/*.yml | grep -v ':0' || echo "no stale refs"
python3 -c "import yaml,glob,sys; [yaml.safe_load(open(f)) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
```

Expected: `no stale refs`, then `YAML OK`.

- [x] **Step 4: Push, open the PR, and read its CI conclusion — this is the freeze tripwire**

```bash
git add -A .github/workflows && git commit -m "chore(deps): converge pnpm/action-setup onto the canonical v6.1.0 commit

ea17c68d is tag v6.1.0 and is already admitted by the org allow-list; the v4.3.0
commit it replaces is two majors behind. No allow-list change is needed.

Refs: VV-2026-11-016

ai:cheap" && git push -q -u origin HEAD
gh pr create --base main --head chore/pnpm-action-setup-convergence --title "chore(deps): converge pnpm/action-setup onto v6.1.0" --body "Single-source pin convergence. Target commit is already allow-listed, so no org mutation.

ai:top"
sleep 90
gh pr checks --json name,status,conclusion 2>&1 | head -20
```

Expected: checks `in_progress` or `pass`. **If any run concludes `startup_failure`, STOP immediately** — the target is not admitted and continuing freezes this repo permanently. Do not merge.

- [x] **Step 5: Handle `viavitae-qa` PR #14 without losing its other updates**

```bash
gh pr view 14 --json title,body,files --jq '{title, files: [.files[].path]}'
gh pr diff 14 | grep -E '^[-+].*uses:' | sort -u | head -20
```

Expected: the full list of action bumps the PR carries. PR #14 is titled "4 updates", so re-pointing only the pnpm line preserves the rest; **do not close it** without confirming which of the four would be lost. Closing with `--delete-branch` is destructive and needs the owner's explicit word.

- [ ] **Step 6: Repeat Steps 1–4 for every repo Task 2 listed, one PR each. Then prove zero stale refs remain**

Run from `/opt/viavitae/repos`:

```bash
grep -rl 'pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1' */.github/workflows/*.yml 2>/dev/null | grep -v '\-wt-' | wc -l
```

Expected: `0`. **Any non-zero count is the STOP condition for Task 4** — retiring the pattern now would freeze those repos.

---

## Task 4: Retire the stale allow-list pattern — OWNER AUTHORIZATION REQUIRED

**Files:**
- Modify: `variables.tf` (the `actions_allowed_patterns` default list)

**`STOP — human approval required before this step.`** This section is a `terraform apply` against the live Via-Vitae organization. It must not be executed until the owner issues an explicit, standalone authorization sentence. Listing these steps is not that sentence.

- [ ] **Step 1: Confirm the precondition measured, not remembered**

Run from `/opt/viavitae/repos`:

```bash
n=$(grep -rl 'pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1' */.github/workflows/*.yml 2>/dev/null | grep -v '\-wt-' | wc -l | tr -d ' ')
echo "repos still on b906affc = $n"
[ "$n" = "0" ] && echo "PRECONDITION MET" || echo "PRECONDITION FAILED - do not proceed"
```

Expected: `PRECONDITION MET`.

- [ ] **Step 2: Edit the pattern list**

In `variables.tf`, remove the `pnpm/action-setup@b906affcce14559ad1aafd4ab0e942779e9f58b1` entry from the `actions_allowed_patterns` default, keeping `pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413`, and update the adjacent comment block to state that the estate converges on one commit and that Dependabot bumps to any other commit will `startup_failure` until the manifest, the refs and this list move together.

- [ ] **Step 3: Plan and assert the delta**

Run from `viavitae-control`:

```bash
terraform fmt -check -recursive && terraform init -backend=false && terraform validate
GITHUB_TOKEN="$(gh auth token)" TF_VAR_billing_email=ci-placeholder-not-applied terraform plan -no-color -input=false 2>&1 | grep -E '^Plan:|will be updated|patterns_allowed' | head -8
```

Expected: `Plan: 0 to add, 1 to change, 0 to destroy`, the one change being `github_actions_organization_permissions.this`. **Any destroy or replace is a STOP.**

- [ ] **Step 4: Apply only under the authorization, then verify live**

```bash
gh api orgs/Via-Vitae/actions/permissions/selected-actions --jq '.patterns_allowed[] | select(startswith("pnpm"))'
```

Expected after apply: exactly one line, `pnpm/action-setup@ea17c68df8912ef543352723c149a84f56e3d413`.

- [ ] **Step 5: Prove no repo froze, using the new guard from Task 5**

Expected: the guard reports zero open PRs in `startup_failure`.

---

## Task 5: Make the freeze visible — a detectability guard

**Files:**
- Create: `scripts/check_startup_failures.sh`
- Modify: `policies/README.md` (one row in the Script table)

Rationale: `startup_failure` creates no jobs and no check-runs, so it is indistinguishable from "CI has not run yet" in every aggregate view. Without this guard, the class this plan fixes will silently recur on the next bump.

- [x] **Step 1: Write the guard**

```bash
#!/usr/bin/env bash
# check_startup_failures.sh — name every open PR whose workflow last concluded
# startup_failure. That failure mode creates zero jobs and zero check-runs, so the
# PR looks merely "untested" in aggregates while it is in fact permanently unrunnable.
# Contract: 0 none found, 1 at least one frozen PR (named), 2 nothing readable.
set -uo pipefail
ORG="${1:-Via-Vitae}"
command -v gh >/dev/null 2>&1 || { echo "gh required" >&2; exit 2; }
repos=$(gh api "orgs/$ORG/repos" --paginate --jq '.[] | select(.archived==false) | .name' 2>/dev/null)
[[ -n "$repos" ]] || { echo "no repositories readable for $ORG" >&2; exit 2; }
found=0; scanned=0
while IFS=$'\t' read -r repo number head; do
  [[ -z "${number:-}" ]] && continue
  scanned=$((scanned + 1))
  bad=$(gh run list -R "$ORG/$repo" --limit 6 --json headSha,conclusion \
          --jq ".[] | select(.headSha==\"$head\") | select(.conclusion==\"startup_failure\") | .conclusion" 2>/dev/null | head -1)
  if [[ -n "$bad" ]]; then
    echo "::error::$ORG/$repo PR #$number is frozen: its head run concluded startup_failure (0 jobs, no check-runs)"
    found=$((found + 1))
  fi
done < <(gh pr list -R "$ORG" --state open --limit 200 --json headRefOid,number --repo "$ORG/." 2>/dev/null >/dev/null; \
         for r in $repos; do gh pr list -R "$ORG/$r" --state open --limit 50 --json headRefOid,number \
           --jq '.[] | "'"$r"'\t\(.number)\t\(.headRefOid)"' 2>/dev/null; done)
echo "== open PRs scanned: $scanned · frozen PRs: $found"
[[ $scanned -gt 0 ]] || { echo "nothing was scanned - not reporting clean" >&2; exit 2; }
(( found == 0 )) || exit 1
echo "OK: no open PR is in startup_failure."
```

- [x] **Step 2: Prove it is sensitive, not decorative**

Run from `viavitae-control`:

```bash
bash -n scripts/check_startup_failures.sh && echo "SYNTAX OK"
./scripts/check_startup_failures.sh Via-Vitae; echo "EXIT=$?"
```

Expected at authoring time: `EXIT=1` naming **`Via-Vitae/viavitae-qa` PR #14**, because that PR is frozen right now. A guard that reports clean while a known-frozen PR exists is broken — this is the mutation proof for this guard, and it is available without planting anything.

- [x] **Step 3: Register it and commit**

Add one row to the Script table in `policies/README.md` with all three columns populated, purpose stating the zero-jobs invisibility rationale, write behaviour `read-only (gh GETs) with an operator credential; exit 0 none frozen, 1 a frozen PR named, 2 nothing readable`.

```bash
git add scripts/check_startup_failures.sh policies/README.md
git commit -m "feat(scripts): detect open PRs frozen by startup_failure

startup_failure creates no jobs and no check-runs, so a permanently unrunnable
PR reads as merely untested in every aggregate. Proven sensitive against the
live estate: it names viavitae-qa PR #14 without any planted fixture.

Refs: VV-2026-11-016

ai:cheap"
```

---

## Execution record - 2026-11-03 (Tasks 1, 2, 3 Steps 1-5, 5)

**PRs opened, none merged:** `viavitae-control` #57 (manifest pin, VV-2026-11-020,
`scripts/check_startup_failures.sh` plus its `policies/README.md` row) - `audit` pass,
`provenance` pass. `viavitae-qa` #21 (13 refs in 5 files) and `viavitae-demos` #12
(8 refs in 3 files) - both `CI status` and `Compliance status` pass.

**Task 2 measured, live `origin/main` after an explicit fetch** (the local clones were
behind, which is why the census reads refs at the base commit rather than at HEAD):
demos 8, qa 13 on `b906affcce` and web 9 on `ea17c68df8`, exactly two distinct commits,
`lock=yes` in all three, so no halt trigger fired. Task 3 Step 4's tripwire is the real
proof the plan needed: neither convergence head produced `startup_failure`, so
`ea17c68df8` is confirmed admitted by direct observation rather than by reading the
allow-list and trusting the inference.

**Behaviour delta measured before recommending the direction** (the plan asserted
compatibility from the README; this is the stronger check): `diff` of `action.yml` at the
two commits is three lines - two input description texts and `runs.using` going from
node20 to node24. No input is added, removed or re-defaulted, and `version:` still means
"Version of pnpm to install", so demos' `version: ${{ env.PNPM_VERSION }}` stays valid.
Which pnpm is installed comes from `packageManager`, not from the ref: web's runner log
for run 41449846096 reads `Switching pnpm from v11.25.0 to v9.15.0` then
`Successfully updated pnpm to v9.15.0`. One caveat stated: the `Node.js 20 is deprecated`
warning observed in demos run 41451712042 and qa run 41578799982 names
`actions/checkout` and `actions/upload-artifact`, not the pnpm step, so it evidences the
platform direction, not a warning this repo's pnpm step emits.

**Task 3 Step 5 measured:** qa PR #14 carries four bumps - `pnpm/action-setup` plus
`github/codeql-action` init, autobuild and analyze. Closing it would lose the three
codeql bumps, so nothing was closed. demos PR #6 proposes the same `fc06bc12` pnpm bump.

**The guard's first version was wrong and the fix is the point of the exercise.** Written
as the plan specifies (`gh run list --limit 6` per repo), it scanned 50 open PRs, named
nothing and printed a clean verdict while two PRs were frozen - a PR frozen on 2026-10-19
has not been inside an active repo's last six runs for weeks. Rewritten to query the runs
of each head (`actions/runs?head_sha=`), it now exits 1 naming qa #14 (4 `startup_failure`
runs on head `3a896253`) and demos #6 (2 on head `42f05f67`), with failed reads and
heads-without-runs counted and printed separately instead of folded into the clean total.

**Deviations from the plan, stated rather than buried:**

1. Executed at top tier, so commit trailers read `ai:top`; the plan routed Tasks 1-3 to
   the cheap tier. A trailer naming a tier that did not produce the change would corrupt
   the record the provenance gate exists to keep.
2. Task 3 Step 4 as written branches `chore/pnpm-pin-convergence` but opens the PR with
   `--head chore/pnpm-action-setup-convergence`, which does not exist. Used one name.
3. Task 3 Step 3 validates with bare `python3`; Ubuntu 24.04 keeps `yaml` out of the
   system interpreter, so the control plane's `.venv/bin/python` parsed every workflow.
4. `policies/README.md` did not survive the first guard commit: `git add` listed only the
   script and the row was absent from the tree afterwards (no stash entry). Re-added and
   grep-verified in both the worktree and `HEAD` before pushing, which is why that check
   is now part of the step.
5. Task 1 Step 2's expected `YAML OK, keys: 10` held, and the manifest comment carries
   more evidence than the plan text because the allow-list constraint, the measured
   v4-to-v6 delta and the census bases are what make the choice auditable.

**Not executed, and why:** Task 3 Step 6 cannot print `0` while the two PRs are unmerged
(13 refs on qa `origin/main` `2d670ec`, 8 on demos `origin/main` `1ec6e2f`, 0 on web), so
Task 4's `PRECONDITION MET` line is not available and Task 4 additionally needs the
owner's standalone apply authorization. Nothing in this round touched the allow-list,
`variables.tf` or Terraform state.

---

## Out of scope

| Item | Why |
|---|---|
| Migrating to `pnpm/setup` | A redesign, not a pin fix. It would also remove the need for `actions/setup-node` in pnpm repos, so it needs its own assessment of the darwin-x64 caveat in the README |
| Turning `sha_pinning_required` on org-wide | Would fail the nine floating patterns and roughly 150 floating refs in the charity plane. Separate project with its own blast-radius assessment |
| The charity and jolarca planes | Different orgs, different allow-lists, boundary 1 forbids shared CI configuration. Each needs its own manifest and its own convergence |
| Closing qa PR #14 with `--delete-branch` | Destructive and it carries three other action bumps. Needs the owner's explicit word |

---

## Review checklist (required — policy §5)

Metrics recomputed for this document (re-counted after the 2026-11-03 execution
round: Tasks 1, 2, 5 and Task 3 Steps 1–5 were executed; Task 3 Step 6, all of
Task 4 and the post-merge items wait on the merges and on an apply authorization):
selfcite:stop_clauses=6 selfcite:halt_clauses=4 selfcite:rationale_rows=4
selfcite:file_rows=4 selfcite:tier_rows=7 selfcite:tasks_open=12 selfcite:tasks_done=24

### Pre-commit checklist

- [x] **Plan exists and is committed** — path: `docs/superpowers/plans/2026-11-03-viavitae-control-pnpm-pin-convergence.md`
- [x] **Plan includes STOP conditions** — 6 clauses, section present above
- [x] **Plan includes compliance rationale** — 4 rows
- [x] **Plan includes explicit halt-and-report triggers** — 4 clauses
- [x] **Deterministic gates passed** — paste `fmt · validate · YAML OK · TOOLCHAIN` outputs
- [ ] **Diff matches plan** — expected `0 to add, 1 to change, 0 to destroy` for Task 4 only
- [x] **No silent fallback** — no allow-list pattern added; convergence uses the already-admitted commit
- [ ] **Tier prefix in commit message** — `ai:cheap` per repo PR, `ai:top` in each PR body
- [x] **Small diff** — one action line per workflow
- [x] **No state mutation** — `terraform apply` **not** run; Task 4 gated on explicit authorization
- [x] **Freeze tripwire observed** — Task 3 Step 4 CI conclusion recorded per repo before merge
- [ ] **Ordering precondition measured** — Task 4 Step 1 prints `PRECONDITION MET`

### Post-merge checklist

- [ ] **Zero stale refs org-wide** — paste the Task 3 Step 6 count, expected `0`
- [ ] **Startup-failure guard clean** — paste `check_startup_failures.sh` output after Task 4
- [ ] **Audit trail complete** — `git log --grep '^ai:' --oneline` per repo

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

## Evidence base

- `gh api orgs/Via-Vitae/actions/permissions/selected-actions` — `patterns_allowed` contains exactly two `pnpm/action-setup@<sha>` entries, `github_owned_allowed: true`, `verified_allowed: true`
- `gh api --paginate repos/pnpm/action-setup/tags` — `b906affc…` = `v4.3.0` and `v4`; `ea17c68d…` = `v6.1.0`; `fc06bc12…` = `v5.0.0`, `v5` and `v4.4.0`; latest release `v6.1.1` published 2026-11-03
- `gh api repos/pnpm/action-setup/readme` — the action "supports pnpm v12 and earlier"; `pnpm/setup` is offered as an additional option that installs a self-contained binary and optionally a JS runtime; `pnpm/setup` cannot install pnpm v11 on darwin-x64
- `gh api repos/pnpm/setup` — exists, 161 stars, not archived, pushed 2026-11-03
- `packageManager` pins: `viavitae-qa` and `viavitae-web` `pnpm@9.15.0`, `viavitae-demos` `pnpm@9.12.0`
- Reference counts across Via-Vitae main checkouts: `b906affc` 21, `ea17c68d` 9
- `viavitae-qa` PR #14 — OPEN, head `3a896253`, `mergeStateStatus` BLOCKED, `gh pr checks` reports "no checks reported on the branch"; run 39194144090 `jobs.total_count = 0`, annotation names `pnpm/action-setup@fc06bc12…` as not allowed
- `compliance-check.yml` action inventory: `actions/checkout`, `actions/setup-node`, `actions/setup-python`, `actions/upload-artifact` — all GitHub-owned, so adopting it carries no allow-list risk; its `governance` job requires 13 files that `viavitae-control` largely does not have, which is why Tier 2 was not executed blind
- All measurements taken 2026-11-03
