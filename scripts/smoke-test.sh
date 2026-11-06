#!/usr/bin/env bash
# =============================================================================
# OnYx Smoke Test Script
# Verifies container readiness and key endpoints after deployment
# =============================================================================

set -euo pipefail

TARGET_URL="${1:-http://localhost:3000}"
MAX_RETRIES=10
RETRY_DELAY=2

echo "🔍 Starting OnYx smoke tests against: ${TARGET_URL}"

# 1. Health Endpoint Check (/api/health)
echo "  [1/2] Checking health endpoint (/api/health)..."
health_status=""
for ((i=1; i<=MAX_RETRIES; i++)); do
  if response=$(curl -s -f -m 5 "${TARGET_URL}/api/health" 2>/dev/null); then
    if echo "${response}" | grep -q '"status":"ok"'; then
      echo "  ✅ Health check PASSED: ${response}"
      health_status="ok"
      break
    fi
  fi
  echo "    Waiting for health endpoint (attempt ${i}/${MAX_RETRIES})..."
  sleep "${RETRY_DELAY}"
done

if [[ "${health_status}" != "ok" ]]; then
  echo "  ❌ Health check FAILED after ${MAX_RETRIES} attempts!"
  exit 1
fi

# 2. Web Root Check (/)
echo "  [2/2] Checking landing page (HTTP 200 on /)..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "${TARGET_URL}/")
if [[ "${http_code}" == "200" ]]; then
  echo "  ✅ Landing page returned HTTP 200 OK"
else
  echo "  ❌ Landing page returned unexpected status: ${http_code}"
  exit 1
fi

echo "🎉 All smoke tests passed successfully!"
exit 0

