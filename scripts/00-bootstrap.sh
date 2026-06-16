#!/usr/bin/env bash
# Run scripts from host by delegating into the toolbox container.
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

CLUSTER="${K3D_CLUSTER_NAME:-devops-assignment}"
export KUBECONFIG="${KUBECONFIG:-/kubeconfig/config}"
HOST_WS="${HOST_WORKSPACE:?HOST_WORKSPACE must be set to the host repo path}"

echo "==> Creating k3d cluster '${CLUSTER}' (4 agents) if missing..."
if ! k3d cluster list | grep -q "^${CLUSTER}"; then
  k3d cluster create "${CLUSTER}" \
    --agents 4 \
    --api-port 6550 \
    --port "8080:80@loadbalancer" \
    --volume "${HOST_WS}:/workspace@all" \
    --k3s-arg '--kubelet-arg=eviction-hard=imagefs.available<1%,nodefs.available<1%@agent:*' \
    --wait
  k3d kubeconfig merge "${CLUSTER}" --kubeconfig-merge-default=false --output "${KUBECONFIG}"
  chmod 666 "${KUBECONFIG}" 2>/dev/null || true
else
  k3d kubeconfig merge "${CLUSTER}" --kubeconfig-merge-default=false --output "${KUBECONFIG}" 2>/dev/null || true
fi

kubectl cluster-info
kubectl get nodes

echo "==> Initializing git repo (required for ArgoCD file:// source)..."
cd /workspace
if [ ! -d .git ]; then
  git init -q
  git config user.email "devops@local"
  git config user.name "devops"
fi

echo "==> Labeling nodes (spot / on-demand / GPU)..."
/troubleshoot/prepare.sh

echo "==> Bootstrap complete."
