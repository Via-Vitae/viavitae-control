# viavitae-control — GitHub Organization Control Plane (Design Spec)

- **Date:** 2026-09-24
- **Owner org:** `Via-Vitae` (GitHub Free plan)
- **Target repo:** `Via-Vitae/viavitae-control` (empty, default branch `main`)
- **Local working dir:** `/opt/viavitae/repos/viavitae-control`
- **Compliance targets:** SOC 2, GDPR, ISO 27001
- **Status:** Approved design; implementation = generate files + local validate only (no push, no apply)

> Scope boundary: this control plane manages **Via-Vitae only**. It is deliberately
> separate from `jol-control`, which manages the `journeyoflife-org` org. The two
> organizations and their repos are never mixed in this repository.

## 1. Problem

`Via-Vitae` runs a platform of ministry/funeral/memorial landing sites plus
compliance, data-governance, and vendor-management repositories. It has **30
repositories, all public**, and **every org-level security control disabled**. There
is no declarative source of truth for repository or organization policy. This spec
defines `viavitae-control`: a Terraform control plane that becomes the single,
reviewable, drift-detectable declaration of the org's repositories and security policy.

## 2. Verified baseline (empirical, via `gh api`, 2026-09-24)

- 30 repos, all `public`, none archived, none forks (`.github` + 29 `viavitae-*`).
- 6 teams: `architects`(push), `compliance`, `dpo`, `legal`, `platform`, `security`.
- **1 member:** `JourneyOfLife`.
- Org plan: **free**. `two_factor_requirement_enabled=false`,
  `secret_scanning_enabled_for_new_repositories=false`,
  `secret_scanning_push_protection=false`, `advanced_security=false`,
  `dependabot_alerts=false`, `default_repository_permission=read`,
  `members_can_delete_repositories=true`, `members_can_change_repo_visibility=true`.
- billing_email: `journey4oflife+viavitae.github@gmail.com`.
- Compliance-sensitive repos are public: `viavitae-compliance`,
  `viavitae-data-governance` (DPIAs/records of processing), `viavitae-vendor-register`
  (GDPR Art. 28), `viavitae-threat-model`, `viavitae-policies`.

## 3. Hard constraints

**GitHub Free plan** — the following are not enforceable on Free for private repos
and are modeled as *gated* (activatable on upgrade), never faked:

- SAML/SSO enforcement → Enterprise only; **no open-source Terraform resource** exists.
- Advanced Security (secret scanning on *private* repos) → Enterprise.
- Branch protection on *private* repos → Team or Enterprise.

Public repos DO get free secret scanning, push protection, Dependabot, and branch
protection, so the design leans on those while the org is on Free.

**Single-member org** — requiring >=1 approving review or code-owner review would lock
the sole admin out (you cannot approve your own PR). Branch protection therefore
defaults to `required_approving_review_count = 0` + `require_code_owner_reviews = false`,
still enforcing a PR workflow, blocking force-push/deletion, requiring linear history
and up-to-date branches. Tighten once a second member/team exists.

## 4. Decisions (approved)

1. **Repo declaration = Approach A + C.** Explicit inventory map (`repos_data.tf`) is the
   source of truth; `scripts/detect_drift.sh` fails CI if any live repo is missing.
2. **Tier-agnostic feature flags.** `github_plan_tier` + per-control booleans; `locals.tf`
   computes an *effective-control matrix*: a paid control activates only if flag AND tier
   permit; otherwise recorded as a documented gap in outputs + COMPLIANCE.md.
3. **Non-destructive first apply.** All 30 existing repos keep current visibility; no files
   written to them (`manage_files=false`); repos adopted via `import` blocks, not recreated.
   Secret scanning/push protection/Dependabot enabled on existing public repos
   (non-breaking compliance win). Privatization is a separate staged step.
4. **SSO handled as a flagged API script + documented gap**, not a fabricated resource.
   Org-wide 2FA (free) is automated in `policies/enforce_sso.sh`.
5. **State = encrypted local now**, with a stubbed S3 backend ready to enable.
6. **CODEOWNERS use real Via-Vitae teams.** Tier→team defaults in `locals.tf`; sensitive
   repos override to include `dpo`/`legal`/`compliance`.

