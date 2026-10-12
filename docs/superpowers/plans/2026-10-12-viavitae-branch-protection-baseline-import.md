# Branch-Protection Baseline Import — viavitae-control

| Field | Value |
|---|---|
| Date | 2026-10-12 |
| Repo | Via-Vitae/viavitae-control |
| Status | **PROPOSED — not executed.** No `terraform import` or `apply` has been run. |
| Authority | plan-only. State mutation requires explicit owner authorization. |
| Trigger | `terraform plan` showed 20 `github_branch_protection` resources as `create`, not `update` |
| Evidence | `audit-evidence/live-branch-protection-2026-10-12.txt` (local, gitignored) |

## §1 Problem

`terraform plan` proposes **51 create / 27 update / 8 no-op / 0 destroy**. State holds
only **9 resources**, of which exactly **one** is a branch protection
(`module.repo["viavitae-hermes-agents"].github_branch_protection.this[0]`).

The other 20 classic protections exist **live but unmanaged**. Because they were never
recorded in state, applying would `create` over them with the declared configuration,
which is **weaker than live** on three axes. Measured 2026-10-12 across the 21 repos the
plan targets:

| Control | Live (of 21) | Declared | Effect on apply |
|---|---|---|---|
| `required_approving_review_count ≥ 1` | **19** | `0` | **DOWNGRADE** 19 repos |
| `require_code_owner_reviews = true` | **8** | `false` | **DOWNGRADE** 8 repos |
| required status contexts ≥ 1 (2–5 each) | **20** | none | **DOWNGRADE** 20 repos |
| `enforce_admins = true` | **0** | `true` | **UPGRADE** 21 repos |
| `required_linear_history = true` | not measured | `true` | unmeasured |

So the plan is a **mixed change**: it hardens `enforce_admins` org-wide while silently
removing peer-review, code-owner, and required-check gates from most repos. Neither half
is visible as a diff today, because a `create` shows no "before".

## §2 Why import is the correct fix

Importing live protection into state converts every blind `create` into an
in-place `update` with an explicit before/after diff. The downgrade then becomes
**reviewable instead of invisible**, and the capture file makes it reversible.

Provider v6.13.0 import ID format is `repository:pattern` (verified from
`docs/resources/branch_protection.md`):

```shell
terraform import github_branch_protection.terraform terraform:main
```

## §3 Pre-flight — must pass before any import

a. Confirm the drift guardrail and org baseline are green:

```bash
bash scripts/detect_drift.sh;       echo "rc=$? (want 0)"
bash policies/check_org_security.sh; echo "rc=$? (want 0)"
```
Expected: `OK: inventory matches the live org (no shadow, no ghost repos).`

b. Confirm the recovery capture exists and is current:

```bash
ls -l audit-evidence/live-branch-protection-2026-10-12.txt
```
Expected: ~32 KB, 21 `@@@ REPO` blobs.

c. Re-capture immediately before touching state, so the rollback baseline reflects reality
rather than a stale snapshot:

```bash
for r in $(awk '{print}' /tmp/vv-bprepos-839247.txt); do
  echo "@@@ REPO $r @@@"
  gh api "repos/Via-Vitae/$r/branches/main/protection" 2>&1
done > audit-evidence/live-branch-protection-$(date +%F).txt
cp terraform.tfstate terraform.tfstate.bak-$(date +%Y%m%dT%H%M%S)
```
Expected: a state backup file exists before the first import.

## §4 Import the 20 unmanaged protections

The repo list is the set of addresses the plan targets. Generate, review, then run.

a. Generate the command list, excluding what is already in state:

```bash
terraform plan -input=false -no-color \
  -var 'billing_email=org-billing@example.invalid' \
  | grep -oE 'module\.repo\["[^"]+"\]\.github_branch_protection\.this\[0\] will be created' \
  | sed -E 's/module\.repo\["([^"]+)"\].*/\1/' | sort -u > /tmp/vv-to-import.txt
wc -l /tmp/vv-to-import.txt    # expect 20
```

b. Dry-run review of each ID before executing anything. The address contains double
quotes, so it must be wrapped in **single** quotes — nesting them as `"...["$r"]..."`
breaks at the first inner quote and the command fails:

```bash
while read -r r; do
  printf "terraform import 'module.repo[\"%s\"].github_branch_protection.this[0]' %s:main\n" "$r" "$r"
done < /tmp/vv-to-import.txt | tee /tmp/vv-import-cmds.sh
```
Expected: 20 lines, each of the form
`terraform import 'module.repo["viavitae-api"].github_branch_protection.this[0]' viavitae-api:main`

