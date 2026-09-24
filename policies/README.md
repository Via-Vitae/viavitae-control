# policies/

Organization-level policy that either (a) has no first-class Terraform resource in
the open-source GitHub provider, or (b) depends on the org's GitHub plan tier.

These are managed as **documented, idempotent API scripts** behind feature flags —
never fabricated as fake Terraform resources. Each policy states its compliance
mapping, its plan-tier requirement, and how it is verified.

| File | Purpose | Plan tier | Automatable? |
|---|---|---|---|
| `enforce_sso.sh` | Org-wide 2FA requirement + SAML SSO guidance | 2FA: Free · SAML: Enterprise | 2FA yes; SAML needs IdP config |
| `allowed_actions.md` | GitHub Actions allow-list rationale | Free+ | yes (in Terraform) |
| `sso_saml.md` | SSO/SAML gap analysis & compensating controls | Enterprise | partial |

## Why scripts and not resources?

The `integrations/github` provider does not expose a resource for SAML SSO
enforcement, and org-wide two-factor enforcement is a distinct API call. Rather
than pretend these are declarative, we implement them as reviewed scripts, gate
them by `var.enable_sso` / plan tier, and record the residual gap in
`docs/COMPLIANCE.md`. This keeps the control plane honest under audit.

All scripts default to **dry-run**; pass `--apply` to make changes.
