# #############################################################################
# Organization data sources — read-only, used to derive alerts and assertions.
#
# two_factor_requirement_enabled is NOT IaC-settable in provider 6.13.0; it is
# exposed only as a computed attribute on the github_organization data source.
# Therefore 2FA enforcement is permanently out-of-band and requires a detective
# control, not a resource.
#
# OPT-IN GATE: the assertions live in modules/org_assertions and are instantiated
# only when var.manage_org_data = true (default false). Reading organization full
# details requires a credential with organization administration access, and CI's
# job is proving repository/ruleset drift — it never needs org 2FA state. Ungated,
# every CI plan was structurally dependent on an org-admin credential sitting in a
# PUBLIC repository's Actions secrets, and this read is the one that stalled into
# `context deadline exceeded` in run 37236904591.
#
# With the gate closed the assertion runs out-of-band via
# scripts/assert_org_2fa.sh (operator credential), and control_gaps /
# p0_security_alerts report the state as UNKNOWN rather than implying it passed.
#
# WHAT THE GATE DOES NOT REMOVE: measured 2026-10-05 with TF_LOG=TRACE, `terraform
# plan` issues exactly one `GET /orgs/{org}` with tf_rpc=Configure — the provider's
# own bootstrap, because provider "github" sets owner. It fires identically with
# the gate closed and open. Gating removes the DATA SOURCE read (the admin-only
# fields), not that configure-time call, so it must not be described as making the
# plan organization-free.
# #############################################################################

module "org_assertions" {
  count  = var.manage_org_data ? 1 : 0
  source = "./modules/org_assertions"

  org = var.github_owner
}
