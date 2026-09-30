#!/usr/bin/env bash
# #############################################################################
# check_commit_provenance.sh — commit-msg hook
#
# Enforces a provenance trailer on every commit, per
# policies/AI_WORKFLOW_POLICY.md §3.11 and §8.
#
# A "provenance trailer" is a line consisting of EXACTLY one of:
#   ai:top | ai:mid | ai:cheap | ai:free | ai:review
#
#   ai:<tier>  -> an AI model of that tier produced (or reviewed) the change
#
# The trailer set is ai:*-ONLY; there is no non-AI escape hatch (owner decision,
# 2026-09-30). A purely manual, human-only commit uses ai:review (human-reviewed).
#
# Exit 0 = pass (or a git-generated message that is exempt).
# Exit 1 = fail (missing trailer, or an ai:<tier> with an invalid tier).
#
# LIMITATION (do not overclaim): a LOCAL commit-msg hook is bypassable with
# `git commit --no-verify` and is inactive on a fresh clone until
# `pre-commit install`. It is an early-feedback aid, NOT the authoritative
# control. Human review (policy §3.9) and CI enforcement remain the control.
#
# Usage: check_commit_provenance.sh <path-to-commit-message-file>
# Invoked by pre-commit at the commit-msg stage as:
#   bash scripts/check_commit_provenance.sh <COMMIT_EDITMSG>
# #############################################################################
set -euo pipefail

VALID_TIERS=(top mid cheap free review)

MSG_FILE="${1:-}"
if [[ -z "$MSG_FILE" || ! -f "$MSG_FILE" ]]; then
  echo "check_commit_provenance: no commit message file given (arg: '${MSG_FILE}')." >&2
  exit 1
fi

# --- Load message: drop git comment lines, trim whitespace, skip blanks ------
LINES=()
while IFS= read -r raw || [[ -n "$raw" ]]; do
  # Skip git's comment lines (lines beginning with optional space then '#').
  if [[ "$raw" =~ ^[[:space:]]*# ]]; then
    continue
  fi
  # Trim leading whitespace.
  trimmed="${raw#"${raw%%[![:space:]]*}"}"
  # Trim trailing whitespace.
  trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
  if [[ -z "$trimmed" ]]; then
    continue
  fi
  LINES+=("$trimmed")
done < "$MSG_FILE"

if [[ ${#LINES[@]} -eq 0 ]]; then
  echo "check_commit_provenance: empty commit message." >&2
  exit 1
fi

SUBJECT="${LINES[0]}"

# --- Exempt git-generated / non-authored messages ----------------------------
case "$SUBJECT" in
  'Merge '*|'Revert '*|'fixup! '*|'squash! '*|'amend! '*)
    exit 0
    ;;
esac

# --- Scan for a standalone provenance trailer --------------------------------
found_valid=0
found_invalid=0
invalid_tier=""
for line in "${LINES[@]}"; do
  if [[ "$line" =~ ^ai:([A-Za-z0-9_-]+)$ ]]; then
    tier="${BASH_REMATCH[1]}"
    tier_ok=0
    for t in "${VALID_TIERS[@]}"; do
      if [[ "$tier" == "$t" ]]; then
        tier_ok=1
        break
      fi
    done
    if [[ $tier_ok -eq 1 ]]; then
      found_valid=1
      break
    else
      found_invalid=1
      invalid_tier="$tier"
    fi
  fi
done

if [[ $found_valid -eq 1 ]]; then
  exit 0
fi

if [[ $found_invalid -eq 1 ]]; then
  echo "check_commit_provenance: INVALID tier 'ai:${invalid_tier}'." >&2
  echo "  Valid trailers: ai:top | ai:mid | ai:cheap | ai:free | ai:review" >&2
  echo "  See policies/AI_WORKFLOW_POLICY.md §3.11." >&2
  exit 1
fi

echo "check_commit_provenance: MISSING provenance trailer." >&2
echo "  Every commit must declare its origin on its own line, e.g.:" >&2
echo "    ai:top | ai:mid | ai:cheap | ai:free | ai:review" >&2
echo "  Add it as the last line of the commit message." >&2
echo "  See policies/AI_WORKFLOW_POLICY.md §3.11." >&2
exit 1
