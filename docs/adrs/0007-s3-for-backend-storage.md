# ADR 0007: S3 for backend storage across all three signal types

## Status

Accepted.

## Context

Tempo, Mimir, and Loki each need durable backend storage for their blocks. Options are object storage (S3, GCS, Azure Blob, MinIO), block storage (EBS), or local disk.

The platform is AWS-native and expected to grow to tens of terabytes of retained telemetry data over time.

## Decision

Use **Amazon S3** as the backend storage for all three products.

Three dedicated buckets, one per product:

- `observability-tempo-blocks-{account}-{region}`
- `observability-mimir-blocks-{account}-{region}`
- `observability-loki-chunks-{account}-{region}`

Per-bucket controls:

- **KMS encryption at rest** using a dedicated customer-managed KMS key per bucket. KMS keys never cross product boundaries.
- **Versioning enabled** on all three buckets, so an operator error (bad lifecycle rule, accidental delete) is recoverable within the 30-day versioning window.
- **Lifecycle rules** aligned with each product's retention target. Tempo blocks → Intelligent-Tiering after 7 days, delete after 90 days. Mimir blocks → Intelligent-Tiering after 30 days, delete after 13 months. Loki chunks → Intelligent-Tiering after 7 days, delete after 90 days.
- **Public access block** on all three (block all four controls).
- **Bucket policies** that deny TLS 1.0 and TLS 1.1 and require encryption on PUTs.
- **Access logging** to a dedicated audit bucket.

Access is granted exclusively via IRSA roles (see ADR 0006), one role per component per bucket.

## Consequences

- Storage cost scales linearly with retention and compresses well. Intelligent-Tiering drops older data to lower-cost tiers automatically.
- Horizontal scaling of ingest, query, and compaction is independent of storage. Pods are stateless (except for small WAL volumes on ingesters).
- Multi-AZ durability is inherited from S3's 99.999999999% design.
- Query performance depends on bloom filter and index design in each product — on-S3 latency is non-trivial (tens of ms per block read). Mitigated by ingester tier for recent data and store-gateway caching for S3-backed data.
- KMS cost scales with API operations. Mitigated by S3 Bucket Keys which cache per-bucket data keys and reduce KMS calls by 99%.

## Alternatives considered

- **EBS volumes attached to each component**: rejected. Pods are stateless by design to allow horizontal scaling and node replacement. Component redesign would be required to make ingesters, queriers, and compactors stateful.
- **MinIO self-hosted**: rejected on operational cost. MinIO is a reasonable choice when S3 is not available (on-prem) or when egress costs matter. In AWS, S3 is strictly better.
- **Shared single bucket for all three products**: rejected on blast radius and IAM scoping. A compromised Tempo role should not grant any access to Mimir or Loki data.
- **S3 Standard with no lifecycle**: rejected on cost. For a lab project with modest ingest, this is tolerable; for prod it is wasteful. Lifecycle rules are set up from day one so the discipline is in place.

## When to revisit

- Query latency on cold S3 data exceeds user tolerance: evaluate adding a dedicated Redis/Memcached cache in front of the store-gateway tier.
- Egress costs cross a budget threshold: evaluate VPC endpoints for S3 (added in Phase 2) and audit cross-region traffic.
