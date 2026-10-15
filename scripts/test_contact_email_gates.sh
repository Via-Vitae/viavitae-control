#!/usr/bin/env bash
# #############################################################################
# test_contact_email_gates.sh — deterministic checks for the safety gates in
# scripts/update_contact_emails.sh.
#
# The sweep is safe only because of its gates, and every one of them rotted at
# least once while being built:
#   - a sed-driven rewrite silently matched nothing, because the PGP sentence
#     contains `[`, `(`, `.` and `/` (BRE syntax)
#   - a path exclusion anchored with `$` was applied to whole `path:num:text`
#     grep lines, so it could never match and raised false alarms
#   - the leak gate matched the detector's own BASE_INBOX pattern, so the control
#     plane reported itself as a leak
#
# NEVER invokes the sweeper's write mode: this script must not push a branch or
# open a PR. It works on throwaway clones under $WORK, on copies of single files,
# and on --check-residue, which rehearses every gate and reverts.
#
# Usage:  ./scripts/test_contact_email_gates.sh
# Exit 0 = all gates behave. 1 = a gate misbehaved — do not run the sweeper's write mode.
# #############################################################################
set -uo pipefail

ORG="${ORG:-Via-Vitae}"
PROBE_REPO="${PROBE_REPO:-viavitae-landing-diocese}"   # public, small, has SECURITY.md + CHANGELOG.md
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWEEPER="${HERE}/update_contact_emails.sh"
WORK="${WORK:-${TMPDIR:-/tmp}/vv-gate-tests}"
fail=0

grep -qE '^[^#].*--(apply|push)' "${BASH_SOURCE[0]}" && {
  echo "test script must not invoke the sweeper's write mode" >&2; exit 1; }

pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1" >&2; fail=1; }

clone_probe() { # echoes a fresh scratch dir containing $PROBE_REPO
  local d="$1"
  rm -rf "${d}"; mkdir -p "${d}"
  git clone -q --depth 1 --single-branch "https://github.com/${ORG}/${PROBE_REPO}" "${d}/${PROBE_REPO}" \
    || { echo "clone failed: ${ORG}/${PROBE_REPO}" >&2; exit 1; }
  printf '%s' "${d}"
}

printf '\n=== contact-email gate tests (org=%s repo=%s work=%s) ===\n\n' "${ORG}" "${PROBE_REPO}" "${WORK}"

# --- T0 syntax ---------------------------------------------------------------
if bash -n "${SWEEPER}"; then pass "T0 sweeper parses"; else bad "T0 sweeper syntax error"; fi

# Generate the rule artifacts exactly as the sweeper does (dry-run writes them).
GEN="$(clone_probe "${WORK}/gen")"
WORKDIR="${GEN}" "${SWEEPER}" --repos "${PROBE_REPO}" >/dev/null 2>&1
TABLE="${GEN}/contact_emails.map"; REWRITER="${GEN}/contact_emails_rewrite.py"
for f in "${TABLE}" "${REWRITER}"; do
  [[ -f "${f}" ]] || { bad "T0b sweeper did not generate $(basename "${f}")"; exit 1; }
done

# --- T1 every rule class actually fires --------------------------------------
one="$(mktemp -d)"; cp "${GEN}/${PROBE_REPO}/SECURITY.md" "${one}/SECURITY.md"
python3 "${REWRITER}" "${TABLE}" "${one}/SECURITY.md" >/dev/null 2>&1
if grep -q 'journey4oflife+viavitae.security@gmail.com' "${one}/SECURITY.md"; then
  pass "T1a address rule fired (security@viavitae.* -> +viavitae.security)"
else
  bad "T1a address rule did not fire"
fi
if grep -q 'No PGP key is published for this mailbox yet' "${one}/SECURITY.md"; then
  pass "T1b sentence rule fired (PGP claim removed — the rule sed silently skipped)"
else
  bad "T1b sentence rule did not fire: silent no-op leaves a false assurance published"
fi
if grep -qE '(security|dpo|legal|billing|privacy|platform|brand|info|support|hello)@viavitae\.[a-z]+' "${one}/SECURITY.md"; then
  bad "T1c a dead role address survives the rewrite"
else
  pass "T1c no dead role address left in the rewritten sample"
fi

# --- T2 contributor placeholder is untouched ---------------------------------
two="$(mktemp -d)"; cp "${GEN}/${PROBE_REPO}/CONTRIBUTING.md" "${two}/CONTRIBUTING.md" 2>/dev/null || true
if [[ -f "${two}/CONTRIBUTING.md" ]] && grep -q 'you@viavitae.com' "${two}/CONTRIBUTING.md"; then
  python3 "${REWRITER}" "${TABLE}" "${two}/CONTRIBUTING.md" >/dev/null 2>&1
  if grep -q 'you@viavitae.com' "${two}/CONTRIBUTING.md"; then
    pass "T2 DCO placeholder you@viavitae.com not rewritten"
  else
    bad "T2 placeholder rewritten — contributors would be told to sign off with a real org inbox"
  fi
