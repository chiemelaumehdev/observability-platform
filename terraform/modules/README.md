# Terraform modules

Reusable modules consumed by environment root modules under `terraform/envs/`.

| Module                   | Owns                                                                                 |
|--------------------------|--------------------------------------------------------------------------------------|
| `vpc/`                   | Dedicated observability VPC, subnets, routing, NAT, S3/ECR/STS/SM VPC endpoints.    |
| `s3-storage/`            | Tempo/Mimir/Loki buckets with KMS, versioning, lifecycle, bucket policies.          |
| `ecr/`                   | ECR repository for the tenant application image.                                     |
| `rds-grafana/`           | RDS PostgreSQL instance for Grafana's config state, with encrypted storage.          |
| `iam-irsa/`              | IAM roles per observability workload scoped to its ServiceAccount via OIDC.          |
| `eks/`                   | EKS cluster, managed node groups, cluster add-ons, OIDC provider.                    |
| `ecs-tenant-service/`    | ECS Fargate service + task definition for the tenant application (two containers).  |
| `tfstate-bootstrap/`     | S3 bucket and DynamoDB table used by every environment's `backend "s3"`.             |

Modules are stubbed in Phase 1 and implemented over Phase 2.
