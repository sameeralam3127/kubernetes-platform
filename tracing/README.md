# tracing/

Distributed tracing: OpenTelemetry Collector and a trace backend. **Scaffold —
populated in [Phase 7](../ROADMAP.md#phase-7--observability).**

```
tracing/
├── otel-collector/   # Collector config: receivers, processors, exporters
└── backend/          # Tempo (or Jaeger) values and storage config
```

## Why tracing at all, without a service mesh

Metrics tell you *that* p99 latency is 2 seconds. Logs tell you what one service did.
Only traces tell you **which hop in the request path spent the 2 seconds** — and in a
frontend → api → postgres/redis chain, that is the question you actually have during
an incident.

A service mesh would provide this automatically via sidecars, and this platform
deliberately does not run one (see [`ROADMAP.md`](../ROADMAP.md) Phase 13 and the
component checklist). Application-level OpenTelemetry instrumentation gets the
observability value without the mesh's operational overhead — and it produces *better*
traces, because the app can annotate spans with business context (`order_id`, cache
hit/miss) that a sidecar proxy cannot see.

The honest cost: instrumentation is work the application team has to do, and it is
easy to do inconsistently. A mesh gives you uniform mediocre traces for free.

## Collector design

The Collector runs as a **gateway deployment**, not a per-node DaemonSet: trace
volume here does not justify per-node agents, and a central gateway makes sampling
policy, redaction, and backend routing a single configuration rather than N.

Pipeline:

- **Receivers** — OTLP gRPC and HTTP.
- **Processors** — `memory_limiter` first (a Collector OOM-killing itself takes
  observability down exactly when you need it), then `k8sattributes` to attach pod
  metadata, then batching, then attribute redaction.
- **Exporters** — traces to Tempo; span metrics to Prometheus via the `spanmetrics`
  connector, giving RED metrics derived from traces without extra instrumentation.

## Sampling

Head-based sampling at a fixed low rate is cheap but throws away the traces you want:
errors and slow requests are rare, so uniform sampling systematically discards them.
**Tail-based sampling** in the Collector — keep 100% of errors and slow requests, a
small percentage of the rest — costs more memory (spans buffer until the decision) but
keeps the interesting traces. That is the right trade here and the reason the
Collector is a gateway.

## Rules

- W3C `traceparent` propagated across every service boundary, including into async
  work via message headers — a trace that stops at the queue is half a trace.
- `trace_id` written into structured logs so traces and logs cross-link
  ([`../logging/`](../logging/)).
- Exemplars on Prometheus histograms so a latency spike on a Grafana panel links
  directly to an example trace of a slow request.
- No PII in span attributes.
