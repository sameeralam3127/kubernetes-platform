# infra/

Infrastructure definitions — everything that exists *below* Kubernetes workloads.

```
infra/
├── kind/        # local development cluster topology (Phase 1) ✅
└── terraform/   # cloud infrastructure and managed cluster (Phase 10)
```

## Why the split

`infra/kind/` and `infra/terraform/` describe the same layer of the stack — the
cluster and what it runs on — for two different targets. They are separated rather
than unified because unifying them would mean either pretending a laptop is a cloud
or watering the cloud definitions down to what kind can express. Neither is honest.

The platform *above* this layer is intended to be portable across both: the same
manifests, charts, and overlays in [`k8s/`](../k8s/), [`helm/`](../helm/), and
[`kustomize/`](../kustomize/) should apply to a kind cluster and a managed cluster,
with environment differences confined to overlays. Where that portability breaks
(load balancer types, storage classes, IAM-backed identity), the difference is
documented in the overlay rather than hidden.

## Current state

| Target | Status |
| --- | --- |
| [`kind/`](kind/) — local, 1 control-plane + 2 workers | ✅ Phase 1 |
| [`terraform/`](terraform/) — cloud infra | ⬜ Phase 10, provider not yet chosen |

The cloud provider decision is deliberately deferred — see
[ADR-0002](../docs/decisions/0002-defer-cloud-provider-choice.md).
