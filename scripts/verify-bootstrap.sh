#!/usr/bin/env bash
# Checks that Bootstrap left the local cluster in the expected state.
# Prints PASS, FAIL or SKIP per check and exits non-zero if any check fails.
#
# The tunnel checks run only while `minikube tunnel` is up (the Traefik
# LoadBalancer Service has an address); otherwise they are reported as SKIP.
# The other HTTP checks reach Traefik through a port-forward.
#
# It never prints the registry token: the pull secret check reads the secret
# only inside a pipe.
#
# Variables (same defaults as bootstrap.sh):
#   MINIKUBE_PROFILE  minikube profile and kubectl context   (default: minikube)
#   GIT_REPO_URL      repo the root Application must follow  (default: the public repo)
#   GIT_REVISION      revision the root Application follows  (default: main)
#   APP_HOST          Ingress host of the dev Environment    (default: sample-nodejs.127.0.0.1.nip.io)
set -euo pipefail

MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/sela27/sample-nodejs.git}"
GIT_REVISION="${GIT_REVISION:-main}"
APP_HOST="${APP_HOST:-sample-nodejs.127.0.0.1.nip.io}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The cluster must run what the repo pins, so expected versions are read from the
# files that pin them rather than repeated here.
# shellcheck disable=SC2016 # the sed pattern matches a literal ${...} in bootstrap.sh
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-$(sed -n 's/^ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-\(.*\)}"$/\1/p' "$REPO_ROOT/scripts/bootstrap.sh")}"
TRAEFIK_CHART_VERSION="$(sed -n 's/^[[:space:]]*targetRevision:[[:space:]]*\([^[:space:]]*\).*$/\1/p' "$REPO_ROOT/gitops/apps/traefik.yaml" 2>/dev/null || true)"

# Traefik's answer for a request that matches no route.
TRAEFIK_NOT_FOUND_BODY="404 page not found"

# The dev Environment's namespace, which Bootstrap creates and the
# sample-nodejs-dev Application deploys into.
APP_NAMESPACE="sample-nodejs-dev"
# The registry pull secret Bootstrap creates there (ADR-0003). The chart's
# ServiceAccount refers to it by this name.
PULL_SECRET="ghcr-pull"
REGISTRY="ghcr.io"
# The dev Environment's ArgoCD Application. It renders our chart with the dev
# values from main, where the Bump commit sets the image tag, whichever
# revision the root Application follows.
APP="sample-nodejs-dev"
APP_SOURCE="$GIT_REPO_URL gitops/charts/sample-nodejs main $APP values-dev.yaml"
# The user the image runs as (the Dockerfile's USER).
APP_UID="1000"
# The app's answer on /my-app.
APP_GREETING="Hello, World!"

tmp_dir="$(mktemp -d)"
port_forward_pid=""

