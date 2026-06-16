# Troubleshooting — Part 3

Diagnosis performed against `troubleshoot/broken-app.yaml`. Each issue is independent.

---

## Issue 1 — Web pods never become Ready (ImagePullBackOff)

**Symptom:** `kubectl get pods -n troubleshoot` shows `ImagePullBackOff` or `ErrImagePull` for `web-*`.

**Diagnosis:**
```bash
kubectl describe pod -n troubleshoot -l app=web | grep -A2 "Failed"
kubectl get deployment web -n troubleshoot -o jsonpath='{.spec.template.spec.containers[0].image}'
# nginx:1.25.99
```

**Root cause:** Invalid/non-existent image tag `nginx:1.25.99`.

**Fix:** Use a valid tag, e.g. `nginx:1.25`.

---

## Issue 2 — Web pods Pending (insufficient memory)

**Symptom:** Pods stuck `Pending`; events show insufficient memory.

**Diagnosis:**
```bash
kubectl describe pod -n troubleshoot -l app=web | grep -A5 Events
kubectl get deployment web -n troubleshoot -o yaml | grep -A3 requests
# memory: 16Gi
```

**Root cause:** `resources.requests.memory: 16Gi` exceeds agent node capacity in the local cluster.

**Fix:** Reduce requests/limits to realistic values (e.g. 64Mi request, 128Mi limit).

---

## Issue 3 — Probes failing (wrong port)

**Symptom:** Pods Running but not Ready; probe failures on port 8080.

**Diagnosis:**
```bash
kubectl describe pod -n troubleshoot -l app=web | grep -i probe
kubectl get deployment web -n troubleshoot -o jsonpath='{.spec.template.spec.containers[0].ports[0].containerPort}'
# 80
```

**Root cause:** nginx listens on **80**; liveness/readiness probes targeted **8080**.

**Fix:** Point probes at port 80.

---

## Issue 4 — ConfigMap mount failure

**Symptom:** Pod events: `configmap "web-conf" not found`.

**Diagnosis:**
```bash
kubectl get configmap -n troubleshoot
kubectl get deployment web -n troubleshoot -o jsonpath='{.spec.template.spec.volumes[0].configMap.name}'
# web-conf (ConfigMap is named web-config)
```

**Root cause:** Volume references `web-conf` but ConfigMap is `web-config`.

**Fix:** Align volume name to `web-config`.

---

## Issue 5 — Service has no endpoints

**Symptom:** `kubectl get endpoints web-svc -n troubleshoot` shows empty subsets.

**Diagnosis:**
```bash
kubectl get svc web-svc -n troubleshoot -o yaml | grep -A2 selector
kubectl get pods -n troubleshoot --show-labels | grep web
# selector app=webapp vs pod label app=web
kubectl get svc web-svc -n troubleshoot -o jsonpath='{.spec.ports[0].targetPort}'
# 8080 vs containerPort 80
```

**Root cause:** Service selector `app: webapp` does not match pod label `app: web`; `targetPort: 8080` does not match nginx on 80.

**Fix:** Selector `app: web`; `targetPort: 80`.

---

## Issue 6 — ai-inference Pending (wrong nodeSelector)

**Symptom:** `ai-inference` pod Pending; no matching nodes.

**Diagnosis:**
```bash
kubectl describe pod -n troubleshoot -l app=ai-inference | grep -A3 "Node-Selectors"
kubectl get nodes --show-labels | grep gpu
# node label is acme.io/node-type=gpu, not node-type=gpu
```

**Root cause:** `nodeSelector: node-type: gpu` uses wrong label key.

**Fix:** `nodeSelector: acme.io/node-type: gpu`.

---

## Issue 7 — ai-inference Pending (missing toleration)

**Symptom:** After fixing selector, pod still Pending with taint mismatch.

**Diagnosis:**
```bash
kubectl describe node -l acme.io/node-type=gpu | grep Taints
# nvidia.com/gpu=true:NoSchedule
kubectl get deployment ai-inference -n troubleshoot -o yaml | grep -i tolerat
# (none)
```

**Root cause:** GPU node is tainted; workload lacks toleration.

**Fix:** Add toleration for `nvidia.com/gpu=true:NoSchedule`.

---

## Issue 8 — Smoke test fails (NetworkPolicy default-deny)

**Symptom:** Rollouts succeed but `verify.sh` fails at smoke test; curl job cannot reach `web-svc`.

**Diagnosis:**
```bash
kubectl get networkpolicy -n troubleshoot
kubectl logs job/smoke-test -n troubleshoot
# connection timeout / refused
```

**Root cause:** `default-deny` blocks all ingress/egress; smoke client cannot egress to web pods; web pods cannot receive ingress; DNS may also be blocked.

**Fix:** Keep `default-deny`; add least-privilege policies:
- `allow-dns` — egress UDP/TCP 53 to `kube-system`
- `allow-web-ingress` — ingress to `app=web` from `app=smoke-client` on port 80
- `allow-smoke-egress` — egress from smoke client to `app=web` on port 80

**Verify:**
```bash
./troubleshoot/verify.sh
# PASS
```
