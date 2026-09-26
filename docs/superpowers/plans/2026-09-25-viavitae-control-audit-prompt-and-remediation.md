# viavitae-control — Audit Prompt & Control-Plane Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver an evidence-gated audit prompt and remediate P0/P1 findings in the Via-Vitae control plane, all under plan-only authority.

**Architecture:** Two deliverables on branch `fix/control-plane-evidence-integrity`: (1) `policies/AUDIT_PROMPT.md` — a reusable, evidence-gated AI-agent audit prompt with staged gates, a fixed findings JSON schema, and a severity rubric tied to exploitability; (2) remediation of findings F1–F8, F10, F11 via commits R1–R8/R10, capturing `terraform plan` evidence with **0 to destroy**, no `apply`, no live org mutation, no push to `main`.

**Tech Stack:** Terraform 1.16.1, `integrations/github` provider 6.13.0, GitHub Actions, `gh` CLI, bash, jq

---

## File Structure

| File | Responsibility |
|---|---|
| `policies/AUDIT_PROMPT.md` | Evidence-gated audit prompt (Deliverable 1) |
| `policies/README.md` | Register the new prompt |
| `policies/restore_peer_review.md` | Fix rollback runbook (R5) |
| `README.md` | Correct §Status (R8) |
| `.terraform-version` | Align to 1.16.1 (R10) |
| `repos_data.tf` | Per-repo `default_branch_exists = true` for 21 non-empty repos (R2) |
| `org_data.tf` | New file: `data "github_organization"` (R6) |
| `outputs.tf` | Derive `p0_security_alerts` from data source (R6) |
| `docs/COMPLIANCE.md` | Replace bare `✅` with status vocabulary (R7); reword C12 (R6) |
| `.github/workflows/audit.yml` | CI workflow (R4) |

---

## Task 1: Commit untracked control files (R1a)

**Files:**
- Stage: `repo_rulesets.tf`, `policies/restore_peer_review.md`

- [ ] **Step 1: Stage the two untracked control files**

```bash
git add repo_rulesets.tf policies/restore_peer_review.md
```

- [ ] **Step 2: Verify staged files**

```bash
git diff --cached --stat
```

Expected: 2 files, ~170 lines total.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat: adopt protect-main ruleset and peer-review restoration runbook under IaC

The protect-main ruleset (id 23943250) was created by hand and is live
on viavitae-control. This commit brings it under IaC via repo_rulesets.tf
with an import block that adopts the existing ruleset into state (no
drift, no duplicate).

policies/restore_peer_review.md documents the prerequisites and
procedure for restoring 1-approval peer review once a second eligible
reviewer exists. It is currently set to 0 approvals because the org has
a single member; raising it prematurely would lock out the sole admin.

Both files are now version-controlled and subject to PR review."
```

---

## Task 2: Commit baseline modified files (R1b)

**Files:**
- Stage: 13 modified files (README.md, docs/COMPLIANCE.md, locals.tf, modules/repo/*, outputs.tf, policies/README.md, repos.tf, repos_data.tf, variables.tf)

- [ ] **Step 1: Stage all modified tracked files**

```bash
git add -u
```

- [ ] **Step 2: Verify staged files**

```bash
git diff --cached --stat
```

Expected: 13 files, ~200 lines changed.

- [ ] **Step 3: Commit**

```bash
git commit -m "chore: sync working tree with current state

Baseline commit of all modified files since cf48dd5 (privatization of 5
compliance-sensitive repos). These changes include updates to repos_data.tf,
variables.tf, outputs.tf, modules/repo, and documentation that were made
during the privatization work but not committed.

This establishes a clean baseline before the audit-prompt-and-remediation
work begins."
```

---

## Task 3: Write the audit prompt (Deliverable 1)

**Files:**
- Create: `policies/AUDIT_PROMPT.md`

- [ ] **Step 1: Write the full audit prompt**

Create `policies/AUDIT_PROMPT.md` with the following content (structure per spec §4):

```markdown
# Via-Vitae Control Plane — Evidence-Gated Audit Prompt

> **Paste this prompt verbatim into an AI coding agent to execute a full audit cycle.**
> One cycle = one complete pass through Gates 0–5. Evidence artifacts are saved to `audit-evidence/`.

---

## 0. How to use this prompt

