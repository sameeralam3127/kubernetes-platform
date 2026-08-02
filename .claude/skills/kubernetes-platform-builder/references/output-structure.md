# Output Structure Reference

Detailed spec for each of the 14 sections referenced by SKILL.md. Read this before
drafting a full plan; skim only the relevant subsection when scoping a partial answer.

## 1. Project identity
- Strong project title (repo stays `kubernetes-platform` unless a refinement is
  clearly better — if so, suggest it but keep that name central).
- One-line tagline.
- GitHub "About" description (concise, keyword-rich).
- Suggested GitHub topics/tags (8–15, mixing broad + specific: `kubernetes`,
  `platform-engineering`, `gitops`, `argocd`, `terraform`, `observability`, etc.).

## 2. Project vision
Cover: what the platform is, why it exists, who it's for (internal platform/dev
teams as the in-universe audience), what problem it solves, and why it's valuable
as a portfolio piece. Should read like a real platform's README intro, not a class
assignment.

## 3. Architecture
Cover every layer, and for each component state include/exclude + why:
- **Application layer**: frontend, backend API, worker jobs, cron jobs, sample
  services (enough to exercise the platform, not a full product).
- **Kubernetes primitives**: namespaces, Deployments, StatefulSets, DaemonSets,
  Jobs/CronJobs, Services, Ingress, ConfigMaps, Secrets, RBAC, ResourceQuotas,
  LimitRanges, probes, HPA/VPA.
- **Delivery/packaging**: Helm vs Kustomize (justify using both — Helm for
  templated 3rd-party/app charts, Kustomize for env overlays — or pick one and say
  why), Argo CD, ApplicationSets, progressive delivery (Argo Rollouts) if it earns
  its complexity, environment overlays (dev/staging/prod).
- **Infrastructure**: Terraform, modules, remote state, environment separation,
  target cloud (pick one primary — AWS is the safe portfolio default — and note
  multi-cloud as a stretch goal, not a v1 requirement).
- **Networking**: ingress controller, DNS, TLS, cert-manager, Gateway API only if
  it demonstrates something Ingress can't (canary routing, cross-namespace routing).
- **Data/state**: PostgreSQL, Redis, persistent storage class, backup approach;
  discuss managed-vs-in-cluster tradeoff explicitly.
- **Observability**: Prometheus, Grafana, Alertmanager, Loki, Fluent Bit,
  OpenTelemetry/tracing.
- **Security**: Pod Security Admission, RBAC, NetworkPolicies, secrets management,
  image/dependency scanning, policy enforcement, runtime security, supply chain.
- **Reliability**: health checks, PodDisruptionBudgets, rollback, self-healing,
  autoscaling, failure recovery.
- **Disaster recovery**: Velero, backup/restore, restore testing, runbooks.
- **Advanced/optional features** — evaluate each explicitly:
  Argo Rollouts, External Secrets Operator, Kyverno, Falco, Trivy, Cosign, SBOM
  generation (Syft), Chaos Mesh/Litmus, multi-env deployments, cost monitoring
  (OpenCost/Kubecost), multi-cluster, service mesh (usually **exclude** for a
  single-cluster portfolio repo unless demonstrating mTLS/traffic-shaping is the
  point — flag the complexity/interview-time tradeoff either way).

