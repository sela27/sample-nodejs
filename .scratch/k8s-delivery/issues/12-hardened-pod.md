# 12: Hardened pod: security context and ServiceAccount

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The pods meet the restricted Pod Security profile and run under a dedicated ServiceAccount that has no Kubernetes API token and references the registry pull secret.

**Blocked by:** 11

**Status:** done

- [x] Pod and container security context: runAsNonRoot, uid and gid 1000, read-only root filesystem, allowPrivilegeEscalation false, all capabilities dropped, and the `RuntimeDefault` seccomp profile.
- [x] A dedicated ServiceAccount with `automountServiceAccountToken: false`, and an imagePullSecrets entry that takes the pull secret name from values. The secret itself is created at Bootstrap (ADR-0003).
  - The name is `image.pullSecret`, default `ghcr-pull`. Ticket 19's Bootstrap must create the secret under that name; `scripts/check-chart.sh` pins it.
- [x] The rendered manifests still pass the `chart` check.
- [x] Verified locally: the image starts and serves with a read-only root filesystem as uid 1000.
  - `docker run --read-only --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges`: `/ready` 200, `/my-app` "Hello, World!". No writable path is needed, not even `/tmp`, so the chart has no emptyDir.
- [x] The README security-controls list gains the pod hardening rows.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
