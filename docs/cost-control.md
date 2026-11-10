# OnYx — AWS Cost Control, Budgeting & Governance Runbook

## 1. Project Governance & AWS Identity

All cloud infrastructure for the OnYx DevSecOps deployment is provisioned under a strictly controlled environment designed to operate entirely within promotional AWS credits ($120 available).

- **AWS Account ID:** `797661819601`
- **Designated Region:** `ap-southeast-2` (Sydney)
- **Deployment IAM Identity:** `onyx-devsecops-admin`
- **Promotion Runway:** $120.00 credits (~6+ months of deployment capacity)

---

## 2. Active Budget Guardrails

An automated AWS Cost Budget is configured to monitor spending 24/7:

| Parameter | Configuration |
|---|---|
| **Budget Name** | `OnYx-DevSecOps-Budget` |
| **Budget Type** | Monthly Fixed Cost Budget |
| **Limit Amount** | `$25.00 / month` |
| **Threshold Alert 1** | **50% ($12.50)** — Automated email notification to developer |
| **Threshold Alert 2** | **80% ($20.00)** — Automated email warning before credit threshold |

---

## 3. Mandatory Resource Tagging Standard

Every cloud resource created via Terraform or AWS Console must carry these metadata tags. This allows immediate cost tracking in AWS Cost Allocation Tags:

```hcl
default_tags {
  tags = {
    Project     = "OnYx-DevSecOps"
    Environment = "demo"
    ManagedBy   = "Terraform"
    Owner       = "Daham"
  }
}
```

---

## 4. Architecture Sizing & Monthly Cost Estimate

To maximize credit longevity, OnYx uses a **single-instance demonstration architecture** without expensive managed services:

| Component | Service & Specifications | Estimated Monthly Cost (24/7) | On-Demand Hourly Cost |
|---|---|---|---|
| **App & DB Host** | Amazon EC2 `t3.small` (2 vCPU, 2 GB RAM) | ~$15.18 / month | ~$0.0208 / hour |
| **Encrypted Disk** | 20 GB General Purpose SSD (`gp3`) | ~$1.60 / month | ~$0.002 / hour |
| **Container Registry** | Amazon ECR (Private, 3-image retention lifecycle) | ~$0.15 / month | Negligible |
| **Instance Management** | AWS Systems Manager (SSM Agent) | $0.00 (Included) | $0.00 |
| **Logging** | Amazon CloudWatch (7-day retention) | $0.00 (Free Tier) | $0.00 |
| **Public IPv4** | In-use public IPv4 address | ~$3.60 / month | ~$0.005 / hour |
| **TOTAL** | | **~$20.50 / month** | **~$0.028 / hour** |

> **Cost Optimization Tip:** Stopping the EC2 instance when not presenting or testing drops compute charges to $0.00, costing only ~$0.05/day for storage.

---

## 5. Architectural Anti-Patterns Avoided (Cost Killers)

| Prohibited Service in Demo | Why Avoided | Budget Impact Saved |
|---|---|---|
| **NAT Gateways** | Charges fixed hourly rate even with zero traffic | Saved ~$32.00 / month |
| **Application Load Balancers (ALB)** | Charges fixed hourly rate for idle listener | Saved ~$18.00 / month |
| **Multi-AZ Managed RDS** | Managed database licensing and standby instances | Saved ~$35.00 / month |
| **Elastic Kubernetes Service (EKS)** | Cluster control plane fee ($0.10/hr) | Saved ~$73.00 / month |

---

## 6. Teardown & Cost Emergency Procedures

If you ever need to pause or completely wipe out cloud costs, follow these steps:

### A. Temporary Pause (Halts 90% of charges)
In the AWS Console:
1. Go to **EC2** ➔ **Instances**.
2. Select `onyx-demo-server` ➔ **Instance state** ➔ **Stop instance**.
3. Compute charges stop immediately. When ready to demo again, click **Start instance**.

### B. Complete Teardown (Destroys all infrastructure)
From your terminal:
```bash
cd infra/terraform
terraform destroy
```

### C. Retained Billable Resources Audit Checklist
Before walking away from the project, check these 4 items in the AWS Console to ensure zero orphaned charges:
- [ ] **EBS Volumes**: Go to EC2 ➔ Volumes. Confirm no unattached volumes remain.
- [ ] **Elastic IPs**: Go to EC2 ➔ Elastic IPs. Confirm no unassociated IPs exist.
- [ ] **ECR Images**: Go to ECR ➔ Repositories. Confirm test images are deleted.
- [ ] **S3 State Bucket**: Go to S3. Confirm the Terraform state bucket is emptied and deleted when the project is concluded.

