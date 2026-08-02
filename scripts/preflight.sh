#!/usr/bin/env bash
#
# preflight.sh — verify the local toolchain can build the platform cluster.
#
# Checks that Docker, kind, and kubectl are present and healthy, and reports the
# versions in use. Run standalone (`make preflight`) or implicitly by cluster-up.sh.
#
# Environment:
#   CLUSTER_NAME   kind cluster name (default: kubernetes-platform)
#
# Exit codes: 0 all good · 1 something is missing or unhealthy
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

usage() {
  cat <<EOF
Usage: ${0##*/} [--help]

Verifies the local toolchain required to run the kubernetes-platform dev cluster:
Docker (running), kind, and kubectl. Reports versions and exits non-zero if any
requirement is unmet.
EOF
}

# Minimum kubectl/cluster skew tolerated before we warn. kubectl supports +/-1
# minor against the API server; beyond that, behaviour is not guaranteed.
readonly MAX_MINOR_SKEW=1

failures=0
note_failure() { err "$1"; failures=$(( failures + 1 )); }

check_docker() {
  if ! has docker; then
    note_failure "docker not found. Install Docker Desktop, OrbStack, Colima, or Podman."
    printf '        macOS:  brew install --cask docker      (or: brew install colima docker)\n' >&2
    return
  fi

  if ! docker info >/dev/null 2>&1; then
    note_failure "docker is installed but the daemon is not reachable. Start Docker and retry."
    return
  fi

  local server_version
  server_version="$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo unknown)"
  success "docker ${server_version} (daemon reachable)"

  # kind needs real headroom: 3 nodes plus, later, an observability stack.
  local mem_bytes mem_gib
  mem_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
  if [[ "${mem_bytes}" =~ ^[0-9]+$ ]] && (( mem_bytes > 0 )); then
    mem_gib=$(( mem_bytes / 1024 / 1024 / 1024 ))
    if (( mem_gib < 4 )); then
      warn "docker has ${mem_gib}GiB of memory; a 3-node cluster wants 4GiB+ (6GiB once Phase 7 lands)"
    else
      success "docker memory ${mem_gib}GiB"
    fi
  fi
}

check_kind() {
  if ! has kind; then
    note_failure "kind not found."
    printf '        macOS:  brew install kind\n' >&2
    printf '        Linux:  go install sigs.k8s.io/kind@latest   (or see kind.sigs.k8s.io)\n' >&2
    return
  fi
  success "kind $(kind version 2>/dev/null | awk '{print $2}')"
}

check_kubectl() {
  if ! has kubectl; then
    note_failure "kubectl not found."
    printf '        macOS:  brew install kubernetes-cli\n' >&2
    return
  fi

  local client
  client="$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || true)"
  [[ -n "${client}" && "${client}" != "null" ]] || client="$(kubectl version --client 2>/dev/null | head -1 | awk '{print $NF}')"
  success "kubectl ${client:-unknown}"

  # Warn on version skew only when the cluster is already up.
  if cluster_exists && kubectl --context "${KUBE_CONTEXT}" version -o json >/dev/null 2>&1; then
    local server c_minor s_minor
    server="$(kubectl --context "${KUBE_CONTEXT}" version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || true)"
    if [[ -n "${server}" && "${server}" != "null" ]]; then
      c_minor="$(sed -E 's/^v[0-9]+\.([0-9]+).*/\1/' <<<"${client}")"
      s_minor="$(sed -E 's/^v[0-9]+\.([0-9]+).*/\1/' <<<"${server}")"
      if [[ "${c_minor}" =~ ^[0-9]+$ && "${s_minor}" =~ ^[0-9]+$ ]]; then
        local skew=$(( c_minor > s_minor ? c_minor - s_minor : s_minor - c_minor ))
        if (( skew > MAX_MINOR_SKEW )); then
          warn "kubectl ${client} vs cluster ${server}: ${skew} minor versions apart (supported skew is ±${MAX_MINOR_SKEW})"
          warn "pin the cluster closer with KIND_NODE_IMAGE — see infra/kind/README.md"
        else
          success "cluster ${server} (skew ok)"
        fi
      fi
    fi
  fi
}

check_optional() {
  local missing=()
  has helm       || missing+=("helm (Phase 4)")
  has kustomize  || missing+=("kustomize (Phase 4 — kubectl has it built in, standalone is nicer)")
  has shellcheck || missing+=("shellcheck (make lint-shell)")
  has jq         || missing+=("jq (nicer script output)")

  if (( ${#missing[@]} > 0 )); then
    heading "Optional, not needed for Phase 1"
    printf '  · %s\n' "${missing[@]}"
  fi
}

main() {
  [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && { usage; exit 0; }

  heading "Preflight — kubernetes-platform"
  check_docker
  check_kind
  check_kubectl

  # Config file must exist and parse as YAML-ish before we hand it to kind.
  if [[ -f "${KIND_CONFIG}" ]]; then
    success "cluster config ${KIND_CONFIG#"${REPO_ROOT}/"}"
  else
    note_failure "missing cluster config at ${KIND_CONFIG}"
  fi

  check_optional

  echo
  if (( failures > 0 )); then
    die "${failures} requirement(s) unmet — see above"
  fi

  if cluster_exists; then
    success "all required tools present; cluster '${CLUSTER_NAME}' already exists"
  else
    success "all required tools present; ready to run 'make up'"
  fi
}

main "$@"
