# OnYx — Automated Deployment & Rollback Architecture (Phase 9)

## 1. Overview & Trust Boundaries

The Continuous Deployment (CD) pipeline automatically deploys validated release images to the Amazon EC2 demonstration host (`i-00d2233bfd6f65be2`) following a successful release publish or manual dispatch.

```text
GitHub Actions (CD Workflow)
   │
   ├─► 1. Query ECR API for Authoritative Digest (sha256:afe3d4...)
   ├─► 2. Query AWS EC2 API for Public IPv4 (16.178.119.245)
   ├─► 3. Send SSM Run Command (Zero SSH)
   │         │
   │         ▼
   │   AWS Systems Manager (Agent on EC2)
   │         │
   │         ├─► Pulls Scoped ECR Image via EC2 Instance Role
   │         ├─► Preserves Active Version in deploy_state.env
   │         ├─► Deploys via Docker Compose (compose.prod.yml)
   │         └─► Tier-1 Smoke Test (localhost:3000/api/health)
   │               └── [Failure? Instant Automated Rollback]
   │
   └─► 4. Tier-2 External Smoke Test (http://16.178.119.245:3000/api/health)
```

---

## 2. Core DevSecOps Principles

1. **Immutable Cryptographic Digest Pinning:**
   - Production deployments never target mutable tags like `latest`.
   - The deployment workflow queries the Amazon ECR registry API to extract the exact `sha256` image digest.
   - Deployments execute against:
     ```text
     797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app@sha256:afe3d4561c1fcf72a27d05e1e5f6eacefad06d810b119c8414a7f45f01c4edb5
     ```

2. **Zero SSH Access:**
   - Inbound port `22` (SSH) is completely closed in Security Group `sg-03616e0efd08c9941`.
   - All management and deployment operations occur over TLS via **AWS Systems Manager (SSM) Run Command** using the document `AWS-RunShellScript`.

3. **Two-Tier Health Verification:**
   - **Tier 1 (Internal):** The deployment script (`scripts/deploy-demo.sh`) polls `http://127.0.0.1:3000/api/health` directly on the host up to 15 times before declaring the deployment successful.
   - **Tier 2 (External):** GitHub Actions sends an HTTP probe across the public internet to `http://${PUBLIC_IP}:3000/api/health` to ensure network routes and security group rules allow user traffic.

---

## 3. Automated Rollback Drill (Exit Gate Proof)

To verify the exit gate (*"an intentional bad image triggers a demonstrable rollback"*), an intentional failure was dispatched on EC2 using `alpine:latest` (a non-functional container lacking web endpoints).

### Execution Evidence:
```text
======================================================================
🚀 Starting OnYx Deployment Process
Target Image: alpine:latest
Deployment Directory: /opt/onyx
Timestamp: 2026-11-10T18:12:27Z
======================================================================
ℹ️ Recorded previous active image: 797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app@sha256:afe3d4561c1fcf72a27d05e1e5f6eacefad06d810b119c8414a7f45f01c4edb5
📦 Pulling target image: alpine:latest...
Status: Downloaded newer image for alpine:latest
🔄 Rolling out new container version...
🩺 Running post-deployment health verification...
  Waiting for application readiness (attempt 1/15)...
  Waiting for application readiness (attempt 2/15)...
  ...
  Waiting for application readiness (attempt 15/15)...
❌ Health check FAILED for target image alpine:latest!
⚠️ Initiating automated rollback to previous known-good image...
⏪ Reverting to previous image: 797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app@sha256:afe3d4561c1fcf72a27d05e1e5f6eacefad06d810b119c8414a7f45f01c4edb5
🩺 Verifying rollback health...
✅ Rollback SUCCESSFUL: Previous version restored and healthy.
```

### Post-Rollback Live Verification:
```bash
$ curl -s http://16.178.119.245:3000/api/health
{"status":"ok","timestamp":"2026-11-10T18:14:11.534Z","uptime":53.99}
```

The system automatically caught the failure, rolled back the Docker containers, restored the healthy version, and verified endpoint recovery without manual operator intervention.

