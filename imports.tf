# #############################################################################
# Adoption of pre-existing repositories into Terraform state (non-destructive).
#
# The org already has 30 repos. Without import, `terraform apply` would try to
# CREATE them (and fail / duplicate). These import blocks adopt each existing
# repo into state so the first plan shows no-op or benign updates — never a
# destroy-and-recreate.
#
# Import ID = the repository name (owner is supplied by the provider). Requires
# Terraform >= 1.7 for `for_each` on import blocks. Gated by var.import_existing_repos.
# #############################################################################

import {
  for_each = var.import_existing_repos ? { for k, v in local.inventory : k => k } : {}

  to = module.repo[each.key].github_repository.this
  id = each.value
}
