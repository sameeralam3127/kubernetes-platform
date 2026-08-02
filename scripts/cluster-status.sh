#!/usr/bin/env bash
#
# cluster-status.sh — report the health of the local development cluster.
#
# Read-only. Shows the active context, node topology, system pod health, and any
# pods that are not in a healthy state. Exits non-zero if the cluster is missing
# or unhealthy, so it can be used as a check in CI or a Makefile chain.
#
# Usage:
#   ./cluster-status.sh [--help]
#
# Environment:
#   CLUSTER_NAME   kind cluster name (default: kubernetes-platform)
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

usage() {
  cat <<EOF
Usage: ${0##*/} [--help]

Read-only health report for the local kind cluster '${CLUSTER_NAME}'.
Exits 0 if healthy, 1 if the cluster is absent or degraded.
EOF
}

main() {
  [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }

  require_cmd kind
  require_cmd kubectl

  if ! cluster_exists; then
    err "cluster '${CLUSTER_NAME}' does not exist"
    log "create it with: make up"
    exit 1
  fi

  local kubectl_ctx=(kubectl --context "${KUBE_CONTEXT}")

  heading "Context"
  printf '  cluster:  %s\n' "${CLUSTER_NAME}"
  printf '  context:  %s\n' "${KUBE_CONTEXT}"
  printf '  current:  %s\n' "$(kubectl config current-context 2>/dev/null || echo '<none>')"
  if [[ -f "${LOCAL_STATE_DIR}/cluster-info.txt" ]]; then
    printf '  created:  %s\n' \
      "$(awk '/^created:/ {print $2}' "${LOCAL_STATE_DIR}/cluster-info.txt")"
  fi

  heading "Nodes"
  "${kubectl_ctx[@]}" get nodes -o wide

  heading "System pods (kube-system)"
  "${kubectl_ctx[@]}" -n kube-system get pods

  heading "Non-running pods (all namespaces)"
  local unhealthy
  unhealthy="$("${kubectl_ctx[@]}" get pods -A \
    --field-selector=status.phase!=Running,status.phase!=Succeeded \
    --no-headers 2>/dev/null || true)"
  if [[ -z "${unhealthy}" ]]; then
    success "none"
  else
    printf '%s\n' "${unhealthy}"
  fi

  heading "Summary"
  local total ready
  total="$("${kubectl_ctx[@]}" get nodes --no-headers | wc -l | tr -d ' ')"
  ready="$("${kubectl_ctx[@]}" get nodes --no-headers | awk '$2 == "Ready"' | wc -l | tr -d ' ')"
  printf '  nodes ready:  %s/%s\n' "${ready}" "${total}"
  printf '  k8s version:  %s\n' \
    "$("${kubectl_ctx[@]}" get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')"

  if [[ "${ready}" != "${total}" || -n "${unhealthy}" ]]; then
    echo
    err "cluster is degraded"
    exit 1
  fi

  echo
  success "cluster '${CLUSTER_NAME}' is healthy"
}

main "$@"
