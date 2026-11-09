#!/usr/bin/env bash
# Chart Gate: lints the Helm chart, renders it with the dev values (once as
# is, once with Ingress TLS on), validates the rendered manifests against the
# Kubernetes schemas, and checks what the rendered manifests promise: only the
# Public paths behind the Ingress, probes on the app's health endpoints, the
# ports, the pod hardening, the ServiceAccount, the standard labels, and that
# the TLS flag adds the TLS section and the cert-manager issuer annotation and
# nothing else.
#
# The `chart` job in .github/workflows/pr.yml runs this script, so a local run
# checks exactly what CI checks. Prints PASS or FAIL per check and exits
# non-zero if any check fails.
#
# Needs helm (v4), kubeconform and yq (mikefarah, v4) on PATH.
#
# Variables:
#   KUBERNETES_VERSION  Kubernetes version whose schemas kubeconform uses
#                       (default: 1.35.1, the version Bootstrap runs)
set -euo pipefail

KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.35.1}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$REPO_ROOT/gitops/charts/sample-nodejs"
DEV_VALUES="$CHART_DIR/values-dev.yaml"
# The same release name ArgoCD uses for the dev Environment.
RELEASE="sample-nodejs-dev"
# Ingress TLS is off by default. A second render turns it on with this
# cert-manager ClusterIssuer name, which the checks then expect on the Ingress.
TLS_ISSUER="check-chart-issuer"
TLS_ON=(--set ingress.tls.enabled=true --set-string "ingress.tls.clusterIssuer=$TLS_ISSUER")

for tool in helm kubeconform yq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'error: %s is not on PATH\n' "$tool" >&2
    exit 2
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
rendered="$tmp_dir/dev.yaml"
tls_rendered="$tmp_dir/dev-tls.yaml"

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() {
  printf 'FAIL  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '      %s\n' "$2"
  failures=$((failures + 1))
}

# Lint and render first: every later check reads the rendered manifests.
if helm lint --strict "$CHART_DIR" -f "$DEV_VALUES"; then
  pass "helm lint --strict"
else
  fail "helm lint --strict"
fi

if helm lint --strict "$CHART_DIR" -f "$DEV_VALUES" "${TLS_ON[@]}"; then
  pass "helm lint --strict with Ingress TLS on"
else
  fail "helm lint --strict with Ingress TLS on"
fi

if helm template "$RELEASE" "$CHART_DIR" -f "$DEV_VALUES" >"$rendered"; then
  pass "render with the dev values"
else
  fail "render with the dev values"
  exit 1
fi

if helm template "$RELEASE" "$CHART_DIR" -f "$DEV_VALUES" "${TLS_ON[@]}" >"$tls_rendered"; then
  pass "render with the dev values and Ingress TLS on"
else
  fail "render with the dev values and Ingress TLS on"
  exit 1
fi

# With no issuer, cert-manager would ignore the Ingress and no certificate
# would ever arrive, so the chart must refuse to render instead.
if render_error="$(helm template "$RELEASE" "$CHART_DIR" -f "$DEV_VALUES" --set ingress.tls.enabled=true 2>&1 >/dev/null)"; then
  fail "Ingress TLS on without a ClusterIssuer does not render" "it rendered"
elif [[ "$render_error" != *ingress.tls.clusterIssuer* ]]; then
  fail "Ingress TLS on without a ClusterIssuer does not render" "failed for another reason: $render_error"
else
  pass "Ingress TLS on without a ClusterIssuer does not render"
fi

if kubeconform -strict -summary -kubernetes-version "$KUBERNETES_VERSION" "$rendered" "$tls_rendered"; then
  pass "kubeconform -strict against Kubernetes $KUBERNETES_VERSION, Ingress TLS off and on"
else
  fail "kubeconform -strict against Kubernetes $KUBERNETES_VERSION, Ingress TLS off and on"
fi

# What the rendered dev manifests must say. The expected values come from the
# spec and the app, not from the chart, so a chart change cannot quietly move
# them. The image tag is the one exception: the Bump commit changes it.
IMAGE_REPOSITORY="ghcr.io/sela27/sample-nodejs"
IMAGE_TAG="$(yq '.image.tag' "$DEV_VALUES" | tr -d '\r')"
CONTAINER_PORT="8080"
SERVICE_PORT="80"
DEV_HOST="sample-nodejs.127.0.0.1.nip.io"
# The Public paths (GLOSSARY.md), sorted. Every other app path stays internal.
PUBLIC_PATHS="/about /my-app"
# The user and group the image runs as (the Dockerfile's USER).
APP_UID="1000"
APP_GID="1000"
# The registry pull secret Bootstrap creates in the app namespace (ADR-0003).
# Bootstrap and the chart must agree on this name.
PULL_SECRET="ghcr-pull"

# Evaluates a yq expression over all rendered documents at once.
q() { yq ea "$1" "$rendered" | tr -d '\r'; }

