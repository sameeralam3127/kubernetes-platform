# Local Development

How to stand up the platform on your own machine. Everything through Phase 9 runs
locally — no cloud account, no spend.

## Prerequisites

| Tool | Minimum | Why | Install (macOS) |
| --- | --- | --- | --- |
| **Docker** | any recent | kind runs Kubernetes nodes as containers | `brew install --cask docker` |
| **kind** | 0.20+ | creates the cluster | `brew install kind` |
| **kubectl** | within ±1 minor of the cluster | talks to it | `brew install kubernetes-cli` |
| **make** | any | task entrypoints | preinstalled |

Optional, needed from later phases: `helm` (Phase 4), `kustomize` (Phase 4),
`shellcheck` (linting), `jq` (nicer script output).

### Resources

Docker needs **4GiB+ of memory** for the three-node cluster, and **6GiB+** once the
observability stack arrives in Phase 7. On Docker Desktop: Settings → Resources.
`make preflight` warns if you are under.

Disk: roughly 2GB for the node image plus a few hundred MB of cluster state.

### Alternatives to Docker Desktop

kind works with any Docker-compatible runtime. [OrbStack](https://orbstack.dev/)
is noticeably lighter on Apple Silicon; [Colima](https://github.com/abiosoft/colima)
(`brew install colima docker && colima start --cpu 4 --memory 8`) is the free CLI
option. Podman works with `KIND_EXPERIMENTAL_PROVIDER=podman`, with rougher edges.

## Quick start

```bash
git clone https://github.com/sameeralam3127/kubernetes-platform.git
cd kubernetes-platform

make preflight   # verify your toolchain
make up          # create the cluster (1–3 min first run)
make status      # confirm it is healthy
```

You should end up with:

```
NAME                                STATUS   ROLES           AGE   VERSION
kubernetes-platform-control-plane   Ready    control-plane   60s   v1.3x.x
kubernetes-platform-worker          Ready    <none>          45s   v1.3x.x
kubernetes-platform-worker2         Ready    <none>          45s   v1.3x.x
```

Tear it down with `make down`.

## Commands

Run `make help` for the current list. Phase 1 provides:

| Command | Does |
| --- | --- |
| `make preflight` | Check Docker/kind/kubectl are present and healthy |
| `make up` | Create the cluster. Idempotent — safe to re-run |
| `make recreate` | Delete and rebuild from scratch |
| `make status` | Nodes, system pods, unhealthy pods, context. Exits non-zero if degraded |
| `make down` | Delete the cluster (prompts) |
| `make down-force` | Delete without prompting |
| `make context` | Point `kubectl` at this cluster |
| `make lint-shell` | Shellcheck the scripts |
| `make verify` | Full Phase 1 acceptance: clean bootstrap → healthy → teardown |

The `make` targets delegate to [`scripts/`](../scripts/); call the scripts directly
if you prefer — they all support `--help`.

## What you get

One control-plane node and two workers, defined in
[`infra/kind/cluster.yaml`](../infra/kind/cluster.yaml). Two workers rather than one
because PodDisruptionBudgets, anti-affinity, topology spread, and the Phase 12
node-drain experiment are all meaningless on a single node. See
[ADR-0001](decisions/0001-local-cluster-kind-over-k3d.md) for why kind rather than
k3d or minikube.

Ports **80**, **443**, and **30000** are mapped from the control-plane node to
`127.0.0.1`, so once ingress-nginx lands in Phase 2, `http://localhost` reaches the
cluster. Loopback only — this cluster is not exposed to your network.

## Configuration

Everything is environment variables with sane defaults:

| Variable | Default | Purpose |
| --- | --- | --- |
| `CLUSTER_NAME` | `kubernetes-platform` | Run more than one cluster side by side |
| `KIND_NODE_IMAGE` | kind's default | Pin the Kubernetes version |
| `WAIT_TIMEOUT` | `300` | Seconds to wait for readiness |
| `ASSUME_YES` | `0` | Skip confirmation prompts |
| `NO_COLOR` | unset | Disable coloured output |

```bash
CLUSTER_NAME=scratch make up
KIND_NODE_IMAGE="kindest/node:v1.34.0@sha256:<digest>" make up
```

### Pinning the Kubernetes version

By default the cluster uses whatever node image your kind binary ships with, and
`make up` records the resulting version in `.local/cluster-info.txt`. For
reproducible work — and required once CI runs this — pin it explicitly by digest
(not by tag; tags are mutable). Digests are in the
[kind release notes](https://github.com/kubernetes-sigs/kind/releases). More detail
in [`infra/kind/README.md`](../infra/kind/README.md).

## Safety

The failure mode worth designing against is a stale kubeconfig pointing at a real
cluster while you believe you are on a laptop.

`cluster-down.sh` deletes by kind cluster **name**, so it is structurally incapable of
deleting anything that is not this kind cluster — no guard needed for it to be safe.
It still warns if your current context points somewhere unexpected, because a
surprised operator is worth catching even when nothing is at risk.

`scripts/lib/common.sh` also provides a `require_kind_context` guard, which verifies
both the context name and that the API server is on loopback. **No Phase 1 script
calls it**, because nothing in Phase 1 applies resources to the ambient context. It
exists as the mandatory guard for the scripts that will — `install-addons.sh` in
Phase 2, then the chaos and restore-drill scripts, all of which run `kubectl apply`
against whatever context is current.

## Troubleshooting

### `docker is installed but the daemon is not reachable`

Start Docker and wait for it to report running. If it was already running, it may
have restarted — check `docker info`.

### Cluster creation fails partway through, often at "Joining worker nodes"

Usually the Docker daemon restarting or running out of memory mid-create. kind leaves
the partial cluster behind, so:

```bash
make recreate      # deletes and rebuilds
```

`make up` deliberately refuses to report success on a half-built cluster: it checks
that the API server actually responds, not just that the cluster is listed.

If it recurs, give Docker more memory. A `kubeadm join` failure mentioning
`could not find a JWS signature in the cluster-info ConfigMap` is the classic symptom
of the control plane being starved or interrupted while workers were joining.

### `make up` says the cluster already exists but nothing works

```bash
make recreate
```

### Nodes stuck `NotReady`

Almost always the CNI failing to start. Check it:

```bash
kubectl -n kube-system get pods -l app=kindnet
kubectl -n kube-system logs -l app=kindnet --tail=50
```

A `podSubnet` colliding with your home or VPN network is a common cause. The config
uses `10.244.0.0/16`; change it in `infra/kind/cluster.yaml` if that conflicts.

### Ports 80/443 already in use

Something else on your machine is bound to them. Either stop it, or edit the
`extraPortMappings` in `infra/kind/cluster.yaml` to use e.g. 8080/8443 and rebuild.

### `kubectl` talking to the wrong cluster

```bash
make context                      # switch to this cluster
kubectl config current-context    # confirm: kind-kubernetes-platform
```

### Everything is broken and you want a clean slate

```bash
make down-force
docker system prune -a --volumes   # WARNING: removes all unused Docker data
make up
```

## Known limitations

This is a laptop cluster, and the gaps matter for later phases:

- **`LoadBalancer` Services stay `Pending`** — no cloud controller. Use ingress.
- **NetworkPolicy enforcement is CNI-dependent** and must be verified with a real
  allow/deny test in Phase 8 before it is trusted.
- **Storage is node-local `local-path`** with no real CSI snapshots, which limits
  what the Phase 11 restore drills can prove locally.
- **No cloud IAM**, so External Secrets runs against a local backend until Phase 10.

The full list, with what each one means for the roadmap, is in
[`infra/kind/README.md`](../infra/kind/README.md).

## Next

Phase 1 ends with a healthy empty cluster. Phase 2 adds namespaces, RBAC, resource
quotas, and the first addons. See [ROADMAP.md](../ROADMAP.md).
