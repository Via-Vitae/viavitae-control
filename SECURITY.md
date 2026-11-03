# Security policy — viavitae-control

## What this repository is

The Terraform control plane for the `Via-Vitae` GitHub organization. It declares the
organization's 31 repositories (`repos_data.tf` — counted 2026-11-03: 31 inventory
entries), the organization settings (`org_settings.tf`), the repository rulesets
(`repo_rulesets.tf`) and the organization Actions allow-list (`org_actions_policy.tf`).

It runs no workload, serves no traffic and holds no application code. A defect here is a
**configuration** defect with organization-wide blast radius, not a remote code execution
surface: everything this repo can change, it changes through the GitHub API using a
credential that CI does not hold write to.

## Credential classes reachable from this repository

| Credential | Where it lives | Capability |
| --- | --- | --- |
| CI plan credential | Actions secret `TF_GITHUB_TOKEN` | Fine-grained PAT, Metadata + Administration **read-only**, all repositories. `scripts/check_ci_credential.sh` runs before `terraform plan` and fails the run if anything reporting an OAuth/classic scope set is put in this slot, so a write-capable token in CI is a red check rather than a latent risk. |
| Operator read token | Actions secret `ORG_READ_TOKEN` | Optional. `scripts/detect_drift.sh` and `scripts/assert_live_controls.sh` are gated on it; without it those two steps are skipped and the run reports that as a skip, not a pass. |
| Terraform state | `terraform.tfstate` on the operator's host, gitignored | Repository and organization settings, **including the organization's operational contact address** stored as `billing_email`. No credential values. Because that one field is personal data of a named individual, the state file is treated as sensitive: it is backed up age-encrypted off-host (`state/README.md`, and the backup verification recorded in `docs/COMPLIANCE.md`). |
| The Actions allow-list | `org_actions_policy.tf` | Not a credential, but a supply-chain control: what it admits is what up to 31 repositories' CI is permitted to execute. |

## Reporting a vulnerability

Email `journey4oflife+viavitae.security@gmail.com`. This is the address
[`policies/EMAIL_POLICY.md`](policies/EMAIL_POLICY.md) designates for security intake, and
it is a working mailbox — the organization's `security@viavitae.com` style addresses were
measured undeliverable and are being migrated off, so do not report to those.

**Please do not open a public issue.** This repository is public, and an issue describing
how to reach the organization's settings is a disclosure before a fix.

GitHub private vulnerability reporting is enabled here (measured 2026-11-03:
`gh api repos/Via-Vitae/viavitae-control/private-vulnerability-reporting` →
`{"enabled":true}`), so the *Security* tab form is an alternative route.

Tell us, in the report:

1. The affected file and line, or the resource address
   (`module.repo["viavitae-api"].github_repository.this`).
2. Which organization-wide control you believe is bypassed, and how.
3. Whether the finding depends on the CI credential, the operator credential, or a
   configuration that a `terraform apply` would push.
4. Steps to reproduce, at the level of reading a configuration — do not attempt a write,
   a mutation, or access to another repository's data to prove the point.

## Response timing, and what the 72 hours actually is

First response within **72 hours** of receipt. Be precise about why: GDPR Art. 33's 72-hour
notification clock starts when a breach is *established as a personal-data breach*, not when
this file was written and not for every security finding. Most reports against this
repository concern configuration and carry no personal data at all; for those the 72 hours
is our own triage target. Where a report does establish a personal-data breach, the clock and
the Art. 34 data-subject notification duty apply and the handling follows the breach workflow
in the organization's [`.github/SECURITY.md`](https://github.com/Via-Vitae/.github/blob/main/SECURITY.md).

## What is already hardened

The full list with each guard's exit contract is in
[`policies/README.md`](policies/README.md). The load-bearing ones for this file:

- `scripts/check_ci_credential.sh` — refuses a write-capable CI credential and proves every
  read the current configuration actually requires.
- `toolchain.yml` + `scripts/check_toolchain_pins.sh` — every `uses:` in
  `.github/workflows/` must reference a 40-character commit **and** the canonical commit
  recorded in the manifest; CI tool versions come from one place.
- `scripts/check_public_register.sh` + `scripts/reconcile_secret_register.sh` — keep the
  published secrets inventory free of identifiers while matching the confidential register.
- `.github/workflows/provenance.yml` — requires an `ai:<tier>` trailer on every PR. Stated
  honestly: as measured 2026-10-17 the `protect-main` ruleset listed no required status
  checks, so a failing provenance report was **advisory** — recorded, not blocking. It
  becomes a gate when the context is required in the ruleset (`repo_rulesets.tf` declares
  that; it lands on an apply the owner authorizes).

## Scope of this policy

This policy covers `Via-Vitae/viavitae-control` — the Via-Vitae organization only. The
sibling control planes govern different legal entities with separate credentials and
separate reporting routes; do not use this address for findings against them.
