# 24: Rollback demo

**Spec:** k8s-delivery spec (User story 81)

**What to build:** Show that a bad Deploy leaves the previous version serving, ArgoCD reports it as Degraded, and a `git revert` restores Healthy.

**Blocked by:** 23

**Status:** done

**Human step:** screenshots of the Degraded Application, and of Healthy after the revert.

**Done on minikube (2026-11-10):** the human took both screenshots during the demo. The README's "Rollback" section has the timeline, both screenshots and the request loop's numbers. The loop ran 25 minutes through the tunnel, `total=7381 ok=7348 non200=0 errors=33`. The 33 errors are three bursts of 11 timeouts. Two of the bursts came after the revert, while the cluster was idle and Healthy, so they are a stall on the workstation's side of the tunnel, not an effect of the rollout.

- [x] A PR points the `dev` image tag at a version that does not exist (a simulated bad Bump commit). ([#35](https://github.com/sela27/sample-nodejs/pull/35): `scripts/bump-dev-image-tag.sh 9.9.9`, merged 19:03:02 UTC.)
- [x] After the merge, the new pod cannot start, the old pods keep serving (the smoke test passes), and ArgoCD shows the Application as Degraded once the progress deadline passes. (The new pod went `ErrImagePull` with `manifest unknown`, then `ImagePullBackOff`. The two `1.1.0` pods kept running. `ProgressDeadlineExceeded` and Degraded at 19:06:14, and `scripts/smoke-test.sh` through the tunnel then passed all five paths.)
- [x] A revert PR restores the previous tag, and ArgoCD returns to Healthy. ([#36](https://github.com/sela27/sample-nodejs/pull/36), a plain `git revert` of #35's commit, merged 19:11:40. Synced to `f7d6a5b` and Healthy at 19:11:52. The same two pods kept serving throughout, with no restarts.)
- [x] Both screenshots are saved. The README gains a "Rollback" section that explains `git revert` of a Bump commit as the rollback mechanism. (`docs/screenshots/24-argocd-degraded-bad-bump.png` and `docs/screenshots/24-argocd-healthy-after-revert.png`.)
- [x] Both PRs use `chore: …` titles (no Release). This ticket's status lands with the revert PR. (Both titles are `chore: …`, and neither merge made a Release. The status landed in this docs PR instead, so the revert stayed a pure `git revert` of one file, the way the README says to do it, and the screenshot of Healthy after the revert could only be taken once it had merged.)
