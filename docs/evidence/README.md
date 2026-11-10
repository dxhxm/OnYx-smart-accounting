# OnYx DevSecOps Verification & Evidence Log

This catalog compiles the empirical test results, automated security gate outputs, rollback verification drills, and live deployment proofs executed during the implementation.

---

## 1. Verified Live Deployment

* **Custom Domain:** `https://onyx-smart-accounting.app`
* **Health API Endpoint:** `https://onyx-smart-accounting.app/api/health`
* **Response:**
  ```json
  {
    "status": "ok",
    "timestamp": "2026-11-10T20:25:00.000Z",
    "uptime": 279.42
  }
  ```
* **TLS / Edge Verification:**
  ```bash
  $ curl -I https://onyx-smart-accounting.app/api/health
  HTTP/2 200
  date: Tue, 10 Nov 2026 20:25:00 GMT
  content-type: application/json
  server: cloudflare
  cf-ray: 99c75908b8b0e7c5-SYD
  alt-svc: h3=":443"; ma=86400
  ```

---

## 2. DevSecOps Security Gate Verifications

### A. Pre-Publish Container Vulnerability Scan (Trivy)
* **Workflow:** `.github/workflows/image-publish.yml`
* **Scan Target:** Multi-stage Next.js production image
* **Policy:** `severity: CRITICAL,HIGH`, `exit-code: 1`
* **Remediation Executed:**
  - Removed package managers (`npm`, `npx`, `corepack`) from the runner stage in `Dockerfile` to eradicate bundled `undici` CVEs (`CVE-2024-51752`, `CVE-2025-22150`).
  - Generated CycloneDX Software Bill of Materials: `onyx-sbom.cdx.json`.
* **Gate Status:** ✅ Passed — Clean build promoted to Amazon ECR.

### B. CI/CD IAM Least-Privilege & Negative Authorization Drills
* **Workflow:** `.github/workflows/aws-verify.yml`
* **Identity Tested:** `arn:aws:iam::797661819601:user/onyx-github-actions-deployer`
* **Test Results:**
  1. `sts get-caller-identity`: Passed (Authenticated as deployer user)
  2. `ecr get-login-password`: Passed (Read token for registry authorized)
  3. `ssm describe-instance-information`: Passed (Instance `i-00d2233bfd6f65be2` reachable)
  4. **Negative Test (S3 Access):**
     ```bash
     $ aws s3 ls
     An error occurred (AccessDenied) when calling the ListBuckets operation
     ```
     Result: ✅ Denied as expected.
  5. **Negative Test (IAM Escalation):**
     ```bash
     $ aws iam create-user --user-name hacker
     An error occurred (AccessDenied) when calling the CreateUser operation
     ```
     Result: ✅ Denied as expected.

---

## 3. Automated CD Rollback Verification Drill

* **Workflow:** `.github/workflows/deploy-demo.yml`
* **Test Date:** 2026-11-10
* **Dispatched Target:** Intentionally corrupted image (`alpine:latest` without Next.js app on port 3000).
* **Execution Log Summary:**
  ```
  Attempt 1/15: Health check returned 000. Waiting 2s...
  Attempt 5/15: Health check returned 000. Waiting 2s...
  Attempt 15/15: Health check returned 000. Waiting 2s...
  [ERROR] Health check failed after 15 attempts.
  [ROLLBACK] Initiating rollback to previous image: 797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app@sha256:afe3d4561c1fcf72a27d05e1e5f6eacefad06d810b119c8414a7f45f01c4edb5
  Restoring previous .env...
  Pulling rollback image...
  Restarting containers...
  Verifying rollback health: HTTP 200 OK
  [ROLLBACK SUCCESS] Application successfully restored to healthy release.
  ```
* **Result:** ✅ Automatic recovery succeeded; zero operator intervention required.

---

## 4. Live Chaos Outage Drill

* **Drill:** Manual kill of production application container via AWS SSM Session Manager (`docker stop onyx-prod-app`).
* **Observed Edge Behavior:** Cloudflare & Caddy returned `HTTP 502 Bad Gateway` (confirming reverse proxy health and upstream failure detection).
* **Recovery Action:** Executed Docker Compose state reconciliation (`docker compose -f compose.prod.yml up -d`).
* **Recovery Duration:** < 5 seconds to `HTTP 200 OK`.

---

## 5. Amazon ECR Release Record

* **Repository:** `797661819601.dkr.ecr.ap-southeast-2.amazonaws.com/onyx-app`
* **Authoritative Release Digest:**
  `sha256:afe3d4561c1fcf72a27d05e1e5f6eacefad06d810b119c8414a7f45f01c4edb5`
* **Tags:** `latest`, `0888c18...`, `sha-0888c18`
* **Container Size:** ~85MB compressed (Alpine Next.js standalone runner)

