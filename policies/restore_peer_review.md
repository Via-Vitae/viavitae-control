# Runbook — Restore 1-approval peer review

**Control:** SOC 2 CC1.4 / CC8.1 (segregation of duties, change approval),
ISO 27001 A.6.1 / A.14.2, GDPR Art. 24.

**Current state (re-verified 2026-10-15 — this section was stale):** live branch
protection requires **1 approving review** on 19 of the 21 populated public repos
(`viavitae-qa` is the outlier at 0), with `enforce_admins=true` everywhere. That is
**drift from the declared config**: `variables.tf` defaults
`branch_required_approving_review_count` to `0` and `terraform.tfvars.example` sets
`0`, because the org has a **single member** (`JourneyOfLife`).

`IterVitae` is **not** a member: `gh api orgs/Via-Vitae/members` returns only
`JourneyOfLife`, and `gh api orgs/Via-Vitae/invitations` shows an **admin invitation
still pending** (invited by `JourneyOfLife`). A pending invitee cannot approve, so the
combination *1 required review + enforce_admins + no second member* makes **every PR in
those 19 repos unmergeable** — including the 20 contact-address PRs this policy exists to
serve. Fix the prerequisite (accept the invitation) rather than bypassing the control.

> ⚠️ **DO NOT** raise the approval count until the prerequisites below are met.
> Doing so with one eligible reviewer makes `main` **unmergeable and unpushable**
> (you cannot approve your own PR, and there is no bypass) — a self-inflicted
> lockout of the control plane. Note this has already happened on 19 repos: the count
> is live at 1 while the second reviewer is still an invitee.

## Single source of truth

Both enforcement mechanisms read the **same variables** (`variables.tf`), so this
is a one-line policy flip that updates everything at once:

| Variable | Now | After |
|---|---|---|
| `branch_required_approving_review_count` | `0` | `1` |
| `branch_require_code_owner_reviews` | `false` | `true` (only if step P3 done) |
| `branch_require_last_push_approval` | `false` | `true` (recommended) |

These feed:
- `github_repository_ruleset.protect_main` (the live `protect-main` ruleset on
  `viavitae-control` — `repo_rulesets.tf`), and
- `modules/repo` `github_branch_protection` for every other managed repo.

## Prerequisites (ALL must be true before flipping)

- **P1 — A 2nd eligible reviewer.** At least one *additional* person with `write`
  (or `triage`) access to each repo you protect. Either:
  - add a genuine 2nd **org member**, or
  - elevate `IterVitae` (or another collaborator) from `read` → `write` on the
    relevant repos. Note: making an external collaborator the required gate of the
    compliance control plane is a governance decision — record it.
  - Verify: `gh api repos/Via-Vitae/viavitae-control/collaborators/<user>/permission --jq .permission` returns `write`/`admin`.
  - **Accepting the pending invitation is the missing step.** It must be done by the
    invitee (`IterVitae`), and it is not available through the REST API — use the web UI
    while signed in as that account: https://github.com/organizations/Via-Vitae/invitations
    Then confirm: `gh api orgs/Via-Vitae/members --jq '.[].login'` lists both accounts.
- **P2 — Author cannot self-approve.** With ≥2 write-capable people, each can
  approve the other's PR. Confirm the sole admin is no longer the only approver.
- **P3 — (Only if enabling code-owner review)** commit a `CODEOWNERS` file to each
  protected repo and ensure the reviewer is in a listed team. Without this,
  `require_code_owner_review = true` is unsatisfiable → lockout. The control plane
  can manage this file: set `manage_files = true` for the repo in `repos_data.tf`.
- **P4 — Private repos need Team+.** Branch protection on *private* repos requires
  GitHub Team/Enterprise. On Free, this flip only takes effect for **public** repos
  (and the `protect-main` ruleset on public `viavitae-control`).

## Procedure

1. Confirm P1–P4 above. Re-run the membership/permission checks.
2. Edit `terraform.tfvars` (or the defaults in `variables.tf`):
   ```hcl
   branch_required_approving_review_count = 1
   branch_require_last_push_approval      = true
   branch_require_code_owner_reviews      = false  # set true ONLY after P3
   ```
3. Preview (must show the ruleset + branch-protection updates, **0 destroy**):
   ```bash
   export GITHUB_TOKEN="$(gh auth token)"
   terraform plan
   ```
4. Apply:
   ```bash
   terraform apply
   ```
5. If the `protect-main` ruleset is not yet in state (first apply of
   `repo_rulesets.tf`), it is adopted automatically by its `import` block.

## Verify

```bash
# Live state per repo (what actually blocks a merge):
gh api "repos/Via-Vitae/<repo>/branches/main/protection" \
  --jq '{reviews:.required_pull_request_reviews.required_approving_review_count,
         enforce_admins:.enforce_admins.enabled,
         required_checks:[.required_status_checks.contexts[]]}'
gh api orgs/Via-Vitae/members --jq '.[].login'          # must list the reviewer too

# Ruleset now requires 1 approval:
gh api repos/Via-Vitae/viavitae-control/rulesets --jq '.[] | select(.name=="protect-main") | .id' \
  | xargs -I{} gh api repos/Via-Vitae/viavitae-control/rulesets/{} \
     --jq '.rules[] | select(.type=="pull_request") | .parameters.required_approving_review_count'
# terraform view:
terraform output effective_control_matrix   # code_owner_review_enforced should reflect the change
terraform output control_gaps             # the "peer-review requirement is 0" gap should disappear
```
Then open a test PR and confirm it **cannot** merge without a second approval.

## Rollback (if you get locked out)

The `protect-main` ruleset has `bypass_actors: []`, so if you are locked out you
must relax it out-of-band. Fastest safe rollback:
```bash
# Get the ruleset ID
RSID=$(gh api repos/Via-Vitae/viavitae-control/rulesets --jq '.[] | select(.name=="protect-main") | .id')

# Fetch the current ruleset, modify the approval count, and update
gh api repos/Via-Vitae/viavitae-control/rulesets/$RSID \
  | jq '.rules |= map(if .type == "pull_request" then .parameters.required_approving_review_count = 0 else . end)' \
  | gh api -X PUT repos/Via-Vitae/viavitae-control/rulesets/$RSID --input -
```
Simpler: temporarily set `branch_required_approving_review_count = 0` and
`terraform apply`. To avoid ever needing this, do not enable the flip until P1–P3
are genuinely satisfied.

## Related

- `policies/sso_saml.md` — the broader single-member / access-management gap.
- `docs/COMPLIANCE.md` — P1-2 (single-member org) in the findings register.
