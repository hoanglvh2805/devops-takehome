#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${K3D_CLUSTER_NAME:-devops-assignment}"
KUBECONFIG_PATH="${KUBECONFIG:-/kubeconfig/config}"

export KUBECONFIG="$KUBECONFIG_PATH"

wait_for_cluster() {
  local attempts=0
  until kubectl cluster-info >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 120 ]; then
      echo "Timed out waiting for Kubernetes API" >&2
      exit 1
    fi
    sleep 2
  done
}

if [ "${1:-}" = "bootstrap" ]; then
  shift
  /scripts/00-bootstrap.sh "$@"
  exit $?
fi

if [ "${1:-}" = "idle" ]; then
  echo "Toolbox ready. Run: docker compose exec toolbox /scripts/run-all.sh"
  tail -f /dev/null
fi

wait_for_cluster
exec "$@"