## 4. Phased implementation plan
15-phase skeleton (adapt count only if the user's scope is narrower):

1. **Foundation** — repo scaffold, docs skeleton, license, contributing guide,
   local kind/k3d cluster bootstrap.
2. **Cluster basics** — namespaces, RBAC, quotas, first raw manifests.
3. **Application deployment** — sample frontend/backend/worker deployed manually.
4. **Packaging and environment overlays** — Helm charts + Kustomize overlays
   (dev/staging/prod).
5. **CI/CD** — GitHub Actions: lint/test/build/scan/push.
6. **GitOps** — Argo CD + ApplicationSets syncing the overlays.
7. **Observability** — Prometheus/Grafana/Loki/Alertmanager stack + dashboards.
8. **Security hardening** — PSA, NetworkPolicies, Kyverno policies, image scanning,
   signing.
9. **Scaling and resilience** — HPA, PDBs, chaos-informed resilience tuning.
10. **Infrastructure as Code** — Terraform for the cluster + supporting cloud infra.
11. **Backups and disaster recovery** — Velero, scheduled backups, restore drills.
12. **Chaos engineering** — Chaos Mesh/Litmus experiments + observed recovery.
13. **Progressive delivery** — Argo Rollouts canary/blue-green with automated
    analysis.
14. **Production readiness** — SLOs, on-call runbooks, alert tuning, load testing.
15. **Portfolio polish** — diagrams, GIFs/screenshots, polished README, release
    tagging, badges.

Every phase needs: objective, scope, deliverables, files/folders created, files/
folders modified, tools used, acceptance criteria, demo value, interview value.

## 5. Missing pieces analysis
Per area (architecture, repo structure, docs, CI/CD, GitOps, K8s manifests,
Terraform, testing, security, observability, backup/restore, chaos testing,
release management, portfolio presentation): state what's missing and add it
proactively rather than waiting to be asked.

## 6. Suggested repository structure
Annotated tree, e.g.:
```
kubernetes-platform/
├── docs/            # architecture, guides, runbooks index
├── diagrams/         # source + exported architecture diagrams
├── runbooks/         # operational runbooks per failure scenario
├── apps/              # sample application source (frontend/backend/worker)
├── infra/terraform/   # cloud infra, modules, remote state, per-env dirs
├── k8s/base/          # raw/kustomize base manifests
├── helm/              # first-party Helm charts
├── kustomize/overlays/{dev,staging,prod}/
├── argocd/            # Application + ApplicationSet manifests
├── monitoring/        # Prometheus/Grafana/Alertmanager config + dashboards
├── logging/           # Loki/Fluent Bit config
├── tracing/           # OpenTelemetry collector config
├── security/          # Kyverno policies, network policies, PSA config
├── backup/            # Velero schedules, restore test scripts
├── chaos/             # Chaos Mesh/Litmus experiment manifests
├── .github/workflows/  # CI/CD pipelines
├── scripts/            # bootstrap, teardown, restore-drill scripts
├── tests/              # unit/integration/manifest-validation tests
└── examples/           # example workloads exercising platform features
```
Explain what belongs in each folder and why it's separated the way it is.

## 7. README blueprint
Sections: overview, architecture diagram, problem statement, tech stack,
prerequisites, local setup, deployment steps, environment structure,
observability, security model, scaling, backups, DR, testing, troubleshooting,
roadmap, screenshots, future work. Recommend specific screenshots/diagrams/GIFs
(e.g. Grafana dashboard during a load test, Argo CD sync view, a chaos experiment
recovering, an architecture diagram with data flow arrows).

## 8. GitHub optimization
Description, topics, pinned-repo positioning, README badges (build status,
license, Go/Node version, Argo CD sync status), social preview image, diagram
files, semantic release tags, issue templates, PR template, CONTRIBUTING.md,
CODE_OF_CONDUCT.md, SECURITY.md.

## 9. CI/CD design
Stage-by-stage: formatting → linting → unit tests → integration tests → manifest
validation (kubeconform) → Helm lint → Kustomize build validation → build images →
vuln scan (Trivy) → dependency scan → SBOM (Syft) → image signing (Cosign) → push
to registry → GitOps sync trigger → smoke tests → rollback handling → release
tagging → notifications. Flag optional stages explicitly (e.g. dependency scanning
as a separate job vs blocking gate) with the tradeoff of speed vs rigor.

## 10. Security strategy
Least-privilege RBAC, network segmentation, non-root containers, read-only root
filesystem, dropped capabilities, secret handling (External Secrets Operator +
cloud secret manager over raw K8s Secrets), image/dependency scanning, policy
enforcement (Kyverno), runtime security (Falco), admission control, signed images
(Cosign), supply chain integrity (SBOM + provenance), secure defaults everywhere.

## 11. Observability strategy
Metrics, logs, traces, alerts, dashboards, SLO-style thinking (error budgets,
burn-rate alerts), alert routing (Alertmanager → Slack/PagerDuty), dashboards that
prove the platform works under load/failure, example failure signals, and
operational runbooks tied to each alert.

## 12. Failure and recovery scenarios
Cover: pod crash, node failure, DB outage, Redis outage, bad deployment, high
CPU, high memory, failed rollout, cert expiry, broken secret, network policy
mistake, backup restore test. For each: expected platform behavior and the
runbook that documents it.

## 13. Documentation strategy
Architecture docs, operator guide, developer guide, installation guide, local dev
guide, security guide, backup/restore guide, runbooks, troubleshooting, roadmap,
FAQ, known limitations.

## 14. What You Should Add That I May Have Missed
Opinionated, non-redundant additions beyond the above — e.g. GitOps
ApplicationSets, multi-env promotion flow, policy-as-code, cost visibility
(OpenCost), managed-vs-in-cluster DB tradeoff writeup, test strategy doc, release
strategy (semver + changelog automation), drift detection, PR preview
environments, pre-commit hooks, secret rotation policy, admission policy
examples, backup verification job, operational dashboards, demo scripts (a
scripted walkthrough for interviews), reference architecture diagram. Only
include items that meaningfully improve the project — be opinionated, not
exhaustive for its own sake.
