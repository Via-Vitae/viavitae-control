#!/usr/bin/env bash
# #############################################################################
# reconcile_branch_protection.sh — bring LIVE branch protection back to the
# config this control plane declares, instead of hand-editing 19 repos in the UI.
#
# Why this exists (measured 2026-10-15):
#   - modules/repo/branch_protection.tf emits required_approving_review_count
#     from var.branch_required_approving_review_count, whose declared default is
#     0 with the comment "default to 0 because the Via-Vitae org currently has a
#     single member (requiring approvals would lock out the sole admin)".
#   - Live reality: 19 of 21 populated public repos are at 1 approving review.
#     With one member, a pending second account and no admin bypass, that made
#     EVERY PR in those repos unmergeable — including the contact-address fixes.
#   - This script lowers only the approving-review COUNT. It does NOT delete the
#     required_pull_request_reviews rule: deleting it would allow direct pushes
#     to main and destroy the PR audit trail. Requiring a PR is preserved.
#
# Everything else in the protection is read from the live API and re-supplied
# unchanged (contexts, strict, enforce_admins, linear history, force-push and
# deletion blocks). A PUT replaces the whole document, so omission would
# silently drop a control. Shape matters and is asymmetric:
#   - combined PUT: enforce_admins, required_linear_history, allow_force_pushes,
#     allow_deletions, block_creations, required_conversation_resolution and
#     required_signatures are BARE BOOLEANS; only required_status_checks,
#     required_pull_request_reviews and restrictions are objects/null.
#   - the individual sub-endpoints (PUT .../protection/required_linear_history)
#     are the ones that take {"enabled": bool}.
# Sending the sub-endpoint shape here returns 422 "{'enabled' => false} is not a
# boolean". The script fails closed on any non-2xx so a partial batch can never
# be reported as success.
#
# The review block is set to the DECLARED values, not the live ones, because the
# lockout has two halves: approvals AND code-owner review. Live carries
# require_code_owner_reviews=true while variables.tf declares false; leaving it
# would keep every PR unmergeable even at 0 approvals (no CODEOWNERS exists).
#
# DRY-RUN BY DEFAULT. Pass --apply to write. Pass --yes to skip the prompt.
#
# Usage:
#   ORG=Via-Vitae ./scripts/reconcile_branch_protection.sh                    # show drift
#   ./scripts/reconcile_branch_protection.sh --repos "viavitae-docs .github"
#   ./scripts/reconcile_branch_protection.sh --apply          # prompts for the org name
#   ./scripts/reconcile_branch_protection.sh --apply --yes     # non-interactive
#
# Revert (once a real second reviewer exists, and set terraform.tfvars to 1):
#   REVIEW_COUNT=1 ./scripts/reconcile_branch_protection.sh --apply --yes
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
REVIEW_COUNT="${REVIEW_COUNT:-0}"          # declared value in variables.tf
CODEOWNER_REVIEW="${CODEOWNER_REVIEW:-false}"   # declared: branch_require_code_owner_reviews = false
LAST_PUSH_APPROVAL="${LAST_PUSH_APPROVAL:-false}"
BRANCH="${BRANCH:-main}"
APPLY=0
ASSUME_YES=0
REPOS=""

usage() { sed -n '/^# Usage:/,/^# Revert/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --yes) ASSUME_YES=1; shift ;;
    --repos) REPOS="${2:?--repos takes a space-separated list}"; shift 2 ;;
    --org) ORG="${2:?}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown argument: $1" >&2; usage ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "gh required" >&2; exit 1; }
gh api user --jq .login >/dev/null 2>&1 || { echo "gh not authenticated" >&2; exit 1; }

if [[ -z "${REPOS}" ]]; then
  # Populated public repos only: private repos cannot hold branch protection on
  # the Free plan, and a PUT there returns 403 "Upgrade to GitHub Pro".
  REPOS="$(gh api "orgs/${ORG}/repos?per_page=100" --jq '.[] | select(.private==false and .size>0) | .name' | tr '\n' ' ')"
fi

drift=0
failed=0
declare -a changed=()

# Confirmation gate: this writes branch protection across the whole org, so --apply
# alone is not consent. --yes is what automation uses.
if [[ ${APPLY} -eq 1 && ${ASSUME_YES} -eq 0 ]]; then
  set -- ${REPOS}
  printf '\nAbout to REWRITE branch protection on %d repos in %s (approvals -> %s,\n  code-owner -> %s). Every other field is re-supplied from live.\n' \
    "$#" "${ORG}" "${REVIEW_COUNT}" "${CODEOWNER_REVIEW}"
  printf 'Type the organization name to continue (anything else aborts): '
  read -r answer
  if [[ "${answer}" != "${ORG}" ]]; then
    echo "aborted by operator; nothing written." >&2
    exit 1
  fi
  unset answer
fi

printf '\n=== %s: reconciling live protection to declared review count = %s (%s)\n' \
  "${ORG}" "${REVIEW_COUNT}" "$(if [[ ${APPLY} -eq 1 ]]; then echo 'APPLY'; else echo 'DRY-RUN'; fi)"
printf '%-34s %-6s %-6s %-9s %-8s %-7s %s\n' REPO LIVE WANT CODEOWNER CHECKS ENFORCE PUSH
printf '%-34s %-6s %-6s %-9s %-8s %-7s %s\n' '----' '----' '----' '---------' '------' '-------' '----'

