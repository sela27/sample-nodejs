# 07: SAST Gate with SonarQube Cloud

**Spec:** k8s-delivery spec (CI on pull requests)

**What to build:** SonarQube Cloud analyzes every PR. An explicit Gate fails the PR if any open vulnerability at the top severities exists anywhere in the project, not just in new code. Pushes to `main` are analyzed too, so the dashboard reflects the released code.

**Blocked by:** 05

**Status:** done

**Human step:** sign in to SonarQube Cloud with GitHub, create the organization, import the project, switch to CI-based analysis (automatic analysis off), create a token, and add it as the `SONAR_TOKEN` secret (organization and project keys as repo variables).

**Human step done (2026-11-11):** the human ran a setup wizard the agent wrote, which walked through each SonarQube Cloud page. The result:
- Organization `sela27` on the free plan, with the SonarQubeCloud app allowed on this repo only.
- Project `sela27_sample-nodejs`, with Automatic Analysis off.
- A 90-day personal token, which the wizard checked against the Web API before storing it as `SONAR_TOKEN`, both as an Actions secret and as a Dependabot secret.

The organization and project keys live in `sonar-project.properties` instead of repo variables. The scanner needs them there anyway, and the Gate reads them from the same file, so they have one source of truth and need no extra repo setting.

- [x] Scanner configuration is committed (organization, project key, sources, with tests marked as tests). (`sonar-project.properties`. It also points at the lcov coverage report, and keeps the vendored schemas and the screenshots out of the analysis.)
- [x] Job `sast` runs the official scanner (pinned by SHA) and waits until the analysis is processed. It then queries the SonarQube Web API for open vulnerability issues at Blocker or Critical (standard mode) or Blocker or High (MQR mode) across the whole project. If there are any, it fails and lists them. (`SonarSource/sonarqube-scan-action` 8.4.1 by SHA, then `scripts/sast-gate.js`. "Across the whole project" means the open vulnerabilities on `main` plus those the PR's analysis raised on the code it changes, because a PR analysis reports only those. The severities are checked in the script, because the Web API ignores unknown parameters, which an anonymous query showed. `test/sast-gate.test.js` covers it with 12 tests.)
- [x] A push to `main` triggers an analysis that only reports and does not Gate. (`.github/workflows/sast-main.yml` runs the Gate with `--report-only`. Verified after the merge: run [43033761123](https://github.com/sela27/sample-nodejs/actions/runs/43033761123) on `cb3c1b5` printed `Analysis ... processed: branch main` and `main branch: 8 open vulnerabilities, 0 blocking`. The `Release` run for the same commit made no Release, as a `ci:` commit should not.)
- [x] `sast` is added to the required checks. (Added to `REQUIRED_CHECKS` in `scripts/protect-main.sh`, which the human approved re-running on 2026-11-11. The ruleset now requires seven checks, and `scripts/verify-protection.sh` passes every check, including "required checks are the PR jobs in pr.yml".)
- [x] This PR is green, and the SonarQube Cloud dashboard shows the `main` analysis. (The PR was green, `sast` included. After the merge, the dashboard's `main` branch shows the CI analysis of `cb3c1b5` at 13:57 UTC. Its 8 open vulnerabilities are all Security LOW or MEDIUM. This box was ticked in ticket 08's docs PR, because it could only be checked after the merge.)
- [x] The README gains a "SAST" section explaining why the Gate is explicit: the built-in gate only checks new code, and custom gates may not be on the free plan.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.

**Found on the way:** SonarQube's own PR check, `SonarCloud Code Analysis`, failed this PR's first run on two reliability issues in `scripts/sast-gate.js`: a backtracking regular expression and an unhandled promise. Both were fixed in the PR, and the check passed.