# Stops a background process. In Git Bash, `kill` reaches only the MSYS stub of a
# native Windows program (and package-manager shims start the real kubectl as a
# child), so the whole Windows process tree is ended with taskkill.
stop_background() {
  local pid="$1"
  if [[ -r "/proc/${pid}/winpid" ]] && command -v taskkill >/dev/null 2>&1; then
    taskkill //F //T //PID "$(cat "/proc/${pid}/winpid")" >/dev/null 2>&1 || true
  fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

cleanup() {
  if [[ -n "$port_forward_pid" ]]; then
    stop_background "$port_forward_pid"
  fi
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

failures=0

check() {
  local name="$1"
  shift
  if "$@"; then
    printf 'PASS  %s\n' "$name"
  else
    printf 'FAIL  %s\n' "$name"
    failures=$((failures + 1))
  fi
}

k() { kubectl --context "$MINIKUBE_PROFILE" "$@"; }

# Reads one field with kubectl jsonpath. Prints nothing if the object is missing.
field() { k get "$@" 2>/dev/null | tr -d '\r' || true; }

minikube_running() {
  [[ "$(minikube status -p "$MINIKUBE_PROFILE" --format '{{.Host}}/{{.APIServer}}' 2>/dev/null | tr -d '\r\n')" == "Running/Running" ]]
}

calico_ready() {
  local desired ready
  desired="$(field -n kube-system daemonset calico-node -o jsonpath='{.status.desiredNumberScheduled}')"
  ready="$(field -n kube-system daemonset calico-node -o jsonpath='{.status.numberReady}')"
  [[ -n "$desired" && "$desired" -gt 0 && "$ready" == "$desired" ]]
}

# The metrics API needs a scrape cycle after metrics-server starts, so allow a minute.
node_metrics_served() {
  local attempt
  for attempt in 1 2 3 4 5 6; do
    k top nodes >/dev/null 2>&1 && return 0
    ((attempt < 6)) && sleep 10
  done
  return 1
}

argocd_release_pinned() {
  local release
  release="$(helm list --kube-context "$MINIKUBE_PROFILE" --namespace argocd --filter '^argocd$' --output yaml 2>/dev/null | tr -d '\r')"
  [[ -n "$ARGOCD_CHART_VERSION" ]] &&
    grep -q "chart: argo-cd-${ARGOCD_CHART_VERSION}\$" <<<"$release" &&
    grep -q 'status: deployed$' <<<"$release"
}

# Every ArgoCD Deployment and StatefulSet has all its replicas ready.
argocd_ready() {
  local workloads line
  workloads="$(field -n argocd deployments,statefulsets -o jsonpath='{range .items[*]}{.metadata.name}={.status.readyReplicas}/{.spec.replicas}{"\n"}{end}')"
  [[ -n "$workloads" ]] || return 1
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    [[ "${line#*=}" =~ ^([0-9]+)/([0-9]+)$ && "${BASH_REMATCH[1]}" == "${BASH_REMATCH[2]}" ]] || return 1
  done <<<"$workloads"
}

app_field() { field -n argocd application "$1" -o jsonpath="$2"; }

root_app_points_at_apps_dir() {
  [[ "$(app_field root '{.spec.source.repoURL} {.spec.source.path} {.spec.source.targetRevision}')" == "$GIT_REPO_URL gitops/apps $GIT_REVISION" ]]
}

root_app_synced_healthy() {
  [[ "$(app_field root '{.status.sync.status}/{.status.health.status}')" == "Synced/Healthy" ]]
}

traefik_app_pinned_chart() {
  [[ -n "$TRAEFIK_CHART_VERSION" &&
    "$(app_field traefik '{.spec.source.repoURL} {.spec.source.chart} {.spec.source.targetRevision}')" == "https://traefik.github.io/charts traefik $TRAEFIK_CHART_VERSION" ]]
}

# app_syncs_automatically <application>: automated sync with prune and
# self-heal, and namespace creation.
app_syncs_automatically() {
  [[ "$(app_field "$1" '{.spec.syncPolicy.automated.prune}/{.spec.syncPolicy.automated.selfHeal}')" == "true/true" ]] &&
    grep -qx 'CreateNamespace=true' <<<"$(app_field "$1" '{range .spec.syncPolicy.syncOptions[*]}{@}{"\n"}{end}')"
}

traefik_app_synced() {
  [[ "$(app_field traefik '{.status.sync.status}')" == "Synced" ]]
}

lb_address() { field -n traefik service traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; }

# ArgoCD rates a LoadBalancer Service Progressing until it has an address, which
# only `minikube tunnel` provides. Without the tunnel, Progressing is expected,
# provided the Service really has no address and Traefik itself is available.
traefik_app_healthy_or_waiting_for_tunnel() {
  case "$(app_field traefik '{.status.health.status}')" in
    Healthy) return 0 ;;
    Progressing)
      [[ -z "$(lb_address)" &&
        "$(field -n traefik deployment traefik -o jsonpath='{.status.availableReplicas}')" =~ ^[1-9] ]]
      ;;
    *) return 1 ;;
  esac
}

traefik_runs_pinned_chart() {
  local ready
  ready="$(field -n traefik deployment traefik -o jsonpath='{.metadata.labels.helm\.sh/chart} {.status.availableReplicas}')"
  [[ "$ready" =~ ^traefik-${TRAEFIK_CHART_VERSION}\ [1-9][0-9]*$ ]]
}

traefik_service_is_load_balancer() {
  [[ "$(field -n traefik service traefik -o jsonpath='{.spec.type}')" == "LoadBalancer" ]]
}

