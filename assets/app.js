/* =========================================================================
   kubernetes-platform — site behaviour
   Vanilla JS, no dependencies. Data-driven so the roadmap stays one source.
   ========================================================================= */
(function () {
  'use strict';

  var $  = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  var esc = function (s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  };

  /* ===================== DATA ===================== */

  var ARCH = [
    {
      label: 'Source', sub: 'Phase 3',
      title: 'Application layer', accent: 'var(--cyan)', phase: 'Phase 3',
      nodes: ['frontend', 'api', 'worker', 'cronjob', 'loadgen', 'PostgreSQL', 'Redis']
    },
    {
      flow: 'git push → pull request'
    },
    {
      label: 'Build', sub: 'Phase 5',
      title: 'CI/CD — GitHub Actions', accent: 'var(--violet)', phase: 'Phase 5',
      nodes: ['lint', 'unit tests', 'kubeconform', 'helm lint', 'buildx', 'Trivy', 'Syft SBOM', 'Cosign sign']
    },
    {
      flow: 'signed image digest → overlay commit'
    },
    {
      label: 'Deliver', sub: 'Phase 4 · 6',
      title: 'Packaging & GitOps', accent: 'var(--k8s)', phase: 'Phase 4 · 6',
      nodes: ['Helm charts', 'Kustomize overlays', 'dev / staging / prod', 'Argo CD', 'ApplicationSets', 'sync waves']
    },
    {
      flow: 'reconcile — git is the only way in'
    },
    {
      label: 'Runtime', sub: 'Phase 1 · 2',
      title: 'Cluster, guardrails & networking', accent: 'var(--green)', phase: 'Phase 1 · 2',
      nodes: [
        { n: 'kind — 3 nodes', live: true },
        { n: 'namespaces ×4', live: true },
        { n: 'RBAC personas', live: true },
        { n: 'ResourceQuota', live: true },
        { n: 'LimitRange', live: true },
        { n: 'ingress-nginx', live: true },
        { n: 'cert-manager', live: true },
        { n: 'metrics-server', live: true }
      ]
    },
    {
      label: 'Observe', sub: 'Phase 7',
      title: 'Observability', accent: 'var(--cyan)', phase: 'Phase 7',
      nodes: ['Prometheus', 'Grafana', 'Alertmanager', 'Loki', 'Fluent Bit', 'OpenTelemetry', 'Tempo']
    },
    {
      label: 'Secure', sub: 'Phase 8',
      title: 'Security & policy', accent: 'var(--rose)', phase: 'Phase 8',
      nodes: ['Pod Security Admission', 'Kyverno', 'NetworkPolicy default-deny', 'External Secrets', 'Cosign verify']
    },
    {
      label: 'Survive', sub: 'Phase 9–13',
      title: 'Resilience, DR & delivery safety', accent: 'var(--amber)', phase: 'Phase 9–13',
      nodes: ['HPA', 'PodDisruptionBudget', 'Velero', 'pg_dump CronJob', 'Chaos Mesh', 'Argo Rollouts', 'SLO burn-rate alerts']
    },
    {
      label: 'Foundation', sub: 'Phase 1 · 10',
      title: 'Infrastructure', accent: 'var(--k8s)', phase: 'Phase 1 · 10',
      nodes: [
        { n: 'kind (local, today)', live: true },
        { n: 'Terraform modules' }, { n: 'remote state' }, { n: 'managed cluster' }, { n: 'cloud provider — deferred' }
      ]
    }
  ];

  var STACK = [
    { layer: 'Local cluster', name: 'kind', st: 'done', ph: 1, d: '1 control-plane + 2 workers. Upstream Kubernetes via kubeadm — no distribution defaults to explain away.' },
    { layer: 'Namespaces & quotas', name: 'ResourceQuota + LimitRange', st: 'done', ph: 2, d: 'Per-environment caps sized so a rejection is demonstrable, with defaults so ordinary work is not blocked.' },
    { layer: 'Access control', name: 'RBAC personas', st: 'done', ph: 2, d: 'One identity per persona bound across namespaces. Cluster-wide visibility, namespace-scoped authority. No cluster-admin anywhere.' },
    { layer: 'Metrics (basic)', name: 'metrics-server', st: 'done', ph: 2, d: 'Resource metrics for kubectl top, and the input HPA needs from Phase 9.' },
    { layer: 'Packaging', name: 'Helm', st: 'todo', ph: 4, d: 'Reusable, parameterised charts. Used where the difference is which service, not which environment.' },
    { layer: 'Environments', name: 'Kustomize', st: 'todo', ph: 4, d: 'Overlays for dev/staging/prod. No templating language — patches stay declarative and diffable.' },
    { layer: 'GitOps', name: 'Argo CD', st: 'todo', ph: 6, d: 'App-of-apps plus ApplicationSets. Git is the audit trail; drift is detected everywhere.' },
    { layer: 'CI/CD', name: 'GitHub Actions', st: 'todo', ph: 5, d: 'Lint, test, build, scan, SBOM, sign, push. Actions pinned by commit SHA, not tag.' },
    { layer: 'Supply chain', name: 'Trivy · Syft · Cosign', st: 'todo', ph: 5, d: 'Scanning, SBOMs and keyless signing — with admission-time verification, since signing alone is theatre.' },
    { layer: 'Networking', name: 'ingress-nginx', st: 'done', ph: 2, d: 'Chosen deliberately rather than inherited, and reachable at localhost via mapped host ports.' },
    { layer: 'TLS', name: 'cert-manager', st: 'done', ph: 2, d: 'Automated certificate issuance and renewal. Expiry is a documented failure mode with a runbook.' },
    { layer: 'Metrics', name: 'Prometheus + Grafana', st: 'todo', ph: 7, d: 'Recording rules for RED metrics. Alerts are symptom-based; every one carries a runbook_url.' },
    { layer: 'Logs', name: 'Loki + Fluent Bit', st: 'todo', ph: 7, d: 'Label-indexed, not full-text — cheaper, and shares Grafana with metrics. Low cardinality enforced.' },
    { layer: 'Traces', name: 'OpenTelemetry + Tempo', st: 'todo', ph: 7, d: 'Gateway collector with tail-based sampling, so errors and slow requests are kept rather than sampled away.' },
    { layer: 'Policy', name: 'Kyverno', st: 'todo', ph: 8, d: 'Policies as Kubernetes YAML, not Rego. Every policy ships in Audit mode before it enforces.' },
    { layer: 'Secrets', name: 'External Secrets', st: 'todo', ph: 8, d: 'Cloud secret manager as source of truth. Kubernetes Secrets are base64, not encryption.' },
    { layer: 'Cloud infra', name: 'Terraform', st: 'todo', ph: 10, d: 'Modules, remote state, per-env directories. Provider deliberately deferred until requirements are known.' },
    { layer: 'Backup / DR', name: 'Velero', st: 'todo', ph: 11, d: 'Scheduled backups plus independent pg_dump. Restore drills that actually run, with measured RTO.' },
    { layer: 'Chaos', name: 'Chaos Mesh', st: 'todo', ph: 12, d: 'Hypothesis-driven fault injection with bounded blast radius. Failures are the valuable output.' },
    { layer: 'Progressive delivery', name: 'Argo Rollouts', st: 'todo', ph: 13, d: 'Canary with automated analysis against real Prometheus metrics — a bad release aborts itself.' },
    { layer: 'Runtime security', name: 'Falco', st: 'todo', ph: 14, d: 'Deferred on purpose: untuned runtime alerts train people to ignore alerts.' }
  ];

  var PHASES = [
    { n: 1, name: 'Foundation', st: 'done',
      obj: 'A repo you can clone and get a working multi-node cluster from, in one command.',
      del: ['Full directory tree, each folder documented with what belongs in it',
            'MIT licence, contributing guide, code of conduct, security policy',
            'ADR process plus the first two decisions recorded',
            'Idempotent, guarded cluster bootstrap and teardown behind a Makefile',
            'Local development guide with a real troubleshooting section'],
      tools: ['kind', 'kubectl', 'Docker', 'make', 'bash', 'shellcheck'],
      ac: [['make preflight reports toolchain state and fails clearly', 1],
           ['make up creates 1 control-plane + 2 workers and waits for genuine readiness', 1],
           ['make up is idempotent and refuses success on a half-built cluster', 1],
           ['make status exits 0 when healthy, non-zero when degraded', 1],
           ['Teardown is name-scoped and cannot touch a non-kind cluster', 1],
           ['make lint-shell clean; make verify passes end to end', 1]],
      demo: 'git clone && make up — a three-node cluster in under three minutes.',
      iv: 'Decision discipline. ADR-0001 is a written defence of a tool choice with its costs stated.' },

    { n: 2, name: 'Cluster basics', st: 'progress',
      obj: 'Turn an empty cluster into a multi-tenant-shaped platform with guardrails — before any application exists to bend them.',
      del: ['Four namespaces: platform-system, dev, staging, prod, with ownership labels',
            'ResourceQuota + LimitRange per workload namespace; platform-system deliberately unquotaed',
            'Two personas — one ServiceAccount each, bound across namespaces with different Roles',
            'ingress-nginx, metrics-server and cert-manager at pinned chart versions',
            'Three examples: a compliant workload, a refused one, and the full RBAC matrix',
            'verify-platform.sh — 40 assertions that try to break the guardrails'],
      tools: ['kubectl', 'Kustomize', 'Helm', 'ingress-nginx 4.15.1', 'metrics-server 3.13.1', 'cert-manager v1.21.1'],
      ac: [['Every workload namespace has a quota and a limit range', 1],
           ['platform-system has no quota, so a tenant cannot starve ingress', 1],
           ['A 3 CPU container is refused, reporting all violations at once', 1],
           ['A pod declaring no resources is still admitted, via LimitRange defaults', 1],
           ['developer cannot create secrets, edit RBAC, or raise its own quota', 1],
           ['Production is read-only for humans; exec is dev-only', 1],
           ['CI writes to dev and nowhere else — no secrets, delete or exec', 1],
           ['Nothing in the repo binds cluster-admin', 1],
           ['hello-workload returns HTTP 200 with replicas across both workers', 1],
           ['make apply-base and make addons refuse a non-kind context', 1],
           ['make verify-platform passes 40/40 deterministically', 1]],
      demo: 'Try to deploy something oversized and watch the cluster refuse it, with the reason.',
      iv: 'Multi-tenancy, least privilege and capacity governance — the questions that separate deploying to Kubernetes from running a cluster others deploy to.' },

    { n: 3, name: 'Application deployment', st: 'todo',
      obj: 'Real workloads running, deployed by hand, so Phase 4’s abstractions solve problems actually felt.',
      del: ['frontend, api, worker and cronjob with non-root multi-stage Dockerfiles',
            'Deployments, Services, Ingress, ConfigMaps and Secret references',
            'PostgreSQL and Redis, with the managed-vs-in-cluster tradeoff written down',
            'Distinct liveness/readiness/startup probes — not copy-pasted',
            'The first runbook: pod-crashloop.md'],
      tools: ['Docker Buildx', 'kubectl', 'PostgreSQL', 'Redis'],
      ac: [['Full request path works: browser → ingress → frontend → api → datastore', 0],
           ['A pod killed by hand is replaced with no failed requests', 0],
           ['Every container is non-root with a read-only root filesystem', 0],
           ['One image runs in every environment — all config injected', 0]],
      demo: 'A working application on your own platform.',
      iv: 'Probe semantics and graceful shutdown — where most candidates get vague.' },

    { n: 4, name: 'Packaging & overlays', st: 'todo',
      obj: 'Stop copy-pasting YAML. Introduce Helm and Kustomize, each where it earns its place.',
      del: ['helm/web-service with values.schema.json and secure defaults',
            'dev/staging/prod overlays differing only in permitted dimensions',
            'ADR recording the Helm/Kustomize division of labour',
            'kubeconform validation of every rendered overlay'],
      tools: ['Helm', 'Kustomize', 'kubeconform', 'helm-docs'],
      ac: [['kustomize build succeeds and validates for all three environments', 0],
           ['Environments differ in config, never in resource shape', 0],
           ['helm lint clean; the schema rejects an invalid values file', 0],
           ['No YAML duplicated between environments', 0]],
      demo: 'One base, three environments, a readable diff between them.',
      iv: '“Helm or Kustomize?” is a trap question. A written boundary beats a preference.' },

    { n: 5, name: 'CI/CD', st: 'todo',
      obj: 'Nothing reaches a registry that has not been linted, tested, scanned and signed.',
      del: ['ci.yaml — format → lint → test → build → scan → SBOM → sign → push',
            'manifests.yaml — kubeconform, helm lint, kustomize build',
            'Multi-arch images to GHCR, tagged by digest',
            'Trivy blocking only on fixable Critical/High, so the gate stays actionable',
            'Optional kind-in-CI integration gate'],
      tools: ['GitHub Actions', 'Buildx', 'Trivy', 'Syft', 'Cosign', 'kubeconform'],
      ac: [['A PR that breaks a manifest fails before merge', 0],
           ['Images are signed and cosign verify succeeds', 0],
           ['Every action pinned by commit SHA; least-privilege GITHUB_TOKEN', 0],
           ['Pipeline finishes in under 10 minutes', 0]],
      demo: 'A green pipeline with a signature-verification step in it.',
      iv: 'Supply-chain security — the highest-signal CI topic right now.' },

    { n: 6, name: 'GitOps', st: 'todo',
      obj: 'Git becomes the only way anything reaches the cluster.',
      del: ['Argo CD with AppProject restrictions on repos, namespaces and kinds',
            'App-of-apps root Application — the single manual bootstrap step',
            'ApplicationSets fanning out over the Phase 4 overlays',
            'Sync waves ordering CRDs and namespaces ahead of workloads',
            'Automated rollback on failed sync'],
      tools: ['Argo CD', 'ApplicationSets', 'Kustomize'],
      ac: [['A bare cluster reaches full platform state from one kubectl apply', 0],
           ['A manual kubectl edit is reverted by self-heal, visibly', 0],
           ['Adding an environment needs a directory and a generator entry', 0],
           ['No AppProject permits wildcard destinations or resources', 0]],
      demo: 'Change a value in Git and watch it land. Then break it by hand and watch it heal.',
      iv: 'Drift handling and “who may sync what” — where GitOps talk gets real.' },

    { n: 7, name: 'Observability', st: 'todo',
      obj: 'Answer “is it working, and if not where is it broken?” from data rather than intuition.',
      del: ['kube-prometheus-stack with RED recording rules per service',
            'Loki + Fluent Bit, structured JSON logs carrying trace_id',
            'OpenTelemetry gateway collector with tail-based sampling, Tempo backend',
            'Grafana dashboards provisioned as code',
            'Alertmanager routing with inhibition, grouping and runbook_url'],
      tools: ['Prometheus', 'Grafana', 'Alertmanager', 'Loki', 'Fluent Bit', 'OpenTelemetry', 'Tempo'],
      ac: [['Metrics → logs → traces navigation works in three clicks', 0],
           ['Every alert has a runbook link, and every runbook is reachable from an alert', 0],
           ['No alert fires on a healthy idle cluster', 0],
           ['A killed dependency produces one symptom alert, not twelve cause alerts', 0]],
      demo: 'The screenshots that carry the whole README.',
      iv: 'Symptom-vs-cause alerting and cardinality discipline — opinions you only hold from operating.' },

    { n: 8, name: 'Security hardening', st: 'todo',
      obj: 'Make insecure configuration impossible to deploy, not merely discouraged.',
      del: ['Pod Security Admission at restricted where possible',
            'Kyverno: required limits/probes/labels, no :latest, signature verification',
            'Default-deny ingress AND egress NetworkPolicies',
            'External Secrets Operator replacing every committed Secret',
            'Policy tests with must-block and must-allow fixtures'],
      tools: ['Kyverno', 'External Secrets Operator', 'Trivy', 'Cosign', 'PSA'],
      ac: [['Verify the CNI actually enforces NetworkPolicy before claiming segmentation', 0],
           ['A manifest without resource limits is rejected at admission', 0],
           ['An unsigned image is refused', 0],
           ['No Secret manifests remain in Git; rotation needs no redeploy', 0],
           ['Every policy shipped in Audit mode first, violations reviewed', 0]],
      demo: 'Try to deploy something bad. Watch it get refused.',
      iv: 'Defence in depth, and Audit-before-Enforce — the mark of someone who has actually rolled out policy.' },

    { n: 9, name: 'Scaling & resilience', st: 'todo',
      obj: 'Behave correctly under load and during disruption.',
      del: ['HPAs tuned on real load-test data, not guessed thresholds',
            'PodDisruptionBudgets and topology spread across both workers',
            'loadgen service and a k6 load-test script',
            'Documented capacity findings — where it saturates and what breaks first',
            'Runbooks for node failure, DB/Redis outage, high CPU and memory'],
      tools: ['HPA', 'metrics-server', 'PodDisruptionBudget', 'k6'],
      ac: [['Load drives a scale-up and p99 stays inside target throughout', 0],
           ['kubectl drain respects PDBs and causes no downtime', 0],
           ['Anti-affinity provably spreads replicas across both workers', 0],
           ['A capacity limit is documented with a number, not an adjective', 0]],
      demo: 'Grafana during a load test — replicas climbing, latency flat.',
      iv: 'Tuned-from-data beats tuned-from-defaults. “What breaks first?” needs real experience.' },

    { n: 10, name: 'Infrastructure as Code', st: 'todo',
      obj: 'Move to a real managed cluster and prove the platform above the cluster boundary was portable.',
      del: ['ADR selecting the cloud provider, and one on managed vs in-cluster Postgres',
            'Terraform modules: network, cluster, dns, iam, secrets',
            'Per-environment directories, not workspaces',
            'Remote state backend created out-of-band',
            'terraform plan posted as a PR comment; apply gated on merge'],
      tools: ['Terraform', 'chosen cloud provider', 'cert-manager DNS-01'],
      ac: [['terraform apply from nothing produces a working cluster', 0],
           ['The same Argo CD bootstrap that works on kind works on the managed cluster', 0],
           ['Remote state is versioned and locked; never local', 0],
           ['terraform destroy leaves nothing behind — verified, because cloud bills', 0]],
      demo: 'The whole thing, from zero, in two commands.',
      iv: 'Where the portability claim from ADR-0002 gets tested in public.' },

    { n: 11, name: 'Backups & DR', st: 'todo',
      obj: 'Lose things and get them back, with a measured recovery time rather than a hoped-for one.',
      del: ['Velero with object-storage location and CSI volume snapshots',
            'Backup schedules with deliberate retention per data class',
            'An independent pg_dump CronJob — snapshots do not survive a bad migration',
            'restore-drill.sh that runs, times and records a restore',
            'Documented and measured RTO/RPO per scenario'],
      tools: ['Velero', 'CSI snapshots', 'object storage'],
      ac: [['A deleted namespace is restored and verified by querying the data', 0],
           ['Restores go to a separate namespace first — a drill never overwrites the source', 0],
           ['Measured RTO recorded and compared against target', 0],
           ['A failed backup pages', 0],
           ['At least one drill recorded, including what went wrong first time', 0]],
      demo: 'Delete something important on camera. Get it back. State the elapsed time.',
      iv: 'The most commonly skipped area in portfolio repos, and the most asked about at senior level.' },

    { n: 12, name: 'Chaos engineering', st: 'todo',
      obj: 'Test the resilience claims made in Phases 7–11 instead of asserting them.',
      del: ['ADR selecting Chaos Mesh or Litmus',
            'Steady-state hypotheses as Prometheus queries, committed before experiments run',
            'Experiments: pod-kill, CPU/memory stress, network delay, partition, node drain, DNS chaos',
            'Recorded results — especially the failures',
            'chaos-run.sh: steady state → inject → observe → report'],
      tools: ['Chaos Mesh or Litmus', 'Prometheus', 'k6'],
      ac: [['Every experiment has a written hypothesis and abort criteria before it runs', 0],
           ['Blast radius bounded by namespace and label selector', 0],
           ['At least one experiment falsifies an assumption, and the fix is documented', 0],
           ['Every runbook exercised gets its “last validated” date updated', 0]],
      demo: 'Kill a node during a load test and show the SLO holding.',
      iv: '“What surprised you?” — having a real answer is the entire point.' },

    { n: 13, name: 'Progressive delivery', st: 'todo',
      obj: 'Make a bad release stop itself before it becomes an incident.',
      del: ['Argo Rollouts replacing Deployments for user-facing services',
            'Canary strategy with weighted steps and analysis at each gate',
            'AnalysisTemplates querying Prometheus for error rate and latency',
            'Automatic abort and rollback on failed analysis',
            'ADR on why no service mesh, and what that costs'],
      tools: ['Argo Rollouts', 'Prometheus', 'ingress-nginx traffic splitting'],
      ac: [['A canary with a deliberately broken build aborts automatically', 0],
           ['Analysis queries real Prometheus metrics, not a timer', 0],
           ['Argo CD reports Rollout health correctly mid-canary', 0],
           ['The no-service-mesh decision is written down with its tradeoff', 0]],
      demo: 'Deploy something broken on purpose. Watch the platform refuse it, with no human involved.',
      iv: 'Safe-release mechanics, plus the judgement to exclude a mesh and say why.' },

    { n: 14, name: 'Production readiness', st: 'todo',
      obj: 'Operate it, not just run it.',
      del: ['SLIs and SLOs per service with explicit error budgets',
            'Multi-window multi-burn-rate alerts — fast burn pages, slow burn tickets',
            'Alert tuning pass: delete everything that fired without being actionable',
            'Falco for runtime security, deferred to here on purpose',
            'OpenCost for cost visibility; on-call guide and incident template'],
      tools: ['Prometheus', 'Falco', 'OpenCost', 'Alertmanager'],
      ac: [['Every user-facing service has an SLO with a stated error budget', 0],
           ['Burn-rate alerts fire at the right speed for the right severity', 0],
           ['Every remaining alert has fired in testing and was actionable', 0],
           ['Cost per namespace is visible', 0]],
      demo: 'An error-budget dashboard with a burn-rate alert firing during a chaos experiment.',
      iv: 'SLO thinking is the clearest marker of SRE maturity. “Which alerts did you delete?” is the better question.' },

    { n: 15, name: 'Portfolio polish', st: 'todo',
      obj: 'Make the work legible in the 90 seconds a reviewer actually spends.',
      del: ['Architecture diagram with data flow arrows as the hero image',
            'Screenshots and GIFs: Grafana under load, an Argo CD sync, a canary aborting',
            'README rewritten now that everything exists',
            'demo.sh — a scripted end-to-end walkthrough for live interviews',
            'Semantic release tags, generated changelog, known-limitations doc'],
      tools: ['Mermaid / D2', 'asciinema', 'release-please'],
      ac: [['The README communicates what this is above the fold', 0],
           ['Every major capability has a visual', 0],
           ['demo.sh runs the whole story with no manual steps', 0],
           ['known-limitations.md is honest, including what only runs locally', 0]],
      demo: 'The repository sells itself without you in the room.',
      iv: 'Communication. A platform nobody understands in 90 seconds never gets discussed.' }
  ];

  var TREE = [
    ['apps/',            'sample services that exercise the platform', 3],
    ['argocd/',          'Application, ApplicationSet, AppProject manifests', 6],
    ['backup/',          'Velero schedules, restore drills', 11],
    ['chaos/',           'experiments, steady-state hypotheses, results', 12],
    ['diagrams/',        'diagram sources + exports', 15],
    ['docs/',            'architecture, guides, decision records', 1, true],
    ['examples/',        'small workloads proving one capability each', 2],
    ['helm/',            'first-party charts', 4],
    ['infra/kind/',      'local cluster topology', 1, true],
    ['infra/terraform/', 'cloud infrastructure — provider deferred', 10],
    ['k8s/base/',        'raw manifests / Kustomize base', 2],
    ['kustomize/',       'dev / staging / prod overlays', 4],
    ['logging/',         'Loki, Fluent Bit', 7],
    ['monitoring/',      'Prometheus, Grafana, Alertmanager', 7],
    ['runbooks/',        'one per failure scenario', 3],
    ['scripts/',         'bootstrap, teardown, drills', 1, true],
    ['security/',        'Kyverno, NetworkPolicies, PSA', 8],
    ['tests/',           'manifest, policy, integration, smoke', 4],
    ['tracing/',         'OpenTelemetry, Tempo', 7]
  ];

  var ADRS = [
    { n: 'ADR-0001', t: 'kind over k3d for the local cluster',
      p: 'kind runs upstream Kubernetes via kubeadm — the same tool that bootstraps real clusters. k3s is excellent but opinionated: Traefik, servicelb, SQLite and a bundled metrics-server. For a platform whose value is choosing and defending its own components, inheriting someone else’s defaults is backwards.',
      c: 'Roughly 3× slower to start and ~3 GB more RAM than k3d, and LoadBalancer Services never resolve — handled with mapped host ports.',
      u: 'https://github.com/sameeralam3127/kubernetes-platform/blob/main/docs/decisions/0001-local-cluster-kind-over-k3d.md' },
    { n: 'ADR-0002', t: 'Defer the cloud provider to Phase 10',
      p: 'Phases 1–9 need no cloud, and what the infrastructure must provide is decided by choices not yet made — ingress type, storage class, workload identity. Writing Terraform now means guessing, then rewriting.',
      c: 'infra/terraform/ reads as empty for nine phases, and a few decisions may need revisiting once a provider is chosen.',
      u: 'https://github.com/sameeralam3127/kubernetes-platform/blob/main/docs/decisions/0002-defer-cloud-provider-choice.md' }
  ];

  var EXCL = [
    { t: 'Service mesh (Istio / Linkerd)', d: 'Real operational overhead, and Ingress plus Argo Rollouts already cover the traffic shaping this platform needs. mTLS between services is the one genuine gap — called out in the Phase 13 ADR rather than papered over.' },
    { t: 'Multi-cloud', d: 'Spreads effort across three providers instead of demonstrating depth on one. Portability is a design goal expressed through module boundaries, not a live requirement.' },
    { t: 'Multi-cluster', d: 'A good narrative, expensive to actually run. Documented as target architecture; the ApplicationSet patterns in Phase 6 are the honest cheap demonstration of the shape.' },
    { t: 'A rich sample application', d: 'The apps exist to stress the platform. Any feature that does not exercise a platform capability distracts from the thing being demonstrated.' }
  ];

  /* ===================== RENDER ===================== */

  function renderArch() {
    var el = $('#arch'); if (!el) return;
    el.innerHTML = ARCH.map(function (r) {
      if (r.flow) {
        return '<div class="flow"><div class="flow-line"><span class="pip"></span>' + esc(r.flow) + '</div></div>';
      }
      var nodes = r.nodes.map(function (n) {
        var name = typeof n === 'string' ? n : n.n;
        var live = typeof n === 'object' && n.live;
        return '<span class="node' + (live ? ' live' : '') + '">' + esc(name) + '</span>';
      }).join('');
      var isLive = r.phase.indexOf('Phase 1') === 0;
      return '' +
        '<div class="arch-row">' +
          '<div class="arch-label"><b>' + esc(r.label) + '</b>' + esc(r.sub) + '</div>' +
          '<div class="layer" style="--accent:' + r.accent + '">' +
            '<div class="layer-head">' +
              '<span class="layer-title"><i class="bar"></i>' + esc(r.title) + '</span>' +
              '<span class="ph-tag' + (isLive ? ' on' : '') + '">' + esc(r.phase) + '</span>' +
            '</div>' +
            '<div class="nodes">' + nodes + '</div>' +
          '</div>' +
        '</div>';
    }).join('');
  }

  function renderStack(filter) {
    var grid = $('#stackGrid'); if (!grid) return;
    grid.innerHTML = STACK.map(function (s) {
      var hide = filter && filter !== 'all' && s.st !== filter;
      var label = s.st === 'done' ? 'Live' : 'Phase ' + s.ph;
      return '' +
        '<article class="sc' + (hide ? ' hidden' : '') + '" data-st="' + s.st + '">' +
          '<div class="sc-top">' +
            '<span class="sc-layer">' + esc(s.layer) + '</span>' +
            '<span class="st ' + s.st + '">' + esc(label) + '</span>' +
          '</div>' +
          '<h3>' + esc(s.name) + '</h3>' +
          '<p>' + esc(s.d) + '</p>' +
        '</article>';
    }).join('');
  }

  function renderPhases(filter) {
    var tl = $('#timeline'); if (!tl) return;
    tl.innerHTML = PHASES.map(function (p) {
      var hide = filter && filter !== 'all' && p.st !== filter;
      var label = p.st === 'done' ? 'Complete' : p.st === 'progress' ? 'In progress' : 'Not started';
      var id = 'ph-' + p.n;
      return '' +
      '<div class="phase' + (hide ? ' hidden' : '') + '" data-status="' + p.st + '">' +
        '<button class="phase-btn" aria-expanded="false" aria-controls="' + id + '">' +
          '<span class="phase-n">' + (p.n < 10 ? '0' : '') + p.n + '</span>' +
          '<span class="phase-name">' + esc(p.name) +
            '<span class="phase-obj">' + esc(p.obj) + '</span>' +
          '</span>' +
          '<span class="st ' + p.st + '">' + label + '</span>' +
          '<svg class="chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>' +
        '</button>' +
        '<div class="phase-body" id="' + id + '">' +
          '<h4>Deliverables</h4><ul>' + p.del.map(function (d) { return '<li>' + esc(d) + '</li>'; }).join('') + '</ul>' +
          '<h4>Acceptance criteria</h4><ul class="ac">' + p.ac.map(function (a) {
            return '<li class="' + (a[1] ? 'pass' : '') + '">' + esc(a[0]) + '</li>';
          }).join('') + '</ul>' +
          '<h4>Tools</h4><div class="tools">' + p.tools.map(function (t) { return '<span class="tool">' + esc(t) + '</span>'; }).join('') + '</div>' +
          '<h4>Demo value</h4><ul><li>' + esc(p.demo) + '</li></ul>' +
          '<h4>Interview value</h4><ul><li>' + esc(p.iv) + '</li></ul>' +
        '</div>' +
      '</div>';
    }).join('');

    $$('.phase-btn', tl).forEach(function (btn) {
      btn.addEventListener('click', function () {
        var open = btn.getAttribute('aria-expanded') === 'true';
        btn.setAttribute('aria-expanded', String(!open));
        var body = document.getElementById(btn.getAttribute('aria-controls'));
        if (body) body.classList.toggle('open', !open);
      });
    });
  }

  function renderTree() {
    var el = $('#tree'); if (!el) return;
    var rows = TREE.map(function (t, i) {
      var last = i === TREE.length - 1;
      var pad = t[0] + ' '.repeat(Math.max(1, 18 - t[0].length));
      var live = t[3];
      return '<span class="row">' + (last ? '└── ' : '├── ') +
        '<span class="d">' + esc(pad) + '</span>' +
        '<span class="note">' + esc(t[1]) + '</span>' +
        (live ? '<span class="live">  ← works today</span>' : '') +
        '</span>';
    }).join('');
    el.innerHTML = '<span class="row"><span class="d">kubernetes-platform/</span></span>' + rows;
  }

  function renderAdrs() {
    var el = $('#adrs'); if (!el) return;
    el.innerHTML = ADRS.map(function (a) {
      return '' +
      '<article class="adr rv">' +
        '<span class="adr-n">' + esc(a.n) + ' · Accepted</span>' +
        '<h3><a href="' + esc(a.u) + '">' + esc(a.t) + '</a></h3>' +
        '<p>' + esc(a.p) + '</p>' +
        '<p class="cost"><b>What it costs:</b> ' + esc(a.c) + '</p>' +
      '</article>';
    }).join('');
  }

  function renderExcl() {
    var el = $('#excl'); if (!el) return;
    el.innerHTML = EXCL.map(function (e) {
      return '<article class="ex rv"><h3>' + esc(e.t) + '</h3><p>' + esc(e.d) + '</p></article>';
    }).join('');
  }

  function renderFilters(mount, counts, onPick) {
    var el = $(mount); if (!el) return;
    el.innerHTML = counts.map(function (c, i) {
      return '<button class="chip" data-v="' + c.v + '" aria-pressed="' + (i === 0) + '">' +
        esc(c.l) + '<span class="ct">' + c.n + '</span></button>';
    }).join('');
    $$('.chip', el).forEach(function (chip) {
      chip.addEventListener('click', function () {
        $$('.chip', el).forEach(function (c) { c.setAttribute('aria-pressed', 'false'); });
        chip.setAttribute('aria-pressed', 'true');
        onPick(chip.dataset.v);
      });
    });
  }

  /* ===================== TERMINAL ===================== */

  var TERM = [
    ['c-prompt', '$ ', 'c-cmd', 'make bootstrap'],
    ['c-dim',    ''],
    ['c-ok',     ' ok  ', 'c-dim', 'kind v0.32.0 · kubectl v1.36.1'],
    ['c-key',    '==> ', 'c-dim', 'creating cluster — 1 control-plane + 2 workers'],
    ['c-ok',     ' ok  ', 'c-dim', 'all nodes Ready · CoreDNS available'],
    ['c-key',    '==> ', 'c-dim', 'applying k8s/base to kind-kubernetes-platform'],
    ['c-ok',     ' ok  ', 'c-dim', 'namespaces · quotas · limit ranges · RBAC'],
    ['c-key',    '==> ', 'c-dim', 'installing ingress-nginx · metrics-server · cert-manager'],
    ['c-dim',    ''],
    ['c-prompt', '$ ', 'c-cmd', 'make verify-platform'],
    ['c-ok',     '  ok ', 'c-dim', 'platform-system has no ResourceQuota, by design'],
    ['c-ok',     '  ok ', 'c-dim', '3 CPU container refused in dev'],
    ['c-ok',     '  ok ', 'c-dim', 'developer raises its own quota  ', 'c-warn', 'no'],
    ['c-ok',     '  ok ', 'c-dim', 'developer writes to prod        ', 'c-warn', 'no'],
    ['c-ok',     '  ok ', 'c-dim', 'ci deploys to prod              ', 'c-warn', 'no'],
    ['c-dim',    ''],
    ['c-ok',     ' ok  ', 'c-cmd', 'passed: 40   failed: 0']
  ];


  function typeTerm() {
    var el = $('#term'); if (!el) return;
    var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function lineHtml(parts) {
      var out = '';
      for (var i = 0; i < parts.length; i += 2) {
        out += '<span class="' + parts[i] + '">' + esc(parts[i + 1] || '') + '</span>';
      }
      return '<span class="l">' + (out || '&nbsp;') + '</span>';
    }

    if (reduce) {
      el.innerHTML = TERM.map(lineHtml).join('');
      return;
    }

    var i = 0;
    (function next() {
      if (i >= TERM.length) {
        el.insertAdjacentHTML('beforeend', '<span class="l"><span class="c-prompt">$ </span><span class="cursor"></span></span>');
        return;
      }
      el.insertAdjacentHTML('beforeend', lineHtml(TERM[i]));
      el.scrollTop = el.scrollHeight;
      i++;
      setTimeout(next, i < 3 ? 340 : 190);
    })();
  }

  /* ===================== BEHAVIOUR ===================== */

  function theme() {
    var btn = $('#theme'); if (!btn) return;
    var saved = null;
    try { saved = localStorage.getItem('kp-theme'); } catch (e) {}
    if (saved) document.documentElement.setAttribute('data-theme', saved);

    btn.addEventListener('click', function () {
      var cur = document.documentElement.getAttribute('data-theme');
      if (!cur) {
        cur = window.matchMedia('(prefers-color-scheme: light)').matches ? 'light' : 'dark';
      }
      var next = cur === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', next);
      try { localStorage.setItem('kp-theme', next); } catch (e) {}
      var meta = document.querySelector('meta[name="theme-color"]');
      if (meta) meta.setAttribute('content', next === 'dark' ? '#070b14' : '#f7f9fc');
    });
  }

  function nav() {
    var n = $('#nav'), toggle = $('#navToggle'), links = $('#navLinks');
    if (n) {
      var onScroll = function () { n.classList.toggle('stuck', window.scrollY > 8); };
      window.addEventListener('scroll', onScroll, { passive: true });
      onScroll();
    }
    if (toggle && links) {
      toggle.addEventListener('click', function () {
        var open = links.classList.toggle('open');
        toggle.setAttribute('aria-expanded', String(open));
      });
      $$('a', links).forEach(function (a) {
        a.addEventListener('click', function () {
          links.classList.remove('open');
          toggle.setAttribute('aria-expanded', 'false');
        });
      });
    }

    // Scroll spy
    var secs = $$('main section[id], header.hero');
    var map = {};
    $$('#navLinks a').forEach(function (a) { map[a.getAttribute('href').slice(1)] = a; });
    if ('IntersectionObserver' in window) {
      var spy = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) {
          var a = map[e.target.id];
          if (!a) return;
          if (e.isIntersecting) {
            $$('#navLinks a').forEach(function (x) { x.classList.remove('active'); });
            a.classList.add('active');
          }
        });
      }, { rootMargin: '-45% 0px -50% 0px' });
      secs.forEach(function (s) { spy.observe(s); });
    }
  }

  function reveal() {
    var els = $$('.rv');
    if (!('IntersectionObserver' in window)) {
      els.forEach(function (e) { e.classList.add('in'); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: .06 });
    els.forEach(function (e) { io.observe(e); });
  }

  function copy() {
    $$('.copy').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var text = btn.dataset.copy || '';
        var done = function () {
          var old = btn.innerHTML;
          btn.classList.add('done');
          btn.textContent = '✓ copied';
          setTimeout(function () { btn.classList.remove('done'); btn.innerHTML = old; }, 1600);
        };
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).then(done, function () {});
        } else {
          var ta = document.createElement('textarea');
          ta.value = text; ta.style.position = 'fixed'; ta.style.opacity = '0';
          document.body.appendChild(ta); ta.select();
          try { document.execCommand('copy'); done(); } catch (e) {}
          document.body.removeChild(ta);
        }
      });
    });
  }

  function toTop() {
    var b = $('#toTop'); if (!b) return;
    window.addEventListener('scroll', function () {
      b.classList.toggle('show', window.scrollY > 640);
    }, { passive: true });
    b.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
  }

  /* ===================== INIT ===================== */

  function count(arr, v) {
    return v === 'all' ? arr.length : arr.filter(function (x) { return x.st === v; }).length;
  }

  document.addEventListener('DOMContentLoaded', function () {
    renderArch();
    renderStack('all');
    renderPhases('all');
    renderTree();
    renderAdrs();
    renderExcl();

    renderFilters('#stackFilters', [
      { v: 'all',  l: 'All',      n: count(STACK, 'all') },
      { v: 'done', l: 'Live',     n: count(STACK, 'done') },
      { v: 'todo', l: 'Planned',  n: count(STACK, 'todo') }
    ], renderStack);

    renderFilters('#phaseFilters', [
      { v: 'all',      l: 'All phases',   n: count(PHASES, 'all') },
      { v: 'progress', l: 'In progress',  n: count(PHASES, 'progress') },
      { v: 'todo',     l: 'Not started',  n: count(PHASES, 'todo') }
    ], renderPhases);

    theme(); nav(); copy(); toTop(); typeTerm(); reveal();
  });
})();
