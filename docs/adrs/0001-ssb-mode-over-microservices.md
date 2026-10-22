# ADR 0001: SSB mode over microservices for Tempo, Mimir, Loki

## Status

Accepted.

## Context

Tempo, Mimir, and Loki each support multiple deployment modes:

- **Monolithic / single-binary**: one process contains every component. Horizontal scaling by adding identical replicas.
- **Scalable modes (Mimir read-write, Loki Simple Scalable Deployment)**: components split into a small number of role groups, typically three — read, write, backend. Each role group runs as its own Deployment or StatefulSet.
- **Microservices**: each component (distributor, ingester, compactor, querier, query-frontend, store-gateway, ruler, alertmanager, index-gateway) runs as its own Deployment or StatefulSet, scaled independently.

Microservices mode is designed for very large scale — Grafana Cloud runs it at hundreds of billions of events per day. The operational cost is high: fifteen-plus Deployments per product, independent scaling policies per component, more Helm config, more failure modes.

This platform's expected scale is sub-10B events per day across all signals.

## Decision

- **Tempo**: single-binary mode, 3 replicas, `target: all` on each.
- **Mimir**: read-write mode, 3 targets (`read`, `write`, `backend`), 2–3 replicas each.
- **Loki**: Simple Scalable Deployment, 3 targets (`read`, `write`, `backend`), 2–3 replicas each.

## Consequences

- Operational surface drops from ~45 workloads (microservices across three products) to ~15 workloads total.
- Grafana Labs supports both modes in their official Helm charts, so moving to microservices later is a config change, not a rewrite.
- Horizontal scaling within a role still works: add more read replicas when query load grows, add more write replicas when ingest grows.
- At the maximum scale the SSB modes can handle (roughly 10B events per day for any one signal), moving to microservices becomes a planned migration.
- Resource efficiency is comparable; the main difference between modes is granularity of scaling, not raw throughput.

## Alternatives considered

- **Microservices mode from day one**: rejected on operational overhead vs. the current scale needs. Would be the right choice above 10B events per day for any signal, or when distinct scaling pressures (ingest-heavy vs query-heavy workloads) show up in production.
- **Monolithic single-pod mode**: rejected on no HA and no horizontal scaling. Suitable for development only.

## When to revisit

- Sustained signal volume crosses 5B events per day: begin planning the microservices migration.
- Any single component's resource usage dominates the Pod's budget (e.g. compactor saturates CPU while querier is idle): split that component out early.
