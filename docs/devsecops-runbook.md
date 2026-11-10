# OnYx DevSecOps Operational Runbook

This document serves as the standard operating procedure (SOP) and incident response runbook for the OnYx Smart Accounting production demo environment.

---

## 1. System Overview & Architecture

* **Production URL:** `https://onyx-smart-accounting.app`
* **Health Check Endpoint:** `https://onyx-smart-accounting.app/api/health`
* **Hosting Region:** AWS Sydney (`ap-southeast-2`)
* **Compute Instance:** EC2 `t3.small` (`i-00d2233bfd6f65be2`)
* **Public IPv4:** `16.178.119.245`
* **Edge Proxy & DNS:** Cloudflare (Anycast DNS, Universal SSL, Full mode)
* **Ingress Controller:** Caddy 2 reverse proxy (`onyx-prod-caddy`) with internal TLS and HTTP/2
* **Application:** Next.js 16 standalone container (`onyx-prod-app`, non-root user `nextjs:1001`)
* **Database:** PostgreSQL 16 (`onyx-prod-db`), bound strictly to internal Docker bridge network (`onyx-internal`)

```
[ Internet ]
     │
     ▼ (HTTPS Port 443 / Cloudflare Universal SSL)
[ Cloudflare Anycast Edge ]
     │
     ▼ (HTTPS Port 443 / Inbound SG sg-03616e0efd08c9941)
[ Caddy 2 Reverse Proxy (onyx-prod-caddy) ]
     │
     ▼ (HTTP Port 3000 / Internal Docker Network onyx-internal)
[ Next.js Standalone (onyx-prod-app) ]
     │
     ▼ (TCP Port 5432 / Internal Docker Network onyx-internal)
[ PostgreSQL 16 (onyx-prod-db) ] (Persistent Volume: pg_data)
```

---

## 2. Zero-SSH Access & Diagnostics via AWS Systems Manager (SSM)

To prevent credential sprawl and eliminate brute-force attack vectors, **Port 22 (SSH) is permanently closed**. All administrative operations are conducted via AWS Systems Manager Session Manager.

### Connecting to the Host
1. **Via AWS Console:**
   * Navigate to **EC2 > Instances > `onyx-demo-server`**.
   * Click **Connect > Session Manager > Connect**.
2. **Via AWS CLI (Local Terminal):**
   ```bash
   aws ssm start-session --target i-00d2233bfd6f65be2 --region ap-southeast-2
   ```

### Core Diagnostic Commands (Run inside SSM Session)
```bash
# Elevate to root
sudo su -

# 1. Check container health status
docker ps

# 2. Check live resource consumption (CPU / Memory)
docker stats --no-stream

# 3. Check Caddy edge access logs
docker logs --tail 50 onyx-prod-caddy

# 4. Check application logs
docker logs --tail 50 onyx-prod-app

# 5. Check database logs
docker logs --tail 50 onyx-prod-db

# 6. Check EBS root disk utilization
df -h /
```

---

## 3. Incident Response Playbooks

### Playbook A: Application Unreachable / 502 Bad Gateway
**Symptoms:** Cloudflare displays `502 Bad Gateway` when requesting `https://onyx-smart-accounting.app`.

1. **Root Cause Analysis:**
   * 502 indicates Caddy is alive and terminating TLS, but cannot connect to `app:3000`.
   * Check container status:
     ```bash
     docker ps -a --filter "name=onyx-prod-app"
     ```
   * Inspect exit code and crash logs:
     ```bash
     docker logs --tail 100 onyx-prod-app
     ```
2. **Immediate Recovery Action:**
   ```bash
   cd /opt/onyx
   docker compose -f compose.prod.yml up -d
   ```
3. **Verification:**
   ```bash
   curl -i http://localhost:3000/api/health
   # Expected: HTTP/1.1 200 OK
   ```

---

### Playbook B: Failed CD Deployment / Rollback Drill
**Symptoms:** A newly deployed release fails health checks or causes runtime regressions.

1. **Automated Rollback (Built-in):**
   * The CD script (`scripts/deploy-demo.sh`) automatically checks `/api/health` 15 times post-deployment.
   * If health checks fail, it automatically rolls back to the previous image digest:
     ```bash
     # Automatic trigger in scripts/deploy-demo.sh
     ROLLBACK_TARGET=$(cat /opt/onyx/previous_image.txt)
     ```
