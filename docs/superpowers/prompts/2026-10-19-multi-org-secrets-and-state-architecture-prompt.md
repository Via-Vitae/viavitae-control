# Multi-Org Secrets, Credentials and Terraform State Architecture — Reusable Prompt (v2)

| Field | Value |
| --- | --- |
| Created | 2026-10-19 |
| Revision | 2 — supersedes v1 of the same date (v1 preserved in git history) |
| Repo | viavitae-control |
| Type | Prompt asset (not a policy, not a plan — ungated by CI) |
| Scope | Via-Vitae, journeyoflife-org, jolarca-dev |
| Frameworks | SOC 2 Type II, ISO/IEC 27001:2022, GDPR, PCI-DSS 4.0 (jolarca only) |
| Operator model | Single owner, single programmer, no teams, no separation of duties |
| Baseline verified | 2026-10-19: three control-plane trees on host `jol`, host probes (`stat`, `age`, tooling, `dmsetup`), owner-account fine-grained PAT page (screenshot), org list page (screenshot) |

## What this file is

A copy-paste-ready prompt that asks a model to produce a compliance-grade architecture
opinion on four coupled questions: Terraform plane separation, GitHub credential
inventory, state backend selection, and where secrets actually live.

It exists because the naive version of this question ("Excel table? Dropbox + TrueCrypt?")
produces naive answers. This version pins the environment facts, forbids hedging, and
demands evidence — so the reply is decision-ready instead of a survey.

What v2 adds over v1:

- A **cross-surface credential reconciliation** demand: the fine-grained PAT list, the
  classic PAT list, the `gh` keyring, Actions secrets and HCP tokens are five different
  surfaces that partially overlap; the model must produce one matrix covering all of them.
- The **screenshot evidence** (five fine-grained PATs with expiry dates; all three orgs
  showing `2FA required`) pinned into the baseline, including the dormant
  `jolarca-control-tf-write-2026-10-17` write token ("Never used").
- An **expiry-cluster finding**: all five fine-grained PATs expire inside a ten-day
  window (2027-01-08 … 2027-01-17); the model must produce a staggered rotation calendar.
- A **plan-only execution gate**: no emitted runbook step may mutate state or live
  infrastructure without a printed human-approval gate.
- A corrected baseline line: both local state files are mode `0600` as of 2026-10-19
  (the v1 `0664` group-readable finding on jol-control is a *historical* finding).
- A **self-audit checklist** (§11 of the output contract): the model must map every
  numbered requirement to the section where it answered it.
- A **worked example** of the expected explanation depth, so "student-level" is
  demonstrable rather than asserted.

## How to use

a. Re-verify §4 against the live trees before sending (facts drift; see refresh commands).
b. Copy everything between the `~~~~` fences below.
c. Attach the two screenshots (fine-grained PAT page, org list page) if the channel
   supports images; otherwise their content is already transcribed into §4.6/§4.7.
d. Send to a model with tool/file access if available — §5 lets it self-correct stale facts.
e. If the model has no file access, run the refresh commands yourself and paste the output
   into §4 in place of the recorded values.

### Refresh commands

```bash
for d in /opt/viavitae/repos/viavitae-control /opt/jol/repos/jol-control /opt/jolarca/repos/jolarca-control; do
  printf '%-45s state=%-10s mode=%s\n' "$d" \
    "$(stat -c%s "$d/terraform.tfstate" 2>/dev/null || echo NA)" \
    "$(stat -c%a "$d/terraform.tfstate" 2>/dev/null || echo NA)"
done
ls -l ~/.config/age/
for b in age age-keygen gpg pass bw ykman keepassxc-cli; do printf '%-16s %s\n' "$b" "$(command -v $b || echo ABSENT)"; done
ls -t /opt/jol/backup/tfstate/ | head -5
dmsetup ls --target crypt
gh auth status
grep -n -A6 'cloud' /opt/jolarca/repos/jolarca-control/main.tf
```

---

## THE PROMPT

~~~~
# 1. ROLE AND STANCE

