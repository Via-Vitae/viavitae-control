#!/usr/bin/env bash
# check_startup_failures.sh — name every open PR whose workflow last concluded
# startup_failure. That failure mode creates zero jobs and zero check-runs, so the
# PR looks merely "untested" in aggregates while it is in fact permanently unrunnable.
# Contract: 0 none found, 1 at least one frozen PR (named), 2 nothing readable.
#
# WHY THIS EXISTS. The org Actions allow-list admits only the exact commits listed
# in patterns_allowed, so a Dependabot bump of pnpm/action-setup to a third commit
# is rejected at workflow PARSE time: no job starts, no check-run is created, and
# the required contexts (provenance, CI status, Compliance status) never report.
# Every aggregate view then reads the PR as "checks have not run yet". Measured
# 2026-11-03 on viavitae-qa PR #14 and viavitae-demos PR #6 — both frozen this way.
#
# Read-only: gh GETs with the operator credential. Not wired into audit.yml, because
# audit.yml's CI token is scoped to plan reads and widening a credential is a
# privilege increase (same reasoning as scripts/check_dependabot_scope.py).
set -uo pipefail

ORG="${1:-Via-Vitae}"
command -v gh >/dev/null 2>&1 || { echo "gh required" >&2; exit 2; }

repos=$(gh api "orgs/$ORG/repos" --paginate --jq '.[] | select(.archived==false) | .name' 2>/dev/null)
[[ -n "$repos" ]] || { echo "no repositories readable for $ORG — cannot report clean" >&2; exit 2; }

found=0; scanned=0; unreadable=0; noruns=0
while IFS=$'\t' read -r repo number head; do
  [[ -z "${number:-}" ]] && continue
  scanned=$((scanned + 1))
  # Capture the exit status on its own line: a failed read must count as UNKNOWN,
  # never as "no freeze found". Reading $? after another command tests the wrong
  # status, and an empty result from a broken call is not evidence of absence.
  #
  # Filtered by head_sha on purpose. `gh run list --limit 6` was the first attempt
  # and it is WRONG: a frozen PR from three weeks ago has not been in the last six
  # runs of an active repo for a long time, so the guard scanned 50 open PRs, named
  # nothing, and reported clean while viavitae-qa PR #14 sat frozen. Query the runs
  # OF THAT HEAD instead, and treat a head with no runs at all as unverified.
  status=0
  out=$(gh api "repos/$ORG/$repo/actions/runs?head_sha=$head&per_page=50" --jq '.workflow_runs[] | .conclusion' 2>/dev/null) || status=$?
  if (( status != 0 )); then
    echo "   unknown: $ORG/$repo PR #$number — runs unreadable (exit $status), not counted as clean"
    unreadable=$((unreadable + 1))
    continue
  fi
  if [[ -z "$out" ]]; then
    echo "   unverified: $ORG/$repo PR #$number — no workflow run exists for head ${head:0:8} yet"
    noruns=$((noruns + 1))
    continue
  fi
  bad=$(printf '%s\n' "$out" | grep -c '^startup_failure$' || true)
  if (( bad > 0 )); then
    echo "::error::$ORG/$repo PR #$number is frozen: $bad run(s) for its head concluded startup_failure (0 jobs, no check-runs)"
    found=$((found + 1))
  fi
done < <(for r in $repos; do
           gh pr list -R "$ORG/$r" --state open --limit 50 --json headRefOid,number \
             --jq '.[] | "'"$r"'\t\(.number)\t\(.headRefOid)"' 2>/dev/null
         done)

echo "== open PRs scanned: $scanned · frozen PRs: $found · heads with no run yet: $noruns · unreadable reads: $unreadable"
[[ $scanned -gt 0 ]] || { echo "nothing was scanned — not reporting clean" >&2; exit 2; }
if (( unreadable > 0 )); then
  echo "some reads failed — the verdict is incomplete, not clean" >&2
fi
(( found == 0 )) || exit 1
echo "OK: no open PR is in startup_failure."
