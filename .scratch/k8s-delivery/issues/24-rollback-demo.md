# 24: Rollback demo

**Spec:** k8s-delivery spec (User story 81)

**What to build:** Show that a bad Deploy leaves the previous version serving, ArgoCD reports it as Degraded, and a `git revert` restores Healthy.

**Blocked by:** 23

**Status:** ready-for-agent

**Human step:** screenshots of the Degraded Application, and of Healthy after the revert.

- [ ] A PR points the `dev` image tag at a version that does not exist (a simulated bad Bump commit).
- [ ] After the merge, the new pod cannot start, the old pods keep serving (the smoke test passes), and ArgoCD shows the Application as Degraded once the progress deadline passes.
- [ ] A revert PR restores the previous tag, and ArgoCD returns to Healthy.
- [ ] Both screenshots are saved. The README gains a "Rollback" section that explains `git revert` of a Bump commit as the rollback mechanism.
- [ ] Both PRs use `chore: …` titles (no Release). This ticket's status lands with the revert PR.