You are a paranoid, compliance-driven security and infrastructure architect with 30+
years of operational experience. You have personally cleaned up after credential leaks,
lost state files, and single-operator bus-factor incidents. You are retained to give a
binding professional opinion, not a survey of options.

Explain everything so that a competent student can follow it: assume the reader is
fluent with Linux and Terraform but has never designed a credential hierarchy. Every
paragraph of every answer must be decomposed into numbered steps and lettered
sub-paragraphs. Define every term at first use. Never skip a "why".

# 2. COMPLIANCE TARGETS

Map every recommendation onto these frameworks, citing the clause by name each time:

- **SOC 2 Type II** — Trust Services Criteria, especially CC6.1 (logical access),
  CC6.2 (registration/authorization), CC6.3 (access modification), CC6.6 (external
  threats), CC6.7 (transmission), CC7.2 (monitoring), CC9.2 (vendor risk), A1.2/A1.3
  (availability, backup and recovery).
- **ISO/IEC 27001:2022 Annex A** — especially A.5.15/A.5.16/A.5.17/A.5.18 (access
  control, identity management, authentication information, access rights), A.8.2
  (privileged access), A.8.4 (source code), A.8.5 (secure authentication), A.8.15
  (logging), A.8.24 (cryptography), A.5.30 (ICT continuity), A.5.34 (privacy/PII).
- **GDPR** — controller/processor separation per legal entity, Art. 5(1)(f) integrity
  and confidentiality, Art. 28 processor contracts, Art. 32 security of processing,
  Art. 44–50 international transfer, Art. 33/34 breach notification within 72 hours.
- **PCI-DSS 4.0** — applies to `jolarca-dev` only. Req. 3 (stored account data),
  Req. 7/8 (access control and authentication), Req. 10 (logging), Req. 12.10
  (incident response).

# 3. HARD CONSTRAINTS

1. **The operator is one human being.** There are no teams, no second approver, no
   on-call rotation, no separation of duties. Every control you propose that normally
   requires two people must be replaced by a *named compensating control* that one
   person can actually execute — or you must state explicitly that the control is
   unachievable and record the residual risk.
2. **Paranoia is the default.** Assume: the workstation disk fails without warning,
   the operator is incapacitated for 90 days, one GitHub PAT has already leaked into a
   public commit somewhere, Dropbox has been served a lawful-access request, and a
   free-tier vendor changes its terms with 30 days' notice.
3. **No hedging.** Never write "consider using", "you might want to", "one option is".
   Every question ends in a single verdict, a rationale, and an explicit rejection
   record for each alternative you discarded.
4. **Three legal entities are three controllers.** Via-Vitae is a commercial IT company.
   journeyoflife-org is a Catholic charity whose stated operating principle is
   "built and operated in-house on hardware it owns". jolarca-dev is a marketplace
   platform in PCI-DSS scope. Data from one must not transit or rest in infrastructure
   controlled by another. Treat cross-entity leakage as a reportable incident, not a
   tidy-up task.
5. **Plan-only execution authority.** Read-only and plan-only commands (`plan`, drift
   reads, `stat`, inventory probes) may appear freely in your runbooks. Any step that
   mutates live infrastructure or Terraform state — `apply`, `destroy`, `import`,
   `init -migrate-state`, secret rotation writes, scope edits — must carry a printed
   gate line: `STOP — human approval required before this step`. A runbook without
   gates on mutating steps is a contract violation.
6. **Provenance and plan-as-contract.** Any commit produced from your advice must carry
   the tier-provenance prefix required by the operator's AI workflow policy (e.g.
   `ai:top`), and the written plan is a contract: if execution deviates from it, work
   halts for review instead of improvising. Design your runbooks so each step is
   individually committable and reversible.
7. **Halt on destroy/replace.** Any recommendation whose execution would produce a
   `terraform destroy` or a resource `replace` must stop at the plan output and escalate
   to the human, with the blast radius stated.

# 4. VERIFIED ENVIRONMENT BASELINE (2026-10-19, host `jol`, Ubuntu 24.04)

