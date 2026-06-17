# NOMAD on AWS: Documentation Index

This documentation set is tailored to the selected direction:

- Priority: low-cost MVP first
- MongoDB: MongoDB Atlas on AWS
- Orchestration/workflows: keep Temporal on your own cluster
- NORTH/JupyterHub: deploy in a later phase

## Document map

1. [01-architecture-mvp.md](01-architecture-mvp.md)
   - MVP and target architecture
   - Data/control flow for NOMAD services
   - What runs where in AWS

2. [02-aws-compatible-services.md](02-aws-compatible-services.md)
   - Compatible AWS services per NOMAD component
   - Recommended service choices for MVP and scale phase

3. [03-cost-performance-comparison.md](03-cost-performance-comparison.md)
   - Cost/performance tradeoffs by service option
   - Practical shortlist for your specific constraints

4. [04-deployment-roadmap.md](04-deployment-roadmap.md)
   - Step-by-step roadmap with test gates
   - Each phase is independently testable

5. [05-testing-and-traffic-simulation.md](05-testing-and-traffic-simulation.md)
   - High-traffic simulation approaches
   - CDK patterns for autoscaling validation and repeatable load tests

6. [06-nomad-gui-architecture.md](06-nomad-gui-architecture.md)
   - NOMAD-gui deployment model options
   - Cost/performance and caching strategy for GUI assets
   - GUI-specific test and rollout checklist

## Scope notes

- This set describes architecture and delivery strategy only.
- No infrastructure was built and no runtime changes were applied.
- Configuration assumptions are based on NOMAD services found in the existing compose/Helm setup:
  - app, worker, north, logtransfer, proxy
  - temporal + postgresql
  - elasticsearch
  - mongodb
   - nomad-gui served through app/proxy path
