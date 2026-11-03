# Governance Artifacts for the Control Plane — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give `viavitae-control` the governance artifacts a Terraform control plane genuinely needs, and record which of the ten "missing" files are real gaps versus a product-repo template misapplied to infrastructure.

**Architecture:** Comparative measurement against the two sibling control planes decides each file, rather than assuming the product-repo `governance` job defines correctness for every repository. Eight files are adopted, one is adapted, one is rejected with a reason. The `compliance-check.yml` workflow itself is **not** adopted: the guard landed in PR #53 already enforces the only job of it that applies here.

**Tech Stack:** Markdown, YAML, `.editorconfig`, GitHub CODEOWNERS and Dependabot, `scripts/check_toolchain_pins.sh` and `policies/README.md` from PR #53.

**Authority boundary:** Plan-only. No `terraform apply`, no push to `main`, no merge, no org mutation.

**Related spec:** [2026-11-03-mise-toolchain-adoption-decision-package.md](../specs/2026-11-03-mise-toolchain-adoption-decision-package.md) §6.1 Tier 2, VV-2026-11-019
**Related findings:** VV-2026-11-019 (this plan is its remediation), VV-2026-11-016

---

## The reframe, and why it matters

Tier 2 of the toolchain plan said: "land `compliance-check.yml` in `viavitae-control` so rule R4 covers 31 of 31 repos." Measured, that premise fails twice.

**First**, the workflow's `governance` job requires 13 named files and this repo has **3**. Adopting it as written produces a red `governance` job and a red `compliance-status` aggregate on every PR — a gate red on arrival, which is the fourth time this estate has met that pattern.

**Second**, and more important: **some of those ten files are not this repo's gap.** Compared against the two sibling control planes:

| Required by the governance job | viavitae-control | jol-control | jolarca-control | Verdict |
| --- | --- | --- | --- | --- |
| `README.md` | yes | yes | yes | present |
| `LICENSE` | yes | yes | yes | present |
| `.gitignore` | yes | yes | yes | present |
| `SECURITY.md` | **no** | no | yes | **ADOPT** — this repo holds provider credentials and state |
| `CONTRIBUTING.md` | **no** | yes | yes | **ADOPT** — both peers have it; it is the review-convention carrier |
| `CHANGELOG.md` | **no** | yes | yes | **ADOPT** — both peers have it |
| `.editorconfig` | **no** | yes | yes | **ADOPT** — cheapest file in the list |
| `docs/architecture.md` | **no** | yes | yes | **ADOPT** — the decision package already cites the sibling's copy |
| `.github/CODEOWNERS` | **no** | yes | yes | **ADOPT** — see the single-member caveat in Task 3 |
| `.github/dependabot.yml` | **no** | yes | yes | **ADOPT** — terraform plus actions ecosystems |
| `.github/PULL_REQUEST_TEMPLATE.md` | **no** | yes | yes | **ADOPT** — a PR body is a policy artifact here; the `provenance` gate reads it |
| `QODER.md` | **no** | yes | no | **ADAPT** — agent instructions with owner, precedence and a review date |
| `docs/DPIA-template.md` | **no** | **no** | **no** | **REJECT** — absent from all three control planes |

`docs/DPIA-template.md` is the tell. It is a **product-repo** artifact: DPIAs concern personal data in an application, and a Terraform control plane holds none. That no control plane in the portfolio has it, while the product-repo template demands it, means the requirement is a **template defect**, not ten downstream gaps. Creating a stub to satisfy the gate would be exactly the gate-gaming this estate has already rejected once (the `print_hi` test proposal, refused as gate-gaming in the landing-repos decision package).

**So: do the nine real ones because they are genuinely missing. Do not create the tenth. And do not adopt the workflow that demands it.**

---

## Plan metadata