Correct any line below that the live tree contradicts, and say so loudly. Do not silently
accept a stale fact. Facts marked SCREENSHOT were read from owner-account UI screenshots
taken 2026-10-19; treat them as point-in-time truth, not as live API responses.

## 4.1 Control planes

| GitHub org | Legal entity | Control-plane repo | Local path |
| --- | --- | --- | --- |
| `Via-Vitae` | Commercial IT company | viavitae-control | `/opt/viavitae/repos/viavitae-control` |
| `journeyoflife-org` | Catholic charity, owns its hardware | jol-control | `/opt/jol/repos/jol-control` |
| `jolarca-dev` | Marketplace platform, PCI-DSS 4.0 | jolarca-control | `/opt/jolarca/repos/jolarca-control` |

## 4.2 Terraform state

| Plane | Backend | `terraform.tfstate` on disk | Mode | Notes |
| --- | --- | --- | --- | --- |
| viavitae-control | **local** | 179,004 bytes | 0600 | Git-ignored; committed-adjacent risk |
| jol-control | **local** | 195,121 bytes | 0600 | Was 0664 group-readable; remediated to 0600 by 2026-10-19 — historical finding, verify before re-reporting |
| jolarca-control | **HCP Terraform** | 0 bytes | n/a | `cloud` block: organization `jolarca-dev`, workspace name `jolarca-control`; workspace id `ws-w6NSnTXXmYgh78Su`, org id `org-3zNQFys8XA3HNPCF`; free tier (<500 resources); accepted in ADR-0006 which explicitly rejected "S3 + DynamoDB". A stale 67 KB serial-151 local snapshot previously existed as a stray-read risk. |

## 4.3 Existing secret protection

- `age` identity at `~/.config/age/state-backup-key.txt`, mode `0600`, 189 bytes.
- Encrypted archives written to `/opt/jol/backup/tfstate/` as
  `<project>-terraform.tfstate.<YYYYMMDDTHHMMSSZ>.age` under `umask 077`.
- Recipient derived via `age-keygen -y` from the same identity; restore is
  `age -d -i ~/.config/age/state-backup-key.txt <archive>`.
- Restorability proven by `sha256sum` round-trip against the live state.
- Newest archives at verification time: viavitae 2026-10-17, jol 2026-10-13; jolarca has
  none by design (state lives in HCP). No written backup cadence control exists.
- **Known gap:** the backup directory shares the same physical NVMe disk as the state.
  This protects against accidental deletion and corruption, **not** against disk failure.
- **Known gap:** `dm-crypt` returns 0 devices — no full-disk encryption is active, yet
  compliance documentation has previously claimed at-rest encryption. Treat that claim
  as false until proven otherwise.

## 4.4 Tooling

- **Present:** `age`, `age-keygen`, `gpg`, `gh`, `terraform`.
- **Absent:** `pass`, `bw` (Bitwarden CLI), `ykman` (YubiKey Manager), `keepassxc-cli`.
- No hardware security key is currently enrolled.

## 4.5 AWS

- Exactly one account: `<aws-account-id>` ("Happy Path", ~$100 free-tier credits).
- It is a member of an AWS Organization (management account `376896792604`) whose
  **Service Control Policy places an explicit deny on S3** (`p-r9i2lq77`).
  An SCP explicit deny overrides any IAM allow — no bucket can be created by this
  account regardless of its own policies.
- IAM user `viavitae-terraform` exists in that account.
- Resolution paths: management-account carve-out, org admin creates the bucket, or a
  separate AWS account outside the Organization.

## 4.6 GitHub credentials — five surfaces, only partially overlapping

**Surface A — fine-grained PATs on the owner account (SCREENSHOT, 2026-10-19):**

| # | Name | Last used | Expires |
| --- | --- | --- | --- |
| A1 | `jol-control-drift-read` | within last week | Sun, 17 Jan 2027 |
| A2 | `jolarca-control-tf-write-2026-10-17` | **Never used** | Fri, 15 Jan 2027 |
| A3 | `viavitae-control-drift` | within last week | Fri, 15 Jan 2027 |
| A4 | `viavitae-control-ci-plan` | within last week | Fri, 15 Jan 2027 |
| A5 | `jolarca-dev` | within last week | Fri, 8 Jan 2027 |

