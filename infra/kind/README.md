# infra/kind/

Local development cluster topology. **✅ Phase 1 — this is the one part of `infra/`
that works today.**

| File | Purpose |
| --- | --- |
| [`cluster.yaml`](cluster.yaml) | kind `Cluster` config: node topology, port mappings, node labels |

Stand it up with `make up` from the repo root. Full walkthrough:
[docs/local-development.md](../../docs/local-development.md). Why kind rather than
k3d: [ADR-0001](../../docs/decisions/0001-local-cluster-kind-over-k3d.md).

## Topology, and why

**1 control-plane + 2 workers.** A single-node cluster is faster to start and cannot
demonstrate the things this platform is about: pod anti-affinity has nothing to
spread across, PodDisruptionBudgets are meaningless, `node-drain` chaos experiments
(Phase 12) have nowhere to reschedule to, and topology spread constraints are a no-op.
Two workers is the minimum that makes scheduling decisions real. The cost is roughly
1.5GB more memory on the host, which is a fair trade.

**Control-plane is not tainted for workloads** — with only three nodes, reserving one
entirely for the control plane wastes a third of the cluster on a laptop. Production
would taint it; the difference is noted in `docs/environments.md` (Phase 4) rather
than pretended away.

**`ingress-ready=true` label on the control-plane node**, with host ports 80 and 443
mapped to it. This is the standard kind pattern for running an ingress controller
locally: ingress-nginx (Phase 2) schedules onto that node via a nodeSelector, and
`http://localhost` reaches the cluster. Ports bind to `127.0.0.1` only, so the
cluster is not exposed to the local network.

**Port 30000 mapped** as a general-purpose NodePort escape hatch for demos, so a
quick test does not require reconfiguring ingress.

## Kubernetes version pinning

`cluster.yaml` intentionally does **not** hardcode a node image. kind ships a default
node image matched to the kind binary you have, and a hardcoded tag rots — it silently
pins the platform to an old Kubernetes release, or breaks when the digest is pulled
for a different architecture.

To pin explicitly (recommended once the platform stabilises, and required for
reproducible CI):

```bash
KIND_NODE_IMAGE="kindest/node:v1.34.0@sha256:<digest>" make up
```

`cluster-up.sh` records the Kubernetes version that actually came up in
`.local/cluster-info.txt`, so the version in use is always discoverable even when it
is not pinned. Pick a digest from the [kind release
notes](https://github.com/kubernetes-sigs/kind/releases) matching your kind version —
always the digest, not the bare tag, since tags are mutable.

## Known limitations

Stated explicitly, because pretending a laptop cluster is production is how people
get surprised in Phase 10:

- **`LoadBalancer` Services stay `Pending`.** No cloud controller. Ingress via the
  mapped host ports is the local path; `cloud-provider-kind` is an option if a real
  `LoadBalancer` is ever needed.
- **NetworkPolicy enforcement depends on the CNI.** Verify with a real
  allow/deny test in Phase 8 before trusting it — see
  [`examples/network-policy-demo/`](../../examples/). If the default CNI does not
  enforce, the fix is `disableDefaultCNI: true` plus Calico or Cilium, and that
  becomes its own ADR.
- **Storage is `local-path` on the node filesystem.** No real CSI snapshots, which
  constrains what the Phase 11 Velero drills can prove locally.
- **No real cloud IAM**, so External Secrets (Phase 8) runs against a local or
  emulated backend until Phase 10.
- **Node "failure" is container removal**, not hardware failure. Close enough for
  scheduling behaviour, not for testing anything about the kubelet's own resilience.
