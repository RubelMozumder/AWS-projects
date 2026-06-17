# NOMAD AWS Deployment: Knowledge Map

**Goal:** Deploy NOMAD research data management platform to AWS EKS using Terraform + Helm.

---

## Quick Lookup

| I need to... | Go to |
|---|---|
| Understand what runs where on AWS | `deploymentNotes/01-architecture-mvp.md` |
| Choose AWS services for each component | `deploymentNotes/02-aws-compatible-services.md` |
| Write Terraform (EKS/ALB/EFS/RDS) | `deploymentNotes/` decisions + Helm values below |
| See all NOMAD service ports & defaults | `nomad-FAIR/nomad/config/defaults.yaml` |
| Read/edit the Helm chart | `nomad-distro/ops/kubernetes/nomad/` |
| See production replica counts & limits | `nomad-distro/ops/kubernetes/nomad-prod.yaml` |
| See Kubernetes pod specs | `nomad-distro/ops/kubernetes/nomad/templates/` |
| Understand what goes in ConfigMap | `nomad-docs/docs/howto/oasis/configure.md` |
| Auth / Keycloak / Cognito config | `nomad-docs/docs/howto/oasis/secure.md` |
| Build the Docker image | `nomad-distro/Dockerfile` |
| Load testing | `nomad-FAIR/ops/locust/` |

---

## MVP Architecture

```
EKS Cluster
├── Helm-managed deployments (nomad-distro/ops/kubernetes/nomad/)
│   ├── app         — FastAPI + React GUI  (port 8000 internal)
│   ├── worker      — Task workers         (KEDA: 3–15 replicas)
│   ├── cpuworker   — CPU-intensive jobs
│   ├── gpuworker   — GPU workers          (Phase 2)
│   ├── proxy       — Nginx reverse proxy  (port 80)
│   └── temporal    — Workflow engine      (port 7233)
│
├── AWS Managed (Terraform-provisioned, NOT in-cluster)
│   ├── MongoDB Atlas        — metadata & user data      (port 27017)
│   ├── OpenSearch Service   — search & indexing         (port 9200, TLS)
│   ├── RDS PostgreSQL       — Temporal state store      (port 5432)
│   ├── EFS                  — shared NOMAD file storage (CSI driver)
│   ├── S3                   — backups & static assets
│   ├── ALB                  — ingress (replaces nginx ingress controller)
│   ├── Route 53             — DNS
│   ├── ACM                  — TLS certificates
│   └── Keycloak / Cognito   — OIDC authentication
│
└── Deferred to Phase 2
    ├── NORTH / JupyterHub
    └── GPU worker pools
```

---

## Folder Reference

### `nomad-FAIR/` — Core Application Source

The actual NOMAD Python + React application. **Do not modify for deployment.** Read it to understand what config the app expects.

```
nomad-FAIR/
├── nomad/
│   ├── app/main.py           — FastAPI entry point
│   ├── app/v1/               — REST API v1 routes
│   ├── config/defaults.yaml  — ALL default config (ports, timeouts, feature flags)
│   ├── actions/              — Temporal workflows & activities
│   ├── auth/                 — Authentication logic
│   ├── mongo/                — MongoDB operations
│   ├── parsing/              — File parsers (200+ formats)
│   ├── normalizing/          — Data normalization pipeline
│   └── north/                — JupyterHub integration
├── gui/                      — React frontend (built into Docker image)
├── ops/
│   ├── docker-compose/
│   │   ├── infrastructure/           — Reference: MongoDB, Elasticsearch, RabbitMQ
│   │   ├── nomad-oasis/              — Standalone OASIS compose (config reference)
│   │   └── nomad-oasis-with-keycloak/ — OASIS + Keycloak auth
│   └── locust/               — Load testing scripts
└── Dockerfile                — Multi-stage: base_node → base_python → dev → final
```

**Service ports** (from `nomad/config/defaults.yaml`):

| Service | Port |
|---|---|
| App (FastAPI) | 8000 |
| Elasticsearch / OpenSearch | 9200 |
| MongoDB | 27017 |
| Temporal frontend | 7233 |
| PostgreSQL | 5432 |

