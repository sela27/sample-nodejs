#!/usr/bin/env bash
# Bootstrap: takes an empty machine to a local minikube cluster in which ArgoCD
# manages everything else from git. Safe to re-run: every step is idempotent.
#
# Runs from Git Bash on Windows and natively on Linux and macOS.
#
# Variables (all optional):
#   MINIKUBE_PROFILE    minikube profile and kubectl context   (default: minikube)
#   MINIKUBE_CPUS       CPUs for the minikube node             (default: 4)
#   MINIKUBE_MEMORY     memory for the minikube node, in MiB   (default: 4096)
#   KUBERNETES_VERSION  Kubernetes version of the node         (default: v1.35.1)
#   ARGOCD_CHART_VERSION  argo/argo-cd Helm chart version      (default: pinned below)
#   GIT_REPO_URL        repo the root Application follows      (default: the public repo)
#   GIT_REVISION        revision the root Application follows  (default: main)
#                       Point it at a pushed branch to test child Applications
#                       before they merge; re-run with the default afterwards.
set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-4096}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.35.1}"
# Chart 10.17.0 ships ArgoCD v3.6.1.
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.17.0}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/sela27/sample-nodejs.git}"
GIT_REVISION="${GIT_REVISION:-main}"

APP_HOST="sample-nodejs.127.0.0.1.nip.io"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n==> %s\n' "$*"; }
die() {
  printf '\nERROR: %s\n' "$*" >&2
  exit 1
}

k() { kubectl --context "$MINIKUBE_PROFILE" "$@"; }

# wait_until <seconds> <what> <command...>: re-runs the command until it succeeds.
wait_until() {
  local timeout="$1" what="$2"
  shift 2
  local deadline=$((SECONDS + timeout))
  printf 'Waiting for %s ' "$what"
  until "$@"; do
    if ((SECONDS >= deadline)); then
      printf '\n'
      die "timed out after ${timeout}s waiting for ${what}. Inspect with: kubectl --context ${MINIKUBE_PROFILE} -n argocd get applications"
    fi
    printf '.'
    sleep 5
  done
  printf ' done\n'
}

app_status() {
  k -n argocd get application "$1" -o jsonpath="$2" 2>/dev/null | tr -d '\r' || true
}
app_synced() { [[ "$(app_status "$1" '{.status.sync.status}')" == "Synced" ]]; }
app_synced_and_healthy() { [[ "$(app_status "$1" '{.status.sync.status}/{.status.health.status}')" == "Synced/Healthy" ]]; }
deployment_available() {
  [[ "$(k -n "$1" get deployment "$2" -o jsonpath='{.status.availableReplicas}' 2>/dev/null | tr -d '\r')" =~ ^[1-9] ]]
}

check_prerequisites() {
  log "Checking prerequisites"
  local tool missing=""
  for tool in docker minikube kubectl helm; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  if [[ -n "$missing" ]]; then
    die "missing required tool(s):${missing}. Install them and make sure they are on PATH, then re-run."
  fi
  docker info >/dev/null 2>&1 ||
    die "docker is installed but the Docker daemon is not reachable. Start Docker Desktop (or the docker service), then re-run."
}

start_minikube() {
  if [[ "$(minikube status -p "$MINIKUBE_PROFILE" --format '{{.Host}}/{{.APIServer}}' 2>/dev/null | tr -d '\r\n')" == "Running/Running" ]]; then
    log "minikube profile '$MINIKUBE_PROFILE' is already running"
  else
    log "Starting minikube profile '$MINIKUBE_PROFILE' (Calico CNI, ${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY} MiB)"
    minikube start \
      --profile "$MINIKUBE_PROFILE" \
      --driver docker \
      --cni calico \
      --cpus "$MINIKUBE_CPUS" \
      --memory "$MINIKUBE_MEMORY" \
      --kubernetes-version "$KUBERNETES_VERSION"
  fi
  log "Waiting for Calico"
  k -n kube-system rollout status daemonset/calico-node --timeout=5m
}

enable_metrics_server() {
  log "Enabling the metrics-server addon"
  minikube addons enable metrics-server --profile "$MINIKUBE_PROFILE"
  k -n kube-system rollout status deployment/metrics-server --timeout=5m
}

# "upgrade --install" installs on the first run and upgrades in place afterwards.
# --repo avoids adding a chart repository to the user's Helm configuration.
install_argocd() {
  log "Installing ArgoCD (Helm chart argo-cd ${ARGOCD_CHART_VERSION}) and waiting until it is ready"
  helm upgrade --install argocd argo-cd \
    --repo https://argoproj.github.io/argo-helm \
    --version "$ARGOCD_CHART_VERSION" \
    --kube-context "$MINIKUBE_PROFILE" \
    --namespace argocd \
    --create-namespace \
    --values "$REPO_ROOT/gitops/bootstrap/argocd-values.yaml" \
    --wait \
    --timeout 10m
}

# The committed manifest follows main; GIT_REPO_URL and GIT_REVISION override it.
apply_root_app() {
  [[ "$GIT_REVISION" =~ ^[A-Za-z0-9._/-]+$ ]] || die "GIT_REVISION '${GIT_REVISION}' is not a branch, tag or commit name."
  [[ "$GIT_REPO_URL" =~ ^https://[A-Za-z0-9._/-]+$ ]] || die "GIT_REPO_URL '${GIT_REPO_URL}' is not an https git URL."
  log "Applying the root Application (gitops/apps at '${GIT_REVISION}' of ${GIT_REPO_URL})"
  sed \
    -e "s|^\([[:space:]]*repoURL:\).*|\1 ${GIT_REPO_URL}|" \
    -e "s|^\([[:space:]]*targetRevision:\).*|\1 ${GIT_REVISION}|" \
    "$REPO_ROOT/gitops/bootstrap/root-app.yaml" | k apply -f -
}

# The Traefik Application stays Progressing until `minikube tunnel` gives its
# LoadBalancer Service an address, so Bootstrap waits for Synced and a running
# Traefik rather than for Healthy.
wait_for_applications() {
  log "Waiting for ArgoCD to sync the Applications from git"
  wait_until 300 "the root Application to be Synced and Healthy" app_synced_and_healthy root
  wait_until 300 "the traefik Application to be Synced" app_synced traefik
  wait_until 300 "Traefik to be available" deployment_available traefik traefik
}

print_next_steps() {
  local verify="scripts/verify-bootstrap.sh"
  [[ "$GIT_REVISION" == "main" ]] || verify="GIT_REVISION=${GIT_REVISION} ${verify}"
  cat <<EOF

Bootstrap finished. ArgoCD now manages everything declared under gitops/apps.

ArgoCD admin password:
  kubectl --context ${MINIKUBE_PROFILE} -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

ArgoCD UI: keep this running, then open https://localhost:8080 and log in as
admin (the certificate is self-signed):
  kubectl --context ${MINIKUBE_PROFILE} -n argocd port-forward service/argocd-server 8080:443

Ingress on localhost: in a separate terminal, run this and keep it running
(it may ask for admin rights, because it binds ports 80 and 443):
  minikube tunnel -p ${MINIKUBE_PROFILE}

With the tunnel up, http://${APP_HOST}/ answers Traefik's
"404 page not found" until the app is deployed:
  curl -i http://${APP_HOST}/

Check the cluster state at any time (the tunnel check runs while the tunnel is up):
  ${verify}
EOF
}

main() {
  check_prerequisites
  start_minikube
  enable_metrics_server
  install_argocd
  apply_root_app
  wait_for_applications
  print_next_steps
}

main "$@"
