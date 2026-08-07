#!/usr/bin/env bash
#
# apply-base.sh — apply the platform base (namespaces, quotas, RBAC).
#
# A thin wrapper around `kubectl apply -k k8s/base`, and the wrapper is the
# point: every path that writes to a cluster goes through require_kind_context
# first. A bare `kubectl apply -k` in a Makefile will happily target whatever
# context happens to be current, which is how manifests end up in the wrong
# cluster — including a real one.
#
# Usage:
#   ./apply-base.sh [--diff] [--prune] [--help]
#
#   --diff    Show what would change; apply nothing
#   --prune   Delete platform-labelled resources no longer in the base
#
# Environment:
#   CLUSTER_NAME   kind cluster name (default: kubernetes-platform)
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

readonly BASE_DIR="${REPO_ROOT}/k8s/base"
DIFF_ONLY=0
PRUNE=0

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

Applies k8s/base (namespaces, ResourceQuotas, LimitRanges, RBAC) to the local
kind cluster. Refuses to run against any other context.

Options:
  --diff     Show what would change, apply nothing
  --prune    Remove platform-labelled resources no longer present in the base
  --help,-h  Show this help

Environment:
  CLUSTER_NAME=${CLUSTER_NAME}
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --diff)    DIFF_ONLY=1 ;;
      --prune)   PRUNE=1 ;;
      --help|-h) usage; exit 0 ;;
      *) usage >&2; die "unknown argument: $1" ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  require_cmd kubectl
  [[ -d "${BASE_DIR}" ]] || die "missing ${BASE_DIR}"

  # The guard. Everything above this line is setup; this is the safety check.
  require_kind_context

  if (( DIFF_ONLY )); then
    log "diffing k8s/base against ${KUBE_CONTEXT}"
    # kubectl diff exits 1 when differences exist, which is not an error here.
    kubectl --context "${KUBE_CONTEXT}" diff -k "${BASE_DIR}" || true
    exit 0
  fi

  log "applying k8s/base to ${KUBE_CONTEXT}"

  local -a args=(--context "${KUBE_CONTEXT}" apply -k "${BASE_DIR}")
  if (( PRUNE )); then
    warn "pruning: platform-labelled resources absent from the base will be deleted"
    args+=(--prune --selector "app.kubernetes.io/part-of=kubernetes-platform")
  fi

  kubectl "${args[@]}"

  success "platform base applied to ${KUBE_CONTEXT}"
  log "verify with: make verify-platform"
}

main "$@"
