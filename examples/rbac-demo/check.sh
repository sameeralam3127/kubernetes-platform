#!/usr/bin/env bash
#
# check.sh — print the RBAC permission matrix for the platform's personas.
#
# Read-only: every call is `kubectl auth can-i`, which asks the API server's
# authorizer what *would* happen. Nothing is created, changed, or deleted.
#
# Usage:  ./check.sh [--help]
set -Eeuo pipefail

DEV="system:serviceaccount:platform-system:developer"
CI="system:serviceaccount:platform-system:ci-deployer"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
  exit 0
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  G=$'\033[0;32m'; R=$'\033[0;31m'; D=$'\033[2m'; B=$'\033[1m'; N=$'\033[0m'
else
  G=""; R=""; D=""; B=""; N=""
fi

# cell <subject> <namespace|-> <verb> <resource> [extra args...]
cell() {
  local as="$1" ns="$2" verb="$3" res="$4"; shift 4
  local -a args=(auth can-i "${verb}" "${res}" --as="${as}" "$@")
  [[ "${ns}" != "-" ]] && args+=(-n "${ns}")
  if [[ "$(kubectl "${args[@]}" 2>/dev/null || true)" == "yes" ]]; then
    printf '%s   yes  %s' "${G}" "${N}"
  else
    printf '%s   no   %s' "${R}" "${N}"
  fi
}

row() { # row <label> <verb> <resource> [extra...]
  local label="$1" verb="$2" res="$3"; shift 3
  printf '  %-34s' "${label}"
  cell "${DEV}" dev     "${verb}" "${res}" "$@"
  cell "${DEV}" staging "${verb}" "${res}" "$@"
  cell "${DEV}" prod    "${verb}" "${res}" "$@"
  cell "${CI}"  dev     "${verb}" "${res}" "$@"
  printf '\n'
}

printf '\n%sRBAC permission matrix%s\n\n' "${B}" "${N}"
printf '  %-34s%s\n' "" "developer          ci"
printf '  %-34s%s\n' "" "dev    stg    prod   dev"
printf '  %s\n' "$(printf '─%.0s' {1..62})"

printf '\n  %s— workload management —%s\n' "${D}" "${N}"
row "create deployments"   create deployments.apps
row "delete deployments"   delete deployments.apps
row "create services"      create services
row "create ingresses"     create ingresses.networking.k8s.io

printf '\n  %s— debugging —%s\n' "${D}" "${N}"
row "read pods"            get   pods
row "read pod logs"        get   pods --subresource=log
row "delete pods"          delete pods
row "exec into pods"       create pods --subresource=exec

printf '\n  %s— secrets —%s\n' "${D}" "${N}"
row "read secrets"         get    secrets
row "write secrets"        create secrets

printf '\n  %s— escalation paths (all must be no) —%s\n' "${D}" "${N}"
row "edit rolebindings"    create rolebindings.rbac.authorization.k8s.io
row "edit roles"           create roles.rbac.authorization.k8s.io
row "raise own quota"      patch  resourcequotas

printf '\n  %s— cluster scope —%s\n' "${D}" "${N}"
printf '  %-34s' "list nodes (developer)"
cell "${DEV}" - get nodes; printf '\n'
printf '  %-34s' "create namespaces (developer)"
cell "${DEV}" - create namespaces; printf '\n'
printf '  %-34s' "delete nodes (developer)"
cell "${DEV}" - delete nodes; printf '\n'

cat <<EOF

  ${B}What this shows${N}
    · Authority is namespace-scoped; visibility is cluster-wide.
      The developer can list nodes but cannot touch them — that is the
      platform-viewer ClusterRole, and it is the only cluster-scoped grant.
    · Production is read-only for humans. From Phase 6 prod changes arrive
      through Git and Argo CD, so a human write path would bypass the audit
      trail rather than add to it.
    · exec is dev-only. It runs arbitrary code as the pod's ServiceAccount,
      inside its network namespace — a genuine escalation path, not a
      convenience.
    · CI can write to dev and nothing else. It is the credential most worth
      stealing, so it holds the least.
    · No persona can edit RBAC or raise its own quota. A guardrail you can
      lift yourself is not a guardrail.

EOF
