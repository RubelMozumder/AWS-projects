# Cost and Performance Comparison

## 1. Decision summary for your case

Given your choices (MVP-first, MongoDB Atlas, self-managed Temporal, North later), this shortlist is optimal:

- Orchestration: EKS
- Database: MongoDB Atlas on AWS
- Search: OpenSearch Service
- Workflow engine: Temporal in your EKS cluster
- Shared storage: EFS

## 2. Cost/performance table

| Area | Option A | Option B | Cost view | Performance view | Recommendation |
|---|---|---|---|---|---|
| GUI delivery | app-bundled via app/proxy | S3 + CloudFront | Bundled is cheapest to start (no extra frontend stack) | CDN is faster globally and reduces app load | Bundled first, CDN later if needed |
| Orchestration | EKS | ECS EC2/Fargate | EKS has control plane cost, but can be cheaper than Fargate at steady load | EKS gives strong scaling flexibility and ecosystem support | EKS |
| Mongo backend | MongoDB Atlas | DocumentDB | Atlas often cheaper at small-medium tiers and avoids migration overhead | Atlas is true Mongo behavior; fewer compatibility issues | Atlas |
| Search backend | OpenSearch Service | Self-managed Elasticsearch | Managed OpenSearch costs more than DIY infra at tiny scale but lower total ops cost | Better stability and scaling than DIY for production | OpenSearch Service |
| Temporal runtime | In-cluster Temporal | Temporal Cloud | In-cluster cheaper at low-medium scale if team can operate it | Good performance if tuned; more ops responsibility | In-cluster now |
| Temporal SQL store | In-cluster Postgres | RDS PostgreSQL | In-cluster can be cheaper initially | RDS provides better durability/operability | Start in-cluster, then evaluate RDS |
| Shared file storage | EFS | EBS-only or S3-only pattern | EFS can be pricier than EBS per GB, but simplifies multi-pod shared paths | EFS provides shared POSIX semantics | EFS for live, S3 for backup |
| Worker scaling capacity | On-demand only | Mixed Spot + on-demand | Mixed capacity is significantly cheaper for bursty/async workers | Comparable performance with fallback strategy | Mixed Spot + fallback |

## 3. Practical cost controls (high impact)

1. Keep North disabled in MVP.
2. Use small on-demand app node group and Spot-heavy worker node group.
3. Set worker min replicas low, scale by demand.
4. Use OpenSearch and Atlas right-sized tiers, upgrade only after load tests.
5. Snapshot and archive old data to S3 lifecycle tiers.
6. Keep one region in MVP; avoid premature multi-region spend.
7. Keep GUI served by app/proxy until traffic patterns justify CDN split.
8. If CDN is enabled later, use long cache TTL for versioned assets and short TTL for HTML shell.

## 4. Performance guidance by service

- App pods:
  - prioritize low latency and stable CPU
  - keep on on-demand nodes
- GUI path:
  - bundled mode is simpler, but app pods carry static asset serving load
  - CDN mode improves latency and offloads static requests from app pods
- Worker pods:
  - prioritize throughput per dollar
  - run mainly on Spot with disruption tolerance
- OpenSearch:
  - tune index lifecycle and shard strategy early
- Atlas:
  - monitor connection count and slow queries before vertical scaling
- Temporal:
  - track queue depth, activity latency, and retry rate

## 5. Expected MVP profile

- Best balance: moderate baseline cost, strong incremental scale path.
- Major cost drivers will be:
  - worker compute
  - OpenSearch storage/IO
  - Atlas tier and storage growth
  - potential CDN/data transfer if global GUI traffic is high

## 6. Development environment cost (decided)

**Decision: Scenario B — cluster stays up for the full sprint, EC2 nodes scaled to 0 when not working.**

Rationale: avoids the 15-minute cluster rebuild each morning while still saving EC2 cost during idle hours. EKS control plane stays live so kubectl access, dashboards, and Temporal UI remain reachable at any time.

### Configuration

| Parameter | Value |
|---|---|
| Cluster lifetime | 5 days (120 hours) |
| Active working hours | 10 hours/day × 5 days = 50 hours |
| App replicas | 4 (from `nomad-prod-develop.yaml`) |
| Worker replicas | 3 min → 15 max (KEDA, 8Gi request / 64Gi limit) |
| Databases | MongoDB Atlas M0 (free), Elasticsearch + PostgreSQL in-cluster |
| Node strategy | Spot instances, scaled to 0 outside working hours |

### Cost breakdown (5-day sprint)

| Service | Rate | Calculation | Cost |
|---|---|---|---|
| EKS control plane | $0.10/hr | 120hr × $0.10 | $12.00 |
| 2 × r5.2xlarge spot (nodes) | ~$0.12/hr each | 50hr × 2 × $0.12 | $12.00 |
| MongoDB Atlas M0 | free | — | $0.00 |
| Elasticsearch (in-cluster) | covered by EC2 | — | $0.00 |
| PostgreSQL for Temporal (in-cluster) | covered by EC2 | — | $0.00 |
| EFS 100GB | $0.30/GB/month | 100GB × $0.30 × (5/30) | $5.00 |
| ALB | $0.0225/hr | 120hr × $0.0225 | $2.70 |
| NAT Gateway (1 AZ) | $0.045/hr + $0.045/GB | 120hr × $0.045 + ~50GB data | $7.65 |
| Data transfer out | $0.09/GB | ~5GB dev traffic | $0.45 |
| CloudWatch logs | $0.50/GB | ~5GB logs | $2.50 |
| **Total** | | | **~$42** |

### Node scale-down approach

Scale the node group to 0 at end of working session, back to 2 at start:

```bash
# scale down (end of day)
aws eks update-nodegroup-config \
  --cluster-name nomad-dev \
  --nodegroup-name worker-spot \
  --scaling-config minSize=0,maxSize=2,desiredSize=0

# scale up (start of day)
aws eks update-nodegroup-config \
  --cluster-name nomad-dev \
  --nodegroup-name worker-spot \
  --scaling-config minSize=2,maxSize=5,desiredSize=2
```

Or automate with EventBridge Scheduler (cron) triggering a Lambda that calls the above — adds ~$0 cost at this scale.

### Node sizing rationale

Minimum RAM needed for dev pods at request level:

| Workload | vCPU | RAM |
|---|---|---|
| 4 app replicas | 2 | 8Gi |
| 3 workers (min) | 6 | 24Gi |
| cpuworker × 1 | 1 | 4Gi |
| Temporal + PostgreSQL | 0.8 | 1.5Gi |
| Elasticsearch (in-cluster) | 1 | 2Gi |
| MongoDB (in-cluster) | 0.5 | 1Gi |
| kube-system + KEDA | 1 | 2Gi |
| **Total** | **~12** | **~43Gi** |

Two r5.2xlarge nodes (8 vCPU, 64GB each = 128GB total) gives comfortable headroom.

### Monthly equivalent (if running the same pattern every week)

~$42 × (30/5) ≈ **$252/month** — significantly cheaper than the full always-on dev estimate of ~$390/month.
