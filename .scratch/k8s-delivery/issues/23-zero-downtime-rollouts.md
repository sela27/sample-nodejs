# 23: Zero-downtime rollouts

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** A rollout never reduces the number of available pods and never drops in-flight requests.

**Blocked by:** 17, 19

**Status:** done

- [x] RollingUpdate with `maxUnavailable: 0` and `maxSurge: 1`, a termination grace period longer than the app's shutdown timeout, and a short preStop pause.
- [x] A progress deadline short enough that a stuck rollout turns Degraded within a few minutes (ticket 24 relies on this).
- [x] Verified: during a rollout restart, a request loop through the Ingress records zero failures. The numbers are written up in the README.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
