# logging/

Log collection and aggregation: Loki + Fluent Bit. **Scaffold — populated in
[Phase 7](../ROADMAP.md#phase-7--observability).**

```
logging/
├── loki/          # Loki values, retention, storage backend config
└── fluent-bit/    # DaemonSet values, input/filter/output pipeline, parsers
```

## Why Loki and Fluent Bit rather than an ELK stack

**Loki** indexes labels, not full log content. That makes it dramatically cheaper to
run than Elasticsearch for the same volume, and it shares Grafana with the metrics
stack — so "spike in the graph → the logs behind that spike" is one click with the
same label selectors, rather than a context switch into Kibana and a manual time
correlation. The tradeoff is real and worth stating: full-text search across all
history is genuinely worse than Elasticsearch. For a platform where the workflow is
"start from an alert, narrow by service and time", that is the right trade. For
log-analytics-as-a-product, it would not be.

**Fluent Bit** over Fluentd: written in C, ~1/10th the memory footprint, and the
routing and parsing needed here does not require Fluentd's plugin ecosystem. On a
DaemonSet running on every node, per-node overhead is multiplied by the cluster size,
so it is worth caring about.

## Design rules

- **Structured JSON logs from every service.** Grep-parsing unstructured text at
  query time is a tax paid on every single query forever.
- **Consistent labels with the metrics stack** — `namespace`, `service`, `pod`,
  `trace_id`. This is what makes metrics → logs → traces navigation actually work;
  without it the three systems are three separate tools that happen to share a UI.
- **Low label cardinality.** Never label by user ID, request ID, or trace ID —
  high-cardinality labels are how Loki installations fall over. Those go in the log
  *body*, where they are still searchable within a narrowed stream.
- **`trace_id` in every log line** so a trace links to its logs and back (Phase 7).
- **Retention is a deliberate decision, not a default** — short and cheap for debug
  logs, longer for audit-relevant events. Documented in `docs/observability.md`.
- **No secrets, tokens, or PII in logs.** Fluent Bit filters scrub known-sensitive
  fields as a backstop, but the real fix is applications not logging them.
