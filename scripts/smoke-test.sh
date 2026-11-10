#!/usr/bin/env bash
# Smoke test of a Deploy, from outside the cluster, through the Ingress.
# The Public paths must answer and the internal paths must not:
#
#   /my-app                          200 and "Hello, World!"
#   /about                           200
#   /classified, /metrics, /ready    404
#
# Prints PASS or FAIL per path and exits non-zero if any path fails.
#
# By default the requests go to http://$APP_HOST, which `minikube tunnel`
# exposes on localhost. Without the tunnel, pass --port-forward: the script then
# port-forwards the Traefik Service itself and sends the requests to that port
# with the Host header, so Traefik routes them exactly as it routes the tunnel's.
#
# Over HTTPS (a BASE_URL that starts with https://, or --https with
# --port-forward) the Ingress serves a self-signed certificate from
# cert-manager. The script verifies it against the CA in the certificate's
# secret (read with kubectl), or against the file in CA_CERT, and the
# certificate must be valid for APP_HOST: the requests go to https://$APP_HOST
# and are only routed to BASE_URL's address (curl --connect-to), so the name
# checked is the Ingress host, not 127.0.0.1. --insecure skips the
# verification altogether: use it only to see the paths answer when no CA is
# at hand, because it also accepts a certificate from the wrong server.
#
# Usage: scripts/smoke-test.sh [--port-forward [--https]] [--insecure]
#
#   --port-forward  Port-forward the Traefik Service instead of using the
#                   tunnel: port 80, or port 443 with --https.
#   --https         With --port-forward, forward Traefik's websecure port (443)
#                   and use HTTPS. Without --port-forward, set BASE_URL instead.
#   --insecure      HTTPS only: do not verify the certificate.
#
# Variables:
#   APP_HOST          Ingress host of the Environment, sent as the Host header
#                     (default: sample-nodejs.127.0.0.1.nip.io)
#   BASE_URL          Scheme, host and port the requests go to
#                     (default: http://$APP_HOST; not used with --port-forward)
#   CA_CERT           HTTPS only: file with the CA to trust, instead of reading
#                     it from the secret
#   TLS_NAMESPACE     Namespace of the certificate's secret (default: sample-nodejs-dev)
#   TLS_SECRET        The certificate's secret (default: sample-nodejs-dev-tls)
#   MINIKUBE_PROFILE  kubectl context for --port-forward and the secret
#                     (default: minikube)
set -euo pipefail

APP_HOST="${APP_HOST:-sample-nodejs.127.0.0.1.nip.io}"
MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
TLS_NAMESPACE="${TLS_NAMESPACE:-sample-nodejs-dev}"
TLS_SECRET="${TLS_SECRET:-sample-nodejs-dev-tls}"

# The app's answer on /my-app.
APP_GREETING="Hello, World!"

usage() {
  printf 'Usage: %s [--port-forward [--https]] [--insecure]\n' "$0" >&2
  exit 2
}

port_forward=false
use_https=false
insecure=false
for arg in "$@"; do
  case "$arg" in
    --port-forward) port_forward=true ;;
    --https) use_https=true ;;
    --insecure) insecure=true ;;
    *) usage ;;
  esac
done
if [[ "$port_forward" == true && -n "${BASE_URL:-}" ]]; then
  printf 'Set BASE_URL or pass --port-forward, not both.\n' >&2
  exit 2
fi
if [[ "$use_https" == true && "$port_forward" == false ]]; then
  printf -- '--https goes with --port-forward; otherwise set BASE_URL=https://...\n' >&2
  exit 2
fi

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

# Port-forwards the Traefik Service (kubectl picks a free local port) and
# prints the local port. The cleanup at exit stops it.
start_traefik_port_forward() {
  local log="$tmp_dir/port-forward.log" attempt port
  kubectl --context "$MINIKUBE_PROFILE" -n traefik port-forward service/traefik ":${forward_port}" >"$log" 2>&1 &
  port_forward_pid=$!
  for attempt in $(seq 1 20); do
    port="$(sed -n 's/^Forwarding from 127\.0\.0\.1:\([0-9]*\) .*/\1/p' "$log" | head -n 1)"
    if [[ -n "$port" ]]; then
      traefik_port="$port"
      return 0
    fi
    sleep 1
  done
  cat "$log" >&2
  return 1
}

if [[ "$port_forward" == true ]]; then
  traefik_port=""
  # Traefik's web port is 80 and its websecure port 443 on the Service.
  forward_port=80
  [[ "$use_https" == true ]] && forward_port=443
  if ! start_traefik_port_forward; then
    printf 'FAIL  could not port-forward service/traefik in context %s\n' "$MINIKUBE_PROFILE"
    exit 1
  fi
  scheme=http
  [[ "$use_https" == true ]] && scheme=https
  BASE_URL="${scheme}://127.0.0.1:${traefik_port}"
