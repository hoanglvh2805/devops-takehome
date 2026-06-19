#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

ROOT="/workspace"
CLUSTER="${K3D_CLUSTER_NAME:-devops-assignment}"
IMAGE_REPO="${IMAGE_REPO:-registry.gitlab.com/mrobert280525/devops-takehome}"
GIT_SHA="${GIT_SHA:-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)}"
TAG="${IMAGE_REPO}:${GIT_SHA}"
LOCAL_TAG="quote-api:${GIT_SHA}"

echo "==> Building image ${LOCAL_TAG}..."
docker build -t "${LOCAL_TAG}" -f "${ROOT}/Dockerfile" "${ROOT}"

echo "==> Importing image into k3d cluster..."
k3d image import "${LOCAL_TAG}" -c "${CLUSTER}"

echo "==> Image ready: ${TAG} (imported as ${LOCAL_TAG})"
echo "${GIT_SHA}" > /tmp/git-sha
echo "${LOCAL_TAG}" > /tmp/local-image
