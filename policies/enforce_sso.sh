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
#   1) Org-wide TWO-FACTOR requirement — available on ALL plans (incl. Free).
#      Automated here via the REST API. This is the enforceable baseline today.
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

log "Org:    ${ORG}"
log "Mode:   ${MODE}"

# --- Current plan + 2FA state ------------------------------------------------
PLAN="$(gh api "orgs/${ORG}" --jq '.plan.name' 2>/dev/null || echo unknown)"
TFA="$(gh api "orgs/${ORG}" --jq '.two_factor_requirement_enabled' 2>/dev/null || echo false)"
log "Detected plan: ${PLAN}; two_factor_requirement_enabled=${TFA}"

# --- Control 1: org-wide 2FA requirement (all plans) -------------------------
if [[ "${TFA}" == "true" ]]; then
  log "2FA requirement already enabled — no action."
else
  log "Members without 2FA (they will be removed on enforcement):"
  gh api "orgs/${ORG}/members?per_page=100" --jq '.[].login' | sed 's/^/  - /' || true
  if [[ "${MODE}" == "apply" ]]; then
    log "Enabling org-wide 2FA requirement..."
    gh api -X PATCH "orgs/${ORG}" -f two_factor_requirement_enabled=true \
      >/dev/null && log "2FA requirement ENABLED." \
      || fail "Failed to enable 2FA requirement."
  else
    log "DRY-RUN: would PATCH /orgs/${ORG} two_factor_requirement_enabled=true"
    log "Re-run with --apply to enforce. Ensure every member has 2FA enrolled first."
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
