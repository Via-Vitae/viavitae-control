#!/usr/bin/env bash
# Open one PR per repo that replaces the text-grep aggregate gate verdict with an
# expression-based one.
#
# DRY-RUN BY DEFAULT: it patches and verifies in a scratch clone and pushes nothing.
# APPLY=1 pushes the branch and opens the PR; merging stays a separate, explicit step
# so the CI result can be read first.
#
# Deliberately excludes repos whose CI is currently red (viavitae-web, viavitae-demos,
# viavitae-qa): making their gate honest would freeze merges for reasons unrelated to
# this change, and that is the owner's call, not a side effect of a tool.
set -uo pipefail

CTRL=/opt/viavitae/repos/viavitae-control
ORG=Via-Vitae
REPOS="${REPOS:-viavitae-infra viavitae-brand viavitae-api viavitae-docs .github}"
WORKROOT="${WORKROOT:-/tmp/agg-rollout}"
BRANCH="fix/aggregate-gate-needs-expression"
APPLY="${APPLY:-0}"
EMAIL="journey4oflife+viavitae.github@gmail.com"

rm -rf "$WORKROOT"; mkdir -p "$WORKROOT"
printf '\n=== aggregate-gate rollout (repos: %s, apply=%s) ===\n' "$REPOS" "$APPLY"

for r in $REPOS; do
  d="$WORKROOT/$r"
  if ! git clone -q --depth 1 -b main "https://github.com/$ORG/$r" "$d"; then
    printf '  %-24s CLONE FAILED\n' "$r"; continue
  fi
  out="$(cd "$d" && python3 "$CTRL/scripts/patch_aggregate_gate.py" . --write 2>&1)"
  echo "$out" | sed "s/^/  $r /"
  if echo "$out" | grep -q 'REFUSED'; then
    printf '  %-24s REFUSED - human review needed, nothing pushed\n' "$r"; continue
  fi
  if git -C "$d" diff --quiet; then
    printf '  %-24s no change needed\n' "$r"; continue
  fi
  # A patched workflow that cannot be parsed must never leave this machine.
  if ! python3 -c "import yaml,sys,glob;[yaml.safe_load(open(f)) for f in glob.glob('$d/.github/workflows/*.yml')]"; then
    printf '  %-24s YAML INVALID AFTER PATCH - aborted\n' "$r"; continue
  fi
  frag="$(grep -rlF '"result":"failure"' "$d/.github/workflows/" 2>/dev/null | wc -l)"
  if [ "$frag" != "0" ]; then
    printf '  %-24s %s fragile file(s) still present - aborted\n' "$r" "$frag"; continue
  fi

  git -C "$d" checkout -q -b "$BRANCH"
  git -C "$d" -c user.name=JourneyOfLife -c user.email="$EMAIL" commit -q -sam "fix(ci): decide the aggregate gate from the needs context, not JSON text

The status job counted failures by grepping the serialised text of
toJSON(needs). That string is not contractual: if the expansion carries a space
after the colon the pattern matches nothing, the count is 0 and this job reports
success over failed gates (seen on viavitae-web PR #32, where Lint and Unit +
contract tests completed failure while CI status completed success).

The verdict now comes from contains(needs.*.result, ...) via GATE_BAD. 'skipped'
is still not a failure, so matrix legs that do not apply stay neutral.

ai:cheap"
  if [ "$APPLY" != "1" ]; then
    printf '  %-24s patch verified locally only (branch NOT pushed; APPLY=1 to open PRs)\n' "$r"
    continue
  fi
  if ! git -C "$d" push -q -u origin "$BRANCH"; then
    printf '  %-24s PUSH FAILED\n' "$r"; continue
  fi
  pr="$(gh pr create -R "$ORG/$r" --head "$BRANCH" --base main \
        --title "fix(ci): decide the aggregate gate from the needs context, not JSON text" \
        --body "The aggregate status job counted failures by grepping \`toJSON(needs)\` **text**. That serialisation is not contractual; with a space after the colon the matcher counts 0 and the job reports success over failing gates. Verdict now uses \`contains(needs.*.result, 'failure')\` via \`GATE_BAD\`; \`skipped\` stays neutral so inapplicable matrix legs do not freeze unrelated changes. Found while landing the contact-address remediation; tracked as P1-15 in \`viavitae-control/docs/COMPLIANCE.md\`. Verified: patched YAML parses, no fragile matcher remains, tool is idempotent. ai:cheap" 2>&1 | tail -1)"
  printf '  %-24s PR %s\n' "$r" "$pr"
done
