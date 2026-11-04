# QODER.md — Agent Operating Rules for `viavitae-control`

Rules for AI coding agents (Qoder and equivalents) working in this repository.
Derived from the four Karpathy principles — *Think Before Coding*, *Simplicity
First*, *Surgical Changes*, *Goal-Driven Execution* — and bound to the controls
this repo actually enforces.

**Precedence.** [`policies/AI_WORKFLOW_POLICY.md`](policies/AI_WORKFLOW_POLICY.md)
is the authoritative compliance control (15 levers + mandatory review checklist).
This file is the agent-facing adapter: it says what to do at the keyboard and
points at the policy for the rationale. On any conflict, the policy wins. Owner
instructions in the current session win over both.

**Review.** Document owners: `@Via-Vitae/security` and `@Via-Vitae/compliance` - the two teams
`locals.tf` binds to the `control` tier, and the handles `.github/CODEOWNERS` assigns through its
`*` catch-all (this file has no CODEOWNERS line of its own). Reviewed 2026-11-04. Next review
2027-05-01. Re-review early if any of these changes: the tier set in
`policies/AI_WORKFLOW_POLICY.md`, the standalone `ai:<tier>` trailer rule, the guard exit-code
contract `0`/`1`/`2`, the canonical-SHA rule in `toolchain.yml`, or the authority boundary in
section 1.

Nothing enforces that date. `check_plan_selfcite.sh` scans `docs/superpowers/plans/*.md` and
`check_audit_register.py` scans `docs/security/` plus `docs/superpowers/specs/*.md`, so a
root-level markdown file falls outside every CI glob and can drift from the policy it adapts
without any gate noticing. The date is written here precisely because no machine will write it.

**Tradeoff.** These rules bias toward caution over speed. For a one-line typo
fix, use judgment — not every change needs the full gate run. Nothing here
relaxes §1.

---

## 1. Authority boundary (non-negotiable)

This is a live control plane for the `Via-Vitae` GitHub organization. Terraform
state is **local**, there is **no locking**, and one bad write has org-wide blast
radius. Default authority is **plan-only**.

Prohibited without an explicit, unconditional owner authorization in the current
session:

- `terraform apply`, `terraform import`, `terraform state *`, `terraform destroy`
- `git push` to `main`, force-push, branch deletion, `gh pr merge`
- any live org mutation (`gh api -X PATCH/POST/PUT/DELETE`, `policies/*.sh --apply`,
  `scripts/rollout_*.sh` with `APPLY=1`, ruleset or branch-protection edits)
- editing `terraform.tfstate`, `terraform.tfstate.backup`, or `terraform.tfvars`
- widening a CI credential, adding a GitHub Actions allow-list pattern, or raising
  a token's scopes to "make a step pass"
- committing anything under `.scratch_*`, `.private/`, `audit-evidence/`

