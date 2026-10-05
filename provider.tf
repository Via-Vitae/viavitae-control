# GitHub provider configuration.
#
# SECURITY — credential contract: two roles, two credentials, never one token.
#
# The token is NEVER stored in code or state; the provider reads GITHUB_TOKEN only.
#
# CI role - `.github/workflows/audit.yml` runs `terraform plan` and nothing else
# (there is no apply workflow and the repo defines no environment), so CI needs
# READ ONLY. Use a fine-grained personal access token:
#   repository access = All repositories, INCLUDING the org's private ones. A
#     fine-grained token always sees public repositories, so a private-repo blind
#     spot surfaces as "Cannot import non-existent remote object" during import
#     and never as a 403 - which is why this line used to be wrong.
#   Metadata: read-only        -> GET /repos/{owner}/{repo}, /orgs/{org}/repos,
#     ruleset reads; also satisfies the provider's configure-time org lookup.
#   Administration: read-only  -> branch protection, automated-security-fixes
#     and vulnerability-alerts, i.e. what modules/repo/ instantiates.
#   NO organization permissions. Organization administration read was only ever
#     needed to read org full-detail fields; if a root `github_organization` data
#     source is being read again, add it deliberately, not by default.
#   NO Contents, NO Workflows, NO Secrets. Contents is unnecessary while every
#     repos_data.tf entry keeps manage_files = false, and Workflows would let a
#     compromised job rewrite the CI that audits it.
# scripts/check_ci_credential.sh derives this read set from the configuration and
# fails the job on a classic PAT or any blind spot, before `terraform plan` runs.
#
# Why a classic PAT cannot satisfy the CI role: the classic scope set has no
# "read these repo settings" option. `admin:org` bundles org WRITE and `repo`
# bundles content WRITE, so any classic token able to make the plan green also
# hands an unattended job apply-time power. A fine-grained PAT is the only
# credential that can express the read this job actually needs.

# Operator role — local `terraform apply`: a separate, expiring credential held
# only in the operator's own environment.
#
# Never place an interactive credential (`gh auth token`) in CI: every run would
# act as that human, the credential could not be rotated without logging the
# human out, and this repo is PUBLIC, so every workflow run in it can read it.
# The `workflow` scope is needed only when an inventory entry sets
# manage_files = true (modules/repo/files.tf writes .github/workflows/* into the
# repo); every entry in repos_data.tf is false today, so it is dead weight.
provider "github" {
  owner = var.github_owner
  # token is read from GITHUB_TOKEN env var; do not hardcode it here.
}
