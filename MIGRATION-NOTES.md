# CI Migration Notes — GitLab → GitHub Actions

## What changed and why

| Legacy (GitLab) | Migrated (GitHub Actions) | Rationale |
|-----------------|----------------------------|-----------|
| `sonar_check` with `allow_failure: true` | Semgrep `--error` gate on `app/` | Quality scan must block merges; decorative scans don't migrate |
| `unit_test` with `\|\| echo "tests flaky, continuing"` | Pytest job; failures fail the workflow | Flaky tests are not ignored in production pipelines |
| `build_image` tags only `:latest` | GHCR push with `type=sha` tag + optional `latest` on default branch | Immutable deploy artifacts; matches Part 1 requirement |
| Hardcoded AWS keys in `variables` | Removed; use GitHub Secrets / OIDC | Secrets never belong in VCS (legacy values were AWS doc examples) |
| `deploy_prod` manual `kubectl set image` | Not migrated (out of scope for take-home) | GitOps (ArgoCD) replaces imperative prod deploys |
| `only: master` | `push`/`pull_request` on `main`/`master` | Standard GitHub trigger model |
| DinD docker:20.10 | `docker/build-push-action` with GITHUB_TOKEN → GHCR | Supported, cached, integrated with GitHub Packages |

## Secret / variable migration (real project)

| GitLab CI variable | GitHub equivalent |
|--------------------|-------------------|
| `CI_REGISTRY_USER` / `CI_REGISTRY_PASSWORD` | `GITHUB_TOKEN` (packages:write) or PAT with `write:packages` |
| `SONAR_HOST_URL` / `SONAR_TOKEN` | `SONAR_TOKEN` + `SONAR_HOST_URL` repo secrets, or Semgrep App token |
| `KUBECONFIG_CONTENT` | Removed — deploy via ArgoCD watching Git, not CI kubectl |
| `AWS_*` keys | `AWS_ROLE_ARN` + OIDC (`aws-actions/configure-aws-credentials`) instead of long-lived keys |

Recommended production pattern: CI builds/signs image → updates Helm `values` or ArgoCD image-updater → ArgoCD syncs. No cluster credentials in CI.

## Bonus items not implemented

- Trivy image scan gating — would add `aquasecurity/trivy-action` after build.
- Cosign signing — would add `sigstore/cosign-installer` + key in GitHub Secrets.

Both are straightforward add-ons once GHCR push is green.