**Authorization is literal.** Restated steps are not authorization. A quoted
trigger word is not authorization. Conditional wording ("delete the branch if you
judge it superseded") authorizes only the unconditional part. When in doubt, stop
and ask — do not infer consent.

**Compliance judgment is not yours.** Whether a control is *adequate* — a
`visibility` change, a `manage_files` flip, `enforce_admins`, a ruleset
modification, a review-count change — is a human or top-tier decision. You may
implement a control a spec states exactly. You may not decide one.

---

## 2. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State assumptions explicitly before editing. If a value cannot be determined
  from a file, command output, or the live API, **halt and report** — never guess
  and never silently substitute (policy §3.15).
- If a request admits two readings, present both. Do not pick silently.
- If a simpler approach exists, say so before implementing the complex one.
- Read the target file before changing it. In this repo, most "obvious" edits are
  already wrong: the guard scripts have deliberate exit-code semantics, the
  workflows have deliberate step ordering, and `toolchain.yml` values carry
  evidence comments that forbid naive convergence.
- Ask one question at a time when clarification is needed; do not batch five.

---

## 3. Simplicity First

Minimum change that satisfies the request. Nothing speculative.

- No features beyond what was asked; no abstractions for single-use code; no
  "flexibility" or "configurability" nobody requested; no error handling for
  impossible states.
- Prefer a documented script + a gate over a new Terraform resource when the
  provider has no first-class resource — that is this repo's established pattern
  (see [`policies/README.md`](policies/README.md), "Why scripts and not
  resources?"). Never fabricate a resource to look declarative.
- Do not add a new binary dependency to make a check work. `yq` is absent on this
  host; `toolchain.yml` is flat `key: value` **for that reason** and nesting it
  breaks the guard's parser (exit 2, not a silent pass).
- If 200 lines could be 50, rewrite it. Test: would a senior engineer call this
  overcomplicated?

---

## 4. Surgical Changes

Touch only what you must. Clean up only your own mess.

- Don't "improve" adjacent code, comments, or formatting. Don't refactor what
  isn't broken. Match existing style even where you'd do it differently.
- **Comments in this repo are evidence.** Many carry dated measurements, finding
  IDs, and rejected alternatives. Never delete or rewrite a comment you don't
  fully understand; never strip a `# verified YYYY-MM-DD` or `VV-YYYY-MM-NNN`
  citation as a side effect.
- If you notice unrelated dead code or a stale claim, **mention it — don't fix
  it**. Unrequested register edits have invented finding IDs before.
- Remove imports/variables/locals that *your* change orphaned. Leave pre-existing
  dead code alone.
- Stage named paths only. Never `git add -A`: the working tree regularly holds
  untracked `.scratch_*` files and unrelated in-flight work.
- Test: every changed line traces directly to the request.

---

## 5. Goal-Driven Execution

Define success criteria, then loop until verified **by command output**.

| Instead of | Do this |
|---|---|
| "Update the register" | Edit it, then run `scripts/check_audit_register.py` and paste exit code + output |
| "Pin the action" | Edit it, then run `scripts/check_toolchain_pins.sh` and show the invariant passing |
| "Fix CI" | Reproduce the failing step locally, show the failure, then show it gone |
| "The docs are consistent" | Run the self-citation gate and show `selfcite` assertions matching |

- "I've updated the file successfully" is a claim, not evidence. Paste the command
  and its output (policy §3.6).
- For multi-step work, state the plan as `step → verify:` pairs before starting,
  and include STOP conditions (§8).
- Two failed attempts on the same step → stop and escalate with the exact error
  output. Do not loop; looping is where unrequested edits appear (policy §3.7).
- **Empty output is not absence and not success.** A blank stdout from `git`,
  `grep`, or `gh` in this environment has repeatedly masqueraded as "no matches".
  Redirect to a file and read it back, or re-run with an explicit marker
  (`; echo "exit=$?"`).

---

## 6. House conventions

**Artifact locations (create, then register).**

| Artifact | Path | Naming | Registration |
|---|---|---|---|
| Policy | `policies/` | `UPPER_SNAKE.md` | one row + one section in [`policies/README.md`](policies/README.md) |
| Design spec | `docs/superpowers/specs/` | `YYYY-MM-DD-repo-topic-design.md` | metadata header, numbered `§1…§9` |
| Implementation plan | `docs/superpowers/plans/` | `YYYY-MM-DD-repo-topic.md` | copy [`docs/superpowers/plans/TEMPLATE.md`](docs/superpowers/plans/TEMPLATE.md) |

Cross-links are relative and resolved **from each file's own directory**. Verify
a link with `test -f` on the resolved path before claiming it resolves.

**Commit provenance.** Exactly one `ai:<tier>` trailer per commit, as a
**standalone body line** — `ai:top`, `ai:mid`, `ai:cheap`, `ai:free`, `ai:review`.
A prefix in the subject line is rejected by
[`scripts/check_commit_provenance.sh`](scripts/check_commit_provenance.sh):

```bash
git commit -m 'docs: explain the pin guard' -m 'ai:top'
```

The local hook is bypassable and inactive until installed; the server-side check
in [`.github/workflows/provenance.yml`](.github/workflows/provenance.yml) reads
the PR description, which becomes the squash commit on `main`.

**Guard-script contract.** Every `scripts/check_*` and `scripts/assert_*` tool is
read-only and uses a three-way exit: `0` = the applicable invariants hold,
`1` = a named violation, `2` = could not run. **An unchecked invariant is never
reported as a pass**, and a file with zero checkable assertions is reported as
*not* evidence of conformance. Preserve that contract in any new guard; a gate
that cannot fail is not a control.

**Toolchain pins.** [`toolchain.yml`](toolchain.yml) is the single source for
declared tool versions and canonical action commits. Every `uses:` must be a
40-char SHA **equal to the manifest's canonical commit** — a valid but
non-canonical SHA passes generic pinning rules and fails here. Every value in the
manifest carries its evidence; add evidence with any new value. A canonical SHA
comes from a **runner log**, never from `git/ref/tags` (annotated tags return the
tag object, not a commit).

**Secrets and contact addresses.** Nothing secret in code or state. `billing_email`
lives only in gitignored `terraform.tfvars`; the published plus-addressed Gmail
streams are public on purpose and must never enter variables, defaults, or state.
[`docs/SECRETS_INVENTORY.md`](docs/SECRETS_INVENTORY.md) is the **public twin**:
it must stay opaque — no vault paths, host paths, account ids, holder names, or
media serials — and stay in sync with the confidential register. Local secrets go
through [`scripts/vault.sh`](scripts/vault.sh) (age-backed), never into the repo.

**Registers and findings.** Cite only finding IDs you have read in
[`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) or
[`docs/security/pre-deployment-independent-audit-2026-10-26.md`](docs/security/pre-deployment-independent-audit-2026-10-26.md).
Never invent an ID, never mark a finding remediated without command output
proving it, and never renumber a table — the register asserts counts about itself
and CI fails on parity violations. One writer per register file at a time.

**Terraform.** [`repos_data.tf`](repos_data.tf) is the repository inventory and
source of truth; `repos.tf` iterates it. No Terragrunt. This repo's own protection
is a `github_repository_ruleset` ([`repo_rulesets.tf`](repo_rulesets.tf)), not
classic branch protection. Paid-tier controls stay gated on `github_plan_tier` —
model them honestly, never fake them on Free. Keep `terraform fmt` clean.

---

## 7. Gates before you claim done

Run what your change touches; paste the output.

```bash
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform plan -no-color -input=false          # read-only; requires GITHUB_TOKEN
./scripts/check_toolchain_pins.sh toolchain.yml .github/workflows
python3 scripts/check_audit_register.py \
  docs/security/pre-deployment-independent-audit-2026-10-26.md docs/superpowers/specs/*.md
./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md
./scripts/check_secret_inventory.sh docs/SECRETS_INVENTORY.md
./scripts/check_public_register.sh docs/SECRETS_INVENTORY.md
```

CI runs these in [`.github/workflows/audit.yml`](.github/workflows/audit.yml).
The secret-free, network-free gates are placed **before** every credential
dependent step on purpose: a step after a failure is skipped, and a skipped docs
gate is indistinguishable from a passing one. Preserve that ordering.

`terraform plan` is never a formality — read the summary line and compare it to
what you intended (§5).

---

## 8. STOP conditions — halt and report

Stop immediately, state what you observed, and wait:

1. Any plan showing `destroy` or `replace`, or a summary that differs from the
   intended one (`1 to add, 0 to change` planned, `0 to add, 1 to change` seen).
2. A required value cannot be determined from evidence — no guessing, no
   placeholder, no silent fallback.
3. You are asked to judge compliance adequacy rather than implement a stated
   control.
4. Two consecutive failures on the same step.
5. A credential is missing, empty, or write-capable where read-only is required.
6. A register, table, or guard file has an unexpected shape (torn row, missing
   heading, zero assertions) — fix nothing until the owner has seen it.
7. The change would widen privilege: a token scope, an allow-list pattern, a
   bypass actor, a review count lowered.
8. Any instruction that conflicts with §1.

Halting is a successful outcome. Guessing is a P1 finding.

---

## 9. Environment facts (verified)

- Terraform `1.16.1` ([`.terraform-version`](.terraform-version)); installed via
  the HashiCorp apt repo.
- Python `.venv/bin/python` 3.12.3. Hooks are installed in this clone and bind
  `INSTALL_PYTHON` to `.venv/bin/python3`, so no venv activation is needed.
  (Re)install with
  `.venv/bin/pip3 install pre-commit && .venv/bin/pre-commit install`
  — `default_install_hook_types` wires both `pre-commit` and `commit-msg`.
  pre-commit 4.7.0.
- Declared tool versions in `toolchain.yml`: node `22`, python `3.12`,
  terraform `1.16.1`, pre-commit `4.7.0`. The host runs node v20.20.2 — a live
  divergence (VV-2026-11-003), stated not fixed here.
- `yq` is absent on this host. `gh` is present; the interactive credential is for
  the operator role only and must never reach CI
  ([`provider.tf`](provider.tf) holds the full two-role credential contract).
- Org shape: single-member, so peer review is `0` approvals by necessity —
  separation of duties is a documented gap, not a control.

---

## 10. Interaction contract

- Short replies; commands over narrative. Extra detail only on request.
- Deliver artifacts as **files** at a stated path, not as blocks to copy-paste.
- End with the next action as one unambiguous trigger the agent will execute,
  not as homework for the owner.
- Do the remaining read-only investigation yourself instead of listing it.
- Report failures honestly. A skipped or unrun gate is never reported green.

---

## 11. References

- [`policies/AI_WORKFLOW_POLICY.md`](policies/AI_WORKFLOW_POLICY.md) — the 15 levers, review checklist, tier routing, enforcement
- [`policies/AUDIT_PROMPT.md`](policies/AUDIT_PROMPT.md) — evidence-gated audit prompt
- [`policies/README.md`](policies/README.md) — policy and guard-script register
- [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) — findings register and control matrix
- [`state/README.md`](state/README.md) — local-state runbook and backend stub
- [`README.md`](README.md) — what this control plane manages
