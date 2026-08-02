# kustomize/

Environment overlays. **Scaffold — populated in
[Phase 4](../ROADMAP.md#phase-4--packaging-and-environment-overlays).**

```
kustomize/
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

The base these overlays patch is [`k8s/base/`](../k8s/) — there is no separate copy
of the manifests here, which is the entire point. See [`helm/`](../helm/) for why
this platform uses Kustomize for environments and Helm for packaging.

## What each overlay is allowed to change

Keeping this list short is what keeps environments comparable. If an overlay can
change anything, "it works in staging" stops meaning anything about prod.

| Concern | dev | staging | prod |
| --- | --- | --- | --- |
| Replica counts | 1 | 2 | 3+ with PDBs |
| Resource requests/limits | minimal | production-shaped | production |
| Ingress hostname | `*.dev.example.invalid` | `*.staging.example.invalid` | `*.example.invalid` |
| Image tag | branch build | release candidate | released digest |
| HPA bounds | off | on, narrow | on, wide |
| Log level | debug | info | info |
| Secret source | local dev values | cloud secret manager | cloud secret manager |

**Not allowed to differ:** the resource *shape* itself. If prod needs a container
that dev does not have, that belongs in the base with a feature flag, not in an
overlay — otherwise prod is running an untested topology.

## Rules

- Overlays patch; they never re-declare a full resource. A `kustomization.yaml` full
  of complete resource bodies is a copy-paste fork wearing a Kustomize hat.
- Prefer strategic-merge patches for field changes and JSON6902 patches for list
  surgery.
- `kustomize build overlays/<env>` must succeed and pass `kubeconform` for every
  environment — enforced in CI from Phase 5.
- Overlay output is what Argo CD syncs from Phase 6. Anything that cannot be
  expressed as a build output cannot be GitOps-managed, so no imperative steps.
- Image tags are updated by the CI pipeline writing to the overlay (Phase 5/6), not
  by hand — the commit that changes an image tag *is* the deployment record.
