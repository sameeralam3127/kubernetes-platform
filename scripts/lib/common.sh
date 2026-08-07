#!/usr/bin/env bash
# Shared helpers for kubernetes-platform scripts.
#
# Source this; do not execute it:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

# Guard against double-sourcing.
[[ -n "${_KP_COMMON_SOURCED:-}" ]] && return 0
_KP_COMMON_SOURCED=1

# ---------------------------------------------------------------------------
# Repo layout
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
# SC2034: consumed by the scripts that source this library. Linting this file
# on its own cannot see those consumers, so the "unused" warning is a false
# positive here.
# shellcheck disable=SC2034
readonly KIND_CONFIG="${REPO_ROOT}/infra/kind/cluster.yaml"
# shellcheck disable=SC2034
readonly LOCAL_STATE_DIR="${REPO_ROOT}/.local"

# ---------------------------------------------------------------------------
# Configuration (override via environment)
# ---------------------------------------------------------------------------
CLUSTER_NAME="${CLUSTER_NAME:-kubernetes-platform}"
readonly CLUSTER_NAME
# kubectl context name kind creates for the above.
readonly KUBE_CONTEXT="kind-${CLUSTER_NAME}"
# Empty means "use kind's default node image for this kind binary".
KIND_NODE_IMAGE="${KIND_NODE_IMAGE:-}"

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------
if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_RED=$'\033[0;31m'
  readonly C_GREEN=$'\033[0;32m'
  readonly C_YELLOW=$'\033[0;33m'
  readonly C_BLUE=$'\033[0;34m'
  readonly C_BOLD=$'\033[1m'
else
  readonly C_RESET="" C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_BOLD=""
fi

log()      { printf '%s==>%s %s\n' "${C_BLUE}" "${C_RESET}" "$*"; }
success()  { printf '%s ok %s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
warn()     { printf '%swarn%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
err()      { printf '%sfail%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; }
heading()  { printf '\n%s%s%s\n' "${C_BOLD}" "$*" "${C_RESET}"; }
die()      { err "$*"; exit 1; }

# Print a friendly message on unexpected failure, including where it happened.
# Callers opt in with:  trap 'on_error $LINENO' ERR
on_error() {
  local line="${1:-?}"
  err "unexpected failure at ${BASH_SOURCE[1]:-script}:${line}"
  err "re-run with 'bash -x' for a trace, or see docs/local-development.md#troubleshooting"
}

# ---------------------------------------------------------------------------
# Guards
# ---------------------------------------------------------------------------

has() { command -v "$1" >/dev/null 2>&1; }

require_cmd() {
  local cmd="$1" hint="${2:-}"
  has "${cmd}" || die "'${cmd}' not found in PATH.${hint:+ }${hint}"
}

# True if a kind cluster with CLUSTER_NAME currently exists.
#
# Deliberately NOT `kind get clusters | grep -qx ...`. Under `set -o pipefail`,
# `grep -q` exits the moment it matches, which closes the pipe and kills the
# upstream command with SIGPIPE (exit 141). pipefail then reports the whole
# pipeline as failed *even though the match succeeded* — non-deterministically,
# depending on whether the writer had already finished. Capturing first and
# matching against a here-string removes the pipe, and with it the race.
cluster_exists() {
  local clusters
  clusters="$(kind get clusters 2>/dev/null || true)"
  grep -qx "${CLUSTER_NAME}" <<<"${clusters}"
}

# Refuse to run destructive operations against anything that is not our own kind
# cluster. This is the guard that separates a teardown script from an outage:
# the failure mode we are preventing is a stale kubeconfig context pointing at a
# real cluster while the operator believes they are on a laptop.
require_kind_context() {
  local current
  current="$(kubectl config current-context 2>/dev/null || true)"

  [[ -n "${current}" ]] || die "no current kubectl context; refusing to continue"

  if [[ "${current}" != "${KUBE_CONTEXT}" ]]; then
    err "current kubectl context is '${current}', expected '${KUBE_CONTEXT}'"
    err "refusing to act on a cluster this script does not own"
    err "fix with: kubectl config use-context ${KUBE_CONTEXT}"
    exit 1
  fi

  # Belt and braces: the context name could be reused. Confirm the API server is
  # actually on loopback, which a remote cluster never is.
  local server
  server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || true)"
  case "${server}" in
    https://127.0.0.1:* | https://localhost:* | https://0.0.0.0:*) ;;
    *) die "context '${current}' points at '${server}', which is not a local kind cluster; refusing to continue" ;;
  esac
}

# Ask for confirmation unless ASSUME_YES=1 (set by --yes).
confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  if [[ ! -t 0 ]]; then
    die "refusing to '${prompt}' without a TTY; pass --yes to confirm non-interactively"
  fi
  local reply
  printf '%s%s%s [y/N] ' "${C_YELLOW}" "${prompt}" "${C_RESET}"
  read -r reply
  [[ "${reply}" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# ---------------------------------------------------------------------------
# Waiting
# ---------------------------------------------------------------------------

# wait_for <timeout-seconds> <description> <command...>
# Polls until the command succeeds. Returns 1 on timeout.
wait_for() {
  local timeout="$1" desc="$2"; shift 2
  local deadline=$(( SECONDS + timeout ))

  log "waiting for ${desc} (timeout ${timeout}s)"
  while (( SECONDS < deadline )); do
    if "$@" >/dev/null 2>&1; then
      success "${desc}"
      return 0
    fi
    sleep 3
  done

  err "timed out after ${timeout}s waiting for ${desc}"
  return 1
}
