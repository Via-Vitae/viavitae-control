# GitHub provider configuration.
#
# SECURITY: The token is NEVER stored in code or state. Provide it via the
# GITHUB_TOKEN environment variable (or a sealed secret in CI). The token needs
# `admin:org` + `repo` + `workflow` scopes to manage organization policy and repos.
#
#   export GITHUB_TOKEN="$(gh auth token)"   # local convenience only
provider "github" {
  owner = var.github_owner
  # token is read from GITHUB_TOKEN env var; do not hardcode it here.
}
