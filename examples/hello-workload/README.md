# hello-workload

**Demonstrates:** what a fully compliant workload looks like on this platform —
the reference every other manifest is measured against.

Every field in [deployment.yaml](deployment.yaml) exists because a guardrail
requires it. From Phase 8, Kyverno rejects manifests missing resource limits,
probes, or the recommended labels, so this is what passing admission looks like.

## Apply

```bash
kubectl apply -k examples/hello-workload/
kubectl -n dev rollout status deployment/hello --timeout=90s
```

## Expected output

```console
$ kubectl -n dev get pods -l app.kubernetes.io/name=hello -o wide
NAME                     READY   STATUS    RESTARTS   AGE   NODE
hello-6d9f8b7c5d-4xk2p   1/1     Running   0          18s   kubernetes-platform-worker
hello-6d9f8b7c5d-r7mnq   1/1     Running   0          18s   kubernetes-platform-worker2

$ curl -s http://localhost/hello | head -4
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
```

Note the two pods land on **different workers** — that is the
`topologySpreadConstraints` working, and it is why the local cluster has two
worker nodes rather than one.

## What to look at

| Field | Why it is there |
| --- | --- |
| `runAsNonRoot`, `runAsUser: 101` | Container runs unprivileged. `nginx-unprivileged` binds :8080, so no `NET_BIND_SERVICE` is needed. |
| `readOnlyRootFilesystem: true` | Nothing writes to the image layer. The two `emptyDir` mounts are the explicit exceptions nginx needs. |
| `capabilities: drop: [ALL]` | No capability is granted that has not been justified. |
| `requests` **and** `limits` | Without requests the scheduler guesses; without limits one pod starves its neighbours. |
| Separate `readiness` / `liveness` | They answer different questions. Wiring liveness to a dependency check restarts the whole fleet when one database is slow. |
| `startupProbe` | Gives a slow start 60s before liveness begins killing it. |
| `topologySpreadConstraints` | Spreads replicas across workers, so losing a node does not lose the service. |
| `app.kubernetes.io/*` labels | What makes selectors, dashboards, and cost attribution work later without a relabelling migration. |

## Verify the guardrails accepted it

```bash
# The quota now shows consumption
kubectl -n dev describe resourcequota compute-quota

# The pod's resources were taken from the manifest, not the LimitRange default
kubectl -n dev get pod -l app.kubernetes.io/name=hello \
  -o jsonpath='{.items[0].spec.containers[0].resources}' | jq
```

## Clean up

```bash
kubectl delete -k examples/hello-workload/
```
