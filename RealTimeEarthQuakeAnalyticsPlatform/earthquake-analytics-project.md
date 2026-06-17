# Real-Time Earthquake Analytics Platform on AWS
### A Data Engineering Portfolio Project

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Motivation](#2-motivation)
3. [Data Source](#3-data-source)
4. [Architecture Overview](#4-architecture-overview)
5. [Service Comparisons by Layer](#5-service-comparisons-by-layer)
6. [Terraform Stacks Plan](#6-terraform-stacks-plan)
7. [Estimated Costs](#7-estimated-costs)
8. [Build Roadmap (40 Hours)](#8-build-roadmap-40-hours)

---

## 1. Project Overview

This project builds a **real-time seismic data ingestion and analytics pipeline** on AWS,
processing global earthquake data continuously sourced from the United States Geological
Survey (USGS). The system ingests, transforms, stores, and prepares earthquake events
for analytical querying and visual dashboards.

The pipeline demonstrates a production-grade, cloud-native data engineering architecture
covering streaming ingestion, serverless compute, data lake design, and SQL-based
analytics — all provisioned with **Terraform Stacks** as Infrastructure as Code (IaC).

### What the system does

```
USGS Live Feed (every 5 min)
        │
        ▼
  EventBridge Scheduler
        │  triggers
        ▼
  Collector Lambda          ← fetches GeoJSON from USGS, posts events to API Gateway
        │
        ▼
  API Gateway (REST)        ← entry point / ingestion layer
        │
        ▼
  Kinesis Data Firehose     ← buffers, batches, and delivers the stream
        │  invokes
        ▼
  Transformer Lambda        ← enriches & normalises each earthquake record
        │
        ▼
  Amazon S3
  ├── raw/                  ← original records as received
  └── processed/            ← cleaned, enriched, Parquet-formatted records
        │
        ▼
  AWS Glue Data Catalog     ← schema registry, makes S3 queryable
        │
        ▼
  Amazon Athena             ← serverless SQL engine over S3
        │
        ▼
  Amazon QuickSight         ← dashboards & visualisations  (Phase 2 — new account)
```

---

## 2. Motivation

### Why this project for a portfolio?

| Goal | How This Project Addresses It |
|---|---|
| Show data engineering skills | End-to-end pipeline: ingest → transform → store → query |
| Demonstrate AWS breadth | 8+ AWS services working together |
| Show IaC maturity | Full Terraform Stacks with modular design |
| Real-world relevance | Live, continuously updating data source |
| Cost awareness | Architecture designed to minimise spend |
| Interviewer friendliness | Physics domain, intuitive dashboards |

### Why Earthquakes?

- **Always live** — USGS publishes new events around the clock, globally
- **Rich attributes** — magnitude, depth, location, fault type, significance score, tsunami warning flag
- **Geographically visual** — maps of earthquake clusters are immediately compelling
- **Analytically interesting** — time-series trends, depth vs. magnitude correlations, regional risk patterns
- **No synthetic data needed** — everything is real and publicly available under open licence

---

## 3. Data Source

### USGS Earthquake Hazards Program

**Base URL:** `https://earthquake.usgs.gov/earthquakes/feed/v1.0/`

| Feed | Update Frequency | Coverage |
|---|---|---|
| `summary/all_hour.geojson` | Real-time | Last 60 minutes |
| `summary/all_day.geojson` | Every minute | Last 24 hours |
| `summary/all_week.geojson` | Every minute | Last 7 days |
| `summary/all_month.geojson` | Every minute | Last 30 days |
| `summary/significant_month.geojson` | Every minute | Significant events, 30 days |

**No API key required. No rate limits for reasonable polling.**

### Sample earthquake record (GeoJSON feature)

```json
{
  "type": "Feature",
  "properties": {
    "mag": 4.2,
    "place": "15 km NNE of Tōkyō, Japan",
    "time": 1716412800000,
    "updated": 1716413100000,
    "tz": null,
    "url": "https://earthquake.usgs.gov/earthquakes/eventpage/us7000abcd",
    "detail": "...",
    "felt": 120,
    "cdi": 3.1,
    "mmi": 4.0,
    "alert": null,
    "status": "reviewed",
    "tsunami": 0,
    "sig": 284,
    "net": "us",
    "code": "7000abcd",
    "ids": ",us7000abcd,",
    "sources": ",us,",
    "types": "...",
    "nst": 45,
    "dmin": 0.621,
    "rms": 0.55,
    "gap": 76,
    "magType": "mb",
    "type": "earthquake",
    "title": "M 4.2 - 15 km NNE of Tōkyō, Japan"
  },
  "geometry": {
    "type": "Point",
    "coordinates": [139.7456, 35.8012, 42.0]
  },
  "id": "us7000abcd"
}
```

### Key fields we use

| Field | Description | Use in Pipeline |
|---|---|---|
| `mag` | Richter magnitude | Core metric, dashboard KPI |
| `place` | Human-readable location | Display, filtering |
| `time` | Unix timestamp (ms) | Partitioning S3 by date |
| `tsunami` | Tsunami warning flag (0/1) | Alert enrichment |
| `sig` | USGS significance score (0–1000) | Severity classification |
| `coordinates[0]` | Longitude | Map visualisation |
| `coordinates[1]` | Latitude | Map visualisation |
| `coordinates[2]` | Depth (km) | Depth vs. magnitude analysis |
| `felt` | Number of felt reports | Human impact metric |

---

## 4. Architecture Overview

### Layer-by-layer description

#### Layer 1 — Data Collection (EventBridge + Collector Lambda)
An **EventBridge Scheduler** triggers a **Collector Lambda** every 5 minutes.
The Lambda fetches the latest earthquake GeoJSON feed from USGS, deduplicates events
already seen (using a DynamoDB table or S3 marker), and posts each new event as a
separate JSON message to the API Gateway endpoint.

#### Layer 2 — Ingestion (API Gateway)
A **REST API Gateway** exposes a `POST /ingest` endpoint. It acts as the controlled
entry point to the pipeline — providing throttling, request validation, and a clean
separation between data producers and the streaming backend. In a real-world clickstream
scenario this is where your web SDK would post events directly. Here, the Collector
Lambda plays that role.

#### Layer 3 — Streaming & Buffering (Kinesis Data Firehose)
API Gateway forwards payloads directly to a **Kinesis Data Firehose** delivery stream.
Firehose buffers incoming records (configurable: up to 128 MB or 900 seconds) and
delivers them to S3, optionally invoking a Lambda for inline transformation before
delivery. This is the heart of the streaming layer.

#### Layer 4 — Transformation (Transformer Lambda)
A **Lambda function** is attached to Firehose as a **data transformation processor**.
It receives batches of raw records and performs:
- Field extraction and flattening (GeoJSON → flat JSON)
- Type casting (Unix ms timestamp → ISO 8601 string)
- Severity classification (`minor` / `moderate` / `strong` / `major` / `great`)
- Continent/region tagging from coordinates
- Tsunami alert flag normalisation
- Output in **Parquet** format for cost-efficient Athena queries

#### Layer 5 — Storage (Amazon S3 — Data Lake)
Two S3 prefixes separate concerns:

```
s3://your-bucket/
├── raw/
│   └── year=2025/month=05/day=23/hour=14/
│       └── firehose-delivery-2025-05-23-14-00-00.json.gz
└── processed/
    └── year=2025/month=05/day=23/
        └── earthquakes-2025-05-23-14-00.parquet
```

Hive-style partitioning (`year=`, `month=`, `day=`) allows Athena to scan only
relevant partitions, dramatically reducing query cost and time.

#### Layer 6 — Schema & Catalogue (AWS Glue)
**AWS Glue Data Catalog** stores the table schema for both raw and processed S3 prefixes.
A **Glue Crawler** can automatically detect new partitions. This makes the data
immediately queryable in Athena without manual schema management.

#### Layer 7 — Analytics (Amazon Athena)
**Amazon Athena** allows standard SQL queries directly against S3 data via the Glue
Catalog — no servers, no loading data. Pay only per TB scanned. Example queries:

```sql
-- Top 10 most significant earthquakes this month
SELECT place, mag, sig, depth, event_time
FROM processed_earthquakes
WHERE year = '2025' AND month = '05'
ORDER BY sig DESC
LIMIT 10;

-- Average magnitude by continent
SELECT region, AVG(mag) AS avg_magnitude, COUNT(*) AS event_count
FROM processed_earthquakes
GROUP BY region
ORDER BY avg_magnitude DESC;

-- Tsunami-warning events
SELECT place, mag, event_time, latitude, longitude
FROM processed_earthquakes
WHERE tsunami = 1
ORDER BY event_time DESC;
```

#### Layer 8 — Visualisation (Amazon QuickSight) — Phase 2
To be connected in a new AWS account to utilise the 30-day free trial.
Will connect to Athena as the data source and provide:
- World map of earthquake epicentres (coloured by magnitude)
- Time-series of daily event counts and average magnitude
- Depth vs. magnitude scatter plot
- Severity distribution bar chart
- Tsunami alert timeline

---

## 5. Service Comparisons by Layer

### Layer 2 — Ingestion Entry Point

| Service | Type | Best For | Why NOT chosen here |
|---|---|---|---|
| **API Gateway** ✅ | Managed REST/HTTP API | Controlled ingestion, auth, throttling | — our choice |
| Application Load Balancer | Layer-7 load balancer | High-throughput HTTP routing | No request validation, no direct Kinesis integration |
| Direct Kinesis PUT | SDK call | Internal services producing data | No HTTP entry point, no auth layer |
| SQS | Message queue | Decoupled producer/consumer | Pull-based, not ideal for streaming fan-out |

**Why API Gateway wins here:** It provides throttling, API key management, request
validation schemas, and native integration with Kinesis Firehose via AWS service
integrations — no Lambda needed just to forward messages.

---

### Layer 3 — Streaming & Buffering

| Service | Model | Replay | Ordering | Managed | Best For |
|---|---|---|---|---|---|
| **Kinesis Data Firehose** ✅ | Micro-batch delivery | No | No | Fully | S3/Redshift delivery, built-in Lambda transform |
| Kinesis Data Streams | Real-time shard stream | Yes (24h–365d) | Per shard | Partially | Complex consumers, replay needed, low latency |
| SQS Standard | Message queue | No | No | Fully | Decoupled async processing, at-least-once delivery |
| SQS FIFO | Message queue | No | Yes | Fully | Strict ordering, exactly-once processing |
| Amazon MSK (Kafka) | Distributed log | Yes | Per partition | Partially | Very high throughput, Kafka ecosystem |

**Why Kinesis Data Firehose wins here:**
- No shard management or scaling needed
- Native Lambda transformation built in
- Direct S3 delivery with automatic partitioning
- Pay per GB ingested (no minimum cost)
- Perfect for our data volume (no need for Kafka-scale infrastructure)

---

### Layer 4 — Data Transformation

| Service | Model | Latency | Cost Model | Best For |
|---|---|---|---|---|
| **Lambda (Firehose transformer)** ✅ | Serverless function | Milliseconds | Per invocation | Lightweight, inline record transformation |
| AWS Glue ETL | Serverless Spark | Minutes | Per DPU-hour | Large-scale batch ETL, complex joins |
| AWS Glue Streaming | Streaming Spark | Seconds | Per DPU-hour | High-volume streaming ETL |
| Amazon EMR | Managed Hadoop/Spark | Minutes | Per instance-hour | Petabyte-scale processing |
| AWS Step Functions + Lambda | Orchestrated workflow | Variable | Per state transition | Multi-step pipelines with branching logic |

**Why Lambda wins here:**
- Earthquake records are small and simple — no Spark cluster needed
- Firehose has native Lambda transform support
- Invoked only when data arrives (true serverless cost model)
- Sufficient for field flattening, type casting, and classification logic

---

### Layer 5 — Storage

| Service | Type | Query Engine | Cost | Best For |
|---|---|---|---|---|
| **Amazon S3** ✅ | Object store / Data Lake | Athena, Spark | Very low | Scalable, schema-flexible, works with everything |
| Amazon DynamoDB | NoSQL key-value | DynamoDB API / PartiQL | Medium | Low-latency lookups, operational data |
| Amazon RDS (PostgreSQL) | Relational database | SQL | Medium | Transactional, structured, OLTP |
| Amazon Redshift | Columnar data warehouse | SQL | High | Petabyte OLAP, complex aggregations |
| Amazon OpenSearch | Search & analytics engine | Lucene / OpenSearch SQL | High | Full-text search, log analytics |

**Why S3 wins here:**
- Data lake pattern is industry standard for analytics pipelines
- Schema-on-read: no migrations needed as data evolves
- Works natively with Athena, Glue, QuickSight, Spark
- Cheapest storage available on AWS at any scale

---

### Layer 7 — Query & Analytics

| Service | Model | Cost | Latency | Best For |
|---|---|---|---|---|
| **Amazon Athena** ✅ | Serverless SQL on S3 | Per TB scanned | Seconds | Ad-hoc SQL on S3 data lake |
| Amazon Redshift Spectrum | SQL on S3 via Redshift | Cluster + per TB | Seconds | When you already have Redshift |
| Amazon EMR | Spark/Hive cluster | Per instance | Minutes | Complex ML, large-scale joins |
| AWS Glue Studio | Visual ETL + Spark | Per DPU | Minutes | Transform-heavy pipelines |
| Amazon OpenSearch | Near-real-time search | Per instance | Milliseconds | Full-text, log analytics |

**Why Athena wins here:**
- Zero infrastructure — no cluster to manage
- Pay only for data scanned ($5 per TB — Parquet with partitioning reduces this by 90%+)
- Direct integration with Glue Catalog and QuickSight
- Standard ANSI SQL — any analyst can use it immediately

---

## 6. Terraform Stacks Plan

The project is divided into **5 Terraform Stacks**, each independently deployable.
This mirrors real-world infrastructure separation and teaches modular IaC design.

| Stack | Name | Contents | Est. Time |
|---|---|---|---|
| 1 | `foundation` | S3 bucket, IAM roles & policies, KMS key | 4 hrs |
| 2 | `ingestion` | API Gateway, Kinesis Firehose, EventBridge Scheduler | 8 hrs |
| 3 | `processing` | Collector Lambda, Transformer Lambda, DynamoDB dedup table | 8 hrs |
| 4 | `analytics` | Glue Database, Glue Crawler, Athena Workgroup, S3 results bucket | 6 hrs |
| 5 | `observability` | CloudWatch dashboards, alarms, Lambda error alerts via SNS | 4 hrs |

**Note:** Stacks depend on each other in order (1 → 2 → 3 → 4 → 5). Terraform remote
state in S3 with DynamoDB locking will be used to share outputs between stacks.

---

## 7. Estimated Costs

### Development account (your current account, no free tier)

| Service | Monthly Estimate | Notes |
|---|---|---|
| S3 storage | < $0.10 | ~50 MB/month of earthquake data |
| S3 requests | < $0.05 | GET/PUT for Firehose delivery |
| Kinesis Firehose | < $0.10 | ~50 MB ingested/month |
| Lambda (both functions) | < $0.10 | ~8,640 invocations/month (every 5 min) |
| API Gateway | < $0.05 | ~260,000 requests/month |
| EventBridge Scheduler | < $0.01 | ~8,640 invocations/month |
| DynamoDB (dedup table) | < $0.25 | On-demand, minimal reads/writes |
| Glue Crawler | < $0.50 | Run daily or on-demand |
| Athena | < $0.10 | Parquet + partitioning = minimal scans |
| CloudWatch | < $0.30 | Logs, metrics, dashboards |
| **Total** | **~$1.50/month** | Comfortably under $5 |

### Final deployment (new account — QuickSight free trial period)
Add QuickSight: $0 during 30-day trial → capture screenshots, demo video, then destroy.

---

## 8. Build Roadmap (40 Hours)

| Phase | Stack | Tasks | Hours |
|---|---|---|---|
| **Phase 1** | Setup | AWS account config, Terraform backend, project structure | 2 |
| **Phase 2** | Stack 1: Foundation | S3, IAM, KMS in Terraform | 4 |
| **Phase 3** | Stack 2: Ingestion | API Gateway + Firehose in Terraform | 8 |
| **Phase 4** | Stack 3: Processing | Collector Lambda + Transformer Lambda code + Terraform | 10 |
| **Phase 5** | Stack 4: Analytics | Glue Catalog + Athena + test queries | 6 |
| **Phase 6** | Stack 5: Observability | CloudWatch alarms, SNS alerts | 4 |
| **Phase 7** | Integration & Testing | End-to-end pipeline test, data validation | 4 |
| **Phase 8** | QuickSight | New account, connect to Athena, build dashboards | 2 |
| **Total** | | | **40 hrs** |

---

*Document version 1.0 — subject to revision as the project evolves.*
