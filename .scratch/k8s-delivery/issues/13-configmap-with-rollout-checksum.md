# 13: App configuration through a ConfigMap

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** `PORT` and `NODE_ENV` reach the app from a ConfigMap, and changing that configuration rolls the pods.

**Blocked by:** 11

**Status:** ready-for-agent

- [ ] A ConfigMap carries `PORT` (8080) and `NODE_ENV` (production) from values. The container loads it as environment variables.
- [ ] The pod template carries a checksum annotation of the ConfigMap content.
- [ ] The container port, the probes and `PORT` all come from one value, so they cannot drift apart.
- [ ] Verified: rendering with a changed value changes the checksum annotation.
- [ ] The README chart-features list includes the ConfigMap and the rollout trigger.
- [ ] PR title is `chore(chart): …`. Status set to `done` in the same PR.
