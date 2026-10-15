#!/usr/bin/env bash
# #############################################################################
# test_check_org_security.sh — fixture self-test for the org security monitor.
#
# A monitor that cannot detect the failure it was written for is not a control.
# These cases exercise it against a stubbed `gh` (no network, no org mutation)
# using the REAL baseline shape captured 2026-10-12 (24 settings).
# #############################################################################
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HERE/check_org_security.sh"
BASE_SRC="$HERE/org-security-baseline.json"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; failn=0

# stub gh emitting an org payload; $1 = two_factor value, $2 = members_can_delete_repositories value
stub() {
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/gh" <<STUB
#!/usr/bin/env bash
a="\$*"
case "\$a" in
  *repos*|*members*) exit 0 ;;
esac
printf '{"login":"Via-Vitae","two_factor_requirement_enabled":%s,"default_repository_permission":"read","default_repository_branch":"main","members_can_delete_repositories":%s,"members_can_change_repo_visibility":true,"members_can_create_repositories":true,"members_can_create_public_repositories":true,"members_can_create_private_repositories":true,"members_can_create_internal_repositories":false,"members_can_fork_private_repositories":false,"members_can_invite_outside_collaborators":true,"members_can_create_teams":true,"web_commit_signoff_required":false,"deploy_keys_enabled_for_repositories":false,"readers_can_create_discussions":true,"advanced_security_enabled_for_new_repositories":false,"dependabot_alerts_enabled_for_new_repositories":false,"dependabot_security_updates_enabled_for_new_repositories":false,"dependency_graph_enabled_for_new_repositories":false,"secret_scanning_enabled_for_new_repositories":false,"secret_scanning_push_protection_enabled_for_new_repositories":false,"secret_scanning_validity_checks_enabled":false,"members_can_create_pages":true,"billing_email":"journey4oflife+viavitae.github@gmail.com","plan":{"name":"free"}}\n' $1 $2
STUB
  chmod +x "$TMP/bin/gh"
}

case_() { # name want_rc want_substr want_absent baseline
  local name="$1" want="$2" want_s="$3" want_n="$4" bl="$5"
  local out rc
  out="$(PATH="$TMP/bin:$PATH" BASELINE="$bl" bash "$TARGET" 2>&1)"; rc=$?
  local ok=1
  [[ "$rc" == "$want" ]] || { ok=0; echo "     rc got=$rc want=$want"; }
  [[ -z "$want_s" || "$out" == *"$want_s"* ]] || { ok=0; echo "     missing substring: $want_s"; }
  [[ -z "$want_n" || "$out" != *"$want_n"* ]] || { ok=0; echo "     FORBIDDEN substring present: $want_n"; }
  if [[ $ok == 1 ]]; then pass=$((pass+1)); echo "   PASS  $name (rc=$rc)"; else failn=$((failn+1)); echo "   FAIL  $name"; echo "$out" | sed 's/^/         | /' | tail -5; fi
}

echo "== check_org_security.sh self-test"
GOOD="$TMP/good.json"; cp "$BASE_SRC" "$GOOD"

stub true true;  case_ "baseline matches live org -> OK"                 0 "OK     24 settings match" "DRIFT" "$GOOD"
stub false true; case_ "2FA turned off behind our back -> FAIL"          1 "two_factor_requirement_enabled is NOT true" "OK     24 settings match" "$GOOD"
stub true false; case_ "repo-deletion re-enabled -> DRIFT reported"      1 "DRIFT" "OK     24 settings match" "$GOOD"
stub false false; case_ "both regressions -> still FAIL"                 1 "FAIL"  "OK     24 settings match" "$GOOD"

# unreadable org must be UNEVALUATED (2), never a silent pass
mkdir -p "$TMP/bin"; printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin/gh"; chmod +x "$TMP/bin/gh"
out="$(PATH="$TMP/bin:$PATH" BASELINE="$GOOD" bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *UNEVALUATED* ]]; then pass=$((pass+1)); echo "   PASS  unreadable org -> UNEVALUATED rc=2"; else failn=$((failn+1)); echo "   FAIL  rc=$rc ${out:0:120}"; fi

# non-JSON (proxy page) -> 2
printf '#!/usr/bin/env bash\nprintf "<!DOCTYPE html>\\n"\n' > "$TMP/bin/gh"; chmod +x "$TMP/bin/gh"
out="$(PATH="$TMP/bin:$PATH" BASELINE="$GOOD" bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *UNEVALUATED* ]]; then pass=$((pass+1)); echo "   PASS  non-JSON org payload -> UNEVALUATED rc=2"; else failn=$((failn+1)); echo "   FAIL  rc=$rc ${out:0:120}"; fi

# missing baseline -> 2 (cannot check), not 0
stub true true
out="$(PATH="$TMP/bin:$PATH" BASELINE="$TMP/nope.json" bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *"--refresh"* ]]; then pass=$((pass+1)); echo "   PASS  no baseline file -> rc=2 with the re-record instruction"; else failn=$((failn+1)); echo "   FAIL  rc=$rc ${out:0:120}"; fi

echo "RESULT: $pass passed, $failn failed"
[[ $failn == 0 ]] || exit 1
