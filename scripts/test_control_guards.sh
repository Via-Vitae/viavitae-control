#!/usr/bin/env bash
# #############################################################################
# test_control_guards.sh — deterministic, OFFLINE tests for the three CI guards
# that decide whether the Audit job passes:
#   scripts/check_plan_selfcite.sh   (pure file analysis)
#   scripts/assert_live_controls.sh  (reads live branch protection via gh)
#   scripts/check_ci_credential.sh   (reads credential class + org via curl/gh)
#
# WHY. docs/COMPLIANCE.md §5.2 recorded that guards outnumber their tests ~12:1:
# only update_contact_emails.sh had a suite, and each of these three shipped a
# defect that only manual probing found (#9's parser silently dropped repos, #11
# printed OK while asserting nothing). A tool that gates merges deserves the same
# planted-failure treatment the sweep got: green is not accepted as evidence
# until the gate is shown to go RED on a fault.
#
# HOW. `gh` and `curl` are replaced with PATH shims that read fixtures from
# $FAKE_DIR. No network, no token, no live org is touched. jq and python3 are the
# real binaries (the guards parse with them). Each test sets the scenario via env
# (FAKE_ROOT_STATUS / FAKE_SCOPES / FAKE_PROBE_CODE / FAKE_PROT_ERR) and writes
# the fixtures the shim will serve.
#
# Dev-time suite (like test_contact_email_gates.sh): not wired into audit.yml,
# because it asserts the guards' LOGIC against fabricated org state, not reality.
#
# Usage:  ./scripts/test_control_guards.sh
# Exit 0 = every guard reacts correctly. 1 = a guard misbehaved. 2 = environment.
# #############################################################################
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0

for dep in jq python3 awk grep sed; do
  command -v "$dep" >/dev/null 2>&1 || { echo "missing dependency: $dep" >&2; exit 2; }
done

pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1" >&2; fail=1; }

# --- shims -------------------------------------------------------------------
SHIM="$(mktemp -d)"; FAKE_DIR="$(mktemp -d)"; export FAKE_DIR
cleanup() { rm -rf "${SHIM}" "${FAKE_DIR}"; }
trap cleanup EXIT

