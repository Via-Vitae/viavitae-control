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
#
# Exit codes (same contract as policies/check_org_security.sh and
# policies/enforce_sso.sh — the distinction matters for compliance):
#   0  inventory matches the live org exactly
#   1  DRIFT (shadow or ghost repos) — a real finding
#   2  UNEVALUATED — the org could not be read; NOT evidence of drift
###############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${INVENTORY:-${ROOT}/repos_data.tf}"

command -v gh >/dev/null 2>&1 \
  || { echo "ERROR: gh CLI required — UNEVALUATED" >&2; exit 2; }
[[ -f "${INVENTORY}" ]] \
  || { echo "ERROR: repos_data.tf not found at ${INVENTORY} — UNEVALUATED" >&2; exit 2; }

# Declared repo names: 4-space-indented quoted keys opening an object.
declared_txt="$(
  grep -oE '^[[:space:]]{4}"[^"]+"[[:space:]]*=[[:space:]]*\{' "${INVENTORY}" \
    | grep -oE '"[^"]+"' | tr -d '"' | grep -v '^[[:space:]]*$' | sort -u || true
)"
mapfile -t declared < <(printf '%s\n' "${declared_txt}" | grep -v '^[[:space:]]*$' || true)
# A zero-name inventory is a parse failure, not an empty org.
if [[ "${#declared[@]}" -eq 0 ]]; then
  echo "ERROR: parsed 0 declared repos from ${INVENTORY} — UNEVALUATED" >&2
  exit 2
fi

# Live repo names.
# NOTE: `mapfile -t live < <(gh api ...)` does NOT abort under `set -euo
# pipefail` when gh fails — process substitutions are outside the pipeline's
# error propagation. Without an explicit status check an outage or a bad token
# yields live=() and every declared repo is then reported as GHOST drift, which
# would send an operator to generate_inventory.sh and produce an empty inventory
# that plans to destroy the whole org. Treat an unreadable org as UNEVALUATED.
if ! live_raw="$(gh api "orgs/${ORG}/repos?per_page=100&type=all" --paginate \
                  --jq '.[].name' 2>&1)"; then
  printf 'ERROR: cannot read orgs/%s/repos — UNEVALUATED (not drift)\n' "${ORG}" >&2
  printf '       gh said: %s\n' "$(printf '%s\n' "${live_raw}" | head -1)" >&2
  exit 2
fi
mapfile -t live < <(printf '%s\n' "${live_raw}" | grep -v '^[[:space:]]*$' | sort -u)
if [[ "${#live[@]}" -eq 0 ]]; then
  printf 'ERROR: orgs/%s returned zero repos — refusing to report every repo as a ghost; UNEVALUATED\n' "${ORG}" >&2
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
