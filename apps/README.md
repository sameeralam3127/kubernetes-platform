# apps/

Source code for the sample applications that exercise the platform.

**These apps exist to stress the platform, not to be a product.** Their job is to
produce the conditions a real platform must handle: HTTP traffic, DB and cache
dependencies, async work, scheduled work, health endpoints, metrics, traces,
configuration, and secrets. Every feature they have should map to a platform
capability being demonstrated.

That constraint is deliberate. A rich sample app is a distraction — reviewers should
spend their attention on the platform, and the apps should stay small enough that
their Dockerfiles and manifests are readable in one screen.

## Planned services (Phase 3)

| Service | Role | Platform capability it exercises |
| --- | --- | --- |
| `frontend/` | Web UI calling the API | Ingress, TLS, HPA under load, canary routing (Phase 13) |
| `api/` | REST API, reads/writes Postgres and Redis | Deployment, probes, ConfigMaps/Secrets, DB dependency failure modes, tracing |
| `worker/` | Consumes a queue, does async work | Scaling on queue depth, PDBs, graceful shutdown, retry behaviour |
| `cronjob/` | Scheduled batch job | CronJob semantics, job failure alerting, backoff |
| `loadgen/` | Traffic generator (Phase 9/14) | Drives HPA, saturates SLOs, feeds canary analysis |

## Per-service layout

Each service directory owns its build, not its deployment:

```
apps/<service>/
├── src/                 # application source
├── Dockerfile           # multi-stage, non-root, minimal base, pinned by digest
├── .dockerignore
├── README.md            # what it does, endpoints, env vars, how to run locally
└── tests/               # unit tests run in CI (Phase 5)
```

Deployment manifests live in [`k8s/`](../k8s/), [`helm/`](../helm/), and
[`kustomize/`](../kustomize/) — never here. Keeping build separate from deploy is
what makes the same image promotable across environments unchanged, which is the
whole point of the overlay model in Phase 4.

## Requirements every service must meet

Set now so Phase 3 has a bar to hit rather than a retrofit:

- Non-root user, read-only root filesystem, all capabilities dropped.
- Distinct `/healthz` (liveness) and `/readyz` (readiness) — they are not the same
  question, and conflating them causes rolling-update outages.
- Graceful shutdown on `SIGTERM` within the termination grace period.
- Prometheus metrics on `/metrics`, including RED metrics (Phase 7).
- OpenTelemetry trace context propagated across service calls (Phase 7).
- All configuration from environment or mounted ConfigMap — nothing baked into the
  image, so one image runs in every environment.
