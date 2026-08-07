#!/usr/bin/env bash
#
# install-addons.sh — install the cluster addons a workload needs to be
# reachable, measurable, and served over TLS.
#
#   ingress-nginx   HTTP(S) entry point, pinned to the ingress-ready node
#   metrics-server  resource metrics, required by `kubectl top` and by HPA (Phase 9)
#   cert-manager    certificate issuance, plus a self-signed local ClusterIssuer
#
# Idempotent: uses `helm upgrade --install`, so re-running converges rather than
# failing. Safe to run against an existing cluster at any time.
#
# This is the first script that applies resources to whatever context is
# current, so it is the first to use the require_kind_context guard.
#
# Usage:
#   ./install-addons.sh [--only <addon>] [--help]
#
# Environment:
#   CLUSTER_NAME    kind cluster name (default: kubernetes-platform)
#   WAIT_TIMEOUT    seconds to wait for each addon (default: 300)
set -Eeuo pipefail

# shellcheck source=scripts/lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
trap 'on_error $LINENO' ERR

readonly WAIT_TIMEOUT="${WAIT_TIMEOUT:-300}"
readonly ADDON_NS="platform-system"
# Values live in files, not in a wall of --set flags: they are reviewable in a
# diff, they can carry comments explaining *why* a setting is what it is, and
# --set silently coerces types (a bare `true` becomes a boolean, which the API
# server then rejects for string fields like nodeSelector).
readonly VALUES_DIR="${REPO_ROOT}/k8s/addons/values"

# Chart versions are pinned. An unpinned addon means the cluster you get today
# and the cluster you get in six months are different clusters, which makes
# "worked last week" unfalsifiable.
readonly INGRESS_NGINX_CHART="4.15.1"    # app v1.15.1
readonly METRICS_SERVER_CHART="3.13.1"   # app v0.8.1
readonly CERT_MANAGER_CHART="v1.21.1"    # app v1.21.1

ONLY=""

usage() {
  cat <<EOF
Usage: ${0##*/} [options]

Installs cluster addons into the '${ADDON_NS}' namespace. Idempotent.

Options:
  --only <addon>   Install just one of: ingress-nginx, metrics-server, cert-manager
  --help, -h       Show this help

Environment:
  CLUSTER_NAME=${CLUSTER_NAME}
  WAIT_TIMEOUT=${WAIT_TIMEOUT}

Pinned chart versions:
  ingress-nginx   ${INGRESS_NGINX_CHART}
  metrics-server  ${METRICS_SERVER_CHART}
  cert-manager    ${CERT_MANAGER_CHART}
EOF
}

parse_args() {
  while (( $# > 0 )); do
    case "$1" in
      --only) ONLY="${2:-}"; shift ;;
      --help|-h) usage; exit 0 ;;
      *) usage >&2; die "unknown argument: $1" ;;
    esac
    shift
  done

  if [[ -n "${ONLY}" ]]; then
    case "${ONLY}" in
      ingress-nginx|metrics-server|cert-manager) ;;
      *) die "--only must be one of: ingress-nginx, metrics-server, cert-manager" ;;
    esac
  fi
}

wants() { [[ -z "${ONLY}" || "${ONLY}" == "$1" ]]; }

add_repos() {
  log "adding/updating helm repositories"
  helm repo add ingress-nginx  https://kubernetes.github.io/ingress-nginx      >/dev/null 2>&1 || true
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ >/dev/null 2>&1 || true
  helm repo add jetstack       https://charts.jetstack.io                       >/dev/null 2>&1 || true
  helm repo update >/dev/null
  success "helm repositories ready"
}

# ---------------------------------------------------------------------------
# ingress-nginx
#
# Pinned to the control-plane node via the `ingress-ready=true` label set in
# infra/kind/cluster.yaml, using hostPort rather than a Service of type
# LoadBalancer — kind has no cloud controller, so a LoadBalancer would sit
# Pending forever. This is the standard kind pattern and the reason ports 80/443
# are mapped in the cluster config.
# ---------------------------------------------------------------------------
install_ingress_nginx() {
  heading "ingress-nginx ${INGRESS_NGINX_CHART}"
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace "${ADDON_NS}" \
    --version "${INGRESS_NGINX_CHART}" \
    --values "${VALUES_DIR}/ingress-nginx.yaml" \
    --wait --timeout "${WAIT_TIMEOUT}s"
  success "ingress-nginx ready — http://localhost reaches the cluster"
}

# ---------------------------------------------------------------------------
# metrics-server
#
# --kubelet-insecure-tls is required on kind: kubelet serving certificates are
# self-signed and not in the cluster CA, so metrics-server cannot verify them.
# This is a local-cluster concession and must NOT survive to Phase 10 — the
# managed cluster's kubelet certs are properly signed. Flagged in
# docs/architecture.md as a known local/cloud divergence.
# ---------------------------------------------------------------------------
install_metrics_server() {
  heading "metrics-server ${METRICS_SERVER_CHART}"
  helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace "${ADDON_NS}" \
    --version "${METRICS_SERVER_CHART}" \
    --values "${VALUES_DIR}/metrics-server.yaml" \
    --wait --timeout "${WAIT_TIMEOUT}s"
  success "metrics-server ready — 'kubectl top nodes' works"
}

# ---------------------------------------------------------------------------
# cert-manager
#
# Installed with its CRDs. The self-signed ClusterIssuer below is a local
# stand-in: it proves the certificate lifecycle works end to end without needing
# a public DNS name or a real ACME account. Phase 10 adds a real ACME issuer
# using DNS-01 against the chosen cloud's DNS.
# ---------------------------------------------------------------------------
install_cert_manager() {
  heading "cert-manager ${CERT_MANAGER_CHART}"
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace "${ADDON_NS}" \
    --version "${CERT_MANAGER_CHART}" \
    --values "${VALUES_DIR}/cert-manager.yaml" \
    --wait --timeout "${WAIT_TIMEOUT}s"

  log "applying local self-signed ClusterIssuer"
  kubectl apply -f "${REPO_ROOT}/k8s/addons/clusterissuer-selfsigned.yaml"

  # The issuer is only useful once it reports Ready; applying it is not the same
  # as it working.
  wait_for 60 "ClusterIssuer/selfsigned to be Ready" \
    kubectl wait --for=condition=Ready clusterissuer/selfsigned --timeout=15s
  success "cert-manager ready"
}

summary() {
  heading "Addons in ${ADDON_NS}"
  helm list --namespace "${ADDON_NS}"
  echo
  kubectl get pods -n "${ADDON_NS}" -o wide
  cat <<EOF

  Next:
    kubectl top nodes                 metrics-server
    curl -I http://localhost          ingress-nginx (404 until an Ingress exists)
    kubectl apply -k examples/hello-workload/

EOF
}

main() {
  parse_args "$@"

  require_cmd kubectl
  require_cmd helm "Install with: brew install helm"

  # Refuse to install anything into a cluster this repo does not own.
  require_kind_context

  # The namespace comes from k8s/base — addons must not create it implicitly,
  # or the labels and ownership annotations would be missing.
  if ! kubectl get namespace "${ADDON_NS}" >/dev/null 2>&1; then
    err "namespace '${ADDON_NS}' does not exist"
    log "apply the platform base first:  make apply-base"
    exit 1
  fi

  add_repos
  wants ingress-nginx  && install_ingress_nginx
  wants metrics-server && install_metrics_server
  wants cert-manager   && install_cert_manager
  summary
}

main "$@"
