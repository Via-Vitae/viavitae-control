# Architecture — viavitae-control

Describes what this repository is, how it relates to the two sibling control planes, and how
each claim below can be re-measured. Every section ends with the command that proves it, because
in this estate a document is a claim and command output is evidence
([`policies/AI_WORKFLOW_POLICY.md`](../policies/AI_WORKFLOW_POLICY.md) §3.6).

Measured 2026-11-03. If you are reading this later and a command disagrees with the text, the
text is stale — fix it in the same PR that notices.

## 1. What this repository is

The Terraform control plane for the `Via-Vitae` GitHub organization. It declares every
repository in the org plus organization-level policy: settings, rulesets, the Actions
allow-list. It contains no application code, runs nothing, and its CI has no `apply` job.

Two consequences shape everything else in this file:

- **The blast radius is configuration, not runtime.** A bad value here becomes a live
  organization setting on the next apply the owner authorizes. That is why the workflow is
  plan-only by policy, not by convenience.
- **The description of a control is not the control.** Several sections below state that a
  guard *cannot see* something. Those sentences are load-bearing; a reader who assumes
  coverage from the file listing alone gets false assurance — the recurring defect class in
  [`docs/security/pre-deployment-independent-audit-2026-10-26.md`](../security/pre-deployment-independent-audit-2026-10-26.md).

Prove: `sed -n '1,12p' README.md` and `grep -c 'terraform apply' .github/workflows/*.yml` → `0`.

## 2. The three control planes and the entity each governs

The portfolio has three independent Terraform planes, one per legal entity and one per GitHub
organization. They share no state, no credentials and no repository inventory.

| Plane | Path | GitHub org | What the entity is |
| --- | --- | --- | --- |
| viavitae-control | `/opt/viavitae/repos/viavitae-control` | `Via-Vitae` | Commercial IT company; regulated EU hosting, 31 repositories |
| jol-control | `/opt/jol/repos/jol-control` | `journeyoflife-org` | Charity plane — governance for the church-community infrastructure tree |
| jolarca-control | `/opt/jolarca/repos/jolarca-control` | `jolarca-dev` | Marketplace tree; PCI-DSS scope |

Prove: `head -4 /opt/jol/repos/jol-control/README.md` (charity plane),
`head -4 /opt/jolarca/repos/jolarca-control/README.md` (marketplace), and this file's own
`head -4 README.md`. Repository counts per org move; measure them rather than trusting any
number in a document, including the 31 above.

## 3. State backend, per plane

| Plane | Backend | Measured |
| --- | --- | --- |
| viavitae-control | Local file `terraform.tfstate`, gitignored | No `backend` or `cloud` block in root `*.tf`; `grep -o '"serial": *[0-9]*' terraform.tfstate` → 143 |
| jol-control | Local file `terraform.tfstate` | No backend block; serial 306 |
| jolarca-control | HCP Terraform `cloud {}` | `main.tf` declares `cloud { organization = "jolarca-dev" workspaces { name = "jolarca-control" } }` |

The two local-state planes therefore depend on host durability, not a service. For this plane
the compensating control is an **age-encrypted backup copy**, procedure in
[`state/README.md`](../state/README.md): `umask 077` first, encrypt to
`/opt/jol/backup/tfstate/…tfstate.<ts>.age`, prove the mode guard with a `find -perm /g+r,o+r`
that must print nothing, and prove restorability with a `sha256sum` round-trip of one archive
per run. Cadence is after every apply and at least every 30 days. The same file states the
limit plainly and it must be repeated here: until a second physical medium exists, those
archives **share `nvme1n1` with the data they protect**, so they guard deletion and corruption
— not disk loss. `state/README.md` also records the plane's state `lineage` invariant
(`eff08856`): `serial` only ever increases, so no document should hard-check a serial value.
The S3 backend is written but not adopted (`state/backend_s3.tf.example`); `docs/COMPLIANCE.md`
records that the P1-4 migration is blocked by the AWS account's SCP.

Prove: `grep -rn -E '^\s*(backend|cloud)\s' *.tf` in each plane (empty output means local
state), and `cat .gitignore | grep tfstate`.

## 4. The isolation boundary, and what it does not cover

Declared rule: the control plane manages Via-Vitae only, and orgs are never mixed —
`docs/COMPLIANCE.md` opens with that sentence. The mechanism is `provider.tf` setting
`owner = var.github_owner`, whose default is `Via-Vitae` (`variables.tf`). Pointing this plane
at a different organization is therefore a variable override, not a code change — which is
precisely why `terraform plan` output, and not intent, is the review surface.

Real limits, stated because the boundary is easy to over-read:

- **The human identity is shared.** `JourneyOfLife` is the sole member of `Via-Vitae`, the sole
  member of `jolarca-dev`, and one of two members of `journeyoflife-org`. Three orgs, three
  credentials, one person who can approve any of them. Prove:
  `gh api orgs/<org>/members --jq '.[].login'` for each org.
- **Every team in this org resolves to that same account.** All six teams
  (`architects`, `compliance`, `dpo`, `legal`, `platform`, `security`) have exactly one member.
  This is why `.github/CODEOWNERS` in this repo is routing, not separation of duties, and why
  finding `VV-2026-10-003` is open.
