# 05: Protect main

**Spec:** k8s-delivery spec (Repo protection)

**What to build:** Merging into `main` requires a PR with every required check green. Squash is the only merge method, and force-push and branch deletion are blocked. A script applies all of this, so it can be reproduced.

**Blocked by:** 04

**Status:** ready-for-agent

**Human step:** approve applying the repository settings (ruleset and merge methods).

- [ ] A script uses `gh api` to create or update a ruleset on `main` that requires a PR (zero approvals), requires the status checks from ticket 04, and blocks force-push and deletion.
- [ ] The same script sets the repo merge settings: squash only, PR title as the default squash commit message, and delete branch on merge.
- [ ] The script is idempotent. Re-running it updates the existing ruleset instead of creating a duplicate.
- [ ] The list of required checks lives in one place in the script, so later tickets append to it.
- [ ] Verified: the ruleset shows as active, and an open PR shows "merging is blocked" while its required checks are pending or failing.
- [ ] The README gains a "Branch protection" section.
- [ ] PR title is `chore: …`. Status set to `done` in the same PR.
