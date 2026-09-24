# Skeleton files pushed into a repository — ONLY when manage_files = true.
#
# Pre-existing repos have manage_files = false so Terraform never overwrites
# their content. For brand-new repos set auto_init = true so the default branch
# exists before these files are committed.

locals {
  codeowners_line = "* ${join(" ", [for t in var.codeowners_teams : "@${var.owner}/${t}"])}"

  codeowners_content = <<-EOT
    # CODEOWNERS — managed declaratively by viavitae-control. DO NOT EDIT BY HAND.
    # Enforced by branch protection (require_code_owner_reviews).
    ${local.codeowners_line}
  EOT

  security_workflow_content = <<-EOT
    # Managed by viavitae-control. DO NOT EDIT BY HAND.
    # Baseline code-security workflow: CodeQL static analysis on push + PR.
    # Only allow-listed actions are used (see org_actions_policy.tf).
    name: security
    on:
      push:
        branches: [${var.default_branch}]
      pull_request:
        branches: [${var.default_branch}]
      schedule:
        - cron: '0 3 * * 1'   # weekly, Mondays 03:00 UTC
    permissions:
      contents: read
      security-events: write
    jobs:
      codeql:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: github/codeql-action/init@v3
          - uses: github/codeql-action/analyze@v3
  EOT

  readme_content = <<-EOT
    # ${var.name}

    ${var.description}

    > Managed by [`viavitae-control`](https://github.com/${var.owner}/viavitae-control).
    > Repository settings, branch protection, CODEOWNERS, and security workflow
    > are declared as code. Open a PR against viavitae-control to change them.
  EOT
}

resource "github_repository_file" "codeowners" {
  count = var.manage_files ? 1 : 0

  repository          = github_repository.this.name
  file                = ".github/CODEOWNERS"
  content             = local.codeowners_content
  branch              = var.default_branch
  commit_message      = "chore(viavitae-control): manage CODEOWNERS [skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "security_workflow" {
  count = var.manage_files ? 1 : 0

  repository          = github_repository.this.name
  file                = ".github/workflows/security.yml"
  content             = local.security_workflow_content
  branch              = var.default_branch
  commit_message      = "chore(viavitae-control): manage security workflow [skip ci]"
  overwrite_on_create = true
}

resource "github_repository_file" "readme" {
  count = var.manage_files && !var.auto_init ? 1 : 0

  repository          = github_repository.this.name
  file                = "README.md"
  content             = local.readme_content
  branch              = var.default_branch
  commit_message      = "docs(viavitae-control): add managed README [skip ci]"
  overwrite_on_create = true
}
