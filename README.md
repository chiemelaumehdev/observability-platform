# observability-platform

A production-shaped observability platform on AWS. Serves telemetry from tenant applications running on their own infrastructure.

Pairs with [observability-app](https://github.com/chiemelaumehdev/observability-app), a sample tenant workload running on ECS Fargate.

## What this is

A single-engineer-owned reference implementation of the Grafana OSS observability stack, deployed as an opinionated platform on AWS. The design mirrors how a real platform team at a mid-to-large organization operates observability as an internal product serving many application teams.

## Architecture at a glance

- **One dedicated EKS cluster** for the platform. Tenant applications never run here.
- **Grafana OSS stack**: Grafana + Tempo (traces) + Mimir (metrics) + Loki (logs).
- **OpenTelemetry Collector** Gateway tier inside the cluster, receiving OTLP from tenant workloads.
- **S3** for backend storage across Tempo, Mimir, and Loki. KMS-encrypted at rest.
- **RDS Postgres** for Grafana configuration state.
- **Istio service mesh** for workload-to-workload mTLS inside the cluster.
- **cert-manager** for Ingress TLS.
- **Argo CD** for GitOps-driven deployment of every workload.
- **External Secrets Operator** backed by AWS Secrets Manager.
- **IRSA** (IAM Roles for Service Accounts) for every workload needing AWS access. No static keys inside pods.
- **Grafana Unified Alerting** evaluating rules across all signals, routing to PagerDuty.

### Deployment modes

| Component | Mode | Rationale |
|-----------|------|-----------|
| Tempo    | Single-binary, 3 replicas              | Sufficient for sub-10B-events-per-day. See `docs/adrs/0001`. |
| Mimir    | Read-Write mode (3 targets)            | Grafana Labs middle-ground recommendation. See `docs/adrs/0001`. |
| Loki     | Simple Scalable Deployment (3 targets) | Equivalent middle-ground pattern.                            |

### Tenant topology

Tenant applications run on **ECS Fargate** (or any other runtime). Each task includes an **ADOT sidecar** receiving OTLP on `localhost:4317` and forwarding mTLS to the Collector Gateway Service inside the observability cluster via an internal NLB.

## Repository layout

```
.
├── terraform/
│   ├── envs/prod/           Root module for the prod environment
│   └── modules/             Reusable Terraform modules
│       ├── vpc/
│       ├── eks/
│       ├── s3-storage/
│       ├── rds-grafana/
│       ├── ecr/
│       ├── iam-irsa/
│       └── ecs-tenant-service/
├── clusters/
│   └── observability/
│       ├── argocd/          Argo CD apps-of-apps and Application manifests
│       ├── helm-values/     Per-component Helm values files
│       ├── dashboards/      Grafana dashboard JSON files, provisioned
│       ├── alert-rules/     Grafana alert rule YAML, provisioned
│       └── datasources/     Grafana data source YAML, provisioned
├── docs/
│   ├── architecture.md      End-to-end architecture document
│   └── adrs/                Architecture Decision Records, numbered
├── scripts/
│   ├── bootstrap.sh         Idempotent cluster bootstrap
│   └── teardown.sh          Safe teardown to reduce cost between study sessions
├── .github/workflows/       CI pipelines
└── Makefile
```

## Prerequisites

- `aws` CLI configured with an `observability` profile pointing at a personal AWS account
- `terraform` ≥ 1.9
- `kubectl` ≥ 1.30
- `helm` ≥ 3.15
- `argocd` CLI
- `gh` CLI authenticated
- `pre-commit` installed and `pre-commit install` run

## Operating

```bash
# Phase 2: provision AWS foundations
cd terraform/envs/prod
terraform init -backend-config=backend.hcl
terraform plan -out plan.tfplan
terraform apply plan.tfplan

# Phase 4: bootstrap the cluster
./scripts/bootstrap.sh

# Teardown between sessions to save cost (keeps S3 + RDS, destroys EKS nodes)
./scripts/teardown.sh --node-group-only

# Full teardown (destroys everything)
./scripts/teardown.sh --full
```

## Decisions

Every significant architectural choice is documented as an [ADR](docs/adrs/README.md). Read them in order to understand *why* the platform looks the way it does, not just *what* it does.

## Status

Scaffolding complete. Phase 2 (AWS Terraform foundations) in progress.