expect() {
  local name="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then
    pass "$name"
  else
    fail "$name" "expected: $want | got: $got"
  fi
}

# Resolves a port reference (number or container port name) to the number the
# app container listens on.
container_port_number() {
  local ref="$1"
  if [[ "$ref" =~ ^[0-9]+$ ]]; then
    printf '%s' "$ref"
  else
    q "select(.kind == \"Deployment\") | .spec.template.spec.containers[0].ports[] | select(.name == \"$ref\") | .containerPort"
  fi
}

# Resolves a port reference (number or Service port name) to a Service port number.
service_port_number() {
  local ref="$1"
  if [[ "$ref" =~ ^[0-9]+$ ]]; then
    printf '%s' "$ref"
  else
    q "select(.kind == \"Service\") | .spec.ports[] | select(.name == \"$ref\") | .port"
  fi
}

deployment='select(.kind == "Deployment")'
container="$deployment | .spec.template.spec.containers[0]"

expect "one Deployment" "1" "$(q "[$deployment] | length")"
expect "dev image tag is a fixed tag" "fixed" \
  "$([[ -n "$IMAGE_TAG" && "$IMAGE_TAG" != "null" && "$IMAGE_TAG" != "latest" ]] && echo fixed || echo "'$IMAGE_TAG'")"
expect "container image" "$IMAGE_REPOSITORY:$IMAGE_TAG" "$(q "$container | .image")"
expect "container ports" "$CONTAINER_PORT" "$(q "[$container | .ports[].containerPort] | join(\" \")")"

for probe in startupProbe:/live livenessProbe:/live readinessProbe:/ready; do
  kind="${probe%%:*}" path="${probe#*:}"
  expect "$kind path" "$path" "$(q "$container | .$kind.httpGet.path")"
  expect "$kind port" "$CONTAINER_PORT" "$(container_port_number "$(q "$container | .$kind.httpGet.port")")"
done

for resource in requests.cpu requests.memory limits.cpu limits.memory; do
  value="$(q "$container | .resources.$resource")"
  expect "resources.$resource is set" "set" "$([[ -n "$value" && "$value" != "null" ]] && echo set || echo unset)"
done

# The restricted Pod Security profile, plus a read-only root filesystem.
# A setting can sit on the pod or on the container; the container's own value
# wins, as in the kubelet, so moving a setting between the two keeps it passing.
effective() {
  q "$deployment | .spec.template.spec as \$pod
    | (\$pod | .containers[0].securityContext.$1) as \$own
    | if \$own == null then (\$pod | .securityContext.$1) else \$own end"
}

expect "runAsNonRoot" "true" "$(effective runAsNonRoot)"
expect "runAsUser is the image's uid" "$APP_UID" "$(effective runAsUser)"
expect "runAsGroup is the image's gid" "$APP_GID" "$(effective runAsGroup)"
expect "seccomp profile" "RuntimeDefault" "$(effective seccompProfile.type)"
# Container-only settings.
expect "readOnlyRootFilesystem" "true" "$(q "$container | .securityContext.readOnlyRootFilesystem")"
expect "allowPrivilegeEscalation" "false" "$(q "$container | .securityContext.allowPrivilegeEscalation")"
expect "capabilities dropped" "ALL" "$(q "[$container | .securityContext.capabilities.drop[]] | join(\" \")")"
expect "capabilities added" "none" \
  "$(q "[$container | .securityContext.capabilities.add[]] | join(\" \")" | sed 's/^$/none/')"

# A dedicated ServiceAccount with no Kubernetes API token, which hands the pods
# the registry pull secret.
serviceaccount='select(.kind == "ServiceAccount")'

expect "one ServiceAccount" "1" "$(q "[$serviceaccount] | length")"
expect "pods run under the ServiceAccount" "$(q "$serviceaccount | .metadata.name")" \
  "$(q "$deployment | .spec.template.spec.serviceAccountName")"
expect "ServiceAccount does not automount its token" "false" "$(q "$serviceaccount | .automountServiceAccountToken")"
# The pod's own setting wins over the ServiceAccount's.
pod_token="$(q "$deployment | .spec.template.spec.automountServiceAccountToken")"
[[ "$pod_token" == "null" ]] && pod_token="$(q "$serviceaccount | .automountServiceAccountToken")"
expect "pods mount no API token" "false" "$pod_token"
expect "ServiceAccount pull secret" "$PULL_SECRET" "$(q "[$serviceaccount | .imagePullSecrets[].name] | join(\" \")")"

service='select(.kind == "Service")'

expect "one Service" "1" "$(q "[$service] | length")"
expect "Service type" "ClusterIP" "$(q "$service | .spec.type")"
expect "Service ports" "$SERVICE_PORT" "$(q "[$service | .spec.ports[].port] | join(\" \")")"
expect "Service port $SERVICE_PORT reaches the container port" "$CONTAINER_PORT" \
  "$(container_port_number "$(q "$service | .spec.ports[] | select(.port == $SERVICE_PORT) | .targetPort")")"

