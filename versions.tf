terraform {
  # Floor raised from "~> 1.9" to ">= 1.10" on 2026-10-13. S3 native state locking
  # (`use_lockfile`) does not exist before Terraform 1.10, so the old constraint let a
  # 1.9 operator initialise a backend with NO locking while the docs claimed locking was
  # in place (C13c). Runtime is pinned to 1.16.1 (.terraform-version) and CI pins the
  # same version (audit.yml), so this only rejects a version nobody is meant to use.
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.6"
    }
  }
}
