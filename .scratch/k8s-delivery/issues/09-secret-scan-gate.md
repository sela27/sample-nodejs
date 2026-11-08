# 09: Secret scan Gate

**Spec:** k8s-delivery spec (CI on pull requests)

**What to build:** Every PR is scanned for committed secrets, and a finding fails a required check.

**Blocked by:** 05

**Status:** ready-for-agent

- [ ] Job `secrets` runs gitleaks, pinned by version or SHA, over the commits the PR brings, with enough history fetched to see them.
- [ ] Verified on a temporary branch that is never merged: a fake token is caught and the check goes red.
- [ ] `secrets` is added to the required checks.
- [ ] The README security-controls list includes secret scanning.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
