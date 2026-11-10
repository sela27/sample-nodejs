#!/usr/bin/env bash
# IaC Gate: scans the Dockerfile and the Helm chart for misconfigurations with
# Trivy, and fails on any HIGH or CRITICAL finding that .trivyignore does not
# list.
#
# The chart is scanned as ArgoCD applies it to the dev Environment: rendered
# by helm with the dev values and the dev release name, not as raw templates.
# So a finding reflects what would run, including what only the values decide,
# and it names the rendered object.
#
# Trivy uses the misconfiguration checks embedded in its own binary: it does
# not download the checks bundle (--skip-check-update), and it gets an empty
# cache of its own, so no bundle cached by an earlier run is used instead. The
# checks are then pinned with the binary's version and SHA-256, the scan needs
# no network, and a local run applies the same checks as CI. Upgrading Trivy
# upgrades the checks.
#
# The `iac-gate` job in .github/workflows/pr.yml runs this script, so a local
# run checks exactly what CI checks. Exits 1 on any finding it fails on, and 2
# if a tool is missing.
#
# Needs helm (v4) and trivy (0.76.2, the version CI pins) on PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHART_DIR="$REPO_ROOT/gitops/charts/sample-nodejs"
DEV_VALUES="$CHART_DIR/values-dev.yaml"
# The same release name ArgoCD uses for the dev Environment.
RELEASE="sample-nodejs-dev"

for tool in helm trivy; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'error: %s is not on PATH\n' "$tool" >&2
    exit 2
  fi
done

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
# The scan target: the Dockerfile and the rendered chart side by side, so one
# Trivy run covers both and its report names each file.
target="$tmp_dir/target"
mkdir "$target"
cp "$REPO_ROOT/Dockerfile" "$target/Dockerfile"
helm template "$RELEASE" "$CHART_DIR" -f "$DEV_VALUES" >"$target/$RELEASE.yaml"

trivy --version
# With an empty cache, Trivy logs "Falling back to embedded checks" at ERROR
# level. That is the intended path, not a failure.
printf 'note: the "Falling back to embedded checks" log line below is expected\n'
trivy config \
  --misconfig-scanners dockerfile,kubernetes \
  --skip-check-update \
  --cache-dir "$tmp_dir/cache" \
  --severity HIGH,CRITICAL \
  --ignorefile "$REPO_ROOT/.trivyignore" \
  --format table \
  --exit-code 1 \
  "$target"
