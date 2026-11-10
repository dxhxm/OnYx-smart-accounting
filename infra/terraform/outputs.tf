# =============================================================================
# Terraform Outputs
# Deployment identifiers and configuration references
# =============================================================================

output "aws_region" {
  description = "The target AWS region"
  value       = var.aws_region
}

output "ecr_repository_url" {
  description = "The URL of the private Amazon ECR repository"
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "The name of the private Amazon ECR repository"
  value       = aws_ecr_repository.app.name
}

output "instance_id" {
  description = "The EC2 instance ID for SSM targeting and CD deployment"
  value       = aws_instance.demo_server.id
}

output "instance_public_ip" {
  description = "The public IPv4 address of the demonstration server"
  value       = aws_instance.demo_server.public_ip
}

output "app_url" {
  description = "The direct HTTP URL to the OnYx application"
  value       = "http://${aws_instance.demo_server.public_ip}:3000"
}

output "ssm_connect_command" {
  description = "AWS CLI command to start an encrypted interactive session via SSM (Zero SSH)"
  value       = "aws ssm start-session --target ${aws_instance.demo_server.id} --region ${var.aws_region}"
}

output "cicd_iam_user_name" {
  description = "The name of the dedicated CI/CD IAM service user"
  value       = aws_iam_user.cicd.name
}

output "cicd_access_key_id" {
  description = "The Access Key ID for GitHub Actions CI/CD"
  value       = aws_iam_access_key.cicd.id
  sensitive   = true
}

output "cicd_secret_access_key" {
  description = "The Secret Access Key for GitHub Actions CI/CD"
  value       = aws_iam_access_key.cicd.secret
  sensitive   = true
}

