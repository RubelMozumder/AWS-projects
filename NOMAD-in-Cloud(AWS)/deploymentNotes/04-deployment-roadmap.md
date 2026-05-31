# AWS Deployment Roadmap (Step-by-Step, Test-Worthy)

This roadmap is intentionally incremental. Every step has a test gate so each AWS service is validated before moving on.

## Phase 0: Foundation and guardrails

### Deliverables

- AWS accounts/environments (dev first)
- IAM roles and least-privilege policies
- VPC, subnets, NAT/egress model
- Cost budgets and alert thresholds

### Test gates

- IAM access tests pass (no over-permission)
- Budget alerts trigger in test threshold mode
- Network reachability confirmed between private subnets and required endpoints

## Phase 1: EKS baseline (no data migration yet)

### Deliverables

- EKS cluster with:
  - app/system node group (on-demand)
  - worker node group (spot + fallback)
- AWS Load Balancer Controller
- ExternalDNS (optional)
- Basic observability (CloudWatch container logs/metrics)
- Initial GUI route mapping through ALB -> proxy -> app

### Test gates

- Test deployment can be scheduled on both node groups
- ALB ingress responds over HTTPS with ACM cert
- Cluster autoscaling responds to synthetic pod pressure
- GUI shell and static assets load correctly through ingress path

## Phase 2: Core NOMAD services in cluster (MVP runtime)

### Deliverables

- Deploy app, worker, proxy
- Deploy self-managed Temporal in cluster
- Keep North disabled
- Keep GUI bundled with app/proxy path for release simplicity

### Test gates

- Health endpoints stable
- Worker can process test workflow end-to-end
- Temporal UI/health checks accessible internally
- App and worker restart/recovery test passes
- GUI to API compatibility checks pass (login, search, upload screens)

## Phase 3: Managed data services integration

### Deliverables

- MongoDB Atlas on AWS connected from EKS
- OpenSearch Service connected from EKS
- Optional: move Temporal SQL to RDS PostgreSQL when ready

### Test gates

- Read/write integration tests pass for Mongo and search paths
- Indexing and query latency under agreed threshold
- Failover/reconnect behavior tested for transient DB/search outages

## Phase 4: Storage and backup hardening

### Deliverables

- EFS mounted for shared file paths
- Backup workflows to S3
- Retention/lifecycle policies enabled

### Test gates

- Data persistence test across pod restart/node replacement
- Restore drill from backup snapshot succeeds
- Storage growth alerting validated

## Phase 5: Autoscaling and load validation

### Deliverables

- HPA for app
- KEDA or custom queue-based scaling for workers
- Node autoscaling tuning for cost/performance
- GUI load profile testing (asset-heavy and API-heavy scenarios)

### Test gates

- Load test proves scale-out under traffic and queue growth
- Scale-in behavior meets stability criteria
- Cost/perf checks confirm no uncontrolled spend under load
- GUI response time and first-contentful render stay within target under load

## Phase 5b: Optional GUI CDN split (only if needed)

### Deliverables

- Versioned GUI static assets deployed to S3
- CloudFront distribution for static asset delivery
- Cache invalidation/versioning workflow in release pipeline

### Test gates

- GUI loads correctly from CDN while API stays on ALB/app
- No frontend/backend version drift after rollout
- Rollback test confirms quick recovery to previous GUI version

## Phase 6: North phase (later)

### Deliverables

- Enable north/JupyterHub in separate namespace and node group
- Apply storage/session and security controls

### Test gates

- Auth flow and notebook launch validated
- Session isolation and persistence checks pass
- Capacity tests for concurrent users pass

## Recommended release pattern

- Deploy by environment: dev -> staging -> production
- Promote only when all test gates pass in current environment
- Use rollback checkpoints per phase
