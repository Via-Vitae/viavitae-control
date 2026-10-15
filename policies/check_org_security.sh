#!/usr/bin/env bash
# #############################################################################
# check_org_security.sh — organisation security baseline monitor.
#
# WHY THIS EXISTS (2026-10-12):
#   The org-wide two-factor requirement was enabled, but it CANNOT be managed by
#   Terraform (github_organization_settings has no such argument in provider
#   6.13.0) and it CANNOT be set by the REST API (PATCH /orgs/{org} accepts no
#   such body parameter; it answers 200 and changes nothing). On the Free plan
#   GET /orgs/{org}/audit-log returns 404, so GitHub keeps no retrievable record
#   of who changed the setting or when — the org payload's updated_at did not move.
#
#   A control that is live, undeclarable and unlogged is unmonitorable unless
#   something outside GitHub watches it. This script is that something: it
#   snapshots the live org settings into a VERSION-CONTROLLED baseline and fails
#   on any deviation, which makes the repository the system of record for
#   organisational security changes.
#
# Exit codes (same doctrine as enforce_sso.sh / plan_gate.py):
#   0  baseline matches live org
#   1  DRIFT (a tracked setting changed) or a mandatory control is off
#   2  UNEVALUATED (org unreadable / not JSON / tooling missing) — never treated as pass
#
# Usage:
#   ORG=Via-Vitae policies/check_org_security.sh            # verify
#   ORG=Via-Vitae policies/check_org_security.sh --refresh  # re-record baseline
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE="${BASELINE:-${ROOT}/policies/org-security-baseline.json}"
MODE="verify"
[[ "${1:-}" == "--refresh" ]] && MODE="refresh"

command -v gh  >/dev/null 2>&1 || { echo "ERROR: gh CLI required — UNEVALUATED" >&2; exit 2; }
command -v jq  >/dev/null 2>&1 || { echo "ERROR: jq required — UNEVALUATED" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "ERROR: git required to sign the baseline — UNEVALUATED" >&2; exit 2; }

RAW="$(gh api "orgs/${ORG}" 2>/dev/null)" || { printf 'ERROR: cannot read orgs/%s (token/scope/network) — UNEVALUATED\n' "$ORG" >&2; exit 2; }
printf '%s' "$RAW" | jq -e 'has("two_factor_requirement_enabled")' >/dev/null 2>&1 \
  || { printf 'ERROR: orgs/%s response has no two_factor_requirement_enabled — UNEVALUATED\n' "$ORG" >&2; exit 2; }

# Keys tracked as the org security baseline. Flat org fields plus two nested ones
# surfaced under explicit names so the JSON stays a plain key/value contract.
TRACK='["two_factor_requirement_enabled","default_repository_permission","default_repository_branch","members_can_delete_repositories","members_can_change_repo_visibility","members_can_create_repositories","members_can_create_public_repositories","members_can_create_private_repositories","members_can_create_internal_repositories","members_can_fork_private_repositories","members_can_invite_outside_collaborators","members_can_create_teams","web_commit_signoff_required","deploy_keys_enabled_for_repositories","readers_can_create_discussions","advanced_security_enabled_for_new_repositories","dependabot_alerts_enabled_for_new_repositories","dependabot_security_updates_enabled_for_new_repositories","dependency_graph_enabled_for_new_repositories","secret_scanning_enabled_for_new_repositories","secret_scanning_push_protection_enabled_for_new_repositories","secret_scanning_validity_checks_enabled"]'
# Build the tracked-settings object in ONE jq pass: reduce over the key list,
# then add the two nested/derived fields from the original payload.
LIVE="$(printf '%s' "$RAW" | jq -c --argjson k "$TRACK" '
  . as $o
  | reduce ($k[]) as $key ({}; . + {($key): ($o[$key] // "absent")})
  | . + {"plan.name":    ($o.plan.name // "unknown"),
         "billing_email": ($o.billing_email // "absent")}'
)"

if [[ "$MODE" == "refresh" ]]; then
  git -C "$ROOT" rev-parse HEAD >/dev/null 2>&1 || { echo "ERROR: not a git repo — cannot bind the baseline to a commit" >&2; exit 2; }
  jq -n --arg org "$ORG" --arg ts "$(date -u +%FT%TZ)" --arg sha "$(git -C "$ROOT" rev-parse HEAD)" \
        --arg actor "$(git -C "$ROOT" config user.email 2>/dev/null || echo unknown)" \
        --argjson live "$LIVE" \
        '{org:$org, recorded_at:$ts, recorded_by:$actor, repo_commit:$sha,
           source:("GET /orgs/"+$org), settings:$live}' \
    > "${BASELINE}.tmp" && mv "${BASELINE}.tmp" "$BASELINE"
  echo "BASELINE RECORDED: $BASELINE ($(jq '.settings|length' "$BASELINE") settings at $(jq -r .recorded_at "$BASELINE"))"
  echo "This file is the change record GitHub Free does not keep. Commit it with the change it describes."
  exit 0
fi

[[ -f "$BASELINE" ]] || { echo "ERROR: no baseline at $BASELINE — run --refresh (deliberately, in a commit)" >&2; exit 2; }
jq -e '.settings | type == "object"' "$BASELINE" >/dev/null 2>&1 || { echo "ERROR: malformed baseline — UNEVALUATED" >&2; exit 2; }

drift=0
printf 'Org: %s   baseline recorded: %s by %s\n' "$ORG" "$(jq -r '.recorded_at // "?"' "$BASELINE")" "$(jq -r '.recorded_by // "?"' "$BASELINE")"
while IFS=$'\t' read -r key want; do
  have="$(printf '%s' "$LIVE" | jq -r --arg k "$key" '.[$k] | tostring')"
  if [[ "$have" != "$want" ]]; then
    printf 'DRIFT  %-52s baseline=%s  live=%s\n' "$key" "$want" "$have"; drift=$((drift+1))
  fi
done < <(jq -r '.settings | to_entries[] | "\(.key)\t\(.value|tostring)"' "$BASELINE")

# Mandatory controls fail independently of the baseline: a baseline can be
# refreshed by mistake, "2FA required" must never be one of its values.
if [[ "$(printf '%s' "$LIVE" | jq -r '.two_factor_requirement_enabled')" != "true" ]]; then
  echo "FAIL   two_factor_requirement_enabled is NOT true — org-wide 2FA is off (mandatory)."
  echo "       Enable it at https://github.com/organizations/${ORG}/settings/security (the API cannot set it)."
  drift=$((drift+1))
fi

if [[ "$drift" == 0 ]]; then
  echo "OK     $(jq '.settings|length' "$BASELINE") settings match the live org ($(date -u +%FT%TZ))"
  exit 0
fi
echo "RESULT: $drift deviation(s) from the recorded baseline — review before re-recording."
exit 1
