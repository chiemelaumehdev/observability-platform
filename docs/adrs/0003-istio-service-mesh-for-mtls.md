# ADR 0003: Istio service mesh for workload mTLS

## Status

Accepted.

## Context

Workload-to-workload traffic inside the observability cluster — Collector Gateway talking to Tempo distributor, Tempo querier talking to S3, Grafana talking to Tempo query-frontend — must be encrypted and mutually authenticated. The platform handles PHI-adjacent telemetry data, so zero-trust posture is a hard requirement, not a nice-to-have.

Three practical options:

- **cert-manager + per-workload mTLS wiring**: cert-manager issues X.509 certs from a private ClusterIssuer into Kubernetes Secrets. Each workload mounts the Secret and configures its own server to require client certs. Each caller mounts certs and configures its own client to present them.
- **Istio service mesh**: Envoy sidecar injected into every pod. Istiod issues short-lived certs via SPIFFE and configures Envoy to use them transparently. Applications are unaware of mTLS.
- **Linkerd service mesh**: equivalent to Istio with a lighter proxy (linkerd2-proxy in Rust instead of Envoy in C++). Simpler, less feature-rich.

## Decision

Deploy **Istio** on the observability cluster in `ambient` mode where supported, with `sidecar` mode as the fallback for workloads that require it. Enforce `STRICT` mutual TLS cluster-wide via `PeerAuthentication`.

- `istiod` runs in the `istio-system` namespace, HA with 2 replicas.
- The `observability` namespace is labeled `istio-injection=enabled` so every workload automatically gets its sidecar.
- A `PeerAuthentication` resource in the `observability` namespace sets `mtls.mode: STRICT`.
- cert-manager still runs on the cluster for a different purpose: issuing TLS certs for the Ingress endpoints (ACM certs for the internal ALB fronting Grafana).

## Consequences

- No application code touches certs. Istio auto-rotates every 24 hours via SPIFFE/SPIRE.
- Observability of pod-to-pod traffic becomes automatic: Istio emits metrics and traces for every call via its Envoy proxies, feeding directly into the stack we are building.
- Resource overhead: each application pod gets an Envoy sidecar, adding ~50 MiB memory and some CPU. Cluster-wide this is non-trivial and is budgeted into node sizing.
- Operational surface grows: Istio control plane upgrades, mesh config, and `AuthorizationPolicy` resources are additional artifacts the platform team maintains.

## Alternatives considered

- **cert-manager alone with hand-wired mTLS**: rejected on operational and consistency cost. Every workload would need custom cert mount config, custom server auth config, custom client cert presentation. Any new workload is a new round of mTLS wiring. Istio collapses this to one `PeerAuthentication` resource.
- **Linkerd**: a defensible alternative with less overhead. Rejected because Istio is more widely adopted at the Lead-level target orgs (CVS, large enterprise healthcare) and because Envoy's integration with AWS Load Balancer Controller and the broader AWS tooling is more mature.
- **No mesh, cluster-level network policies only**: rejected. NetworkPolicies restrict who can talk to whom at L3/L4 but do not encrypt or authenticate. PHI-adjacent traffic must be encrypted on the wire regardless of what network policy says.

## When to revisit

- Resource overhead becomes problematic (sidecar memory crosses 10% of total cluster memory): evaluate Istio ambient mode fully, or Linkerd migration.
- Mesh traffic management features (canary routing, retries, circuit breakers) are needed: Istio stays. Those features are the long-term dividend of this ADR.