# Prints the HTTP status, and writes the body to the given file.
request() {
  local url="$1" body_file="$2"
  shift 2
  curl --silent --max-time 10 --output "$body_file" --write-out '%{http_code}' "$@" "$url" 2>/dev/null || true
}

answers_traefik_404() {
  local status="$1" body_file="$2"
  [[ "$status" == "404" && "$(cat "$body_file")" == "$TRAEFIK_NOT_FOUND_BODY" ]]
}

answers_app_greeting() {
  local status="$1" body_file="$2"
  [[ "$status" == "200" && "$(cat "$body_file")" == "$APP_GREETING" ]]
}

# Port-forwards the Traefik Service once (kubectl picks a free local port) and
# sets traefik_port. The cleanup at exit stops it. Must not run in a subshell.
traefik_port=""
start_traefik_port_forward() {
  [[ -n "$traefik_port" ]] && return 0
  local log="$tmp_dir/port-forward.log" attempt
  k -n traefik port-forward service/traefik :80 >"$log" 2>&1 &
  port_forward_pid=$!
  for attempt in $(seq 1 20); do
    traefik_port="$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9]*\) .*/\1/p' "$log" | head -n 1)"
    [[ -n "$traefik_port" ]] && return 0
    sleep 1
  done
  return 1
}

# A request for the app host's root path, which has no route.
traefik_404_through_port_forward() {
  local body="$tmp_dir/port-forward-root.body" status
  start_traefik_port_forward || return 1
  status="$(request "http://127.0.0.1:${traefik_port}/" "$body" --header "Host: ${APP_HOST}")"
  answers_traefik_404 "$status" "$body"
}

app_greets_through_port_forward() {
  local body="$tmp_dir/port-forward-my-app.body" status
  start_traefik_port_forward || return 1
  status="$(request "http://127.0.0.1:${traefik_port}/my-app" "$body" --header "Host: ${APP_HOST}")"
  answers_app_greeting "$status" "$body"
}

traefik_404_through_tunnel() {
  local body="$tmp_dir/tunnel-root.body" status
  status="$(request "http://${APP_HOST}/" "$body")"
  answers_traefik_404 "$status" "$body" &&
    [[ "$(app_field traefik '{.status.health.status}')" == "Healthy" ]]
}

app_greets_through_tunnel() {
  local body="$tmp_dir/tunnel-my-app.body" status
  status="$(request "http://${APP_HOST}/my-app" "$body")"
  answers_app_greeting "$status" "$body"
}

# Every app pod is Running, and the app process in it (PID 1 of the app
# container) runs as the image's uid. The uid is read from the process itself,
# not from the pod spec.
app_pods_run_as_app_uid() {
  local pods pod phase uid
  pods="$(field -n "$APP_NAMESPACE" pods -l "app.kubernetes.io/instance=$APP" -o jsonpath='{range .items[*]}{.metadata.name} {.status.phase}{"\n"}{end}')"
  [[ -n "$pods" ]] || return 1
  while read -r pod phase; do
    [[ -z "$pod" ]] && continue
    [[ "$phase" == "Running" ]] || return 1
    uid="$(k -n "$APP_NAMESPACE" exec "$pod" -c app -- cat /proc/1/status </dev/null 2>/dev/null |
      tr -d '\r' | sed -n 's/^Uid:[[:space:]]*\([0-9]*\).*/\1/p')"
    [[ "$uid" == "$APP_UID" ]] || return 1
  done <<<"$pods"
}

# Bootstrap labels the app namespace so that every pod in it must meet the
# restricted Pod Security profile (enforce), and a workload that would not is
# also recorded (audit) and warned about when it is applied (warn).
app_namespace_restricted() {
  local labels='{.metadata.labels.pod-security\.kubernetes\.io/enforce} {.metadata.labels.pod-security\.kubernetes\.io/audit} {.metadata.labels.pod-security\.kubernetes\.io/warn}'
  [[ "$(field namespace "$APP_NAMESPACE" -o jsonpath="$labels")" == "restricted restricted restricted" ]]
}