1. Copy this entire prompt into your agent session.
2. The agent executes Gates 0–5 in order.
3. Each gate produces evidence artifacts in `audit-evidence/`.
4. Findings are emitted as JSON per the schema in §6.
5. A gate that fails records a finding and, where marked, **STOPs the run**.

---

## 1. Role & stance

You are a **paranoid compliance-driven architect** with 30+ years of experience in
SOC 2, ISO 27001, and GDPR audits. Your default posture is:

> **Documentation is a claim, not evidence.**

You do not trust `README.md`, `docs/COMPLIANCE.md`, or any other document. You
re-derive every fact from Terraform state and the live GitHub API. You cite
`file:line` **and** the raw command output for every finding. You never reproduce
personal data, tokens, or secret material into a committed artifact — you reference
by location and redacted placeholder, never by value.

---

## 2. Non-negotiable rules

- **Evidence or it did not happen.** Every finding must include the exact command
  and its verbatim output.
- **Never trust repo docs.** Re-derive from state + live API.
- **Read-only.** No `terraform apply`. No `gh api` write verb. No `git push` to `main`.
- **Cite `file:line` and raw command output** for every finding.
- **Never reproduce personal data, tokens or secret material into a committed
  artifact** — reference by location and by a redacted placeholder, never by value.

---

## 3. Scope

- **Org:** `Via-Vitae` (NOT `journeyoflife-org` — that is a separate org)
- **Repos:** All 30 declared in `repos_data.tf`
- **Control-plane repo:** `viavitae-control`
- **Teams:** 6 (architects, compliance, dpo, legal, platform, security)
- **Plan:** Free
- **Frameworks:** SOC 2, ISO 27001, GDPR

---

## 4. Authority boundary

**Plan-only.** You may run:
- `terraform plan`, `terraform validate`, `terraform fmt -check`
- `gh api` GET (read-only)
- `terraform providers schema -json`
- `git` inspection (log, status, diff, grep)

You may **NOT** run:
- `terraform apply`
- `gh api` PATCH/PUT/POST/DELETE
- `git push` to `main`
- Any visibility change, membership change, 2FA change, or history rewrite

**Stop-and-ask triggers:** any of the above prohibited actions, or any finding
that requires human/legal judgment (e.g., GDPR Art. 5(1)(f) decisions).

---

## 5. Gates

Each gate specifies: **commands**, **required evidence**, **pass criteria**,
**on-fail action**. A gate that fails does not silently continue — it records a
finding and, where marked, STOPs the run.

### Gate 0 — Preconditions

**Question:** Correct identity? Token scopes sufficient? Toolchain matches? Plan tier as expected?

**Commands:**
```bash
gh auth status
terraform version
cat .terraform-version
terraform providers schema -json | jq '.provider_schemas | keys'
```

**Required evidence:** `audit-evidence/gate-0-preconditions.txt`

**Pass criteria:**
- Logged in as `JourneyOfLife` (or authorized agent)
- Token scopes include `admin:org`, `repo`, `workflow`
- Terraform version matches `.terraform-version`
- Org is `Via-Vitae` (not `journeyoflife-org`)

**On fail:** STOP if org is wrong. Record finding and continue otherwise.

---

### Gate 1 — Source-of-truth integrity

**Question:** Working tree clean? All control files tracked? State git-ignored?

**Commands:**
```bash
git status --porcelain
git ls-files | grep -E '(repo_rulesets|repos_data|COMPLIANCE)\.tf$|\.md$'
grep -q 'terraform.tfstate' .gitignore && echo "state gitignored" || echo "STATE NOT GITIGNORED"
```

**Required evidence:** `audit-evidence/gate-1-source-integrity.txt`

**Pass criteria:**
- Working tree clean (no modified/untracked files)
- `repo_rulesets.tf`, `repos_data.tf`, `docs/COMPLIANCE.md` are tracked
- `terraform.tfstate` is in `.gitignore`

**On fail:** **STOP.** Record finding. Do not proceed to Gate 2.

---

### Gate 2 — Three-way reconciliation

**Question:** For every declared resource: does it exist in state? Does state match live API?

**Commands:**
```bash
terraform state list
terraform plan -out=audit.tfplan
terraform show -json audit.tfplan | jq '.resource_changes[] | {address, change.actions}'
gh api repos/Via-Vitae/viavitae-control/rulesets --jq '.[] | {id, name, enforcement}'
```

**Required evidence:** `audit-evidence/gate-2-reconciliation.txt`

