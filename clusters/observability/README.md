# clusters/observability

Everything that Argo CD syncs into the `observability-eks` cluster.

```
clusters/observability/
├── argocd/
│   ├── bootstrap/        One-time apply by hand; brings up Argo CD itself
│   └── apps/             Argo CD Application manifests, one per workload
├── helm-values/          Per-workload Helm values files referenced by Apps
├── dashboards/           Grafana dashboard JSON files, provisioned
├── alert-rules/          Grafana alert rules, provisioned
└── datasources/          Grafana data source YAMLs, provisioned
```

## Deployment ordering

Argo CD syncs in waves driven by sync waves on each Application. The intended ordering:

| Wave | Workloads                                                         |
|------|-------------------------------------------------------------------|
| 0    | istio-base, istiod, istio-ingressgateway                          |
| 1    | cert-manager, external-secrets-operator, external-dns, aws-lb-controller |
| 2    | otel-collector-gateway                                            |
| 3    | tempo, mimir, loki, grafana-image-renderer                        |
| 4    | grafana (depends on all data source backends being up)            |
| 5    | fluent-bit, grafana alerting ConfigMaps                            |

Each wave must reach `Synced + Healthy` before the next proceeds.