Check the quoting before running anything:

```bash
head -1 /tmp/vv-import-cmds.sh
bash -n /tmp/vv-import-cmds.sh && echo "shell-parse OK"
```

c. Execute one, verify, then proceed. Stop immediately on any error:

```bash
read -r r < /tmp/vv-to-import.txt
terraform import "module.repo[\"$r\"].github_branch_protection.this[0]" "$r:main"
```
Better, using the same single-quote discipline as the reviewed list:

```bash
read -r r < /tmp/vv-to-import.txt
terraform import 'module.repo["'"$r"'"].github_branch_protection.this[0]' "$r:main"
terraform state show 'module.repo["'"$r"'"].github_branch_protection.this[0]'
```

d. Loop the remainder only after (c) is confirmed correct.

## §4c Verified list

The generated list resolves to exactly these 20 addresses (verified 2026-10-12; count
matches the plan's 20 `github_branch_protection` creates):

```
.github  viavitae-api  viavitae-brand  viavitae-clients  viavitae-demos  viavitae-docs
viavitae-infra  viavitae-landing-basilica  viavitae-landing-cathedral
viavitae-landing-cemetery-services  viavitae-landing-churches-orthodox
viavitae-landing-churches-other  viavitae-landing-churches-protestant
viavitae-landing-deaneries  viavitae-landing-diocese
viavitae-landing-funeral-services  viavitae-landing-parish-church  viavitae-qa
viavitae-template  viavitae-web
```

`viavitae-hermes-agents` is **excluded** — it is the one protection already in state.
Note `/tmp/vv-to-import.txt` and `/tmp/vv-bprepos-839247.txt` are session scratch files;
regenerate them per §4a rather than assuming they survived.

## §5 Post-import verification — the actual decision point

Re-plan and inspect what apply would really do:

```bash
TF_VAR_billing_email=org-billing@example.invalid \
  terraform plan -input=false -no-color | grep -E 'github_branch_protection|~|^\s+[+-]' \
  | grep -E 'required_approving_review_count|require_code_owner_reviews|contexts'
```

Expected outcome: each protection now appears as `~ update in place` showing the exact
attribute deltas, e.g.

```
~ required_approving_review_count = 1 -> 0
~ require_code_owner_reviews      = true -> false
- contexts = ["ci/test", "security/sast"] -> null
```

**STOP here.** That diff is the compliance decision, and it belongs to the owner.

## §6 Options once the diff is visible

| Option | Action | Consequence |
|---|---|---|
| A. Preserve live strength | Declare the real values: set `branch_required_approving_review_count = 1`, `branch_require_code_owner_reviews = true`, and populate `branch_required_status_checks_contexts` per repo | **Risks locking out the sole admin** — cannot approve own PR. This is why the vars default to 0/false. |
| B. Keep solo-safe, protect checks only | Leave reviews at 0/false, but populate `branch_required_status_checks_contexts` | No lockout; CI gate preserved. **Recommended for a single-member org.** |
| C. Migrate to rulesets | Move the 20 repos onto `github_repository_ruleset` like `viavitae-control`, which already declares `required_check { context = "provenance" }` | Consistent single mechanism; rulesets outrank classic protection. Larger change. |
| D. Apply as-is | Accept the downgrade | **Not recommended** — removes required status checks from 20 repos. |

Option B is the smallest change that removes the material regression, because
`strict = true` over an empty context list gates nothing, while reviews at 0 are a
deliberate documented single-member-org guard rather than an oversight.

## §7 Rollback

```bash
# restore state
cp terraform.tfstate.bak-<timestamp> terraform.tfstate
# re-apply live protection values from the capture (per repo)
gh api -X PUT repos/Via-Vitae/<repo>/branches/main/protection -F input=@<protection-blob>
```

## §8 STOP conditions

- Any `destroy` or `replace` in the plan → halt and report.
- Any import that errors → halt; do not continue the loop.
- State backup missing → do not import.
- Capture older than the current session → re-capture first.

## §9 Note on `billing_email`

`billing_email` has no default by design (GDPR Art. 5(1)(c)), so **every** terraform
command must supply it — including read-only ones like `-refresh-only`. Use the
`org-billing@example.invalid` placeholder for all read-only operations; the real value
is needed only by `github_organization_settings` at apply time, and once applied it is
stored in plaintext in `terraform.tfstate` while the backend is still local (the S3
backend remains AWS-SCP-blocked). That is an open GDPR-at-rest item, not a new one.
