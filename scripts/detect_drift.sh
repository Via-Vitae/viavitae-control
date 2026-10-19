#!/usr/bin/env bash
# #############################################################################
# detect_drift.sh — CI guardrail (Approach C).
#
# Fails if the live org and the declared inventory (repos_data.tf) disagree:
#   - SHADOW: a live repo that is NOT declared  -> uncontrolled repo (fail)
#   - GHOST:  a declared repo that no longer exists -> stale inventory (fail)
#
# Intended to run in CI on every PR/merge. Exit 0 only when they match exactly.
#
# Exit contract (three-way, so "could not check" never becomes a drift verdict):
#   0  declared == live
#   1  drift detected (SHADOW or GHOST)
#   2  the check could not run: no gh, no credential, no inventory, or the org
#      read returned an empty list (dead token / throttling), which would
#      otherwise be reported as every declared repo being a GHOST.
#
# Usage:  ORG=Via-Vitae ./scripts/detect_drift.sh
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Overridable so scripts/test_control_guards.sh can drive it from a small fixture
# inventory offline (same convention as scripts/assert_live_controls.sh).
INVENTORY="${INVENTORY:-${ROOT}/repos_data.tf}"

command -v gh >/dev/null 2>&1 || { echo "gh CLI required" >&2; exit 2; }
[[ -f "${INVENTORY}" ]] || { echo "repos_data.tf not found at ${INVENTORY}" >&2; exit 2; }

# Which credential is answering? Named because the two possible answers look
# identical in the output but carry different evidence value: CI injects
# GITHUB_TOKEN (= the ORG_READ_TOKEN secret), while a local run silently falls
# back to the interactive keyring, whose credential is org ADMIN. A pass printed
# by a fallback run therefore says nothing about the CI credential, and must not
# be quoted as such (same ambiguity scripts/check_ci_credential.sh closes for the
# plan credential and audit.yml leaves open for this one).
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  CREDENTIAL_SOURCE="injected:GITHUB_TOKEN"
elif gh auth status >/dev/null 2>&1; then
  CREDENTIAL_SOURCE="gh-auth-fallback (interactive keyring, NOT the CI credential)"
else
  echo "no credential: set GITHUB_TOKEN or authenticate gh" >&2
  exit 2
fi
printf 'credential_source=%s\n' "${CREDENTIAL_SOURCE}"

# Declared repo names: 4-space-indented quoted keys opening an object.
mapfile -t declared < <(
  grep -oE '^[[:space:]]{4}"[^"]+"[[:space:]]*=[[:space:]]*\{' "${INVENTORY}" \
    | grep -oE '"[^"]+"' | tr -d '"' | sort -u
)

# Live repo names. The read STATUS is checked before the result is interpreted:
# `mapfile` from a process substitution does not inherit `set -e`, so an error
# inside < <(...) used to leave a partial or empty list and `comm -23` then
# flagged EVERY declared repo as GHOST - an outage indistinguishable from "all 31
# repos deleted", whose own advice (rebuild the inventory) would plan a destroy.
# stderr is kept out of the list (a gh notice on the success path would otherwise
# appear as a SHADOW repo) and re-issued only on the failure branch to report why.
fetch_live() { gh api "orgs/${ORG}/repos?per_page=100&type=all" --jq '.[].name'; }
if ! live_raw="$(fetch_live 2>/dev/null)"; then
  printf 'could not read orgs/%s/repos: %s\n' "${ORG}" \
    "$(fetch_live 2>&1 >/dev/null | tr '\n' ' ' | cut -c1-200)" >&2
  echo "refusing to compare declared inventory against a failed org read" >&2
  exit 2
fi
# `printf '%s\n' ""` emits one blank line, so an empty payload would count as a
# single (empty) repo name; blank lines are stripped before counting.
mapfile -t live < <(printf '%s\n' "${live_raw}" | sed '/^[[:space:]]*$/d' | sort -u)

# Reached only when the read SUCCEEDED and returned nothing. Legitimate for a
# genuinely empty org, which for this org (31 repos) means something is wrong, so
# it is reported as "could not evaluate" rather than as 31 GHOSTs.
if [[ "${#live[@]}" -eq 0 ]]; then
  echo "orgs/${ORG} returned no repositories on a successful read" >&2
  echo "refusing to report ${#declared[@]} GHOST repos from an empty org read" >&2
  exit 2
fi

printf 'Declared: %d   Live: %d\n' "${#declared[@]}" "${#live[@]}"

drift=0

echo "--- SHADOW repos (live but NOT declared) ---"
shadow="$(comm -13 <(printf '%s\n' "${declared[@]}") <(printf '%s\n' "${live[@]}"))"
if [[ -n "${shadow}" ]]; then
  echo "${shadow}" | sed 's/^/  ! /'
  drift=1
else
  echo "  (none)"
fi

echo "--- GHOST repos (declared but NOT live) ---"
ghost="$(comm -23 <(printf '%s\n' "${declared[@]}") <(printf '%s\n' "${live[@]}"))"
if [[ -n "${ghost}" ]]; then
  echo "${ghost}" | sed 's/^/  ! /'
  drift=1
else
  echo "  (none)"
fi

if [[ "${drift}" -ne 0 ]]; then
  echo "" >&2
  echo "DRIFT DETECTED. Reconcile repos_data.tf with the live org." >&2
  echo "Run scripts/generate_inventory.sh to rebuild the candidate inventory." >&2
  exit 1
fi

echo ""
echo "OK: inventory matches the live org (no shadow, no ghost repos)."
