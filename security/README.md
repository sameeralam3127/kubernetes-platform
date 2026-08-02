# security/

Policy-as-code, network segmentation, and admission control. **Scaffold — populated
in [Phase 8](../ROADMAP.md#phase-8--security-hardening).**

> ⚠️ Until Phase 8 lands, the cluster is **not hardened**. See
> [SECURITY.md](../SECURITY.md) for the current state and how to report issues.

```
security/
├── policies/          # Kyverno ClusterPolicies (validate, mutate, generate)
├── network-policies/  # default-deny + explicit allow rules, per namespace
├── psa/               # Pod Security Admission namespace labels
└── rbac/              # ClusterRoles and bindings beyond the Phase 2 basics
```

## Defence in depth, in layers

No single control here is sufficient; the point is that bypassing one leaves you
facing the next.

**1. Pod Security Admission** — built into Kubernetes, no extra component to run.
Namespaces are labelled `restricted` wherever possible, `baseline` where a workload
genuinely needs more. Enforced *and* audited, so violations are visible before they
are blocking.

**2. Kyverno** — what PSA cannot express: require resource limits and probes, require
the `app.kubernetes.io/*` labels, block `:latest` tags, require images from the
approved registry, verify Cosign signatures, auto-generate a default-deny
NetworkPolicy in every new namespace.

*Kyverno over OPA/Gatekeeper:* policies are Kubernetes YAML rather than Rego. For a
platform where policies must be readable by every engineer who touches it — and
explainable in an interview without teaching a second language — that matters more
than Rego's extra expressiveness. Gatekeeper is the stronger choice for genuinely
complex policy logic; this platform does not have any.

**3. NetworkPolicies** — default-deny ingress *and* egress per namespace, then
explicit allows. Default-deny is the only design where a forgotten policy fails
closed. Egress deny is the half people skip, and it is the half that limits
exfiltration and lateral movement after a compromise.

> **Local-cluster caveat:** verify the CNI actually enforces NetworkPolicy before
> trusting a green test. A policy that is silently ignored is worse than no policy,
> because you believe you are protected. See
> [ADR-0001](../docs/decisions/0001-local-cluster-kind-over-k3d.md).

**4. Workload hardening** — non-root, read-only root filesystem, all capabilities
dropped, no privilege escalation, seccomp `RuntimeDefault`. Set as chart defaults in
[`helm/`](../helm/) so it is the path of least resistance, then enforced by policy so
it cannot be quietly skipped.

**5. Secrets** — External Secrets Operator pulling from a cloud secret manager.
Kubernetes `Secret` objects are base64, not encryption; anyone with namespace read
access has the plaintext. ESO keeps the source of truth outside the cluster, gives
real rotation, and keeps secrets out of Git — which GitOps otherwise makes
structurally difficult.

**6. Supply chain** — Trivy scanning images and IaC in CI, Syft generating SBOMs,
Cosign signing images, and a Kyverno policy that refuses unsigned images at admission.
Signing without admission verification is theatre; the enforcement is the point.

**7. Runtime — Falco** (deferred to Phase 14). Real value, but noisy to tune, and an
untuned runtime-security tool trains people to ignore alerts. Added once there is a
working alert-routing discipline to plug it into.

## Rules

- Every policy ships in `Audit` mode first, with the violation count reviewed, then
  flips to `Enforce`. Enforcing on day one breaks deploys and gets policy switched off
  entirely, which is the worst outcome.
- Every policy has a test fixture in [`tests/`](../tests/) — both a manifest it must
  block and one it must allow. An untested policy is an assumption.
- RBAC is least-privilege and namespace-scoped by default. No `cluster-admin`
  bindings for humans or CI.
