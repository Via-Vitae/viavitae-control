#!/usr/bin/env bash
# #############################################################################
# test_enforce_sso.sh — self-test for policies/enforce_sso.sh using a stubbed
# `gh` that reproduces GitHub's documented behaviour exactly:
#   PATCH /orgs/{org} returns 200 and IGNORES two_factor_requirement_enabled.
# The incident this test exists to prevent (2026-10-12): the old script treated a
# 200 as success and logged "2FA requirement ENABLED." while the org stayed false.
# Fixture derived from real captured output: HTTP/2.0 200 OK + full org JSON with
# "two_factor_requirement_enabled":false, plan free, 1 member, 0 collaborators.
# #############################################################################
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HERE/enforce_sso.sh"
TMP="$(mktemp -d)"
pass=0; failn=0

mk_stub() {  # $1 = value the org GET reports for two_factor_requirement_enabled
  mkdir -p "$TMP/bin"
  # Stub emits ONLY valid JSON for an org GET (a previous version printed extra
  # lines before the JSON and made jq fail — the fixture, not the script, was wrong).
  cat > "$TMP/bin/gh" <<STUB
#!/usr/bin/env bash
args="\$*"
STATE="$1"
if [[ "\$args" == *"-X PATCH"* ]]; then
  # Real captured GitHub behaviour: HTTP 200 OK, and the field is ignored.
  printf 'HTTP/2.0 200 OK\n\n'
  printf '{"login":"Via-Vitae","two_factor_requirement_enabled":false}\n'
  exit 0
fi
if [[ "\$args" == *"members"* ]]; then printf 'JourneyOfLife\n'; exit 0; fi
printf '{"login":"Via-Vitae","type":"Organization","plan":{"name":"free"},"collaborators":0,"total_public_repos":26,"two_factor_requirement_enabled":%s}\n' "\$STATE"
exit 0
STUB
  chmod +x "$TMP/bin/gh"
}

run_case() { # $1 stub-state $2 script-args $3 expected-exit $4 must-contain $5 must-NOT-contain
  local st="$1" args="$2" want_rc="$3" want="$4" wantnot="$5" name="$6"
  mk_stub "$st"
  local out rc
  out="$(PATH="$TMP/bin:$PATH" ORG=Via-Vitae bash "$TARGET" $args 2>&1)"; rc=$?
  local ok=1
  [[ "$rc" == "$want_rc" ]] || { ok=0; echo "   rc: got $rc want $want_rc"; }
  [[ -z "$want"    || "$out" == *"$want"*    ]] || { ok=0; echo "   missing: $want"; }
  [[ -z "$wantnot" || "$out" != *"$wantnot"* ]] || { ok=0; echo "  FORBIDDEN string present: $wantnot"; }
  if [[ $ok == 1 ]]; then pass=$((pass+1)); echo "   PASS  $name (rc=$rc)"; else failn=$((failn+1)); echo "   FAIL  $name"; echo "$out" | sed 's/^/         | /' | tail -8; fi
}

echo "== enforce_sso.sh self-test"
run_case false "--apply"  1 "still NOT enforced"        "2FA requirement ENABLED." "apply mode must refuse to claim success on a silent-200"
run_case false ""         0 "CANNOT be enabled via the API" "2FA requirement ENABLED." "dry-run detects the gap without mutating"
run_case true  ""         0 "already enabled"           "still NOT enforced"       "compliant org passes quietly"
run_case true  "--apply"  0 "already enabled"           "ERROR"                    "compliant org in apply mode"

echo "== cannot-check must not look like compliance"
mkdir -p "$TMP/bin2"; printf '#!/usr/bin/env bash\nexit 1\n' > "$TMP/bin2/gh"; chmod +x "$TMP/bin2/gh"
out="$(PATH="$TMP/bin2:$PATH" ORG=Via-Vitae bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *UNEVALUATED* ]]; then pass=$((pass+1)); echo "   PASS  unreadable org exits 2 as UNEVALUATED (not false/compliant)"; else failn=$((failn+1)); echo "   FAIL  rc=$rc out=${out:0:120}"; fi

echo "== malformed response must be UNEVALUATED, not exit 5 / not compliance"
mkdir -p "$TMP/bin3"; printf '#!/usr/bin/env bash\ncase "$*" in *members*) echo JourneyOfLife; exit 0;; esac\nprintf "<!DOCTYPE html>not json at all\\n"\nexit 0\n' > "$TMP/bin3/gh"; chmod +x "$TMP/bin3/gh"
out="$(PATH="$TMP/bin3:$PATH" ORG=Via-Vitae bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *UNEVALUATED* ]]; then pass=$((pass+1)); echo "   PASS  non-JSON org response exits 2 as UNEVALUATED"; else failn=$((failn+1)); echo "   FAIL  rc=$rc out=${out:0:140}"; fi

rm -rf "$TMP"
echo "RESULT: $pass passed, $failn failed"
[[ $failn == 0 ]] || exit 1
