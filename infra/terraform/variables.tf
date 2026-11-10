# =============================================================================
# Input Variables
# =============================================================================

variable "aws_region" {
  description = "Target AWS Region for deployment"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment name (e.g., demo, staging, prod)"
  type        = string
  default     = "demo"
}

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "onyx"
}

variable "instance_type" {
  description = "EC2 instance type for demonstration server"
  type        = string
  default     = "t3.small"
}

