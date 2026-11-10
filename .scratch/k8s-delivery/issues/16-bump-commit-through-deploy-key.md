# 16: Bump commit through the deploy key

**Spec:** k8s-delivery spec (CD on `main`, Repo protection), ADR-0001

**What to build:** After each Release, the pipeline makes a Bump commit that points the `dev` Environment at the new image. The commit is pushed with a deploy key that the ruleset lets bypass the PR requirement, and it does not start another pipeline run.

**Blocked by:** 05, 11, 15

**Status:** done

**Human step:** approve generating a deploy key with write access, storing its private half as an Actions secret, and adding the key to the ruleset bypass list. Approved; all three done from this branch.

**Verified before merge:** `test/bump-dev-image-tag.test.js` runs `scripts/bump-dev-image-tag.sh` against a copy of the dev values: the diff is exactly the tag line, nine malformed versions fail and leave the file unchanged, and a file without the tag fails. `scripts/verify-protection.sh` was extended first and failed on the two new checks, then passed all 22 against the live repo after `scripts/protect-main.sh` was applied. actionlint 1.7.12 passes on the workflows and shellcheck 0.11.0 on the scripts.

- [x] A deploy key is generated for this purpose only. Its public half is on the repo with write access, its private half is an Actions secret, and the local copy is deleted. (ed25519, deploy key `bump-commit`, id 169403968, write access; secret `DEPLOY_KEY`. It was generated in a temp directory outside the repo, piped into `gh secret set`, and both halves were deleted.)
- [x] The ruleset bypass list contains only this deploy key, applied through ticket 05's script. (GitHub's bypass entry for deploy keys names no key and covers every deploy key of the repo, so the bypass list is that one entry, in `always` mode, and `bump-commit` is the repo's only deploy key. `scripts/verify-protection.sh` checks both.)
- [x] After the Release step, the job checks out over SSH with the deploy key, changes only the `dev` image tag, commits `chore(release): deploy <version> to dev [skip ci]`, and pushes to `main`. On a non-fast-forward it rebases and retries once.
- [x] This PR seeds the `dev` image tag to `1.0.0`, which already exists in GHCR from ticket 15.
- [x] Verified on the next Release (ticket 17): a Bump commit by the deploy key appears on `main`, and no new workflow run starts. (Verified with the v1.1.0 Release, run 42843956960: the `bump` job pushed `daf8f62` `chore(release): deploy 1.1.0 to dev [skip ci]` over SSH, the ruleset's rule suite for that push is `bypass` with the deploy key as the only bypass actor, the commit changes only `image.tag` in `values-dev.yaml`, and `gh run list --commit daf8f62` is empty.)
- [x] The README gains a "Bump commit" section.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
