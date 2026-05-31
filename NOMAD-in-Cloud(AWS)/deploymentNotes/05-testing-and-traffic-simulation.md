# Traffic Simulation and Autoscaling Validation (CDK-Aware)

## 1. Short answer

Yes, you can use CDK to provision high-traffic test infrastructure and autoscaling experiments.

Important nuance:

- CDK does not natively generate traffic by itself.
- CDK is excellent for creating repeatable load-testing stacks and autoscaling test environments.

## 2. Practical options

## Option A: Locust on ECS Fargate (CDK-managed)

Best when you want a simple isolated load generator without touching EKS workloads.

- CDK provisions:
  - ECS cluster/service or scheduled tasks running Locust
  - CloudWatch dashboards and alarms
- Good for:
  - API load profiles
  - ramp/soak tests

## Option B: Locust or k6 in EKS (CDK + Helm)

Best when you want in-cluster network-realistic testing.

- CDK provisions:
  - EKS test namespace
  - Helm chart/job for Locust/k6
  - metrics and alarms
- Good for:
  - full path tests including ingress and service mesh/network policy effects

## Option C: AWS Distributed Load Testing solution

- AWS provides a managed solution pattern for distributed load generation.
- Useful for large concurrent user simulations.
- Can be integrated into IaC workflows; teams often wrap deployment steps in CDK/CI pipelines.

## 3. Autoscaling validation design

To prove autoscaling is truly working, test in layers:

1. Pod scaling:
- Verify HPA scales app pods on CPU/RPS metrics.

2. Worker scaling:
- Verify queue-aware scaling policy (KEDA/custom metric) expands and shrinks worker replicas correctly.

3. Node scaling:
- Verify cluster autoscaler/Karpenter adds and removes nodes as pod demand changes.

4. Cost safety:
- Verify budgets/alerts during stress and soak tests.

## 4. Recommended MVP test plan

1. Baseline test:
- Low RPS and low queue; confirm stability and latency.

2. Burst test:
- Sudden RPS increase; confirm app scale-out and recovery.

3. Queue stress test:
- Push workflow backlog; confirm worker scale-out and drain time.

4. Soak test:
- Long-running moderate load; confirm no memory leaks or runaway cost.

5. Failure test:
- Simulate pod/node interruption; confirm graceful recovery and bounded error rate.

6. GUI-heavy test:
- Simulate many concurrent users loading GUI routes and static assets.
- Verify asset delivery latency and API call latency separately.

7. GUI/API compatibility test:
- Validate that deployed GUI version correctly targets current API endpoints.
- Include smoke tests for login, search, upload, and entry detail views.

## 5. Suggested CDK repository structure for tests

- cdk/stacks/networking-stack
- cdk/stacks/eks-stack
- cdk/stacks/observability-stack
- cdk/stacks/loadtest-stack
- loadtests/locust
- loadtests/k6

This keeps load generation repeatable, versioned, and environment-specific.

## 6. Recommendation for your current plan

- Start with Locust in a dedicated loadtest stack.
- Keep North out of first load campaign.
- Validate app/worker autoscaling first, then add North-specific scenarios in phase 2.
- Add GUI-heavy load scenario before deciding whether to split GUI to S3 + CloudFront.
