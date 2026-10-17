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
  for_each = var.import_existing_repos ? { for k, v in local.inventory : k => k if lookup(v, "create_new", false) != true } : {}

  to = module.repo[each.key].github_repository.this
  id = each.value
}

# Adoption of pre-existing classic branch protections. The org already carries
# hand-made protection on the default branch of every populated public repo, so
# `terraform apply` cannot CREATE it (GitHub 409 "Name already protected: main").
# These blocks adopt the existing rule so a rebuilt state re-adopts it and the plan
# shows in-place updates, never a failed create. The for_each mirrors
# modules/repo/main.tf's branch_protection_enabled predicate, so the import set is
# exactly the repos that declare a protection resource. Import ID is
# "<repository>:<pattern>" - the BPR_* node id is NOT the import id.
import {
  for_each = var.import_existing_repos ? {
    for k, v in local.repos : k => k if v.enable_branch_protection &&
    (v.default_branch_exists || v.auto_init) &&
    (v.visibility != "private" || local.effective_controls.branch_protection_private)
  } : {}

  to = module.repo[each.key].github_branch_protection.this[0]
  id = "${each.value}:${var.default_branch}"
}
