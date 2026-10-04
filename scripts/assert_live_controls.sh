#!/usr/bin/env bash
# #############################################################################
# assert_live_controls.sh — CI guardrail: declared merge controls vs LIVE org.
#
# WHY THIS EXISTS. detect_drift.sh proves the *inventory* (which repos exist)
# matches reality. It cannot see whether a declared merge control is actually
# enforced. On 2026-10-04 a captured plan (audit-evidence/pre-apply-plan.txt,
# 2026-09-30) already showed `required_status_checks.contexts = []` on repos
# whose IaC header claimed strict status checks — the divergence was written
# down and nothing failed. A stored plan is a snapshot that rots; this script
# asks the live API every run, so a control that silently stops being enforced
# turns CI red instead of turning into documentation.
#
# WHAT IT ASSERTS, for every repo that declares required_status_checks_contexts
# in repos_data.tf (declaring an empty list is a valid assertion: "no check is
# required"):
#   1. the default branch has classic branch protection at all (404 = DIVERGED)
#   2. required status check contexts == declared list, exactly (set equality)
#   3. strict (branch must be up to date)              == true
#   4. enforce_admins                                  == true
#   5. required_linear_history                         == true
#   6. allow_force_pushes                              == false
#   7. allow_deletions                                 == false
#
# Exit codes (deliberately three-way; "could not check" is never success):
#   0  every opted-in repo matches the live org
#   1  at least one DIVERGED or ERROR line was printed
#   2  the check could not run at all (missing gh, missing token, no jq)
#
# Usage:  ORG=Via-Vitae ./scripts/assert_live_controls.sh
#         INVENTORY=/path/to/repos_data.tf  (override, for tests)
#
# LIMITS — stated, not hidden:
#   * Classic branch protection only. Repos governed by rulesets (e.g.
#     viavitae-control) are NOT covered here; assert them separately.
#   * Contexts are check-run names; for Actions that is the JOB id, not the
#     workflow name. A declared name that never reports blocks merges — that
#     outcome is correct behaviour, not a bug in this script.
#   * Parsing assumes the documented shape: repo keys at 4 spaces, the list on
#     one line. Names are unquoted by jq, so spaces inside a name are preserved;
#     a context name containing a comma would still split wrongly on comparison.
#   * jq's `//` treats false as absent, so booleans are compared with
#     `== true` rather than defaulted - otherwise `enabled: false` would read
#     as true and every invariant would produce a false alarm.
#   * PRIVATE repos cannot expose protection on the Free plan (HTTP 403); those
#     are reported as ERROR so an opt-in there cannot pass silently.
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${INVENTORY:-${ROOT}/repos_data.tf}"

command -v gh >/dev/null 2>&1 || { echo "gh CLI required" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq required" >&2; exit 2; }
[[ -f "${INVENTORY}" ]] || { echo "inventory not found: ${INVENTORY}" >&2; exit 2; }
if [[ -z "${GITHUB_TOKEN:-}" ]] && ! gh auth status >/dev/null 2>&1; then
  echo "no credential: set GITHUB_TOKEN or authenticate gh" >&2
  exit 2
fi

# Declared opt-ins: "<repo>\t<[bracketed,list]>" for blocks carrying the field.
mapfile -t DECL < <(
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]{4}"[^"]+"[[:space:]]*=[[:space:]]*\{/ {
      if (name != "" && decl != "") printf "%s\t%s\n", name, decl
      name = $0; sub(/^[[:space:]]*"/, "", name); sub(/".*$/, "", name); decl = ""; next
    }
    /^[[:space:]]*required_status_checks_contexts[[:space:]]*=/ {
      line = $0
      sub(/^[^=]*=[[:space:]]*/, "", line)
      sub(/[[:space:]]*\][[:space:]]*$/, "]", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      decl = line
    }
    END { if (name != "" && decl != "") printf "%s\t%s\n", name, decl }
  ' "${INVENTORY}"
)

if [[ "${#DECL[@]}" -eq 0 ]]; then
  echo "NOTICE: no repo declares required_status_checks_contexts - nothing asserted."
  echo "        Controls are unverified, not verified. See repos_data.tf."
  exit 0
fi

fails=0
checked=0

