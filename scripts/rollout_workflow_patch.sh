#!/usr/bin/env bash
# Open one PR per repository applying a workflow-patching script, with the checks that
# make it safe to run against live repositories.
#
# DRY-RUN BY DEFAULT: patches and verifies in a scratch clone and pushes nothing.
# APPLY=1 pushes the branch and opens the PR; merging stays a separate, explicit step
# so each repository's own CI result can be read before main moves.
#
#   REPOS="a b" PATCHER=scripts/patch_codeql_detect.py \
#     BRANCH=fix/codeql-detected-languages \
#     TITLE='fix(ci): detect CodeQL languages instead of asserting them' \
#     BODY='...' VERIFY_ABSENT='language: \["' \
#     APPLY=1 bash scripts/rollout_workflow_patch.sh
#
# A repository is skipped (nothing pushed) when the patcher refuses, when the patched
# YAML does not parse, or when VERIFY_ABSENT still matches.
set -uo pipefail

CTRL=/opt/viavitae/repos/viavitae-control
ORG="${ORG:-Via-Vitae}"
REPOS="${REPOS:?set REPOS to a space-separated list of repositories}"
PATCHER="${PATCHER:?set PATCHER to the patch script to run}"
BRANCH="${BRANCH:?set BRANCH to the branch name}"
TITLE="${TITLE:?set TITLE for the commit and pull request}"
BODY="${BODY:?set BODY for the pull request description}"
COMMIT_BODY="${COMMIT_BODY:-$TITLE}"
# A fixed-string pattern that must NOT survive in .github/workflows after patching.
VERIFY_ABSENT="${VERIFY_ABSENT:-}"
WORKROOT="${WORKROOT:-/tmp/workflow-rollout}"
APPLY="${APPLY:-0}"
EMAIL="journey4oflife+viavitae.github@gmail.com"

rm -rf "$WORKROOT"; mkdir -p "$WORKROOT"
printf '\n=== workflow rollout (%s) repos: %s, apply=%s ===\n' "$(basename "$PATCHER")" "$REPOS" "$APPLY"

merged=0; held=0
for r in $REPOS; do
  d="$WORKROOT/$r"
  if ! git clone -q --depth 1 -b main "https://github.com/$ORG/$r" "$d"; then
    printf '  %-34s CLONE FAILED\n' "$r"; held=$((held+1)); continue
  fi
  out="$(python3 "$CTRL/$PATCHER" "$d" --write 2>&1)"
  echo "$out" | sed "s/^/  $r /"
  if echo "$out" | grep -q 'REFUSED'; then
    printf '  %-34s REFUSED - human review needed, nothing pushed\n' "$r"; held=$((held+1)); continue
  fi
  if git -C "$d" diff --quiet; then
    printf '  %-34s already correct, no PR\n' "$r"; merged=$((merged+1)); continue
  fi
  if ! python3 -c "import yaml,glob,sys;[yaml.safe_load(open(f)) for f in glob.glob('$d/.github/workflows/*.yml')]"; then
    printf '  %-34s YAML INVALID AFTER PATCH - aborted\n' "$r"; held=$((held+1)); continue
  fi
  if [ -n "$VERIFY_ABSENT" ] && grep -rqF "$VERIFY_ABSENT" "$d/.github/workflows/"; then
    printf '  %-34s %q still present after patch - aborted\n' "$r" "$VERIFY_ABSENT"; held=$((held+1)); continue
  fi

  git -C "$d" checkout -q -b "$BRANCH"
  git -C "$d" -c user.name=JourneyOfLife -c user.email="$EMAIL" commit -q -sam \
    "$(printf '%s\n\n%s\n\nai:cheap' "$TITLE" "$COMMIT_BODY")"
  if [ "$APPLY" != "1" ]; then
    printf '  %-34s verified locally only (branch NOT pushed; APPLY=1 to open PR)\n' "$r"
    continue
  fi
  if ! git -C "$d" push -q -u origin "$BRANCH"; then
    printf '  %-34s PUSH FAILED\n' "$r"; held=$((held+1)); continue
  fi
  pr="$(gh pr create -R "$ORG/$r" --head "$BRANCH" --base main --title "$TITLE" --body "$BODY" 2>&1 | tail -1)"
  printf '  %-34s %s\n' "$r" "$pr"
  merged=$((merged+1))
done
printf '\n=== opened/no-op: %s   held: %s ===\n' "$merged" "$held"
