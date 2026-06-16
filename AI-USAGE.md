# AI Usage Disclosure

## Tools used

- **Cursor (Claude)** — primary assistant for scaffolding compose/scripts, Helm chart, troubleshooting fixes, Terraform/Karpenter YAML, and documentation.

## Prompts that moved the work forward

1. *"Create a k3d docker-compose harness with a toolbox container (kubectl, helm, terraform, k6) and idempotent numbered scripts that a reviewer runs via ./scripts/run-all.sh"*
2. *"Design Helm placement for 3 replicas: prefer spot, at least one on on-demand, soft spread across nodes for spot reclaim resilience"*
3. *"Diagnose all issues in troubleshoot/broken-app.yaml without deleting default-deny NetworkPolicy or node taints"*

## Where the AI was wrong — and how I corrected it

**ArgoCD + local Helm chart:** The first suggestion used `repoURL: file:///workspace/helm/quote-api` without mounting `/workspace` into `argocd-repo-server`. ArgoCD pods couldn't read the chart and sync stayed `Unknown`. I verified with `kubectl logs -n argocd deploy/argocd-repo-server`, then patched the deployment with a `hostPath` volume (k3d already mounts the repo at `/workspace` on nodes) and registered a `file:///workspace` repository secret with `path: helm/quote-api`.

**Topology spread too aggressive:** An initial draft used `whenUnsatisfiable: DoNotSchedule` on `kubernetes.io/hostname`, which blocked rescheduling during the spot drain drill. I softened hostname spread to `ScheduleAnyway` while keeping capacity spread strict enough to guarantee an on-demand replica.

## Verification approach

- Ran `./scripts/run-all.sh` end-to-end locally.
- Cross-checked Karpenter API version against current `karpenter.sh/v1` docs (not legacy `v1beta1`).
- Ran `troubleshoot/verify.sh` until `PASS`.
- Reviewed Semgrep/Terraform output manually before trusting generated configs.
