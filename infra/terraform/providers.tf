# =============================================================================
# AWS Provider Configuration & Mandatory Compliance Tags
# =============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OnYx-DevSecOps"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Daham"
    }
  }
}

