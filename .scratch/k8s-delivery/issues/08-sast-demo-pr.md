# 08: SAST Demo PR

**Spec:** k8s-delivery spec (Evidence strategy)

**What to build:** A Demo PR adds a deliberately vulnerable route and shows the SAST Gate blocking the merge. The PR is then closed without merging.

**Blocked by:** 07

**Status:** ready-for-agent

**Human step:** screenshots of the red `sast` check with merging blocked, and of the issue in SonarQube Cloud.

- [ ] A branch adds a route that passes a query parameter into a shell command (command injection).
- [ ] Before taking the screenshot, confirm that SonarQube reports it as a Vulnerability at a blocking severity. If it only reports a Security Hotspot, switch to a pattern that yields a Vulnerability.
- [ ] The `sast` check is red, the finding is listed in the job log, and merging is blocked.
- [ ] Screenshots are saved. The PR is closed with a comment saying it is a Demo PR, and its branch is deleted.
- [ ] Nothing from the Demo PR reaches `main`. The screenshots and this ticket's `done` status land in a separate small `docs:` PR.
