# .github/workflows/

CI/CD pipelines. **Scaffold — populated in
[Phase 5](../../ROADMAP.md#phase-5--cicd).**

No workflow files exist yet. That is deliberate: Phase 1 has nothing meaningful to
build, test, or validate, and a workflow that runs `echo ok` on every push is noise
that trains you to ignore the red X.

## Planned workflows

| Workflow | Trigger | Purpose | Phase |
| --- | --- | --- | --- |
| `ci.yaml` | PR, push to `main` | Lint → test → build → scan → push images | 5 |
| `manifests.yaml` | PR touching `k8s/`, `helm/`, `kustomize/` | `kubeconform`, `helm lint`, `kustomize build` validation | 5 |
| `terraform.yaml` | PR touching `infra/terraform/` | `fmt`, `validate`, `plan` posted as a PR comment | 10 |
| `security.yaml` | PR + nightly | Trivy image/IaC scan, dependency scan, SBOM | 8 |
| `release.yaml` | Tag `v*` | Changelog, release notes, image promotion, signing | 15 |

## Pipeline design (Phase 5)

Stages, in order, with the blocking decision stated for each — because "which stage
can stop a merge" is the actual design question, not the tool list:

| Stage | Tool | Blocking? |
| --- | --- | --- |
| Format check | `gofmt`/`prettier`, `terraform fmt` | ✅ — trivially fixable, no reason to allow |
| Lint | language linter, `shellcheck`, `yamllint` | ✅ |
| Unit tests | language test runner | ✅ |
| Manifest validation | `kubeconform` (strict, against target K8s version) | ✅ — catches broken YAML before Argo CD does |
| Helm lint / template | `helm lint`, `helm template` | ✅ |
| Kustomize build | `kustomize build` per overlay | ✅ |
| Build image | Buildx, multi-arch, SBOM-attached | ✅ |
| Image vuln scan | Trivy | ✅ for **Critical/High with a fix available**; report-only otherwise |
| Dependency scan | Trivy / Dependabot | ⬜ non-blocking job |
| SBOM generation | Syft | ✅ (cheap, ~seconds, one artifact) |
| Image signing | Cosign, keyless via OIDC | ✅ on `main` only |
| Push to registry | GHCR | `main` only |
| Integration tests | kind-in-CI | ⬜ **optional gate** |
| GitOps sync | commit image digest to overlay | `main` only |
| Smoke tests | curl/k6 against dev | ✅ post-deploy |

### The two tradeoffs worth naming

**Vulnerability scanning as a blocking gate.** Blocking on all Critical/High is the
"production" answer and also the one that gets disabled within a month, because most
findings are in base-image packages with no available fix — you cannot act on them, so
the gate only teaches people to bypass it. Blocking only on *fixable* Critical/High
keeps the gate actionable, which keeps it switched on. Everything else is reported and
tracked.

**Integration tests against kind-in-CI.** High value: it catches the class of bug that
only appears when manifests meet a real API server. High cost: several minutes on every
PR. Kept as an optional gate — required on `main`, opt-in via label on PRs — so the
inner loop stays fast without giving up the coverage where it matters.

## Standards

- **Pin actions by commit SHA**, not tag. A tag is mutable; `@v4` is a supply-chain
  hole in a repo that otherwise signs its images.
- **Least-privilege `GITHUB_TOKEN`** — `permissions: {}` at workflow level, granted
  per job.
- **No secrets in `pull_request_target` workflows** triggered by forks.
- **Concurrency groups** cancel superseded runs on the same branch.
- **Caching** for dependencies and build layers, keyed on lockfile hashes.
