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
| K4 | viavitae/github/ci-plan-pat | T1 | fine-grained PAT (id 21301575) | Via-Vitae | GitHub + Actions secret `TF_GITHUB_TOKEN` | 2027-01-15 | 90d | 2026-10-20 | 2-repo admin metadata (org grants removed 2026-10-20; F-04 closed by CI rerun attempt 2, "unused power" notice absent) | CC6.1 / A.8.2 | re-mint per runbook; revoke via UI |
| K3 | viavitae/github/drift-pat | T1 | fine-grained PAT | Via-Vitae | GitHub + Actions secret `ORG_READ_TOKEN` | 2027-01-15 | 90d | 2026-10-19 | org-wide private-repo read | CC6.1 / A.5.17 | re-mint; revoke via UI |
| B1b | (gh-managed, not in pass) | T1 | gh OAuth token (`gho_…`) | all-three (human) | `gh` keyring, account `JourneyOfLife` (active) | 2099-12-31 | manual | 2026-10-20 | same reach as B1 + `gist` (the only credential still carrying it); feeds `GITHUB_TOKEN` for laptop plan/apply | A.8.2 / CC6.2 | `gh auth refresh -h github.com --remove-scopes gist`; revoke via account settings |
| IV-1 | (gh-managed, not in pass) | T1 | gh OAuth token, account `IterVitae` | Via-Vitae (reviewer role) | `gh` keyring, second account (inactive) | never | on-role-change | 2026-10-20 | outside-collaborator repo access; **sole PR reviewer — RETAINED per F-05 verdict (2026-10-20)**, admin invite still pending | A.5.17 / CC6.2 | `gh auth logout -h github.com -u IterVitae` + revoke in that account's settings |
| AWS-1 | viavitae/aws/viavitae-terraform | T1 | IAM access keys | Via-Vitae | `~/.aws/credentials` | 2099-12-31 | 180d | 2026-10-19 | AWS account 775093708742 (S3 SCP-denied) | CC6.1 / A.5.17 | rotate in IAM console |
| AGE-1 | (raw file, not pass) | T0 | age X25519 identity `~/.config/age/state-backup-key.txt` | all-three | host filesystem, mode 0600 | never | on-compromise | 2026-10-17 | every encrypted backup + vault | A.8.24 / A.5.30 | sealed 2-of-2 envelopes (pending) |

`expires` semantics: an ISO date is a hard deadline the CI gate enforces. `2099-12-31`
is a **placeholder for "no server-side expiry"** — it is not a claim of safety; those
rows are the rotation backlog (F-06). `never` means the item is a root key, rotated
only on compromise. The gate treats `never`/`unknown` as findings to report, not passes.

> **2026-10-20 correction:** the register previously claimed B1 was named
> `terraform-control-plane` with `gist` and no expiry. Live measurement (classic-token
> page) shows the only classic PAT is `terraform-control-plane-v2`, **expiring
> 2026-10-27**, without `gist`; the `gist` scope belongs to the separate gh OAuth token
> (B1b). The lesson is the register's own rule: read a credential live, never from prose.
>
> **2026-10-20 retirement:** B1 (`terraform-control-plane-v2`) **deleted** by the owner
> after the consumer hunt found no automated use (only a name mention in two Obsidian
> notes and two `ghp_` lines in `~/.bash_history` echoing into `/tmp/test_secret.txt`
> and `/tmp/github_token.txt`). Both `/tmp` files are gone (boot cleanup) and the token
> is dead server-side, so the history lines are now harmless residue — purge with
> `sed -i '/ghp_/d' ~/.bash_history` when convenient. Interactive laptop auth rides the
> gh OAuth token (B1b), unaffected — verified post-deletion via `gh api user`.
> If a manual apply ever demands a classic PAT, re-mint per the runbook and add a row.

## Rules

1. One row per credential; file name = the account, not the service.
2. Adding a credential without adding its row is a review-checklist failure
   (AI_WORKFLOW_POLICY mandatory sign-off).
3. `expires` within 14 days ⇒ `check_secret_inventory.sh` fails CI ⇒ rotate per
   §7.8 of the architecture prompt, then update `last_verified` here.
4. The vault itself is backed up as a git bundle per
   [`state/README.md`](../state/README.md) — same cadence as state archives.