---

### `nomad-distro/` — PRIMARY DEPLOYMENT PACKAGE

Everything Terraform + Helm work starts here.

```
nomad-distro/
├── ops/kubernetes/                     ← DEPLOYMENT ROOT
│   ├── nomad/                          — Helm chart
│   │   ├── Chart.yaml                  — chart v1.1.0, app v1.2.2; Helm dep list
│   │   ├── values.yaml                 — default Helm values (base layer)
│   │   └── templates/
│   │       ├── configmap.yml           — generates nomad.yaml mounted into pods
│   │       ├── app/
│   │       │   ├── deployment.yaml     — app pod spec (image, resources, mounts)
│   │       │   └── service.yaml        — ClusterIP service for app
│   │       ├── worker/deployment.yaml  — worker pod spec
│   │       ├── cpuworker/deployment.yaml
│   │       ├── gpuworker/deployment.yaml
│   │       ├── proxy/deployment.yaml   — nginx proxy pod spec
│   │       ├── ingress.yaml            — GUI ingress (currently NGINX IC)
│   │       ├── ingress-api.yaml        — API ingress
│   │       ├── hpa.yaml                — Horizontal Pod Autoscaler
│   │       └── serviceaccount.yaml
│   │
│   ├── values.yaml                     — shared overrides (used across envs)
│   ├── nomad-prod.yaml                 — production values ← READ THIS
│   ├── nomad-prod-develop.yaml         — dev env (nightly auto-updates)
│   ├── nomad-prod-staging.yaml         — staging env
│   └── nomad-prod-test.yaml            — test/QA env
│
├── Dockerfile                          — production image (Python 3.12 + uv + GUI)
├── Dockerfile_jupyter                  — JupyterHub image (NORTH, Phase 2)
├── pyproject.toml                      — plugin dependencies (uv-managed)
└── .github/workflows/build-app.yml    — GitHub Actions: build & push to GHCR
```

#### Helm Chart Dependencies (from `Chart.yaml`)

| Helm Dep | Version | AWS Replacement |
|---|---|---|
| Elasticsearch | 7.17.3 | AWS OpenSearch Service |
| MongoDB | 14.0.4 | MongoDB Atlas |
| PostgreSQL | 12.1.6 | RDS PostgreSQL |
| Temporal | 0.73.2 | Keep in-cluster (no AWS managed equiv) |
| JupyterHub | 3.2.1 | Keep in-cluster (Phase 2) |

#### Production Sizing (`nomad-prod.yaml`)

| Component | Replicas | Memory Request | Memory Limit |
|---|---|---|---|
| app | 16 | — | — |
| worker | 3–15 (KEDA) | 8Gi | 32Gi |
| cpuworker | varies | 8Gi | 32Gi |

- Ingress rate limit: **32 RPS**
- Max upload size: **32 GB**

#### Volume Mounts (in `configmap.yml` / pod specs)

| Mount path | Purpose | AWS Target |
|---|---|---|
| `/app/nomad.yaml` | Config file | ConfigMap |
| `/app/.volumes/fs/public` | Public uploads | EFS |
| `/app/.volumes/fs/staging` | Staging uploads | EFS |
| `/nomad` | Main data dir | EFS |

Current StorageClass: `csi-sc-cinderplugin` (OpenStack Cinder)
**Must replace with:** `efs-sc` (AWS EFS CSI driver)

#### Ingress: Current vs AWS

Current: NGINX Ingress Controller + cert-manager TLS
AWS target: AWS Load Balancer Controller (ALB) + ACM

```yaml
# aws-overrides.yaml snippet
ingress:
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: <ACM ARN>
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
```

---

### `nomad-docs/` — Official NOMAD Documentation

Read for config reference and operations procedures. Not deployed.

