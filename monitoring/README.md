# monitoring/

Metrics and alerting: Prometheus, Grafana, Alertmanager. **Scaffold — populated in
[Phase 7](../ROADMAP.md#phase-7--observability).**

```
monitoring/
├── prometheus/       # kube-prometheus-stack values, ServiceMonitors, scrape config
├── rules/            # PrometheusRule: recording rules + alerting rules
├── grafana/
│   ├── dashboards/   # dashboard JSON, provisioned as code
│   └── datasources/  # Prometheus, Loki, Tempo wiring
└── alertmanager/     # routing tree, receivers, inhibition, silences
```

## Why this is separate from logging/ and tracing/

They are three different signals with three different retention profiles, cost
curves, and cardinality risks. Folding them into one `observability/` directory
would hide that metrics are cheap and queryable forever while traces are expensive
and sampled. Grafana is the shared *pane of glass*; that does not make them one
system. They are joined at query time by consistent labels
(`namespace`/`service`/`pod`/`trace_id`), which is the actual integration work.

## What "done" looks like in Phase 7

Not "Prometheus is installed" — installing Prometheus is not a skill. Done is:

- **Recording rules** for RED metrics (rate, errors, duration) per service, so
  dashboards query pre-aggregated series instead of doing heavy work at render time.
- **Alerts that are symptom-based**, not cause-based. Alert on "checkout error rate
  above budget", not on "CPU is high" — high CPU that harms nobody is not an incident,
  and paging on it is how alert fatigue starts.
- **Multi-window, multi-burn-rate SLO alerts** (Phase 14) — fast burn pages, slow
  burn opens a ticket. A single threshold either pages constantly or catches nothing.
- **Every alert carries a `runbook_url`** annotation pointing into
  [`runbooks/`](../runbooks/). No runbook, no alert.
- **Dashboards provisioned as code.** A dashboard built by clicking in the UI is
  gone when the pod restarts.
- **Dashboards that prove the platform works under stress** — the interesting
  screenshot is Grafana during the Phase 12 chaos experiment, not an idle cluster
  showing flat green lines.

## Alert routing

Alertmanager routes by severity and team label. Deliberate design points:

- Inhibition rules so a node failure produces one page, not forty pod alerts.
- Grouping by `alertname` + `namespace` so a bad deploy is one notification.
- `critical` → page; `warning` → chat; `info` → dashboard only, never a notification.
- Explicit silences during known maintenance windows, expressed as config.
