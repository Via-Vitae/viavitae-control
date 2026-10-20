# Secret inventory — Via-Vitae plane

| Field | Value |
| --- | --- |
| Entity | Via-Vitae (commercial IT company, org `Via-Vitae`) |
| Type | Metadata register. **Never record a secret value here** — values live in `~/.password-store/viavitae/` (age-encrypted) or the GitHub Actions secret store. |
| Consumed by | `scripts/check_secret_inventory.sh` (CI expiry gate in `.github/workflows/audit.yml`) |
| Framework basis | ISO 27001:2022 A.5.17 (authentication information), A.8.2 (privileged access), A.5.18 (access rights); SOC 2 CC6.1/CC6.2/CC6.3; GDPR Art. 5(1)(f), Art. 32 |
| Sibling registers | `jol-control` and `jolarca-control` keep their own copies of this file — **boundary 1**: no cross-entity rows, no merged register. Pattern source: `jolarca-control/docs/security/key-custody.md`. |

Storing this metadata unencrypted in a private repo is an accepted risk: it names
credentials an attacker could already enumerate only after compromising the account,
and the register's availability is itself a control (A.5.30). It must never contain
values, token strings, URLs with embedded secrets, or the age identity.

## Register

Columns: `secret_id | vault_path (pass) | tier | type | entity | storage_location | expires | rotation | last_verified | blast_radius | control_id | recovery_path`

| secret_id | vault_path | tier | type | entity | storage_location | expires | rotation | last_verified | blast_radius | control_id | recovery_path |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| K4 | viavitae/github/ci-plan-pat | T1 | fine-grained PAT (id 21301575) | Via-Vitae | GitHub + Actions secret `TF_GITHUB_TOKEN` | 2027-01-15 | 90d | 2026-10-19 | org member lists + 2-repo admin metadata (until F-04 de-grant) | CC6.1 / A.8.2 | re-mint per runbook; revoke via UI |
| K3 | viavitae/github/drift-pat | T1 | fine-grained PAT | Via-Vitae | GitHub + Actions secret `ORG_READ_TOKEN` | 2027-01-15 | 90d | 2026-10-19 | org-wide private-repo read | CC6.1 / A.5.17 | re-mint; revoke via UI |
| B1 | viavitae/github/terraform-control-plane | T1 | classic PAT | all-three (human) | `gh` keyring (account `JourneyOfLife`) | 2099-12-31 | manual | 2026-10-19 | org admin on all three controllers | A.8.2 / CC6.2 | UI revoke + invalidate sessions |
| AWS-1 | viavitae/aws/viavitae-terraform | T1 | IAM access keys | Via-Vitae | `~/.aws/credentials` | 2099-12-31 | 180d | 2026-10-19 | AWS account 775093708742 (S3 SCP-denied) | CC6.1 / A.5.17 | rotate in IAM console |
| AGE-1 | (raw file, not pass) | T0 | age X25519 identity `~/.config/age/state-backup-key.txt` | all-three | host filesystem, mode 0600 | never | on-compromise | 2026-10-17 | every encrypted backup + vault | A.8.24 / A.5.30 | sealed 2-of-2 envelopes (pending) |

`expires` semantics: an ISO date is a hard deadline the CI gate enforces. `2099-12-31`
is a **placeholder for "no server-side expiry"** — it is not a claim of safety; those
rows are the rotation backlog (F-06). `never` means the item is a root key, rotated
only on compromise. The gate treats `never`/`unknown` as findings to report, not passes.

## Rules

1. One row per credential; file name = the account, not the service.
2. Adding a credential without adding its row is a review-checklist failure
   (AI_WORKFLOW_POLICY mandatory sign-off).
3. `expires` within 14 days ⇒ `check_secret_inventory.sh` fails CI ⇒ rotate per
   §7.8 of the architecture prompt, then update `last_verified` here.
4. The vault itself is backed up as a git bundle per
   [`state/README.md`](../state/README.md) — same cadence as state archives.
