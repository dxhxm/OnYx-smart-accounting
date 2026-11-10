# =============================================================================
# Security Group (Virtual Firewall)
# Zero-SSH, least-privilege network perimeter for OnYx demonstration server
# =============================================================================

# Retrieve the default VPC in the chosen region
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "demo_server" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "Security group for OnYx demo server (Zero SSH, Zero public DB)"
  vpc_id      = data.aws_vpc.default.id

  # Inbound: Allow web traffic to OnYx Next.js application port
  ingress {
    description = "Allow inbound HTTP to OnYx application"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: Allow standard HTTP (port 80)
  ingress {
    description = "Allow inbound HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound: Allow standard HTTPS (port 443)
  ingress {
    description = "Allow inbound HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SECURITY BOUNDARY:
  # Notice: NO port 22 (SSH) allowed from internet! Management via AWS Systems Manager.
  # Notice: NO port 5432 (Postgres) allowed from internet! Database is internal only.

  # Outbound: Allow all egress so server can download packages and pull from ECR
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-sg"
  }
}

