# Ops Answers — Part 7

## 1. EKS upgrade 1.33 → 1.35 with zero downtime

**Order of operations**

1. **Pre-flight** — read EKS release notes & addon compatibility matrix; snapshot etcd/RDS backups; confirm PodDisruptionBudgets and cluster-autoscaler/Karpenter headroom; pin target AMI/launch templates.
2. **Control plane** — upgrade one minor version at a time (1.33 → 1.34 → 1.35); AWS manages CP with rolling semantics; validate API (`kubectl get --raw /readyz`) after each step.
3. **Add-ons (each minor)** — upgrade in order: **vpc-cni** (network-critical) → **coredns** → **kube-proxy** → **EBS CSI** → **EFS CSI**; use EKS managed add-on versions tied to the cluster version; roll one add-on, watch pod restarts and DNS/network before the next.
4. **Data plane** — create new node groups / NodePools on the target K8s version; cordon old nodes; drain with respect to PDBs; shift workloads; decommission old ASGs/node groups only after all workloads and system pods are healthy on new nodes.
5. **Post-upgrade** — run conformance/smoke tests, verify admission webhooks, HPA, ingress, and metrics; update runbooks and pin terraform/eks module versions.

**Top 3 risks**

1. **Addon / CNI mismatch** — vpc-cni or kube-proxy skew breaks pod networking or Service routing mid-upgrade.
2. **Draining spot / GPU nodes under load** — aggressive drains evict inference or stateful pods despite PDBs if misconfigured.
3. **Deprecated API removals** — workloads using removed beta APIs fail silently after CP upgrade until manifests are updated.

---

## 2. Spot reclaim alert storms at 3 AM

**Problem:** Spot interruptions trigger `KubeNodeUnreachable` / node-not-ready alerts that page on-call for expected spot churn.

**Strategy**

- **Separate alert tiers:** "Expected spot reclaim" (node has `karpenter.sh/disruption` or `aws-node-termination-handler` event, or node label `acme.io/capacity=spot`) → route to Slack/low-priority ticket, not PagerDuty.
- **Delay and aggregation:** For spot-labeled nodes, require node NotReady **> 10–15 minutes** OR combine with `absent(up{job="kubelet"})` only when **not** preceded by termination notice; use inhibition rules so termination-handler firing suppresses unreachable pages.
- **SLO-based paging:** Page on **user-facing symptoms** (error rate, latency, ready replicas < PDB min) rather than node-level signals alone.
- **Keep hard pages for on-demand / system nodes:** `acme.io/capacity=on-demand` or control-plane-adjacent failures still page immediately.

This kills false positives from normal spot recycling while real failures (on-demand node loss, region-wide API issues) still breach SLO alerts.

---

## 3. Cloudflare marketing site — LCP 5s, HTML caching suspected

**Step-by-step diagnosis**

1. **Reproduce by geography/device** — Cloudflare Speed Test / WebPageTest from mobile profiles; note TTFB vs LCP gap.
2. **Check response headers on HTML** — `curl -sI https://site.example/ | grep -i cache` — look for `cf-cache-status: MISS/BYPASS/DYNAMIC` and origin `Cache-Control`.
3. **Cloudflare dashboard** — Cache Rules / Page Rules: confirm HTML (`/` or `*.html`) is not bypassed unintentionally; verify no `Cache-Control: private, no-store` from origin overriding edge cache.
4. **Compare origin vs edge** — `curl -H "CF-Cache-Status: …"` and bypass Cloudflare (origin host / `hosts` file) to see if slow LCP is origin-render time vs CDN.
5. **Inspect HTML payload** — large uncached hero images, render-blocking JS, or font chains inflate LCP even if HTML is cached; use DevTools Performance → LCP element.
6. **Tiered fix** — cache static HTML at edge with appropriate TTL + stale-while-revalidate; keep dynamic cookies bypassed; optimize LCP element (preload hero image, CDN-transformed WebP/AVIF); enable Early Hints / HTTP3 if available.

---

## 4. Application secrets on EKS — two approaches

| | **AWS Secrets Manager + External Secrets Operator (ESO)** | **HashiCorp Vault with CSI / Agent injector** |
|---|----|----|
| **Pros** | Native AWS IAM integration; audit via CloudTrail; simple for AWS-centric stacks; ESO syncs to K8s Secrets automatically | Dynamic secrets, leasing, PKI, multi-cloud; fine-grained policies; rotation without pod restart (CSI sync) |
| **Cons** | Cost per secret/API call; sync lag; secrets still land in etcd as K8s Secrets unless using CSI driver | Operational burden (HA Vault cluster); steeper learning curve for startups |
| **Multi-cluster** | One Secrets Manager secret per env; ESO `ClusterSecretStore` per cluster with IAM roles | Vault namespaces/paths per cluster; central policy |

**Pick for a startup with multiple production EKS clusters:** **Secrets Manager + External Secrets Operator** — lower ops overhead, IAM role per cluster (IRSA), no Vault HA to run, integrates with existing AWS billing/compliance. Move to Vault later if dynamic credentials or multi-cloud secret brokering becomes a core requirement.
