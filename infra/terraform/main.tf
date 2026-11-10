# =============================================================================
# Amazon EC2 Demonstration Server
# Automated bootstrapping, encrypted storage, and IMDSv2 security hardening
# =============================================================================

# Query the latest official Amazon Linux 2023 AMI in the current region
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "demo_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.demo_server.name
  vpc_security_group_ids = [
    aws_security_group.demo_server.id
  ]

  # Root disk: 20 GB gp3 with enforced encryption at rest
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name = "${var.project_name}-${var.environment}-root-disk"
    }
  }

  # Security Hardening: Enforce IMDSv2 to prevent SSRF credential theft
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 mandatory
    http_put_response_hop_limit = 1
  }

  # Automated Cloud-Init User Data:
  # Installs Docker, Compose, configures log rotation, and prepares directories
  user_data = <<-EOF
#!/usr/bin/env bash
set -euo pipefail

# 1. Update OS packages and install Docker
dnf update -y
dnf install -y docker git

# 2. Configure Docker daemon with log rotation (prevent disk fill)
mkdir -p /etc/docker
cat <<'JSON' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

# 3. Start and enable Docker engine
systemctl enable --now docker
usermod -aG docker ec2-user

# 4. Install Docker Compose plugin (v2)
DOCKER_CONFIG=/usr/local/lib/docker/cli-plugins
mkdir -p "$DOCKER_CONFIG"
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 -o "$DOCKER_CONFIG/docker-compose"
chmod +x "$DOCKER_CONFIG/docker-compose"

# 5. Prepare application directory for deployment
mkdir -p /opt/onyx
chown -R ec2-user:ec2-user /opt/onyx

echo "OnYx EC2 Bootstrap completed successfully at $(date)" >> /var/log/onyx-bootstrap.log
EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-server"
  }
}

