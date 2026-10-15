# Email Address Segmentation Policy — Via-Vitae

## Purpose

Segregate inbound communication by role so that security reports, privacy
requests, billing notices, and day-to-day project email are independently
trackable, filterable, and auditable. This satisfies:

- **GDPR Art. 38(1)(a)** — DPO must be contactable by data subjects.
- **GDPR Art. 39(1)(d)** — DPO serves as contact point for the supervisory authority.
- **SOC 2 CC2.3** — the entity communicates responsibilities and procedures.
- **ISO 27001 A.16.1** — incident reporting channels must be defined.

## Address Scheme (current: Gmail plus-addressing)

All addresses are plus-addresses of a single Gmail account. Filters route each
stream to a dedicated label/folder. This is **Phase 1** of the migration plan.

| Role         | Address                                          | Used by                                    |
|--------------|--------------------------------------------------|--------------------------------------------|
| GitHub org   | `journey4oflife+viavitae.github@gmail.com`       | `billing_email` in Terraform; org owner    |
| Security     | `journey4oflife+viavitae.security@gmail.com`     | GitHub SECURITY.md; vulnerability reports  |
| Privacy/DPO  | `journey4oflife+viavitae.privacy@gmail.com`      | DPIA sign-off; Art. 15/17 data requests     |
| Billing      | `journey4oflife+viavitae.billing@gmail.com`      | GitHub invoices; payment-method alerts     |
| General/Dev  | `journey4oflife+viavitae.dev@gmail.com`          | Project correspondence (fallback)           |

## Published Channels On GitHub

The plus-addresses above are the **only** addresses the org publishes as live
contact channels. The table records which artifact carries which address, so a
reviewer can check each one against the role it is supposed to serve.

| Artifact | Address to use | Why this role |
|---|---|---|
| `orgs/Via-Vitae` profile email + `billing_email` (Terraform) | `+viavitae.github` | Org ownership and billing operations |
| `.github/SECURITY.md`, per-repo `SECURITY.md`, issue templates | `+viavitae.security` | Vulnerability intake and incident response |
| `.github/SUPPORT.md`, `docs/DPIA-template.md`, `CODE_OF_CONDUCT.md` privacy rows | `+viavitae.privacy` | GDPR Art. 12/13/15–17 data-subject requests |
| `LICENSE` contact block, `CODE_OF_CONDUCT.md` legal escalations | `+viavitae.billing` | Commercial and licensing correspondence |
| `README.md` general enquiries, `brand@`/`info@`/`support@` legacy strings | `+viavitae.dev` | Day-to-day project correspondence |
| cert-manager `cluster-issuer.yaml` ACME registration | `+viavitae.github` | Expiry notices are an ops responsibility |

### Why the domain addresses were removed

Every published `security@viavitae.com`, `dpo@viavitae.com` and
`legal@viavitae.com` string was **undeliverable** when this policy was last
measured, so a researcher or data subject following the published instructions
would have been reporting into a void:

| Domain | `dig` observation (2026-10-15) | Consequence |
|---|---|---|
| `viavitae.com` | no `NS` delegation, no `A`, no `MX` (resolver status `SERVFAIL`) | no mailbox can exist at this domain |
| `viavitae.site` | `NS` = `dns-parking.com`, `A` present, **no `MX`** | site resolves, mail bounces |
| `viavitae.eu` | `MX 0 localhost.` | mail is not delivered anywhere real |

A Gmail plus-address, by contrast, is delivered by the existing account and is
already routed by the filters in [`viavitae-gmail-filters.xml`](viavitae-gmail-filters.xml).
It is therefore the working channel **now**, and the custom-domain mailbox remains
Phase 2. The `+suffix` is preserved by Gmail, so each stream still lands under
its own label.

**Accepted trade-off (recorded, with an expiry condition):** publishing a
plus-address discloses the base handle `journey4oflife`, tying the charity's
contact points to a personal Gmail identity. This is accepted only while it is
the sole deliverable channel, and **expires when Phase 2 MX is live** — at that
point the published strings move to `security@viavitae.site` etc. and the
plus-addresses revert to internal use.

**PGP claims:** `SECURITY.md` previously pointed researchers at a key-server
entry for `security@viavitae.com`. No key exists for the plus-addressed
mailbox, so the encryption row must state that plainly rather than assert a key.
The remediation script rewrites that sentence; re-publish a PGP claim only after
a key is generated **and** its fingerprint is published out of band.

## Usage Rules

1. **Never hardcode** these addresses in `.tf` files as variable defaults.
   The Terraform `billing_email` variable has **no default** (GDPR Art. 5(1)(c),
   data minimisation). Supply the real value via `terraform.tfvars` (gitignored)
   or the `TF_VAR_billing_email` environment variable.

2. **Public repos** may reference this policy document and the address table
   for transparency (security/privacy contacts must be discoverable), and may
   carry the addresses in application config that is compiled and served to the
   public (e.g. `viavitae-web/lib/constants.ts`). They must **not** appear in
   Terraform variables, defaults, or anything that lands in `terraform.tfstate`,
   because state is not a public artifact and holds real values unencrypted.

