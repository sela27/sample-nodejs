# 22: NetworkPolicy

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** Only the Ingress controller can reach the app's port, so internal paths such as `/classified` and `/metrics` cannot be reached from arbitrary pods.

**Blocked by:** 19

**Status:** done

- [x] A NetworkPolicy that selects the app pods allows ingress on the app port only from the Traefik namespace, matched by its namespace-name label, and from Traefik's pods.
- [ ] The smoke test still passes.
- [x] From a throwaway pod in another namespace, a request to the app Service times out. The command and its output are recorded in the README.
- [x] The README security-controls list includes the NetworkPolicy, and notes that it depends on Calico being enforced.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.

One criterion is left open, because its test does not exist yet:

- **The smoke test** comes with ticket 20, which is not on `main` yet. In its place, the agent checked the same path by hand on a test deployment of this branch (a temporary `sample-nodejs-t22` Application with the dev values and the host `t22.127.0.0.1.nip.io`): through a port-forward to the Traefik Service, `/my-app` and `/about` answered 200, and `/classified` and `/metrics` 404, with the NetworkPolicy in place. To close it, run the smoke test against `dev` once both this ticket and ticket 20 are on `main`.