**Surface B — classic PATs / keyring (earlier verification, re-verify):**

| # | Name | Kind | Where it lives | Scopes |
| --- | --- | --- | --- | --- |
| B1 | `terraform-control-plane` | Classic PAT | `gh` CLI keyring, account `JourneyOfLife` (must be the active account) | `admin:org`, `repo`, `workflow`, `read:user`, `user:email` |
| B2 | `IterVitae` account token | Classic PAT | `gh` CLI keyring, second account — non-member outside collaborator | `gist`, `read:org`, `repo`, `workflow` — insufficient for org settings |

**Surface C — machine secrets with write-only visibility:**

| # | Name | Where it lives | Backed by |
| --- | --- | --- | --- |
| C1 | `TF_GITHUB_TOKEN` | viavitae-control Actions secret | fine-grained PAT `viavitae-control-ci-plan` (token id <pat-id>); must hold **zero** Organization permissions — org grants are unused power and the CI gate prints a notice if present; correct end state is `Repositories 2` only |
| C2 | `ORG_READ_TOKEN` | viavitae-control Actions secret | fine-grained PAT, read-only; consumed by `detect_drift.sh` and `assert_live_controls.sh` |
| C3 | `GITHUB_TOKEN` | jol-control | classic PAT with `admin:org`, `repo`, `write:org`, `admin:repo_hook` |
| C4 | `TFC_TOKEN` + repo PAT | jolarca-control | HCP Terraform workspace access plus repo admin |

GitHub Actions secrets are write-only through the API and the org PAT inventory endpoint
returns 404 — CI behaviour is the only observable surface for C1/C2. The screenshot of
Surface A does **not** show the classic-token section; it is not a complete inventory.

## 4.7 Org posture (SCREENSHOT, 2026-10-19)

All three orgs (`jolarca-dev`, `journeyoflife-org`, `Via-Vitae`) list the operator as
**Owner** and display the **`2FA required`** badge. Earlier findings registers recorded
org-wide 2FA as unenforced for at least one org; the badge now contradicts that. Verify
per org via API before treating either statement as current.

## 4.8 Isolation model

`jolarca-control/docs/security/isolation-model.md` defines **boundary 1**: no shared
membership, tokens, secrets, CI configuration, or Terraform state between the orgs. It
is a structural boundary, not a naming convention. It currently covers the
`jolarca-dev` ↔ `journeyoflife-org` pair but **not** the pairings involving Via-Vitae.
That is a documented, open gap.

# 5. VERIFICATION CONTRACT

Before answering:

1. Read the three control-plane trees and confirm or correct every row above.
2. State, per fact: `CONFIRMED`, `STALE — actual value is X`, `CANNOT VERIFY — reason`,
   or `SCREENSHOT-ONLY — not re-checkable from the shell`.
3. If a fact in §4 is contradicted, **halt and report the contradiction** before
   continuing. Do not build a recommendation on a fact you know to be false.
4. Never invent a token id, workspace id, ARN, SCP id, serial number, file size, or
   policy name that is not in the baseline or in a file you actually read.
5. Reconcile Surfaces A, B and C into one credential set: for every Surface A token name
   the exact consumer (which CI secret, which local command, which plane), and for every
   Surface B/C entry whether it duplicates a Surface A token. Unexplained overlap or
   orphans are findings, not footnotes.

# 6. QUESTION 1 — Three Terraform control planes

The premise is that three separate Terraform configurations are required. Give your
professional opinion: is three the correct number, and is the *current* separation real
or cosmetic?

Answer must cover:

- **1.1 Legal justification.** Map each plane to its controller/entity and explain why
  a single merged plane would violate boundary 1, GDPR Art. 5(1)(f), and ISO A.5.34.
- **1.2 What separation actually requires.** Separate state, separate credentials,
  separate CI identity, separate backend, separate drift detection. For each, state
  whether it is achieved today, per plane, in a table.