2. **Manual Rollback (via GitHub Actions):**
   * Navigate to GitHub Actions > **Deploy to AWS Demo**.
   * Click **Run workflow**, set `environment` to `demo`, and optionally provide the known-good Git commit SHA or image tag in the workflow dispatch inputs.
3. **Manual Rollback (via SSM Terminal):**
   ```bash
   cd /opt/onyx
   # Check last known good image digest
   cat previous_image.txt
   
   # Point .env to last known good image
   sed -i 's|^IMAGE_URI=.*|IMAGE_URI='"$(cat previous_image.txt)"'|' .env
   docker compose -f compose.prod.yml up -d --remove-orphans
   ```

---

### Playbook C: Disk Space Exhaustion on EC2 Host
**Symptoms:** `df -h /` shows > 85% utilization; Docker builds or pulls fail with `no space left on device`.

1. **Identify space consumers:**
   ```bash
   docker system df
   ```
2. **Prune unused Docker images, stopped containers, and build cache:**
   ```bash
   # Prune dangling/unused images without touching persistent volumes
   docker image prune -a -f
   docker builder prune -f
   ```
3. **Inspect Docker log file sizes:**
   ```bash
   ls -lh /var/lib/docker/containers/*/*-json.log
   ```

---

### Playbook D: Database Maintenance & Volume Persistence
**Architecture:** PostgreSQL data is stored in Docker named volume `onyx_pg_data` mapped to `/var/lib/docker/volumes/onyx_pg_data/_data`.

1. **Verify database connectivity:**
   ```bash
   docker exec -it onyx-prod-db pg_isready -U onyx_user -d onyx_db
   # Expected: /var/run/postgresql:5432 - accepting connections
   ```
2. **Create manual logical backup (SQL dump):**
   ```bash
   docker exec -t onyx-prod-db pg_dumpall -c -U onyx_user > /opt/onyx/backup_$(date +%Y%m%d_%H%M%S).sql
   ```
3. **Restore from SQL dump:**
   ```bash
   cat /opt/onyx/backup_YYYYMMDD_HHMMSS.sql | docker exec -i onyx-prod-db psql -U onyx_user -d onyx_db
   ```

---

## 4. Monitoring & Alarms Configuration

| Alarm Name | Metric | Threshold | Evaluation | Action |
|---|---|---|---|---|
| `onyx-ec2-system-failure` | `StatusCheckFailed` | `>= 1` | 1 datapoint (1 min) | SNS email notification (`onyx-ops-alerts`) |
| `onyx-ec2-high-cpu` (Optional) | `CPUUtilization` | `> 80%` | 2 consecutive (10 min) | SNS email notification |

### CloudWatch Log Retention Policy
* Any CloudWatch Log Groups created for SSM or host logs must have their retention period explicitly set to **7 days** or **14 days** to prevent unbounded storage costs on the AWS Free Tier.
* Command to set retention:
  ```bash
  aws logs put-retention-policy --log-group-name <log-group-name> --retention-in-days 14 --region ap-southeast-2
  ```

---

## 5. Security & Isolation Controls Summary

1. **Network Security:**
   * Inbound traffic strictly limited to Port 80 (HTTP redirect) and Port 443 (HTTPS) from Cloudflare.
   * Port 22 (SSH) blocked at AWS Security Group level (`sg-03616e0efd08c9941`).
   * Database port 5432 bound exclusively to private Docker network `onyx-internal`; never bound to host 0.0.0.0.
2. **Process Privilege:**
   * Container runs with non-root user `nextjs` (UID 1001, GID 1001).
   * Runner base image stripped of package managers (`npm`, `npx` removed) to eradicate transitive runtime vulnerabilities.
3. **CI/CD Credential Boundaries:**
   * Dedicated IAM user `onyx-github-actions-deployer` strictly constrained:
     * `onyx-cicd-ecr-push`: scoped exclusively to ECR repository `onyx-app`.
     * `onyx-cicd-ssm-deploy`: scoped exclusively to EC2 instance `i-00d2233bfd6f65be2`.

