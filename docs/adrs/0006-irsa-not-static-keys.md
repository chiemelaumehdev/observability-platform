# ADR 0006: IRSA for pod AWS access, no static keys

## Status

Accepted.

## Context

Several workloads on the observability cluster need to call AWS APIs:

- Tempo ingester, compactor, querier, store-gateway: read/write S3 blocks, read KMS.
- Mimir ingester, compactor, store-gateway, ruler: read/write S3 blocks, read KMS.
- Loki ingester, compactor, index-gateway: read/write S3 chunks, read KMS.
- External Secrets Operator: read AWS Secrets Manager.
- AWS Load Balancer Controller: manage ELBv2 and EC2 resources.
- external-dns: manage Route53 records.
- cert-manager (if DNS-01 is used for ACM-managed certs): manage Route53 records.

Each needs scoped AWS permissions. The question is how to authenticate.

Options:

- **Static access keys in Secrets**: create an IAM user, generate access keys, store in Kubernetes Secrets, mount into pods. Long-lived credentials, require rotation, blast radius on compromise.
- **Node instance role**: every pod on a node inherits the node's IAM role. One role for all workloads, over-permissioned, no isolation between tenants.
- **IRSA (IAM Roles for Service Accounts)**: per-ServiceAccount IAM role via EKS OIDC provider. Short-lived credentials, pod-level scoping, no long-lived keys anywhere.
- **EKS Pod Identity (newer)**: AWS's successor to IRSA, launched 2023. Simpler setup (no OIDC provider required), equivalent security properties.

## Decision

Use **IRSA** for every workload that needs AWS access.

- Terraform provisions one IAM role per workload with the minimum policy its component needs.
- Each role trusts the cluster's OIDC provider and is scoped to a specific `(namespace, serviceaccount)` pair.
- Helm values set the `serviceAccount.annotations.eks.amazonaws.com/role-arn` on each workload's ServiceAccount.
- The AWS SDK inside the pod auto-detects the IRSA environment and fetches short-lived STS credentials via the pod identity webhook.
- No static access keys exist in any Kubernetes Secret, ConfigMap, or environment variable, ever.

## Consequences

- Credentials rotate automatically (1-hour STS tokens by default). No rotation runbooks.
- Least-privilege per workload: Tempo's role can read/write only the Tempo bucket, not Mimir's bucket.
- Audit trail in CloudTrail is per-ServiceAccount, so a compromised pod's actions are attributable.
- Any new workload requiring AWS access requires a Terraform IAM role addition — enforces policy-as-code discipline.

## Alternatives considered

- **Static access keys**: rejected categorically. Long-lived credentials in a cluster with multi-tenant workloads violate every modern security standard (SOC 2 CC6.1, HIPAA Technical Safeguards, NIST SP 800-53 AC-2).
- **Node instance role**: rejected. Over-permissions every pod, cannot scope per-workload, breaks the principle of least privilege.
- **EKS Pod Identity**: defensible, newer, simpler to set up. Rejected for this project because IRSA has broader ecosystem support in Terraform modules and Helm charts in 2026 and is still the industry default. Pod Identity is on the roadmap for a future ADR when the Grafana Labs charts fully support it.

## When to revisit

- Grafana Labs' official Helm charts and `terraform-aws-modules/eks` fully support Pod Identity: migrate.
- An audit demands per-pod (not per-ServiceAccount) credential isolation: Pod Identity's per-pod scope wins.
