# Component Checklist & Justification Pattern

Use this when drafting Architecture (section 3), CI/CD (section 9), Security
(section 10), or Advanced Features. For every component, apply this pattern:

> **Component** — Include / Exclude (or "include in Phase N, defer") — one or two
> sentences on why, and what it costs you (complexity, setup time, interview
> explainability) if included, or what you lose if excluded.

Don't just list tool names — a bare list reads like a resume keyword dump, not a
design decision.

## Default include list (high portfolio value, manageable complexity)
- **Argo CD + ApplicationSets** — canonical GitOps; ApplicationSets demonstrate
  multi-env/multi-cluster patterns cheaply.
- **Helm** (for reusable/parameterized charts) **+ Kustomize** (for env overlays)
  — using both, each for its strength, shows judgment rather than dogma.
- **Terraform** — cluster + supporting cloud infra (VPC, node groups, DNS, IAM),
  with remote state (S3+DynamoDB or equivalent) and per-env directories/workspaces.
- **cert-manager** — automated TLS is expected in any real cluster.
- **Prometheus + Grafana + Alertmanager** — the standard, and cheap to demo well.
- **Loki + Fluent Bit** — lightweight log stack that pairs naturally with
  Prometheus/Grafana (shared UI).
- **OpenTelemetry** (collector + a few instrumented traces) — shows tracing
  literacy without needing a full mesh.
- **External Secrets Operator** — real secret hygiene (pulls from cloud secret
  manager) instead of raw base64 K8s Secrets.
- **Kyverno** — policy-as-code; easier to demo/explain than OPA/Gatekeeper for a
  portfolio repo, still production-credible.
- **Trivy** — image + IaC scanning, cheap to wire into CI.
- **Cosign + SBOM (Syft)** — supply-chain signing/attestation; increasingly
  expected, differentiates from tutorial repos.
- **Velero** — backup/restore is a common gap in portfolio repos; including it
  (with an actual restore drill) is a strong differentiator.
- **Argo Rollouts** — progressive delivery (canary/blue-green) with automated
  analysis; strong interview talking point about safe releases.
- **Chaos Mesh or Litmus** — pick one; demonstrates resilience thinking, not just
  resilience claims.

## Include with caveats / defer
- **Falco** — good runtime-security signal, but noisy to tune well; include as a
  later phase (Security hardening or Production readiness), not v1.
- **Gateway API** — only if it's demonstrating something Ingress genuinely can't
  (e.g. cross-namespace routing, traffic splitting tied to Rollouts). Otherwise
  stick with an Ingress controller (e.g. ingress-nginx) to avoid unjustified
  complexity.
- **Multi-cluster** — valuable narrative ("this scales beyond one cluster") but
  expensive to actually run; usually best as a documented target architecture /
  stretch phase rather than something fully live in the repo.
- **Cost monitoring (OpenCost/Kubecost)** — nice differentiator, low cost to add;
  include if there's room, otherwise mention in "what I'd add next."

## Usually exclude (call out why explicitly)
- **Service mesh (Istio/Linkerd)** — real operational overhead; only include if
  the repo specifically needs mTLS between services or fine-grained traffic
  shaping beyond what Ingress/Rollouts already cover. Otherwise it inflates scope
  without adding proportional interview value — say so directly rather than
  including it by default.
- **Full multi-cloud support** — spreads effort thin across three providers
  instead of demonstrating depth on one. Pick one cloud (AWS is the safest
  portfolio default given hiring-market familiarity) and note multi-cloud
  portability as a documented design goal, not a live requirement.

## CI/CD stage optionality
When designing CI/CD (section 9), explicitly flag which stages are optional and
why:
- Integration tests against a real ephemeral cluster (e.g. kind-in-CI) — high
  value, higher CI time cost; optional gate vs required gate is a real tradeoff
  to name.
- Dependency scanning as a **separate non-blocking job** vs a **blocking gate** —
  non-blocking keeps velocity, blocking is more "production," name the tradeoff.
  the tradeoff explicitly rather than silently picking one.
- SBOM generation — cheap and additive; rarely worth excluding, but note it adds
  a few seconds to the pipeline and a new artifact to store.
- Image signing (Cosign) — adds a KMS/keyless-signing dependency; worth it for
  supply-chain credibility, but name the added operational dependency.

## Failure-scenario coverage checklist
Ensure section 12 covers, at minimum: pod crash, node failure, DB outage, Redis
outage, bad deployment (needs rollback), high CPU, high memory, failed rollout
(Argo Rollouts abort), cert expiry, broken/rotated secret, network policy
misconfiguration blocking legitimate traffic, and a scheduled backup-restore
drill (Velero) that's actually run, not just documented.
