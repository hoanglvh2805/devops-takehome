#!/usr/bin/env bash
if [ ! -f /kubeconfig/config ] && [ -z "${INSIDE_TOOLBOX:-}" ]; then
  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  exec docker compose exec -e INSIDE_TOOLBOX=1 -e HOST_WORKSPACE="${ROOT}" toolbox "$0" "$@"
fi
set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-/kubeconfig/config}"
ROOT="/workspace"
CLUSTER="${K3D_CLUSTER_NAME:-devops-assignment}"
GIT_SHA="${GIT_SHA:-$(cat /tmp/git-sha 2>/dev/null || git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)}"
LOCAL_TAG="quote-api:${GIT_SHA}"
IMAGE_REPO="${IMAGE_REPO:-ghcr.io/hoanglvh2805/devops-takehome}"

echo "==> Using k3s built-in Traefik ingress (IngressClass traefik)..."
kubectl wait --for=condition=available deployment/traefik -n kube-system --timeout=120s 2>/dev/null \
  || kubectl get ingressclass traefik >/dev/null

echo "==> Installing ArgoCD..."
if ! helm status argocd -n argocd >/dev/null 2>&1; then
  kubectl delete namespace argocd --ignore-not-found --wait=true 2>/dev/null || true
  for kind in crd clusterrole clusterrolebinding; do
    kubectl get "${kind}" -o name 2>/dev/null | grep -E 'argocd|argoproj' | xargs -r kubectl delete --wait=true 2>/dev/null || true
  done
  sleep 5
fi
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set configs.params."reposerver\.enable\.helm\.manifest\.max\.extracted\.size"=1G \
  --wait --timeout 10m
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

echo "==> Creating quote-api namespace..."
kubectl create namespace quote-api --dry-run=client -o yaml | kubectl apply -f -

echo "==> Preparing local git repo for ArgoCD..."
cd "${ROOT}"
if [ ! -d .git ]; then
  git init -q
  git config user.email "devops@local"
  git config user.name "devops"
fi
git add -A
git diff --cached --quiet || git commit -q -m "local argocd sync" || true

echo "==> Mounting workspace into ArgoCD repo-server..."
kubectl patch deployment argocd-repo-server -n argocd --type=json -p='[
  {"op":"add","path":"/spec/template/spec/volumes/-","value":{"name":"workspace","hostPath":{"path":"/workspace","type":"Directory"}}},
  {"op":"add","path":"/spec/template/spec/containers/0/volumeMounts/-","value":{"name":"workspace","mountPath":"/workspace","readOnly":true}}
]' 2>/dev/null || true
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=180s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-workspace
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: file:///workspace
EOF

echo "==> Deploying via ArgoCD Application (Helm chart from repo)..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: quote-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: file:///workspace
    path: helm/quote-api
    targetRevision: HEAD
    helm:
      values: |
        image:
          repository: quote-api
          tag: "${GIT_SHA}"
          pullPolicy: IfNotPresent
        ingress:
          enabled: true
          className: traefik
          host: quote-api.localhost
  destination:
    server: https://kubernetes.default.svc
    namespace: quote-api
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo "==> Waiting for ArgoCD sync..."
for i in $(seq 1 60); do
  STATUS=$(kubectl get application quote-api -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo Unknown)
  HEALTH=$(kubectl get application quote-api -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo Unknown)
  echo "  sync=${STATUS} health=${HEALTH}"
  if [ "$STATUS" = "Synced" ] && [ "$HEALTH" = "Healthy" ]; then
    break
  fi
  sleep 5
done

kubectl rollout status deployment/quote-api -n quote-api --timeout=180s
kubectl get pods -n quote-api -o wide
kubectl get hpa,pdb,ingress -n quote-api

INGRESS_HOST="${INGRESS_HOST:-host.docker.internal}"
echo "==> Smoke test via ingress (host port 8080)..."
for i in $(seq 1 30); do
  if curl -fsS -H "Host: quote-api.localhost" "http://${INGRESS_HOST}:8080/api/quote" >/dev/null 2>&1; then
    curl -fsS -H "Host: quote-api.localhost" "http://${INGRESS_HOST}:8080/api/quote" | head -c 200
    echo ""
    echo "Deploy OK — quote-api reachable at http://localhost:8080/api/quote"
    exit 0
  fi
  sleep 2
done

echo "WARN: ingress curl failed; trying ClusterIP port-forward fallback..."
kubectl run curl-test --rm -i --restart=Never --image=curlimages/curl:8.7.1 -n quote-api -- \
  curl -fsS "http://quote-api.quote-api.svc/api/quote"
