#!/usr/bin/env bash
# #############################################################################
# check_ci_credential.sh — pre-flight gate for the CI plan credential.
#
# WHY THIS EXISTS (measured, not inferred)
# On 2026-10-04, run 37236904591 of the `audit` job died after ~20 minutes with
# five `Error: Cannot import non-existent remote object` entries for exactly the
# org's private repositories (viavitae-policies, -compliance, -data-governance,
# -threat-model, -vendor-register). Nothing in that output says "the credential
# is under-scoped", so the natural (and wrong) reaction is to mint a bigger token
# — an organization-admin classic PAT — and put it in a PUBLIC repository's
# Actions secrets. This gate replaces that mystery with a second-scale message
# that names the missing capability, and it refuses write-capable credentials.
#
# WHAT IT ASSERTS, AND WHERE THE REQUIREMENT COMES FROM
# Every assertion is derived from THIS repository's configuration — never from a
# fixed list of privileged fields — so the gate cannot itself become a reason to
# over-scope the credential:
#
#   1. Credential class. CI only plans; there is no apply workflow and the repo
#      defines no environment. A personal access token (classic) is rejected
#      outright: the classic scope set has no "read organization settings" option
#      (`admin:org` bundles WRITE), so any classic token in this slot is either
#      under- or over-privileged by construction.
#
#      LIMIT OF THIS PROBE, STATED PLAINLY: `X-OAuth-Scopes` is present for a
#      classic PAT and absent for a fine-grained PAT or App token (measured
#      2026-10-05 against GET https://api.github.com with both endpoint choices;
#      the root also works, so a minimal fine-grained PAT with no account
#      permission is not misread as a dead credential). It therefore detects the
#      WRONG CREDENTIAL TYPE. It cannot detect that a fine-grained PAT was minted
#      with, say, Contents: write: GitHub exposes no read-only endpoint that
#      reports a token's own granted permissions, and probing for write capability
#      would mean attempting a write from CI. Fine-grained read-only-ness is
#      enforced by the mint procedure and the org's token settings, NOT by this
#      gate. What the gate can and does prove is every READ the config requires.
#   2. Organization visibility. `provider.tf` sets owner, so the provider issues
#      `GET /orgs/{ORG}` at Configure and the whole plan gates on it. This needs
#      visibility only — measured 2026-10-05 with TF_LOG=TRACE, that request fires
#      with tf_rpc=Configure whether or not any org data source is declared.
#   3. Organization full-detail fields — ONLY IF the root configuration still
#      declares `data "github_organization"` outside a count-gated module.
#      var.manage_org_data (default false) removed that dependency; asserting
#      these fields unconditionally would demand read access the config never
#      uses and push operators back toward admin:org.
#   4. Repository visibility, per repo, from repos_data.tf. `imports.tf` adopts
#      every inventory entry except `create_new = true`, so a blind spot makes the
#      plan structurally unable to pass — no amount of re-running helps. Missing
#      repos are NAMED, because "sees 26/31" does not tell you which four to add.
#
# EXPECTED CREDENTIAL (contract in provider.tf)
#   Fine-grained PAT, repository access = All repositories (the five private ones
#   must be included), permissions: Metadata: read-only + Administration:
#   read-only, expiring. NO organization permissions while var.manage_org_data is
#   false; add Organization administration: read-only only if you open it. NO
#   Contents/Workflows/Secrets while every repos_data.tf entry keeps
#   manage_files = false. Held in TF_GITHUB_TOKEN (plan) and ORG_READ_TOKEN
#   (scripts/detect_drift.sh, scripts/assert_live_controls.sh).
#
# Exit contract (three-way, so a skipped gate can never masquerade as a pass):
#   0 = credential satisfies every capability the current config needs, and is
#       not write-capable
#   1 = an assertion failed (wrong credential class, or a capability the config
#       requires is missing)
#   2 = the gate could not run (missing token/CLI/dependency, inventory absent,
#       network failure) — deliberately NOT the same answer as "passed"
#
# Usage:  ORG=Via-Vitae ./scripts/check_ci_credential.sh
# Read-only: performs GETs only. Never prints the token, org members, or secrets.
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
API="${GITHUB_API_URL:-https://api.github.com}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INVENTORY="${ROOT}/repos_data.tf"

