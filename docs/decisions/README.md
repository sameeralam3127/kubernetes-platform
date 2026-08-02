# Architecture Decision Records

Every non-obvious platform decision gets an ADR. The point is not ceremony — it is
that six months later, "why is this a kind cluster and not k3d?" has a written
answer instead of an argument.

## Format

One file per decision, named `NNNN-short-slug.md`, numbered sequentially and never
renumbered. Each ADR states:

- **Status** — Proposed / Accepted / Superseded by ADR-NNNN / Deprecated
- **Context** — the forces in play, including constraints that were not negotiable
- **Decision** — what we chose, stated plainly
- **Consequences** — what this costs us, not just what it buys us
- **Alternatives considered** — and specifically why each was rejected

ADRs are immutable once Accepted. If a decision changes, write a new ADR that
supersedes the old one and update the old one's status line. Do not edit history.

## Index

| ADR | Title | Status | Phase |
| --- | --- | --- | --- |
| [0001](0001-local-cluster-kind-over-k3d.md) | Use kind for the local development cluster | Accepted | 1 |
| [0002](0002-defer-cloud-provider-choice.md) | Defer the cloud provider choice to Phase 10 | Accepted | 1 |

## Expected upcoming ADRs

These are placeholders for decisions the roadmap forces. They are listed so the gaps
are visible, not because the outcome is predetermined.

- Helm *and* Kustomize, each for its strength (Phase 4)
- Argo CD app-of-apps vs ApplicationSets for env fan-out (Phase 6)
- Kyverno over OPA/Gatekeeper for policy-as-code (Phase 8)
- Managed vs in-cluster PostgreSQL (Phase 10)
- Chaos Mesh vs Litmus (Phase 12)
- Excluding a service mesh, and what we give up (Phase 13)