# The pull secret is a registry credential with an entry for the registry. Its
# content goes from kubectl through base64 to grep in one pipe, so the token
# is never held in a variable or printed.
pull_secret_for_registry() {
  [[ "$(field -n "$APP_NAMESPACE" secret "$PULL_SECRET" -o jsonpath='{.type}')" == "kubernetes.io/dockerconfigjson" ]] &&
    k -n "$APP_NAMESPACE" get secret "$PULL_SECRET" -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null |
    base64 --decode 2>/dev/null | grep -qF "\"${REGISTRY}\""
}

app_renders_dev_chart() {
  [[ "$(app_field "$APP" '{.spec.source.repoURL} {.spec.source.path} {.spec.source.targetRevision} {.spec.source.helm.releaseName} {.spec.source.helm.valueFiles[*]}')" == "$APP_SOURCE" ]]
}

app_deploys_to_app_namespace() {
  [[ "$(app_field "$APP" '{.spec.destination.server} {.spec.destination.namespace}')" == "https://kubernetes.default.svc $APP_NAMESPACE" ]]
}

app_synced_healthy() {
  [[ "$(app_field "$APP" '{.status.sync.status}/{.status.health.status}')" == "Synced/Healthy" ]]
}

check "minikube profile '$MINIKUBE_PROFILE' is running" minikube_running
check "Calico CNI is ready on every node" calico_ready
check "metrics-server serves node metrics (kubectl top nodes)" node_metrics_served
check "ArgoCD Helm release is deployed at chart version ${ARGOCD_CHART_VERSION:-<unknown>}" argocd_release_pinned
check "ArgoCD workloads are ready" argocd_ready
check "root Application follows gitops/apps at '$GIT_REVISION' of $GIT_REPO_URL" root_app_points_at_apps_dir
check "root Application is Synced and Healthy" root_app_synced_healthy
check "traefik Application uses the official chart at ${TRAEFIK_CHART_VERSION:-<unknown>}" traefik_app_pinned_chart
check "traefik Application syncs automatically with prune, self-heal and namespace creation" app_syncs_automatically traefik
check "traefik Application is Synced" traefik_app_synced
check "traefik Application is Healthy (or Progressing only until the tunnel gives the LoadBalancer an address)" traefik_app_healthy_or_waiting_for_tunnel
check "Traefik runs chart ${TRAEFIK_CHART_VERSION:-<unknown>} with available replicas" traefik_runs_pinned_chart
check "Traefik Service is of type LoadBalancer" traefik_service_is_load_balancer
check "Traefik answers its own 404 for Host ${APP_HOST} (port-forward)" traefik_404_through_port_forward
check "namespace ${APP_NAMESPACE} enforces, audits and warns on the restricted Pod Security profile" app_namespace_restricted
check "pull secret ${PULL_SECRET} in ${APP_NAMESPACE} is a registry credential for ${REGISTRY}" pull_secret_for_registry
check "${APP} Application renders gitops/charts/sample-nodejs at main with values-dev.yaml" app_renders_dev_chart
check "${APP} Application deploys into namespace ${APP_NAMESPACE}" app_deploys_to_app_namespace
check "${APP} Application syncs automatically with prune, self-heal and namespace creation" app_syncs_automatically "$APP"
check "${APP} Application is Synced and Healthy" app_synced_healthy
check "app pods in ${APP_NAMESPACE} are Running, with the app process as uid ${APP_UID}" app_pods_run_as_app_uid
check "/my-app answers \"${APP_GREETING}\" through Traefik for Host ${APP_HOST} (port-forward)" app_greets_through_port_forward

if [[ -n "$(lb_address)" ]]; then
  check "http://${APP_HOST}/ answers Traefik's 404 through the tunnel, and traefik is Healthy" traefik_404_through_tunnel
  check "http://${APP_HOST}/my-app answers \"${APP_GREETING}\" through the tunnel" app_greets_through_tunnel
else
  printf 'SKIP  http://%s/ and /my-app through the tunnel (run "minikube tunnel -p %s" in another terminal, then re-run)\n' "$APP_HOST" "$MINIKUBE_PROFILE"
fi

if ((failures > 0)); then
  printf '\n%d check(s) failed.\n' "$failures"
  exit 1
fi
printf '\nAll checks passed.\n'
