# =============================================================================
# GitHub Actions CI/CD Dedicated IAM User & Least-Privilege Policies
# =============================================================================
# Implements the sanctioned least-privilege CI/CD authentication pattern:
# - Dedicated service user 'onyx-github-actions-deployer'
# - Strictly scoped ECR push permissions (only to onyx-app repository)
# - Strictly scoped SSM Run Command permissions (only to the demo instance)
# - Zero SSH keys, zero management console access, zero broad admin rights
# =============================================================================

resource "aws_iam_user" "cicd" {
  name = "onyx-github-actions-deployer"

  tags = {
    Role        = "cicd-service-account"
    ManagedBy   = "terraform"
    Description = "Least-privilege CI/CD deployment user for GitHub Actions"
  }
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

# Policy Document for ECR Push & Pull
data "aws_iam_policy_document" "cicd_ecr" {
  # 1. Authorization token retrieval requires resource "*" per AWS specification
  statement {
    sid       = "ECRAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # 2. Scoped operations restricted strictly to the onyx-app repository
  statement {
    sid    = "ECRRepositoryAccess"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_user_policy" "cicd_ecr" {
  name   = "onyx-cicd-ecr-push"
  user   = aws_iam_user.cicd.name
  policy = data.aws_iam_policy_document.cicd_ecr.json
}

# Policy Document for SSM Run Command
data "aws_iam_policy_document" "cicd_ssm" {
  # 1. SendCommand scoped strictly to the target demo instance and AWS-RunShellScript document
  statement {
    sid    = "SSMSendCommand"
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      aws_instance.demo_server.arn,
      "arn:aws:ssm:${var.aws_region}:*:document/AWS-RunShellScript"
    ]
  }

  # 2. Polling and status checks for executed commands
  statement {
    sid    = "SSMCommandStatusCheck"
    effect = "Allow"
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ssm:ListCommands",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "cicd_ssm" {
  name   = "onyx-cicd-ssm-deploy"
  user   = aws_iam_user.cicd.name
  policy = data.aws_iam_policy_document.cicd_ssm.json
}

