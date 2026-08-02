# backup/

Backup and disaster recovery: Velero schedules, restore procedures, and drills.
**Scaffold — populated in
[Phase 11](../ROADMAP.md#phase-11--backups-and-disaster-recovery).**

```
backup/
├── velero/       # install values, BackupStorageLocation, VolumeSnapshotLocation
├── schedules/    # Schedule CRs: what is backed up, how often, retained how long
└── drills/       # restore drill scripts and recorded results
```

## Why this is a differentiator

Most portfolio Kubernetes repos stop at "deployed and monitored". Backup/restore is
the most commonly skipped area and one of the most commonly asked-about in
senior/staff interviews, because it is where the difference between building a system
and *operating* one shows up.

The bar this folder is held to: **an untested backup is not a backup.** Anyone can
install Velero and create a `Schedule`. The deliverable that means something is
`drills/` containing evidence of a restore that actually ran, with a measured time,
and a note about what broke the first time.

## What gets backed up, and what does not

| Data | Approach | Why |
| --- | --- | --- |
| Cluster resource definitions | Velero, but **Git is the real source of truth** | GitOps means manifests are already recoverable; Velero covers controller-generated state Git does not have |
| PersistentVolumes (Postgres) | Velero + CSI volume snapshots | Actual data loss risk lives here |
| Database logical dumps | `pg_dump` CronJob to object storage | Independent of the storage layer; the only thing that survives a corrupted snapshot or a bad schema migration |
| Secrets | **Not** backed up from the cluster | Source of truth is the cloud secret manager (Phase 8); backing them up again just creates a second place to leak them from |
| Observability data | Not backed up | High volume, low recovery value — after a disaster you need the service back, not last month's dashboards |

Two independent backup mechanisms for the database is intentional. Snapshots restore
fast; logical dumps survive failure modes snapshots do not.

## RTO and RPO

These are stated as targets and then *measured* by drills, not assumed. A documented
RTO nobody has timed is a guess.

| Scenario | RPO target | RTO target |
| --- | --- | --- |
| Accidental namespace deletion | 0 (Git) | < 15 min |
| PV data corruption | < 1 hour | < 1 hour |
| Full cluster loss | < 1 hour | < 4 hours (rebuild via Terraform + Argo CD + Velero) |

## Drill discipline

- Restore drills run on a schedule and are recorded in `drills/` with date, duration,
  and what went wrong — the failures are the valuable part.
- Restores go into a *separate namespace or cluster* first. A drill that overwrites
  production is not a drill, it is an incident.
- Verification is a query against restored data, not "the pod is Running".
- The procedure lives in
  [`runbooks/backup-restore-drill.md`](../runbooks/) and is written so someone who
  has never done it can follow it under pressure.
