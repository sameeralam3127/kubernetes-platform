# quota-limits

**Demonstrates:** the capacity guardrails refusing work — and, just as
importantly, *not* getting in the way of work that plays by the rules.

A quota that has never rejected anything is an untested assumption. This example
makes the rejection reproducible in about ten seconds.

## The guardrails in dev

```bash
kubectl -n dev describe resourcequota compute-quota
kubectl -n dev describe limitrange container-limits
```

| Control | Value | Stops |
| --- | --- | --- |
| LimitRange container `max.cpu` | `1` | One container claiming the whole namespace |
| LimitRange container `max.memory` | `1Gi` | Same, for memory |
| LimitRange `maxLimitRequestRatio.cpu` | `8` | Wildly over-committed containers that schedule anywhere then starve neighbours |
| LimitRange `defaultRequest` | `50m` / `64Mi` | Pods with no resources being rejected outright by the quota |
| ResourceQuota `requests.cpu` | `2` | The namespace as a whole |
| ResourceQuota `pods` | `15` | Object-count runaway |

## 1. A container that is too large — refused by the LimitRange

```bash
kubectl apply -f oversized-pod.yaml
```

```console
Error from server (Forbidden): error when creating "oversized-pod.yaml": pods
"oversized" is forbidden: [maximum cpu usage per Container is 1, but limit is 3,
maximum memory usage per Container is 1Gi, but limit is 2Gi, maximum cpu usage
per Pod is 2, but limit is 3]
```

Note that **all three** violations are reported at once, not just the first —
the container CPU max, the container memory max, and the pod-level CPU max. A
single fix-one-thing-at-a-time loop is a bad developer experience, and the
LimitRange admission plugin is deliberately built to avoid it.

The rejection happens at admission. The pod is never scheduled, never pulls an
image, and never consumes anything.

## 2. Too much in total — refused by the ResourceQuota

`dev` allows `requests.cpu: 2`. This Deployment asks for 10 × 400m = 4 CPU:

```bash
kubectl apply -f quota-buster.yaml
kubectl -n dev describe replicaset -l app.kubernetes.io/name=quota-buster | tail -5
```

```console
$ kubectl -n dev get deploy quota-buster
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
quota-buster   4/10    4            4           12s

Warning  FailedCreate  replicaset-controller
  Error creating: pods "quota-buster-6b4f749d8d-wv5ld" is forbidden:
  exceeded quota: compute-quota,
  requested: limits.cpu=800m,requests.cpu=400m,
  used:      limits.cpu=3600m,requests.cpu=1700m,
  limited:   limits.cpu=4,requests.cpu=2
```

Three things worth noticing:

1. **The Deployment was accepted.** The failure is in the ReplicaSet controller,
   which is why `kubectl get deploy` showing `4/10` needs
   `kubectl describe replicaset` to explain itself. This is the shape most
   real quota exhaustion takes.
2. **It is partial, not all-or-nothing.** Four replicas exist; the fifth was
   refused. You end up with a half-deployed service, which is worse than a clean
   rejection and is exactly why quota alerts matter (Phase 7).
3. **Both `requests` and `limits` are enforced.** Here `limits.cpu` (3600m of 4)
   was closer to its ceiling than `requests.cpu` (1700m of 2) — over-commitment
   is capped independently of reservation.

## 3. No resources declared — accepted, with defaults applied

```bash
kubectl apply -f no-resources-pod.yaml
kubectl -n dev get pod no-resources -o jsonpath='{.spec.containers[0].resources}' | jq
```

```json
{
  "limits":   { "cpu": "200m", "memory": "256Mi" },
  "requests": { "cpu": "50m",  "memory": "64Mi"  }
}
```

Nothing in the manifest set these — the LimitRange did. This matters: a
ResourceQuota on `requests.*` rejects any pod that does not declare requests, so
without LimitRange defaults the namespace would refuse almost everything a
newcomer wrote, with an error that does not explain itself.

**The guardrail should stop the dangerous thing, not the ordinary thing.**

## Clean up

```bash
kubectl -n dev delete -f oversized-pod.yaml -f quota-buster.yaml -f no-resources-pod.yaml --ignore-not-found
```
