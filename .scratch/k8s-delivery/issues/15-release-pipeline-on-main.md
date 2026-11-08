# 15: Release pipeline on main

**Spec:** k8s-delivery spec (CD on `main`)

**What to build:** A squash-merge of a `feat` or `fix` produces a Release: the version is computed, the image is built, passes the Gate, and is pushed to the private GHCR package, and then the tag and GitHub Release are created. A merge that warrants no Release stops early and stays green.

**Blocked by:** 06

**Status:** ready-for-agent

**Human step:** after the first push, confirm in the GHCR package settings that the package is private and linked to the repo, and take a screenshot of the package page.

- [ ] A workflow triggers on push to `main`, inside a concurrency group that never cancels a run in progress. Bump commits marked `[skip ci]` do not trigger it.
- [ ] semantic-release config: release branch `main`, Conventional Commits preset, release notes, GitHub release, `v${version}` tags, no npm publish, and no commit back to the repo.
- [ ] Order: dry-run to get the next version (if there is none, log it and exit successfully); BuildKit build tagged with the version and `sha-<short>`; image Gate with the same settings and ignore file as on PRs; push to GHCR; the real semantic-release run, which creates the tag and the GitHub Release.
- [ ] Each job requests only what it needs: contents write for the Release, packages write for the push, everything else read-only.
- [ ] The first run produces `v1.0.0`, driven by the `fix(deps)` from ticket 06, and GHCR shows the tags `1.0.0` and `sha-…`.
- [ ] If the Gate fails, nothing is pushed and no tag is created (visible in the run's step order).
- [ ] The README gains a "Release flow" section.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