| Field | Value |
|---|---|
| Plan author tier | top |
| Execution tier(s) | cheap for content scaffolds, top for SECURITY.md and CODEOWNERS wording |
| Review tier | human |
| Expected plan delta | `0 to add, 0 to change, 0 to destroy` — no `.tf` file is touched |
| Blast radius | single repo, new files only, no existing file modified except `policies/README.md` |
| Gate risk | none — no workflow is added, so no new required or advisory context appears |

---

## File structure

| Action | File | Responsibility |
|---|---|---|
| Create | `SECURITY.md` | Vulnerability reporting route, the credential classes this repo holds, and the disclosure window |
| Create | `CONTRIBUTING.md` | The plan-as-contract workflow, tier routing, and the review checklist this repo already enforces |
| Create | `CHANGELOG.md` | Keep-a-changelog record seeded from the landed PRs of this assessment |
| Create | `.editorconfig` | Cross-editor baseline matching the pre-commit hooks already in force |
| Create | `docs/architecture.md` | The three-plane control-plane map, the isolation boundary, and where state and credentials live |
| Create | `.github/CODEOWNERS` | Default owner for the repo, scoped to a real team handle |
| Create | `.github/dependabot.yml` | terraform and github-actions ecosystems only, weekly, grouped |
| Create | `.github/PULL_REQUEST_TEMPLATE.md` | Carries the mandatory `ai:<tier>` trailer line and the sign-off block |
| Create | `QODER.md` | Agent instruction file: owner, precedence order, expiry date |
| Modify | `policies/README.md` | One row noting the governance-artifact convention |

`docs/DPIA-template.md` is deliberately **not** created.

---

## STOP conditions (required — policy §3.8)

The executing agent **halts immediately and reports** if any of the following occur:

- `terraform plan` delta is anything other than `No changes` — this plan touches no `.tf` file.
- Any existing file would be modified other than `policies/README.md`.
- A `CODEOWNERS` rule would name a team that does not exist in the org, or a handle that is not a real identity.
- `docs/DPIA-template.md` is about to be created as a stub to satisfy a gate.
- Any workflow file would be added or modified.
- A command returns a non-zero exit code not anticipated below.

---

## Compliance rationale (policy §3.12)

| Field | Value | Rationale | Framework ref |
|---|---|---|---|
| `SECURITY.md` | created, not stubbed | This repository's provider block reads org settings and repository security across 31 repos; a reporter with no contact route has nowhere to go. GDPR Art. 33's 72-hour clock cannot start without one | GDPR Art. 32, Art. 33; ISO A.5.24, A.6.14 |
| `.github/CODEOWNERS` | default rule to a real team | Protects Terraform state and org settings from unreviewed change. **Caveat stated in Task 3:** in a single-member org this is a claim, not a control, until a second reviewer exists | SOC 2 CC8.1; ISO A.8.32 |
| `.github/dependabot.yml` | two ecosystems only | The estate already has a recorded class of dead Dependabot entries that resolve nothing and train the operator to ignore the column | ISO A.8.19; SOC 2 CC7.1 |
| `QODER.md` | adapted from the sibling control plane | Agent instructions need a named owner, a precedence order and a review date, or they silently rot into a second unenforced policy | ISO A.5.31, A.8.32 |
| `docs/DPIA-template.md` | **not created** | A DPIA is about personal data in a processing system. A control plane processes none. Producing a stub would create a compliance artifact that asserts nothing | GDPR Art. 35 by exclusion; ISO A.18.1.1 (avoid records with no content) |

---

## Halt-and-report triggers (required — policy §3.15)

- If the exact team handle for `CODEOWNERS` cannot be confirmed from the live org, **STOP and report**. Do not invent `@Via-Vitae/architects` from the governance job's error text; verify the team exists first.
- If `jolarca-control/SECURITY.md` or `jol-control/CONTRIBUTING.md` contains entity-specific text (a different legal entity, a different DPO address, a different disclosure mailbox), **STOP and report** rather than copying it across a controller boundary. Three legal entities must not share policy text that names an owner.
- If the sibling `dependabot.yml` lists an ecosystem this repo cannot resolve, do not copy it — Task 4 states the measured content.
- Do not paraphrase the sibling `docs/architecture.md`. It describes the **charity** plane, whose residency rule ("built and operated in-house on hardware it owns") does not apply to Via-Vitae. Write a new one.

