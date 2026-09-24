output "name" {
  description = "Repository name."
  value       = github_repository.this.name
}

output "full_name" {
  description = "Fully-qualified repository name (owner/repo)."
  value       = github_repository.this.full_name
}

output "node_id" {
  description = "GraphQL node ID of the repository."
  value       = github_repository.this.node_id
}

output "html_url" {
  description = "Web URL of the repository."
  value       = github_repository.this.html_url
}

output "visibility" {
  description = "Effective visibility."
  value       = github_repository.this.visibility
}

output "branch_protection_enabled" {
  description = "Whether branch protection was applied (resolved against plan tier)."
  value       = local.branch_protection_enabled
}

output "files_managed" {
  description = "Whether CODEOWNERS/security workflow/README are managed by Terraform."
  value       = var.manage_files
}
