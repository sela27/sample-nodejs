# 22: NetworkPolicy

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** Only the Ingress controller can reach the app's port, so internal paths such as `/classified` and `/metrics` cannot be reached from arbitrary pods.

**Blocked by:** 19

**Status:** ready-for-agent

- [ ] A NetworkPolicy that selects the app pods allows ingress on the app port only from the Traefik namespace, matched by its namespace-name label, and from Traefik's pods.
- [ ] The smoke test still passes.
- [ ] From a throwaway pod in another namespace, a request to the app Service times out. The command and its output are recorded in the README.
- [ ] The README security-controls list includes the NetworkPolicy, and notes that it depends on Calico being enforced.
- [ ] PR title is `chore(chart): …`. Status set to `done` in the same PR.
