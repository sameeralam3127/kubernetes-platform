# Roadmap

A cumulative, 15-phase build-out. Each phase builds on the last, and each is
independently demoable — at the end of any phase the repository is a coherent thing
you could show someone, not a half-finished refactor.

## Status

| | Phase | Status |
| --- | --- | --- |
| 1 | [Foundation](#phase-1--foundation) | ✅ Complete |
| 2 | [Cluster basics](#phase-2--cluster-basics) | 🟡 **In progress** |
| 3 | [Application deployment](#phase-3--application-deployment) | ⬜ Not started |
| 4 | [Packaging and environment overlays](#phase-4--packaging-and-environment-overlays) | ⬜ Not started |
| 5 | [CI/CD](#phase-5--cicd) | ⬜ Not started |
| 6 | [GitOps](#phase-6--gitops) | ⬜ Not started |
| 7 | [Observability](#phase-7--observability) | ⬜ Not started |
| 8 | [Security hardening](#phase-8--security-hardening) | ⬜ Not started |
| 9 | [Scaling and resilience](#phase-9--scaling-and-resilience) | ⬜ Not started |
| 10 | [Infrastructure as Code](#phase-10--infrastructure-as-code) | ⬜ Not started |
| 11 | [Backups and disaster recovery](#phase-11--backups-and-disaster-recovery) | ⬜ Not started |
| 12 | [Chaos engineering](#phase-12--chaos-engineering) | ⬜ Not started |
| 13 | [Progressive delivery](#phase-13--progressive-delivery) | ⬜ Not started |
| 14 | [Production readiness](#phase-14--production-readiness) | ⬜ Not started |
| 15 | [Portfolio polish](#phase-15--portfolio-polish) | ⬜ Not started |

Legend: ✅ Complete · 🟡 In progress · ⬜ Not started

---

## Phase 1 — Foundation

✅ **Complete**

**Objective.** A repository someone can clone and get a working multi-node
Kubernetes cluster from, in one command, with the structure and governance in place
for everything that follows.

**Scope.** Repo scaffold, governance files, documentation skeleton, ADR process, and
a local cluster bootstrap. No workloads, no addons — an empty, healthy cluster is the
deliverable.

**Deliverables**

- Full directory tree, each folder with a README explaining what belongs in it and
  which phase fills it.
- MIT licence, contributing guide, code of conduct, security policy.
- ADR process plus the first two decisions recorded.
- Idempotent, guarded cluster bootstrap/teardown scripts behind a `Makefile`.
- Local development guide with a real troubleshooting section.

**Files created**

```
README.md · ROADMAP.md · LICENSE · CONTRIBUTING.md · CODE_OF_CONDUCT.md
SECURITY.md · Makefile · .gitignore
.github/{PULL_REQUEST_TEMPLATE.md,ISSUE_TEMPLATE/*,workflows/README.md}
docs/{README.md,local-development.md}
docs/decisions/{README.md,0001-local-cluster-kind-over-k3d.md,0002-defer-cloud-provider-choice.md}
infra/kind/{README.md,cluster.yaml}
scripts/{README.md,preflight.sh,cluster-up.sh,cluster-down.sh,cluster-status.sh,lib/common.sh}
{diagrams,runbooks,apps,infra,infra/terraform,k8s,helm,kustomize,argocd,
 monitoring,logging,tracing,security,backup,chaos,tests,examples}/README.md
```

**Files modified.** None — first phase.

**Tools.** kind, kubectl, Docker, make, bash, shellcheck.

**Acceptance criteria**

- [x] `make preflight` reports the toolchain state and fails clearly when something
      is missing.
- [x] `make up` creates a 1 control-plane + 2 worker cluster and waits for genuine
      readiness (all nodes Ready **and** CoreDNS available), not just for `kind` to
      return.
- [x] `make up` is idempotent, and refuses to report success on a half-built cluster.
- [x] `make status` reports healthy and exits 0; exits non-zero when degraded.
- [x] `make down` removes the cluster cleanly, and is idempotent when nothing exists.
- [x] Teardown is name-scoped to the kind cluster, so it cannot delete anything else,
      and warns when the current context is not what the operator expects.
- [x] `make lint-shell` is clean.
- [x] Every top-level directory has a README explaining its purpose.
- [x] Local development guide covers prerequisites, commands, and troubleshooting.
- [x] `make verify` (clean bootstrap → healthy → teardown) passes end to end.

**Carried into Phase 2.** `require_kind_context` exists in `scripts/lib/common.sh` and
is tested, but no Phase 1 script calls it — nothing here applies resources to the
ambient context. It becomes a required guard in `install-addons.sh`.

**Demo value.** `git clone && make up` → a three-node cluster in under three minutes.
The teardown is as clean as the bootstrap.

**Interview value.** Shows repo hygiene and, more importantly, decision discipline —
ADR-0001 is a written defence of a tool choice with its costs stated, which is the
thing that separates "I used kind" from "I chose kind, and here is what it cost me."

---

## Phase 2 — Cluster basics

🟡 **In progress**

**Objective.** Turn an empty cluster into a multi-tenant-shaped platform with
guardrails, before any application exists to bend them.

**Scope.** Namespaces, RBAC, resource governance, and the minimum addons a workload
needs to be reachable and measurable.

**Deliverables**

- Namespace-per-environment plus `platform-system`, with ownership labels.
- ServiceAccounts, Roles, and RoleBindings for a developer persona and a CI persona —
  neither of which is `cluster-admin`.
- ResourceQuotas and LimitRanges per namespace, so a runaway pod cannot starve the
  cluster.
- ingress-nginx, metrics-server, cert-manager installed via `scripts/install-addons.sh`.
- First `examples/` workloads demonstrating a quota rejection and RBAC boundaries.

**Files created.**
`k8s/base/{kustomization.yaml,namespaces/,governance/,rbac/}`,
`k8s/addons/{clusterissuer-selfsigned.yaml,values/*.yaml}`,
`scripts/{apply-base.sh,install-addons.sh,verify-platform.sh}`,
`docs/architecture.md`, `diagrams/platform-overview.mmd`,
`examples/{hello-workload,quota-limits,rbac-demo}/`

**Files modified.** `Makefile` (`apply-base`, `addons`, `bootstrap`, `demo`,
`lint-manifests`, `verify-platform` become real), `scripts/lib/common.sh`
(SIGPIPE fix in `cluster_exists`), `k8s/README.md`, `scripts/README.md`,
`examples/README.md`, `README.md`, this file.

**Tools.** kubectl, Kustomize, Helm, ingress-nginx 4.15.1, metrics-server 3.13.1,
cert-manager v1.21.1.

**Acceptance criteria**

- [x] Four namespaces exist with ownership labels; `platform-system` deliberately
      has **no** ResourceQuota, so a tenant cannot starve the ingress controller.
- [x] Every workload namespace has a ResourceQuota **and** a LimitRange.
- [x] A 3 CPU container is refused in `dev` by the LimitRange, reporting all
      violations at once.
- [x] A pod declaring **no** resources is still admitted, because the LimitRange
      supplies defaults — the guardrail stops the dangerous thing, not the
      ordinary thing.
- [x] `kubectl auth can-i` proves the developer persona cannot create secrets,
      edit RBAC, raise its own quota, create namespaces, or delete nodes.
- [x] One identity per persona, bound across namespaces with different Roles —
      so "writes to dev, reads prod" is true of a person, not a coincidence
      between three accounts.
- [x] Production is read-only for humans; `exec` is granted in `dev` only.
- [x] CI can write to `dev` and nowhere else, with no secrets, delete, or exec.
- [x] Nothing in the repository binds `cluster-admin`, `edit`, or `admin`.
- [x] ingress-nginx serves `http://localhost`; `examples/hello-workload` returns
      HTTP 200 with replicas spread across both workers.
- [x] `kubectl top nodes` returns metrics; `ClusterIssuer/selfsigned` is Ready.
- [x] `make addons` and `make apply-base` are idempotent, and both refuse to run
      against a non-kind context.
- [x] `make verify-platform` passes 40/40 deterministically.

**Carried forward.** Namespaces intentionally carry no Pod Security Admission
labels and there are **no NetworkPolicies**, so the workload namespaces have no
network isolation between them. Both land in Phase 8, once there are real
workloads to test a `restricted` profile against.

**Demo value.** Show a deploy being *refused* — guardrails you can see working are
more convincing than guardrails you are told about.

**Interview value.** Multi-tenancy, least privilege, and capacity governance are the
questions that separate "I can deploy to Kubernetes" from "I can run a cluster other
people deploy to."

---

## Phase 3 — Application deployment

**Objective.** Get real workloads running, deployed by hand, so that the abstractions
added in Phase 4 solve problems that have actually been felt.

**Scope.** Sample frontend, API, worker, and cron job — deliberately deployed with
raw manifests and no templating.

**Deliverables**

- `apps/{frontend,api,worker,cronjob}/` with multi-stage, non-root Dockerfiles.
- Deployments, Services, Ingress, ConfigMaps, and Secret references in `k8s/base/`.
- PostgreSQL and Redis as StatefulSet/Deployment for local use, with the
  managed-vs-in-cluster tradeoff written down rather than assumed.
- Correct liveness/readiness/startup probes — distinct, not copy-pasted.
- `runbooks/pod-crashloop.md`, the first runbook.

**Files created.** `apps/*/`, `k8s/base/apps/*.yaml`, `docs/developer-guide.md`,
`examples/ingress-tls/`, `diagrams/request-path.mmd`, `runbooks/pod-crashloop.md`

**Files modified.** `k8s/base/kustomization.yaml`, `apps/README.md`, this file.

**Tools.** Docker Buildx, kubectl, PostgreSQL, Redis.

**Acceptance criteria**

- The full request path works: browser → ingress → frontend → API → Postgres/Redis.
- A pod killed by hand is replaced with no failed requests.
- Every container runs non-root with a read-only root filesystem.
- Config comes entirely from environment/ConfigMap — one image, any environment.

**Demo value.** A working application on your own platform.

**Interview value.** Probe semantics and graceful shutdown are where most people are
vague. Being precise about why liveness ≠ readiness is a strong signal.

---

## Phase 4 — Packaging and environment overlays

**Objective.** Stop copy-pasting YAML. Introduce Helm and Kustomize, each where it
actually earns its place.

**Scope.** A reusable chart for the common service shape, plus dev/staging/prod
overlays over the Phase 3 base.

**Deliverables**

- `helm/web-service/` — a generic chart with `values.schema.json`, secure defaults,
  and helm-docs-generated documentation.
- `kustomize/overlays/{dev,staging,prod}/` differing only in replicas, resources,
  hostnames, image tags, HPA bounds, and log level.
- ADR recording the Helm/Kustomize division of labour.
- `tests/manifests/` — kubeconform validation of every rendered overlay.

**Files created.** `helm/web-service/*`, `kustomize/overlays/*/`,
`docs/environments.md`, `docs/decisions/0003-helm-and-kustomize.md`, `tests/manifests/`

**Files modified.** `k8s/base/` (becomes a proper Kustomize base), `helm/README.md`,
`kustomize/README.md`, this file.

**Tools.** Helm, Kustomize, kubeconform, helm-docs.

**Acceptance criteria**

- `kustomize build overlays/<env>` succeeds and passes kubeconform for all three.
- The three overlays differ only in the permitted dimensions — resource *shape* is
  identical.
- `helm lint` is clean and the schema rejects an invalid values file.
- No YAML is duplicated between environments.

**Demo value.** One base, three environments, a readable diff between them.

**Interview value.** "Helm or Kustomize?" is a common trap question. Having a written
boundary rather than a preference is the answer that lands.

---

## Phase 5 — CI/CD

**Objective.** Nothing reaches a registry that has not been linted, tested, scanned,
and signed.

**Scope.** GitHub Actions covering the full path from commit to a signed image and an
updated overlay.

**Deliverables**

- `ci.yaml` — format → lint → unit tests → build → scan → SBOM → sign → push.
- `manifests.yaml` — kubeconform, helm lint, kustomize build on relevant paths.
- Multi-arch image builds pushed to GHCR, tagged by digest.
- Trivy scanning, blocking only on *fixable* Critical/High — see the rationale in
  [`.github/workflows/README.md`](.github/workflows/README.md).
- Syft SBOMs attached as attestations; Cosign keyless signing via OIDC.
- Optional kind-in-CI integration gate.

**Files created.** `.github/workflows/{ci,manifests}.yaml`, `tests/integration/`,
`docs/ci-cd.md`

**Files modified.** `apps/*/Dockerfile` (build args, cache mounts),
`kustomize/overlays/dev/` (image digest written by CI), this file.

**Tools.** GitHub Actions, Buildx, Trivy, Syft, Cosign, kubeconform.

**Acceptance criteria**

- A PR that breaks a manifest fails before merge.
- Images are signed, and the signature verifies with `cosign verify`.
- Every action is pinned by commit SHA; `GITHUB_TOKEN` permissions are least-privilege.
- The pipeline finishes in under 10 minutes.

**Demo value.** A green pipeline with a signature-verification step in it.

**Interview value.** Supply-chain security is currently the highest-signal CI topic,
and most portfolio repos stop at "it builds a Docker image."

---

## Phase 6 — GitOps

**Objective.** Git becomes the only way anything reaches the cluster.

**Scope.** Argo CD, app-of-apps bootstrap, ApplicationSets generating per-environment
Applications, and per-environment sync policy.

**Deliverables**

- `argocd/install/` — Argo CD via upstream chart, with `AppProject` restrictions.
- `argocd/applications/root.yaml` — app-of-apps, the single manual bootstrap step.
- `argocd/applicationsets/` — generators fanning out over the Phase 4 overlays.
- Sync waves ordering CRDs and namespaces ahead of workloads.
- Automated rollback on failed sync; `runbooks/{bad-deployment,argocd-out-of-sync}.md`.

**Files created.** `argocd/*`, `scripts/bootstrap-argocd.sh`, `docs/gitops.md`,
`diagrams/gitops-sync-flow.mmd`, `runbooks/bad-deployment.md`

**Files modified.** `.github/workflows/ci.yaml` (commits the image digest),
`argocd/README.md`, this file.

**Tools.** Argo CD, ApplicationSets, Kustomize.

**Acceptance criteria**

- A bare cluster reaches full platform state from one `kubectl apply`.
- A manual `kubectl edit` against a managed resource is reverted by self-heal, visibly.
- Adding an environment requires a directory and a generator entry — nothing else.
- No `AppProject` permits `*` destinations or resources.

**Demo value.** Change a value in Git, watch it appear in the cluster. Then break it
by hand and watch it heal.

**Interview value.** Drift handling and the "who is allowed to sync what" question
are where GitOps discussions get real.

---

## Phase 7 — Observability

**Objective.** Be able to answer "is it working, and if not, where is it broken?"
from data rather than intuition.

**Scope.** Metrics, logs, and traces, joined by consistent labels, with alerts that
route somewhere and link to runbooks.

**Deliverables**

- kube-prometheus-stack with recording rules for RED metrics per service.
- Loki + Fluent Bit, structured JSON logs, `trace_id` on every line.
- OpenTelemetry Collector as a gateway with tail-based sampling; Tempo backend.
- Grafana dashboards provisioned as code — platform overview, per-service RED,
  and one that is legible during an incident.
- Alertmanager routing with inhibition, grouping, and `runbook_url` on every alert.

**Files created.** `monitoring/*`, `logging/*`, `tracing/*`, `docs/observability.md`,
`scripts/port-forward.sh`, `diagrams/observability-flow.mmd`

**Files modified.** `apps/*` (instrumentation), `helm/web-service/` (ServiceMonitor),
this file.

**Tools.** Prometheus, Grafana, Alertmanager, Loki, Fluent Bit, OpenTelemetry, Tempo.

**Acceptance criteria**

- Metrics → logs → traces navigation works by shared labels, in three clicks.
- Every alert has a runbook link, and every runbook is reachable from an alert.
- No alert fires on a healthy idle cluster (no baseline noise).
- Killing a dependency produces a symptom-based alert, not twelve cause-based ones.

**Demo value.** The screenshots that carry the whole README.

**Interview value.** Symptom-vs-cause alerting and cardinality discipline are
opinions you can only hold if you have actually run this.

---

## Phase 8 — Security hardening

**Objective.** Make insecure configurations impossible to deploy, not merely
discouraged.

**Scope.** Admission control, network segmentation, secret management, and supply
chain enforcement.

**Deliverables**

- Pod Security Admission at `restricted` where possible, `baseline` where justified.
- Kyverno policies: required limits/probes/labels, no `:latest`, approved registries,
  Cosign signature verification, auto-generated default-deny NetworkPolicy per namespace.
- Default-deny **ingress and egress** NetworkPolicies with explicit allows.
- External Secrets Operator replacing every committed `Secret`.
- `tests/policies/` with must-block *and* must-allow fixtures for each policy.
- Runbooks for cert expiry, broken secrets, and NetworkPolicy misconfiguration.

**Files created.** `security/*`, `tests/policies/`, `docs/security.md`,
`examples/{network-policy-demo,policy-violation,secret-rotation}/`,
`diagrams/network-policy-matrix.mmd`, `runbooks/{cert-expiry,broken-secret,network-policy-block}.md`

**Files modified.** `k8s/base/namespaces/` (PSA labels), `helm/web-service/values.yaml`
(hardened defaults), `.github/workflows/security.yaml`, `SECURITY.md`, this file.

**Tools.** Kyverno, External Secrets Operator, Trivy, Cosign, PSA.

**Acceptance criteria**

- **Verify the CNI actually enforces NetworkPolicy** before claiming segmentation —
  a silently-ignored policy is worse than none. Swap to Calico/Cilium if it does not.
- A manifest without resource limits is rejected at admission, with a clear message.
- An unsigned image is refused.
- No `Secret` manifests remain in Git; a rotated secret propagates without a redeploy.
- Every policy shipped in Audit mode first, with violation counts reviewed.

**Demo value.** Try to deploy something bad. Watch it get refused.

**Interview value.** Defence in depth, and the discipline of Audit-before-Enforce —
which is the difference between someone who has rolled out policy and someone who has
read about it.

---

## Phase 9 — Scaling and resilience

**Objective.** Behave correctly under load and during disruption.

**Scope.** Autoscaling, disruption budgets, anti-affinity, and load testing that
produces evidence.

**Deliverables**

- HPAs tuned on real load-test data, not guessed thresholds.
- PodDisruptionBudgets and topology spread constraints across the two worker nodes.
- `apps/loadgen/` and `scripts/load-test.sh` (k6).
- Documented capacity findings: where it saturates and what breaks first.
- Runbooks for node failure, DB/Redis outage, high CPU, high memory.

**Files created.** `apps/loadgen/`, `scripts/load-test.sh`, `docs/scaling.md`,
`examples/{hpa-load,pdb-drain}/`, `runbooks/{node-failure,database-outage,redis-outage,high-cpu,high-memory}.md`

**Files modified.** `helm/web-service/` (HPA/PDB templates), overlays (per-env bounds),
`monitoring/rules/` (saturation alerts), this file.

**Tools.** HPA, metrics-server, PDBs, k6.

**Acceptance criteria**

- Load drives a scale-up, and p99 stays inside target throughout.
- `kubectl drain` on a worker respects PDBs and causes no downtime.
- Anti-affinity provably spreads replicas across both workers.
- A capacity limit is documented with a number, not an adjective.

**Demo value.** The Grafana dashboard during a load test — replicas climbing, latency
flat.

**Interview value.** Tuned-from-data beats tuned-from-defaults, and "what breaks
first" is a question only people who have actually load-tested can answer.

---

## Phase 10 — Infrastructure as Code

**Objective.** Move from a laptop to a real managed cluster, and prove the platform
above the cluster boundary was genuinely portable.

**Scope.** Provider selection, Terraform modules, remote state, per-environment
infrastructure.

**Deliverables**

- ADR selecting the cloud provider, and a second on managed vs in-cluster PostgreSQL.
- `infra/terraform/modules/{network,cluster,dns,iam,secrets}/`.
- `infra/terraform/envs/{dev,staging,prod}/`, separated by directory not workspace.
- `infra/terraform/bootstrap/` for the remote state backend.
- `terraform plan` posted as a PR comment; apply gated on merge.

**Files created.** `infra/terraform/**`, `docs/infrastructure.md`,
`.github/workflows/terraform.yaml`, `docs/decisions/000N-cloud-provider.md`

**Files modified.** Overlays (storage classes, LB annotations, workload identity),
`security/` (real cloud secret manager), `infra/terraform/README.md`, this file.

**Tools.** Terraform, the chosen cloud provider, cert-manager DNS-01.

**Acceptance criteria**

- `terraform apply` from nothing produces a working cluster.
- The same Argo CD bootstrap that works on kind works on the managed cluster.
- Remote state is versioned and locked; no state file has ever been local.
- No hardcoded account IDs or regions outside per-env tfvars.
- `terraform destroy` leaves nothing behind (verified, because cloud bills).

**Demo value.** "The whole thing, from zero, in two commands."

**Interview value.** This is where the portability claim from ADR-0002 gets tested
in public. Directory-vs-workspace separation is a small opinion that signals real
Terraform mileage.

---

## Phase 11 — Backups and disaster recovery

**Objective.** Be able to lose things and get them back, with a measured recovery
time rather than a hoped-for one.

**Scope.** Velero, scheduled backups, independent database dumps, and restore drills
that actually run.

**Deliverables**

- Velero with object-storage backup location and CSI volume snapshots.
- Backup schedules with deliberate retention per data class.
- A `pg_dump` CronJob to object storage — independent of the storage layer, because
  snapshots do not survive a bad schema migration.
- `scripts/restore-drill.sh` that runs, times, and records a restore.
- Documented, *measured* RTO/RPO per scenario.

**Files created.** `backup/{velero,schedules,drills}/`, `scripts/restore-drill.sh`,
`docs/backup-restore.md`, `runbooks/backup-restore-drill.md`,
`diagrams/backup-restore-flow.mmd`

**Files modified.** `infra/terraform/modules/` (backup bucket, IAM), `monitoring/rules/`
(backup-failure alerts), `backup/README.md`, this file.

**Tools.** Velero, CSI snapshots, object storage.

**Acceptance criteria**

- A deleted namespace is restored from backup, verified by querying restored data —
  not by "the pod is Running".
- Restores go to a separate namespace first; a drill never overwrites the source.
- Measured RTO is recorded and compared against target.
- A failed backup pages.
- `drills/` records at least one run, **including what went wrong the first time**.

**Demo value.** Delete something important on camera. Get it back. State the elapsed
time.

**Interview value.** The most commonly skipped area in portfolio repos, and the one
most likely to be asked about for senior roles.

---

## Phase 12 — Chaos engineering

**Objective.** Test the resilience claims made in Phases 7–11 instead of asserting
them.

**Scope.** Hypothesis-driven fault injection with bounded blast radius and recorded
results.

**Deliverables**

- ADR selecting Chaos Mesh or Litmus.
- `chaos/steady-state/` — the hypothesis as concrete Prometheus queries, committed
  *before* any experiment runs.
- `chaos/experiments/` — pod-kill, container-kill, CPU/memory stress, network delay,
  network partition, DB outage, node drain, DNS chaos.
- `chaos/results/` — outcomes, **especially the failures**.
- `scripts/chaos-run.sh` — steady state → inject → observe → report.

**Files created.** `chaos/*`, `scripts/chaos-run.sh`, `docs/chaos.md`,
`docs/decisions/000N-chaos-tool.md`

**Files modified.** Runbooks (corrected by what the experiments actually revealed),
`monitoring/rules/` (gaps found), `chaos/README.md`, this file.

**Tools.** Chaos Mesh or Litmus, Prometheus, k6.

**Acceptance criteria**

- Every experiment has a written hypothesis and abort criteria before it runs.
- Blast radius is bounded by namespace and label selector.
- At least one experiment **falsifies** an assumption, and the fix is documented.
  An experiment suite that never found anything was not testing hard enough.
- Every runbook exercised by an experiment gets its "last validated" date updated.

**Demo value.** Kill a node while a load test runs and show the SLO holding.

**Interview value.** "What surprised you?" is the follow-up question, and having a
real answer is the entire point of this phase.

---

## Phase 13 — Progressive delivery

**Objective.** Make a bad release stop itself before it becomes an incident.

**Scope.** Argo Rollouts with metric-driven canary analysis and automatic abort.

**Deliverables**

- Argo Rollouts replacing Deployments for the user-facing services.
- Canary strategy with weighted steps and analysis at each gate.
- `AnalysisTemplate`s querying Prometheus for error rate and latency.
- Automatic abort and rollback on failed analysis.
- ADR recording why a service mesh is *not* used, and what that costs.

**Files created.** `k8s/base/rollouts/`, `monitoring/analysis-templates/`,
`docs/progressive-delivery.md`, `examples/canary-rollout/`,
`runbooks/failed-rollout.md`, `diagrams/canary-rollout.mmd`,
`docs/decisions/000N-no-service-mesh.md`

**Files modified.** `helm/web-service/` (Rollout instead of Deployment),
`argocd/` (Rollout health checks), this file.

**Tools.** Argo Rollouts, Prometheus, ingress-nginx traffic splitting.

**Acceptance criteria**

- A canary with a deliberately broken build aborts automatically and rolls back.
- Analysis queries real Prometheus metrics, not a timer.
- Argo CD reports Rollout health correctly mid-canary.
- The no-service-mesh decision is written down with its tradeoff, not left implicit.

**Demo value.** Deploy something broken on purpose. Watch the platform refuse it,
with no human involved.

**Interview value.** Safe-release mechanics, plus the judgement to *exclude* a mesh
and say why — excluding things well is rarer than including them.

---

## Phase 14 — Production readiness

**Objective.** Operate it, not just run it.

**Scope.** SLOs, error budgets, alert tuning, runtime security, and cost visibility.

**Deliverables**

- SLIs and SLOs per service with explicit error budgets.
- Multi-window, multi-burn-rate alerts — fast burn pages, slow burn tickets.
- Alert tuning pass: delete everything that has ever fired without being actionable.
- Falco for runtime security, deferred to here because untuned runtime alerts train
  people to ignore alerts.
- OpenCost for cost visibility.
- On-call guide, escalation policy, incident template.

**Files created.** `docs/{slos.md,troubleshooting.md,on-call.md}`,
`monitoring/rules/slo-*.yaml`, `security/falco/`, `monitoring/opencost/`

**Files modified.** Every runbook (escalation paths), `monitoring/alertmanager/`,
`docs/observability.md`, this file.

**Tools.** Prometheus, Falco, OpenCost, Alertmanager.

**Acceptance criteria**

- Every user-facing service has an SLO with a stated error budget.
- Burn-rate alerts fire at the right speed for the right severity.
- Every remaining alert has fired at least once in testing and was actionable.
- Cost per namespace is visible.
- Falco is tuned to a signal-to-noise ratio someone would actually keep enabled.

**Demo value.** An error-budget dashboard with a burn-rate alert firing during a
chaos experiment.

**Interview value.** SLO thinking is the clearest marker of SRE maturity, and
"which alerts did you delete" is a better question than "which did you add."

---

## Phase 15 — Portfolio polish

**Objective.** Make the work legible in the 90 seconds a reviewer actually spends.

**Scope.** Diagrams, screenshots, README, release process, repository presentation.

**Deliverables**

- Architecture diagram with data flow arrows as the README hero image.
- Screenshots and GIFs: Grafana under load, an Argo CD sync, a chaos experiment
  recovering, a canary aborting.
- README rewritten now that everything exists — problem first, tour second.
- `scripts/demo.sh` — a scripted end-to-end walkthrough for live interviews.
- Semantic release tags, generated changelog, badges.
- GitHub metadata: description, topics, social preview.
- `docs/{faq.md,known-limitations.md}` — an honest account of what this is not.

**Files created.** `diagrams/exports/*`, `docs/{faq.md,known-limitations.md}`,
`scripts/demo.sh`, `.github/workflows/release.yaml`, `CHANGELOG.md`

**Files modified.** `README.md` (full rewrite), every diagram, this file (all phases
complete).

**Tools.** Mermaid/D2, asciinema or a screen recorder, release-please or similar.

**Acceptance criteria**

- The README communicates what this is and why it is interesting above the fold.
- Every major capability has a visual.
- `scripts/demo.sh` runs the whole story end to end without manual steps.
- Releases are tagged with generated notes.
- `known-limitations.md` is honest — including that some phases only run locally.

**Demo value.** The repository sells itself without you in the room.

**Interview value.** Communication. A platform nobody can understand in 90 seconds
is a platform that does not get discussed in the interview at all.

---

## Deliberate exclusions

Things not on this roadmap, and why — because what you leave out is a design decision
too:

- **Service mesh (Istio/Linkerd).** Real operational overhead, and Ingress plus Argo
  Rollouts already cover the traffic shaping this platform needs. mTLS between
  services is the one genuine gap; it is called out in the Phase 13 ADR rather than
  papered over.
- **Multi-cloud.** Spreads effort across three providers instead of demonstrating
  depth on one. Portability is a design goal expressed through module boundaries, not
  a live requirement.
- **Multi-cluster.** A good narrative, expensive to actually run. Documented as a
  target architecture; the ApplicationSet patterns in Phase 6 are the cheap honest
  demonstration of the shape.
- **A rich sample application.** The apps exist to stress the platform. Any feature
  that does not exercise a platform capability is a distraction from the thing being
  demonstrated.
