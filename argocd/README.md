# argocd/

Argo CD configuration — `Application`, `ApplicationSet`, `AppProject`, and repo
registration manifests. **Scaffold — populated in
[Phase 6](../ROADMAP.md#phase-6--gitops).**

## The model

Git is the source of truth. Nothing reaches a cluster because someone ran `kubectl
apply` from a laptop; it reaches the cluster because it was merged, and Argo CD
reconciled it. The audit trail is `git log`, which is the actual value here — not
the pretty sync UI.

```
argocd/
├── install/              # Argo CD itself (upstream chart + values)
├── projects/             # AppProject definitions: RBAC and permitted destinations
├── applications/         # app-of-apps root Application
└── applicationsets/      # generators producing per-env Applications
```

## app-of-apps + ApplicationSets

A single root `Application` bootstraps everything else, so cluster state is one
`kubectl apply` away from a bare cluster and there is exactly one thing to bootstrap
by hand.

`ApplicationSet` generators then produce the per-environment Applications from the
overlays in [`kustomize/overlays/`](../kustomize/). Adding an environment becomes a
directory plus a generator entry, not three hand-copied Application manifests that
drift apart within a month. This is also the cheapest honest demonstration of a
multi-cluster pattern without paying to run multiple clusters.

## Sync policy, per environment

Automated sync is not uniformly correct — the tradeoff is speed versus control:

| Environment | Sync | Rationale |
| --- | --- | --- |
| dev | Automated, prune + self-heal on | Fast feedback matters more than change control; drift should not survive |
| staging | Automated, prune on, self-heal on | Must behave like prod to be a meaningful gate |
| prod | Automated with sync windows, **manual gate for destructive changes** | Self-heal reverting a legitimate emergency manual fix is its own outage |

Drift detection stays on everywhere, including where auto-sync is off — knowing about
drift and choosing not to auto-correct it is a decision; not knowing is a gap.

## Rules

- `AppProject` restricts each project to specific source repos, destination
  namespaces, and permitted resource kinds. A default-permissive project makes Argo
  CD a cluster-admin-as-a-service, which is exactly the risk GitOps is supposed to
  reduce.
- No secrets in this directory. Repo credentials come from the External Secrets
  Operator (Phase 8), not committed `Secret` manifests.
- Sync waves order the bootstrap: CRDs and namespaces before the workloads that need
  them, otherwise the first sync fails on a race that looks like a bug.
- Health checks and `ignoreDifferences` are tuned so "Synced" and "Healthy" mean
  something. A permanently-degraded app trains everyone to ignore the dashboard.
