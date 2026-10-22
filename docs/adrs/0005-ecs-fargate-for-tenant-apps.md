# ADR 0005: Tenant applications on ECS Fargate, platform on EKS

## Status

Accepted.

## Context

The observability platform serves tenant applications. A core design question is where tenant applications run relative to the platform.

Three realistic options:

- **Same EKS cluster as the platform**: tenant workloads in their own namespace alongside Tempo, Mimir, Loki, etc. Operationally simple, but conflates platform ownership and tenant ownership on one cluster.
- **Second EKS cluster**: full multi-cluster. Each tenant team runs its own cluster, forwards telemetry across the network to the platform cluster.
- **Alternate runtime (ECS Fargate, EC2, Lambda)**: tenants run on infrastructure that is not Kubernetes at all. Platform receives telemetry over the network like any other OTLP client.

The real-world shape at mid-to-large enterprises is a mix: a dedicated platform cluster for the observability team, and heterogeneous tenant runtimes depending on each application team's choice. Platform teams must support any tenant runtime.

## Decision

- **Platform runs on a dedicated EKS cluster** (`observability-eks`). No tenant workloads run on this cluster.
- **Sample tenant application** ([observability-app](https://github.com/chiemelaumehdev/observability-app)) runs as an **ECS Fargate service** in the same AWS account. The task definition contains two containers:
  - `app`: the Go HTTP service, listening on `:8080`.
  - `adot`: AWS Distro for OpenTelemetry Collector sidecar, listening on `127.0.0.1:4317`. Forwards upstream over OTLP mTLS to the Collector Gateway Service in the observability cluster, reached via an internal Network Load Balancer and private Route53 record.

The sidecar pattern on ECS is the equivalent of the DaemonSet pattern on Kubernetes: a Collector agent co-located with the workload, enriching with runtime metadata, forwarding to a central Gateway.

## Consequences

- Platform operational concerns stay strictly inside the platform cluster. A buggy tenant workload cannot affect Tempo, Mimir, Loki, or Grafana.
- Platform cluster billing and sizing are cleanly separable from tenant application billing and sizing.
- The platform is proven to work across runtime boundaries from day one. Adding Lambda, EC2, or an additional EKS cluster as a telemetry source is a configuration change at the sender, not a redesign at the platform.
- The ECS task role gets scoped permissions to call the Collector Gateway's NLB and nothing else.
- Cross-boundary mTLS requires certs that both sides trust. We mint a public-key signed by cert-manager's internal CA and embed it in the ADOT sidecar's config via Secrets Manager + External Secrets.

## Alternatives considered

- **Same EKS cluster**: rejected because it violates platform-tenant separation. The lesson of running observability as a product is that platform ownership and tenant ownership are different accountabilities. Running them on the same substrate dilutes that lesson in a portfolio project and dilutes it operationally in real work.
- **Second EKS cluster for tenants**: defensible, but doubles the EKS control plane cost ($72/mo per cluster) and adds operational complexity (cross-cluster networking, cross-cluster IAM) for marginal learning benefit at this scale.
- **EC2 with Docker Compose**: a legitimate runtime for legacy VM workloads. Deferred as a future lab exercise to demonstrate hybrid K8s-plus-VM observability. ECS Fargate is more representative of mid-size modern deployments.

## When to revisit

- The platform needs to prove multi-cluster federation (e.g. multiple EKS clusters forwarding to one central platform): add a second tenant EKS cluster.
- Tenants land on serverless-first stacks: add Lambda-extension-based telemetry forwarding alongside the ECS sidecar pattern.
