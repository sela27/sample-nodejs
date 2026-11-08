# 06: Image Gate catches the sample's real vulnerabilities

**Spec:** k8s-delivery spec (CI on pull requests, Evidence strategy)

**What to build:** Every PR builds the image without pushing it, and Trivy blocks the PR on any HIGH or CRITICAL vulnerability. The first run on this PR catches the real vulnerabilities in the sample's original lockfile. The same PR then fixes them and turns green.

**Blocked by:** 05

**Status:** ready-for-agent

**Human step:** screenshot the red PR with merging blocked.

**Why one PR and not two:** a separate fix PR opened from `main` would not contain this Gate (it exists only on this unmerged branch), so it could never satisfy the required check. The PR therefore carries two commits: the Gate first, then the fix.

- [ ] Job `image-gate` builds the image with BuildKit, loads it locally, and does not push or log in to any registry.
- [ ] Trivy scans the built image for HIGH and CRITICAL, unfixed included, and fails on any finding. Trivy is pinned to a known-good version by SHA, outside the compromised 0.69.4–0.69.6 range and the hijacked action tags. The findings table appears in the job log.
- [ ] The Trivy ignore file exists, is empty, and has a header saying every entry needs a justification and the reason it is safe.
- [ ] `image-gate` is added to the required checks through ticket 05's script.
- [ ] First commit (Gate only): the check is red and lists `proxy-addr` (critical) plus the high findings. The screenshot is saved under the evidence naming convention.
- [ ] Second commit: the lockfile is updated within the existing semver ranges (Express stays on 4.x). `npm audit` reports no high or critical findings, tests pass, and the check is green.
- [ ] PR title is `fix(deps): …`, so it counts as the fix that drives the first Release.
- [ ] The README gains an "Image Gate" section covering this story and the ignore-file policy.
- [ ] Status set to `done` in the same PR.
