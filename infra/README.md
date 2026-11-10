# OnYx — Infrastructure as Code (Terraform)

## 1. Directory Structure

```text
infra/
├── bootstrap/             # Independent S3 Remote State Bucket (AES-256 + Versioning)
│   ├── main.tf
│   └── outputs.tf
├── terraform/             # Primary Demo Cloud Infrastructure
│   ├── versions.tf        # Pinned Terraform >= 1.10 & AWS ~> 5.0
│   ├── backend.tf         # S3 backend with native locking (use_lockfile = true)
│   ├── providers.tf       # AWS provider & mandatory default_tags
│   ├── variables.tf       # Configurable deployment inputs
│   ├── ecr.tf             # Private ECR registry (scan-on-push + 5-image lifecycle)
│   ├── security.tf        # Virtual Firewall (Port 3000 open, Port 22 SSH CLOSED)
│   ├── iam.tf             # Instance Profile for AWS Systems Manager (SSM) & ECR pull
│   ├── cicd_iam.tf        # Least-privilege IAM service user for GitHub Actions CI/CD
│   ├── main.tf            # EC2 t3.small server with encrypted gp3 & cloud-init
│   └── outputs.tf         # Deployment identifiers (ECR URL, Public IP, SSM command)
└── README.md
```

---

## 2. Active Cloud Resources (Provisioned in `ap-southeast-2`)

| Resource | Service | Identifier | Security Notes |
|---|---|---|---|
| **Terraform State** | Amazon S3 | `onyx-devsecops-tfstate-797661819601` | AES-256, Versioned, 100% Public Access Blocked |
| **Container Registry** | Amazon ECR | `onyx-app` (`797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app`) | Private, Scan-on-push, 5-image lifecycle |
| **Firewall** | Security Group | `sg-03616e0efd08c9941` (`onyx-demo-sg`) | Port 3000 open, Port 22 CLOSED, Port 5432 CLOSED |
| **Server Identity** | IAM Instance Profile | `onyx-demo-instance-profile` | SSM Managed, ECR pull permissions, Zero keys on disk |
| **Demo Host** | Amazon EC2 | `i-00d2233bfd6f65be2` (`16.178.119.245`) | `t3.small`, 20GB gp3 encrypted, IMDSv2 enforced |
| **CI/CD Service Account** | IAM User | `onyx-github-actions-deployer` | Scoped ECR push + SSM Run Command only. Zero console access. |

---

## 3. How to Connect Securely (Zero SSH)

Because inbound SSH (port 22) is completely closed for security, connect directly using AWS Systems Manager:

```bash
aws ssm start-session --target i-00d2233bfd6f65be2 --region ap-southeast-2
```

Alternatively, open the AWS Management Console ➔ **EC2** ➔ Select `onyx-demo-server` ➔ Click **Connect** ➔ **Session Manager**.

---

## 4. Teardown Procedure

To destroy all compute, network, and registry resources:
```bash
cd infra/terraform
terraform destroy -auto-approve
```
*(The S3 state bucket in `infra/bootstrap/` is protected by `prevent_destroy = true` and will remain preserved).*

