# 04: PR pipeline: tests and Dockerfile lint

**Spec:** k8s-delivery spec (CI on pull requests, Supply chain and permissions)

**What to build:** Every PR to `main` runs the unit tests and a Dockerfile lint as separate checks, and a failure shows as a red check on the PR.

**Blocked by:** 02, 03

**Status:** done

- [x] A workflow triggers on pull requests to `main`.
- [x] Job `test` runs on Node 24 and runs `npm ci` and `npm test`.
- [x] Job `dockerfile-lint` runs hadolint and fails on warnings or worse.
- [x] Every third-party action is pinned by full commit SHA, with the version in a trailing comment. The workflow's default token permission is read-only.
- [x] The job names are stable and documented, because ticket 05 makes them required checks.
- [x] This PR shows both checks green.
- [x] The README gains a "Pipeline" section, starting with a table of PR-stage checks.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
