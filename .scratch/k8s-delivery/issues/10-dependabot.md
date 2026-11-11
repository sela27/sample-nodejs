# 10: Dependabot

**Spec:** k8s-delivery spec (Supply chain and permissions)

**What to build:** Dependabot opens weekly PRs for npm, the base image and GitHub Actions. Those PRs go through the same Gates as any other PR.

**Blocked by:** 04

**Status:** done

**Human step:** approve turning on Dependabot security updates in the repo settings, and adding `SONAR_TOKEN` as a Dependabot secret.

- [x] Dependabot config covers npm, docker and github-actions on a weekly schedule. Updates to SHA-pinned actions keep the version comment.
- [x] Commit prefixes: production npm dependencies use `fix(deps)` (a security bump produces a Release). Dev dependencies, the base image and actions use `chore(deps)` or `ci(deps)`.
- [x] Dependabot PRs can run the SAST Gate: `SONAR_TOKEN` is available as a Dependabot secret, because Dependabot PRs cannot read regular Actions secrets. (Completed with ticket 07 on 2026-11-11: the human's SonarQube Cloud setup stored the token as an Actions secret and as a Dependabot secret, both named `SONAR_TOKEN`; `gh secret list --app dependabot` lists it.)
- [x] The README security-controls list includes Dependabot.
- [x] PR title is `chore: …`. Status set to `done` in the same PR.
