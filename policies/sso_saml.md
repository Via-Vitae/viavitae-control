# SSO / SAML — gap analysis & compensating controls

## Requirement

SOC 2 (CC6.1), ISO 27001 (A.9.2, A.9.4), and GDPR (Art. 32) all require strong,
centrally-managed authentication for access to systems that process personal data.

## Current state (verified 2026-09-24)

- Org plan: **Free**.
- `two_factor_requirement_enabled`: **false**.
- SAML SSO: **not available** on Free (Enterprise Cloud only).

## Gap

| Control | Enforceable on Free? | Mechanism |
|---|---|---|
| Org-wide 2FA requirement | **Yes** | REST `PATCH /orgs/{org}` — automated in `enforce_sso.sh` |
| SAML SSO + IdP-managed access | **No** (Enterprise) | Manual IdP config; no OSS Terraform resource |
| SCIM user provisioning | **No** (Enterprise) | Manual / IdP |

## Compensating controls (until Enterprise)

1. **Enforce org-wide 2FA immediately** via `enforce_sso.sh --apply` (free, high value).
2. **Least-privilege membership** — only 1 member today (`JourneyOfLife`); keep it
   minimal and review quarterly. Note the single-member state also blocks peer-review
   enforcement (see `docs/COMPLIANCE.md` P1-2).
3. **Fine-grained PATs / short-lived tokens** for CI, scoped per-repo, stored in a sealed
   secret manager — never in Terraform state or repo files.
4. **Branch protection + CODEOWNERS** so no single credential can push unreviewed code.
5. **Allowed-actions policy** (`../org_actions_policy.tf`) to limit workflow supply chain.

## Remediation path

- **Short term:** enable 2FA (step 1). Record residual SSO gap in the risk register.
- **Medium term:** upgrade to GitHub Team → unlocks private-repo branch protection.
- **Long term:** upgrade to Enterprise Cloud → enable SAML SSO + SCIM, set
  `github_plan_tier = "enterprise"` and `enable_sso = true`; the control plane's
  effective-control matrix then reports SSO as active with no code change.
