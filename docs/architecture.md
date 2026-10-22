# Architecture

End-to-end architecture for the observability platform. For the reasoning behind individual choices, see [ADRs](adrs/).

## Topology

```
┌────────────────────────────────────────────────────────────────────────┐
│ AWS Account (personal) · us-east-1                                     │
│                                                                        │
│ ┌── observability-vpc (10.100.0.0/16) ──────────────────────────────┐ │
│ │                                                                    │ │
│ │  ┌── ECS cluster (tenant runtime) ─────────────────────────────┐  │ │
│ │  │                                                               │  │ │
│ │  │  Fargate task: observability-app                             │  │ │
│ │  │  ┌────────────────┐   ┌─────────────────────────────────┐    │  │ │
│ │  │  │ app container  │─▶ │ ADOT sidecar (OTel Collector)   │    │  │ │
│ │  │  │  :8080 HTTP    │   │  :4317 OTLP gRPC                │    │  │ │
│ │  │  └────────────────┘   │  resourcedetection + ecsobserver│    │  │ │
│ │  │                       └────────────┬────────────────────┘    │  │ │
│ │  └──────────────────────────────────────┼──────────────────────┘  │ │
│ │                                         │ OTLP mTLS                │ │
│ │                                         │ internal NLB             │ │
│ │                                         ▼                          │ │
│ │  ┌── observability-eks ──────────────────────────────────────────┐│ │
│ │  │                                                                 ││ │
│ │  │  ns: istio-system                                               ││ │
│ │  │    └─ istiod + ingressgateway (mesh control plane)              ││ │
│ │  │                                                                 ││ │
│ │  │  ns: cert-manager                                               ││ │
│ │  │    └─ cert-manager + ACM private CA ClusterIssuer               ││ │
│ │  │                                                                 ││ │
│ │  │  ns: external-secrets                                           ││ │
│ │  │    └─ ESO → AWS Secrets Manager                                 ││ │
│ │  │                                                                 ││ │
│ │  │  ns: argocd                                                     ││ │
│ │  │    └─ Argo CD apps-of-apps watching this repo                   ││ │
│ │  │                                                                 ││ │
│ │  │  ns: observability (Istio sidecar injection ON, mTLS STRICT)    ││ │
│ │  │    ├─ otel-collector-gateway Deployment × 3                     ││ │
│ │  │    │   tail_sampling, PII redaction, tenant tagging             ││ │
│ │  │    │   fan-out: Tempo + Mimir + Loki                            ││ │
│ │  │    │                                                             ││ │
│ │  │    ├─ Tempo (monolithic, 3 replicas)                            ││ │
│ │  │    │   blocks → s3://observability-tempo-blocks-…               ││ │
│ │  │    │                                                             ││ │
│ │  │    ├─ Mimir (read-write mode: read/write/backend × 2–3)         ││ │
│ │  │    │   blocks → s3://observability-mimir-blocks-…               ││ │
│ │  │    │                                                             ││ │
│ │  │    ├─ Loki (SSD mode: read/write/backend × 2–3)                 ││ │
│ │  │    │   chunks → s3://observability-loki-chunks-…                ││ │
│ │  │    │                                                             ││ │
│ │  │    ├─ Grafana Deployment × 3                                    ││ │
│ │  │    │   datasources: Tempo, Mimir, Loki                          ││ │
│ │  │    │   unified alerting → PagerDuty / OpsGenie / Slack          ││ │
│ │  │    │   config state → RDS Postgres                              ││ │
│ │  │    │                                                             ││ │
│ │  │    └─ Grafana image renderer Deployment × 1                     ││ │
│ │  │                                                                 ││ │
│ │  └─────────────────────────────────────────────────────────────────┘│ │
│ │                                                                      │ │
│ │  Supporting AWS resources (all tagged Project=observability):        │ │
│ │  ├─ RDS Postgres (observability-grafana-db)                          │ │
│ │  ├─ ECR repository (observability-app)                               │ │
│ │  ├─ ACM certificate for *.observability.chiemela.dev                 │ │
│ │  ├─ Route53 private hosted zone                                      │ │
│ │  ├─ Internal ALB (Grafana) + Internal NLB (OTLP ingress)             │ │
│ │  ├─ KMS keys: one per S3 bucket                                      │ │
│ │  ├─ IAM OIDC provider for IRSA                                       │ │
│ │  ├─ IAM roles per component (least privilege per bucket + API)       │ │
│ │  ├─ VPC endpoints: S3, ECR, STS, Secrets Manager (NAT cost control)  │ │
│ │  └─ Secrets Manager entries                                          │ │
│ └──────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  External: CloudWatch Synthetics canary monitoring Grafana + Collector  │
└──────────────────────────────────────────────────────────────────────────┘
```

