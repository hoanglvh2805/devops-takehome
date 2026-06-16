#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/kubeconfig/config}"
DIR="/troubleshoot"

echo "==> Applying fixed manifests..."
kubectl delete namespace troubleshoot --ignore-not-found --wait=true 2>/dev/null || true
kubectl apply -f "${DIR}/fixed-app.yaml"

echo "==> Waiting for rollouts..."
kubectl rollout status deployment/web -n troubleshoot --timeout=120s
kubectl rollout status deployment/ai-inference -n troubleshoot --timeout=120s

echo "==> Running verifier..."
"${DIR}/verify.sh"