- **1.3 Shared-code risk.** All three planes are structurally similar. Advise precisely
  on the module-sharing question: what may be copied, what may be a shared module, and
  what must never be shared. Address the supply-chain consequence of a shared module
  registry.
- **1.4 The Via-Vitae gap.** Boundary 1 does not cover the Via-Vitae pairings. Give the
  remediation as a numbered sequence with the exact files to change.
- **1.5 Verdict.** Three planes: correct or not. If correct, state what must change for
  the separation to stop being a naming convention.

# 7. QUESTION 2 — The GitHub credential set

Give your professional opinion on the credential inventory and its hygiene. The naive
reading is "five tokens"; the baseline shows five fine-grained PATs *plus* classic PATs
*plus* CI-injected secrets *plus* an HCP token. Answer against the reconciled set.

Answer must cover:

- **7.1 Full credential matrix.** One row per reconciled credential, with exactly these
  columns: `ID | surface | name | entity/org | type | permissions granted | permissions
  evidenced as used | storage location (exact) | consumer (command or CI step that reads
  it) | expiry | rotation interval | blast radius if leaked | revocation command |
  compensating control today`. A matrix missing columns is a contract violation.
- **7.2 The dormant write token.** `jolarca-control-tf-write-2026-10-17` (A2) is a
  write-scoped token that has never been used. Verdict: revoke, or wire it to a named
  consumer with a reason it must exist. A dormant write credential is latent blast
  radius; say which control clause it offends while it sits unused.
- **7.3 Unused power.** Where granted scopes exceed used scopes, name the excess and
  give the exact narrowing steps. Note that editing fine-grained PAT permissions
  preserves the token string, so Actions secrets do not need re-pasting; note the two UI
  traps (keep `Repositories 2`; press the bottom Update under Permissions).
- **7.4 Classic vs fine-grained.** B1 and C3 are classic PATs with `admin:org`. Give a
  migration verdict per credential, with the order of operations and the rollback if a
  migration breaks CI.
- **7.5 Scope minimality.** Assess `admin:org` and `admin:repo_hook` on C3 against least
  privilege. State whether the charity plane can run on narrower scopes.
- **7.6 The `IterVitae` account (B2).** Retire, retain, or narrow — with reasoning.
- **7.7 Expiry calendar and staggered rotation.** All five Surface A tokens expire
  inside 2027-01-08 … 2027-01-17. Produce a dated calendar table for every credential,
  flag the ten-day cluster as a single-point-of-failure window (one distracted week =
  five expired credentials across three entities), and give a staggered schedule so that
  at most one credential per entity expires in any seven-day window, plus the reminder
  mechanism one person will actually keep.
- **7.8 Rotation and revocation.** A one-operator rotation procedure runnable in under
  30 minutes per credential, plus the emergency-revocation path when a token is found in
  a public commit (include the push-protection and secret-scanning interaction, and note
  that secret-scanning visibility is coupled to plan tier on GitHub Free).
- **7.9 Verdict.** Is the reconciled count the right number? If not, state the target
  count and the consolidation path.

# 8. QUESTION 3 — AWS S3 and the state backend

The premise is that each project needs its own separate S3 bucket. Give your
professional opinion.

Answer must cover:

- **8.1 Feasibility today.** Explain, at student level, the SCP permission algebra:
  why an explicit deny in a Service Control Policy beats an allow in an IAM policy,
  and what that means for account `<aws-account-id>`. Give the three resolution paths and
  the effort/risk of each, with the carve-out request written out as copy-pasteable
  text for the org administrator.
- **8.2 Should S3 be the answer at all.** jolarca's ADR-0006 already rejected
  "S3 + DynamoDB" in favour of HCP Terraform. State whether that decision still holds
  for all three planes, per plane.
- **8.3 Data residency, per entity.** The charity's principle is in-house operation on
  hardware it owns. Assess HCP Terraform's US free tier against that principle and
  against GDPR Art. 44–50. Assess a self-hosted HTTP backend on charity-owned hardware
  as the alternative — including its locking, availability, and backup obligations.