---

## Tier routing for this plan (policy §6)

| Task | Tier | Rationale |
|---|---|---|
| Spec → this plan | top | comparative measurement, template-defect call |
| T1 · `.editorconfig` | cheap | exact content given |
| T2 · `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md` | top for wording | legal-entity-specific content, disclosure routes |
| T3 · `CODEOWNERS`, PR template | top | a wrong owner rule silently removes review |
| T4 · `dependabot.yml` | cheap | exact content given, ecosystems measured |
| T5 · `docs/architecture.md`, `QODER.md` | top | architecture and precedence are judgment |
| T6 · register and verify | cheap | deterministic gates |

**Escalation:** the same step fails twice → stop, escalate with the exact error output.

---

## Task 1: `.editorconfig`

**Files:**
- Create: `.editorconfig`

- [ ] **Step 1: Confirm what the existing hooks already demand, so the file agrees with them**

Run from `viavitae-control`:

```bash
grep -nE 'end_of_file|trailing_whitespace|check_yaml' .pre-commit-config.yaml
```

Expected: hooks for `end-of-file-fixer`, `trailing-whitespace` and `check-yaml` are present, so the editor config must set the same rules rather than invent new ones.

- [ ] **Step 2: Write the file**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.tf]
indent_size = 2

[*.{yml,yaml}]
indent_size = 2

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

Markdown keeps trailing whitespace because two trailing spaces are a hard line break, and this repo's compliance prose relies on it.

- [ ] **Step 3: Verify it does not contradict the hooks**

```bash
.venv/bin/pre-commit run --files .editorconfig 2>&1 | tail -6
```

Expected: all hooks `Passed` or `Skipped`, none `Failed`.

---

## Task 2: `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`

**Files:**
- Create: `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`

- [ ] **Step 1: Read the sibling files for structure only, and note every entity-specific string**

```bash
grep -nE 'journeyoflife|jolarca|@jol|Lithuania|dpo@|Vilnius' /opt/jol/repos/jol-control/SECURITY.md /opt/jolarca/repos/jolarca-control/SECURITY.md 2>/dev/null | head -20
```

Expected: any hit is a halt-and-report trigger — that text belongs to a different controller and must not be copied.

- [ ] **Step 2: Write `SECURITY.md`**

Required sections, each with real content, no placeholders:

```markdown
# Security policy

## What this repository is
Terraform control plane for the Via-Vitae GitHub organization. It declares 31 repositories,
organization settings, rulesets and the Actions allow-list. It holds no personal data and runs
no workload.

## Credential classes reachable from this repository
- GitHub provider token used by CI to plan across the org (read-only; enforced by
  `scripts/check_ci_credential.sh`)
- Terraform state, which contains repository settings but no secret values
- The Actions allow-list, which is a supply-chain control for the whole org

## Reporting a vulnerability
Email `security@via-vitae.example` — replace with the live address before merge. Do not open a
public issue. Expected first response: 72 hours, aligned to the GDPR Art. 33 notification clock,
which starts when a report establishes a personal-data breach rather than when this file was written.

## Hardening already in force
`policies/README.md` lists every guard. `toolchain.yml` plus `scripts/check_toolchain_pins.sh`
pin the CI toolchain and canonical action commits.
```

- [ ] **Step 3: Write `CONTRIBUTING.md`**

It must state the workflow the repo already enforces, not a new one: plan-as-contract, plan-only authority, the `ai:<tier>` trailer requirement, the review checklist, and that `terraform apply` needs an explicit owner sentence. Point at `policies/AI_WORKFLOW_POLICY.md` rather than restating its 15 levers.

- [ ] **Step 4: Write `CHANGELOG.md`**

Seed it from the landed commits of this assessment, measured rather than remembered:

