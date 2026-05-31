# Architecture: Low-Cost MVP First

## 1. Context from current NOMAD layout

Your current distribution topology is composed of:

- app: NOMAD API + GUI runtime
- worker: background processing worker
- north: remote tools hub (JupyterHub path)
- proxy: nginx ingress/reverse proxy
- temporal + postgresql: workflow orchestration and state
- elasticsearch: search/index backend
- mongodb: metadata/user data backend
- logtransfer: optional

## 2. MVP architecture (recommended)

Goal: go live with minimum spend, keep autoscaling where it matters, and avoid heavy ops overhead.

### Compute and orchestration

- EKS cluster (single region, 2 node groups):
  - System/App node group (on-demand, small/medium instances)
  - Worker node group (spot-first with on-demand fallback)

### Stateless/runtime services in cluster

- In EKS:
  - nomad app deployment
  - nomad worker deployment
  - nginx/proxy deployment
  - temporal deployment (self-managed)
  - temporal-postgresql can be self-managed first, then moved to RDS
- Deferred to phase 2:
  - north/jupyterhub
  - gpu/cpu specialized action workers unless needed

### Managed data services

- MongoDB Atlas on AWS
- OpenSearch Service (managed)
- Optional later: RDS PostgreSQL for Temporal persistence if you want stronger durability/ops simplicity

### Networking and ingress

- AWS Load Balancer Controller in EKS
- ALB for HTTPS ingress
- ACM certificate + Route 53 DNS
- Security groups and network policies for namespace/service isolation

### NOMAD-gui architecture in MVP

- Primary mode for MVP:
  - Keep GUI bundled with the app service and exposed via nginx/proxy path routing.
  - This minimizes moving parts and avoids separate frontend deployment overhead.
- Optional optimization after baseline stability:
  - Serve immutable GUI static assets through CloudFront + S3, while API traffic still goes to ALB -> app.
  - Keep a strict versioning strategy so GUI and API remain compatible.

GUI request flow in MVP:

1. Browser -> Route 53 -> ALB
2. ALB -> proxy (nginx)
3. proxy -> app service for GUI and API routes
4. app -> MongoDB Atlas / OpenSearch / Temporal services

### Storage

- EFS for shared NOMAD filesystem paths used by app/worker
- S3 for backups, archive snapshots, and long-retention artifacts

## 3. Target architecture (after MVP)

- Enable north/JupyterHub in its own namespace/node pool
- Enable KEDA-driven worker autoscaling (Temporal queue based)
- Split app and worker node groups for finer cost/performance control
- Add observability stack with explicit SLO alerting
- Introduce multi-AZ posture for stronger availability targets
- Optionally externalize GUI static assets to CloudFront for lower latency and lower app egress/CPU pressure

## 4. Why this is the best fit for your constraints

- Lowest risk migration path from current compose/Helm topology
- Keeps architecture close to existing service boundaries
- Cost-effective start while preserving scale path
- Lets you validate each service independently before adding complexity
- Keeps NOMAD-gui deployment simple at first, then allows a safe CDN split once API behavior is stable

## 5. Explicit phase decision

You selected:

- North in later phase: yes

That is a good cost/risk decision because north introduces extra compute, storage, and identity/session complexity that is not required to validate core ingest/search/worker behavior first.
