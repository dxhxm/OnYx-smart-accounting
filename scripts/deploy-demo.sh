#!/usr/bin/env bash
# =============================================================================
# OnYx Automated Deployment & Rollback Script
# Executed on EC2 via AWS Systems Manager Run Command
# =============================================================================
set -euo pipefail

TARGET_IMAGE="${1:-}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/onyx}"
AWS_REGION="${AWS_REGION:-ap-southeast-2}"
COMPOSE_FILE="${DEPLOY_DIR}/compose.prod.yml"
STATE_FILE="${DEPLOY_DIR}/deploy_state.env"

echo "======================================================================"
echo "🚀 Starting OnYx Deployment Process"
echo "Target Image: ${TARGET_IMAGE}"
echo "Deployment Directory: ${DEPLOY_DIR}"
echo "Timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "======================================================================"

if [[ -z "${TARGET_IMAGE}" ]]; then
  echo "❌ Error: Target image URI (with tag or digest) must be provided as arg 1"
  exit 1
fi

mkdir -p "${DEPLOY_DIR}"
cd "${DEPLOY_DIR}"

# 1. Read last known good image for rollback safety
PREVIOUS_IMAGE=""
if [[ -f "${STATE_FILE}" ]]; then
  # Source previous image safely
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  PREVIOUS_IMAGE="${CURRENT_IMAGE:-}"
  echo "ℹ️ Recorded previous active image: ${PREVIOUS_IMAGE}"
fi

# 2. Authenticate to Amazon ECR using EC2 Instance Profile credentials
echo "🔑 Authenticating to Amazon ECR in ${AWS_REGION}..."
REGISTRY_HOST=$(echo "${TARGET_IMAGE}" | cut -d/ -f1)
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${REGISTRY_HOST}"

# 3. Pull target image
echo "📦 Pulling target image: ${TARGET_IMAGE}..."
docker pull "${TARGET_IMAGE}"

# 4. Rollout new version with Docker Compose
echo "🔄 Rolling out new container version..."
export IMAGE_URI="${TARGET_IMAGE}"

# Write runtime environment configuration
echo "IMAGE_URI=${TARGET_IMAGE}" > "${DEPLOY_DIR}/.env"

docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

# 5. Health Check & Smoke Test Gate
echo "🩺 Running post-deployment health verification..."
HEALTH_PASSED=false

# Wait for container to become healthy
for i in {1..15}; do
  if curl -s -f -m 5 "http://127.0.0.1:3000/api/health" | grep -q '"status":"ok"'; then
    echo "✅ Health endpoint verified OK on attempt ${i}"
    HEALTH_PASSED=true
    break
  fi
  echo "  Waiting for application readiness (attempt ${i}/15)..."
  sleep 3
done

if [[ "${HEALTH_PASSED}" == "true" ]]; then
  echo "🎉 Smoke test PASSED! Deployment of ${TARGET_IMAGE} is live and healthy."
  
  # Update deployment state record
  cat <<EOF > "${STATE_FILE}"
CURRENT_IMAGE="${TARGET_IMAGE}"
LAST_DEPLOYED_AT="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
DEPLOY_STATUS="SUCCESS"
PREVIOUS_GOOD_IMAGE="${PREVIOUS_IMAGE}"
EOF

  # Cleanup dangling/unused images to save disk space on EC2 gp3
  docker image prune -f >/dev/null 2>&1 || true
  exit 0
fi

# =============================================================================
# ROLLBACK PROCEDURE (Triggered if health check fails)
# =============================================================================
echo "❌ Health check FAILED for target image ${TARGET_IMAGE}!"
echo "⚠️ Initiating automated rollback to previous known-good image..."

if [[ -n "${PREVIOUS_IMAGE}" && "${PREVIOUS_IMAGE}" != "${TARGET_IMAGE}" ]]; then
  echo "⏪ Reverting to previous image: ${PREVIOUS_IMAGE}"
  export IMAGE_URI="${PREVIOUS_IMAGE}"
  echo "IMAGE_URI=${PREVIOUS_IMAGE}" > "${DEPLOY_DIR}/.env"
  docker compose -f "${COMPOSE_FILE}" up -d --remove-orphans

  echo "🩺 Verifying rollback health..."
  sleep 5
  if curl -s -f -m 5 "http://127.0.0.1:3000/api/health" | grep -q '"status":"ok"'; then
    echo "✅ Rollback SUCCESSFUL: Previous version ${PREVIOUS_IMAGE} restored and healthy."
  else
    echo "💥 CRITICAL: Rollback failed to achieve healthy status. Manual intervention required."
  fi
else
  echo "⚠️ No previous known-good image recorded. Unable to perform automated rollback."
fi

# Exit with failure code so CD workflow alerts and records the failure
exit 1

