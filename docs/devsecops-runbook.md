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

---

## 6. Observability & Monitoring Operations

The observability stack runs as an independent Docker Compose project (`onyx-monitoring`) connected to `onyx_prod_network`.

### Service Components
* `onyx-node-exporter:v1.8.2`: Host hardware and Linux kernel metrics (Port `127.0.0.1:9100`).
* `onyx-cadvisor:v0.49.1`: Per-container resource utilization (Port `127.0.0.1:8080`).
* `onyx-prometheus:v2.54.1`: TSDB scraping targets every 15s; outbound `remote_write` to Grafana Cloud (Port `127.0.0.1:9090`).
* `onyx-prod-app`: Next.js 16 instrumented with `prom-client` serving `/api/metrics` on port 3000.

### Operational Procedures (via AWS SSM)

#### 1. Check Scrape Target Health
```bash
INSTANCE_ID="i-00d2233bfd6f65be2"
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s http://localhost:9090/api/v1/targets | python3 -c \"import sys, json; [print(t[\x27labels\x27][\x27job\x27], t[\x27health\x27]) for t in json.load(sys.stdin)[\x27data\x27][\x27activeTargets\x27]]\""]' \
  --region ap-southeast-2
```

#### 2. Reload Prometheus Configuration (Zero-Downtime)
When updating `/opt/onyx/monitoring/prometheus/prometheus.yml`, trigger a config reload without restarting the container:
```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["curl -s -X POST http://localhost:9090/-/reload"]' \
  --region ap-southeast-2
```

#### 3. Verify Remote Write Egress to Grafana Cloud
Check Prometheus logs for outbound push confirmations:
```bash
aws ssm send-command \
  --instance-ids "$INSTANCE_ID" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["docker logs onyx-prometheus --tail 50 | grep -i -E \"remote_write|wal\""]' \
  --region ap-southeast-2
```

---

## 7. Incident Response & Alert Triage Runbook

### Alert: `OnYx App Down` (Severity: Critical)
* **Trigger:** `up{job="onyx-app"} < 1` for 2 minutes.
* **Triage Steps:**
  1. Check container status: `docker ps -a --filter name=onyx-prod-app`
  2. Inspect crash logs: `docker logs onyx-prod-app --tail 100`
  3. Verify port binding and internal health: `curl -v http://localhost:3000/api/health`
  4. If container crashed after deployment, trigger rollback:
     ```bash
     /opt/onyx/scripts/deploy-demo.sh rollback
     ```

### Alert: `EC2 Host CPU High` (Severity: Warning)
* **Trigger:** Host CPU usage `> 85%` for 5 minutes.
* **Triage Steps:**
  1. Inspect top processes by CPU: `docker stats --no-stream` and `top -b -n 1 | head -n 20`
  2. Determine if traffic spike or rogue process: Check Dashboard 3 (RPS).
  3. If traffic spike is malicious, engage Cloudflare Under Attack mode or enable rate-limiting rules.

### Alert: `EC2 Host Memory High` (Severity: Warning)
* **Trigger:** Available memory `< 15%` (Usage `> 85%`) for 5 minutes.
* **Triage Steps:**
  1. Check per-container memory: `docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"`
  2. Check V8 heap memory in Dashboard 3 (`onyx_nodejs_heap_size_used_bytes`). If growing monotonically without garbage collection, a Node.js memory leak is likely.
  3. Perform a safe rolling restart: `docker compose -f /opt/onyx/compose.prod.yml restart app`

### Alert: `OnYx HTTP 5xx Error Spike` (Severity: Critical)
* **Trigger:** 5xx error rate `> 5%` for 3 minutes.
* **Triage Steps:**
  1. Inspect Caddy and App error logs:
     ```bash
     docker logs onyx-prod-app --tail 50 --since 10m | grep -i error
     docker logs onyx-prod-caddy --tail 50 --since 10m
     ```
  2. Verify database connection pool: `docker exec onyx-prod-db pg_isready -U onyx_user -d onyx_db`
  3. Inspect route breakdown panel in Dashboard 3 to isolate which specific endpoint is generating 500s.


