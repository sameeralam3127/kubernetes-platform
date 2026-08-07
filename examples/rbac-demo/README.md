# rbac-demo

**Demonstrates:** least-privilege RBAC — what each persona can do, where, and
which escalation paths are closed.

## Run it

```bash
./examples/rbac-demo/check.sh
```

Read-only. Every call is `kubectl auth can-i`, which asks the API server's
authorizer what *would* happen. Nothing is created, changed, or deleted.

## Expected output

```
RBAC permission matrix

                                    developer          ci
                                    dev    stg    prod   dev
  ──────────────────────────────────────────────────────────────

  — workload management —
  create deployments                   yes     yes     no      yes
  delete deployments                   yes     yes     no      no
  create services                      yes     yes     no      yes
  create ingresses                     yes     yes     no      yes

  — debugging —
  read pods                            yes     yes     yes     yes
  read pod logs                        yes     yes     yes     yes
  delete pods                          yes     yes     no      no
  exec into pods                       yes     no      no      no

  — secrets —
  read secrets                         yes     yes     no      no
  write secrets                        no      no      no      no

  — escalation paths (all must be no) —
  edit rolebindings                    no      no      no      no
  edit roles                           no      no      no      no
  raise own quota                      no      no      no      no

  — cluster scope —
  list nodes (developer)               yes
  create namespaces (developer)        no
  delete nodes (developer)             no
```

Every column is the **same identity**. `developer` is one ServiceAccount in
`platform-system`, bound into three namespaces with three different Roles — not
three accounts that happen to share a name. That distinction is what makes
"writes to dev, reads prod" a true statement about a person rather than a
coincidence between unrelated identities.

## The design, and why

**Authority is namespace-scoped; visibility is cluster-wide.** The developer can
list nodes but cannot touch them. That read comes from the `platform-viewer`
ClusterRole — the only cluster-scoped grant in the platform, and deliberately
read-only. During an incident, "is this one app or is the node unhealthy?" has
to be answerable without escalating.

`platform-viewer` deliberately does **not** use Kubernetes' built-in `view`
ClusterRole, because `view` grants read on Secrets in every namespace it is bound
to — unsuitable for a broad cluster-wide grant.

**Production is read-only for humans.** From Phase 6, prod changes arrive through
Git and Argo CD. A human write path bypasses the audit trail rather than adding
to it. Read access stays generous on purpose: refusing it just means someone
keeps a break-glass admin kubeconfig in a drawer, which is strictly worse.

**`exec` is dev-only**, and lives in its own Role
([role-developer-exec-dev.yaml](../../k8s/base/rbac/role-developer-exec-dev.yaml))
rather than folded into the main one, so the grant is visible in
`kubectl get roles` and obvious in review. Exec runs arbitrary code as the pod's
ServiceAccount, inside the pod's network namespace, behind whatever NetworkPolicy
protects it. In dev that is a reasonable debugging affordance; in staging it
would invalidate the gate, and in prod it is a hole through the audit trail.

**CI holds the least.** It can write to `dev` and nowhere else, cannot create
secrets, cannot delete anything, and cannot exec. A build runner is the most
valuable credential an attacker can steal, so it carries the least authority.

**No persona can edit RBAC or raise its own quota.** A role that can edit roles
is `cluster-admin` with extra steps; a guardrail you can lift yourself is not a
guardrail.

## Verify no one has cluster-admin

```bash
kubectl get clusterrolebindings \
  -l app.kubernetes.io/part-of=kubernetes-platform \
  -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name'
```

```
NAME              ROLE
platform-viewer   platform-viewer
```

One cluster-scoped binding, and it is read-only.

## Impersonation note

`--as` requires impersonation rights, which your admin kubeconfig has. That is
what makes this demo possible — and it is also why the ability to impersonate is
itself a privilege worth protecting.

## Where these come from

[k8s/base/rbac/](../../k8s/base/rbac/) — Roles, ClusterRole, ServiceAccounts,
and bindings. The identities are ServiceAccounts because a kind cluster has no
OIDC provider; in Phase 10 the subjects become OIDC groups and nothing else
about those manifests changes.
