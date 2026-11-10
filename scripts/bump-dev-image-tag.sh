#!/usr/bin/env bash
# Points the dev Environment at a Release's image: sets `image.tag` in the
# chart's dev values to the given version and changes no other line, so the
# Bump commit's diff is that one line. The `bump` job in
# .github/workflows/release.yml runs it, then commits and pushes the result.
#
# Usage: scripts/bump-dev-image-tag.sh <version>
#
# The version is the Release version without the `v`, for example 1.2.3, as
# the image is tagged in GHCR.
#
# The file is rewritten in place only after the edit succeeded. If the tag
# already is the version, the file is left as it is and the script says so.
#
# Runs from Git Bash on Windows and natively on Linux and macOS. Needs only
# bash and awk.
#
# Variables:
#   DEV_VALUES  values file to change (default: the chart's values-dev.yaml)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_VALUES="${DEV_VALUES:-$REPO_ROOT/gitops/charts/sample-nodejs/values-dev.yaml}"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 1 ]] || die "usage: $0 <version>"
version="$1"
# MAJOR.MINOR.PATCH with no leading zeros, nothing before or after it: the
# form semantic-release gives a Release on main.
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] ||
  die "malformed version '$version': expected MAJOR.MINOR.PATCH, such as 1.2.3, without a leading v"
[[ -f "$DEV_VALUES" ]] || die "$DEV_VALUES does not exist"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Replaces the value of `tag:` inside the top-level `image:` block, keeping
# its indentation. Exits 3 unless exactly one such line exists, so a reshaped
# file fails here instead of leaving nothing to commit.
awk -v version="$version" '
  /^[^[:space:]#]/ { inimage = ($0 ~ /^image:[[:space:]]*(#.*)?$/) }
  inimage && /^[[:space:]]+tag:/ {
    match($0, /^[[:space:]]+/)
    $0 = substr($0, 1, RLENGTH) "tag: " version
    found++
  }
  { print }
  END { exit (found == 1 ? 0 : 3) }
' "$DEV_VALUES" >"$tmp" ||
  die "expected exactly one image.tag line under the top-level image: key in $DEV_VALUES"

cat "$tmp" >"$DEV_VALUES"
printf 'Set the dev image tag to %s in %s\n' "$version" "$DEV_VALUES"
