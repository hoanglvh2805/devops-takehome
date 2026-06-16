#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/kubeconfig/config}"

SPOT_NODE=$(kubectl get nodes -l acme.io/capacity=spot -o jsonpath='{.items[0].metadata.name}')
echo "==> Spot reclaim drill — draining node: ${SPOT_NODE}"
echo "Pods before drain:"
kubectl get pods -n quote-api -o wide

echo "==> Starting background curl loop (30 requests)..."
(
  ok=0
  fail=0
  for i in $(seq 1 30); do
    if curl -fsS --max-time 3 -H "Host: quote-api.localhost" "http://127.0.0.1:8080/api/quote" >/dev/null 2>&1; then
      ok=$((ok + 1))
      echo "  [${i}] OK"
    else
      fail=$((fail + 1))
      echo "  [${i}] FAIL (may recover)"
    fi
    sleep 1
  done
  echo "Curl summary: ${ok} OK, ${fail} fail"
) &
CURL_PID=$!

kubectl drain "${SPOT_NODE}" --ignore-daemonsets --delete-emptydir-data --force --grace-period=30
echo "==> Pods after drain:"
kubectl get pods -n quote-api -o wide
kubectl get events -n quote-api --sort-by='.lastTimestamp' | tail -10

wait "${CURL_PID}" || true

echo "==> Uncordoning ${SPOT_NODE}..."
kubectl uncordon "${SPOT_NODE}"
kubectl get nodes
kubectl get pods -n quote-api -o wide
echo "Reclaim drill complete."
