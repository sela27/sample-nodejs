#!/usr/bin/env bash
# Protects main through `gh api`, so the protection is reproducible and
# reviewable. Applies the repo merge settings (squash only, PR title as the
# squash commit message, delete branch on merge) and the protect-main
# repository ruleset: a pull request is required (zero approvals, squash only),
# the required status checks must pass, and force-push and deletion are blocked.
#
# Safe to re-run: the merge settings are set to the same values, and the ruleset
# is found by name and updated in place, or created when it does not exist yet.
# scripts/verify-protection.sh checks the result against the live repo.
#
# Needs gh, logged in as an admin of the repo. Runs from Git Bash on Windows and
# natively on Linux and macOS.
#
# Variables:
#   GH_REPO  repository to protect, as owner/name (default: sela27/sample-nodejs)
set -euo pipefail

GH_REPO="${GH_REPO:-sela27/sample-nodejs}"
RULESET_NAME="protect-main"

# The required status checks, one per PR job in .github/workflows/pr.yml, named
# by job id. A new Gate appends its job id here in the same PR that adds the
# job, then this script is re-run.
REQUIRED_CHECKS=(
  test
  dockerfile-lint
  chart
  secrets
)

# GitHub Actions' app id. Each required check is bound to it, so only a
# workflow job can satisfy the check, not another app or a status posted with
# a personal token.
GITHUB_ACTIONS_APP_ID=15368

# Who may skip the ruleset, as a JSON array. Empty means nobody, the repo admin
# included. Ticket 16 adds the pipeline's deploy key here, so the Bump commit
# can push to main without a pull request:
#   [{"actor_id": null, "actor_type": "DeployKey", "bypass_mode": "always"}]
BYPASS_ACTORS='[]'

log() { printf '==> %s\n' "$*"; }
die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

check_prerequisites() {
  command -v gh >/dev/null 2>&1 || die "gh is not on PATH. Install the GitHub CLI, then re-run."
  gh auth status >/dev/null 2>&1 || die "gh is not logged in. Run \"gh auth login\", then re-run."
  [[ "$(gh api "repos/$GH_REPO" --jq '.permissions.admin' | tr -d '\r')" == "true" ]] ||
    die "the gh user is not an admin of $GH_REPO, so it cannot change rulesets or merge settings."
}

ruleset_json() {
  local check checks=""
  for check in "${REQUIRED_CHECKS[@]}"; do
    checks+="${checks:+, }{\"context\": \"$check\", \"integration_id\": $GITHUB_ACTIONS_APP_ID}"
  done
  cat <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "bypass_actors": $BYPASS_ACTORS,
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "pull_request", "parameters": {
      "required_approving_review_count": 0,
      "dismiss_stale_reviews_on_push": false,
      "require_code_owner_review": false,
      "require_last_push_approval": false,
      "required_review_thread_resolution": false,
      "allowed_merge_methods": ["squash"]
    }},
    {"type": "required_status_checks", "parameters": {
      "strict_required_status_checks_policy": false,
      "do_not_enforce_on_create": false,
      "required_status_checks": [$checks]
    }}
  ]
}
EOF
}

apply_ruleset() {
  local ids count id
  ids="$(gh api --paginate "repos/$GH_REPO/rulesets?includes_parents=false" \
    --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" | tr -d '\r')"
  count="$(grep -c . <<<"$ids" || true)"
  case "$count" in
    0)
      id="$(ruleset_json | gh api --method POST "repos/$GH_REPO/rulesets" --input - --jq '.id' | tr -d '\r')"
      log "Created ruleset '$RULESET_NAME' (id $id)"
      ;;
    1)
      id="$ids"
      ruleset_json | gh api --method PUT "repos/$GH_REPO/rulesets/$id" --input - --silent
      log "Updated ruleset '$RULESET_NAME' (id $id)"
      ;;
    *)
      die "found $count rulesets named '$RULESET_NAME' (ids: ${ids//$'\n'/, }). Delete all but one in the repo settings, then re-run."
      ;;
  esac
  log "Required checks: ${REQUIRED_CHECKS[*]}"
  log "https://github.com/$GH_REPO/rules/$id"
}

# Squash is the only merge method, so each PR lands on main as one commit whose
# message is the PR title (GitHub's "Default to pull request title"), which is
# the Conventional Commit that decides the Release. Merged head branches are
# deleted.
apply_merge_settings() {
  gh api --method PATCH "repos/$GH_REPO" --silent \
    -F allow_squash_merge=true \
    -F allow_merge_commit=false \
    -F allow_rebase_merge=false \
    -f squash_merge_commit_title=PR_TITLE \
    -f squash_merge_commit_message=BLANK \
    -F delete_branch_on_merge=true
  log "Merge settings: squash only, PR title as the squash commit message, delete branch on merge"
}

check_prerequisites
apply_merge_settings
apply_ruleset
log "Done. Check the result with scripts/verify-protection.sh"
