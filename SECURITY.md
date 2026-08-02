# Security Policy

## Scope and intent

`kubernetes-platform` is a **reference platform**. It is designed to demonstrate
production security patterns, and the hardening work is delivered in
[Phase 8](ROADMAP.md#phase-8--security-hardening). Until that phase lands, treat
this repository as **not hardened**.

Concretely, as of Phase 1:

- No admission control, Pod Security Admission profiles, or NetworkPolicies exist yet.
- No image scanning, signing, or SBOM generation runs yet.
- The local cluster created by `make up` is a [kind](https://kind.sigs.k8s.io/)
  cluster bound to `127.0.0.1` for development only. **Do not expose it to a
  network you do not control, and do not run it on a shared or production host.**

## Reporting a vulnerability

**Do not open a public GitHub issue for security problems.**

Report privately via GitHub's [private vulnerability
reporting](https://github.com/sameeralam3127/kubernetes-platform/security/advisories/new)
(Security → Report a vulnerability). If that is unavailable, email
**sameeralam3127@gmail.com** with `[SECURITY]` in the subject.

Please include:

- Affected path(s), commit SHA, and phase/component.
- Reproduction steps or a proof of concept.
- Impact assessment — what an attacker gains.
- Any suggested remediation.

### What to expect

| Stage | Target |
| --- | --- |
| Acknowledgement of report | 3 business days |
| Initial triage and severity assessment | 7 business days |
| Fix or documented mitigation | 30 days for High/Critical; best effort otherwise |

This is a personally maintained project, not a vendor product — these are good-faith
targets, not a contractual SLA. Coordinated disclosure is appreciated; credit will be
given in the advisory unless you prefer otherwise.

## What is in scope

- Committed secrets, credentials, or private keys anywhere in history.
- Manifests, Helm charts, or Terraform that grant excessive privilege by default
  (cluster-admin bindings, privileged containers, wide-open security groups).
- CI/CD supply-chain weaknesses: unpinned actions, injectable workflow inputs,
  over-scoped `GITHUB_TOKEN` permissions, mutable image tags in deploy paths.
- Scripts in `scripts/` that could damage a host or an unintended cluster —
  for example acting on the wrong `kubectl` context.

## What is out of scope

- Vulnerabilities in upstream third-party components (Kubernetes, Argo CD,
  Prometheus, etc.). Report those to their maintainers; if this repo pins a known-bad
  version, that pin *is* in scope.
- The intentional pre-hardening state of phases not yet complete, as listed above
  and tracked in [ROADMAP.md](ROADMAP.md). Pointing out that Phase 8 has not shipped
  is not a vulnerability report.
- Findings that require an attacker to already have cluster-admin or host root.

## Secret handling in this repo

There are no real secrets in this repository, and there should never be any.

- `.gitignore` broadly excludes key material, `.env` files, `*-secret.yaml`, and
  kubeconfigs.
- From Phase 8, secrets are sourced through the External Secrets Operator from a
  cloud secret manager rather than committed as base64 `Secret` objects.
- Example values are always placeholders and must be obviously fake
  (`REPLACE_ME`, `example.invalid`), never a redacted real value.

If you believe a credential has been committed — even in an old commit — report it
privately as above. Rotation comes first; scrubbing history comes second.
