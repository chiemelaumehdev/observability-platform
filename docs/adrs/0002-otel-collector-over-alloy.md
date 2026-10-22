# ADR 0002: OpenTelemetry Collector over Grafana Alloy as the agent

## Status

Accepted.

## Context

Two mature options exist for the agent tier of the telemetry pipeline:

- **OpenTelemetry Collector** — CNCF reference agent, vendor-neutral, YAML config, hundreds of community-contributed receivers and exporters. Every observability vendor supports it as a first-class ingest source. Universal skill in the industry.
- **Grafana Alloy** — Grafana Labs' agent, launched 2024 as the successor to Grafana Agent. Fork of OTel Collector with Grafana-specific additions (native Prometheus scraping with service discovery, Pyroscope profile collection, Grafana Cloud optimizations). Config in River, Grafana's HCL-like language.

Both are production-ready. The difference is strategic positioning: OTel Collector is the universal standard, Alloy is Grafana-native with slight feature advantages inside the Grafana ecosystem.

## Decision

Use the **OpenTelemetry Collector** across the entire pipeline:

- The ADOT (AWS Distro for OpenTelemetry) sidecar in tenant ECS tasks is an OTel Collector distribution maintained by AWS.
- The Gateway tier in the observability cluster is upstream OTel Collector in `contrib` distribution.
- The Prometheus-scraping role is handled by the OTel Collector's `prometheus` receiver running in the Gateway, not by a separate Prometheus pod or an Alloy pod.

Pipeline config stays YAML, vendor-neutral, portable to any OTel-compatible backend.

## Consequences

- Backend swap is a one-line config change at the Gateway. The platform is not Grafana-locked at the agent tier.
- Skills built on this platform transfer to any observability shop, including Datadog, New Relic, Honeycomb, Lightstep, and self-hosted Jaeger.
- Loses Alloy's Pyroscope profiling receiver. If profiling becomes a priority, add a Pyroscope agent sidecar instead of migrating the whole pipeline.
- Loses Alloy's slightly more ergonomic Prometheus service discovery config. Workaround: use `k8sattributes` processor and `prometheus` receiver scrape configs, which are more verbose but functionally equivalent.

## Alternatives considered

- **Grafana Alloy**: rejected for universal-skill-transfer reasons. Alloy is excellent inside the Grafana ecosystem; this platform's design keeps the agent tier vendor-neutral.
- **Prometheus server + Fluent Bit + Jaeger Agent**: rejected as the pre-OTel pattern. Three separate agents, three separate protocols, three separate scaling and operations stories. OTel Collector collapses the agent tier.
- **Fluent Bit for logs + OTel Collector for traces and metrics**: rejected. Dual-agent setup adds operational surface for marginal benefit. OTel Collector's `filelog` receiver and `otlp` receiver handle logs natively.

## When to revisit

- The organization adopts Grafana Cloud as the backend: Alloy becomes attractive on cost and ergonomics.
- Continuous profiling becomes a first-class signal: evaluate adding Alloy as a sidecar alongside OTel Collector, not replacing it.
