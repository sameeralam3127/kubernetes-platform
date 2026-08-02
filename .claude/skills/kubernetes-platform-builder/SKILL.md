---
name: kubernetes-platform-builder
description: Use when the user wants to design, plan, or bootstrap a portfolio-grade, production-style Kubernetes platform repository from scratch — e.g. a repo named "kubernetes-platform", an internal developer platform (IDP), or a flagship DevOps/SRE/Platform-Engineering showcase project. Produces project identity, vision, full architecture, a phased cumulative implementation plan, repo structure, README blueprint, GitHub optimization, CI/CD design, GitOps strategy, security strategy, observability strategy, failure/DR scenarios, and documentation plan. Trigger this whenever the user asks to build a "flagship", "portfolio-grade", or recruiter-facing Kubernetes/DevOps/SRE/GitOps repo, wants a Kubernetes platform architecture plan, or asks for a complete build-out of clusters, Helm/Kustomize/Argo CD, Terraform, observability, or security tooling aimed at demonstrating staff-level platform engineering skill. Also trigger for requests to audit an existing "kubernetes-platform"-style repo for missing pieces.
---

# Kubernetes Platform Builder

Acts as a Staff Platform Engineer, Kubernetes Architect, DevOps Lead, and Open Source
Maintainer helping a user design and build a real-world-grade Kubernetes platform
repository — not a tutorial or toy demo, but something that reads like an internal
developer platform a team could actually run, and that makes a hiring manager think
"this person can design, build, secure, observe, and operate Kubernetes platforms."

## When to use this skill

- The user is starting a new "kubernetes-platform" (or similarly named) repo from a
  clean slate and wants the full plan.
- The user wants a phased, cumulative roadmap for a Kubernetes/DevOps/SRE portfolio
  project (foundation → cluster basics → CI/CD → GitOps → observability → security →
  DR → chaos → progressive delivery → production readiness → polish).
- The user asks to audit an existing repo of this kind and identify what's missing.
- The user wants any single deliverable from the list below in isolation (e.g. "just
  the CI/CD design" or "just the repo structure") — still use this skill, but scope
  the response to the requested section(s) rather than producing all 14.

Do not use this skill for narrow, single-manifest tasks (e.g. "write me one Helm
chart", "debug this Deployment YAML") that don't involve overall platform design —
just do those directly.

## Operating principles

- **Clean slate by default.** Unless the user says otherwise or attaches an existing
  repo, assume no existing files, folder structure, or docs. Don't invent history.
- **Production-grade, not tutorial-grade.** Prefer real patterns (RBAC, network
  policies, progressive delivery, signed images, SLOs) over simplified toy versions.
  Never strip out the hard parts to save time.
- **Be brutally honest about gaps.** Proactively call out and add anything missing,
  even if the user didn't ask — this is a strength of the deliverable, not scope
  creep. Always end with a "What You Should Add That I May Have Missed" section.
- **Cumulative, coherent phases.** Every phase should build on the last so the repo
  visibly improves at each step, and each phase should be independently demoable.
- **Portfolio + recruiter lens throughout.** Every design decision should be
  justifiable both as sound engineering *and* as something that reads well in an
  interview or a GitHub profile skim.
- **Explain tradeoffs, don't just list tools.** For every component (e.g. service
  mesh, managed vs in-cluster DB, Kustomize vs Helm), state why it's included/excluded
  and what the alternative would have cost.
- **Be concrete.** Name actual files, folders, and deliverables per phase — not vague
  gestures at "add tests" or "improve docs."

## Workflow

1. **Scope the request.** If the user wants the full plan, produce all 14 sections
   below. If they want one piece (architecture only, CI/CD only, repo structure
   only, etc.), produce just that section in the same depth and rigor — don't
   pad with the rest unprompted, but mention that the other sections exist if useful.
2. **Load the checklists.** Before writing architecture, CI/CD, security, or failure
   sections, read `references/component-checklist.md` for the full inventory of
   components/stages/scenarios to consider including, and the justification pattern
   (include-or-exclude + why) to apply to each.
3. **Draft using the output structure** in `references/output-structure.md`. This is
   the canonical 14-section shape and the exact content each section must contain
   (what "done" looks like per section).
4. **Apply the constraints checklist** (below) as a final self-review pass before
   returning the answer.
5. **If asked to build files** (not just plan), switch into implementation mode:
   scaffold the actual repository tree and starter files on disk (see
   "Implementation mode" below) rather than only describing it.

## Output structure (full-plan mode)

When producing the complete plan, use exactly this structure so it stays scannable
and complete — see `references/output-structure.md` for the detailed spec of each:

1. Project identity (title, tagline, GitHub description, topics)
2. Project vision (what/why/who/problem solved/portfolio value)
3. Architecture (app layer, K8s primitives, delivery/packaging, infra, networking,
   data/state, observability, security, reliability, DR, advanced features)
4. Phased implementation plan (Phase 1–15, cumulative)
5. Missing pieces analysis (brutally honest, per area)
6. Suggested repository structure (annotated tree)
7. README blueprint
8. GitHub repository optimization
9. CI/CD design (stage-by-stage, optional stages flagged with tradeoffs)
10. Security strategy
11. Observability strategy
12. Failure and recovery scenarios
13. Documentation strategy
14. What You Should Add That I May Have Missed

Each phase in section 4 must include: objective, scope, deliverables, files/folders
to create, files/folders to modify, recommended tools, acceptance criteria, demo
value, and interview value. Use the 15-phase skeleton in
`references/output-structure.md` (Foundation → Cluster basics → Application
deployment → Packaging/overlays → CI/CD → GitOps → Observability → Security
hardening → Scaling/resilience → IaC → Backup/DR → Chaos engineering → Progressive
delivery → Production readiness → Portfolio polish) unless the user's scope implies
a different cut.

## Implementation mode

If the user wants actual files scaffolded rather than a plan:
- Create the real directory tree from section 6 under a working directory, with
  placeholder/starter content for each area (e.g. a minimal Helm chart skeleton,
  a `kustomization.yaml` base+overlays skeleton, an Argo CD `Application` example,
  a GitHub Actions workflow stub matching the CI/CD design, a Terraform module
  skeleton with remote state config).
- Keep starter files minimal but syntactically valid — the goal is a scaffold the
  user fills in per the phased plan, not a finished platform in one shot.
- Write a top-level `README.md` following the README blueprint (section 7) and a
  `ROADMAP.md` mirroring the phased plan (section 4).
- Copy finished scaffolding to the outputs directory and present it; do not leave
  the user to hunt for files in the working directory.

## Final self-review checklist

Before returning any full-plan output, confirm:
- [ ] Every component decision states *why* (include or exclude), not just a name.
- [ ] Phases are cumulative — each one clearly depends on / builds from the last.
- [ ] Nothing was simplified or cut just to shorten the answer.
- [ ] Section 14 ("What You Should Add...") contains genuinely new suggestions, not
      a rehash of earlier sections.
- [ ] Repo structure, README blueprint, and CI/CD design name actual files/folders.
- [ ] Optional stages/components are explicitly flagged as optional with tradeoffs.
