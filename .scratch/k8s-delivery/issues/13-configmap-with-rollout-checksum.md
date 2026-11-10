# 13: App configuration through a ConfigMap

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** `PORT` and `NODE_ENV` reach the app from a ConfigMap, and changing that configuration rolls the pods.

**Blocked by:** 11

**Status:** done

- [x] A ConfigMap carries `PORT` (8080) and `NODE_ENV` (production) from values. The container loads it as environment variables.
  - The values are `config.port` and `config.nodeEnv`, loaded with `envFrom`. The image also sets `NODE_ENV=production`. `scripts/check-chart.sh` resolves each variable the way the kubelet does (`env` over `envFrom` over the image's `ENV`), checks that it comes from the ConfigMap, and checks that `config.nodeEnv=development` reaches the app over the image's value.
- [x] The pod template carries a checksum annotation of the ConfigMap content.
  - `checksum/config`, the SHA-256 of the ConfigMap's data. A values change outside the ConfigMap keeps it.
- [x] The container port, the probes and `PORT` all come from one value, so they cannot drift apart.
  - `config.port`. The probes and the Service refer to the container port by name. The check renders with `config.port=9090` and sees all of them move together.
- [x] Verified: rendering with a changed value changes the checksum annotation.
  - In `scripts/check-chart.sh`, so the `chart` check keeps verifying it: changing `config.nodeEnv` or `config.port` changes the checksum.
- [x] The README chart-features list includes the ConfigMap and the rollout trigger.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
