# #############################################################################
# org_assertions — plan-time assertions about organization-level state.
#
# Everything in here reads ORGANIZATION-OWNER-ONLY fields. GET /orgs/{org} answers
# HTTP 200 for any authenticated caller, but two_factor_requirement_enabled and
# the rest of the full-detail block are populated only for a credential with
# organization administration read. A credential that cannot see them gets null,
# NOT an error — which is why reachability must be asserted on the instance
# existing, never on a status code.
#
# The root instantiates this module only when var.manage_org_data = true. When it
# is not instantiated, no github_organization DATA SOURCE read happens, so the plan
# never depends on the organization full-detail fields.
#
# SCOPE OF THAT CLAIM (measured 2026-10-05, TF_LOG=TRACE): the plan still issues
# exactly one `GET /orgs/{org}` with tf_rpc=Configure, with the gate closed and
# open alike. That call comes from the provider's own configuration, because
# provider "github" sets owner = var.github_owner; it is NOT this module. What the
# gate removes is the dependency on organization ADMIN-ONLY fields, not all
# organization traffic.
# #############################################################################

data "github_organization" "this" {
  name = var.org
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