## 5. Architecture

```
root/
  versions.tf provider.tf variables.tf locals.tf
  repos_data.tf   -> inventory map of all 30 repos (generated from live org)
  repos.tf        -> module "repo" { for_each = local.repos }
  imports.tf      -> import blocks adopting existing repos into state
  org_settings.tf -> github_organization_settings (current values preserved)
  org_actions_policy.tf -> github_actions_organization_permissions
  outputs.tf      -> drift report + effective-control matrix + gap register + P0/P1
  modules/repo/   -> per-repo: repository, branch_protection, security, files
  policies/       -> SSO/SAML gap doc + enforce_sso.sh (2FA) + allowed_actions doc
  state/          -> local-state runbook + backend_s3.tf.example (stubbed)
  scripts/        -> generate_inventory.sh, detect_drift.sh
  docs/COMPLIANCE.md -> control->resource mapping + gap register
```

### 5.1 repo module contract
- **Inputs:** `name, description, visibility, auto_init, license_template, codeowners_teams,
  manage_files, enable_branch_protection, apply_private_branch_protection,
  required_approving_review_count, require_code_owner_reviews, enforce_admins,
  enable_secret_scanning, enable_push_protection, enable_advanced_security,
  enable_dependabot_alerts, enable_dependabot_security_updates, default_branch, owner`.
- **Does:** asserts `github_repository`; conditionally adds `github_branch_protection`,
  security settings, Dependabot updates, and skeleton files (CODEOWNERS,
  `.github/workflows/security.yml`, README). All conditionals gated by flags.
- **Depends on:** `integrations/github` provider only; token via `GITHUB_TOKEN` env.

### 5.2 Inventory object shape
```hcl
"<repo>" = {
  description  = string
  visibility   = "public" | "private" | "internal"   # preserved = current live value
  tier         = "control" | "platform" | "app" | "site" | "meta"
  manage_files = bool                                # false for existing repos
  # optional overrides: codeowners_teams, license_template, enable_branch_protection
}
```
Tier→default CODEOWNERS teams: `control→[security,compliance]`,
`platform→[platform,security]`, `app→[architects,platform]`,
`site→[platform,architects]`, `meta→[security,platform]`.

## 6. Effective-control matrix (locals.tf)

| Control | Flag | Requires | Free behavior |
|---|---|---|---|
| Secret scanning (public repo) | `enable_secret_scanning` | Free+ | enabled |
| Push protection (public repo) | `enable_push_protection` | Free+ | enabled |
| Dependabot security updates | `enable_dependabot_security_updates` | Free+ | enabled |
| Branch protection (public repo) | `enable_branch_protection` | Free+ | enabled |
| Advanced Security (private repo) | `enable_advanced_security` | Enterprise | gap |
| Branch protection (private repo) | `enable_private_branch_protection` | Team+ | gap |
| Peer review / code-owner review | `branch_required_approving_review_count` | 2nd member | 0 (gap) |
| SAML SSO | `enable_sso` | Enterprise + API script | gap |
| Allowed Actions policy | `actions_allowed_mode` | Free+ | enabled |

## 7. Non-destructive guarantees

- `import` blocks adopt existing repos → plan shows import + in-place updates, **0 destroys**.
- Visibility of all 30 repos unchanged on first apply.
- `manage_files=false` on existing repos → CODEOWNERS/workflows not written (no clobber).
- `github_organization_settings` initialized to **current** live Via-Vitae values.
- Compliance-sensitive repos flagged for staged privatization, not auto-flipped.

## 8. Validation plan

`terraform init` (local backend) → `terraform providers schema` (verify argument names
empirically) → `terraform validate` → `terraform plan` (read-only, token from `gh`) →
`scripts/detect_drift.sh`. Show diff. **No `git push`, no `terraform apply`.**

## 9. Out of scope (this iteration)

- Flipping repos private / migrating state to S3 / enforcing SSO / enforcing 2FA
  (staged follow-ups requiring explicit go-ahead).
- Editing the existing Python `main.py`/`pyproject.toml` (left untouched).
