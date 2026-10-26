# Secret inventory — Via-Vitae plane (public expiry twin)

| Field | Value |
| --- | --- |
| Entity | Via-Vitae (commercial IT company, org `Via-Vitae`) |
| Classification | PUBLIC — this repository is published on GitHub. Treat every byte below as readable by anyone, permanently. |
| Owner / Approver | Sole operator of the Via-Vitae plane (identity recorded in the confidential register, not here — naming the holder in a public file is itself a finding) |
| Version | 2.0 (2026-10-26) — the full custody register used to live here; it moved. See §Why two files. |
| Next review | 2027-01-15, aligned to the earliest date in the table below |
| Authoritative source | `Via-Vitae/viavitae-compliance` (private) → `docs/security/SECRETS_INVENTORY.md`. Values here are **derived**; never edit a date here without editing the register. |
| Consumed by | `scripts/check_secret_inventory.sh` (offline expiry gate in `.github/workflows/audit.yml`) and `scripts/check_public_register.sh` (offline anti-leak gate) |
| Framework basis | ISO 27001:2022 A.5.17, A.8.2, A.8.24; SOC 2 CC6.1/CC6.2; GDPR Art. 5(1)(c) data minimisation, Art. 5(1)(f), Art. 32 |

## Why two files

A secret register is audit evidence: it names credentials, says where each one is
stored, who can use it and what breaks if it leaks. For years this file was that
register while sitting in a **public** repository, and its own accepted-risk paragraph
asserted the opposite ("storing this metadata in a private repo"). Both halves cannot be
true, and the false half was the justification.

The split keeps the two jobs that were fighting each other:

- **Confidential register** (private repo): every column — vault path, type, owner,
  consumers, blast radius, control id, recovery path, backup media, revocation evidence.
  This is what an auditor is handed.
- **Public expiry twin** (this file): only what a CI gate needs to decide "is a dated
  credential about to expire", which is an opaque key and a date. Nothing else.

## Accepted risk, stated correctly

Exposing *this* file publicly is an accepted risk because it contains no identifying
metadata: an outsider learning that a key called `K4` expires on 2027-01-15 learns
nothing about which service it opens, where it is stored, or what it reaches. The
accepted residual risk is that the register's *existence and shape* are public (how many
dated credentials there are, and when the next rotation window lands) — a timing hint for
an attacker, judged proportionate to the benefit of having the check run in public CI
without a credential.

The confidential register is **never** stored in this repository, not even as a copy, a
draft, or a rename. `.private/` is git-ignored as the staging area for the file that
belongs to the private repo, and `scripts/check_public_register.sh` fails CI if anything
identifier-shaped appears in this file.

## Machine contract (read before editing)

1. The table below is the **only** table in this file that may contain an `expires`
   header, and it must be the **last** table: the gate parses every `|`-row after that
   header, so a second table further down is silently mis-read or crashes the gate.
2. Exactly two columns: `secret_id`, `expires`. Adding a column here re-publishes the
   metadata you just removed.
3. `secret_id` is the primary key and must exist in the confidential register.
   `reconcile_secret_register.sh` proves the two sets agree.
4. `expires` is one of: an ISO `YYYY-MM-DD` hard deadline (CI-enforced), `2099-12-31`
   (no server-side expiry — a rotation backlog item, **not** a safety claim), `never`
   (root key, rotated only on compromise), or `unknown` (nobody has measured it).
5. `never`, `unknown` and `2099-*` are reported as notice/warning/error respectively and
   are **never** counted as passes.

## Register (derived — edit the private register instead)

| secret_id | expires |
| --- | --- |
| K4 | 2027-01-15 |
| K3 | 2027-01-15 |
| B1b | 2099-12-31 |
| IV-1 | never |
| ID-1 | never |
| AWS-1 | 2099-12-31 |
| AGE-1 | never |

## Rules

1. One row per credential, mirroring one row in the confidential register; the row is
   added to **both** files or the change is not finished (AI_WORKFLOW_POLICY sign-off).
2. A date here that disagrees with the register is a documentation defect even when CI is
   green — `reconcile_secret_register.sh` is the check that says so.
3. `expires` within 14 days ⇒ `check_secret_inventory.sh` exits 1 ⇒ the advisory `Audit`
   job goes red. **Advisory means it does not block the merge:** the live `protect-main`
   ruleset requires only the `provenance` context. Treat a red `Audit` on `main` as a
   defect to fix before the next change, not as a warning you may walk past.
4. Rotate per §7.8 of
   `docs/superpowers/prompts/2026-10-19-multi-org-secrets-and-state-architecture-prompt.md`,
   then update `last_verified` in the confidential register and re-derive this table.
5. The `2099-*`, `never` and `unknown` rows are the rotation backlog; they cannot be
   enforced by date, only by the rotation policy applied to the confidential register.
