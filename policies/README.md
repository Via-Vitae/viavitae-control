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
| `EMAIL_POLICY.md` | Role-based email address segmentation + migration plan; ships `viavitae-gmail-filters.xml` (bulk Gmail filter import) | Free+ | document + tfvars convention |

## Why scripts and not resources?

The `integrations/github` provider does not expose a resource for SAML SSO
enforcement, and org-wide two-factor enforcement is a distinct API call. Rather
than pretend these are declarative, we implement them as reviewed scripts, gate
them by `var.enable_sso` / plan tier, and record the residual gap in
`docs/COMPLIANCE.md`. This keeps the control plane honest under audit.

All scripts default to **dry-run**; pass `--apply` to make changes. Before using the write
mode of `update_contact_emails.sh`, run `scripts/test_contact_email_gates.sh` (14
assertions over the gates) and `scripts/update_contact_emails.sh --check-residue`, which
rehearses every gate org-wide and reverts without pushing.

`reconcile_branch_protection.sh` is the sanctioned way to move live protection back to what
`variables.tf` declares (or to revert it once a second reviewer exists). It re-supplies every
other field from the live document, because a `PUT` to branch protection **replaces** the
whole object — omitting a field would silently drop that control. It fails closed: any
non-2xx is reported per repo and the script exits non-zero.

