# diagrams/

Diagram **sources** and their exported images. Kept separate from `docs/` so that
binary/large exports do not bloat the diff surface of text documentation, and so
diagram sources are obviously editable rather than screenshots someone has to
recreate from scratch.

## Rules

1. **Always commit the source, not just the export.** A PNG nobody can edit is
   technical debt. Prefer text-based formats that diff cleanly:
   - [Mermaid](https://mermaid.js.org/) (`.mmd`) — renders natively on GitHub, best
     default for flow/sequence diagrams.
   - [D2](https://d2lang.com/) (`.d2`) or Graphviz (`.dot`) for layered architecture.
   - `.excalidraw` / `.drawio` when a hand-drawn feel helps a README hero image.
2. **Export to `exports/`** as SVG (preferred — scales, small, themeable) or PNG at
   ≥1600px wide for README embedding.
3. **Name by what it shows**, not when it was made: `platform-overview.mmd`,
   `request-path.mmd`, `gitops-sync-flow.mmd` — not `diagram-v3-final.png`.

## Planned diagrams

| Diagram | Shows | Phase |
| --- | --- | --- |
| `platform-overview` | Full layered architecture with data flow arrows — the README hero image | 2, refreshed each phase |
| `request-path` | Client → DNS → Ingress → Service → Pod → DB/cache | 3 |
| `environments` | Base + dev/staging/prod overlay relationships | 4 |
| `ci-cd-pipeline` | Commit → CI stages → registry → Argo CD → cluster | 5 |
| `gitops-sync-flow` | Git as source of truth, drift detection, reconciliation loop | 6 |
| `observability-flow` | Metric/log/trace collection paths and where alerts fire | 7 |
| `network-policy-matrix` | Which namespace may talk to which, and on what ports | 8 |
| `backup-restore-flow` | Velero backup targets and the restore decision tree | 11 |
| `canary-rollout` | Rollout states and the analysis gates that abort them | 13 |

Phase 15 pulls these into the README alongside screenshots and GIFs (Grafana under
load, an Argo CD sync, a chaos experiment recovering).
