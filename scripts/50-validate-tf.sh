#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  exec docker compose exec -e INSIDE_TOOLBOX=1 toolbox "$0" "$@"
fi
set -euo pipefail

TF_DIR="/terraform/cloudflare"
cd "${TF_DIR}"

echo "==> terraform fmt -check"
terraform fmt -check -recursive

echo "==> terraform init -backend=false"
terraform init -backend=false

echo "==> terraform validate"
terraform validate

echo "Terraform validation PASS"
