# #############################################################################
# Repository inventory — SOURCE OF TRUTH (Approach A)
#
# Organization: Via-Vitae  (NOT journeyoflife-org — that is a separate org with
# its own control plane). Every repository in the Via-Vitae org is declared here
# explicitly. Refresh with scripts/generate_inventory.sh and review by PR;
# scripts/detect_drift.sh fails CI if a live repo is missing from this map.
#
# NON-DESTRUCTIVE BASELINE: `visibility` reflects each repo's CURRENT live value
# (all 30 are public today). Changing a repo to private is a deliberate, staged,
# PR-reviewed edit — never automatic. `manage_files = false` means Terraform will
# NOT write CODEOWNERS/workflows into these existing repos on first apply.
#
# Fields:
#   description  = string
#   visibility   = "public" | "private" | "internal"   (current live value)
#   tier         = "control" | "platform" | "app" | "site" | "meta"
#   manage_files = bool                                (false for existing repos)
#   # Optional overrides: codeowners_teams, license_template, enable_branch_protection
#
# Via-Vitae teams (verified live): architects, compliance, dpo, legal, platform,
# security. Tier->team defaults live in locals.tf; sensitive repos override here.
# #############################################################################

locals {
  inventory = {
    # ---------------------------------------------------------------- meta ----
    ".github" = {
      description           = "Organisation-level defaults: community health files, reusable CI/CodeQL/compliance workflows, issue and PR templates for the Via-Vitae GitHub organisation."
      visibility            = "public"
      tier                  = "meta"
      manage_files          = false
      default_branch_exists = true
    }

    # ------------------------------------------------------------- control ----
    "viavitae-control" = {
      description           = "Terraform GitHub control plane — declarative source of truth for all Via-Vitae repositories and organization policy (SOC 2 / GDPR / ISO 27001)."
      visibility            = "public"
      tier                  = "control"
      manage_files          = false
      default_branch_exists = true
      # Protection for THIS repo is handled by the `protect-main` repository
      # ruleset (repo_rulesets.tf), not the module's classic branch protection.
      # Disabled here to avoid two overlapping mechanisms on the same branch.
      enable_branch_protection = false
    }
    "viavitae-compliance" = {
      description = "Via-Vitae compliance evidence and control monitoring for ISO 27001, SOC 2 and GDPR"
      # STAGED PRIVATIZATION (2026-09-24): audit evidence is confidential.
      # NOTE (Free plan): private repos lose secret scanning; branch protection
      # requires Team+.
      visibility       = "private"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["compliance", "security"]
    }
    "viavitae-data-governance" = {
      description = "Via-Vitae data governance - records of processing, retention schedules and DPIAs"
      # STAGED PRIVATIZATION (2026-09-24): GDPR Art. 9/32 — DPIAs & records of
      # processing must not be public. NOTE (Free plan): once private, GitHub
      # secret scanning is unavailable and branch protection requires Team+.
      visibility       = "private"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["dpo", "compliance", "security"]
    }
    "viavitae-policies" = {
      description = "Via-Vitae organisational policy library - governance, information security and privacy policies"
      # STAGED PRIVATIZATION (2026-09-24): internal infosec/privacy policies are
      # confidential. NOTE (Free plan): private repos lose secret scanning; branch
      # protection requires Team+.
      visibility       = "private"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["compliance", "legal", "security"]
    }
    "viavitae-vendor-register" = {
      description = "Via-Vitae vendor and sub-processor register with GDPR Article 28 due diligence"
      # STAGED PRIVATIZATION (2026-09-24): GDPR Art. 28/32 — sub-processor register
      # is confidential. NOTE (Free plan): private repos lose secret scanning;
      # branch protection requires Team+.
      visibility       = "private"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["dpo", "legal", "compliance"]
    }
    "viavitae-threat-model" = {
      description = "Via-Vitae threat models, STRIDE analysis and risk assessments"
      # STAGED PRIVATIZATION (2026-09-24): ISO 27001 A.12.6 / SOC2 CC7.1 — public
      # threat models hand attackers a roadmap. NOTE (Free plan): private repos lose
      # secret scanning; branch protection requires Team+.
      visibility       = "private"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["security", "architects"]
    }
    "viavitae-training" = {
      description      = "Via-Vitae security and compliance training material and awareness records"
      visibility       = "public"
      tier             = "control"
      manage_files     = false
      codeowners_teams = ["compliance", "security"]
    }
    "viavitae-docs" = {
      description           = ""
      visibility            = "public"
      tier                  = "control"
      manage_files          = false
      default_branch_exists = true
    }

    # ------------------------------------------------------------ platform ----
    "viavitae-infra" = {
      description           = ""
      visibility            = "public"
      tier                  = "platform"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-observability" = {
      description  = "Via-Vitae observability stack configuration - metrics, logs, traces, dashboards and alerting"
      visibility   = "public"
      tier         = "platform"
      manage_files = false
    }
    "viavitae-runbooks" = {
      description  = "Via-Vitae operational runbooks for incident response, backup/restore and disaster recovery"
      visibility   = "public"
      tier         = "platform"
      manage_files = false
    }
    "viavitae-reusable-workflows" = {
      description      = "Via-Vitae shared GitHub Actions reusable workflows for CI, compliance and security gates"
      visibility       = "public"
      tier             = "platform"
      manage_files     = false
      codeowners_teams = ["platform", "security"]
    }
    "viavitae-template" = {
      description           = ""
      visibility            = "public"
      tier                  = "platform"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-qa" = {
      description           = ""
      visibility            = "public"
      tier                  = "platform"
      manage_files          = false
      default_branch_exists = true
    }

    # ----------------------------------------------------------------- app ----
    "viavitae-api" = {
      description           = ""
      visibility            = "public"
      tier                  = "app"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-clients" = {
      description           = ""
      visibility            = "public"
      tier                  = "app"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-web" = {
      description           = "ViaVitae marketing & product website — Next.js 15 App Router, React 19, next-intl (LT/EN/RU), MDX, OpenAPI contracts"
      visibility            = "public"
      tier                  = "app"
      manage_files          = false
      default_branch_exists = true
      codeowners_teams      = ["architects", "platform"]
    }
    "viavitae-brand" = {
      description           = ""
      visibility            = "public"
      tier                  = "app"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-demos" = {
      description           = ""
      visibility            = "public"
      tier                  = "app"
      manage_files          = false
      default_branch_exists = true
    }

    # ---------------------------------------------------------------- site ----
    "viavitae-landing-basilica" = {
      description           = "ViaVitae landing page — viavitae-landing-basilica"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-cathedral" = {
      description           = "ViaVitae landing page — viavitae-landing-cathedral"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-cemetery-services" = {
      description           = "ViaVitae landing page — viavitae-landing-cemetery-services"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-churches-orthodox" = {
      description           = "ViaVitae landing page — viavitae-landing-churches-orthodox"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-churches-other" = {
      description           = "ViaVitae landing page — viavitae-landing-churches-other"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-churches-protestant" = {
      description           = "ViaVitae landing page — viavitae-landing-churches-protestant"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-deaneries" = {
      description           = "ViaVitae landing page — viavitae-landing-deaneries"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-diocese" = {
      description           = "ViaVitae landing page — viavitae-landing-diocese"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-funeral-services" = {
      description           = "ViaVitae landing page — viavitae-landing-funeral-services"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
    "viavitae-landing-parish-church" = {
      description           = "ViaVitae landing page — viavitae-landing-parish-church"
      visibility            = "public"
      tier                  = "site"
      manage_files          = false
      default_branch_exists = true
    }
  }
}