for repo in ${REPOS}; do
  prot="$(gh api "repos/${ORG}/${repo}/branches/${BRANCH}/protection" 2>/dev/null)" || {
    printf '%-34s %s\n' "${repo}" "no protection (skipped)"; continue; }
  live_rev="$(printf '%s' "${prot}" | python3 -c 'import json,sys;d=json.load(sys.stdin);r=d.get("required_pull_request_reviews") or {};print(r.get("required_approving_review_count","none"))')"
  checks="$(printf '%s' "${prot}" | python3 -c 'import json,sys;d=json.load(sys.stdin);print(",".join((d.get("required_status_checks") or {}).get("contexts") or []))')"
  enforce="$(printf '%s' "${prot}" | python3 -c 'import json,sys;d=json.load(sys.stdin);ea=d.get("enforce_admins") or {};print("yes" if ea.get("enabled") else "no")')"
  # Pushes to the protected branch are blocked while the reviews rule exists; if the
  # rule is absent entirely, direct pushes are possible. Surface that explicitly.
  push="$(printf '%s' "${prot}" | python3 -c 'import json,sys;d=json.load(sys.stdin);print("pr-only" if d.get("required_pull_request_reviews") else "DIRECT-PUSH-ALLOWED")')"

  codeowner="$(printf '%s' "${prot}" | python3 -c 'import json,sys;d=json.load(sys.stdin);r=d.get("required_pull_request_reviews") or {};print("yes" if r.get("require_code_owner_reviews") else "no")')"

  printf '%-34s %-6s %-6s %-9s %-8s %-7s %s\n' "${repo}" "${live_rev}" "${REVIEW_COUNT}" \
    "${codeowner}" "$(printf '%s' "${checks}" | cut -c1-8)" "${enforce}" "${push}"

  if [[ "${live_rev}" == "${REVIEW_COUNT}" ]]; then continue; fi
  drift=1
  changed+=("${repo}")

  [[ ${APPLY} -eq 0 ]] && continue

  # Build the replacement document from the LIVE value, changing only the review block.
  printf '%s' "${prot}" | python3 -c '
import json, sys
count, codeowner, lastpush = sys.argv[1], sys.argv[2] == "true", sys.argv[3] == "true"
d = json.load(sys.stdin)
sc = d.get("required_status_checks") or {}
rvo = d.get("required_pull_request_reviews") or {}

def flag(name, default):
    v = d.get(name)
    if isinstance(v, dict):
        return bool(v.get("enabled", default))
    return bool(v) if v is not None else default

out = {
  "required_status_checks": {"strict": bool(sc.get("strict", True)),
                             "contexts": list(sc.get("contexts") or [])},
  "required_pull_request_reviews": {
    "required_approving_review_count": int(count),
    "dismiss_stale_reviews": bool(rvo.get("dismiss_stale_reviews", True)),
    "require_code_owner_reviews": codeowner,
    "require_last_push_approval": lastpush},
  "enforce_admins": flag("enforce_admins", True),
  "required_linear_history": flag("required_linear_history", True),
  "allow_force_pushes": flag("allow_force_pushes", False),
  "allow_deletions": flag("allow_deletions", False),
  "block_creations": flag("block_creations", False),
  "required_conversation_resolution": flag("required_conversation_resolution", False),
  "required_signatures": flag("required_signatures", False),
  "restrictions": None,
}
json.dump(out, sys.stdout)
' "${REVIEW_COUNT}" "${CODEOWNER_REVIEW}" "${LAST_PUSH_APPROVAL}" > "${TMPDIR:-/tmp}/vv_bp_${repo}.json"

  if ! gh api -X PUT "repos/${ORG}/${repo}/branches/${BRANCH}/protection" \
       --input "${TMPDIR:-/tmp}/vv_bp_${repo}.json" >/dev/null 2>"${TMPDIR:-/tmp}/vv_bperr_${repo}.txt"; then
    printf '      %-30s PUT FAILED: %s\n' "${repo}" \
      "$(head -c 220 "${TMPDIR:-/tmp}/vv_bperr_${repo}.txt" | tr -d '\n')" >&2
    drift=1
    failed=$((failed + 1))
    continue
  fi
  now="$(gh api "repos/${ORG}/${repo}/branches/${BRANCH}/protection" \
           --jq '{count:.required_pull_request_reviews.required_approving_review_count, codeowner:.required_pull_request_reviews.require_code_owner_reviews, ctx:(.required_status_checks.contexts|length), enforce:.enforce_admins.enabled, linear:.required_linear_history.enabled}' 2>/dev/null || echo verify-failed)"
  printf '      %-30s %s\n' "${repo}" "${now}"
done

printf '\n=== repos needing change: %d ===\n' "${#changed[@]}"
if [[ ${#changed[@]} -gt 0 ]]; then printf '  %s\n' "${changed[@]}"; fi
if [[ ${APPLY} -eq 1 && ${failed} -gt 0 ]]; then
  printf '\nSTOP: %d repo(s) failed to reconcile. Do not merge on the assumption that\n  protection is uniform; re-run until this line disappears.\n' "${failed}" >&2
  exit 1
fi

if [[ ${APPLY} -eq 0 ]]; then
  printf '\nDRY-RUN. Nothing written. To apply:\n'
  printf '  ./scripts/reconcile_branch_protection.sh --apply --yes\n'
  printf 'Documented consequence: with 0 approvals and one member, the author can merge\n'
  printf 'their own PR. SOC 2 CC1.4/CC8.1 separation of duties is then a gap, not a control;\n'
  printf 'it must stay recorded in docs/COMPLIANCE.md until a 2FA-enrolled second reviewer exists.\n'
  exit 0
fi

if [[ ${drift} -eq 0 && ${#changed[@]} -eq 0 ]]; then
  printf 'No drift: live already matches the declared review count.\n'
fi
exit 0
