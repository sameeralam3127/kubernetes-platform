# Summary

<!-- What does this change and why? One paragraph. -->

**Phase:** <!-- e.g. Phase 2 — Cluster basics. See ROADMAP.md -->

## Type of change

- [ ] Completes part of a roadmap phase
- [ ] Bug fix
- [ ] Documentation
- [ ] Refactor / cleanup
- [ ] New component (⚠️ requires an ADR — see `docs/decisions/`)

## How was this verified

<!-- Actual commands and their output. "Tested locally" is not a verification.
     Paste the real thing, including anything that surprised you. -->

```console
$ 
```

## Checklist

- [ ] Docs updated alongside the change — a capability that is not documented and not
      runnable from a clean checkout is not done
- [ ] `ROADMAP.md` status updated if this completes or advances a phase
- [ ] No secrets, credentials, or real hostnames anywhere in the diff
- [ ] Manifests set resource requests/limits, probes, and the
      `app.kubernetes.io/*` labels
- [ ] No `:latest` image tags
- [ ] Shell scripts are `shellcheck` clean and idempotent (`make lint-shell`)
- [ ] A new component includes an ADR stating what it costs, not just what it buys

## Related

<!-- Issues, ADRs, runbooks. -->