- **8.4 Decision matrix.** Rows: local state, S3 (post-SCP-carve-out), HCP Terraform
  per org, self-hosted HTTP backend, git-crypt-committed state. Columns: encryption at
  rest, state locking, off-host durability, residency compliance, cost, solo-operator
  burden, PCI-DSS acceptability, auditability, **who owns the encryption key**, **where
  the key physically rests**. One verdict per plane.
- **8.5 Separation requirement.** If S3 or HCP is used, specify the exact isolation
  per entity: separate bucket/workspace, separate encryption key, separate IAM role or
  HCP org, no cross-account bucket policy, versioning, S3 Object Lock or equivalent,
  Public Access Block at every level, `use_lockfile` where applicable.
- **8.6 Backup cadence for hosted state.** jolarca has no local archive by design.
  State what backs up HCP-hosted state, how state version retention on the free tier is
  *verified* (not assumed), and the cadence control that would have caught a silent
  backup failure.
- **8.7 Migration runbook.** If a plane must move, give it as numbered gates:
  authorisation, baseline state hash, capability probe, destination build, role-based
  identity, `terraform init -migrate-state` with lineage preservation (gated per §3.5),
  equivalence diff, stray-file cleanup, offline restore rehearsal, and control-register
  bookkeeping. Include the specific hazard of `terraform init -backend=false` in CI
  masking a create-heavy plan against empty state.
- **8.8 Verdict.** One sentence per plane.

# 9. QUESTION 4 — Where tokens and passwords are stored

The proposal on the table is an Excel table (or similar) kept in Dropbox, inside a
TrueCrypt container. Give your professional opinion.

Answer must cover:

- **9.1 Secret classification first.** Define a tiering scheme before choosing a tool.
  At minimum: Tier 0 root-of-trust material (the `age` identity, AWS root credentials,
  2FA recovery codes, HCP org recovery), Tier 1 long-lived human credentials (PATs,
  `TFC_TOKEN`), Tier 2 machine secrets injected into CI (GitHub Actions secrets),
  Tier 3 application/runtime secrets. For each tier state: who reads it, how often,
  what encrypts it, where the ciphertext lives, where the key lives, and what breaks
  if it is lost.
- **9.2 Why the Excel + Dropbox + TrueCrypt proposal fails.** Name the specific control
  failures, each mapped to a framework clause. Address at minimum: TrueCrypt's 2014
  abandonment by its own authors and its unaudited current state; the single-container
  blast radius (one leaked file = every secret); absence of per-item access control,
  audit log, rotation metadata, and expiry tracking; spreadsheet integrity and version
  history as a disclosure channel; Dropbox as a US processor with lawful-access
  exposure and no residency guarantee for a charity controller; plaintext leakage via
  Excel autosave, temp files, recent-documents lists, and thumbnail caches; and the
  fact that an encrypted container synchronised to a third party still leaks metadata
  (existence, size, modification time, access pattern).
- **9.3 Scored comparison.** Compare at minimum: the existing `age`-encrypted file
  pattern; `pass` (age/gpg-backed, Unix, git-versionable); KeePassXC (local, offline,
  KDBX); Bitwarden or Vaultwarden (self-hosted and cloud); a hardware security key
  (FIDO2/PIV) for the root-of-trust tier; GitHub-native Actions secrets for Tier 2;
  and HCP Vault or AWS Secrets Manager for Tier 3. Score each against: encryption
  strength and auditability, offline survivability, single-operator usability,
  granular access control, rotation and expiry tracking, breach detectability,
  GDPR/residency posture, PCI-DSS acceptability, recovery if the operator is
  incapacitated, and cost. Produce a scored table, not prose.
- **9.4 Verdict and target architecture.** One recommended design, expressed as a
  concrete layout: which tool holds which tier, what encrypts it, where the ciphertext
  and the key each live, and how the three entities stay separated inside it. Reuse the
  `age` pattern already running for state backups unless you can justify discarding it.
  Deliver a copy-pasteable bootstrap script that uses only tools present on the host
  (§4.4); any tool not present must come with its install command and provenance.
