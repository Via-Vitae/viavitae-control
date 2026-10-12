#!/usr/bin/env bash
# #############################################################################
# test_detect_drift.sh — fixture self-test for the inventory drift guardrail.
#
# A guardrail that reports its own failure as a finding is worse than no
# guardrail: an unreadable org yields live=() , which would flag EVERY declared
# repo as a ghost and point an operator at generate_inventory.sh — an empty
# inventory that plans to destroy the whole org. These cases pin the
# 0=match / 1=drift / 2=UNEVALUATED contract using a stubbed `gh`
# (no network, no org mutation).
# #############################################################################
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HERE/detect_drift.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; failn=0

# Fixture inventory: 3 declared repos, 4-space-indented keys (the real parser shape).
INV="$TMP/repos_data.tf"
cat > "$INV" <<'FIXTURE'
locals {
  repos = {
    "viavitae-alpha" = { tier = "public" }
    "viavitae-beta"  = { tier = "public" }
    "viavitae-gamma" = { tier = "private" }
  }
}
FIXTURE

put_live() { # $@ = repo names the live org reports
  mkdir -p "$TMP/bin"
  cat > "$TMP/bin/gh" <<STUB
#!/usr/bin/env bash
case "\$*" in
  *repos*) printf '%s\\n' $* ;;
esac
exit 0
STUB
  chmod +x "$TMP/bin/gh"
}

case_() { # name want_rc want_substr want_absent
  local name="$1" want="$2" want_s="$3" want_n="$4"
  local out rc
  out="$(PATH="$TMP/bin:$PATH" INVENTORY="$INV" bash "$TARGET" 2>&1)"; rc=$?
  local ok=1
  [[ "$rc" == "$want" ]] || { ok=0; echo "     rc got=$rc want=$want"; }
  [[ -z "$want_s" || "$out" == *"$want_s"* ]] || { ok=0; echo "     missing substring: $want_s"; }
  [[ -z "$want_n" || "$out" != *"$want_n"* ]] || { ok=0; echo "     FORBIDDEN substring present: $want_n"; }
  if [[ $ok == 1 ]]; then pass=$((pass+1)); echo "   PASS  $name (rc=$rc)";
  else failn=$((failn+1)); echo "   FAIL  $name"; echo "$out" | sed 's/^/         | /' | tail -6; fi
}

echo "== detect_drift.sh self-test"

put_live viavitae-alpha viavitae-beta viavitae-gamma
case_ "live matches declared -> OK"        0 "OK: inventory matches" "DRIFT"

put_live viavitae-alpha viavitae-beta viavitae-gamma viavitae-shadow
case_ "extra live repo -> SHADOW, rc=1"    1 "SHADOW" "OK: inventory matches"

put_live viavitae-alpha viavitae-beta
case_ "one declared repo missing -> GHOST, rc=1" 1 "viavitae-gamma" "viavitae-alpha"

# The critical case: an unreadable org must NOT be reported as drift.
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\necho "error connecting to api.github.com" >&2\nexit 1\n' > "$TMP/bin/gh"
chmod +x "$TMP/bin/gh"
case_ "gh fails (network/token) -> UNEVALUATED, not ghost drift" \
      2 "UNEVALUATED" "GHOST"

# An empty-but-successful read is equally dangerous.
mkdir -p "$TMP/bin"
printf '#!/usr/bin/env bash\ncase "$*" in *repos*) exit 0 ;; esac\n' > "$TMP/bin/gh"
chmod +x "$TMP/bin/gh"
case_ "org reports zero repos -> UNEVALUATED, not ghost drift" \
      2 "zero repos" "GHOST"

# Missing inventory is a parse failure, not an empty org.
put_live viavitae-alpha viavitae-beta viavitae-gamma
out="$(PATH="$TMP/bin:$PATH" INVENTORY="$TMP/nope.tf" bash "$TARGET" 2>&1)"; rc=$?
if [[ "$rc" == 2 && "$out" == *UNEVALUATED* ]]; then
  pass=$((pass+1)); echo "   PASS  missing repos_data.tf -> UNEVALUATED rc=2"
else failn=$((failn+1)); echo "   FAIL  rc=$rc ${out:0:120}"; fi

echo "RESULT: $pass passed, $failn failed"
[[ $failn == 0 ]] || exit 1