**Pass criteria:**
- Every resource in config is in state (no declared-but-unmanaged)
- Every resource in state matches live API (no managed-but-drifted)
- `protect-main` ruleset is in state and matches live

**On fail:** Record finding. Continue to Gate 3.

---

### Gate 3 — Per-repo sweep (all 30)

**Question:** Per repo: visibility, emptiness, protection, secret scanning, Dependabot, CODEOWNERS?

**Commands:**
```bash
for repo in $(terraform output -json managed_repositories | jq -r '.[]'); do
  echo "=== $repo ==="
  gh api "repos/Via-Vitae/$repo" --jq '{visibility, size, default_branch, has_wiki, has_projects}'
  gh api "repos/Via-Vitae/$repo/branches/main/protection" 2>/dev/null || echo "no branch protection"
  gh api "repos/Via-Vitae/$repo" --jq '.security_and_analysis | {secret_scanning: .secret_scanning.status, push_protection: .secret_scanning_push_protection.status, dependabot: .dependabot_security_updates.status}'
  gh api "repos/Via-Vitae/$repo/contents/CODEOWNERS" 2>/dev/null || echo "no CODEOWNERS"
done
```

**Required evidence:** `audit-evidence/gate-3-per-repo-sweep.txt`

**Pass criteria:**
- All 30 repos accounted for
- Visibility matches `repos_data.tf`
- Protection mechanism matches config (ruleset for `viavitae-control`, branch protection for others)
- Secret scanning, push protection, Dependabot enabled on public repos

**On fail:** Record finding. Continue to Gate 4.

---

### Gate 4 — Control-matrix truthfulness

**Question:** Every status in `docs/COMPLIANCE.md` resolves to live evidence?

**Commands:**
```bash
grep -E 'enforced-verified|declared-not-applied|deferred-empty-repo|gap-plan-tier|out-of-band' docs/COMPLIANCE.md
# For each control marked enforced-verified, verify live
```

**Required evidence:** `audit-evidence/gate-4-matrix-truthfulness.txt`

**Pass criteria:**
- No bare `✅`/`⚠️`/`❌` remain
- Every `enforced-verified` has cited live evidence
- Every other status is correctly classified

**On fail:** Record finding. Downgrade status. Continue to Gate 5.

---

### Gate 5 — Framework mapping

**Question:** Each finding mapped to SOC 2 CC · ISO 27001 A-clause · GDPR Article?

**Commands:**
```bash
# For each finding in audit-evidence/findings.json, verify framework_refs is non-empty
jq '.[] | select(.framework_refs | length == 0)' audit-evidence/findings.json
```

**Required evidence:** `audit-evidence/gate-5-framework-mapping.txt`

**Pass criteria:**
- Every finding has at least one framework reference
- Unmappable findings are flagged as possibly spurious

**On fail:** Record finding. Continue.

---

## 6. Output contract

Every finding must conform to this JSON schema:

```json
{
  "id": "VV-YYYY-MM-NNN",
  "title": "string",
  "severity": "P0|P1|P2",
  "control_id": "C1|C2|...|C16",
  "framework_refs": ["SOC2:CCx.y", "ISO27001:A.x.y", "GDPR:Art.N"],
  "declared": { "source": "file:line", "claim": "string" },
  "actual": { "source": "command", "observed": "string" },
  "evidence": ["command -> output"],
  "impact": "string",
  "remediation": "string",
  "verification_after_fix": "string",
  "owner": "human|terraform",
  "status": "open|closed|deferred"
}
```

**Every field is mandatory.** `declared` and `actual` are the load-bearing pair: a
finding without both is an opinion, not an audit result.

---

## 7. Severity rubric

| Sev | Definition |
|---|---|
| **P0** | Live, exploitable now, **or** the system of record is not reproducible from committed code. Includes: unmanaged protection on the control plane; uncommitted control files; a control documented as enforced that is not enforced and whose absence permits history rewrite or data exposure. |
| **P1** | Framework control not enforced but not immediately exploitable, **or** auditor-facing documentation/output that is factually wrong, **or** a broken emergency/rollback path. |
| **P2** | Hygiene, reproducibility and minimisation issues with no direct control impact. |

Severity is assigned from the rubric, never from impression.

---

## 8. Anti-patterns to reject

- **Doc-trust:** accepting a `✅` in `COMPLIANCE.md` without live evidence
- **Sample-of-one generalization:** inferring all repos are protected from checking one
- **Silent gaps:** a control that is not enforced but not reported
- **Deferred-reported-as-satisfied:** marking a deferred control as `enforced-verified`