- **The cross-plane isolation model is written for the other two planes.**
  `/opt/jolarca/repos/jolarca-control/docs/security/isolation-model.md` defines boundary 1
  (no shared membership, tokens, secrets, CI configuration or state) for `jolarca-dev` ↔
  `journeyoflife-org`. The pairings involving `Via-Vitae` are not covered by that document — a
  known gap, not a settled state. Prove: `ls` that path and read its scope section.
- **Policy text is never copied across planes.** Each plane's compliance artifacts name a
  different controller; `CONTRIBUTING.md` and `SECURITY.md` here were written for Via-Vitae
  rather than adapted, per the halt-and-report rule in the governance-artifacts plan.

## 5. CI credential model — the two-token contract

`.github/workflows/audit.yml` uses two distinct secrets for two distinct jobs, and the built-in
`GITHUB_TOKEN` gets `permissions: contents: read` only.

| Secret | Used by | Contract |
| --- | --- | --- |
| `TF_GITHUB_TOKEN` | the `terraform plan` step | Fine-grained PAT, repository Metadata + Administration **read-only**, all repositories including the private ones. No organization permissions: the root tree stopped reading a `github_organization` data source when that read moved behind `var.manage_org_data` (default `false`) into `modules/org_assertions`. A token that still holds the org grant is reported as *unused power — drop it*, not as a pass. |
| `ORG_READ_TOKEN` | `scripts/detect_drift.sh` and `scripts/assert_live_controls.sh` | Optional in the sense that the two steps are `if: env.HAS_ORG_READ_TOKEN`, bridged from the secret because the `secrets` context is unavailable in `if:`. But absence is not silently tolerated: a following step `Fail loudly if ORG_READ_TOKEN is absent` prints the exact credential to mint and **exits 1**, so the job cannot be green while drift and live-control assertions never ran. |

Why this split exists is recorded in the header of `scripts/check_ci_credential.sh`: on
2026-10-04 a plan failed with five `Cannot import non-existent remote object` errors whose cause
was an under-scoped token, and the natural fix — mint an org-admin classic PAT and put it in a
**public** repository's secrets — would have been worse than the outage. The gate now turns that
mystery into a second-scale message and refuses any credential reporting an OAuth/classic scope
set. Note the limit the script states about itself: it proves the read set the **current
configuration** needs and the absence of write capability; it cannot prove a fine-grained
token's own grants, because GitHub exposes no read-only endpoint for that.

Prove: `grep -n 'secrets\.' .github/workflows/audit.yml` → `TF_GITHUB_TOKEN`, `ORG_READ_TOKEN`;
`sed -n '1,77p' scripts/check_ci_credential.sh` for the contract in the script's own words.

## 6. How this repository is protected

Protection for `main` here is a **ruleset**, `protect-main` (`repo_rulesets.tf`), not classic
branch protection — `repos_data.tf` sets `enable_branch_protection = false` for this repo so the
two mechanisms never overlap.

Live state measured 2026-11-03 (`gh api repos/Via-Vitae/viavitae-control/rulesets/23943250`):

| Field | Live value | Consequence |
| --- | --- | --- |
| rules | deletion, non_fast_forward, required_linear_history, pull_request, required_status_checks | Force-push and branch deletion are refused; history stays linear |
| required status checks | `provenance` **only** | The `ai:<tier>` trailer gate genuinely blocks merge |
| required status checks | `audit` is **not** listed | A PR can merge with `audit` red. The credential, drift and live-control guards are advisory here |
| `require_code_owner_review` | `false` | `.github/CODEOWNERS` routes reviewers; nothing enforces an owner approval |
| `required_approving_review_count` | `0` | One member cannot approve their own PR, so the org keeps the PR workflow without pretending to peer review |
| `bypass_actors` | empty | Not even an admin bypass is declared |

Prove: the `gh api` call above, and `grep -n 'required_status_check' repo_rulesets.tf` to see
the declaration that produced it. The direct-push refusal is observable too: `git push origin
main` fails with `GH013` plus "Required status check `provenance` is expected".

## 7. Guard inventory

Registered, with each script's exit contract, in
[`policies/README.md`](../policies/README.md) — that table is the register, this section is a
map. House contract everywhere: **0** the invariant holds, **1** a violation is named, **2**
nothing was checkable, and an unchecked invariant is never reported as a pass.

- `scripts/check_ci_credential.sh` — CI credential pre-flight (§5).
- `scripts/check_toolchain_pins.sh` — `toolchain.yml` is the single source for CI tool versions
  and canonical action commits; every `uses:` in `.github/workflows/` must be pinned to a
  40-character SHA **and** equal to the manifest's canonical commit. Runs before every
  credential-dependent step, because a docs gate parked behind a credential failure proves
  nothing. This is also the control that stands in for the org's absent SHA-pinning enforcement.
- `scripts/check_plan_selfcite.sh` — a plan must contain the STOP clauses and checklists it
  claims, and its quoted metrics must match its own body.
