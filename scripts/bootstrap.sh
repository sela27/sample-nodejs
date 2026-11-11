#!/usr/bin/env bash
# Bootstrap: takes an empty machine to a local minikube cluster in which ArgoCD
# manages everything else from git. Safe to re-run: every step is idempotent.
#
# Runs from Git Bash on Windows and natively on Linux and macOS.
#
# Required:
#   GHCR_PULL_TOKEN     a classic GitHub personal access token with only the
#                       read:packages scope. Bootstrap stores it in the app
#                       namespace as the registry pull secret and never prints it.
#
# Variables (all optional):
#   GHCR_PULL_USER      GitHub user the token belongs to       (default: sela27)
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

GHCR_PULL_USER="${GHCR_PULL_USER:-sela27}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-4096}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-v1.35.1}"
# Chart 10.17.0 ships ArgoCD v3.6.1.
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-10.17.0}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/sela27/sample-nodejs.git}"
GIT_REVISION="${GIT_REVISION:-main}"

APP_HOST="sample-nodejs.127.0.0.1.nip.io"
APP_IMAGE="ghcr.io/sela27/sample-nodejs"
# The dev Environment's ArgoCD Application (gitops/apps/sample-nodejs-dev.yaml)
# and the namespace it deploys into.
APP="sample-nodejs-dev"
APP_NAMESPACE="sample-nodejs-dev"
# The registry pull secret, by the name the chart's ServiceAccount refers to
# (image.pullSecret in gitops/charts/sample-nodejs/values.yaml).
PULL_SECRET="ghcr-pull"
REGISTRY="ghcr.io"
# Grafana's admin login, by the name gitops/apps/kube-prometheus-stack.yaml
# gives as grafana.admin.existingSecret, in the namespace Prometheus and Grafana
# run in.
MONITORING_NAMESPACE="monitoring"
GRAFANA_ADMIN_SECRET="grafana-admin"
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
      die "timed out after ${timeout}s waiting for ${what}. Inspect with: kubectl --context ${MINIKUBE_PROFILE} -n argocd get applications
and: kubectl --context ${MINIKUBE_PROFILE} get pods --all-namespaces (ImagePullBackOff in ${APP_NAMESPACE} means the registry refused GHCR_PULL_TOKEN)"
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

