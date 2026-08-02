# tests/

Platform tests — as distinct from application unit tests, which live next to their
service in [`apps/`](../apps/).

**Scaffold — grows from [Phase 4](../ROADMAP.md#phase-4--packaging-and-environment-overlays)
onward.** Phase 1's only test is the acceptance check in the roadmap: the cluster
bootstraps from a clean machine.

```
tests/
├── manifests/      # schema + policy validation of rendered YAML
├── policies/       # Kyverno policy tests: must-block and must-allow fixtures
├── integration/    # against a real ephemeral cluster in CI
└── smoke/          # post-deploy checks against a running environment
```

## The test pyramid, for a platform

Platform testing does not look like application testing. What is cheap and what is
expensive is different, so the layers are different:

**1. Static validation (milliseconds, runs on every PR)**
`kubeconform --strict` against the target Kubernetes version, `helm lint`,
`kustomize build` for every overlay, `terraform validate`, `yamllint`. This catches
the single most common failure — YAML that is syntactically fine and semantically
wrong — before it ever reaches a cluster.

**2. Policy tests (seconds)**
Every Kyverno policy needs two fixtures: a manifest it must reject and one it must
allow. Only testing rejection means a policy that blocks *everything* passes its
tests, and you find out when deploys stop working.

**3. Integration tests (minutes, ephemeral kind cluster in CI)**
Apply the real manifests to a real API server and assert the platform behaves:
namespaces get their default-deny NetworkPolicy, quotas are enforced, a workload
missing resource limits is rejected at admission, Argo CD reaches Synced/Healthy.
This is the expensive tier and where the optional-gate tradeoff in
[`.github/workflows/README.md`](../.github/workflows/README.md) applies.

**4. Smoke tests (post-deploy, against a live environment)**
Does the ingress serve? Does the API reach its database? Do metrics appear in
Prometheus? These gate the deployment, and their failure triggers rollback (Phase 6).

**5. Resilience tests** → [`chaos/`](../chaos/) (Phase 12). Also tests, just slower
and with a blast radius.

## What is deliberately not tested here

Upstream components. Prometheus has its own test suite; re-testing that Prometheus
scrapes is not this repo's job. What *is* tested is the platform's **configuration**
of it — that the ServiceMonitors select the right pods and the alert rules fire on
the right conditions. That distinction keeps the suite meaningful instead of large.