## Signal path

A single HTTP request `GET /order/42` to the tenant app produces one trace. The trace travels this path:

1. Request lands on the ECS Fargate task's `app` container.
2. `otelhttp.NewHandler` middleware starts a Server-kind span.
3. Handler returns; `span.End()` queues the span in the SDK BatchSpanProcessor.
4. SDK flushes the batch over OTLP/gRPC to `localhost:4317` — the ADOT sidecar.
5. ADOT sidecar enriches with `aws.ecs.*` and `cloud.*` attributes, forwards upstream over OTLP mTLS to the internal NLB fronting the Collector Gateway Service.
6. Collector Gateway receives the span. Pipeline order:
   - `memory_limiter` processor: refuses new data if RSS over threshold.
   - `tail_sampling` processor: buffers all spans of the trace, decides at trace end (always keep errors, 5% of OK).
   - `attributes` processor: redacts PII patterns.
   - Fan-out to Tempo (traces), Mimir (via `spanmetrics` connector for RED metrics), Loki (if a span event carries a log line).
7. Tempo's distributor validates, consistent-hashes trace_id to an ingester.
8. Ingester buffers in memory, writes WAL to EBS, flushes block to S3 after idle timeout.
9. Query at any time via Grafana Explore → Grafana calls Tempo query-frontend over HTTP → fan-out to queriers → bloom-filter-indexed read from S3 → results merged → JSON back to Grafana → flame graph rendered.

## Tenancy

Every signal carries an `X-Scope-OrgID` header set by the Gateway Collector based on the resource attribute `service.namespace`. Tempo, Mimir, and Loki all enforce per-tenant limits, quotas, and isolation using this header.

## Alerting

Grafana Unified Alerting evaluates rules on a schedule against any data source. Rules provisioned from `clusters/observability/alert-rules/*.yaml`. Firing alerts flow through notification policies to contact points:

- `severity=critical` → PagerDuty primary
- `severity=critical` + `escalation=secondary` → OpsGenie
- `severity=warning` → Slack `#observability-alerts`
- everything else → email team DL

An external **CloudWatch Synthetics canary** independently hits Grafana's `/api/health` every minute and alerts PagerDuty directly if it fails — so a Grafana outage still pages someone.

## Deployment flow

```
developer PR
     │
     ▼
GitHub Actions (lint, validate, plan)
     │
     ▼ merge
Argo CD apps-of-apps
     │
     ▼
observability EKS cluster rolls workloads
```

Terraform runs separately from Argo CD. Terraform owns everything *below* the Kubernetes API (VPC, EKS cluster, RDS, S3, IAM, networking). Argo CD owns everything *above* (every workload inside the cluster via Helm charts and manifests). The two meet at the cluster API endpoint.

## Observability of the platform itself

- Grafana scrapes its own Prometheus metrics endpoint and ships them to Mimir via the Collector Gateway's `prometheus` receiver.
- Collector exposes its own self-telemetry on port 8888 (Prometheus format). Scraped identically.
- Platform workload logs (Grafana, Tempo, Mimir, Loki) are dual-shipped by a Fluent Bit DaemonSet to both Loki (primary) and CloudWatch Logs (fallback, in case Loki itself is unhealthy).
- CloudWatch Synthetics canary provides the external health signal that survives platform outages.
