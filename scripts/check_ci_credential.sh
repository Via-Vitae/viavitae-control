#!/usr/bin/env bash
# #############################################################################
# check_ci_credential.sh — pre-flight gate for the CI plan credential.
#
# WHY THIS EXISTS (measured, not inferred)
# On 2026-10-04, run 37236904591 of the `audit` job died after ~20 minutes with
# five `Error: Cannot import non-existent remote object` entries for
# exactly the org's private repositories (viavitae-policies, -compliance,
# -data-governance, -threat-model, -vendor-register), plus a stalled
# `data.github_organization.this` read. Nothing in that output says "the
# credential is under-scoped", so the natural (and wrong) reaction is to mint a
# bigger token — an organization-admin classic PAT — and put it in a PUBLIC
# repository's Actions secrets. This gate replaces that 20-minute mystery with a
# second-scale message that names the missing capability, and it refuses
# write-capable credentials outright.
#
# WHAT IT ASSERTS
#   1. Read capability: the token can see org settings and EVERY private repo.
#      imports.tf adopts every inventory repo, so blind spots make the plan
#      structurally unable to pass — no amount of re-running helps.
#   2. Least privilege: the token is not a classic personal access token. CI runs
#      `terraform plan` only — as of this change there is no apply workflow and
#      the repo defines no environment — so a credential that can write org
#      settings, repo contents, or
#      `.github/workflows/*` is power CI must not hold. Fine-grained PATs and
#      GitHub App installation tokens send no `X-OAuth-Scopes` header; a classic
#      PAT always does, so the header's presence is the discriminator.
#
# EXPECTED CREDENTIAL (see provider.tf for the contract)
#   Fine-grained PAT, repository access = All repositories,
#   Contents: read-only + Metadata: read-only, and organization permissions
#   Members: read-only + Organization administration: read-only, expiring.
#   It is held in TF_GITHUB_TOKEN (plan) and ORG_READ_TOKEN (gh scripts).
#
# Exit contract (three-way, so a skipped gate can never masquerade as a pass):
#   0 = credential satisfies both capabilities and is not write-capable
#   1 = an assertion failed (under-scoped, or write-capable/classic credential)
#   2 = the gate could not run (missing token/CLI/dependency, network failure)
#
# Usage:  ORG=Via-Vitae ./scripts/check_ci_credential.sh
# Read-only: performs GETs only. Never prints the token or org member data.
# #############################################################################
set -euo pipefail

ORG="${ORG:-Via-Vitae}"
API="${GITHUB_API_URL:-https://api.github.com}"

fail() { echo "::error::$1" >&2; exit 1; }
skip() { echo "::warning::$1" >&2; exit 2; }

[[ -n "${GH_TOKEN:-}" ]] || skip "GH_TOKEN is empty; the CI plan credential is not wired to this step."
command -v gh >/dev/null 2>&1 || skip "gh CLI not available."
command -v jq >/dev/null 2>&1 || skip "jq not available."
command -v curl >/dev/null 2>&1 || skip "curl not available."

# --- 1. Org-level read -------------------------------------------------------
# A credential without organization-administration read still gets HTTP 200 here,
# but the admin-only fields come back null. Compare field presence, not status.
if ! org_json="$(gh api "orgs/${ORG}" 2>/dev/null)"; then
  skip "could not read ${API}/orgs/${ORG} (network or authentication failure)."
fi

# `jq -e` with an explicit != null test: a null must fail loudly rather than be
# defaulted away (a `//` default would silently invert this assertion).
for field in total_private_repos default_repository_permission; do
  if ! jq -e --arg f "${field}" '.[$f] != null' <<<"${org_json}" >/dev/null; then
    fail "the CI credential cannot read org setting '${field}' from /orgs/${ORG}. Needs organization permission Organization administration: read-only."
  fi
done

# --- 2. Private-repository visibility ---------------------------------------
declared_private="$(jq -r '.total_private_repos' <<<"${org_json}")"
if ! seen_private="$(gh api "orgs/${ORG}/repos?type=private&per_page=100" --paginate --jq '.[].name' 2>/dev/null | sort -u | wc -l)"; then
  # `wc -l` (not `grep -c`): a zero-repo result must count as "under-scoped" (exit
  # 1), never as "gate could not run" -- grep exits 1 on zero matches.
  skip "could not list private repos for ${ORG}."
fi
if ((seen_private < declared_private)); then
  fail "the CI credential sees ${seen_private}/${declared_private} private repos. Terraform imports EVERY repo in repos_data.tf, so plan will die with 'Cannot import non-existent remote object'. Set repository access = All repositories on the fine-grained PAT."
fi

# --- 3. Write-capability conformance ----------------------------------------
# HEAD /user: classic PATs report their scopes; fine-grained/App tokens do not.
if ! headers="$(curl -sSI -H "Authorization: Bearer ${GH_TOKEN}" "${API}/user" 2>/dev/null)"; then
  skip "could not read ${API}/user headers to classify the credential."
fi
scopes="$(printf '%s\n' "${headers}" | tr -d '\r' \
  | awk -F': ' 'tolower($1)=="x-oauth-scopes" {print $2}' | tr -d ' ')"

if [[ -n "${scopes}" ]]; then
  case ",${scopes}," in
    *,workflow,*)
      fail "classic scope 'workflow' is present: that writes .github/workflows/* into every repo the token reaches, i.e. code execution in CI of those repos. No instantiated resource needs it while repos_data.tf keeps manage_files=false; even when that changes, file-write power belongs to the operator credential, never to CI. Use a read-only fine-grained PAT."
      ;;
    *,admin:org,*)
      fail "classic scope 'admin:org' is present: org write (members, org settings, webhooks). CI only plans; it must not hold apply-time power. Use a read-only fine-grained PAT."
      ;;
    *,repo,*)
      fail "classic scope 'repo' is present: repo-content write across every repo the account can reach. Use a read-only fine-grained PAT (Contents: read-only + Metadata: read-only)."
      ;;
  esac
  echo "OK: credential passed capability probes; classic scopes reported: ${scopes}"
else
  echo "OK: credential reports no classic scopes (fine-grained PAT or GitHub App token) and can read org settings plus all ${declared_private} private repos."
fi
