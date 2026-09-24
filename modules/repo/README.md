# modules/repo

Standard, compliance-hardened GitHub repository template used by `viavitae-control`.

Every managed repository is an instance of this module. It asserts:

- **Repository settings** — visibility, least-privilege feature toggles (wiki,
  projects, downloads off), `delete_branch_on_merge`.
- **Security & analysis** — secret scanning + push protection (free for public
  repos); Advanced Security when the plan tier allows.
- **Dependabot security updates**.
- **Branch protection** — no direct pushes to the default branch, no force-push or
  deletion, required linear history, strict status checks, admins enforced. Peer-review
  count and code-owner review are configurable (default 0 / false for a single-member
  org to avoid lockout; raise once a second reviewer exists).
- **Managed files** (only when `manage_files = true`) — `.github/CODEOWNERS`,
  `.github/workflows/security.yml` (CodeQL), and a README skeleton.

## Plan-tier gating

Paid-only controls are never faked. The root module resolves each control against
`var.github_plan_tier` before passing it here:

| Control | Free | Team | Enterprise |
|---|---|---|---|
| Secret scanning / push protection (public) | ✅ | ✅ | ✅ |
| Dependabot security updates | ✅ | ✅ | ✅ |
| Branch protection (public repo) | ✅ | ✅ | ✅ |
| Branch protection (private repo) | ❌ | ✅ | ✅ |
| Advanced Security (private repo) | ❌ | ❌ | ✅ |

## Usage

```hcl
module "repo" {
  source = "./modules/repo"

  owner            = "Via-Vitae"
  name             = "viavitae-example"
  description      = "Example service"
  visibility       = "private"
  manage_files     = true
  codeowners_teams = ["architects", "platform"]
}
```

See `variables.tf` for the full contract.
