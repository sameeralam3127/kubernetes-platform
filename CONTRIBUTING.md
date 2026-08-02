# Contributing

Thanks for your interest in this project. This repository is a **production-style
reference platform** — the bar for changes is "would this survive a real platform
team's code review", not "does it work on my machine".

> **Status:** the platform is being built in phases. See [ROADMAP.md](ROADMAP.md)
> for what exists today and what is still scaffolding. Contributions that complete
> an in-progress phase are especially welcome; contributions that skip ahead several
> phases will usually be asked to wait, because each phase depends on the last.

## Ground rules

1. **Open an issue before large changes.** A new component (service mesh, a second
   cloud, an alternative CNI) is a design decision, not just a PR. Design decisions
   get recorded as ADRs — see [docs/decisions/](docs/decisions/).
2. **Every added component must justify its complexity.** Say what it buys, what it
   costs to operate, and what the alternative would have been. "It's popular" is not
   a justification.
3. **No secrets, ever.** Not in manifests, not in values files, not in test
   fixtures, not base64-encoded. See [SECURITY.md](SECURITY.md).
4. **Docs ship with the change.** A new capability that is not documented and not
   runnable from a clean checkout is not done.

## Local setup

Prerequisites and the full walkthrough live in
[docs/local-development.md](docs/local-development.md). The short version:

```bash
make preflight   # verify Docker, kind, kubectl are present and healthy
make up          # create the local kind cluster
make status      # show nodes, system pods, and current context
make down        # delete the cluster
```

## Development workflow

1. Fork and branch from `main`. Use a descriptive branch name:
   `phase-2/namespaces-and-rbac`, `fix/kind-arm64-node-image`, `docs/adr-cni-choice`.
2. Make your change, with docs.
3. Run the checks that exist for the phase you are touching (see below).
4. Open a PR against `main` using the PR template. Fill in the "how was this
   verified" section with actual commands and output — not "tested locally".

## Checks

The check surface grows with the roadmap. Today, Phase 1 provides:

| Check | Command | Enforced in CI |
| --- | --- | --- |
| Shell scripts lint clean | `make lint-shell` (needs `shellcheck`) | Phase 5 |
| Cluster bootstraps from clean | `make up && make status && make down` | Phase 5 |

Phases 2–5 will add manifest validation (`kubeconform`), `helm lint`,
`kustomize build` validation, and unit/integration tests. Until CI exists
(Phase 5), run checks locally and paste results into the PR.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/). The scope should be
the platform area, so history stays greppable by component:

```
feat(argocd): add ApplicationSet for per-env overlays
fix(scripts): wait for CoreDNS before reporting cluster ready
docs(adr): record kind-over-k3d decision
chore(ci): pin actions to commit SHAs
```

This matters beyond tidiness: Phase 15 derives release notes and semver bumps from
commit history, so a sloppy `Updated` commit costs real information later.

## Code style

- **Shell** — `#!/usr/bin/env bash`, `set -Eeuo pipefail`, quote every expansion,
  `shellcheck` clean. Scripts must be idempotent and safe to re-run.
- **YAML** — 2-space indent, no tabs. Every resource sets `metadata.labels` with
  the `app.kubernetes.io/*` recommended labels.
- **Terraform** — `terraform fmt` clean, modules under `infra/terraform/modules/`,
  no hardcoded account IDs or regions outside per-env variable files.
- **Markdown** — one sentence per line is *not* required, but keep lines under
  ~100 characters so diffs stay readable.

## Reporting bugs

Use the issue templates in [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/).
For anything security-relevant, do **not** open a public issue — follow
[SECURITY.md](SECURITY.md).

## Licensing

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE) that covers this project.
