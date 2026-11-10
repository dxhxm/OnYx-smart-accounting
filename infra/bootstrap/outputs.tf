output "s3_bucket_name" {
  description = "The globally unique S3 bucket name for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "The ARN of the S3 state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "aws_region" {
  description = "The AWS region where state bucket is hosted"
  value       = var.aws_region
}

