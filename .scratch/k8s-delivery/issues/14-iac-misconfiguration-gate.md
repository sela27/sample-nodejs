# 14: IaC misconfiguration Gate

**Spec:** k8s-delivery spec (CI on pull requests)

**What to build:** Every PR scans the Dockerfile and the rendered chart for misconfigurations, and a HIGH or CRITICAL finding fails a required check.

**Blocked by:** 05, 12

**Status:** ready-for-agent

- [ ] Job `iac-gate` runs Trivy config, pinned the same way as in ticket 06, over the Dockerfile and the chart rendered with the `dev` values. It fails on HIGH or CRITICAL.
- [ ] The current repo passes. Any finding we accept goes into the ignore file with a justification.
- [ ] Verified locally, without committing: removing the read-only root filesystem setting makes the Gate fail.
- [ ] `iac-gate` is added to the required checks.
- [ ] The README security-controls list includes IaC scanning.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
