# infra/terraform/

Cloud infrastructure as code. **Empty scaffold — populated in
[Phase 10](../../ROADMAP.md#phase-10--infrastructure-as-code).**

## Why this is empty right now

The cloud provider has not been chosen yet, on purpose. Committing to AWS/Azure/GCP
in Phase 1 would mean writing provider-specific Terraform against a cluster shape
that has not been designed yet, then rewriting it once Phases 2–9 reveal what the
platform actually needs (which storage classes, which ingress LB type, which IAM
identities for External Secrets). See
[ADR-0002](../../docs/decisions/0002-defer-cloud-provider-choice.md).

Phases 1–9 all run against the local kind cluster in [`../kind/`](../kind/), which
is enough to build and demo the entire platform. Phase 10 then lifts it to a managed
cluster — and the fact that it lifts cleanly is itself the thing worth demonstrating.

## Planned layout

```
infra/terraform/
├── modules/                 # reusable, provider-specific building blocks
│   ├── network/             # VPC/VNet, subnets, routing, NAT
│   ├── cluster/             # managed K8s control plane + node pools
│   ├── dns/                 # zone + records for ingress hostnames
│   ├── iam/                 # workload identity, least-privilege service roles
│   └── secrets/             # cloud secret manager, for External Secrets (Phase 8)
├── envs/
│   ├── dev/                 # thin composition of modules + env-specific tfvars
│   ├── staging/
│   └── prod/
├── bootstrap/               # remote state backend, created once, out-of-band
└── README.md
```

## Design rules (set now, enforced in Phase 10)

- **Remote state, always** — object storage with versioning plus a locking mechanism.
  Local state on a laptop is how two engineers destroy each other's infrastructure.
- **Environment separation by directory, not workspace.** Workspaces share a backend
  key structure and make "which env am I in?" a runtime question. Directories make it
  a filesystem question, which is much harder to get wrong at 3am.
- **Modules take variables, never read remote state of other envs.** Cross-env
  coupling turns a staging change into a prod incident.
- **No hardcoded account IDs, regions, or CIDRs** outside `envs/*/terraform.tfvars`.
- **`terraform plan` runs in CI on every PR** and posts the plan as a comment; apply
  is gated on merge to `main` (Phase 10 extends the Phase 5 pipeline).
- **Everything tagged** with owner, environment, and cost centre — this is what makes
  the cost visibility work in Phase 14 possible at all.

## Explicitly out of scope

**Multi-cloud.** Supporting three providers spreads effort thin across all of them
instead of demonstrating depth on one. One provider is implemented; portability is a
documented design goal expressed through the module boundary, not a live requirement.
