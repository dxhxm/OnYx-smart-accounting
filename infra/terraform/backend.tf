# =============================================================================
# Terraform Remote State Backend
# Stores state in private S3 bucket with native state locking (Terraform 1.10+)
# =============================================================================

terraform {
  backend "s3" {
    bucket       = "onyx-devsecops-tfstate-797661819601"
    key          = "demo/terraform.tfstate"
    region       = "ap-southeast-2"
    encrypt      = true
    use_lockfile = true
  }
}

