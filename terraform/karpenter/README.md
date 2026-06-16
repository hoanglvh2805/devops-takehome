# Spot vs on-demand for GPU AI inference

Spot GPU instances cut inference infrastructure cost by 60–70% and suit bursty or
batch workloads where a checkpoint/retry path exists. The trade-off is reclaim
risk: a two-minute spot notice can abort in-flight requests unless the scheduler
prefers spot (weight 100) but keeps an on-demand fallback pool (weight 10) for
SLO-critical traffic. For long-running synchronous inference, consolidation is
relaxed (`WhenEmpty` on the fallback pool, `WhenEmptyOrUnderutilized` with a
30-minute delay on spot) so Karpenter does not terminate nodes mid-request.
Production would add request draining, model warm pools on on-demand, and queue
back-pressure before accepting spot-only placement for latency-sensitive tiers.
