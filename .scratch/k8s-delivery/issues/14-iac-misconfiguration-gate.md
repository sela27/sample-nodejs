# 14: IaC misconfiguration Gate

**Spec:** k8s-delivery spec (CI on pull requests)

**What to build:** Every PR scans the Dockerfile and the rendered chart for misconfigurations, and a HIGH or CRITICAL finding fails a required check.

**Blocked by:** 05, 12

**Status:** done

- [x] Job `iac-gate` runs Trivy config, pinned the same way as in ticket 06, over the Dockerfile and the chart rendered with the `dev` values. It fails on HIGH or CRITICAL.
- [x] The current repo passes. Any finding we accept goes into the ignore file with a justification.
- [x] Verified locally, without committing: removing the read-only root filesystem setting makes the Gate fail.
- [x] `iac-gate` is added to the required checks.
- [x] The README security-controls list includes IaC scanning.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
