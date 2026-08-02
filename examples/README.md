# examples/

Self-contained example workloads that exercise a single platform feature.

**Scaffold — grows from [Phase 2](../ROADMAP.md#phase-2--cluster-basics) onward.**

## How this differs from apps/

| | [`apps/`](../apps/) | `examples/` |
| --- | --- | --- |
| **What** | The sample services the platform hosts | Small, disposable workloads |
| **Purpose** | Realistic workload to build the platform around | Prove one capability, in isolation |
| **Lifetime** | Permanent | Applied, observed, deleted |
| **Audience** | The platform itself | A developer onboarding, or an interviewer asking "show me" |

An example should be readable in under a minute and demonstrate exactly one thing. If
it needs a paragraph of setup, it belongs in `docs/` as a guide instead.

## Why this folder earns its place

It is the answer to "show me that it actually works." A default-deny NetworkPolicy is
a claim; `examples/network-policy-demo/` with a pod that gets `connection refused`
before the allow rule and `200 OK` after is a demonstration. Every significant
platform capability should have one, and every one is also an onboarding doc for
whoever joins next.

## Planned examples

| Example | Demonstrates | Phase |
| --- | --- | --- |
| `hello-workload/` | Minimal compliant Deployment: probes, limits, non-root, correct labels | 2 |
| `quota-limits/` | A pod rejected by ResourceQuota, and one that fits | 2 |
| `rbac-demo/` | Two ServiceAccounts, different permissions, `kubectl auth can-i` output | 2 |
| `ingress-tls/` | cert-manager issuing a certificate end to end | 3 |
| `hpa-load/` | Scaling under load, with the Grafana panel to watch | 9 |
| `pdb-drain/` | A PodDisruptionBudget blocking an unsafe drain | 9 |
| `network-policy-demo/` | Blocked before the allow rule, allowed after | 8 |
| `policy-violation/` | A manifest rejected at admission, with the Kyverno message | 8 |
| `secret-rotation/` | External Secrets picking up a rotated value | 8 |
| `canary-rollout/` | An Argo Rollout aborting on bad metrics | 13 |

## Rules

- Every example directory has a `README.md` with: what it shows, how to apply it, the
  **expected output** verbatim, and how to clean up.
- Examples are namespaced into `examples-*` namespaces so cleanup is one delete.
- They never depend on each other, and never on state left behind by a previous
  example.