# The registry pull secret needs the token (ADR-0003). It is checked before
# anything else, so a missing token stops the run before it changes anything.
# The test asks only whether it is set, so that not even `bash -x` prints it.
check_pull_token() {
  [[ "$GHCR_PULL_USER" =~ ^[A-Za-z0-9-]+$ ]] || die "GHCR_PULL_USER '${GHCR_PULL_USER}' is not a GitHub user name."
  [[ "${GHCR_PULL_TOKEN:+set}" == "set" ]] && return 0
  die "GHCR_PULL_TOKEN is not set. Bootstrap needs it to create the registry pull secret for the private image ${APP_IMAGE}.
Create a classic personal access token with only the read:packages scope
(GitHub > Settings > Developer settings > Personal access tokens > Tokens (classic)),
then read it without echo, so it stays out of your shell history, and re-run:
  read -rs GHCR_PULL_TOKEN   # paste the token, press Enter
  export GHCR_PULL_TOKEN
  scripts/bootstrap.sh"
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

# The dev Environment's namespace. Bootstrap creates it, rather than leaving it
# to ArgoCD, because the pull secret must be in it before the app's first pod
# starts. Its labels make every pod in it meet the restricted Pod Security
# profile (enforce), and also record (audit) and warn about (warn, shown when a
# workload is applied) any workload that would not. Server-side apply keeps a
# re-run idempotent and puts the labels back if they were changed.
create_app_namespace() {
  log "Creating namespace ${APP_NAMESPACE} with the restricted Pod Security labels"
  k apply --server-side --force-conflicts --field-manager=bootstrap -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${APP_NAMESPACE}
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF
}

# The registry pull secret for the private image: the one object in the
# cluster that does not come from git (ADR-0003). The chart's ServiceAccount
# names it. The function body is a subshell with xtrace off, and the token
# reaches kubectl on stdin through printf, a shell builtin, so neither
# `bash -x` nor the process list shows it. Server-side apply keeps a re-run
# idempotent, and a re-run with a new token replaces the old one.
create_pull_secret() (
  set +x
  log "Creating the registry pull secret ${PULL_SECRET} in namespace ${APP_NAMESPACE} (token not shown)"
  local auth config
  auth="$(printf '%s:%s' "$GHCR_PULL_USER" "$GHCR_PULL_TOKEN" | base64 | tr -d '\n')"
  config="$(printf '{"auths":{"%s":{"auth":"%s"}}}' "$REGISTRY" "$auth" | base64 | tr -d '\n')"
  printf 'apiVersion: v1
kind: Secret
metadata:
  name: %s
  namespace: %s
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: %s
' "$PULL_SECRET" "$APP_NAMESPACE" "$config" |
    k apply --server-side --force-conflicts --field-manager=bootstrap -f -
)

# Grafana's admin login. Like the pull secret, it is created here and not kept
# in git, so no password is in the repo. The password is random and set only
# when the Secret does not exist yet, so a re-run keeps it. It reaches kubectl
# on stdin and is never printed; the README shows how to read it back.
create_grafana_admin_secret() (
  set +x
  k create namespace "$MONITORING_NAMESPACE" --dry-run=client -o yaml | k apply -f - >/dev/null
  if k -n "$MONITORING_NAMESPACE" get secret "$GRAFANA_ADMIN_SECRET" >/dev/null 2>&1; then
    log "Keeping the existing Grafana admin Secret ${GRAFANA_ADMIN_SECRET} in namespace ${MONITORING_NAMESPACE}"
    return 0
  fi
  log "Creating the Grafana admin Secret ${GRAFANA_ADMIN_SECRET} in namespace ${MONITORING_NAMESPACE} (random password, not shown)"
  local password
  # head reads a fixed number of bytes, so no stage of the pipe is cut short.
  password="$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | cut -c1-32)"
  printf 'apiVersion: v1
kind: Secret
metadata:
  name: %s
  namespace: %s
type: Opaque
stringData:
  admin-user: admin
  admin-password: %s
' "$GRAFANA_ADMIN_SECRET" "$MONITORING_NAMESPACE" "$password" |
    k apply -f - >/dev/null
)

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
# LoadBalancer Service an address, and so does the app's, because Traefik
# copies that address onto the app's Ingress. So Bootstrap waits for each to
# be Synced and its Deployment available rather than for Healthy. The app's
# Deployment is available once its pods pass the readiness probe, which needs
# the image pulled with the token.
wait_for_applications() {
  log "Waiting for ArgoCD to sync the Applications from git"
  wait_until 300 "the root Application to be Synced and Healthy" app_synced_and_healthy root
  wait_until 300 "the traefik Application to be Synced" app_synced traefik
  wait_until 300 "Traefik to be available" deployment_available traefik traefik
  wait_until 300 "the ${APP} Application to be Synced" app_synced "$APP"
  wait_until 300 "the app to be available" deployment_available "$APP_NAMESPACE" "$APP"
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

Grafana: keep this running, then open http://localhost:3000/d/sample-nodejs
(viewing needs no login):
  kubectl --context ${MINIKUBE_PROFILE} -n ${MONITORING_NAMESPACE} port-forward service/kube-prometheus-stack-grafana 3000:80

Grafana admin password (user admin), needed only to change dashboards or settings:
  kubectl --context ${MINIKUBE_PROFILE} -n ${MONITORING_NAMESPACE} get secret ${GRAFANA_ADMIN_SECRET} -o jsonpath='{.data.admin-password}' | base64 -d; echo

Ingress on localhost: in a separate terminal, run this and keep it running
(it may ask for admin rights, because it binds ports 80 and 443):
  minikube tunnel -p ${MINIKUBE_PROFILE}

With the tunnel up, the app answers "Hello, World!" in the browser at the URL
below, and ArgoCD shows both Applications Healthy:
  http://${APP_HOST}/my-app

Check the cluster state at any time (the tunnel checks run while the tunnel is up):
  ${verify}
EOF
}

main() {
  check_pull_token
  check_prerequisites
  start_minikube
  enable_metrics_server
  install_argocd
  create_app_namespace
  create_pull_secret
  create_grafana_admin_secret
  apply_root_app
  wait_for_applications
  print_next_steps
}

main "$@"