```
nomad-docs/docs/
├── howto/oasis/
│   ├── configure.md    — ALL nomad.yaml config keys  ← READ FOR CONFIGMAP VALUES
│   ├── secure.md       — Keycloak/OIDC setup          ← READ FOR COGNITO CONFIG
│   ├── install.md      — Installation walkthrough
│   ├── deploy.md       — Deployment procedures
│   ├── update.md       — Upgrade procedures
│   ├── administer.md   — Admin tasks
│   └── troubleshoot.md — Common issues & fixes
├── explanation/
│   ├── architecture.md — System architecture
│   ├── processing.md   — Data processing pipeline
│   └── workflows.md    — Temporal workflow design
└── reference/
    ├── plugins.md      — Plugin system
    └── glossary.md     — Key terms
```

---

### `deploymentNotes/` — Your AWS Architecture Decisions

Your own planning docs. Source of truth for all AWS design choices.

| File | Contents |
|---|---|
| `00-overview.md` | Index & scope |
| `01-architecture-mvp.md` | MVP design, data flow, service mapping |
| `02-aws-compatible-services.md` | AWS service selection per NOMAD component |
| `03-cost-performance-comparison.md` | Cost/performance tradeoffs |
| `04-deployment-roadmap.md` | Phase-by-phase rollout |
| `05-testing-and-traffic-simulation.md` | Load testing with Locust |
| `06-nomad-gui-architecture.md` | GUI: CloudFront vs ALB options |

---

## Terraform Implementation Notes

### What Terraform must provision

```
VPC + Subnets + Security Groups
EKS Cluster
├── Node group: system/app  (on-demand, e.g. m5.xlarge)
└── Node group: worker      (spot + on-demand, memory-optimized)
ALB (via AWS Load Balancer Controller addon in-cluster)
EFS (shared storage, mounted via EFS CSI driver addon)
S3 bucket (backups)
RDS PostgreSQL (Temporal state; multi-AZ for production)
IAM roles (IRSA): EFS access, ALB controller, S3 backup, OpenSearch
Route 53 hosted zone + A records
ACM certificate (must validate before ALB can use it)
MongoDB Atlas (mongodbatlas Terraform provider + VPC peering)
OpenSearch Service domain (inside VPC)
```

### Helm deploy sequence (after Terraform apply)

1. Terraform outputs: cluster endpoint, EFS ID, RDS endpoint, MongoDB URI, OpenSearch endpoint
2. Install EKS addons: EFS CSI driver, AWS Load Balancer Controller, KEDA
3. `helm upgrade --install nomad ./nomad-distro/ops/kubernetes/nomad \`
   `-f nomad-distro/ops/kubernetes/nomad-prod.yaml \`
   `-f aws-overrides.yaml`
4. `aws-overrides.yaml` contains the service substitutions and EFS StorageClass

### Key `nomad.yaml` values (go into ConfigMap template)

```yaml
# nomad-FAIR/nomad/config/defaults.yaml is the authoritative key reference
services:
  api_host: <Route53 FQDN>
elastic:
  host: <OpenSearch VPC endpoint>
  port: 443
  use_ssl: true
mongo:
  host: <Atlas connection string>
temporal:
  host: temporal-frontend   # in-cluster Temporal service name
keycloak:
  server_url: <Cognito user pool / Keycloak URL>
  realm_name: <realm>
  client_id: nomad
```

---

## NOMAD Terminology

| Term | Meaning |
|---|---|
| Distribution | Git repo with Dockerfile + plugins (= `nomad-distro`) |
| Oasis | A live NOMAD deployment instance |
| NORTH | JupyterHub integration for analysis notebooks |
| Temporal | Workflow engine managing parsing & processing jobs |
| Central Deployment | NOMAD's own prod pipeline (develop→staging→test→prod) |
| Oasis Deployment | Plugin dev testbed on the `test-oasis` branch |

---

## Plugin System

Plugins are declared in `nomad-distro/pyproject.toml` under `[project.optional-dependencies]`.
They are baked into the Docker image at build time — no runtime changes needed for AWS.

Categories: `parsers-*`, `schema-*`, `north-*` (JupyterHub tools), `nexus-*` (NXTools), `ai-toolkit`.

---

**Last ingested:** 2026-06-12 | **Branch:** ScalableNomad
**Status:** Architecture designed in `deploymentNotes/`; Terraform IaC in progress