# Every selector label must be on the pod template, or the Service has no endpoints.
selector="$(q "$service | .spec.selector | to_entries | .[] | .key + \"=\" + .value" | sort)"
pod_labels="$(q "$deployment | .spec.template.metadata.labels | to_entries | .[] | .key + \"=\" + .value" | sort)"
unmatched="$(comm -23 <(printf '%s\n' "$selector") <(printf '%s\n' "$pod_labels"))"
expect "Service selects the app pods" "selects" \
  "$([[ -n "$selector" && -z "$unmatched" ]] && echo selects || echo "selector '${selector//$'\n'/,}' not on pods")"

ingress='select(.kind == "Ingress")'
backends="$ingress | .spec.rules[].http.paths[].backend.service"

expect "one Ingress" "1" "$(q "[$ingress] | length")"
expect "Ingress class" "traefik" "$(q "$ingress | .spec.ingressClassName")"
# ADR-0002: no controller-specific annotations, so the controller can be swapped.
expect "Ingress has no annotations" "0" "$(q "$ingress | .metadata.annotations // {} | length")"
# Ingress TLS is off by default.
expect "Ingress has no TLS section" "0" "$(q "$ingress | .spec.tls // [] | length")"
expect "Ingress hosts" "$DEV_HOST" "$(q "[$ingress | .spec.rules[].host] | join(\" \")")"
expect "Ingress paths are the Public paths only" "$PUBLIC_PATHS" \
  "$(q "[$ingress | .spec.rules[].http.paths[].path] | sort | join(\" \")")"
expect "Ingress path types" "Prefix" "$(q "[$ingress | .spec.rules[].http.paths[].pathType] | unique | join(\" \")")"
expect "Ingress backends are the Service" "$(q "$service | .metadata.name")" \
  "$(q "[$backends | .name] | unique | join(\" \")")"
for port_ref in $(q "[$backends | .port.number // .port.name] | unique | .[]"); do
  expect "Ingress backend port $port_ref is Service port $SERVICE_PORT" "$SERVICE_PORT" "$(service_port_number "$port_ref")"
done

# Ingress TLS on (ingress.tls.enabled). cert-manager sees the issuer
# annotation, issues a certificate for the host in the TLS section and stores
# it in the secret that section names; Traefik serves it.
q_tls() { yq ea "$1" "$tls_rendered" | tr -d '\r'; }

# The flag touches nothing else: without the Ingress's TLS section and
# annotations, the TLS-on render is the default render, object for object.
without_tls='with(select(.kind == "Ingress"); del(.spec.tls) | del(.metadata.annotations))'
tls_diff="$(diff <(yq "$without_tls" "$rendered") <(yq "$without_tls" "$tls_rendered") || true)"
expect "TLS on: only the Ingress's TLS section and annotations change" "no other change" \
  "$([[ -z "$tls_diff" ]] && echo "no other change" || echo "${tls_diff//$'\n'/ | }")"

expect "TLS on: one TLS entry" "1" "$(q_tls "[$ingress | .spec.tls[]] | length")"
expect "TLS on: TLS hosts" "$DEV_HOST" "$(q_tls "[$ingress | .spec.tls[].hosts[]] | join(\" \")")"
# cert-manager writes the certificate into this secret, and Traefik serves it.
secret_name="$(q_tls "$ingress | .spec.tls[0].secretName")"
expect "TLS on: TLS secret name is set" "set" \
  "$([[ -n "$secret_name" && "$secret_name" != "null" ]] && echo set || echo unset)"
# The one annotation the flag adds: it tells cert-manager which ClusterIssuer
# signs the certificate. It is read by cert-manager, not by the Ingress
# controller, so ADR-0002 still holds.
expect "TLS on: Ingress annotations" "cert-manager.io/cluster-issuer=$TLS_ISSUER" \
  "$(q_tls "[$ingress | .metadata.annotations // {} | to_entries | .[] | .key + \"=\" + .value] | join(\" \")")"

# Standard app.kubernetes.io labels, on every object and on the pods. The outer
# parentheses matter: in yq, `or` binds looser than `|`.
labels_wrong="((.\"app.kubernetes.io/name\" != \"sample-nodejs\")
  or (.\"app.kubernetes.io/instance\" != \"$RELEASE\")
  or (.\"app.kubernetes.io/version\" != \"$IMAGE_TAG\")
  or (.\"app.kubernetes.io/managed-by\" != \"Helm\"))"
unlabeled="$(q "[select(. != null) | select(.metadata.labels | $labels_wrong) | .kind + \"/\" + .metadata.name] | join(\" \")")"
expect "standard labels on every object" "none missing" "${unlabeled:-none missing}"
unlabeled="$(q "[$deployment | select(.spec.template.metadata.labels | $labels_wrong) | .metadata.name] | join(\" \")")"
expect "standard labels on the pods" "none missing" "${unlabeled:-none missing}"

if ((failures > 0)); then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nAll checks passed\n'