fail() { echo "::error::$1" >&2; exit 1; }
skip() { echo "::warning::$1" >&2; exit 2; }
note() { echo "::notice::$1"; }

[[ -n "${GH_TOKEN:-}" ]] || skip "GH_TOKEN is empty; the CI plan credential is not wired to this step."
command -v gh   >/dev/null 2>&1 || skip "gh CLI not available."
command -v jq   >/dev/null 2>&1 || skip "jq not available."
command -v curl >/dev/null 2>&1 || skip "curl not available."
[[ -f "${INVENTORY}" ]] || skip "inventory not found at ${INVENTORY}; cannot derive the required read set."

# --- 1. Credential class -----------------------------------------------------
# The API root is probed rather than /user: a minimal fine-grained PAT carries no
# account permissions, so /user answers 403 for exactly the credential we WANT.
# Only `X-OAuth-Scopes` presence matters here, and the root returns it for any
# authenticated classic PAT.
if ! headers="$(curl -s -D - -o /dev/null -H "Authorization: Bearer ${GH_TOKEN}" "${API}" 2>/dev/null)"; then
  skip "could not reach ${API} to classify the credential (network failure)."
fi
status="$(printf '%s\n' "${headers}" | tr -d '\r' \
  | awk '{ if ($1 ~ /^HTTP\//) code = $2 } END { print code }' | tail -1)"
if [[ "${status}" == "401" ]]; then
  fail "the CI credential is rejected (HTTP 401 at ${API}). It is expired, revoked, or never valid; every plan step will die at provider Configure."
elif [[ "${status}" != "200" ]]; then
  skip "unexpected HTTP ${status} from ${API}; cannot classify the credential."
fi

is_classic=false
scopes="$(printf '%s\n' "${headers}" | tr -d '\r' \
  | awk -F': ' 'tolower($1)=="x-oauth-scopes" {print $2}' | tr -d ' ')"
if printf '%s\n' "${headers}" | tr -d '\r' | grep -qi '^x-oauth-scopes:'; then
  is_classic=true
fi

if [[ "${is_classic}" == "true" ]]; then
  case ",${scopes}," in
    *,workflow,*)
      fail "a classic PAT (scopes: ${scopes}) is in the CI credential slot. 'workflow' writes .github/workflows/* into every repo the token reaches — code execution in those repos' CI. No instantiated resource needs it while repos_data.tf keeps manage_files = false; file-write power belongs to the operator credential, never to CI. Mint a fine-grained PAT instead."
      ;;
    *,admin:org,*)
      fail "a classic PAT (scopes: ${scopes}) is in the CI credential slot. 'admin:org' is org WRITE (members, org settings, webhooks) — apply-time power in a PUBLIC repo's Actions secrets, and the classic scope set offers no read-only alternative. CI only plans. Mint a fine-grained PAT instead."
      ;;
    *,repo,*)
      fail "a classic PAT (scopes: ${scopes}) is in the CI credential slot. 'repo' writes repo content across every repo the account can reach, including the private compliance repos. Use a fine-grained PAT (Metadata + Administration read-only)."
      ;;
    *)
      fail "a classic PAT (scopes: '${scopes:-none}') is in the CI credential slot. Any read-only classic token is still wrong here: it cannot see private org repos without 'repo', which writes. Mint a fine-grained PAT (Metadata + Administration read-only, All repositories)."
      ;;
  esac
fi

# --- 2. Organization visibility ---------------------------------------------
# This is the one org-level requirement that cannot be gated away: the provider
# performs it while configuring itself.
if ! org_json="$(gh api "orgs/${ORG}" 2>/dev/null)"; then
  skip "could not read ${API}/orgs/${ORG} (network or authentication failure)."
fi
if ! jq -e --arg o "${ORG}" '(.login // "") == $o' <<<"${org_json}" >/dev/null; then
  fail "the CI credential cannot resolve organization '${ORG}' (GET /orgs/${ORG} returned no matching login). provider.tf sets owner = ${ORG}, so `terraform plan` dies at provider Configure before reading anything else."
fi