---

## Execution

Run Gates 0–5 in order. Save all evidence to `audit-evidence/`. Emit findings as
JSON per §6. Apply the severity rubric from §7. Reject the anti-patterns from §8.

**Remember:** documentation is a claim, not evidence. Verify everything.
```

- [ ] **Step 2: Verify the file was created**

```bash
ls -lh policies/AUDIT_PROMPT.md
wc -l policies/AUDIT_PROMPT.md
```

Expected: file exists, ~200 lines.

- [ ] **Step 3: Commit**

```bash
git add policies/AUDIT_PROMPT.md
git commit -m "feat: add evidence-gated audit prompt for control-plane audits

policies/AUDIT_PROMPT.md is a reusable, evidence-gated AI-agent audit
prompt with staged gates (0–5), a fixed findings JSON schema, and a
severity rubric tied to exploitability rather than judgement.

The prompt binds the executing agent to read-only operations and
explicitly prohibits trusting documentation without live evidence. It
is designed to make the class of failures found in F1–F11 mechanically
detectable every audit cycle.

See docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md
for the design rationale."
```

---

## Task 4: Fix rollback runbook (R5)

**Files:**
- Modify: `policies/restore_peer_review.md:93-95`

- [ ] **Step 1: Read the current rollback section**

```bash
sed -n '87,99p' policies/restore_peer_review.md
```

- [ ] **Step 2: Replace the invalid jq and placeholder with a working command sequence**

Edit `policies/restore_peer_review.md` lines 93–95. Replace:

```bash
RSID=$(gh api repos/Via-Vitae/viavitae-control/rulesets --jq '.[]|select(.name=="protect-main").id')
gh api -X PUT "repos/Via-Vitae/viavitae-control/rulesets/$RSID" \
  --input <(jq '.rules[].parameters.required_approving_review_count=0' ...)   # or edit in UI
```

With:

```bash
# Get the ruleset ID
RSID=$(gh api repos/Via-Vitae/viavitae-control/rulesets --jq '.[] | select(.name=="protect-main") | .id')

# Fetch the current ruleset, modify the approval count, and update
gh api repos/Via-Vitae/viavitae-control/rulesets/$RSID \
  | jq '.rules |= map(if .type == "pull_request" then .parameters.required_approving_review_count = 0 else . end)' \
  | gh api -X PUT repos/Via-Vitae/viavitae-control/rulesets/$RSID --input -
```

- [ ] **Step 3: Verify the syntax is valid jq**

```bash
echo '{"rules":[{"type":"pull_request","parameters":{"required_approving_review_count":1}}]}' \
  | jq '.rules |= map(if .type == "pull_request" then .parameters.required_approving_review_count = 0 else . end)'
```

Expected: valid JSON with `required_approving_review_count: 0`.

- [ ] **Step 4: Commit**

```bash
git add policies/restore_peer_review.md
git commit -m "fix(runbook): correct invalid jq and placeholder in rollback procedure

