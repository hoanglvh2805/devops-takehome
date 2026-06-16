#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

if ! docker compose ps --status running toolbox >/dev/null 2>&1; then
  echo "Starting docker compose..."
  docker compose up -d --build
  echo "Waiting for toolbox..."
  sleep 5
fi

export GIT_SHA="${GIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo local)}"

echo "========================================"
echo " DevOps Assignment — run-all"
echo "========================================"

docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/00-bootstrap.sh
docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/10-build.sh
docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/20-deploy.sh
docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/25-reclaim-drill.sh
docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/30-troubleshoot.sh
docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox /scripts/50-validate-tf.sh

echo ""
echo "========================================"
echo " ALL CORE SCRIPTS COMPLETED"
echo " Quote API: http://localhost:8080/api/quote"
echo "========================================"
