#!/usr/bin/env bash
# #############################################################################
# check_plan_selfcite.sh — fail when a plan document lies about itself.
#
# WHY. A plan's review checklist asserts counts about its own sections ("STOP
# conditions — section present, 7 clauses"). Nothing validates that number, so the
# first amendment that adds a clause turns the checklist into a false statement
# while every existing gate stays green. This repo already has the disease in
# another organ: audit-evidence/pre-apply-plan.txt recorded a real divergence and
# no assertion ever checked it. Same failure mode, different artifact.
#
# CONTRACT. Two assertion forms are recognised:
#   explicit   selfcite:<metric>=<n>            (preferred, unambiguous)
#   prose      **Plan includes STOP conditions** — section present, 8 clauses
#              … 24 open and 7 completed …
# A prose assertion is matched to a metric by keyword; if a line contains a
# number next to a metric keyword, it MUST equal the recomputed value.
#
# It also enforces one anti-fabrication rule: `Approved:` may not claim a yes
# while `Reviewer:` is still an unfilled bracket placeholder.
#
# Exit codes (three-way on purpose — an unchecked file is not a pass):
#   0  every assertion in every argument matched the recomputed metric
#   1  at least one mismatch, or a fabricated sign-off
#   2  usage/environment error (no files, unreadable, no awk)
#
# ADVISORY only, never fatal: a contradiction scan that reports identifiers
# described both as unverified and as verified. Heuristics must not be able to
# break a build; they are printed so a human can decide.
#
# Two false positives were found by testing this script and are guarded above:
#   * a |---|---| separator is made of pipes too, so the row filter must allow
#     '|' in the exclusion class or every header separator counts as a data row;
#   * TEMPLATE.md legitimately shows `Approved: [yes/no]` as an illustrative menu,
#     which is not an assertion of approval.
#   * This gate detects ROT (a citation stale after an amendment). It cannot detect
#     an assertion that was wrong but internally consistent when written.
#
# NOT checked here: `Plan: N to import …` deltas. Those describe Terraform output
# and are verified at apply time by plan review and by assert_live_controls.sh.
#
# Usage:  ./scripts/check_plan_selfcite.sh docs/superpowers/plans/*.md
# #############################################################################
set -euo pipefail

