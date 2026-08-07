#!/usr/bin/env bash
#
# verify-platform.sh — assert that the Phase 2 guardrails actually work.
#
# This is not a smoke test that things exist. It tries to do things that should
# be refused, and fails if they are permitted. A quota that has never rejected
# anything and an RBAC role that has never denied anything are both untested
# assumptions.
#
# Usage:
#   ./verify-platform.sh [--demo] [--help]
#
#   --demo   Also print the human-readable walkthrough (what an interviewer sees)
#
# Exit codes: 0 all assertions pass · 1 one or more failed
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

DEMO=0
PASS=0
FAIL=0

readonly ADDON_NS="platform-system"
readonly DEV_SA="system:serviceaccount:platform-system:developer"
readonly CI_SA="system:serviceaccount:platform-system:ci-deployer"

usage() {
  cat <<EOF
Usage: ${0##*/} [--demo] [--help]

Asserts the Phase 2 platform guardrails behave as designed:
namespaces, ResourceQuotas, LimitRanges, RBAC boundaries, and addon health.

  --demo   Print the narrated walkthrough as well as the assertions
EOF
}

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

ok()   { PASS=$(( PASS + 1 )); printf '  %s✓%s %s\n' "${C_GREEN}" "${C_RESET}" "$1"; }
bad()  { FAIL=$(( FAIL + 1 )); printf '  %s✗%s %s\n' "${C_RED}" "${C_RESET}" "$1"; }

# assert_exists <kind> <name> [namespace]
assert_exists() {
  local kind="$1" name="$2" ns="${3:-}"
  local -a args=(get "${kind}" "${name}")
  [[ -n "${ns}" ]] && args+=(-n "${ns}")
  if kubectl "${args[@]}" >/dev/null 2>&1; then
    ok "${kind}/${name}${ns:+ in ${ns}} exists"
  else
    bad "${kind}/${name}${ns:+ in ${ns}} MISSING"
  fi
}

# assert_can <expected yes|no> <description> <can-i args...>
assert_can() {
  local expect="$1" desc="$2"; shift 2
  local got
  got="$(kubectl auth can-i "$@" 2>/dev/null || true)"
  if [[ "${got}" == "${expect}" ]]; then
    ok "${desc} → ${got}"
  else
    bad "${desc} → got '${got}', expected '${expect}'"
  fi
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

check_namespaces() {
  heading "Namespaces"
  local ns
  for ns in platform-system dev staging prod; do
    assert_exists namespace "${ns}"
  done

  # Ownership labels are what make cost attribution and dashboards work later.
  for ns in dev staging prod; do
    local env
    env="$(kubectl get ns "${ns}" -o jsonpath='{.metadata.labels.platform\.local/environment}' 2>/dev/null || true)"
    if [[ "${env}" == "${ns}" ]]; then
      ok "${ns} labelled platform.local/environment=${env}"
    else
      bad "${ns} missing environment label (got '${env}')"
    fi
  done
}

check_governance() {
  heading "Quotas and limit ranges"
  local ns
  for ns in dev staging prod; do
    assert_exists resourcequota compute-quota "${ns}"
    assert_exists limitrange container-limits "${ns}"
  done

  # platform-system must NOT be quota'd: a full tenant quota must never be able
  # to stop ingress from scheduling.
  #
  # Captured into a variable rather than piped into `grep -q` — see the SIGPIPE
  # note on cluster_exists() in lib/common.sh.
  local sys_quotas
  sys_quotas="$(kubectl get resourcequota -n platform-system --no-headers 2>/dev/null || true)"
  if [[ -n "${sys_quotas}" ]]; then
    bad "platform-system has a ResourceQuota (it must not — see k8s/base/namespaces/)"
  else
    ok "platform-system has no ResourceQuota, by design"
  fi
}

# The real test: try to break the rules and confirm the cluster says no.
check_quota_enforced() {
  heading "Quota enforcement (attempting to exceed it)"

  # Exceeds the dev LimitRange per-container max of 1 CPU.
  local out
  out="$(kubectl run quota-probe-cpu --image=registry.k8s.io/pause:3.10 -n dev \
        --overrides='{"spec":{"containers":[{"name":"c","image":"registry.k8s.io/pause:3.10","resources":{"requests":{"cpu":"3"},"limits":{"cpu":"3"}}}]}}' \
        --dry-run=server 2>&1 || true)"
  if grep -qi 'maximum cpu usage per Container\|exceeded quota\|forbidden' <<<"${out}"; then
    ok "3 CPU container refused in dev"
    [[ "${DEMO}" == "1" ]] && printf '      %s\n' "$(grep -oiE '(maximum cpu[^,]*|exceeded quota[^,]*)' <<<"${out}" | head -1)"
  else
    bad "3 CPU container was NOT refused in dev"
  fi

  # A pod with no resources at all must be admitted, because the LimitRange
  # supplies defaults. If this fails, the namespace is hostile to use.
  if kubectl run quota-probe-default --image=registry.k8s.io/pause:3.10 -n dev \
       --dry-run=server >/dev/null 2>&1; then
    ok "pod with no resources admitted (LimitRange supplies defaults)"
  else
    bad "pod with no resources was refused — LimitRange defaults are not working"
  fi
}

check_rbac() {
  heading "RBAC boundaries"

  # Authority where it belongs.
  assert_can yes "developer creates deployments in dev"   --as="${DEV_SA}" create deployments.apps -n dev
  assert_can yes "developer execs into pods in dev"       --as="${DEV_SA}" create pods --subresource=exec -n dev

  # No escalation paths.
  assert_can no  "developer creates secrets"              --as="${DEV_SA}" create secrets -n dev
  assert_can no  "developer edits rolebindings"           --as="${DEV_SA}" create rolebindings.rbac.authorization.k8s.io -n dev
  assert_can no  "developer raises its own quota"         --as="${DEV_SA}" patch resourcequotas -n dev
  assert_can no  "developer creates namespaces"           --as="${DEV_SA}" create namespaces
  assert_can no  "developer deletes nodes"                --as="${DEV_SA}" delete nodes

  # Environment boundaries.
  assert_can no  "developer writes to prod"               --as="${DEV_SA}" create deployments.apps -n prod
  assert_can yes "developer reads prod"                   --as="${DEV_SA}" get deployments.apps -n prod
  assert_can no  "developer execs in prod"                --as="${DEV_SA}" create pods --subresource=exec -n prod
  assert_can no  "developer reads prod secrets"           --as="${DEV_SA}" get secrets -n prod

  # Cluster-wide visibility, namespace-scoped authority.
  assert_can yes "developer lists nodes (platform-viewer)" --as="${DEV_SA}" get nodes

  # CI is the most valuable credential to steal, so it is the most restricted.
  assert_can yes "ci deploys to dev"                      --as="${CI_SA}" create deployments.apps -n dev
  assert_can no  "ci deploys to staging"                  --as="${CI_SA}" create deployments.apps -n staging
  assert_can no  "ci deploys to prod"                     --as="${CI_SA}" create deployments.apps -n prod
  assert_can no  "ci creates secrets"                     --as="${CI_SA}" create secrets -n dev
  assert_can no  "ci execs into pods"                     --as="${CI_SA}" create pods --subresource=exec -n dev

  # Nothing in this repo may bind cluster-admin.
  local ca
  ca="$(kubectl get clusterrolebindings -o json \
        | grep -c '"name": "cluster-admin"' || true)"
  local ours
  ours="$(kubectl get clusterrolebindings \
          -l app.kubernetes.io/part-of=kubernetes-platform -o json \
          | grep -c '"name": "cluster-admin"' || true)"
  if [[ "${ours}" == "0" ]]; then
    ok "no platform ClusterRoleBinding grants cluster-admin (${ca} exist cluster-wide, all built-in)"
  else
    bad "a platform ClusterRoleBinding grants cluster-admin"
  fi
}

check_addons() {
  heading "Addons"

  local ok_all=1 d ready
  for d in ingress-nginx-controller metrics-server cert-manager; do
    # Query the deployment by name directly. The earlier form piped `kubectl get
    # deploy` into `grep -q`, which raced with SIGPIPE under pipefail and
    # reported healthy addons as missing — see cluster_exists() in lib/common.sh.
    if ! kubectl get deploy -n "${ADDON_NS}" "${d}" >/dev/null 2>&1; then
      bad "${d} not installed"; ok_all=0; continue
    fi
    ready="$(kubectl get deploy -n "${ADDON_NS}" "${d}" \
             -o jsonpath='{.status.readyReplicas}' 2>/dev/null || true)"
    if [[ "${ready:-0}" -ge 1 ]]; then
      ok "${d} ready (${ready}/1)"
    else
      bad "${d} installed but not ready"; ok_all=0
    fi
  done

  # metrics-server is only useful once it actually serves metrics.
  if kubectl top nodes >/dev/null 2>&1; then
    ok "kubectl top nodes returns metrics"
  else
    bad "kubectl top nodes failed — metrics-server is installed but not serving"
  fi

  # cert-manager is only useful once an issuer is Ready.
  local issuer
  issuer="$(kubectl get clusterissuer selfsigned \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
  if [[ "${issuer}" == "True" ]]; then
    ok "ClusterIssuer/selfsigned is Ready"
  else
    bad "ClusterIssuer/selfsigned is not Ready (got '${issuer:-none}')"
  fi

  # Ingress must actually answer on the mapped host port.
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost/ 2>/dev/null || echo 000)"
  if [[ "${code}" == "404" || "${code}" == "200" || "${code}" == "503" ]]; then
    ok "ingress-nginx answering on http://localhost (HTTP ${code})"
  else
    bad "http://localhost returned '${code}' — expected 404 from ingress-nginx"
  fi

  return $(( 1 - ok_all ))
}

main() {
  while (( $# > 0 )); do
    case "$1" in
      --demo) DEMO=1 ;;
      --help|-h) usage; exit 0 ;;
      *) usage >&2; die "unknown argument: $1" ;;
    esac
    shift
  done

  require_cmd kubectl
  require_kind_context

  heading "Verifying platform — ${CLUSTER_NAME}"

  check_namespaces
  check_governance
  check_quota_enforced
  check_rbac
  check_addons || true

  heading "Result"
  printf '  passed: %s%d%s   failed: %s%d%s\n' \
    "${C_GREEN}" "${PASS}" "${C_RESET}" \
    "$( ((FAIL)) && echo "${C_RED}" || echo "${C_GREEN}")" "${FAIL}" "${C_RESET}"

  if (( FAIL > 0 )); then
    echo
    die "${FAIL} assertion(s) failed"
  fi
  echo
  success "platform guardrails verified"
}

main "$@"
