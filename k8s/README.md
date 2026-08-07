# k8s/

Raw Kubernetes manifests — the plain YAML layer, before any templating or overlays.

```
k8s/
├── base/                 # ✅ Phase 2 — the Kustomize base
│   ├── kustomization.yaml
│   ├── namespaces/       # platform-system, dev, staging, prod
│   ├── governance/       # ResourceQuota + LimitRange per environment
│   └── rbac/             # developer + ci-deployer personas, platform-viewer
└── addons/               # ✅ Phase 2 — third-party component config
    ├── clusterissuer-selfsigned.yaml
    └── values/           # pinned Helm values per addon
```

Apply with `make apply-base` (guarded — refuses a non-kind context) and
`make addons`. Verify with `make verify-platform`.

## What belongs here

Cluster-scoped and foundational resources that are **the same in every environment**
and do not benefit from templating:

- Namespaces and their labels (including Pod Security Admission labels, Phase 8)
- ServiceAccounts, Roles, RoleBindings, ClusterRoles (Phase 2)
- ResourceQuotas and LimitRanges (Phase 2)
- The initial Deployments/Services written by hand in Phase 3, before they are
  packaged into charts in Phase 4

## Why raw manifests at all, when Helm and Kustomize exist

Two reasons, one engineering and one pedagogical:

1. **`k8s/base/` is the Kustomize base.** The overlays in
   [`kustomize/overlays/`](../kustomize/) patch these manifests. There is no
   duplication — the raw layer *is* the base layer.
2. **Phase 3 deploys by hand before Phase 4 packages it.** Going raw manifests →
   Helm/Kustomize → GitOps in that order shows the progression and, more
   practically, means each abstraction is introduced only once the problem it solves
   has actually been felt.

## What does not belong here

- Anything environment-specific → [`kustomize/overlays/`](../kustomize/)
- Anything needing templating or reuse across services → [`helm/`](../helm/)
- Third-party components (Prometheus, Argo CD, cert-manager) → installed as upstream
  charts, configured under [`monitoring/`](../monitoring/), [`argocd/`](../argocd/),
  etc.
- Policies → [`security/`](../security/)

## Conventions

- One resource kind per file, named `<kind>-<name>.yaml` (`namespace-platform.yaml`,
  `role-deployer.yaml`). Easier to review and to grep than a 400-line multi-doc file.
- Every resource carries the `app.kubernetes.io/{name,instance,component,part-of,managed-by}`
  recommended labels — this is what makes selectors, dashboards, and cost attribution
  work later without a relabelling migration.
- Every workload sets resource requests **and** limits, a readiness probe, and a
  liveness probe. Manifests missing these are rejected by policy from Phase 8, so
  they are written correctly from Phase 2 rather than retrofitted.
- No `latest` image tags anywhere, at any phase. Pin by digest once Phase 5 builds
  images.
