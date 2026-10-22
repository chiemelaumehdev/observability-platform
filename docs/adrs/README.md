# Architecture Decision Records

Each ADR captures one significant choice: what was decided, what alternatives were weighed, and why the chosen option wins at the scale and constraints of this platform. ADRs are append-only — a decision that is later reversed is recorded as a new ADR that supersedes the earlier one.

## Index

| #    | Title                                                            | Status   |
|------|------------------------------------------------------------------|----------|
| 0001 | [SSB mode over microservices for Tempo, Mimir, Loki](0001-ssb-mode-over-microservices.md) | Accepted |
| 0002 | [OpenTelemetry Collector over Grafana Alloy as the agent](0002-otel-collector-over-alloy.md) | Accepted |
| 0003 | [Istio service mesh for workload mTLS](0003-istio-service-mesh-for-mtls.md) | Accepted |
| 0004 | [Grafana Unified Alerting as the single alerting engine](0004-grafana-unified-alerting.md) | Accepted |
| 0005 | [Tenant applications on ECS Fargate, platform on EKS](0005-ecs-fargate-for-tenant-apps.md) | Accepted |
| 0006 | [IRSA for pod AWS access, no static keys](0006-irsa-not-static-keys.md) | Accepted |
| 0007 | [S3 for backend storage across all three signal types](0007-s3-for-backend-storage.md) | Accepted |

## Template

```
# ADR NNNN: <title>

## Status
<Proposed | Accepted | Superseded by ADR XXXX>

## Context
<The forces at play. The problem to solve. Constraints that bound the solution space.>

## Decision
<The choice made, stated plainly.>

## Consequences
<What becomes easier. What becomes harder. What this locks in.>

## Alternatives considered
<Each alternative, with the specific reason it was not chosen.>
```