# --- 3. Org full-detail fields, ONLY if the config still asks for them -------
# A root-scoped grep, not modules/: modules/org_assertions declares the same data
# source behind count = var.manage_org_data ? 1 : 0, and a count of 0 is never
# read. Detecting the declaration is a config read, not a claim about behaviour.
needs_org_detail=false
if grep -qrE '^data[[:space:]]+"github_organization"' "${ROOT}"/*.tf 2>/dev/null; then
  needs_org_detail=true
fi

if [[ "${needs_org_detail}" == "true" ]]; then
  # A credential without organization-administration read still gets HTTP 200 here,
  # but the admin-only fields come back null. Compare field presence, not status.
  # `jq -e` with an explicit != null test: a null must fail loudly rather than be
  # defaulted away (a `//` default would silently invert this assertion).
  for field in total_private_repos default_repository_permission; do
    if ! jq -e --arg f "${field}" '.[$f] != null' <<<"${org_json}" >/dev/null; then
      fail "this tree reads a root github_organization data source, and the CI credential cannot read org field '${field}' (HTTP 200 with a null value, which is NOT proof of scope). Either grant organization permission Administration: read-only, or stop reading it: keep github_organization out of the root module behind a count-gated opt-in so the plan never issues that GET."
    fi
  done
elif jq -e '.total_private_repos != null' <<<"${org_json}" >/dev/null; then
  note "org full-detail fields ARE visible to this credential, but no resource in the plan graph reads a github_organization data source. If you minted Organization administration: read-only for CI, it is unused power - drop it."
fi

# --- 4. Repository visibility, derived from the declared inventory ----------
# Shape-based parse, same convention as scripts/detect_drift.sh: repo keys are
# 4-space-indented quoted names opening an object; fields are 6-space-indented.
mapfile -t import_targets < <(
  awk '
    /^[[:space:]]{4}"[^"]+"[[:space:]]*=[[:space:]]*\{/ {
      if (cur != "") order[++n] = cur
      cur = $0
      sub(/^[[:space:]]*"/, "", cur)
      sub(/".*$/, "", cur)
      create[cur] = 0
      next
    }
    cur != "" && /^[[:space:]]{6}create_new[[:space:]]*=[[:space:]]*true[[:space:]]*$/ { create[cur] = 1 }
    END {
      if (cur != "") order[++n] = cur
      for (i = 1; i <= n; i++) if (create[order[i]] == 0) print order[i]
    }
  ' "${INVENTORY}" | sort -u
)
[[ "${#import_targets[@]}" -gt 0 ]] || skip "no import targets parsed from ${INVENTORY}; refusing to report a vacuous pass."

# Status codes are read from curl, not gh: `gh api` collapses 404 (repo invisible)
# and 403 (rate limited, or an org restriction such as required 2FA) into one
# message. Reporting a throttled probe as "the credential cannot see these repos"
# would send an operator to re-scope a token that was already fine.
probe() { # url -> HTTP status code
  curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${GH_TOKEN}" "$1" 2>/dev/null || echo "000"
}

INVISIBLE=""
for repo in "${import_targets[@]}"; do
  code="$(probe "${API}/repos/${ORG}/${repo}")"
  case "${code}" in
    200) : ;;
    404) INVISIBLE+="${repo}"$'\n' ;;
    403)
      fail "probe of ${ORG}/${repo} returned HTTP 403 (forbidden), not 404. That is a rate limit or an organization access restriction, not a missing repository selection - the credential's scopes cannot be judged from here. Resolve the 403 before re-running."
      ;;
    *)
      skip "probe of ${ORG}/${repo} returned HTTP ${code}; cannot judge the credential from a server-side error."
      ;;
  esac
done

if [[ -n "${INVISIBLE}" ]]; then
  count_missing="$(printf '%s' "${INVISIBLE}" | awk 'END { print NR }')"
  { \
    echo "::error::the CI credential cannot see ${count_missing}/${#import_targets[@]} declared repositories. imports.tf adopts every entry except create_new = true, so terraform plan will die with 'Cannot import non-existent remote object' - this is not transient and re-running cannot fix it."; \
    echo "::error::Missing from the credential's view (add them, or set repository access = All repositories on the fine-grained PAT):"; \
    printf '%s' "${INVISIBLE}" | sed '/^$/d; s/^/::error::  - /'; \
  } >&2
  exit 1
fi

# A fine-grained PAT reports no X-OAuth-Scopes header, so a reach here means the
# credential declared no classic scopes at all.
note "capability probes complete: credential is not a classic PAT, can resolve /orgs/${ORG}, and can read all ${#import_targets[@]} declared repositories."
echo "OK: CI credential satisfies the read set derived from this configuration and holds no write capability."