- **9.5 Single-owner recoverability.** This is the constraint that decides the design.
  Address explicitly: total workstation loss; loss of the `age` identity; operator
  incapacitation for 90 days; and the brain-wallet problem (secrets that exist only in
  one person's memory). Recommend a sealed-break-glass mechanism — e.g. a shamir-split
  or physically-sealed recovery envelope — and specify where it is stored, who can open
  it, how its integrity is proven without revealing contents, and the dated annual
  rehearsal that proves it still opens.
- **9.6 Inventory, not a spreadsheet.** The operator asked for "an Excel table or
  something similar". Answer the real need: a *secret inventory* that records metadata
  (identifier, tier, owner entity, creation date, expiry, rotation interval, storage
  location, blast radius, linked control ID) **without ever recording the secret value**.
  Give the exact schema as a concrete file (format, column headers, and three sample
  rows — one per entity), state where the inventory itself lives, and argue whether
  storing that metadata unencrypted is acceptable, per clause.
- **9.7 Rotation calendar.** Cross-reference §7.7; state the maximum lifetime per tier
  and the trigger conditions for out-of-band rotation.
- **9.8 Verdict.** One sentence, no ambiguity.

# 10. OUTPUT CONTRACT

Structure the entire reply as follows. Do not deviate.

- **§0 Verification results.** The CONFIRMED / STALE / CANNOT VERIFY / SCREENSHOT-ONLY
  table from the verification contract, including the Surface A/B/C reconciliation.
- **§1 Executive verdict.** Ten lines maximum. The four answers, one line each, plus
  the three highest-risk findings.
- **§2 Question 1** … **§5 Question 4.** Each answer follows its sub-numbering above.
  Every paragraph that makes a claim must be broken into lettered or numbered
  sub-points. Each step must be executable: name the file, the command, or the UI path.
  Mutating steps carry the §3.5 gate line.
- **§6 Control mapping table.** Columns: framework clause (SOC 2 / ISO 27001 Annex A /
  GDPR / PCI-DSS) → implemented control → which question it came from → evidence
  artifact that proves it → current status (implemented / gap / compensating).
- **§7 Findings register.** Each finding gets: an ID, severity, the entity affected,
  root cause, the compensating control in place today, remediation, and effort estimate.
- **§8 Ordered remediation roadmap.** Sequenced for one person working part-time on
  this. Mark which items are prerequisites for others. Give a realistic sequence, not
  a parallel fantasy.
- **§9 What I could not determine.** Explicit list. This section may not be empty and
  may not be omitted.
- **§10 Residual risk accepted.** What remains unmitigated after the full roadmap, and
  why that is tolerable for a single-operator charity and a free-tier commercial entity.
- **§11 Self-audit checklist.** A table with one row per numbered sub-requirement in
  §6–§9 of this prompt (1.1 … 4.8 plus the formatting rules), columns:
  `requirement | section of your reply that answers it | verdict given (yes/no)`.
  Every row must be filled. An unfilled row is a contract violation.

Formatting rules:

- Define every acronym and technical term at first use.
- Prefer a table over a paragraph wherever there are three or more comparable items.
- Every command must be copy-pasteable and must state the directory it runs from.
- Every "should" must be accompanied by the clause it satisfies.
- Length is not a virtue. Completeness and correctness are.

**WORKED EXAMPLE of the expected depth** (illustrative form only, not a recommendation):

> 9.2.c Excel autosave writes a plaintext shadow copy of the open workbook outside the
> encrypted container.
> c.1. Mechanism: while the workbook is open, the application writes `~$<name>.xlsx`
> and temporary files into the unencrypted profile directory, not into the container.
> c.2. Control failure: the ciphertext boundary you paid for is bypassed by the
> application layer — ISO A.8.24 (cryptography applied where the data actually rests)
> and SOC CC6.1 (logical access to the plaintext copy).
> c.3. Verify on this host: `find ~ -name '~$*.xlsx' -o -name '*.tmp' 2>/dev/null | head`
> (run from `$HOME`; an empty result proves absence today, not absence tomorrow).
> c.4. Rejection consequence: any spreadsheet-based store is rejected regardless of
> what encrypts the file, because the tool itself leaks outside the container.

# 11. STOP CONDITIONS

Halt and report instead of answering if:

1. A baseline fact is contradicted by the live tree and the contradiction changes the
   recommendation.
2. You are asked to invent a credential, identifier, ARN, or policy that you have not
   read.
3. A recommendation would require a second human being to operate. Say so, and propose
   the compensating control instead.
4. A recommendation depends on a paid tier, a vendor contract, or an AWS Organizations
   change the operator does not control. Flag the dependency before the recommendation.
5. The correct answer is "do not do this" — say it plainly rather than softening it.
6. Two frameworks conflict (e.g. PCI-DSS logging retention vs GDPR data minimisation).
   Surface the conflict and resolve it explicitly; do not silently pick one.
7. You cannot determine something. Write it into §9 of the output. Never fill the gap
   with a plausible guess.
8. A step you are about to emit mutates state or live infrastructure and lacks the
   §3.5 approval gate. Halt, add the gate, continue.
9. Treating the Surface A screenshot as the complete credential inventory would change
   a verdict. The classic-token and CI surfaces exist; reconcile first (§5.5).

# 12. ANTI-PATTERNS — reject these in your own output

- Recommending a secrets manager without stating where its *own* master key lives.
- Proposing a design whose recovery path assumes the operator is conscious and present.
- Answering "use S3" without addressing the SCP explicit deny.
- Answering "keep the planes separate" without an evidence table showing they are.
- Citing a framework clause without naming the clause.
- Presenting a comparison with no verdict.
- Claiming encryption at rest without verifying it (the `dm-crypt` 0-devices finding is
  the cautionary example).
- Recommending a tool absent from the host without giving the install command and its
  provenance.
- Treating "no team" as a reason to weaken controls rather than to add compensating ones.
- Treating the fine-grained PAT screenshot as the whole inventory while classic PATs
  with `admin:org` sit in the keyring.
- Proposing a rotation plan that keeps all expiries inside one ten-day window.
- Re-reporting the jol state file as group-readable without re-running `stat` first.
- Emitting an `apply`/`destroy`/`migrate` step without the printed human-approval gate.
~~~~

---

## Provenance

Baseline facts recorded from:

- `/opt/viavitae/repos/viavitae-control` — `provider.tf`, `README.md`, `state/README.md`,
  `.github/workflows/audit.yml`, `scripts/check_ci_credential.sh`, `scripts/detect_drift.sh`
- `/opt/jol/repos/jol-control` — `main.tf`, `terraform.tfstate`, `docs/architecture.md`
- `/opt/jolarca/repos/jolarca-control` — `main.tf` (`cloud` block),
  `docs/adr/0006-remote-state-backend.md`, `docs/security/isolation-model.md`
- Host inspection on 2026-10-19 (revision 2): `stat -c%s/-c%a` on the three state files
  (179004/600, 195121/600, 0/600), `~/.config/age/` listing, `command -v` tooling probe,
  `ls -t /opt/jol/backup/tfstate/`, `dmsetup ls --target crypt` (empty)
- Owner-account screenshots, 2026-10-19: fine-grained PAT page (five tokens, names,
  last-used, expiry dates) and org list page (three orgs, Owner, `2FA required` badges)

Revision history:

- v1 (2026-10-19): initial prompt asset.
- v2 (2026-10-19): screenshot evidence pinned; cross-surface reconciliation (§5.5, §7.1);
  dormant write-token verdict (§7.2); expiry-cluster calendar (§7.7); plan-only gate and
  provenance constraints (§3.5–§3.7); state-file mode correction (§4.2); backup-cadence
  question (§8.6); bootstrap-script and inventory-file deliverables (§9.4, §9.6);
  self-audit checklist (§11 of output contract); worked example; three new anti-patterns.

Related artifacts: [COMPLIANCE.md](../../COMPLIANCE.md) ·
[AUDIT_PROMPT.md](../../../policies/AUDIT_PROMPT.md) ·
[AI_WORKFLOW_POLICY.md](../../../policies/AI_WORKFLOW_POLICY.md)
