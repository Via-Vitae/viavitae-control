# #############################################################################
# Organization data sources — read-only, used to derive alerts and assertions.
#
# two_factor_requirement_enabled is NOT IaC-settable in provider 6.13.0; it is
# exposed only as a computed attribute on the github_organization data source.
# Therefore 2FA enforcement is permanently out-of-band and requires a detective
# control, not a resource.
# #############################################################################

data "github_organization" "this" {
  name = var.github_owner
}

# Plan-time warning when 2FA is not enforced. This is a check block (Terraform >=1.5),
# which emits a warning but does not fail the plan. A hard failure would block all
# applies until a human enables 2FA out-of-band, creating a chicken-and-egg.
check "two_factor_enforcement" {
  assert {
    condition     = data.github_organization.this.two_factor_requirement_enabled
    error_message = "Org-wide 2FA is NOT enforced. Run policies/enforce_sso.sh --apply."
  }
}
