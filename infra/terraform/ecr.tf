# =============================================================================
# Amazon Elastic Container Registry (ECR)
# Private, encrypted container repository with automated vulnerability scanning
# =============================================================================

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  # Security: Enable AWS native vulnerability scanning on every image push
  image_scanning_configuration {
    scan_on_push = true
  }

  # Security: Enforce AES-256 encryption at rest
  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Cost Control: Retain only the last 5 tagged images to prevent storage sprawl
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Retain only the 5 most recent container images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