command -v awk >/dev/null 2>&1 || { echo "awk required" >&2; exit 2; }
[[ $# -ge 1 ]] || { echo "usage: $0 <plan.md> [...]" >&2; exit 2; }

# Table rows are counted as: any pipe-led line that is neither the header row
# nor the |---| separator. Excluding by "| " would delete every data row.
# metric -> computed value (filled per file)
declare -A M
fail=0
warn=0

recompute() {
  local f="$1"
  M=()
  M[stop_clauses]=$(awk '/^## .*STOP conditions/{s=1;next} /^## /{s=0} s&&/^- /{c++} END{print c+0}' "$f")
  M[halt_clauses]=$(awk '/^## .*Halt-and-report/{s=1;next} /^## /{s=0} s&&/^- /{c++} END{print c+0}' "$f")
  M[evidence_bullets]=$(awk '/^## .*Evidence base/{s=1;next} /^## /{s=0} s&&/^- /{c++} END{print c+0}' "$f")
  M[rationale_rows]=$(awk '/^## .*Compliance rationale/{s=1;next} /^## /{s=0} s&&/^[[:space:]]*\|/&&!/^[[:space:]]*\|[[:space:]:|-]+$/&&!/^[[:space:]]*\| Field /{c++} END{print c+0}' "$f")
  M[file_rows]=$(awk '/^## .*File structure/{s=1;next} /^## /{s=0} s&&/^[[:space:]]*\|/&&!/^[[:space:]]*\|[[:space:]:|-]+$/&&!/^[[:space:]]*\| Action /{c++} END{print c+0}' "$f")
  M[tier_rows]=$(awk '/^## .*Tier routing/{s=1;next} /^## /{s=0} s&&/^[[:space:]]*\|/&&!/^[[:space:]]*\|[[:space:]:|-]+$/&&!/^[[:space:]]*\| Task /{c++} END{print c+0}' "$f")
  M[tasks_open]=$(grep -cE '^- \[ \] ' "$f" || true)
  M[tasks_done]=$(grep -cE '^- \[x\] ' "$f" || true)
}

check_assertions() {
  local f="$1" line key want got n=0
  while IFS= read -r line; do
    # explicit form: selfcite:<metric>=<n>
    while read -r key want; do
      [[ -z "${key:-}" ]] && continue
      n=$((n + 1))
      got="${M[$key]:-}"
      if [[ -z "$got" ]]; then
        printf '  %s:%s UNKNOWN metric "%s" (typo or new section) - NOT a pass\n' "$f" "${LINENO:-?}" "$key" >&2
        fail=1; continue
      fi
      if [[ "$got" != "$want" ]]; then
        printf '  %s STALE ASSERTION %s: asserted %s, recomputed %s\n' "$f" "$key" "$want" "$got" >&2
        fail=1
      fi
    done < <(printf '%s\n' "$line" | grep -oE 'selfcite:[a-z_]+=[0-9]+' | sed -E 's/selfcite:([a-z_]+)=([0-9]+)/\1 \2/')

    # prose forms, mapped by keyword
    for kw in 'STOP conditions:stop_clauses' 'Halt-and-report triggers:halt_clauses' \
              'compliance rationale:rationale_rows' 'File structure:file_rows' \
              'Tier routing:tier_rows' 'Evidence base:evidence_bullets'; do
      local label="${kw%%:*}" mkey="${kw##*:}"
      if printf '%s' "$line" | grep -qiE "$label" && printf '%s' "$line" | grep -qE '[0-9]+ *(clause|field|row|entry|entries|bullet|item)'; then
        want=$(printf '%s' "$line" | grep -oE '[0-9]+ *(clause|field|row|entry|entries|bullet|item)' | grep -oE '^[0-9]+' | head -1)
        n=$((n + 1))
        got="${M[$mkey]:-}"
        if [[ "$want" != "$got" ]]; then
          printf '  %s STALE ASSERTION %s: asserted %s, recomputed %s\n     | %s\n' "$f" "$label" "$want" "$got" "$(printf '%s' "$line" | sed 's/^ *//')" >&2
          fail=1
        fi
      fi
    done

    # checklist arithmetic: "N open and M completed"
    if printf '%s' "$line" | grep -qE '[0-9]+ open and [0-9]+ completed'; then
      local a b
      a=$(printf '%s' "$line" | sed -E 's/.*[^0-9]([0-9]+) open and ([0-9]+) completed.*/\1/')
      b=$(printf '%s' "$line" | sed -E 's/.*[^0-9]([0-9]+) open and ([0-9]+) completed.*/\2/')
      n=$((n + 1))
      if [[ "$a" != "${M[tasks_open]}" || "$b" != "${M[tasks_done]}" ]]; then
        printf '  %s STALE ASSERTION checkbox counts: asserted %s open / %s completed, recomputed %s / %s\n' "$f" "$a" "$b" "${M[tasks_open]}" "${M[tasks_done]}" >&2
        fail=1
      fi
    fi
  done < <(grep -nE 'selfcite:|clause|field| row|open and .* completed|bullet' "$f" | sed 's/^[0-9]*://')

  if [[ "$n" -eq 0 ]]; then
    printf '  %s: 0 assertions - nothing to verify (NOT evidence of conformance)\n' "$f"
  else
    printf '  %s: %d assertion(s) recomputed and compared\n' "$f" "$n"
  fi
  return 0
}

check_signoff() {
  local f="$1" appr rev
  appr=$(grep -E '^\- Approved:' "$f" | head -1 || true)
  rev=$(grep -E '^\- Reviewer:' "$f" | head -1 || true)
  # Only a real assertion of approval counts. "[yes/no]" is a menu of options in
  # TEMPLATE.md, not a claim, so alternatives are excluded explicitly.
  if printf '%s' "$appr" | grep -qiE 'yes' && ! printf '%s' "$appr" | grep -qE 'yes/no|\[yes/no\]' \
     && printf '%s' "$rev" | grep -qE '\['; then
    printf '  %s FABRICATED SIGN-OFF: Approved claims yes while Reviewer is still a placeholder: %s\n' "$f" "$rev" >&2
    fail=1
  fi
}

advisory_contradictions() {
  local f="$1"
  if grep -qiE 'unverified|not verified|cannot be demonstrated' "$f" && grep -qE 'VERIFIED' "$f"; then
    printf '  %s ADVISORY: the document contains both "unverified/not verified" and "VERIFIED" wording; check they refer to different things:\n' "$f"
    grep -niE 'unverified|not verified|VERIFIED' "$f" | sed 's/^/     /' | head -8
    warn=$((warn + 1))
  fi
}

for f in "$@"; do
  [[ -r "$f" ]] || { printf 'unreadable: %s\n' "$f" >&2; fail=1; continue; }
  printf 'checking %s\n' "$f"
  recompute "$f"
  check_assertions "$f"
  check_signoff "$f"
  advisory_contradictions "$f"
done

if [[ "$fail" -ne 0 ]]; then
  echo "" >&2
  echo "SELF-CITATION CHECK FAILED: a plan asserts a number about itself that no" >&2
  echo "longer holds. Fix the citation, or fix the document it describes." >&2
  exit 1
fi
echo "OK: every self-citation matches the recomputed structure (${warn} advisory note(s))."
