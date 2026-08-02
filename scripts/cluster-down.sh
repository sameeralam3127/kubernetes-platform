#!/usr/bin/env bash
#
# cluster-down.sh — delete the local kind development cluster.
#
# Destructive, and therefore paranoid: it verifies the target is a kind cluster
# owned by this repo before deleting anything, and prompts unless --yes is given.
# The failure this guards against is a stale kubeconfig pointing somewhere real.
#
# Usage:
#   ./cluster-down.sh [--yes] [--help]
#
# Environment:
#   CLUSTER_NAME   kind cluster name (default: kubernetes-platform)
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

ASSUME_YES="${ASSUME_YES:-0}"

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

Deletes the local kind cluster '${CLUSTER_NAME}' and cleans up local scratch state.

Options:
  --yes, -y    Do not prompt for confirmation
  --help, -h   Show this help

Environment:
  CLUSTER_NAME=${CLUSTER_NAME}
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --yes|-y)   ASSUME_YES=1 ;;
      --help|-h)  usage; exit 0 ;;
      *)          usage >&2; die "unknown argument: $1" ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  require_cmd kind "Install with: brew install kind"

  if ! cluster_exists; then
    success "cluster '${CLUSTER_NAME}' does not exist — nothing to do"
    exit 0
  fi

  # kind delete is name-scoped, so it cannot touch a non-kind cluster. But if the
  # current context points elsewhere, the operator's mental model is wrong and
  # they should know before anything is destroyed.
  local current
  current="$(kubectl config current-context 2>/dev/null || echo "<none>")"
  if [[ "${current}" != "${KUBE_CONTEXT}" ]]; then
    warn "current kubectl context is '${current}', not '${KUBE_CONTEXT}'"
    warn "only the kind cluster '${CLUSTER_NAME}' will be deleted; '${current}' is untouched"
  fi

  confirm "Delete kind cluster '${CLUSTER_NAME}'? All cluster state will be lost." \
    || { log "aborted — cluster left running"; exit 0; }

  log "deleting cluster '${CLUSTER_NAME}'"
  kind delete cluster --name "${CLUSTER_NAME}"

  # kind removes its own kubeconfig entries; clear our scratch state too.
  rm -f "${LOCAL_STATE_DIR}/cluster-info.txt"
  rmdir "${LOCAL_STATE_DIR}" 2>/dev/null || true

  success "cluster '${CLUSTER_NAME}' deleted"
  log "docker containers and volumes for this cluster are removed by kind;"
  log "run 'docker system prune' separately if you want to reclaim image cache space"
}

main "$@"
