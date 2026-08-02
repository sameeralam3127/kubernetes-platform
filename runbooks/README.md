# runbooks/

Operational runbooks — one per failure scenario. Written for an on-call engineer who
is tired, under pressure, and does not have time to read architecture docs.

## Runbook contract

Every runbook in this folder must follow the same shape, because inconsistent
runbooks are slow to read under pressure:

1. **Symptom** — what you saw that brought you here (the alert name, verbatim).
2. **Impact** — who or what is broken, and how badly. User-facing or not?
3. **Triage** — the first three commands to run, in order, with expected output.
4. **Diagnosis** — decision tree from triage output to root cause.
5. **Mitigation** — how to stop the bleeding *now* (often: roll back).
6. **Resolution** — the actual fix.
7. **Verification** — how you know it worked, as a command, not a feeling.
8. **Escalation** — when to stop and get help.
9. **Related** — links to the alert rule, dashboard, and relevant ADRs.

Two hard rules:

- **Every alert must link to a runbook, and every runbook must be reachable from an
  alert.** An alert with no runbook is an alert nobody knows how to action.
  Alertmanager annotations carry the `runbook_url` (Phase 7).
- **A runbook that has never been executed is a hypothesis.** Runbooks get exercised
  by the chaos experiments in [`chaos/`](../chaos/) (Phase 12) and the restore drills
  in [`backup/`](../backup/) (Phase 11). Record the date each was last exercised.

## Planned runbooks

| Runbook | Scenario | Phase |
| --- | --- | --- |
| `pod-crashloop.md` | Pod crash / CrashLoopBackOff | 3 |
| `node-failure.md` | Node NotReady, workload rescheduling | 9 |
| `database-outage.md` | PostgreSQL unavailable | 9 |
| `redis-outage.md` | Cache unavailable, degraded-mode behaviour | 9 |
| `bad-deployment.md` | Bad release needing rollback | 6 |
| `high-cpu.md` / `high-memory.md` | Saturation, OOMKills, throttling | 9 |
| `failed-rollout.md` | Argo Rollouts canary aborted by analysis | 13 |
| `cert-expiry.md` | cert-manager renewal failure | 8 |
| `broken-secret.md` | Rotated/missing secret breaking pods | 8 |
| `network-policy-block.md` | NetworkPolicy blocking legitimate traffic | 8 |
| `backup-restore-drill.md` | Scheduled Velero restore test | 11 |
| `argocd-out-of-sync.md` | Drift or a stuck sync | 6 |

The full failure-mode matrix and expected platform behaviour for each is in
[ROADMAP.md](../ROADMAP.md); runbooks are written as the phase that can actually
*cause* the failure lands, so each one can be tested rather than imagined.