```bash
git log --oneline --grep='(#5[0-9])' origin/main | cat
```

Expected: the squash-merged PR subjects, which become the initial entries under a `## Unreleased` heading with the date `2026-11-03`.

- [ ] **Step 5: Verify no placeholder survived**

```bash
grep -nE 'TODO|TBD|\[replace|FIXME|example\.com|via-vitae\.example' SECURITY.md CONTRIBUTING.md CHANGELOG.md
```

Expected: **no output.** A surviving placeholder is a STOP — a published security contact that is not real is worse than none.

---

## Task 3: `CODEOWNERS` and the pull-request template

**Files:**
- Create: `.github/CODEOWNERS`, `.github/PULL_REQUEST_TEMPLATE.md`

- [ ] **Step 1: Confirm the team actually exists before naming it**

Run from anywhere:

```bash
gh api orgs/Via-Vitae/teams --paginate --jq '.[] | "\(.slug)\t\(.privacy_type)\t\(.member_count)"'
```

Expected: a real team slug to use. **If no team fits, STOP and report** — do not invent a handle. Record here that a single-member org means `CODEOWNERS` cannot deliver separation of duties; it is a routing rule, not a review control.

- [ ] **Step 2: Write `.github/CODEOWNERS`**

```
# Default owner for everything in the control plane.
*                                @Via-Vitae/<team-slug-from-step-1>

# Highest-sensitivity paths, named explicitly so a future reviewer split is one line.
/org_settings.tf                 @Via-Vitae/<team-slug-from-step-1>
/repo_rulesets.tf                @Via-Vitae/<team-slug-from-step-1>
/variables.tf                    @Via-Vitae/<team-slug-from-step-1>
/toolchain.yml                   @Via-Vitae/<team-slug-from-step-1>
/.github/workflows/              @Via-Vitae/<team-slug-from-step-1>
```

- [ ] **Step 3: Write `.github/PULL_REQUEST_TEMPLATE.md` carrying the trailer**

Because `provenance.yml` reads the PR body and the trailer is not optional, the template must make it explicit rather than leave authors to discover it:

```markdown
## Change
What and why, in two sentences.

## Plan
Plan path: `docs/superpowers/plans/<file>.md`
Plan followed: yes / no (if no, stop and get the plan updated first)

## Verification
Paste command output, not claims. A gate that has never been observed failing is not a control.

## Terraform
Plan delta: `0 to add, 0 to change, 0 to destroy`
Apply performed: no

ai:top
```

- [ ] **Step 4: Verify the template's trailer line is a valid value**

```bash
grep -cE '^ai:(top|mid|cheap|free|review)$' .github/PULL_REQUEST_TEMPLATE.md
```

Expected: `1`.

---

## Task 4: `.github/dependabot.yml` — two ecosystems, both resolvable

**Files:**
- Create: `.github/dependabot.yml`

- [ ] **Step 1: Prove each ecosystem has something to resolve before declaring it**

Run from `viavitae-control`:

```bash
echo "tf files: $(find . -maxdepth 2 -name '*.tf' -not -path './.terraform/*' | wc -l | tr -d ' ')"
echo "lock files: $(find . -maxdepth 2 -name '.terraform.lock.hcl' | wc -l | tr -d ' ')"
echo "workflow files: $(find .github/workflows -name '*.yml' | wc -l | tr -d ' ')"
```

Expected: all three non-zero. An ecosystem declared with nothing to resolve is the recorded dead-Dependabot defect, and each dead entry is attempted on schedule, which trains everyone to ignore the column.

- [ ] **Step 2: Write it**

```yaml
version: 2

updates:
  - package-ecosystem: "terraform"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    groups:
      terraform-providers:
        patterns:
          - "*"
    open-pull-requests-limit: 5

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    groups:
      actions:
        patterns:
          - "*"
    open-pull-requests-limit: 5
```

No `pip` ecosystem: this repo's Python lives in a git-ignored `.venv` with no `requirements.txt` or `pyproject.toml`, so a `pip` entry would be exactly the dead kind.

