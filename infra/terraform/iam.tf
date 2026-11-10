# =============================================================================
# IAM Role and Instance Profile for EC2 Server
# Allows instance to be managed via SSM (Zero SSH) and pull from private ECR
# =============================================================================

# IAM Role assumed by the EC2 instance
resource "aws_iam_role" "demo_server" {
  name = "${var.project_name}-${var.environment}-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS Systems Manager (SSM) Managed Policy
# Enables AWS Systems Manager Session Manager, Run Command, and inventory without SSH
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.demo_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Scoped Policy: Allow EC2 instance to authenticate and pull images from ECR
resource "aws_iam_policy" "ecr_pull" {
  name        = "${var.project_name}-${var.environment}-ecr-pull"
  description = "Allows EC2 instance to pull images from the Onyx ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthToken"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPullImages"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = aws_ecr_repository.app.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.demo_server.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

# Instance profile used to attach the role to the EC2 instance
resource "aws_iam_instance_profile" "demo_server" {
  name = "${var.project_name}-${var.environment}-instance-profile"
  role = aws_iam_role.demo_server.name
}

