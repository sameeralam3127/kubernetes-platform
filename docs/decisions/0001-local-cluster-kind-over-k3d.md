# ADR-0001: Use kind for the local development cluster

| | |
| --- | --- |
| **Status** | Accepted |
| **Date** | 2026-08-02 |
| **Phase** | 1 — Foundation |
| **Supersedes** | — |

## Context

The platform needs a local Kubernetes cluster that developers and CI can create
from scratch, repeatedly and cheaply. Phases 1 through 9 run entirely against it —
no cloud spend until Phase 10 — so this cluster has to carry roughly two-thirds of
the roadmap, not just a smoke test.

Constraints that shaped the decision:

1. **It must behave like the production target.** Phases 2–9 build namespaces, RBAC,
   quotas, ingress, autoscaling, NetworkPolicies, and admission control here and
   then lift them to a managed cluster in Phase 10. Every behavioural difference
   between local and cloud becomes a bug discovered late.
2. **It must support multi-node scheduling.** PodDisruptionBudgets, pod
   anti-affinity, topology spread, and the Phase 12 node-drain chaos experiment are
   all meaningless on a single node.
3. **It must run in CI.** Phase 5's integration tests need an ephemeral cluster
   inside a GitHub Actions runner.
4. **It must run on an Apple Silicon laptop** alongside Docker and an
   observability stack, in a few GB of RAM.
5. **It should be explainable in an interview** without a detour into how a
   particular distribution differs from upstream Kubernetes.

The realistic candidates were **kind**, **k3d**, and **minikube**.

## Decision

Use **kind** (Kubernetes IN Docker), configured in
[`infra/kind/cluster.yaml`](../../infra/kind/cluster.yaml) as one control-plane node
plus two workers.

## Rationale

**kind runs upstream Kubernetes, unmodified.** It is a Kubernetes SIG project, and
it is what the Kubernetes project itself uses for its own conformance and e2e
testing. Nodes are created with `kubeadm` — the same tool used to bootstrap real
clusters. What passes locally is testing actual Kubernetes behaviour, not a
distribution's interpretation of it.

That is the decisive point, and it is specifically where k3d's cost lands. k3d wraps
**k3s**, which is excellent but deliberately opinionated: it ships Traefik as the
ingress controller, `servicelb` (Klipper) for `LoadBalancer` Services, `local-path`
storage, and a bundled metrics-server, and it replaces etcd with SQLite by default.
For a platform whose entire point is *making and defending its own component
choices*, inheriting someone else's defaults is backwards. This platform installs
ingress-nginx deliberately (Phase 2); on k3s that means first disabling Traefik. It
enforces NetworkPolicy deliberately (Phase 8); on k3s that means reasoning about
Flannel plus k3s's own policy controller. Each of those is individually solvable, and
collectively they mean that every explanation of the platform comes with an asterisk
about what k3s changed. The interview version of "why is your ingress controller
disabled by a flag" is a worse conversation than not having the flag.

**Multi-node topology is first-class.** Adding a worker is three lines in
`cluster.yaml`, and each node is a real kubelet with its own container runtime.
k3d also supports multi-node ("agents"), so this is close to a tie — but kind's node
config lets `kubeadmConfigPatches` set per-node labels and kubelet arguments, which
is how zone labels for topology spread constraints are set up here.

**CI support is unambiguous.** `kind-action` is the de facto standard for
Kubernetes-in-CI on GitHub Actions, with node image pinning by digest. Phase 5's
optional integration-test gate depends on this working without effort.

**Version pinning is precise.** `kindest/node` images are published per Kubernetes
patch release and pinnable by digest, so a cluster can target the exact version of
the managed cluster chosen in Phase 10. See
[`infra/kind/README.md`](../../infra/kind/README.md).

## Consequences

### What this costs

- **Slower.** k3d starts in ~15–20 seconds; kind takes 1–3 minutes for three nodes,
  most of it pulling and starting real control-plane components. Paid on every
  `make recreate` and every CI run. Mitigated by caching the node image and by
  `cluster-up.sh` being idempotent, so the common case is not recreating at all.
- **Heavier.** Roughly 3–4GB RAM for three nodes versus ~1GB for a comparable k3d
  cluster. This is real on a 16GB laptop once Phase 7 adds Prometheus, Grafana, Loki,
  and Tempo. `preflight.sh` warns below 4GiB of Docker memory. If it becomes
  genuinely painful, the mitigation is a `single-node.yaml` variant for phases that
  do not need scheduling behaviour — not switching distributions.
- **No working `LoadBalancer` Services.** There is no cloud controller, so
  `LoadBalancer` stays `Pending` forever. k3s's bundled `servicelb` would just work.
  Handled by mapping host ports 80/443 to the ingress-ready control-plane node, which
  is the standard kind pattern; `cloud-provider-kind` is available if a real
  `LoadBalancer` is ever needed.
- **Storage is `local-path`,** node-local, with no real CSI snapshot support. This
  limits what the Phase 11 Velero restore drills can prove locally — volume snapshot
  restore is only fully exercised once Phase 10 provides a real CSI driver. Called
  out in [`backup/README.md`](../../backup/README.md) rather than glossed over.
- **Docker is a hard dependency.** kind requires a container runtime; minikube's VM
  drivers would not. Acceptable — Docker is already required to build the app images.

### What we gain

- Local behaviour matches upstream Kubernetes, so Phase 10's lift is a migration of
  infrastructure, not a rewrite of the platform.
- Every component in the platform is one this repo chose and can justify.
- The same tool and config work locally and in CI.

### Open risk

**Does the default CNI enforce NetworkPolicy?** kindnet's NetworkPolicy support has
changed across kind releases, and a policy that is silently ignored is worse than no
policy because it produces false confidence. Phase 8 must verify enforcement with a
real allow/deny test ([`examples/network-policy-demo/`](../../examples/)) before any
security claim is made. If it does not enforce, the fix is `disableDefaultCNI: true`
plus Calico or Cilium — which would be recorded as a new ADR, not a silent edit here.

## Alternatives considered

### k3d — rejected

Fastest and lightest by a wide margin, with genuinely good multi-node support and
a built-in registry helper that would have simplified Phase 5. Rejected because k3s's
opinionated defaults (Traefik, servicelb, SQLite, bundled metrics-server) conflict
with a platform whose value is in choosing and justifying its own components. Every
such default becomes either a flag to disable or a caveat to explain. If this project
were optimising for iteration speed rather than production fidelity, k3d would win.

### minikube — rejected

Mature, and its addon system is convenient. Rejected because multi-node support is
less mature than kind's, VM-based drivers are heavier than containers on Apple
Silicon, and the addons encourage exactly the "enable the checkbox" pattern this
platform is trying to avoid demonstrating. Its CI story is also weaker than kind's.

### Managed cloud cluster from Phase 1 — rejected

Highest fidelity, and it removes the local/cloud gap entirely. Rejected on cost and
iteration speed: a cluster running for the months this roadmap spans is real money,
and a 10-minute provisioning cycle destroys the feedback loop for phases that are
mostly manifest iteration. Cloud arrives in Phase 10, once there is a platform worth
running on it.

### Docker Desktop's built-in Kubernetes — rejected

Zero setup, but single-node only, tied to one vendor's desktop product, not
reproducible in CI, and awkward to reset cleanly. Fails constraints 2 and 3 outright.

## Related

- [`infra/kind/README.md`](../../infra/kind/README.md) — topology and known limitations
- [`docs/local-development.md`](../local-development.md) — the walkthrough
- [ADR-0002](0002-defer-cloud-provider-choice.md) — why the cloud target is deferred
