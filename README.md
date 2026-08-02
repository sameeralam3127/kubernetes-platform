# kubernetes-platform

**A production-style internal developer platform on Kubernetes — built in public, one
phase at a time.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Phase](https://img.shields.io/badge/roadmap-phase%201%20of%2015-blue.svg)](ROADMAP.md)
[![Kubernetes](https://img.shields.io/badge/kubernetes-1.36-326ce5.svg?logo=kubernetes&logoColor=white)](infra/kind/cluster.yaml)
[![Local cluster](https://img.shields.io/badge/local-kind-blueviolet.svg)](docs/decisions/0001-local-cluster-kind-over-k3d.md)

> **Status: Phase 1 of 15 — Foundation.** The repository scaffold, governance, and a
> one-command local cluster are working today. Everything else is documented
> scaffolding with a dated plan. See [ROADMAP.md](ROADMAP.md) for exactly what exists
> and what does not — no phase is described as done before it is.

---

## What this is

Most Kubernetes portfolio repositories are a Deployment, a Service, and an Ingress
with a README that says "production-ready". This one is trying to be the other thing:
the platform a team would actually run — where deploys go through Git, bad releases
stop themselves, secrets never touch the repository, backups get restored on a
schedule, and the resilience claims have been tested by breaking things on purpose.

It is built as a **cumulative 15-phase roadmap**. Each phase leaves the repository in
a coherent, demoable state, and each one builds on the last rather than bolting on
beside it.

## The problem it solves

An application team should be able to ship a service without knowing how ingress,
TLS, autoscaling, network policy, secret management, or observability work. A
platform team should be able to guarantee that every service that ships has all of
those things, correctly, by default.

That is the gap this platform sits in — the paved road, with guardrails that reject
unsafe configurations at admission rather than catching them in review.

## Architecture

> 📐 The architecture diagram lands in Phase 2 alongside the first real cluster
> topology, and is refreshed each phase. Placeholder rather than a stale drawing —
> see [`diagrams/`](diagrams/).

```
                      ┌──────────────────────────────────────────┐
   git push ───────►  │  GitHub Actions   lint · test · build    │
                      │                   scan · SBOM · sign      │  Phase 5
                      └──────────────────┬───────────────────────┘
                                         │ image digest → overlay commit
                                         ▼
                      ┌──────────────────────────────────────────┐
                      │  Argo CD          app-of-apps             │  Phase 6
                      │                   ApplicationSets         │
                      └──────────────────┬───────────────────────┘
                                         │ reconcile
      ┌──────────────────────────────────▼───────────────────────┐
      │  Kubernetes cluster                                       │
      │                                                           │
      │   frontend ─► api ─► postgres / redis      Phase 3        │
      │        ▲                                                  │
      │   ingress-nginx · cert-manager             Phase 2        │
      │                                                           │
      │   Kyverno · NetworkPolicy · PSA · ESO      Phase 8        │
      │   Prometheus · Grafana · Loki · Tempo      Phase 7        │
      │   HPA · PDB · Argo Rollouts                Phase 9, 13    │
      │   Velero · Chaos Mesh                      Phase 11, 12   │
      └───────────────────────────────────────────────────────────┘
                     kind (local, today)  ·  managed cluster (Phase 10)
```

## Tech stack

| Layer | Choice | Status |
| --- | --- | --- |
| **Local cluster** | [kind](docs/decisions/0001-local-cluster-kind-over-k3d.md), 1 control-plane + 2 workers | ✅ Phase 1 |
| **Cloud infra** | Terraform — [provider deferred](docs/decisions/0002-defer-cloud-provider-choice.md) | ⬜ Phase 10 |
| **Packaging** | Helm (reuse) + Kustomize (environments), [each for its strength](helm/README.md) | ⬜ Phase 4 |
| **GitOps** | Argo CD + ApplicationSets | ⬜ Phase 6 |
| **CI/CD** | GitHub Actions, Trivy, Syft, Cosign | ⬜ Phase 5 |
| **Networking** | ingress-nginx, cert-manager | ⬜ Phase 2 |
| **Metrics** | Prometheus, Grafana, Alertmanager | ⬜ Phase 7 |
| **Logs** | Loki + Fluent Bit | ⬜ Phase 7 |
| **Traces** | OpenTelemetry Collector + Tempo | ⬜ Phase 7 |
| **Policy** | Kyverno, Pod Security Admission, NetworkPolicies | ⬜ Phase 8 |
| **Secrets** | External Secrets Operator | ⬜ Phase 8 |
| **Backup/DR** | Velero + independent `pg_dump` | ⬜ Phase 11 |
| **Chaos** | Chaos Mesh or Litmus | ⬜ Phase 12 |
| **Progressive delivery** | Argo Rollouts | ⬜ Phase 13 |

**Deliberately excluded:** service mesh, multi-cloud, multi-cluster. Each with a
written reason in [ROADMAP.md](ROADMAP.md#deliberate-exclusions) — what you leave out
is a design decision too.

## Prerequisites

- **Docker** (or OrbStack / Colima / Podman) with **4GiB+** memory
- **kind** 0.20+
- **kubectl** within ±1 minor of the cluster
- **make**

`make preflight` checks all of this and tells you what is missing.

## Local setup

```bash
git clone https://github.com/sameeralam3127/kubernetes-platform.git
cd kubernetes-platform

make preflight   # verify your toolchain
make up          # create the cluster (1–3 min first run)
make status      # confirm healthy
```

```
NAME                                STATUS   ROLES           AGE   VERSION
kubernetes-platform-control-plane   Ready    control-plane   41s   v1.36.1
kubernetes-platform-worker          Ready    <none>          27s   v1.36.1
kubernetes-platform-worker2         Ready    <none>          27s   v1.36.1

 ok  cluster 'kubernetes-platform' is healthy
```

`make down` removes it. Full walkthrough, configuration, and troubleshooting:
[docs/local-development.md](docs/local-development.md).

Run `make help` to see every available target.

## Deployment

⬜ **Phase 3+.** Applications are deployed by hand in Phase 3, packaged in Phase 4,
and from Phase 6 onward nothing reaches a cluster except by merging to `main` and
letting Argo CD reconcile.

## Environment structure

⬜ **Phase 4.** Three environments — `dev`, `staging`, `prod` — as Kustomize overlays
over a single base. Overlays may differ in replica counts, resources, hostnames,
image tags, HPA bounds, and log level. They may **not** differ in resource *shape*,
because an environment running an untested topology is not a meaningful gate. See
[kustomize/README.md](kustomize/README.md).

## Observability

⬜ **Phase 7.** Metrics, logs, and traces joined by consistent labels so that
"spike on a graph → the logs behind it → the trace of one slow request" is a
three-click path rather than three separate tools. Alerts are symptom-based, and
every alert carries a `runbook_url`. See [monitoring/](monitoring/),
[logging/](logging/), [tracing/](tracing/).

## Security model

⬜ **Phase 8.** Defence in depth: Pod Security Admission, Kyverno policy-as-code,
default-deny ingress **and** egress NetworkPolicies, External Secrets Operator instead
of committed `Secret` objects, and Cosign signature verification enforced at
admission. Every policy ships in Audit mode first.

> ⚠️ **Until Phase 8 lands, this cluster is not hardened.** The local cluster binds to
> `127.0.0.1` and is for development only. See [SECURITY.md](SECURITY.md).

## Scaling

⬜ **Phase 9.** HPAs tuned on real load-test data rather than guessed thresholds,
PodDisruptionBudgets, and topology spread across both workers. The two-worker local
topology exists precisely so these are testable — see
[infra/kind/README.md](infra/kind/README.md).

## Backups and disaster recovery

⬜ **Phase 11.** Velero plus independent `pg_dump` backups, with **measured** RTO/RPO
and restore drills that actually run. An untested backup is not a backup. See
[backup/](backup/).

## Testing

| Layer | What | Phase |
| --- | --- | --- |
| Static validation | kubeconform, helm lint, kustomize build | 4 |
| Policy tests | must-block **and** must-allow fixtures per policy | 8 |
| Integration | against an ephemeral kind cluster in CI | 5 |
| Smoke | post-deploy, gates rollback | 6 |
| Resilience | chaos experiments | 12 |

Today: `make lint-shell` and `make verify` (clean bootstrap → healthy → teardown).
See [tests/README.md](tests/README.md).

## Troubleshooting

Common issues — Docker daemon unreachable, a half-created cluster, nodes stuck
`NotReady`, port 80 already bound — are covered in
[docs/local-development.md#troubleshooting](docs/local-development.md#troubleshooting).

## Roadmap

15 phases, cumulative, each independently demoable. Full detail with per-phase
acceptance criteria in **[ROADMAP.md](ROADMAP.md)**.

| | | | |
| --- | --- | --- | --- |
| 🟡 1 Foundation | ⬜ 2 Cluster basics | ⬜ 3 App deployment | ⬜ 4 Packaging |
| ⬜ 5 CI/CD | ⬜ 6 GitOps | ⬜ 7 Observability | ⬜ 8 Security |
| ⬜ 9 Scaling | ⬜ 10 IaC | ⬜ 11 Backup/DR | ⬜ 12 Chaos |
| ⬜ 13 Progressive delivery | ⬜ 14 Production readiness | ⬜ 15 Polish | |

## Screenshots

⬜ **Phase 15.** Planned: Grafana during a load test with replicas climbing and
latency flat, an Argo CD sync view, a chaos experiment recovering, a canary aborting
itself on bad metrics. Placeholders rather than stock images — nothing here will
claim to show something that has not been run.

## Repository structure

```
├── apps/          sample services that exercise the platform
├── argocd/        Application, ApplicationSet, AppProject manifests
├── backup/        Velero schedules, restore drills
├── chaos/         experiments, steady-state hypotheses, results
├── diagrams/      diagram sources + exports
├── docs/          architecture, guides, ADRs
├── examples/      small workloads proving one capability each
├── helm/          first-party charts
├── infra/kind/    local cluster topology          ← works today
├── infra/terraform/  cloud infrastructure
├── k8s/base/      raw manifests / Kustomize base
├── kustomize/     dev / staging / prod overlays
├── logging/       Loki, Fluent Bit
├── monitoring/    Prometheus, Grafana, Alertmanager
├── runbooks/      one per failure scenario
├── scripts/       bootstrap, teardown, drills      ← works today
├── security/      Kyverno, NetworkPolicies, PSA
├── tests/         manifest, policy, integration, smoke
└── tracing/       OpenTelemetry, Tempo
```

Every directory has a README explaining what belongs in it and which phase fills it.

## Design decisions

Non-obvious choices are recorded as ADRs in [docs/decisions/](docs/decisions/), with
their costs stated rather than only their benefits:

- **[ADR-0001](docs/decisions/0001-local-cluster-kind-over-k3d.md)** — kind over k3d
  for the local cluster, and what the slower startup buys.
- **[ADR-0002](docs/decisions/0002-defer-cloud-provider-choice.md)** — why
  `infra/terraform/` is deliberately empty until Phase 10.

## Future work

Beyond the 15 phases: multi-cluster with a real second cluster, PR preview
environments, cost-aware autoscaling, and a policy-driven service catalogue. Tracked
in [ROADMAP.md](ROADMAP.md#deliberate-exclusions) as stretch goals rather than
promises.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The bar is "would this survive a real
platform team's code review" — every added component has to justify its operational
complexity, not just its popularity.

## License

[MIT](LICENSE) © 2026 Sameer Alam
