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

Generated + validated locally against the live Via-Vitae org. **Not pushed, not
applied.** See the design spec in [`docs/superpowers/specs/`](docs/superpowers/specs/).
