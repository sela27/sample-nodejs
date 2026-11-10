# 15: Release pipeline on main

**Spec:** k8s-delivery spec (CD on `main`)

**What to build:** A squash-merge of a `feat` or `fix` produces a Release: the version is computed, the image is built, passes the Gate, and is pushed to the private GHCR package, and then the tag and GitHub Release are created. A merge that warrants no Release stops early and stays green.

**Blocked by:** 06

**Status:** done

**Human step:** after the first push, confirm in the GHCR package settings that the package is private and linked to the repo, and take a screenshot of the package page.

**Human step done (2026-11-10):**
- The package had come out public, so the human switched it to Private.
- The repo's Actions access was lowered from `Admin`, GitHub's default for the publishing repo, to `Write`.
- The package page screenshot is `docs/screenshots/15-ghcr-package-private.png`.
- Checked afterwards: anonymous manifest requests get 401 and 403, and a pod with `imagePullPolicy: Always` pulled `1.1.0` through `ghcr-pull`.

**Verified before merge:** a semantic-release dry run over `main` plus this PR's commit, run the way the `version` job runs it, predicted `v1.0.0` with one Bug Fixes entry, the `fix(deps)` commit. Every other commit, this PR's `ci:` commit included, was analyzed as "should not trigger a release". actionlint 1.7.12 passes on the workflow. The criteria below that need a real run on `main` stay open until the first run after the merge.

- [x] A workflow triggers on push to `main`, inside a concurrency group that never cancels a run in progress. Bump commits marked `[skip ci]` do not trigger it. (GitHub skips push workflows for a `[skip ci]` head commit on its own; ticket 16 sees it happen on the first Bump commit.)
- [x] semantic-release config: release branch `main`, Conventional Commits preset, release notes, GitHub release, `v${version}` tags, no npm publish, and no commit back to the repo.
- [x] Order: dry-run to get the next version (if there is none, log it and exit successfully); BuildKit build tagged with the version and `sha-<short>`; image Gate with the same settings and ignore file as on PRs; push to GHCR; the real semantic-release run, which creates the tag and the GitHub Release.
- [x] Each job requests only what it needs: contents write for the Release, packages write for the push, everything else read-only. (The dry-run job also needs contents write, because semantic-release runs `git push --dry-run` before it analyzes anything; the README says why.)
- [x] The first run produces `v1.0.0`, driven by the `fix(deps)` from ticket 06, and GHCR shows the tags `1.0.0` and `sha-…`. Verified after merge by run [42828540805](https://github.com/sela27/sample-nodejs/actions/runs/42828540805) on `f12d674`: it created `v1.0.0` and pushed `ghcr.io/sela27/sample-nodejs:1.0.0` and `sha-f12d674`.
- [x] If the Gate fails, nothing is pushed and no tag is created (visible in the run's step order). Verified after merge by the step order of run [42828540805](https://github.com/sela27/sample-nodejs/actions/runs/42828540805): `version`, then `image` with the scan (step 5) before the GHCR login (6) and push (7), then `release`.

**Verified after merge:** run [42828531246](https://github.com/sela27/sample-nodejs/actions/runs/42828531246), on this ticket's own merge commit `2ed65a6`, stood down green as designed. `main` had already moved on to `f12d674`, so semantic-release logged that the local branch was behind the remote one, `version` found no Release, and `image` and `release` were skipped. The run for `f12d674` then made the Release.
- [x] The README gains a "Release flow" section.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
