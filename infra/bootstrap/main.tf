terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OnYx-DevSecOps"
      Environment = "bootstrap"
      ManagedBy   = "Terraform"
      Owner       = "Daham"
    }
  }
}

variable "aws_region" {
  description = "AWS region for Terraform state storage"
  type        = string
  default     = "ap-southeast-2"
}

# Globally unique S3 bucket to store Terraform state files remotely
resource "aws_s3_bucket" "terraform_state" {
  bucket = "onyx-devsecops-tfstate-797661819601"

  # Protect the state bucket from accidental deletion
  lifecycle {
    prevent_destroy = true
  }
}

# Enable S3 bucket versioning for rollback capability on state corruption
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce Server-Side Encryption (AES-256) for all state objects
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block 100% of public access (Crucial DevSecOps Security Boundary)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

