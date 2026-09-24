#!/usr/bin/env bash
# #############################################################################
# detect_drift.sh — CI guardrail (Approach C).
#
# Fails if the live org and the declared inventory (repos_data.tf) disagree:
#   - SHADOW: a live repo that is NOT declared  -> uncontrolled repo (fail)
#   - GHOST:  a declared repo that no longer exists -> stale inventory (fail)
#
# Exit 0 only when they match exactly. Intended to run in CI on every PR/merge.
#
# Usage:  ORG=Via-Vitae ./scripts/detect_drift.sh
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${ROOT}/repos_data.tf"

command -v gh >/dev/null 2>&1 || { echo "gh CLI required" >&2; exit 1; }
[[ -f "${INVENTORY}" ]] || { echo "repos_data.tf not found at ${INVENTORY}" >&2; exit 1; }

# Declared repo names: 4-space-indented quoted keys opening an object.
mapfile -t declared < <(
  grep -oE '^[[:space:]]{4}"[^"]+"[[:space:]]*=[[:space:]]*\{' "${INVENTORY}" \
    | grep -oE '"[^"]+"' | tr -d '"' | sort -u
)

# Live repo names.
mapfile -t live < <(
  gh api "orgs/${ORG}/repos?per_page=100&type=all" --jq '.[].name' | sort -u
)

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
