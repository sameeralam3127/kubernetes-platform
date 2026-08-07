# scripts/

Operational scripts for standing the platform up, tearing it down, and exercising it.

Every script here is meant to be run by a human on a laptop or by CI. They are
deliberately plain `bash` with no framework: a script an interviewer can read top to
bottom in 60 seconds is worth more than a clever one.

## Available now (Phases 1–2)

| Script | Purpose |
| --- | --- |
| [`preflight.sh`](preflight.sh) | Verify Docker, kind, and kubectl are present, correct, and healthy. Run by the others; safe to run alone. |
| [`cluster-up.sh`](cluster-up.sh) | Create the local kind cluster from [`infra/kind/cluster.yaml`](../infra/kind/cluster.yaml) and wait until it is genuinely ready. |
| [`cluster-down.sh`](cluster-down.sh) | Delete the local kind cluster. |
| [`cluster-status.sh`](cluster-status.sh) | Show nodes, system pods, and the active context. |
| [`apply-base.sh`](apply-base.sh) | Apply `k8s/base` — namespaces, quotas, limit ranges, RBAC. Guarded. |
| [`install-addons.sh`](install-addons.sh) | Install ingress-nginx, metrics-server, cert-manager at pinned versions. Guarded, idempotent. |
| [`verify-platform.sh`](verify-platform.sh) | 40 assertions that *try to break* the guardrails and fail if they succeed. |
| [`lib/common.sh`](lib/common.sh) | Shared logging, guards, and helpers. Sourced, not executed. |

Most people should use the [`Makefile`](../Makefile) targets (`make bootstrap`,
`make verify-platform`, `make down`) rather than calling these directly.

## Conventions

Every script in this directory follows these rules, and PRs that break them get sent
back:

- `#!/usr/bin/env bash` and `set -Eeuo pipefail`. No exceptions.
- **Idempotent.** Running twice is safe and does the right thing. `cluster-up.sh` on
  an existing cluster reports it and exits 0 rather than erroring or recreating.
- **Never act on the wrong cluster.** This is the single most important rule here: the
  difference between a teardown script and an outage is one wrong `kubectl` context.
  Two mechanisms enforce it:
  - *Name-scoping.* `cluster-down.sh` deletes by kind cluster **name**, so it is
    structurally incapable of touching a non-kind cluster. It still warns if your
    current context points somewhere unexpected, because that means your mental model
    is wrong even though nothing is at risk.
  - *`require_kind_context`* in `lib/common.sh` — verifies both the context name and
    that the API server is on loopback, and aborts otherwise. **Not yet called by any
    Phase 1 script**, because nothing in Phase 1 applies resources to whatever context
    happens to be current. It is the mandatory guard for the context-dependent scripts
    arriving in Phase 2 (`install-addons.sh`) and later (`chaos-run.sh`,
    `restore-drill.sh`).
- **Confirm destructive actions**, with a `--yes` flag for automation.
- **Configurable via environment variables** with sane defaults, documented in the
  script header (`CLUSTER_NAME`, `KIND_NODE_IMAGE`, ...).
- **`--help` on every script.**
- `shellcheck` clean.

## Planned

| Script | Phase |
| --- | --- |
| `bootstrap-argocd.sh` — install Argo CD and apply the root Application | 6 |
| `port-forward.sh` — Grafana / Argo CD / Prometheus UIs | 7 |
| `load-test.sh` — k6 traffic to drive HPA and SLO dashboards | 9 |
| `restore-drill.sh` — run and time a Velero restore, record the result | 11 |
| `chaos-run.sh` — steady-state check → inject → observe → report | 12 |
| `demo.sh` — scripted end-to-end walkthrough for interviews | 15 |