3. **Gmail filters** must be configured to label each plus-address stream
   automatically. Without filters, plus-addressing provides no operational
   segregation.

   A ready-to-import filter set lives at
   [`viavitae-gmail-filters.xml`](viavitae-gmail-filters.xml). Import it in one
   action: Gmail → Settings → **Filters and Blocked Addresses** →
   **Import filters** → select the file → **Import filters**. The import also
   auto-creates the referenced `viavitae/*` labels, so no manual label setup is
   needed. This artifact contains only the plus-addresses already documented
   above (no secrets) and is safe to keep in the repo.

   The `mai:email="journey4oflife@gmail.com"` attribute in that file is the
   **one sanctioned place** the bare base address may be committed: Gmail
   refuses to import a filter archive whose account attribute does not match the
   signed-in account. It is an account identifier for a local import, not a
   published contact channel. Do not "fix" it during an email sweep.

4. **Append-only evidence is never rewritten.** `CHANGELOG.md` entries and ADRs
   (e.g. `viavitae-infra/docs/adr/ADR-000-governance-sole-owner-four-eyes.md`)
   record that the old addresses **were** undeliverable. Substituting the new
   value into that narrative falsifies the audit trail — it is the fix history of
   the finding being remediated. Add a dated entry forward instead.

5. **Placeholders and sample data are never rewritten.** `you@viavitae.com` in
   `CONTRIBUTING.md` is a DCO sign-off example for third-party contributors,
   and `*@demo.viavitae.com` / `*@test.viavitae.com` / `secretary@parish.lt` are
   fictional tenant fixtures. `@jolarca.*` belongs to a **different legal
   entity** and is out of scope for Via-Vitae policy.

6. **Remediation is scripted, not hand-edited.**
   [`../scripts/update_contact_emails.sh`](../scripts/update_contact_emails.sh)
   carries the address table, the exclusions above, an append-only path filter,
   a base-inbox leak gate and a residue gate. It defaults to dry-run; `--diff`
   prints the patch without committing; `--apply` opens one PR per repo and never
   pushes to `main`. Merging is **manual after a peer review** — this org has
   `allow_auto_merge=false`, so `gh pr merge --auto` is refused; use
   `gh pr merge <n> -R Via-Vitae/<repo> --squash`. Commits are authored with
   `+viavitae.github` so a DCO sign-off line does not re-publish the base inbox.

## Migration Plan (Phase 2 — custom-domain aliases)

When `viavitae.site` DNS + email routing is configured (target: Cloudflare
Email Routing, free tier), migrate the three **public-facing** roles:

| Role         | Phase 1 (current)                             | Phase 2 (target)              |
|--------------|-----------------------------------------------|-------------------------------|
| Security     | `journey4oflife+viavitae.security@gmail.com`  | `security@viavitae.site`      |
| Privacy/DPO  | `journey4oflife+viavitae.privacy@gmail.com`   | `privacy@viavitae.site`       |
| Billing      | `journey4oflife+viavitae.billing@gmail.com`   | `billing@viavitae.site`       |
| GitHub org   | (unchanged — internal credential)             | `viavitae.github@viavitae.site` or keep Gmail |
| General/Dev  | (unchanged — internal)                        | keep Gmail plus-address       |

Phase 2 removes the single-Gmail-compromise blast radius for external-facing
contact points while keeping operational overhead minimal (aliases forward to
the same inbox with routing rules at the DNS level).

The `security@` / `dpo@` / `legal@viavitae.*` strings that were published before
this policy are **retired in Phase 1**, not migrated: none of those domains had
an `MX` record, so they never received anything. Phase 2 re-introduces the same
role names as genuine mailboxes once `viavitae.site` MX is proven by a delivered
test message.

## Risk Accepted (Phase 1)

- All plus-addresses resolve to one Gmail account: compromise of that account
  exposes every stream simultaneously.
- Plus-addresses can be stripped by third-party email processors, breaking
  routing (mitigated by never relying on them for two-factor recovery).
- Audit optics: a personal Gmail alias as DPO contact is functional but
  informal for regulatory correspondence.

These risks are **accepted for now** because the org is a single-person
charity operation on GitHub Free. They are **remediated by Phase 2**.

## Verification

```bash
# No email addresses should appear in .tf source files:
grep -r "@gmail\|@viavitae" --include="*.tf" .
# (expected: zero matches)

# No email addresses in any committed terraform.tfvars:
# (terraform.tfvars is gitignored; if accidentally committed, this finds it)
git show HEAD:terraform.tfvars 2>/dev/null | grep "billing_email"

# Deliverability of the published domains must be re-measured, not assumed:
dig +short NS viavitae.com ; dig +short A viavitae.com ; dig +short MX viavitae.com
dig +short MX viavitae.site   # empty => Phase 2 (custom-domain mailboxes) is NOT live

# Org-wide surface still claiming a dead address (expect only excluded files):
./scripts/update_contact_emails.sh            # dry-run report, no writes
```

Phase 2 is reached when `viavitae.site` has an `MX` record **and** a test message
to `security@viavitae.site` is received in the routed mailbox. Until both are
observed, the plus-addresses remain the published channels and no email claim in
`SECURITY.md` may be marked `enforced-verified`.