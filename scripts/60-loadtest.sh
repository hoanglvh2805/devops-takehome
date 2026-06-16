#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/kubeconfig/config}"

echo "Part 6 load test — optional. Install observability stack then run k6."
echo "Skipping in default run-all; execute manually: docker compose exec toolbox /scripts/60-loadtest.sh"
exit 0
