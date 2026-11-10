#!/usr/bin/env bash
# Dependabot config check: validates .github/dependabot.yml before it lands.
# GitHub reads the file only once it is on main, and reports a mistake there
# only in the repo's Dependabot tab, so a broken config would otherwise go
# unnoticed while no update PRs arrive.
#
# First the file is validated against the Dependabot configuration schema
# that check-jsonschema vendors from SchemaStore, which catches an unknown
# key, a wrong type or a missing required field. Then it is checked against
# this repo's update policy, written below as small JSON Schemas:
#
#   - npm in /, npm in /release, docker in / and github-actions in / are each
#     covered, on a weekly schedule.
#   - Only the app's production npm dependencies use a releasing prefix,
#     `fix(deps)`. The app's dev dependencies, the release tooling, the base
#     image and the actions use `chore(deps)` or `ci(deps)`, which produce no
#     Release (.releaserc.yaml).
#   - Every entry sets its prefix explicitly. Without one, Dependabot copies
#     the style of recent commits, which could be a releasing `fix`.
#   - No entry sets `include: scope`, which would append a second scope after
#     the one in the prefix, as in `fix(deps)(deps)`.
#   - Every group of the app's npm updates is limited to one dependency type,
#     because a grouped PR with any production dependency in it takes the
#     production prefix and would release the dev updates in it too.
#
# The expected values come from the spec, not from the config, so a config
# change cannot quietly move them. Prints PASS or FAIL per check and exits
# non-zero if any check fails.
#
# Needs uv on PATH. uvx runs check-jsonschema at the pinned version below,
# with its dependencies resolved as they were published on the pinned date,
# without installing anything.
#
# Usage: scripts/check-dependabot.sh [config]   (default: .github/dependabot.yml)
set -euo pipefail

CHECK_JSONSCHEMA_VERSION="0.39.0"
RESOLVE_AS_OF="2026-11-01T00:00:00Z"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$REPO_ROOT/.github/dependabot.yml}"

if ! command -v uvx >/dev/null 2>&1; then
  printf 'error: uvx (uv) is not on PATH\n' >&2
  exit 2
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() {
  printf 'FAIL  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '%s\n' "$2" | sed 's/^/      /'
  failures=$((failures + 1))
}

check_jsonschema() {
  uvx --quiet --exclude-newer "$RESOLVE_AS_OF" \
    --from "check-jsonschema==$CHECK_JSONSCHEMA_VERSION" check-jsonschema "$@"
}

if [[ ! -f "$CONFIG" ]]; then
  fail "config exists" "no file at $CONFIG"
  exit 1
fi
pass "config exists"

if output="$(check_jsonschema --builtin-schema vendor.dependabot "$CONFIG" 2>&1)"; then
  pass "matches the Dependabot configuration schema (check-jsonschema $CHECK_JSONSCHEMA_VERSION)"
else
  fail "matches the Dependabot configuration schema (check-jsonschema $CHECK_JSONSCHEMA_VERSION)" "$output"
fi

# Validates the config against the policy schema $2 and reports it as $1.
expect_schema() {
  local name="$1" schema="$tmp_dir/policy.json" output
  printf '%s\n' "$2" >"$schema"
  if output="$(check_jsonschema --schemafile "$schema" "$CONFIG" 2>&1)"; then
    pass "$name"
  else
    fail "$name" "$output"
  fi
}

# Checks that the config has an update entry for ecosystem $2 in directory
# $3, on a weekly schedule, whose remaining properties match the JSON Schema
# object members $4. Reports it as $1.
expect_entry() {
  local name="$1" ecosystem="$2" directory="$3" members="$4"
  expect_schema "$name" "$(cat <<EOF
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["updates"],
  "properties": {
    "updates": {
      "type": "array",
      "contains": {
        "type": "object",
        "required": ["package-ecosystem", "directory", "schedule", "commit-message"],
        "properties": {
          "package-ecosystem": { "const": "$ecosystem" },
          "directory": { "const": "$directory" },
          "schedule": {
            "type": "object",
            "required": ["interval"],
            "properties": { "interval": { "const": "weekly" } }
          },
          $members
        }
      }
    }
  }
}
EOF
)"
}

# The prefixes, by what each update touches (spec: Repo and process, and the
# commit-type table in the README's Release flow).
RELEASING_PREFIX="fix(deps)"
DEV_PREFIX="chore(deps)"
IMAGE_PREFIX="chore(deps)"
CI_PREFIX="ci(deps)"
# Every prefix the policy allows outside the app's production dependencies.
# Each is a type the commit analyzer turns into no Release.
NON_RELEASING_PATTERN='^(chore|ci)\\(deps\\)$'

expect_entry "npm in /: weekly, $RELEASING_PREFIX for production and $DEV_PREFIX for dev dependencies, each group one dependency type" \
  npm / "$(cat <<EOF
"commit-message": {
            "type": "object",
            "required": ["prefix", "prefix-development"],
            "properties": {
              "prefix": { "const": "$RELEASING_PREFIX" },
              "prefix-development": { "const": "$DEV_PREFIX" }
            }
          },
          "groups": {
            "type": "object",
            "additionalProperties": {
              "type": "object",
              "required": ["dependency-type"]
            }
          }
EOF
)"

expect_entry "npm in /release (release tooling): weekly, $CI_PREFIX" \
  npm /release "$(cat <<EOF
"commit-message": {
            "type": "object",
            "required": ["prefix"],
            "properties": {
              "prefix": { "const": "$CI_PREFIX" },
              "prefix-development": { "const": "$CI_PREFIX" }
            }
          }
EOF
)"

expect_entry "docker in / (base image): weekly, $IMAGE_PREFIX" \
  docker / "$(cat <<EOF
"commit-message": {
            "type": "object",
            "required": ["prefix"],
            "properties": { "prefix": { "const": "$IMAGE_PREFIX" } }
          }
EOF
)"

expect_entry "github-actions in /: weekly, $CI_PREFIX" \
  github-actions / "$(cat <<EOF
"commit-message": {
            "type": "object",
            "required": ["prefix"],
            "properties": { "prefix": { "const": "$CI_PREFIX" } }
          }
EOF
)"

expect_schema "every entry sets its prefix, without include: scope, and only npm production dependencies in / release" "$(cat <<EOF
{
  "\$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["updates"],
  "properties": {
    "updates": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["commit-message"],
        "properties": {
          "commit-message": {
            "type": "object",
            "required": ["prefix"],
            "properties": {
              "include": false,
              "prefix-development": { "type": "string", "pattern": "$NON_RELEASING_PATTERN" }
            }
          }
        },
        "if": {
          "required": ["package-ecosystem", "directory"],
          "properties": {
            "package-ecosystem": { "const": "npm" },
            "directory": { "const": "/" }
          }
        },
        "then": {
          "properties": {
            "commit-message": { "properties": { "prefix": { "const": "$RELEASING_PREFIX" } } }
          }
        },
        "else": {
          "properties": {
            "commit-message": {
              "properties": { "prefix": { "type": "string", "pattern": "$NON_RELEASING_PATTERN" } }
            }
          }
        }
      }
    }
  }
}
EOF
)"

if ((failures > 0)); then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nAll checks passed\n'
