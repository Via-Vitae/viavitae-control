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