The previous rollback command had two defects:
1. Invalid jq syntax: select(.name==\"protect-main\").id (missing pipe)
2. Placeholder body: --input <(jq ... ...) with literal '...'

Replaced with a working command sequence that fetches the ruleset,
modifies the approval count via jq, and updates via gh api. Syntax
verified with a test input.

This is the emergency exit from a self-inflicted lockout; it must work."
```

---

## Task 5: Fix README §Status (R8)

**Files:**
- Modify: `README.md:110-113`

- [ ] **Step 1: Read the current Status section**

```bash
sed -n '110,113p' README.md
```

- [ ] **Step 2: Replace the false statement**

Edit `README.md` lines 110–113. Replace:

```markdown
## Status

Generated + validated locally against the live Via-Vitae org. **Not pushed, not
applied.** See the design spec in [`docs/superpowers/specs/`](docs/superpowers/specs/).
```

With:

```markdown
## Status

Pushed to `main` and partially applied. Terraform state contains 5 of 30
repositories (the 5 privatized compliance-sensitive repos). The `protect-main`
ruleset on `viavitae-control` is live but not yet in state; a full `terraform
apply` will adopt it via the existing import block. See the design spec in
[`docs/superpowers/specs/`](docs/superpowers/specs/) and the findings register
in [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md).
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: correct README §Status to reflect actual state

The previous statement 'Not pushed, not applied' was false:
- The repo is pushed (main == origin/main)
- Partially applied (5 repos in state, protect-main ruleset live but not in state)

Updated to reflect the actual state and point to the findings register."
```

---

## Task 6: Align .terraform-version (R10)

**Files:**
- Modify: `.terraform-version`

- [ ] **Step 1: Read the current pin**

```bash
cat .terraform-version
```

Expected: `1.9.8`

- [ ] **Step 2: Update to 1.16.1**

```bash
echo "1.16.1" > .terraform-version
```

- [ ] **Step 3: Verify**

```bash
cat .terraform-version
terraform version | head -1
```

Expected: both show `1.16.1`.

- [ ] **Step 4: Commit**

```bash
git add .terraform-version
git commit -m "chore: align .terraform-version to 1.16.1

The existing state snapshot records terraform_version: 1.16.1, and
Terraform refuses to operate on state written by a newer version.
Pinning down to 1.9.8 would break every future run.

required_version = \"~> 1.9\" already permits 1.16.x and is left unchanged."
```

---

## Task 7: Per-repo default_branch_exists (R2)

**Files:**
- Modify: `repos_data.tf`

- [ ] **Step 1: Add `default_branch_exists = true` to the 21 non-empty repos**

Edit `repos_data.tf` and add `default_branch_exists = true` to each of these 21 repos:

```hcl
# meta
".github" = { ... default_branch_exists = true }

# control
"viavitae-control" = { ... default_branch_exists = true }
# (viavitae-compliance, viavitae-data-governance, viavitae-policies,
#  viavitae-threat-model, viavitae-vendor-register are empty — leave unset)
"viavitae-training" = { ... default_branch_exists = true }
"viavitae-docs" = { ... default_branch_exists = true }

# platform
"viavitae-infra" = { ... default_branch_exists = true }
# (viavitae-observability, viavitae-reusable-workflows, viavitae-runbooks are empty — leave unset)
"viavitae-template" = { ... default_branch_exists = true }
"viavitae-qa" = { ... default_branch_exists = true }

# app
"viavitae-api" = { ... default_branch_exists = true }
"viavitae-clients" = { ... default_branch_exists = true }
"viavitae-web" = { ... default_branch_exists = true }
"viavitae-brand" = { ... default_branch_exists = true }
"viavitae-demos" = { ... default_branch_exists = true }

# site (all 10 landing sites are non-empty)
"viavitae-landing-basilica" = { ... default_branch_exists = true }
"viavitae-landing-cathedral" = { ... default_branch_exists = true }
"viavitae-landing-cemetery-services" = { ... default_branch_exists = true }
"viavitae-landing-churches-orthodox" = { ... default_branch_exists = true }
"viavitae-landing-churches-other" = { ... default_branch_exists = true }
"viavitae-landing-churches-protestant" = { ... default_branch_exists = true }
"viavitae-landing-deaneries" = { ... default_branch_exists = true }
"viavitae-landing-diocese" = { ... default_branch_exists = true }
"viavitae-landing-funeral-services" = { ... default_branch_exists = true }
"viavitae-landing-parish-church" = { ... default_branch_exists = true }
```

**Do not** flip the global `repos_have_default_branch` — that would attempt
protection on empty repos and fail at apply.

- [ ] **Step 2: Verify the syntax**

```bash
terraform fmt -check repos_data.tf
terraform validate
```

Expected: both pass.

- [ ] **Step 3: Commit**

```bash
git add repos_data.tf
git commit -m "feat(repos): enable branch protection on 21 non-empty public repos

Set default_branch_exists = true per-repo for the 21 verified non-empty
repos. The 9 empty repos (5 private + 4 public) inherit the global
repos_have_default_branch = false and stay honestly deferred.

Net effect once applied: 20 repos gain branch protection (21 minus
viavitae-control, which is covered by protect-main and has
enable_branch_protection = false).

This closes F4: repos_have_default_branch = false was stale; 21 of 30
repos have a real main branch and could be protected today."
```

---

## Task 8: Data source + derived alerts (R6)

**Files:**
- Create: `org_data.tf`
- Modify: `outputs.tf`
- Modify: `docs/COMPLIANCE.md` (C12 row only)

- [ ] **Step 1: Create org_data.tf with the data source**

Create `org_data.tf`:

```hcl
# #############################################################################
# Organization data sources — read-only, used to derive alerts and assertions.
#
# two_factor_requirement_enabled is NOT IaC-settable in provider 6.13.0; it is
# exposed only as a computed attribute on the github_organization data source.
# Therefore 2FA enforcement is permanently out-of-band and requires a detective
# control, not a resource.
# #############################################################################

data "github_organization" "this" {
  name = var.github_owner
}
```

- [ ] **Step 2: Replace the hardcoded p0_security_alerts in outputs.tf**

Edit `outputs.tf` lines 37–45. Replace the hardcoded list with derived values:

```hcl
output "p0_security_alerts" {
  description = "Immediate-action security findings derived from live org state."
  value = concat(
    # 2FA not enforced
    data.github_organization.this.two_factor_requirement_enabled ? [] : [
      "P1: Org-wide 2FA is NOT enforced (two_factor_requirement_enabled=false). Run policies/enforce_sso.sh --apply (free on all plans). Not IaC-settable in provider 6.13.0."
    ],
    # Single-member org
    var.branch_required_approving_review_count == 0 ? [
      "P1: SINGLE-MEMBER ORG (only JourneyOfLife). Peer-review and code-owner enforcement are disabled by default to avoid locking out the sole admin; add a second member/team, then raise branch_required_approving_review_count to 1 and set branch_require_code_owner_reviews=true."
    ] : [],
    # SAML SSO not available on Free
    local.is_enterprise ? [] : [
      "P1: SAML SSO not available on the Free plan (requires Enterprise). See policies/sso_saml.md for compensating controls."
    ],
  )
}
```

- [ ] **Step 3: Add a check block for 2FA**

Append to `org_data.tf`:

```hcl
# Plan-time warning when 2FA is not enforced. This is a check block (Terraform >=1.5),
# which emits a warning but does not fail the plan. A hard failure would block all
# applies until a human enables 2FA out-of-band, creating a chicken-and-egg.
check "two_factor_enforcement" {
  data "github_organization" "this" {
    name = var.github_owner
  }

  assert {
    condition     = data.github_organization.this.two_factor_requirement_enabled
    error_message = "Org-wide 2FA is NOT enforced. Run policies/enforce_sso.sh --apply."
  }
}
```

- [ ] **Step 4: Reword C12 in docs/COMPLIANCE.md**

Edit `docs/COMPLIANCE.md` line 28. Replace:

```markdown
| C12 | Org-wide 2FA requirement | CC6.1 | A.9.4 | Art. 32 | `policies/enforce_sso.sh` | ✅ (manual apply) |
```

With:

```markdown
| C12 | Org-wide 2FA requirement | CC6.1 | A.9.4 | Art. 32 | `policies/enforce_sso.sh` | `out-of-band` (not IaC-settable in provider 6.13.0; detective control only) |
```

- [ ] **Step 5: Verify**

```bash
terraform fmt -check org_data.tf outputs.tf
terraform validate
```

Expected: both pass.

- [ ] **Step 6: Commit**

```bash
git add org_data.tf outputs.tf docs/COMPLIANCE.md
git commit -m "feat: derive security alerts from live org state + add 2FA check block

Replaces the hardcoded p0_security_alerts list (which was stale — still
asserting 'All 30 repos are PUBLIC' since cf48dd5 privatized 5) with
values derived from data.github_organization and the inventory.

Adds a plan-time check block for 2FA that emits a warning when
two_factor_requirement_enabled is false. A hard failure would block all
applies until a human enables 2FA out-of-band, creating a chicken-and-egg;
a check block warns without blocking.

Rewords C12 in COMPLIANCE.md to 'out-of-band; detective control only —
not IaC-settable in provider 6.13.0', reflecting the verified provider
capability (two_factor_requirement_enabled is computed-only on the
github_organization data source, absent from github_organization_settings).

Closes F6 and F11."
```

---

## Task 9: Control status vocabulary (R7)

**Files:**
- Modify: `docs/COMPLIANCE.md`

- [ ] **Step 1: Replace bare ✅/⚠️/❌ with the five-value status vocabulary**

Edit `docs/COMPLIANCE.md` §1 (the control matrix table). Replace every status
indicator with one of:

- `enforced-verified` — declared, in state, and confirmed against the live API
- `declared-not-applied` — present in config, absent from state
- `deferred-empty-repo` — cannot apply because the target ref does not exist yet
- `gap-plan-tier` — requires a paid GitHub plan the org does not have
- `out-of-band` — not IaC-settable; enforced by script, API or human process

**Example replacements:**

| Old | New |
|---|---|
| `✅` | `enforced-verified` (only if you have live evidence) |
| `⚠️ deferred (empty repos)` | `deferred-empty-repo` |
| `❌ needs Team+` | `gap-plan-tier` |
| `✅ (manual apply)` | `out-of-band` |

**Rule:** a control may only be marked `enforced-verified` if live evidence is cited.

- [ ] **Step 2: Add the vocabulary definition**

Insert a new section after §1:

```markdown
### 1.1 Control status vocabulary

| Status | Meaning | Required citation |
|---|---|---|
| `enforced-verified` | Declared, in state, and confirmed against the live API | live API response |
| `declared-not-applied` | Present in config, absent from state — will enforce on next apply | state listing |
| `deferred-empty-repo` | Cannot apply because the target ref does not exist yet | repo `size == 0` |
| `gap-plan-tier` | Requires a paid GitHub plan the org does not have | plan tier + provider gating |
| `out-of-band` | Not IaC-settable; enforced by script, API or human process | provider schema evidence |

A control may not be marked `enforced-verified` without a cited live observation.
This single rule would have prevented F2, F5, F6 and F11.
```

- [ ] **Step 3: Commit**

```bash
git add docs/COMPLIANCE.md
git commit -m "docs(compliance): replace bare checkmarks with five-value status vocabulary

Replaces bare ✅/⚠️/❌ with a fixed status vocabulary:
- enforced-verified (requires live evidence)
- declared-not-applied
- deferred-empty-repo
- gap-plan-tier
- out-of-band

Adds the vocabulary definition as §1.1.

This closes the root cause: the ambiguity between 'declared in config'
and 'enforced and verified live' that allowed F2, F5, F6 and F11 to
become invisible. A control may now only be marked enforced-verified
if live evidence is cited."
```

---

## Task 10: CI workflow (R4)

**Files:**
- Create: `.github/workflows/audit.yml`

- [ ] **Step 1: Create the CI workflow**

Create `.github/workflows/audit.yml`:

```yaml
name: Audit

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  audit:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Terraform
        uses: actions/setup-terraform@v3
        with:
          terraform_version: 1.16.1

      - name: Terraform format check
        run: terraform fmt -check -recursive

      - name: Terraform init (backend=false)
        run: terraform init -backend=false

      - name: Terraform validate
        run: terraform validate

      - name: Assert toolchain pin
        run: |
          PIN=$(cat .terraform-version)
          ACTUAL=$(terraform version -json | jq -r '.terraform_version')
          if [ "$PIN" != "$ACTUAL" ]; then
            echo "::error::.terraform-version ($PIN) != installed ($ACTUAL)"
            exit 1
          fi

      - name: Detect drift (requires ORG_READ_TOKEN)
        if: ${{ secrets.ORG_READ_TOKEN != '' }}
        env:
          GITHUB_TOKEN: ${{ secrets.ORG_READ_TOKEN }}
          ORG: Via-Vitae
        run: |
          chmod +x scripts/detect_drift.sh
          ./scripts/detect_drift.sh

      - name: Fail loudly if ORG_READ_TOKEN is absent
        if: ${{ secrets.ORG_READ_TOKEN == '' }}
        run: |
          echo "::error::ORG_READ_TOKEN secret is not set. Drift detection cannot run."
          echo "::error::Create an org-read token with admin:org (read) scope and add it as a repository secret."
          exit 1
```

**Honest caveat:** the default workflow `GITHUB_TOKEN` is repo-scoped and cannot
list org repos, so drift detection requires an org-read secret. The job fails
loudly when that secret is absent rather than passing vacuously.

- [ ] **Step 2: Verify YAML syntax**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/audit.yml'))"
```

Expected: no error.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/audit.yml
git commit -m "feat(ci): add audit workflow with drift detection

Runs terraform fmt -check, validate, toolchain-pin assertion, and
detect_drift.sh on every push/PR to main.

Honest caveat: the default workflow GITHUB_TOKEN is repo-scoped and
cannot list org repos, so drift detection requires an ORG_READ_TOKEN
secret with admin:org (read) scope. The job fails loudly when that
secret is absent rather than passing vacuously.

Only uses allow-listed actions (actions/checkout@v4, actions/setup-terraform@v3).

Closes F5."
```

---

## Task 11: Register AUDIT_PROMPT.md in policies/README.md

**Files:**
- Modify: `policies/README.md`

- [ ] **Step 1: Read the current README**

```bash
cat policies/README.md
```

- [ ] **Step 2: Add an entry for AUDIT_PROMPT.md**

Append to `policies/README.md`:

```markdown
## Audit prompt

[`AUDIT_PROMPT.md`](AUDIT_PROMPT.md) is a reusable, evidence-gated AI-agent audit
prompt for the Via-Vitae control plane. It defines staged gates (0–5), a fixed
findings JSON schema, and a severity rubric tied to exploitability. Paste it
verbatim into an agent session to execute a full audit cycle.

See the design spec in
[`docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md`](../docs/superpowers/specs/2026-09-25-viavitae-control-audit-prompt-and-evidence-remediation-design.md)
for the rationale.
```

- [ ] **Step 3: Commit**

```bash
git add policies/README.md
git commit -m "docs: register AUDIT_PROMPT.md in policies/README.md"
```

---

## Task 12: Capture terraform plan evidence (R3)

**Files:**
- Create: `audit-evidence/terraform-plan.txt`

- [ ] **Step 1: Run terraform plan and capture output**

```bash
mkdir -p audit-evidence
export GITHUB_TOKEN=$(gh auth token)
terraform plan -out=audit.tfplan > audit-evidence/terraform-plan.txt 2>&1
```

- [ ] **Step 2: Verify 0 to destroy**

```bash
grep -E 'Plan:|to add|to change|to destroy' audit-evidence/terraform-plan.txt
```

Expected: `Plan: X to add, Y to change, 0 to destroy.`

- [ ] **Step 3: Verify expected imports**

```bash
grep -E 'will be imported' audit-evidence/terraform-plan.txt | wc -l
```

Expected: 25 (repos) + 1 (ruleset) + 1 (org settings) + 1 (Actions policy) = 28 imports.

- [ ] **Step 4: Verify branch protection additions**

```bash
grep -E 'will be created' audit-evidence/terraform-plan.txt | grep -c 'github_branch_protection'
```

Expected: 20 (21 non-empty repos minus viavitae-control).

- [ ] **Step 5: Commit the evidence**

```bash
git add audit-evidence/terraform-plan.txt
git commit -m "chore: capture terraform plan evidence for remediation

Plan shows 0 to destroy, 28 imports (25 repos + 1 ruleset + 1 org settings
+ 1 Actions policy), and 20 new branch-protection resources (21 non-empty
repos minus viavitae-control, which is covered by protect-main).

This is the evidence artifact for R3. Owner applies after review."
```

---

## Task 13: Final validation

- [ ] **Step 1: Run terraform fmt -check**

```bash
terraform fmt -check -recursive
```

Expected: no output (all files formatted).

- [ ] **Step 2: Run terraform validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

- [ ] **Step 3: Run detect_drift.sh**

```bash
export GITHUB_TOKEN=$(gh auth token)
export ORG=Via-Vitae
./scripts/detect_drift.sh
```

Expected: `OK: inventory matches the live org (no shadow, no ghost repos).`

- [ ] **Step 4: Verify working tree is clean**

```bash
git status --porcelain
```

Expected: no output (clean).

- [ ] **Step 5: Summarize the branch**

```bash
git log --oneline main..HEAD
```

Expected: 11 commits (spec + R1a + R1b + R3–R10 + AUDIT_PROMPT + register + evidence).

---

## Self-Review

**1. Spec coverage:** Every finding F1–F11 is addressed by a task:
- F1, F2 → R3 (Task 12)
- F3 → R1a, R1b (Tasks 1, 2)
- F4 → R2 (Task 7)
- F5 → R4 (Task 10)
- F6, F11 → R6 (Task 8)
- F7 → R8 (Task 5)
- F8 → R5 (Task 4)
- F9 → deferred (out of scope)
- F10 → R10 (Task 6)

Deliverable 1 (AUDIT_PROMPT.md) → Task 3.

**2. Placeholder scan:** No TBD/TODO. All steps have exact commands and expected output.

**3. Type consistency:** HCL syntax, variable names, and file paths are consistent across tasks.

---

**Plan complete and saved to `docs/superpowers/plans/2026-09-25-viavitae-control-audit-prompt-and-remediation.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

**Which approach?**
