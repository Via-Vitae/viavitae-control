# GitHub provider configuration.
#
# SECURITY — credential contract: two roles, two credentials, never one token.
#
# The token is NEVER stored in code or state; the provider reads GITHUB_TOKEN only.
#
# CI role — `.github/workflows/audit.yml` runs `terraform plan` and nothing else
# (there is no apply workflow and the repo defines no environment), so CI needs
# READ ONLY. Use a fine-grained PAT: repository access = All repositories,
# Contents: read-only + Metadata: read-only, organization permissions
# Members: read-only + Organization administration: read-only, with an expiry.
# scripts/check_ci_credential.sh enforces this in CI and fails the job on any
# write-capable credential.
#
# Why a classic PAT cannot satisfy the CI role: GitHub documents that reading an
# organization's full settings (GET /orgs/{org}) needs the `admin:org` scope for
# personal access tokens (classic), and `admin:org` BUNDLES WRITE — the classic
# scope set has no "read the organization settings" option. So making the plan
# step green with a classic PAT necessarily hands CI apply-time org power, while a
# fine-grained PAT can express `Organization administration: read` alone.
#
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
