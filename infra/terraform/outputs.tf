# =============================================================================
# Terraform Outputs
# Deployment identifiers and configuration references
# =============================================================================

output "ecr_repository_url" {
  description = "The URL of the private Amazon ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "The name of the private Amazon ECR repository"
  value       = aws_ecr_repository.app.name
}

output "aws_region" {
  description = "The target AWS region"
  value       = var.aws_region
}