- [ ] **Step 3: Validate the YAML and the recorded hazard**

```bash
python3 -c "import yaml; d=yaml.safe_load(open('.github/dependabot.yml')); print([u['package-ecosystem'] for u in d['updates']])"
```

Expected: `['terraform', 'github-actions']`.

Note the interaction this plan cannot fix: a grouped Actions bump that moves `pnpm/action-setup` to a commit outside the org allow-list will `startup_failure` with zero jobs. See VV-2026-11-016 and the convergence plan.

---

## Task 5: `docs/architecture.md` and `QODER.md`

**Files:**
- Create: `docs/architecture.md`, `QODER.md`

- [ ] **Step 1: Write `docs/architecture.md` covering only what is measured**

Required sections: the three control planes and which legal entity each governs; the state backend per plane; the isolation boundary and what it does and does not currently cover; the CI credential model with the two-token contract; the guard inventory; and the Actions allow-list as a supply-chain control. Every claim carries the command that proves it. Explicitly state the known gap that `viavitae-control`'s own ruleset is asserted by no script.

- [ ] **Step 2: Write `QODER.md` with the three fields the sibling's own gate checks**

```markdown
# Agent instructions — viavitae-control

## Owner
Via-Vitae architects (repo maintainers). Human sign-off is required before any merge.

## Precedence
1. Direct owner instruction
2. `policies/AI_WORKFLOW_POLICY.md`
3. This file
4. Tool defaults

## Review
Reviewed 2026-11-03. Next review 2027-05-01.

## Boundaries
Plan-only: no `terraform apply`, no push to `main`, no org mutation, no compliance-adequacy
judgement. Halt and report rather than substitute a value.
```

- [ ] **Step 3: Verify the precedence order does not contradict the policy**

```bash
grep -n 'Precedence' -A6 QODER.md
grep -c 'plan-only\|Plan-only' policies/AI_WORKFLOW_POLICY.md
```

Expected: this file ranks **below** the AI workflow policy, and the policy still states plan-only authority.

---

## Task 6: Register the convention and run every gate

**Files:**
- Modify: `policies/README.md`

- [ ] **Step 1: Add one row to the policy table** stating that governance artifacts for the control plane are decided per file against the sibling planes, and that `docs/DPIA-template.md` is excluded by design with the reason recorded in VV-2026-11-019.

- [ ] **Step 2: Confirm all thirteen required files are now present or deliberately excluded**

Run from `viavitae-control`:

```bash
for f in README.md LICENSE SECURITY.md CONTRIBUTING.md CHANGELOG.md QODER.md .gitignore \
         .editorconfig .github/CODEOWNERS .github/dependabot.yml \
         .github/PULL_REQUEST_TEMPLATE.md docs/architecture.md; do
  [ -e "$f" ] && echo "  present  $f" || echo "  MISSING  $f"; done
echo "  excluded by design: docs/DPIA-template.md"
```

Expected: 12 present, 0 missing, plus the stated exclusion.

- [ ] **Step 3: Every gate**

```bash
terraform fmt -check -recursive && echo "FMT=0"
terraform init -backend=false >/dev/null && terraform validate
./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows; echo "TOOLCHAIN=$?"
./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md; echo "SELFCITE=$?"
.venv/bin/python scripts/check_audit_register.py docs/security/*.md docs/superpowers/specs/*.md; echo "REGISTER=$?"
.venv/bin/pre-commit run --all-files 2>&1 | tail -14
```

Expected: `FMT=0`, `Success! The configuration is valid.`, `TOOLCHAIN=0`, `SELFCITE=0`, `REGISTER=0`, all hooks `Passed`.

- [ ] **Step 4: Prove the Terraform delta is still nothing**

```bash
GITHUB_TOKEN="$(gh auth token)" TF_VAR_billing_email=ci-placeholder-not-applied \
  terraform plan -no-color -input=false 2>&1 | grep -E '^Plan:|No changes'
```