for entry in "${DECL[@]}"; do
  repo="${entry%%$'\t'*}"
  raw="${entry#*$'\t'}"

  # The HCL list is already valid JSON array syntax, so parse it with jq rather
  # than hand-unquoting: stripping spaces globally (an earlier version did) breaks
  # every context name that contains a space, e.g. "Action SHA pinning".
  if ! printf '%s' "${raw}" | jq -e 'type == "array"' >/dev/null 2>&1; then
    printf '%-34s %s\n' "${repo}" "ERROR  declared list is not a valid array: ${raw}"
    fails=$((fails + 1)); checked=$((checked + 1)); continue
  fi
  declared="$(printf '%s' "${raw}" | jq -r '.[]' | sort)"

  branch="$(gh api "repos/${ORG}/${repo}" --jq '.default_branch' 2>/dev/null || true)"
  if [[ -z "${branch}" ]]; then
    printf '%-34s %s\n' "${repo}" "ERROR  repo unreadable (renamed? deleted? private 403?)"
    fails=$((fails + 1)); checked=$((checked + 1)); continue
  fi

  api_path="repos/${ORG}/${repo}/branches/${branch}/protection"
  out="$(gh api "${api_path}" 2>&1)" && ok=1 || ok=0
  if [[ "${ok}" -ne 1 ]]; then
    case "${out}" in
      *'"status":"404"'*) printf '%-34s %s\n' "${repo}" "DIVERGED no classic protection on '${branch}' (404)" ;;
      *'"status":"403"'*) printf '%-34s %s\n' "${repo}" "ERROR  protection unreadable (403: private + plan tier)" ;;
      *)                 printf '%-34s %s\n' "${repo}" "ERROR  gh api failed: $(printf '%s' "${out}" | head -c 120)" ;;
    esac
    fails=$((fails + 1)); checked=$((checked + 1)); continue
  fi

  live="$(printf '%s' "${out}" | jq -r '
    ([.required_status_checks.contexts[]?] | sort | join(",")),
    (.required_status_checks.strict == true),
    (.enforce_admins.enabled == true),
    (.required_linear_history.enabled == true),
    (.allow_force_pushes.enabled == true),
    (.allow_deletions.enabled == true)
  ')"
  live_ctx="$(printf '%s' "${live}" | sed -n '1p' | tr ',' '\n' | sed '/^$/d' | sort)"
  strict="$(printf '%s' "${live}"    | sed -n '2p')"
  admins="$(printf '%s' "${live}"   | sed -n '3p')"
  linear="$(printf '%s' "${live}"   | sed -n '4p')"
  force="$(printf '%s' "${live}"    | sed -n '5p')"
  del="$(printf '%s' "${live}"      | sed -n '6p')"

  problems=()
  if [[ "${live_ctx}" != "${declared}" ]]; then
    problems+=("contexts live=[${live_ctx//$'\n'/,}] declared=[${declared//$'\n'/,}]")
  fi
  [[ "${strict}" == "true" ]] || problems+=("strict=${strict} expected true")
  [[ "${admins}" == "true" ]] || problems+=("enforce_admins=${admins} expected true")
  [[ "${linear}" == "true" ]] || problems+=("required_linear_history=${linear} expected true")
  [[ "${force}"  == "false" ]] || problems+=("allow_force_pushes=${force} expected false")
  [[ "${del}"    == "false" ]] || problems+=("allow_deletions=${del} expected false")

  checked=$((checked + 1))
  if [[ "${#problems[@]}" -eq 0 ]]; then
    printf '%-34s %s\n' "${repo}" "OK     ${raw}"
  else
    printf '%-34s %s\n' "${repo}" "DIVERGED $(printf '%s; ' "${problems[@]}")"
    fails=$((fails + 1))
  fi
done

echo ""
printf 'Asserted %d opted-in repo(s); %d diverged or unreadable.\n' "${checked}" "${fails}"

if [[ "${fails}" -ne 0 ]]; then
  echo "" >&2
  echo "LIVE ORG DOES NOT MATCH DECLARED CONTROLS." >&2
  echo "Either apply the declaration, or correct repos_data.tf to state reality." >&2
  echo "Do not delete this assertion to get a green build: red here means a" >&2
  echo "documented control is not the control in force." >&2
  exit 1
fi

echo "OK: every declared merge control is enforced in the live org."
