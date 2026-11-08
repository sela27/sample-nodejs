# 16: Bump commit through the deploy key

**Spec:** k8s-delivery spec (CD on `main`, Repo protection), ADR-0001

**What to build:** After each Release, the pipeline makes a Bump commit that points the `dev` Environment at the new image. The commit is pushed with a deploy key that the ruleset lets bypass the PR requirement, and it does not start another pipeline run.

**Blocked by:** 05, 11, 15

**Status:** ready-for-agent

**Human step:** approve generating a deploy key with write access, storing its private half as an Actions secret, and adding the key to the ruleset bypass list.

- [ ] A deploy key is generated for this purpose only. Its public half is on the repo with write access, its private half is an Actions secret, and the local copy is deleted.
- [ ] The ruleset bypass list contains only this deploy key, applied through ticket 05's script.
- [ ] After the Release step, the job checks out over SSH with the deploy key, changes only the `dev` image tag, commits `chore(release): deploy <version> to dev [skip ci]`, and pushes to `main`. On a non-fast-forward it rebases and retries once.
- [ ] This PR seeds the `dev` image tag to `1.0.0`, which already exists in GHCR from ticket 15.
- [ ] Verified on the next Release (ticket 17): a Bump commit by the deploy key appears on `main`, and no new workflow run starts.
- [ ] The README gains a "Bump commit" section.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
