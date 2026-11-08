# 07: SAST Gate with SonarQube Cloud

**Spec:** k8s-delivery spec (CI on pull requests)

**What to build:** SonarQube Cloud analyzes every PR. An explicit Gate fails the PR if any open vulnerability at the top severities exists anywhere in the project, not just in new code. Pushes to `main` are analyzed too, so the dashboard reflects the released code.

**Blocked by:** 05

**Status:** ready-for-agent

**Human step:** sign in to SonarQube Cloud with GitHub, create the organization, import the project, switch to CI-based analysis (automatic analysis off), create a token, and add it as the `SONAR_TOKEN` secret (organization and project keys as repo variables).

- [ ] Scanner configuration is committed (organization, project key, sources, with tests marked as tests).
- [ ] Job `sast` runs the official scanner (pinned by SHA) and waits until the analysis is processed. It then queries the SonarQube Web API for open vulnerability issues at Blocker or Critical (standard mode) or Blocker or High (MQR mode) across the whole project. If there are any, it fails and lists them.
- [ ] A push to `main` triggers an analysis that only reports and does not Gate.
- [ ] `sast` is added to the required checks.
- [ ] This PR is green, and the SonarQube Cloud dashboard shows the `main` analysis.
- [ ] The README gains a "SAST" section explaining why the Gate is explicit: the built-in gate only checks new code, and custom gates may not be on the free plan.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