else
  pass "T2 no placeholder in this repo's CONTRIBUTING.md (nothing to check)"
fi

# --- T3 leak gate fires on a real leak --------------------------------------
d3="$(clone_probe "${WORK}/t3")"
printf '\nData subject requests: journey4oflife@gmail.com\n' > "${d3}/${PROBE_REPO}/LEAKY.md"
WORKDIR="${d3}" "${SWEEPER}" --repos "${PROBE_REPO}" >/dev/null 2>&1
rc=$?
if [[ ${rc} -eq 1 ]]; then pass "T3 planted base-inbox leak trips the gate (exit 1)"; else bad "T3 leak gate stayed silent (exit ${rc})"; fi

# --- T4 email-allow marker suppresses a deliberate mention -------------------
d4="$(clone_probe "${WORK}/t4")"
printf '\n<!-- documented exception email-allow --> journey4oflife@gmail.com\n' \
  > "${d4}/${PROBE_REPO}/NOTES.md"
WORKDIR="${d4}" "${SWEEPER}" --repos "${PROBE_REPO}" >/dev/null 2>&1
rc=$?
if [[ ${rc} -eq 0 ]]; then pass "T4 email-allow marker honoured (exit 0)"; else bad "T4 marker ignored (exit ${rc})"; fi

# --- T5 append-only evidence stays out of the file list ----------------------
d5="$(clone_probe "${WORK}/t5")"
out5="$(WORKDIR="${d5}" "${SWEEPER}" --repos "${PROBE_REPO}" 2>&1)"
if grep -qE '^[[:space:]]+CHANGELOG\.md$' <<<"${out5}"; then
  bad "T5 CHANGELOG.md is in the sweep list — rewriting it would falsify the audit trail"
elif grep -q 'CHANGELOG' "${d5}/${PROBE_REPO}/CHANGELOG.md" 2>/dev/null \
  && grep -qE '@viavitae\.[a-z]+' "${d5}/${PROBE_REPO}/CHANGELOG.md"; then
  pass "T5 CHANGELOG.md named a dead address yet was correctly excluded"
else
  pass "T5 CHANGELOG.md excluded (and holds no dead addresses in this repo)"
fi

# --- T6 --diff is non-destructive -------------------------------------------
d6="$(clone_probe "${WORK}/t6")"
before="$(git -C "${d6}/${PROBE_REPO}" status --porcelain | wc -l)"
WORKDIR="${d6}" "${SWEEPER}" --diff --repos "${PROBE_REPO}" >/dev/null 2>&1
after="$(git -C "${d6}/${PROBE_REPO}" status --porcelain | wc -l)"
if [[ "${before}" == "${after}" && "${after}" == "0" ]]; then
  pass "T6 --diff leaves the scratch tree clean"
else
  bad "T6 --diff left ${after} modified file(s) — a later run would under-count"
fi

# --- T7 placeholder residue must NOT block (gate rehearsal, no push) ---------
d7="$(clone_probe "${WORK}/t7")"
printf '\nSigned-off-by: Your Name <you@viavitae.com>\n' >> "${d7}/${PROBE_REPO}/CONTRIBUTING.md"
WORKDIR="${d7}" "${SWEEPER}" --check-residue --repos "${PROBE_REPO}" >/dev/null 2>&1
rc=$?
if [[ ${rc} -eq 0 ]]; then pass "T7 placeholder residue does not block the gate"; else bad "T7 placeholder treated as unmapped residue (exit ${rc})"; fi

# --- T8 an address with no rule MUST block the gate --------------------------
d8="$(clone_probe "${WORK}/t8")"
printf '\nEscalate to security@viavitae.xyz\n' >> "${d8}/${PROBE_REPO}/SECURITY.md"
WORKDIR="${d8}" "${SWEEPER}" --check-residue --repos "${PROBE_REPO}" >/dev/null 2>&1
rc=$?
if [[ ${rc} -eq 1 ]]; then pass "T8 unmapped live-domain address blocks the gate (exit 1)"; else bad "T8 gate stayed silent on an unmapped address (exit ${rc})"; fi

# --- T9 gate rehearsal leaves the scratch tree untouched ---------------------
after9="$(git -C "${d8}/${PROBE_REPO}" status --porcelain | wc -l)"
if [[ "${after9}" == "0" ]]; then pass "T9 --check-residue reverted its own edits"; else bad "T9 --check-residue left ${after9} modified file(s)"; fi

printf '\n=== gate tests %s ===\n' "$( [[ ${fail} -eq 0 ]] && echo 'PASSED' || echo 'FAILED' )"
[[ ${fail} -eq 0 ]] || echo "Do not run the sweeper's write mode until these pass." >&2
exit "${fail}"
