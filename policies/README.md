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
| `restore_peer_review.md` | Runbook to restore 1-approval review once a 2nd reviewer exists | Free+ (public) / Team+ (private) | one-line variable flip |
| `AUDIT_PROMPT.md` | Evidence-gated AI-agent audit prompt for control-plane audits | Free+ | paste into agent session |
| `AI_WORKFLOW_POLICY.md` | Mandatory workflow policy for AI-assisted development (15 levers + review checklist) | Free+ | enforce via PR review |

## Why scripts and not resources?

The `integrations/github` provider does not expose a resource for SAML SSO
enforcement, and org-wide two-factor enforcement is a distinct API call. Rather
than pretend these are declarative, we implement them as reviewed scripts, gate
them by `var.enable_sso` / plan tier, and record the residual gap in
`docs/COMPLIANCE.md`. This keeps the control plane honest under audit.

All scripts default to **dry-run**; pass `--apply` to make changes.

## Audit prompt

[`AUDIT_PROMPT.md`](AUDIT_PROMPT.md) is a reusable, evidence-gated AI-agent audit
prompt for the Via-Vitae control plane. It defines staged gates (0–5), a fixed
findings JSON schema, and a severity rubric tied to exploitability. Paste it
verbatim into an agent session to execute a full audit cycle.

See the design spec in
[`docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md`](../docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md)
for the rationale.

## AI workflow policy

[`AI_WORKFLOW_POLICY.md`](AI_WORKFLOW_POLICY.md) defines the mandatory workflow for
AI-assisted development in this compliance-controlled repository. It specifies 15
levers (in priority order) and a mandatory review checklist that must be signed off
before any AI-generated change is committed. This is the compliance control that
distinguishes authorized automation from uncontrolled automation under SOC 2 CC8.1
and ISO 27001 A.14.2.2.
