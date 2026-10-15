# viavitae-control — GitHub Organization Control Plane

Declarative, compliance-driven source of truth for **every repository and
organization-level policy** in the [`Via-Vitae`](https://github.com/Via-Vitae) org.

> This repo manages **Via-Vitae only**. It is deliberately separate from
> `jol-control`, which manages the `journeyoflife-org` org. The two are never mixed.

Built with Terraform + the `integrations/github` provider. Designed for **SOC 2 /
GDPR / ISO 27001**, tier-agnostic (runs on GitHub **Free** today, activates stricter
controls automatically on Team/Enterprise), and **non-destructive by default**.

> ⚠️ This control plane manages a live organization. Read
> [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) — it lists P0/P1 findings (all 30 repos
> public, 2FA off, single-member org) that require human action.

## What it controls

- **All 30 repositories** declared explicitly in [`repos_data.tf`](repos_data.tf)
  (Approach A) with per-repo visibility, tier, and CODEOWNERS.
- **Repo hardening** via [`modules/repo`](modules/repo): least-privilege features,
  secret scanning + push protection, Dependabot, branch protection, CODEOWNERS,
  and a baseline CodeQL security workflow.
- **Org policy**: member permissions ([`org_settings.tf`](org_settings.tf)) and the
  GitHub Actions allow-list ([`org_actions_policy.tf`](org_actions_policy.tf)).
- **`protect-main` ruleset** ([`repo_rulesets.tf`](repo_rulesets.tf)): the control
  repo's own branch protection, declared as a `github_repository_ruleset` and adopted
  by import (no drift). Rulesets work on empty repos, unlike classic branch protection.
- **Tier-gated controls**: SSO/SAML, private-repo protection, and Advanced Security
  are modeled honestly ([`policies/`](policies)) — never faked on Free.

## Repository layout

```
├── versions.tf · provider.tf · variables.tf · locals.tf
├── repos_data.tf        # inventory of all 30 Via-Vitae repos (SOURCE OF TRUTH)
├── repos.tf             # module "repo" for_each over the inventory
├── imports.tf           # adopt existing repos into state (non-destructive)
├── org_settings.tf      # org member/permission + new-repo security defaults
├── org_actions_policy.tf# GitHub Actions allow-list
├── repo_rulesets.tf     # protect-main ruleset (viavitae-control) under IaC
├── outputs.tf           # effective-control matrix + gap register + P0/P1 alerts
├── modules/repo/        # reusable, compliance-hardened repo template
├── policies/            # SSO/SAML gap + enforce_sso.sh + allowed-actions doc
├── state/               # local-state runbook + S3 backend stub
├── scripts/             # generate_inventory.sh · detect_drift.sh
└── docs/COMPLIANCE.md   # control→resource mapping + P0/P1 findings + roadmap
```

## Quickstart (local, read-only)

```bash
# 1. Provide a token with admin:org + repo + workflow scopes (never committed).
export GITHUB_TOKEN="$(gh auth token)"

# 2. Initialize with local state.
terraform init

# 3. Validate configuration offline.
terraform validate

# 4. Preview changes (adopts existing repos via import; makes NO changes).
terraform plan
```

Only run `terraform apply` after reviewing the plan and the staged rollout in
[`docs/COMPLIANCE.md`](docs/COMPLIANCE.md).

## Changing the org (day-2 workflow)

1. **Add/rename a repo:** edit `repos_data.tf` (one entry), open a PR.
2. **Make a repo private:** change its `visibility`, set `manage_files = true` if you
   want CODEOWNERS/workflow written. Requires Team+ for private branch protection.
3. **New repo from scratch:** add an entry with `visibility`, `auto_init = true`,
   `manage_files = true`; the module creates it fully hardened.
4. **Detect shadow repos:** `scripts/detect_drift.sh` (wire into CI).
5. **Refresh inventory:** `scripts/generate_inventory.sh` (merge the diff by PR).
6. **Re-point published contact addresses:** `scripts/update_contact_emails.sh`
   (dry-run by default; `--diff` to preview, `--check-residue` to rehearse every gate
   without pushing, `--apply` to open one PR per repo). Safety gates are regression-
   tested by `scripts/test_contact_email_gates.sh`.

## Communication addresses

The Via-Vitae org uses **plus-addressed Gmail streams** to segregate
role-based inbound email (all delivered to one inbox, routed by filters):

| Role | Address |
|---|---|
| GitHub org / billing | `journey4oflife+viavitae.github@gmail.com` |
| Security reports | `journey4oflife+viavitae.security@gmail.com` |
| Privacy / DPO | `journey4oflife+viavitae.privacy@gmail.com` |
| Billing | `journey4oflife+viavitae.billing@gmail.com` |
| General / dev | `journey4oflife+viavitae.dev@gmail.com` |

> These are the addresses the org **publishes** as contact channels — they appear
> in `SECURITY.md`, `SUPPORT.md`, `LICENSE`, the DPIA templates and the website
> across the org. They are receiving addresses, not secrets, and are listed
> publicly on purpose (GDPR Art. 38 requires a reachable DPO contact). What is
> forbidden is putting them in Terraform variables/defaults or letting them reach
> `terraform.tfstate`; the real `billing_email` lives only in gitignored
> `terraform.tfvars`.
> See [policies/EMAIL_POLICY.md](policies/EMAIL_POLICY.md) for the role→artifact
> mapping and [policies/README.md](policies/README.md) for the policy rationale.
>
> **Why not `security@viavitae.com`?** Because it cannot receive mail: `viavitae.com`
> has no nameserver delegation and `viavitae.site` has no `MX` record, so the
> previously published domain addresses were a dead channel. They are retired.
>
> **Migration target (Phase 2):** once `viavitae.site` MX is configured and a test
> message is delivered, the public-facing roles (`security@`, `privacy@`,
> `billing@`) move to custom-domain aliases and the personal handle disappears
> from public artifacts again.

## Single-member org caveat

Via-Vitae currently has **one member** (`JourneyOfLife`). Requiring peer review would
lock the sole admin out (you cannot approve your own PR). Branch protection therefore
defaults to `branch_required_approving_review_count = 0` and
`branch_require_code_owner_reviews = false` — still enforcing a PR workflow, blocking
force-pushes/deletions, and requiring up-to-date branches. **Once a second member or
team exists**, raise the review count to 1 and enable code-owner review.

## Safety guarantees

- **No secrets in code or state** — the token comes only from `GITHUB_TOKEN`.
- **First apply is non-destructive** — existing repos are imported, visibility is
  preserved (`0 to destroy` in the plan), and no files are written into them
  (`manage_files = false`).
- **Paid-only controls are gated** by `github_plan_tier`, so `apply` never attempts
  an operation the current plan cannot satisfy.
- **Empty-repo guard** — branch protection is deferred for repos whose default
  branch does not exist yet (all 30 are currently empty), so `apply` never hits a
  "Branch not found" error. Deferred repos are listed in the
  `branch_protection_deferred` output and the `control_gaps` register. Set
  `repos_have_default_branch = true` (or per-repo `default_branch_exists`) once
  repos have content, then re-apply.
- **State** is git-ignored; migrate to the encrypted S3 backend before production.

## Plan-tier feature flags

Set `github_plan_tier` (`free` | `team` | `enterprise`) in `terraform.tfvars`.
`terraform output effective_control_matrix` shows what is actually active;
`terraform output control_gaps` shows what is requested but unenforceable.

## Status

Re-measured 2026-10-15 (this paragraph was stale — see `docs/COMPLIANCE.md` P1-12):

- Org: **31 repositories** — 26 public, 5 private (`viavitae-policies`,
  `viavitae-compliance`, `viavitae-data-governance`, `viavitae-threat-model`,
  `viavitae-vendor-register`); **9 still empty**, 21 populated, and 20 of those carry
  classic branch protection (`viavitae-control` uses the `protect-main` ruleset instead).
- Terraform state is **local and restored from the `age` backup** (lineage `eff08856`,
  serial 13, 9 managed resources: 6 repositories, the org Actions permission, one branch
  protection, one Dependabot-updates resource). It is **not** in an S3 backend, and there is
  no locking — see `state/README.md` and P1-4/P1-12/C13c.
- `terraform apply` has **not** been run in this work. The current plan is readable and contains
  **0 destroys** — 26 imports, 46 creates, 27 updates. Because the 20 classic protections arrive
  as *creates*, the plan cannot show their drift, so each planned document was compared field by
  field with the live API instead: an apply writes `required_linear_history` true on 13 repos and
  `dismiss_stale_reviews` true on `viavitae-qa`, leaves 6 repos identical, and **loosens nothing**.
  Visible updates also include `delete_branch_on_merge` on and `has_projects`/`has_wiki` off for
  22–25 repos. At org level it turns **on** Dependabot alerts, security updates and the dependency
  graph for new repositories (currently off), and adds `provenance` as a required status check on
  this repo's `protect-main` ruleset — verified satisfiable (the check reports on 5/5 recent PRs),
  and note the ruleset has no bypass actors, so that workflow becoming disabled would block merges
  here for admins too. See P1-18 for the method and the full table.
- Published contact channels are all plus-addressed streams now (P1-7 closed, P1-8 closed:
  private vulnerability reporting on 26/26 public repos).
- **This repo's `Audit` CI job is red, and has been** — `Terraform plan` cannot import the five
  private repos with the configured `TF_GITHUB_TOKEN`, and `detect_drift.sh` never runs because
  `ORG_READ_TOKEN` is not set. `fmt`/`validate`/`provenance` pass. See P1-23 for the exact fix
  (a credential, not a workflow edit) and for why making the step green-by-configuration would
  have been the wrong move.
- Peer review is currently **0 approvals** on every repo, because the org has one member and
  the second account cannot join without 2FA (P1-10). Separation of duties is a documented
  gap, not a control, until that changes.
