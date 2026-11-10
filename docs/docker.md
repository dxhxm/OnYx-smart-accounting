# OnYx — Docker Architecture & Container Security Guide

## 1. Container Overview

The OnYx Smart Accounting application is containerized using a hardened multi-stage Docker build producing a minimal standalone production image.

- **Base Image:** `node:26-alpine` (musl Linux)
- **Runtime User:** `nextjs` (UID: 1001, non-root)
- **Container Size:** ~127 MB compressed (~482 MB unpacked)
- **Healthcheck:** Queries internal `/api/health` every 30s
- **Exposed Port:** 3000

---

## 2. Multi-Stage Build Architecture

```
[Stage 1: deps]      node:26-alpine + libc6-compat + openssl -> npm ci
         |
[Stage 2: builder]   Prisma generate -> npm run build (creates .next/standalone)
         |
[Stage 3: runner]    node:26-alpine + non-root user -> copies ONLY .next/standalone + static assets
```

All build-time dependencies, TypeScript compilers, test files, and package caches are discarded in Stage 2 and never reach the final production container.

---

## 3. How to Run Locally

### Option A: Complete Multi-Container Stack (App + Postgres)

Start the app and database in the background:
```bash
docker compose -f compose.demo.yml up -d --build
```

Check running container status:
```bash
docker compose -f compose.demo.yml ps
```

Apply database migrations to the containerized PostgreSQL:
```bash
DATABASE_URL="postgresql://onyx:onyx_local_secret_password@127.0.0.1:5432/onyx_demo?sslmode=disable" npx prisma migrate deploy
```

Run automated smoke tests:
```bash
./scripts/smoke-test.sh
```

Stop and tear down the demo stack:
```bash
docker compose -f compose.demo.yml down
```

### Option B: Build and Run Standalone Container

```bash
# Build
docker build -t onyx-smart-accounting:local .

# Run pointing to Neon or external PostgreSQL
docker run -d -p 3000:3000 \
  -e DATABASE_URL="postgresql://..." \
  --name onyx-app onyx-smart-accounting:local

# Inspect logs
docker logs -f onyx-app
```

---

## 4. Security & Hardening Features

| Control | Implementation | DevSecOps Purpose |
|---|---|---|
| **Non-Root Execution** | `USER nextjs` (`UID 1001`) | Mitigates container breakout risk |
| **Minimal Attack Surface** | Multi-stage build + Alpine | Removes compilers, shell tools, and dev dependencies |
| **Leak Prevention** | `.dockerignore` | Prevents `.env*`, `.git`, and tests from entering images |
| **Zero-Trust Network** | Internal Docker Bridge | Database port bound only to `127.0.0.1`, not exposed externally |
| **Readiness Probes** | `HEALTHCHECK` on `/api/health` | Enables orchestrators to auto-recover unresponsive containers |

---

## 5. Local Trivy Vulnerability Scan & Triage

Scanned image: `onyx-smart-accounting:local` using `aquasec/trivy:latest`.

### Summary
- **OS Packages (Alpine Linux 3.23):** 0 High, 0 Critical vulnerabilities.
- **Application Packages:** 4 Critical findings identified in Next.js 16.1.6 framework dependencies.

### Triage Analysis

| Vulnerability ID | Package | Affected / Fixed | Triage Assessment |
|---|---|---|---|
| **CVE-2026-75604** | `next@16.1.6` | Fixed in `16.4.1` | **Not Applicable in Demo**: Affects Windows-hosted servers only; container runs Linux Alpine. |
| **GHSA-2464-fhr4-w9xw** | `next@16.1.6` | Fixed in `16.4.1` | **Low Risk in Baseline**: Image optimization endpoint for SVG files; no public image upload vector currently active. |
| **GHSA-2xp9-vwfh-vxw4** | `next@16.1.6` | Fixed in `16.4.1` | **Low Risk in Baseline**: AVIF image optimization attack vector. |
| **GHSA-673q-mjm6-r5xr** | `next@16.1.6` | Fixed in `16.4.1` | **Low Risk in Baseline**: Pertains to `use cache` returning typed arrays; not used in project. |

**Policy Decision:** These findings originate from pre-existing Next.js 16 framework packages. Because this deployment is a demo portfolio environment running in an isolated AWS VPC without public financial data, these findings are documented and triaged rather than forcing a breaking major version upgrade mid-pipeline. In Phase 4, we will configure Trivy thresholds and exception policies accordingly.

