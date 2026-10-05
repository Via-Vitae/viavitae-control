output "two_factor_requirement_enabled" {
  description = "Whether the organization requires two-factor authentication for everyone with access to it. Computed-only in provider 6.13.0, so it is asserted, never set."
  value       = data.github_organization.this.two_factor_requirement_enabled
}