cat > "${SHIM}/gh" <<'SH'
#!/usr/bin/env bash
[[ "${1:-}" == "api" ]] || { echo "fake gh: unsupported: $*" >&2; exit 2; }
path="${2:-}"; shift 2 2>/dev/null || true
jqf=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jq) jqf="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done
body=""
case "${path}" in
  orgs/*)
    body="$(cat "${FAKE_DIR}/org.json" 2>/dev/null || echo '{}')" ;;
  */branches/*/protection)
    repo="$(printf '%s' "${path}" | cut -d/ -f3)"
    f="${FAKE_DIR}/protection__${repo}.json"
    if [[ -f "${f}" ]]; then body="$(cat "${f}")";
    else
      printf '{"message":"Branch protection not found","status":"%s"}\n' "${FAKE_PROT_ERR:-404}" >&2
      exit 1
    fi ;;
  repos/*)
    body='{"default_branch":"main"}' ;;
  *) body='{}' ;;
esac
if [[ -n "${jqf}" ]]; then printf '%s' "${body}" | jq -r "${jqf}"; else printf '%s' "${body}"; fi
SH

cat > "${SHIM}/curl" <<'SH'
#!/usr/bin/env bash
mode=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -D) mode="headers"; shift ;;
    -w) mode="code"; shift 2 ;;
    -o) shift 2 ;;
    -H) shift 2 ;;
    -s|-L) shift ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
case "${mode}" in
  headers)
    printf 'HTTP/1.1 %s X\r\n' "${FAKE_ROOT_STATUS:-200}"
    [[ -n "${FAKE_SCOPES:-}" ]] && printf 'X-OAuth-Scopes: %s\r\n' "${FAKE_SCOPES}"
    printf '\r\n' ;;
  code)
    printf '%s' "${FAKE_PROBE_CODE:-200}" ;;
  *) : ;;
esac
exit 0
SH
chmod +x "${SHIM}/gh" "${SHIM}/curl"
export PATH="${SHIM}:${PATH}"

# write_prot <repo> <contexts_json> <strict> <admins> <linear> <force> <del>
write_prot() {
  cat > "${FAKE_DIR}/protection__$1.json" <<EOF
{"required_status_checks":{"contexts":$2,"strict":$3},"enforce_admins":{"enabled":$4},"required_linear_history":{"enabled":$5},"allow_force_pushes":{"enabled":$6},"allow_deletions":{"enabled":$7}}
EOF
}

printf '\n=== control-guard tests (offline; shims=%s) ===\n\n' "${SHIM}"

# --- check_plan_selfcite.sh (PS) --------------------------------------------
PS="${HERE}/check_plan_selfcite.sh"
psdir="$(mktemp -d)"
cat > "${psdir}/good.md" <<'EOF'
## Compliance rationale
| Field | Value |
|---|---|
| tier | ai:reviewed |
## STOP conditions
- one clause
- two clause
EOF
# annotate with a correct explicit self-citation: rationale_rows == 1, stop_clauses == 2
printf '\nselfcite:rationale_rows=1 selfcite:stop_clauses=2\n' >> "${psdir}/good.md"
out="$("${PS}" "${psdir}/good.md" 2>&1)"; rc=$?
if [[ ${rc} -eq 0 ]]; then pass "PS1 correct self-citation passes (exit 0)"; else bad "PS1 rejected a truthful citation (exit ${rc}): ${out}"; fi

# PS2: plant a WRONG count -> must go red naming STALE ASSERTION
sed 's/selfcite:stop_clauses=2/selfcite:stop_clauses=9/' "${psdir}/good.md" > "${psdir}/stale.md"
out="$("${PS}" "${psdir}/stale.md" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'STALE ASSERTION' <<<"${out}"; then
  pass "PS2 planted wrong count trips the gate (exit 1, STALE ASSERTION)"
else bad "PS2 stayed silent on a planted stale count (exit ${rc})"; fi

# PS3: fabricated sign-off (Approved yes while Reviewer placeholder)
cat > "${psdir}/fab.md" <<'EOF'
## Compliance rationale
| Field | Value |
|---|---|
| tier | ai:reviewed |
- Approved: yes
- Reviewer: [name]
EOF
out="$("${PS}" "${psdir}/fab.md" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'FABRICATED SIGN-OFF' <<<"${out}"; then
  pass "PS3 fabricated sign-off blocked (exit 1)"
else bad "PS3 sign-off anti-fabrication did not fire (exit ${rc})"; fi

out="$("${PS}" 2>&1)"; rc=$?
if [[ ${rc} -eq 2 ]]; then pass "PS4 no args -> usage error (exit 2)"; else bad "PS4 no-args returned ${rc}, expected 2"; fi

# --- assert_live_controls.sh (AL) -------------------------------------------
AL="${HERE}/assert_live_controls.sh"
inv="$(mktemp -d)/repos_data.tf"
cat > "${inv}" <<'EOF'
locals {
  repos = {
    "viavitae-alpha" = {
      default_branch_exists = true
      required_status_checks_contexts = ["CI status", "Compliance status"]
    }
    "viavitae-beta" = {
      default_branch_exists = true
    }
    "viavitae-empty" = {
      visibility = "public"
    }
    "viavitae-ruleset" = {
      default_branch_exists = true
      enable_branch_protection = false
    }
  }
}
EOF

# alpha overrides; beta INHERITS the org default ["CI status", "Compliance status"]
# (read from the real variables.tf); empty has no default branch and ruleset is
# ruleset-governed, so neither is asserted.
printf '{}' > "${FAKE_DIR}/org.json"

# AL1: override + inherited default both match live -> exit 0
write_prot viavitae-alpha '["Compliance status", "CI status"]' true true true false false
write_prot viavitae-beta  '["CI status", "Compliance status"]' true true true false false
out="$(ORG=Via-Vitae GITHUB_TOKEN="***" INVENTORY="${inv}" "${AL}" 2>&1)"; rc=$?
if [[ ${rc} -eq 0 ]] && grep -q 'OK: every declared merge control' <<<"${out}"; then
  pass "AL1 override + inherited default both pass (exit 0)"
else bad "AL1 flagged a truthful org (exit ${rc}): ${out}"; fi

# AL2: the inherited-default repo (beta) diverges -> proves e: default IS asserted
write_prot viavitae-beta '["CI status"]' true true true false false
out="$(ORG=Via-Vitae GITHUB_TOKEN="***" INVENTORY="${inv}" "${AL}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'viavitae-beta.*DIVERGED contexts' <<<"${out}"; then
  pass "AL2 inherited-default divergence caught on beta (exit 1)"
else bad "AL2 did not assert beta's inherited default (exit ${rc})"; fi
write_prot viavitae-beta '["CI status", "Compliance status"]' true true true false false  # restore

# AL3: plant required_linear_history=false on alpha -> exit 1
write_prot viavitae-alpha '["Compliance status", "CI status"]' true true false false false
out="$(ORG=Via-Vitae GITHUB_TOKEN="***" INVENTORY="${inv}" "${AL}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'required_linear_history=false' <<<"${out}"; then
  pass "AL3 planted linear-history gap caught (exit 1)"
else bad "AL3 missed the linear-history gap (exit ${rc})"; fi
write_prot viavitae-alpha '["Compliance status", "CI status"]' true true true false false  # restore

# AL4: alpha protection 404 -> exit 1 "no classic protection"
rm -f "${FAKE_DIR}/protection__viavitae-alpha.json"
out="$(ORG=Via-Vitae GITHUB_TOKEN="***" INVENTORY="${inv}" "${AL}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q "no classic protection" <<<"${out}"; then
  pass "AL4 missing protection reported as DIVERGED (exit 1)"
else bad "AL4 did not report a 404 protection (exit ${rc})"; fi
write_prot viavitae-alpha '["Compliance status", "CI status"]' true true true false false  # restore

# AL5: coverage notice states 2 of 4 (only alpha + beta are protected)
out="$(ORG=Via-Vitae GITHUB_TOKEN="***" INVENTORY="${inv}" "${AL}" 2>&1)"; rc=$?
if grep -q 'asserting 2 of 4' <<<"${out}"; then
  pass "AL5 coverage notice is honest (asserting 2 of 4)"
else bad "AL5 coverage notice wrong (exit ${rc})"; fi

# AL6: empty (no default branch) and ruleset (protection off) repos are NOT asserted
if grep -qE 'viavitae-empty|viavitae-ruleset' <<<"${out}"; then
  bad "AL6 asserted a repo it should skip (empty or ruleset-governed)"
else pass "AL6 empty + ruleset repos correctly excluded"; fi

# --- check_ci_credential.sh (CC) --------------------------------------------
CC="${HERE}/check_ci_credential.sh"

# CC1: empty GH_TOKEN -> exit 2 (could not run, never a pass)
out="$(GH_TOKEN="" ORG=Via-Vitae "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 2 ]] && grep -qi 'GH_TOKEN is empty' <<<"${out}"; then
  pass "CC1 empty credential -> exit 2 (not a pass)"
else bad "CC1 empty credential returned ${rc}, expected 2"; fi

# CC2: write-capable scope set present -> exit 1 naming 'repo'
out="$(GH_TOKEN="***" ORG=Via-Vitae FAKE_ROOT_STATUS=200 FAKE_SCOPES="repo" "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q "'repo'" <<<"${out}"; then
  pass "CC2 write-capable scope set rejected (exit 1)"
else bad "CC2 accepted a repo-scoped token (exit ${rc})"; fi

# CC3: HTTP 401 -> exit 1 "rejected"
out="$(GH_TOKEN="***" ORG=Via-Vitae FAKE_ROOT_STATUS=401 "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -qi 'rejected (HTTP 401' <<<"${out}"; then
  pass "CC3 dead credential reported (exit 1)"
else bad "CC3 did not report a 401 (exit ${rc})"; fi

# CC4: valid fine-grained but org admin fields null -> exit 1 "cannot read org field"
printf '{"login":"Via-Vitae","total_private_repos":null,"default_repository_permission":null}' > "${FAKE_DIR}/org.json"
out="$(GH_TOKEN="***" ORG=Via-Vitae FAKE_ROOT_STATUS=200 FAKE_SCOPES="" FAKE_PROBE_CODE=200 "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'cannot read org field' <<<"${out}"; then
  pass "CC4 null org detail caught (exit 1)"
else bad "CC4 missed null org detail (exit ${rc})"; fi

# CC5: fully-scoped fine-grained, org fields present, all repos visible -> exit 0
printf '{"login":"Via-Vitae","total_private_repos":5,"default_repository_permission":"read"}' > "${FAKE_DIR}/org.json"
out="$(GH_TOKEN="***" ORG=Via-Vitae FAKE_ROOT_STATUS=200 FAKE_SCOPES="" FAKE_PROBE_CODE=200 "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 0 ]] && grep -q 'OK: CI credential' <<<"${out}"; then
  pass "CC5 correctly-scoped fine-grained credential passes (exit 0)"
else bad "CC5 rejected a valid credential (exit ${rc}): ${out}"; fi

# CC6: credential cannot see a repository (probe 404) -> exit 1 "cannot see"
out="$(GH_TOKEN="***" ORG=Via-Vitae FAKE_ROOT_STATUS=200 FAKE_SCOPES="" FAKE_PROBE_CODE=404 "${CC}" 2>&1)"; rc=$?
if [[ ${rc} -eq 1 ]] && grep -q 'cannot see' <<<"${out}"; then
  pass "CC6 invisible repositories reported (exit 1)"
else bad "CC6 did not report invisible repos (exit ${rc})"; fi

printf '\n=== control-guard tests %s ===\n' "$( [[ ${fail} -eq 0 ]] && echo 'PASSED' || echo 'FAILED' )"
[[ ${fail} -eq 0 ]] || echo "A merge-gating guard misbehaved; do not trust it until this passes." >&2
exit "${fail}"
