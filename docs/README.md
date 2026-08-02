# docs/

Long-form documentation for the platform. Anything a reader needs *before* they can
safely touch the cluster lives here.

Docs are separated from `runbooks/` deliberately: **docs explain how the platform
works, runbooks tell you what to do at 3am.** A runbook that starts by explaining
architecture is a bad runbook.

## What belongs here

- Architecture and design documents.
- Operator guide (running the platform), developer guide (deploying onto it).
- Installation and local development guides.
- Security model, backup/restore procedures, troubleshooting.
- Architecture Decision Records in [decisions/](decisions/).

## What does not belong here

- Step-by-step incident response → [`runbooks/`](../runbooks/)
- Diagram source files and exports → [`diagrams/`](../diagrams/)
- Per-component configuration reference → the README inside that component's folder

## Current contents

| Document | Status |
| --- | --- |
| [local-development.md](local-development.md) | ✅ Phase 1 |
| [decisions/](decisions/) (ADRs) | ✅ Phase 1, ongoing |

## Planned

| Document | Phase |
| --- | --- |
| `architecture.md` — layered architecture with data flow | 2 |
| `developer-guide.md` — how an app team ships onto the platform | 3 |
| `environments.md` — dev/staging/prod overlay model and promotion flow | 4 |
| `ci-cd.md` — pipeline stages and gate rationale | 5 |
| `gitops.md` — Argo CD sync model, app-of-apps, drift handling | 6 |
| `observability.md` — metrics/logs/traces, SLOs, alert routing | 7 |
| `security.md` — threat model, RBAC model, policy set | 8 |
| `scaling.md` — HPA/PDB tuning and load test results | 9 |
| `infrastructure.md` — Terraform layout, remote state, per-env separation | 10 |
| `backup-restore.md` — Velero schedules and verified restore procedure | 11 |
| `chaos.md` — experiment catalogue and observed blast radius | 12 |
| `progressive-delivery.md` — canary analysis and abort criteria | 13 |
| `slos.md` — SLIs, targets, error budgets, burn-rate alerts | 14 |
| `troubleshooting.md`, `faq.md`, `known-limitations.md` | 14–15 |
