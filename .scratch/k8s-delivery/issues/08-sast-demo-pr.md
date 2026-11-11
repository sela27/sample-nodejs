# 08: SAST Demo PR

**Spec:** k8s-delivery spec (Evidence strategy)

**What to build:** A Demo PR adds a deliberately vulnerable route and shows the SAST Gate blocking the merge. The PR is then closed without merging.

**Blocked by:** 07

**Status:** done

**Human step:** screenshots of the red `sast` check with merging blocked, and of the issue in SonarQube Cloud.

**Done (2026-11-11):** the human took both screenshots. Demo PR [#39](https://github.com/sela27/sample-nodejs/pull/39) is closed without merging, and its branch is deleted. The README's "SAST Gate" section shows the demo.

- [x] A branch adds a route that passes a query parameter into a shell command (command injection). (`demo/08-sast-command-injection`: `exec(`ping -c 1 ${req.query.host}`)` behind `GET /ping`.)
- [x] Before taking the screenshot, confirm that SonarQube reports it as a Vulnerability at a blocking severity. If it only reports a Security Hotspot, switch to a pattern that yields a Vulnerability. (Checked through the Web API before the screenshots: type `VULNERABILITY`, rule `jssecurity:S2076`, severity `BLOCKER`, impact Security `BLOCKER`, from taint analysis. The PR had no hotspot, so the first pattern was enough.)
- [x] The `sast` check is red, the finding is listed in the job log, and merging is blocked. (The log printed `BLOCKING  BLOCKER, SECURITY:BLOCKER  jssecurity:S2076  app.js:46` and `FAIL`. GitHub reported `mergeStateStatus: BLOCKED`, and the other six required checks passed.)
- [x] Screenshots are saved. The PR is closed with a comment saying it is a Demo PR, and its branch is deleted. (`docs/screenshots/08-sast-red-merge-blocked.png` and `docs/screenshots/08-sonarqube-issue.png`.)
- [x] Nothing from the Demo PR reaches `main`. The screenshots and this ticket's `done` status land in a separate small `docs:` PR. (`main` has no `/ping` route; this PR is that `docs:` PR.)
