#!/usr/bin/env bash
# #############################################################################
# enforce_sso.sh — organization authentication hardening.
#
# COMPLIANCE:
#   - SOC 2 CC6.1 (logical access) / CC6.3
#   - ISO 27001 A.9.4 (secure log-on), A.9.2 (user access management)
#   - GDPR Art. 32 (security of processing)
#
# Two distinct controls:
#   1) Org-wide TWO-FACTOR requirement — available on ALL plans (incl. Free),
#      but NOT settable through the REST API. `PATCH /orgs/{org}` documents no
#      `two_factor_requirement_enabled` body parameter (the GET response schema
#      does list it, read-only), so the call returns HTTP 200 and leaves the value
#      `false` — verified twice on 2026-10-12. This script therefore DETECTS the
#      gap and refuses to claim success; enforcement is a Settings-page action.
#      Rule kept from that incident: a 200 status is not evidence of an effect;
#      only the read-back is.
#   2) SAML SSO enforcement — requires GitHub ENTERPRISE Cloud and an external
#      IdP. It has no OSS Terraform resource and cannot be fully automated
#      (IdP metadata/certificate must be configured). See sso_saml.md.
#
# SAFETY: defaults to DRY-RUN. Pass --apply to make changes. Requires GITHUB_TOKEN
# (or an authenticated `gh`). Enabling 2FA will eventually REMOVE members who do
# not enrol — verify all members have 2FA first.
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
MODE="dry-run"
[[ "${1:-}" == "--apply" ]] && MODE="apply"

log()  { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "gh CLI is required (https://cli.github.com)."
command -v jq >/dev/null 2>&1 || fail "jq is required to read the organisation settings."

log "Org:    ${ORG}"
log "Mode:   ${MODE}"

# --- Current plan + 2FA state ------------------------------------------------
# Read the org ONCE and keep "cannot check" distinct from "not compliant": an API error
# must not be reported as two_factor_requirement_enabled=false.
ORG_JSON="$(gh api "orgs/${ORG}" 2>/dev/null)" || { printf 'ERROR: cannot read orgs/%s (check GITHUB_TOKEN/scope/network) — status UNEVALUATED, not compliant.\n' "${ORG}" >&2; exit 2; }
# A malformed/unexpected body (proxy HTML page, truncated stream) is ALSO "cannot check",
# never a silent parse failure with a meaningless exit code.
printf '%s' "${ORG_JSON}" | jq -e 'has("two_factor_requirement_enabled")' >/dev/null 2>&1 \
  || { printf 'ERROR: orgs/%s response has no two_factor_requirement_enabled field — status UNEVALUATED, not compliant.\n' "${ORG}" >&2; exit 2; }
PLAN="$(printf '%s' "${ORG_JSON}" | jq -r '.plan.name // "unknown"')"
TFA="$(printf '%s' "${ORG_JSON}" | jq -r '.two_factor_requirement_enabled')"
log "Detected plan: ${PLAN}; two_factor_requirement_enabled=${TFA}"

# --- Control 1: org-wide 2FA requirement (all plans) -------------------------
if [[ "${TFA}" == "true" ]]; then
  log "2FA requirement already enabled — no action."
else
  # The API does NOT expose per-member 2FA state; the Settings page is the only source.
  log "Members (per-member 2FA state is not exposed by the API — the Settings page lists anyone who would lose access):"
  gh api "orgs/${ORG}/members?per_page=100" --jq '.[].login' | sed 's/^/  - /' || true
  log ""
  log "CANNOT be enabled via the API: PATCH /orgs/${ORG} ignores two_factor_requirement_enabled"
  log "(not a documented body parameter; the request returns 200 and the value stays false)."
  log "Enable it in the browser:"
  log "  https://github.com/organizations/${ORG}/settings/security"
  log "  -> Two-factor authentication -> 'Require two-factor authentication for everyone"
  log "     in your organization' -> Save"
  log "Precondition: every member must already have 2FA on their personal account; GitHub has"
  log "required 2FA for code-contributing accounts since 2023-03, and per-member 2FA state is"
  log "not exposed by the API, so check the Settings page (it lists who would be removed)."
  if [[ "${MODE}" == "apply" ]]; then
    # Read-back, not exit status, decides the claim.
    # Same read path as above (jq, not gh --jq) so the verification is testable and never prints a whole body.
    AFTER="$(gh api "orgs/${ORG}" 2>/dev/null | jq -r '.two_factor_requirement_enabled // "unevaluated"')"; AFTER="${AFTER:-unevaluated}"
    if [[ "${AFTER}" == "true" ]]; then
      log "2FA requirement verified ENABLED (read-back)."
    else
      fail "2FA still NOT enforced (read-back two_factor_requirement_enabled=${AFTER}). Complete the Settings-page action above and re-run; this script will not report success on a 200 alone."
    fi
  else
    log "DRY-RUN: no change attempted. Exit 0 means 'gap detected', not 'control effective'."
  fi
fi

# --- Control 2: SAML SSO (Enterprise only) -----------------------------------
if [[ "${PLAN}" == "enterprise" || "${PLAN}" == "enterprise_cloud" ]]; then
  log "Enterprise detected. SAML SSO must be configured with your IdP:"
  log "  Org Settings -> Authentication security -> Enable SAML single sign-on."
  log "  Then authorize your IdP metadata/certificate and enforce SSO."
  log "  This step is intentionally NOT automated (IdP secrets must not live in IaC)."
else
  log "SAML SSO requires GitHub Enterprise Cloud. Current plan: ${PLAN}."
  log "Recorded as a compliance gap with compensating control = org-wide 2FA above."
  log "See policies/sso_saml.md."
fi

log "Done (${MODE})."
