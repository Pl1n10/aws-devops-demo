#!/bin/bash
set -e
APP_NAME="${APP_NAME:-devops-api}"
IMAGE_REPO="${IMAGE_REPO:-ghcr.io/OWNER/devops-api}"
IMAGE_TAG="${VERSION:-latest}"
HEALTH_CHECK_URL="http://localhost/healthz"
MAX_RETRIES=30
RETRY_DELAY=5
LOG_DIR="/var/log/app"

echo "Deploying ${APP_NAME} -> ${IMAGE_REPO}:${IMAGE_TAG}"
sudo mkdir -p ${LOG_DIR} && sudo chown -R ubuntu:ubuntu ${LOG_DIR}

if [ -n "${GITHUB_TOKEN}" ] && [ -n "${GITHUB_ACTOR}" ]; then
  echo "${GITHUB_TOKEN}" | docker login ghcr.io -u ${GITHUB_ACTOR} --password-stdin
fi

docker pull ${IMAGE_REPO}:${IMAGE_TAG}

sudo tee /etc/app/environment > /dev/null <<EOC
APP_NAME=${APP_NAME}
AWS_REGION=${AWS_REGION}
BACKUP_BUCKET=${BACKUP_BUCKET}
ARTIFACTS_BUCKET=${ARTIFACTS_BUCKET}
IMAGE_REPO=${IMAGE_REPO}
IMAGE_TAG=${IMAGE_TAG}
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id || echo local)
EOC

sudo systemctl stop nginx || true
sudo systemctl daemon-reload
sudo systemctl enable app.service
sudo systemctl restart app.service

echo "Waiting for health..."
for i in $(seq 1 ${MAX_RETRIES}); do
  if curl -fs ${HEALTH_CHECK_URL} >/dev/null; then
    echo "Healthy ✅"
    curl -fs http://localhost/version || true
    exit 0
  fi
  echo "Retry ${i}/${MAX_RETRIES}..."
  sleep ${RETRY_DELAY}
done

echo "❌ Health check failed"
docker logs --tail 80 ${APP_NAME} || true
exit 1
