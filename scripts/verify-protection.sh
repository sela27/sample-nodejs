#!/usr/bin/env bash
# Checks that main is protected the way the spec says, by reading the live repo
# state through `gh api`: the protect-main ruleset and the repo merge settings.
# Prints PASS or FAIL per check and exits non-zero if any check fails.
#
# scripts/protect-main.sh applies what this script checks. The expected values
# come from the spec, not from that script, so a wrong edit there shows up here.
# The one list read from the repo is the PR jobs in .github/workflows/pr.yml,
# because every PR job is a required check under its job id.
#
# Needs gh, logged in as a user who can push to the repo, because GitHub hides
# the merge settings from everyone else. Runs from Git Bash on Windows and
# natively on Linux and macOS.
#
# Variables (same default as protect-main.sh):
#   GH_REPO  repository to check, as owner/name (default: sela27/sample-nodejs)
set -euo pipefail

GH_REPO="${GH_REPO:-sela27/sample-nodejs}"
# Must match the name in protect-main.sh, which finds the ruleset by it.
RULESET_NAME="protect-main"
# GitHub Actions' app id. Each required check must come from a workflow job.
GITHUB_ACTIONS_APP_ID="15368"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PR_WORKFLOW="$REPO_ROOT/.github/workflows/pr.yml"

if ! command -v gh >/dev/null 2>&1; then
  printf 'error: gh is not on PATH\n' >&2
  exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  printf 'error: gh is not logged in. Run "gh auth login", then re-run.\n' >&2
  exit 2
fi

failures=0
pass() { printf 'PASS  %s\n' "$1"; }
fail() {
  printf 'FAIL  %s\n' "$1"
  [[ -n "${2:-}" ]] && printf '      %s\n' "$2"
  failures=$((failures + 1))
}

expect() {
  local name="$1" want="$2" got="$3"
  if [[ "$got" == "$want" ]]; then
    pass "$name"
  else
    fail "$name" "expected: $want | got: ${got:-(nothing)}"
  fi
}

# The job ids under `jobs:` in pr.yml, sorted and space-separated.
pr_jobs() {
  awk '
    /^jobs:/ { injobs = 1; next }
    injobs && /^[^[:space:]#]/ { injobs = 0 }
    injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*(#.*)?$/ { sub(/^  /, ""); sub(/:.*$/, ""); print }
  ' "$PR_WORKFLOW" | tr -d '\r' | sort | paste -sd ' ' -
}

# Prints the value of one `key=value` line from the given block.
field() { sed -n "s/^$1=//p" <<<"$2"; }

# The ruleset: there must be exactly one with this name on the repo.
ruleset_ids="$(gh api --paginate "repos/$GH_REPO/rulesets?includes_parents=false" \
  --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" | tr -d '\r')"
expect "exactly one ruleset named '$RULESET_NAME'" "1" "$(grep -c . <<<"$ruleset_ids" || true)"

# Reads the ruleset once, as one `key=value` line per field the checks need.
ruleset=""
ruleset_id="$(head -n 1 <<<"$ruleset_ids")"
if [[ -n "$ruleset_id" ]]; then
  ruleset="$(gh api "repos/$GH_REPO/rulesets/$ruleset_id" --jq '
    def rule($type): [(.rules // [])[] | select(.type == $type)] | first;
    def checks: rule("required_status_checks").parameters.required_status_checks // [];
    def words: if length == 0 then "none" else join(" ") end;
    "enforcement=\(.enforcement)",
    "target=\(.target)",
    "include=\(.conditions.ref_name.include // [] | join(" "))",
    "exclude=\(.conditions.ref_name.exclude // [] | words)",
    "rules=\([(.rules // [])[].type] | sort | join(" "))",
    "approvals=\(rule("pull_request").parameters.required_approving_review_count)",
    "merge_methods=\(rule("pull_request").parameters.allowed_merge_methods // [] | sort | join(" "))",
    "checks=\(checks | map(.context) | sort | join(" "))",
    "checks_not_from_actions=\(checks | map(select(.integration_id != '"$GITHUB_ACTIONS_APP_ID"') | .context) | words)",
    "bypass_not_deploy_key=\(.bypass_actors // [] | map(select(.actor_type != "DeployKey") | .actor_type) | words)",
    "current_user_can_bypass=\(.current_user_can_bypass)"
  ' | tr -d '\r')"
fi

has_rule() {
  local name="$1" type="$2"
  if grep -qw -- "$type" <<<"$(field rules "$ruleset")"; then
    pass "$name"
  else
    fail "$name" "rule '$type' missing (rules: $(field rules "$ruleset"))"
  fi
}

expect "ruleset is active" "active" "$(field enforcement "$ruleset")"
expect "ruleset targets branches" "branch" "$(field target "$ruleset")"
expect "ruleset applies to main only" "refs/heads/main" "$(field include "$ruleset")"
expect "ruleset excludes nothing" "none" "$(field exclude "$ruleset")"
has_rule "a pull request is required" pull_request
expect "pull requests need zero approvals" "0" "$(field approvals "$ruleset")"
expect "pull requests merge by squash only" "squash" "$(field merge_methods "$ruleset")"
has_rule "required status checks are enforced" required_status_checks
expect "required checks are the PR jobs in pr.yml" "$(pr_jobs)" "$(field checks "$ruleset")"
expect "every required check must come from GitHub Actions (app $GITHUB_ACTIONS_APP_ID)" "none" \
  "$(field checks_not_from_actions "$ruleset")"
has_rule "force-push is blocked" non_fast_forward
has_rule "deletion is blocked" deletion
expect "nothing but a deploy key may bypass the ruleset" "none" "$(field bypass_not_deploy_key "$ruleset")"
expect "the gh user cannot bypass the ruleset" "never" "$(field current_user_can_bypass "$ruleset")"

# The repo merge settings. GitHub returns them only to a token that can push.
repo="$(gh api "repos/$GH_REPO" --jq '
  "squash=\(.allow_squash_merge)",
  "merge_commit=\(.allow_merge_commit)",
  "rebase=\(.allow_rebase_merge)",
  "squash_title=\(.squash_merge_commit_title)",
  "squash_message=\(.squash_merge_commit_message)",
  "delete_branch_on_merge=\(.delete_branch_on_merge)"
' | tr -d '\r')"

expect "squash merging is allowed" "true" "$(field squash "$repo")"
expect "merge commits are not allowed" "false" "$(field merge_commit "$repo")"
expect "rebase merging is not allowed" "false" "$(field rebase "$repo")"
# GitHub's "Default to pull request title" option: the title is the PR title
# and the body is left empty, so the Conventional Commit is the PR title alone.
expect "squash commit title defaults to the PR title" "PR_TITLE" "$(field squash_title "$repo")"
expect "squash commit body defaults to empty" "BLANK" "$(field squash_message "$repo")"
expect "head branches are deleted on merge" "true" "$(field delete_branch_on_merge "$repo")"

if ((failures > 0)); then
  printf '\n%d check(s) failed\n' "$failures"
  exit 1
fi
printf '\nAll checks passed\n'