| Script (repo root) | Purpose | Write behaviour |
|---|---|---|
| `scripts/update_contact_emails.sh` | Sweep published contact addresses across every populated org repo to the `EMAIL_POLICY.md` streams | dry-run / `--diff` preview / `--check-residue` gate rehearsal (reverts) / `--apply` opens one PR per repo (never pushes to `main`) |
| `scripts/test_contact_email_gates.sh` | Regression-tests the sweep's safety gates (rule firing, leak alarm, `email-allow`, append-only and placeholder exclusions) | read-only — never invokes the write mode; clones into `$WORK` only |
| `scripts/reconcile_branch_protection.sh` | Reconcile live branch protection to the **declared** review model (approvals, code-owner) without deleting the PR requirement | dry-run by default; `--apply` writes, then re-reads each repo to verify |
| `scripts/patch_aggregate_gate.py` | Repair an aggregate CI gate that decides its verdict by grepping `toJSON(needs)` text (blind if the JSON is spaced) | edits a local clone only; you open the PR |
| `scripts/patch_codeql_detect.py` | Replace a hard-coded CodeQL `matrix.language` list with the `detect` job already used by `viavitae-template`, so an absent language cannot fail a leg | refuses to write if the YAML will not parse or a literal survives; idempotent; edits a local clone only |
| `scripts/rollout_aggregate_gate.sh` | Open the gate repair as one PR per repo | dry-run by default; `APPLY=1` pushes a branch and opens the PR; merging stays manual |
| `scripts/rollout_workflow_patch.sh` | Same harness, generalised: any patcher (`PATCHER=`) with a branch, title, body and an optional `VERIFY_ABSENT` pattern | dry-run by default; `APPLY=1` pushes and opens PRs; never merges, never touches `main` |
| `scripts/detect_drift.sh` | Compare live org against `repos_data.tf` inventory | read-only (`gh` GET); exit 0 match, 1 drift, 2 could not run (no credential, or a failed/empty org read — never reported as ghost drift); prints `credential_source=` |
| `scripts/assert_live_controls.sh` | Assert the **declared merge controls** (contexts, strict, enforce_admins, linear history, force-push/deletion) against the live API — the gap `detect_drift.sh` cannot see, because inventory equality says nothing about enforcement | read-only; exit 0 match, 1 divergence, 2 could not run; prints its own coverage (`N of M` repositories) |
| `scripts/check_ci_credential.sh` | Pre-flight the CI plan credential: reject anything write-capable and prove every read the **current configuration** requires, before `terraform plan` runs | read-only GETs; exit 0 correct, 1 wrong class or blind spot (names the repos), 2 could not run; never prints the token |
| `scripts/check_plan_selfcite.sh` | Fail when a plan document asserts a number about itself that no longer holds after an amendment (`selfcite:<metric>=<n>`) | read-only; exit 0 match, 1 stale/fabricated assertion, 2 usage error; a file with 0 assertions is reported as **not** evidence of conformance |
| `scripts/assert_org_2fa.sh` | Assert org-wide 2FA enforcement **out-of-band** — the assertion the CI plan can no longer make, because `var.manage_org_data=false` keeps organization full-detail reads out of the plan graph | read-only (`gh` GET) with an operator credential; exit 0 enforced, 1 not enforced, 2 undetermined (a null field is never read as `false`) |
| `scripts/check_audit_register.py` | Fail when the audit register contradicts its own structure — findings-per-table parity, evidence numbering, PART headings, section references and markdown column counts. Exists because four edits broke it silently in one session and each was caught only by a throwaway script | read-only, no network; exit 0 all applicable invariants hold, 1 structural violation (names the line and, for a torn row, quotes the inline code containing the pipe), 2 usage error or a file with no checkable table — unchecked is never reported as a pass |
| `scripts/check_dependabot_scope.py` | Find Dependabot entries that can never resolve a manifest (VV-2026-10-026), real manifests no entry points at (VV-2026-10-027) and — with `--check-runs` — declared entries whose updater run actually **failed** (VV-2026-10-028). Judged per entry's own `directory`, and workspace-aware: a pnpm/npm member under a covered root is monitored through the root lockfile, so it is not reported — the first version of this tool produced 12 such false positives. The outcome layer exists because a config verdict alone is not sufficient: qa and web pass the config check while their npm updater errors, and brand's dead `pip` entry passes weekly while resolving nothing. Exists because each dead entry is attempted on schedule, which trains the operator to ignore the Dependabot column | read-only (`gh` GETs) with an **operator** credential; needs Contents read (and Actions read for `--check-runs`), which `ORG_READ_TOKEN` deliberately does not have, so it is **not** wired into `audit.yml` — running it in CI would mean widening a CI credential. Exit 0 every entry resolves, 1 a dead, unmonitored or failing entry (listed per repo), 2 nothing readable — an unreadable repo or a failed run-read is counted as undetermined, never scored as clean; `--window` must be a `start..end` range, since a bare date filters to one day and silently disables the outcome check. `--selftest` runs 15 offline fixtures with no network |
| `scripts/propagate_landing_scaffold.py` | Carry the two measured landing fixes onto the nine open propagation branches: delete the PyCharm `main.py` stub (option A, VV-2026-10-020/-024) and trim `.github/dependabot.yml` to the one ecosystem that can resolve anything (VV-2026-10-026). Each (repo, item) pair is its own state machine — DONE is a **skip**, an unexpected shape is an **abort with no write** — so a partial sweep is resumable, which the single-repo pilot script it replaces was not | **dry-run by default**; `--apply` writes to nine other repos through the contents API on `fix/ci-matrix-args` only (never `main`, never a merge, never a PR), re-reads each branch to verify, and counts applied / already-done / aborted separately. Validates the payload (YAML re-parse, ecosystem set, no orphan comment header, kept block byte-identical) before writing, and stamps every commit with an `ai:review` trailer. `--selftest` runs the trim fixtures offline |
| `scripts/generate_inventory.sh` | Rebuild the candidate inventory | read-only |
| `scripts/check_secret_inventory.sh` | Fail CI when a dated credential in `docs/SECRETS_INVENTORY.md` expires within 14 days (`WARN_DAYS` overrides); a `2099-*` no-expiry placeholder or `never` root-key row is a warning/notice, `unknown` is a failure, and a row whose `expires` cell cannot be read is a **finding, not a skip** | read-only; exit 0 clean, 1 expired/expiring/unknown/truncated row, 2 register missing or unparseable (never a pass); parses only the register table, so a later table cannot join the enforced set |
| `scripts/check_public_register.sh` | Anti-leak gate for the **public** twin: the expiry gate reads only dates and would happily green-light a register that publishes vault paths, host paths, account ids, named holders or backup media serials. This asserts the property the split depends on, and also that the register table is 2 columns wide and the last table in the file | read-only, no network; exit 0 opaque, 1 identifier-shaped content or unsafe structure, 2 file missing/unparseable. Flags an **empty** register as a finding — zero rows is not a clean register |
| `scripts/reconcile_secret_register.sh` | Prove the public twin and the confidential register agree (same `secret_id` set, same dates, no duplicate keys), then enforce the rotation policy (`last_verified` + `rotation`) that no expiry date can express — the only control over `2099-*`/`never` rows | **local only, never CI**: the CI role is read-only and `provider.tf` forbids Contents, so a job cannot read the private register. Reads two files; exit 0 in sync + no overdue, 1 divergence or overdue rotation, 2 either file unreadable or a register parses to 0 rows. Wired as a pre-commit hook scoped to `docs/SECRETS_INVENTORY.md` |
| `scripts/vault.sh` | age-backed secret store (`put`/`get`/`list`/`rm`/`cp`) reusing the `~/.config/age/state-backup-key.txt` identity; ciphertext under `~/.vault`, git-versioned local-only — supersedes the never-initialized `pass`/`~/.password-store` | host tooling, **not CI-gated**; reads the age identity from stdin/env only, never logs secret values; exit 0 ok, 1 usage/not-found, 2 backend missing |

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