- `scripts/check_audit_register.py` — eight invariants (I1–I8) over the audit register and the
  specs: table column consistency, register/verification finding-set parity, evidence
  contiguity, PART headings, dangling `§` references, front-matter revisions, prose counts
  recomputed against the tables.
- `scripts/check_secret_inventory.sh`, `scripts/check_public_register.sh`,
  `scripts/reconcile_secret_register.sh` — the public secrets register must leak no identifiers
  and must stay in step with the confidential register; "unable to verify" is never recorded as
  "in sync".
- `scripts/detect_drift.sh` — live org versus the `repos_data.tf` inventory (declared
  versus existing).
- `scripts/assert_live_controls.sh` — live protection parameters versus the declaration. Scope
  limit stated in the script header: **classic branch protection only**, so ruleset-governed
  repos are excluded.
- `scripts/check_commit_provenance.sh` — local `commit-msg` hook for the `ai:<tier>` trailer;
  bypassable, so it is early feedback while `.github/workflows/provenance.yml` is the gate.
- `scripts/propagate_landing_scaffold.py`, `scripts/rollout_*.sh`, `scripts/patch_*.py` —
  write-path tooling for estate-wide propagation, each with pre-write validation. They are how
  a uniform fix becomes reviewable PRs instead of hand edits.

Prove: `grep -n '^| \`scripts/' policies/README.md | head -30`.

## 8. The Actions allow-list as a supply-chain control

`org_actions_policy.tf` sets `allowed_actions = "selected"` with
`github_owned_allowed = true`, `verified_allowed = true` and the patterns in
`var.actions_allowed_patterns`. Measured 2026-11-03 the declaration holds **11** entries: nine
floating (`actions/checkout@*`, `actions/setup-node@*`, `actions/setup-python@*`,
`hashicorp/setup-terraform@*`, `actions/upload-artifact@*`, `actions/download-artifact@*`,
`actions/cache@*`, `github/codeql-action@*`, `dependabot/*`) and two pinned to commit SHAs
(`pnpm/action-setup@ea17c68d…`, `pnpm/action-setup@b906affc…`).

Two asymmetries matter:

- The floating patterns are an admission of *any future commit* of those actions, while
  `var.actions_sha_pinning_required` defaults to `false` — org policy and per-repo practice do
  not agree (finding `VV-2026-11-013`). `check_toolchain_pins.sh` closes that gap for *this*
  repository only.
- The `pnpm` pins show the failure mode: `pnpm/action-setup` is not GitHub-owned and not a
  verified creator, so an unadmitted commit makes a workflow start in `startup_failure` with
  **zero jobs, zero check-runs and no logs** — a required context then never reports and every
  PR freezes (finding `VV-2026-11-016`; the convergence plan is
  [`docs/superpowers/plans/2026-11-03-viavitae-control-pnpm-pin-convergence.md`](plans/2026-11-03-viavitae-control-pnpm-pin-convergence.md)).
  Dependabot bumping an action to a third commit reproduces it, which is why the interaction
  between `.github/dependabot.yml` and this allow-list is called out rather than assumed safe.

Prove: `grep -n -A28 'actions_allowed_patterns' variables.tf | sed -n '1,35p'`.

## 9. Known gaps — what is asserted by nothing

Listed in the file it affects, because "not covered" is invisible unless someone writes it down.

1. **This repository's own ruleset is asserted by no script.** `assert_live_controls.sh`
   excludes ruleset-governed repos and its header says "assert them separately" — no separate
   implementation exists. So `protect-main` is verified by an operator running the `gh api` call
   in §6, not by CI. If the ruleset were edited out of band, no guard would notice.
2. **`audit` is advisory on its own protection** (§6): the guards that check the credential,
   the inventory and the live controls can all be red while a PR merges.
3. **The five private compliance repos are unreadable for protection on GitHub Free** (HTTP
   403), so `assert_live_controls.sh` reports them as `ERROR` and they remain unverified —
   findings `VV-2026-10-002` / `-010`.
4. **Org-wide SHA pinning is off** while repositories rely on a per-repo "Action SHA pinning"
   check (`VV-2026-10-007`).
5. **No separation of duties exists** at the identity layer (`VV-2026-10-003`), so every review
   control in this document degrades to a single person's approval until a second reviewer
   exists — `policies/restore_peer_review.md` is the runbook for that.

## 10. Re-measuring this file

```bash
grep -rn -E '^\s*(backend|cloud)\s' *.tf
grep -o '"serial": *[0-9]*' terraform.tfstate | head -1
gh api orgs/Via-Vitae/teams --paginate --jq '.[].slug'
for t in architects compliance dpo legal platform security; do
  printf '%s: ' "$t"; gh api "orgs/Via-Vitae/teams/$t/members" --jq '.[].login'
done
gh api repos/Via-Vitae/viavitae-control/rulesets/23943250 \
  --jq '{ctx: [.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[]?.context], cor: [.rules[] | select(.type=="pull_request") | .parameters.require_code_owner_review]}'
grep -n -A28 'actions_allowed_patterns' variables.tf
grep -n '^| `scripts/' policies/README.md
```