Expected: unchanged from the pre-plan baseline. **This plan adds no `.tf` file, so any new add, change, destroy or replace is a STOP.**

- [ ] **Step 5: Do not push, merge, or apply**

**`STOP — human approval required before this step`** for push, PR creation and merge.

---

## Out of scope

| Item | Why |
|---|---|
| Adopting `compliance-check.yml` into this repo | Its `governance` job encodes product-repo requirements, one of which is a template defect. The one job that applies here, `action-pinning`, is already enforced by `check_toolchain_pins.sh` |
| Creating `docs/DPIA-template.md` | Rejected with a reason. A stub would be a compliance artifact asserting nothing |
| Making `audit` a required status check | A ruleset change, Terraform-declared, `apply`-gated, needs a compliance rationale |
| Real separation of duties | `CODEOWNERS` cannot provide it in a single-member org. The fix is a second reviewer, tracked under the restore-peer-review runbook |
| The sibling control planes | Three legal entities, three separately-owned artifact sets. Copying text across a controller boundary is prohibited |

---

## Review checklist (required — policy §5)

Metrics recomputed for this document:
selfcite:stop_clauses=6 selfcite:halt_clauses=4 selfcite:rationale_rows=5
selfcite:file_rows=10 selfcite:tier_rows=7 selfcite:tasks_open=37 selfcite:tasks_done=0

### Pre-commit checklist

- [ ] **Plan exists and is committed** — path: `docs/superpowers/plans/2026-11-03-viavitae-control-governance-artifacts.md`
- [ ] **Plan includes STOP conditions** — 6 clauses
- [ ] **Plan includes compliance rationale** — 5 rows, including the rejection
- [ ] **Plan includes explicit halt-and-report triggers** — 4 clauses, incl. the controller-boundary rule
- [ ] **Deterministic gates passed** — paste Task 6 Step 3 output
- [ ] **Diff matches plan** — expected `No changes` from Terraform
- [ ] **No silent fallback** — no invented team handle, no copied sibling text
- [ ] **Tier prefix in commit message** — `ai:cheap` or `ai:top` per task
- [ ] **Small diff** — new files only, one row added to `policies/README.md`
- [ ] **No state mutation** — `terraform apply` not run
- [ ] **Placeholder scan clean** — Task 2 Step 5 grep returns nothing
- [ ] **Team handle verified live** — Task 3 Step 1 output pasted

### Post-merge checklist

- [ ] **Terraform plan still clean** — paste Task 6 Step 4
- [ ] **Audit trail complete** — `git log --grep '^ai:' --oneline`

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

- Governance job required-file list read from `viavitae-api/.github/workflows/compliance-check.yml` lines 282–286: `README.md`, `LICENSE`, `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `QODER.md`, `.gitignore`, `.editorconfig`, `.github/CODEOWNERS`, `.github/dependabot.yml`, `.github/PULL_REQUEST_TEMPLATE.md`, `docs/architecture.md`, `docs/DPIA-template.md`
- Measured against `viavitae-control` on 2026-11-03: **3 present, 10 missing**
- Cross-plane presence for `SECURITY.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `QODER.md`, `.editorconfig`, `docs/architecture.md`, `docs/DPIA-template.md` recorded in the table above, from direct `[ -e ]` tests on `/opt/jol/repos/jol-control` and `/opt/jolarca/repos/jolarca-control`
- `compliance-check.yml` action inventory: `actions/checkout`, `actions/setup-node`, `actions/setup-python`, `actions/upload-artifact` — all GitHub-owned, so the workflow carries no allow-list admission risk. The blocker is content, not supply chain
- `.github/` in this repo contains only `workflows/`; root holds `README.md`, `LICENSE`, `.gitignore`, `.pre-commit-config.yaml` and the Terraform files
- Landed PRs available for the changelog seed: `#53` toolchain manifest and guard, `#54` positional self-citation fix, `#55` pnpm convergence plan
