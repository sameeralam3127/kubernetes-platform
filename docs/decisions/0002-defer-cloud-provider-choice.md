# ADR-0002: Defer the cloud provider choice to Phase 10

| | |
| --- | --- |
| **Status** | Accepted |
| **Date** | 2026-08-02 |
| **Phase** | 1 — Foundation |
| **Supersedes** | — |

## Context

[`infra/terraform/`](../../infra/terraform/) exists in the repository structure from
Phase 1, but it is empty. The obvious alternative was to pick a cloud immediately —
AWS being the conventional default — and start writing Terraform alongside everything
else.

Two facts argue against doing that now:

1. **Phases 1–9 do not need a cloud.** Every capability through scaling and
   resilience is built and demonstrated on the local kind cluster
   ([ADR-0001](0001-local-cluster-kind-over-k3d.md)). Terraform written in Phase 1
   would sit unused and un-run for the majority of the roadmap, drifting against
   provider releases the whole time.
2. **The requirements are not known yet.** What the cloud infrastructure has to
   provide is determined by decisions that have not been made: which ingress
   controller and therefore which load balancer type (Phase 2), which storage class
   and snapshot capability the backup strategy needs (Phase 11), which workload
   identity mechanism External Secrets uses (Phase 8), and what the observability
   stack's storage backend is (Phase 7). Writing the infrastructure first means
   guessing at all of it and rewriting later.

## Decision

Leave `infra/terraform/` as a documented, empty scaffold. Choose the cloud provider
at the start of **Phase 10 — Infrastructure as Code**, informed by what Phases 2–9
actually established. Keep everything above the cluster boundary
([`k8s/`](../../k8s/), [`helm/`](../../helm/), [`kustomize/`](../../kustomize/))
provider-agnostic so the Phase 10 lift is a migration, not a rewrite.

## Consequences

### What this costs

- **The repo shows an empty `infra/terraform/` for nine phases.** A reviewer skimming
  early could read that as a gap rather than a decision. Mitigated by the README in
  that directory stating the reasoning and linking here — and arguably a documented
  deferral reads better than speculative Terraform that has never been applied.
- **Some platform decisions get made without a known cloud target,** so a few may
  need revisiting in Phase 10 (storage class names, LB annotations, identity
  bindings). This is bounded: those are exactly the differences that overlays and
  values files are designed to absorb.
- **Cloud-specific work concentrates into one phase** rather than spreading across
  the roadmap, making Phase 10 larger than its neighbours.

### What we gain

- No speculative infrastructure code, and no rewrite of Terraform written against
  requirements that turned out to be wrong.
- Provider-agnosticism is *enforced by circumstance* for nine phases rather than
  merely intended. Portability that has never been tested is a claim; portability
  that was the only option available is a property.
- Zero cloud spend until there is a platform worth running on a cloud.
- Phase 10 becomes a demonstrable "lift this platform to a managed cluster" story —
  which is a more interesting thing to show than "here is some Terraform".

## Guidance for Phase 10

The decision is deferred, not unconstrained. When it is made, it gets its own ADR
covering:

- **Provider choice**, weighted by target job market rather than technical merit —
  the three managed offerings are close enough technically that hiring-market
  familiarity is the deciding factor. AWS/EKS remains the safest default.
- **Managed vs in-cluster PostgreSQL** — its own ADR; the tradeoff (operational
  burden vs cost vs demonstrating StatefulSet competence) deserves a written answer.
- **Remote state backend** and locking mechanism.
- **Whether the local kind cluster remains the dev environment** or dev also moves
  to the cloud. Keeping kind as the inner loop is likely correct on cost alone.

## Alternatives considered

### Pick AWS now and write Terraform in Phase 1 — rejected

The conventional choice, and it makes the repo look more complete sooner. Rejected
because the Terraform would encode guesses about requirements from six phases ahead,
would not be applied or validated for months, and would need rewriting once the
platform's actual needs emerged. Unapplied infrastructure code is a liability that
looks like an asset.

### Write cloud-agnostic Terraform abstractions now — rejected

Superficially attractive: build module interfaces that any provider could implement.
In practice, cloud abstraction layers leak badly — IAM, networking, and storage
models are genuinely different, and a common interface across them either collapses
to the intersection of what all three do or becomes a switch statement. It is also
substantial work with no payoff until a second provider exists, which the roadmap
explicitly does not plan for.

### Skip Terraform entirely, stay local forever — rejected

Cheapest, and Phases 1–9 would be unaffected. Rejected because "can you run this in a
real cloud" is the first question any reviewer asks about a platform that only exists
on a laptop, and Infrastructure as Code is core to the role this project represents.

## Related

- [`infra/terraform/README.md`](../../infra/terraform/README.md) — planned layout and design rules
- [ADR-0001](0001-local-cluster-kind-over-k3d.md) — the local cluster carrying Phases 1–9
- [ROADMAP.md](../../ROADMAP.md) — Phase 10