fi
BASE_URL="${BASE_URL:-http://${APP_HOST}}"
BASE_URL="${BASE_URL%/}"

# curl options and the URL prefix of every request. Over HTTP the request goes
# to BASE_URL with the Host header. Over HTTPS it goes to https://$APP_HOST,
# routed to BASE_URL's address, so the certificate is checked for the Ingress
# host and the SNI is right.
curl_options=(--header "Host: ${APP_HOST}")
request_prefix="$BASE_URL"
if [[ "$BASE_URL" == https://* ]]; then
  if [[ "$insecure" == true ]]; then
    curl_options+=(--insecure)
  else
    ca_file="${CA_CERT:-}"
    if [[ -z "$ca_file" ]]; then
      ca_file="$tmp_dir/ca.pem"
      # A self-signed certificate is its own CA: cert-manager puts it in ca.crt
      # of the secret, and in tls.crt, which is the fallback.
      for key in 'ca\.crt' 'tls\.crt'; do
        kubectl --context "$MINIKUBE_PROFILE" -n "$TLS_NAMESPACE" get secret "$TLS_SECRET" \
          -o "jsonpath={.data.${key}}" 2>/dev/null | base64 -d >"$ca_file" 2>/dev/null || true
        [[ -s "$ca_file" ]] && break
      done
    fi
    if [[ ! -s "$ca_file" ]]; then
      printf 'FAIL  no CA to verify the certificate with: secret %s/%s has none (or set CA_CERT, or pass --insecure)\n' "$TLS_NAMESPACE" "$TLS_SECRET"
      exit 1
    fi
    curl_options+=(--cacert "$ca_file")
  fi
  address="${BASE_URL#https://}"
  address="${address%%/*}"
  [[ "$address" == *:* ]] || address="${address}:443"
  curl_options+=(--connect-to "${APP_HOST}::${address}")
  request_prefix="https://${APP_HOST}"
fi

printf 'Smoke test of %s through %s\n\n' "$APP_HOST" "$BASE_URL"

failures=0
unanswered=0

# Prints an answer as `<status> "<body>"`, or as no response. The body is cut to
# one short line, so a stray page cannot flood the terminal.
describe() {
  local status="$1" body_file="$2" want_body="$3"
  if [[ "$status" == "000" ]]; then
    printf 'no response'
  elif [[ "$want_body" == true ]]; then
    printf '%s "%s"' "$status" "$(head -c 80 "$body_file" | tr -c '[:print:]' ' ' | sed 's/ *$//')"
  else
    printf '%s' "$status"
  fi
}

# expect <path> <status> [<body>]: one request to the path, with the Host header,
# and a PASS or FAIL line for it.
expect() {
  local path="$1" want_status="$2" body_file="$tmp_dir/answer" status want got
  local check_body=false
  [[ $# -ge 3 ]] && check_body=true
  status="$(curl --silent --max-time 10 --output "$body_file" --write-out '%{http_code}' \
    "${curl_options[@]}" "${request_prefix}${path}" 2>/dev/null || true)"
  [[ -f "$body_file" ]] || : >"$body_file"

  if [[ "$check_body" == true ]]; then
    want="$want_status \"$3\""
  else
    want="$want_status"
  fi
  got="$(describe "$status" "$body_file" "$check_body")"

  if [[ "$status" == "$want_status" ]] && { [[ "$check_body" == false ]] || [[ "$(cat "$body_file")" == "$3" ]]; }; then
    printf 'PASS  %-12s %s\n' "$path" "$got"
  else
    printf 'FAIL  %-12s expected %s, got %s\n' "$path" "$want" "$got"
    failures=$((failures + 1))
    [[ "$status" == "000" ]] && unanswered=$((unanswered + 1))
  fi
  rm -f "$body_file"
}

# The Public paths.
expect /my-app 200 "$APP_GREETING"
expect /about 200
# Internal paths: the app serves each of them, but they have no route.
expect /classified 404
expect /metrics 404
expect /ready 404

if ((failures > 0)); then
  printf '\n%d path(s) failed.\n' "$failures"
  if ((unanswered > 0)) && [[ "$port_forward" == false ]]; then
    printf 'Nothing answered at %s. Start "minikube tunnel -p %s" in another terminal, or re-run with --port-forward.\n' "$BASE_URL" "$MINIKUBE_PROFILE"
  fi
  exit 1
fi
printf '\nAll paths passed.\n'
