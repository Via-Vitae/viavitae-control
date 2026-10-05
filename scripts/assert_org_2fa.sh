#!/usr/bin/env bash
# #############################################################################
# assert_org_2fa.sh — detective control for org-wide 2FA enforcement.
#
# WHY THIS EXISTS: two_factor_requirement_enabled is computed-only in provider
# 6.13.0 AND readable only by a credential with organization administration
# access. Terraform no longer reads it during CI plan (var.manage_org_data
# defaults to false), so the assertion has to live somewhere else. This is that
# place: a read-only check an operator runs with their own credential.
#
# It is DETECTIVE: it reports state and changes nothing. To change the state use
# policies/enforce_sso.sh --apply.
#
# FAILURE-MODE SEPARATION: GET /orgs/{ORG} returns HTTP 200 even to a credential
# that cannot see admin-only fields; those fields simply come back null. Collapsing
# "cannot read" into "false" would assert the opposite of reality, so the three
# outcomes are kept apart. (policies/enforce_sso.sh does collapse them today with
# `|| echo false`; that is a pre-existing conflation and is deliberately NOT
# touched here.)
#
# Exit contract (three-way, so an unrunnable check is never read as a pass):
#   0 = 2FA is enforced
#   1 = 2FA is NOT enforced
#   2 = could not determine (no CLI/token, network, or token cannot read the field)
#
# Usage:  ORG=Via-Vitae ./scripts/assert_org_2fa.sh
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"

log() { printf '[%s] %s\n' "$(date -u +%FT%TZ)" "$*"; }
unknown() { printf '::warning::%s\n' "$*" >&2; exit 2; }

command -v gh >/dev/null 2>&1 || unknown "gh CLI is required (https://cli.github.com)."
command -v jq >/dev/null 2>&1 || unknown "jq is required."

if ! org_json="$(gh api "orgs/${ORG}" 2>/dev/null)"; then
  unknown "could not read /orgs/${ORG} (authentication or network failure)."
fi

# `jq -e` with an explicit != null test: a null must fail loudly rather than be
# defaulted into a boolean assertion.
if ! jq -e '.two_factor_requirement_enabled != null' <<<"${org_json}" >/dev/null; then
  unknown "the credential reaches /orgs/${ORG} but cannot read two_factor_requirement_enabled. HTTP 200 is not proof of scope: organization full details need organization administration read."
fi

if jq -e '.two_factor_requirement_enabled' <<<"${org_json}" >/dev/null; then
  log "OK: org-wide 2FA IS enforced for ${ORG}."
  exit 0
fi

log "FAIL: org-wide 2FA is NOT enforced for ${ORG}. Enrol every member first, then run policies/enforce_sso.sh --apply."
exit 1
