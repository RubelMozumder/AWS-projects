# AWS-Compatible Services for NOMAD

## 1. Component-to-service compatibility matrix

| NOMAD component | AWS-compatible options | MVP recommendation | Notes |
|---|---|---|---|
| NOMAD-gui frontend delivery | app-bundled via nginx/app, S3 + CloudFront, Amplify Hosting | app-bundled via nginx/app for MVP | Bundled mode is simplest and keeps GUI/API version lockstep |
| Container orchestration | EKS, ECS EC2, ECS Fargate | EKS | Best alignment with your existing Helm/Kubernetes setup |
| App ingress | ALB, NLB, API Gateway | ALB | ALB works best for HTTP(S) path routing and TLS termination |
| TLS certs | ACM, self-managed certs | ACM | Lower ops overhead, automated rotation |
| DNS | Route 53, external DNS | Route 53 | Native AWS integration with ALB and health checks |
| Search backend | OpenSearch Service, self-managed Elasticsearch on EC2/EKS | OpenSearch Service | Managed ops, scaling, snapshots |
| Metadata DB | MongoDB Atlas on AWS, DocumentDB, self-managed MongoDB | MongoDB Atlas on AWS | Best Mongo compatibility and lowest migration friction |
| Workflow engine | Self-managed Temporal on EKS, Temporal Cloud | Self-managed Temporal on EKS | Matches your decision: "my cluster" |
| Temporal SQL backend | Self-managed PostgreSQL in cluster, RDS PostgreSQL | Start in cluster, then evaluate RDS | For MVP speed keep in-cluster; for durability move to RDS later |
| Shared file storage | EFS, EBS, S3 | EFS (+ S3 backup) | EFS for shared POSIX paths, S3 for cheap retention |
| Container images | ECR, GHCR, Docker Hub | ECR mirror of required images | Improves pull performance/control in AWS |
| Secrets/config | AWS Secrets Manager, SSM Parameter Store, K8s Secrets | Secrets Manager + External Secrets | Better security and rotation than plain K8s secrets |
| Logging/metrics | CloudWatch, AMP/Grafana, OpenSearch | CloudWatch first | Lowest friction for MVP operations |
| Autoscaling | HPA, KEDA, Cluster Autoscaler, Karpenter | HPA + Cluster Autoscaler first | Add KEDA for queue-aware worker scaling in phase 2 |

## 2. Services you should avoid for MVP

- ECS Fargate for all services:
  - Can become expensive for always-on worker-heavy workloads.
- DocumentDB as "drop-in Mongo" without testing:
  - API/feature differences can break edge behaviors.
- Self-managed Elasticsearch in-cluster for production MVP:
  - Operational burden is higher than managed OpenSearch.
- Separate GUI hosting stack before baseline validation:
  - Adds deployment coupling risks (cache invalidation, API/frontend version drift).

## 3. NOMAD-gui service choice details

- MVP path:
  - Keep GUI served from app/proxy path through ALB.
  - Benefit: simplest deployment and rollback model.
- Scale path:
  - Move static GUI assets to S3 + CloudFront if frontend traffic dominates.
  - Keep API on ALB/EKS app service.
- When to split GUI from app:
  - High global read traffic for static assets
  - Need for independent frontend release cadence
  - Need to reduce app CPU from static file serving

## 4. North/JupyterHub compatibility (phase 2)

- Strongly compatible on EKS with:
  - dedicated node group
  - separate namespace
  - persistent storage policy for user workspaces
- Keep it out of MVP to control spend and complexity.
