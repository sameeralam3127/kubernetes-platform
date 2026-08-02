# chaos/

Chaos engineering experiments. **Scaffold — populated in
[Phase 12](../ROADMAP.md#phase-12--chaos-engineering).**

```
chaos/
├── experiments/   # experiment manifests, one per failure mode
├── steady-state/  # the hypothesis: what "healthy" means, as queries
└── results/       # recorded outcomes, including the ones that failed
```

## The point

Chaos engineering is not "break things randomly". It is a **hypothesis test**:

> Under steady state X, when fault Y is injected, the platform should behave as Z,
> and users should observe no more than W impact.

If you cannot state Z before you run the experiment, you are not testing — you are
just causing an outage and finding out afterwards. That is why `steady-state/` exists
as its own directory: the hypothesis is written, as concrete Prometheus queries, and
committed *before* the experiment runs.

This is also what validates everything built in Phases 7–11. A dashboard is a claim
that you would see the problem. A runbook is a claim that you would know what to do.
An HPA is a claim that it would scale. Chaos experiments are how those claims get
tested instead of assumed.

## Experiment catalogue (Phase 12)

Ordered by blast radius, smallest first — you do not start by killing a node.

| Experiment | Fault | Hypothesis | Validates |
| --- | --- | --- | --- |
| `pod-kill` | Delete a random API pod | No failed requests; replacement Ready < 30s | Probes, replica count, rolling behaviour |
| `container-kill` | SIGKILL the container, keep the pod | Restart without pod reschedule; brief error blip | Liveness probe tuning |
| `cpu-stress` | Saturate CPU on API pods | HPA scales up; p99 stays inside SLO | Phase 9 autoscaling |
| `memory-stress` | Approach the memory limit | OOMKill contained to one pod; alert fires | Limits, alerting |
| `network-delay` | 500ms latency to Postgres | Timeouts and retries behave; no cascade | Timeout/retry config |
| `network-partition` | Sever API → Redis | Degraded mode, not a hard outage | Graceful degradation |
| `pod-failure` (DB) | Postgres unavailable 2 min | Correct error surfacing, clean recovery, no data loss | DB failure handling, runbook |
| `node-drain` | Cordon and drain a node | Workloads reschedule; PDBs respected; no downtime | PDBs, anti-affinity |
| `dns-chaos` | DNS resolution failures | Bounded failure, clear signal, no silent hang | Resilience to the classic K8s failure |

## Rules

- **Steady state first.** Define and verify it before injecting anything. If the
  system is already unhealthy, the experiment result is meaningless.
- **One variable at a time.** Two simultaneous faults produce an unattributable
  result.
- **Blast radius is bounded** by namespace and label selectors, always, and starts
  small.
- **Abort criteria are defined up front**, with an actual stop procedure.
- **Record every result in `results/`, especially the failures.** "We expected
  graceful degradation and got a cascading outage" is the single most valuable
  artifact this directory can produce — it is the finding that a real incident would
  otherwise have produced for you at a much worse time.
- **Every experiment maps to a runbook** in [`runbooks/`](../runbooks/). Running the
  experiment is how the runbook gets validated.
- **Never in prod without a documented game day.** In this repo, experiments run
  against dev/staging.
