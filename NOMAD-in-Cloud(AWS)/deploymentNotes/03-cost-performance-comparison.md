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
