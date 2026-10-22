# ADR 0004: Grafana Unified Alerting as the single alerting engine

## Status

Accepted.

## Context

Three alerting engines are compatible with the Grafana OSS stack:

- **Grafana Unified Alerting** — introduced in Grafana 8.0, now the default. One alerting engine inside Grafana that evaluates rules against any Grafana data source (Mimir, Loki, Tempo, Prometheus, PostgreSQL, etc.). Owns rules, contact points, notification policies, silences, and templates in one UI and one API. Supports multi-datasource rules — a rule can `and` a condition in Mimir with a condition in Loki.
- **Mimir's bundled Alertmanager** — the classic Prometheus Alertmanager, bundled inside Mimir. Rules live in Prometheus-flavored YAML served via Mimir's ruler component. Routes via Alertmanager's config.
- **Standalone Prometheus Alertmanager** — same as Mimir's bundle, deployed as its own set of pods instead of embedded.

Pre-Grafana-8 orgs often run Mimir Alertmanager because that was the only path. New stacks increasingly consolidate on Grafana Unified Alerting because it owns the full lifecycle in one place.

## Decision

Use **Grafana Unified Alerting** as the only alerting engine. Mimir's bundled Alertmanager is disabled. Standalone Alertmanager is not deployed.

- Alert rules live as YAML in `clusters/observability/alert-rules/` and are provisioned into Grafana at startup via a mounted ConfigMap.
- Contact points: PagerDuty (critical), OpsGenie (backup critical), Slack (`#observability-alerts`), email (team DL). Defined via provisioning.
- Notification policies route by label: `severity=critical` → PagerDuty, `severity=warning` → Slack, everything else → email.
- Silences and mute timings are user-managed via the Grafana UI, backed by the Grafana config database.

## Consequences

- Single pane of glass for alert authoring, routing, and silencing. No context-switching between Grafana (dashboards) and Alertmanager (alerts).
- Multi-datasource rules enable patterns like "alert when metric X breaches threshold AND there is a correlated error log in Loki," which Mimir's ruler alone cannot do.
- Grafana becomes a critical dependency for alerting. If Grafana is down, no alerts fire. Mitigation: Grafana runs HA with 3 replicas backed by RDS Multi-AZ, and an external CloudWatch Synthetics canary alerts PagerDuty directly if Grafana's `/api/health` fails.
- Loses the ability to use pure Prometheus-rule tooling (e.g. `promtool test rules`). Mitigation: alert rule YAML schema can be linted via `grafana-cli alerting lint` locally and in CI.

## Alternatives considered

- **Mimir Alertmanager**: rejected on fragmentation. Dashboards in Grafana, alerts in a separate tool, two different auth stories.
- **Both Grafana Unified Alerting AND Mimir Alertmanager**: rejected on dual-source-of-truth risk. Operators would not know which alert came from where.
- **Standalone Alertmanager**: rejected for the same fragmentation reason as Mimir Alertmanager plus the extra operational surface of running a third Prometheus-ecosystem component.

## When to revisit

- Grafana becomes a scaling bottleneck for alert rule evaluation (sustained >10k active rules): consider moving some rules into Mimir's ruler for horizontal scaling.
- Need for alerting that must survive Grafana outages: that already exists via the CloudWatch Synthetics canary. Expand canary coverage to monitor the Collector Gateway and Tempo ingest as well.
