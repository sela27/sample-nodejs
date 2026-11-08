# 12: Hardened pod: security context and ServiceAccount

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The pods meet the restricted Pod Security profile and run under a dedicated ServiceAccount that has no Kubernetes API token and references the registry pull secret.

**Blocked by:** 11

**Status:** ready-for-agent

- [ ] Pod and container security context: runAsNonRoot, uid and gid 1000, read-only root filesystem, allowPrivilegeEscalation false, all capabilities dropped, and the `RuntimeDefault` seccomp profile.
- [ ] A dedicated ServiceAccount with `automountServiceAccountToken: false`, and an imagePullSecrets entry that takes the pull secret name from values. The secret itself is created at Bootstrap (ADR-0003).
- [ ] The rendered manifests still pass the `chart` check.
- [ ] Verified locally: the image starts and serves with a read-only root filesystem as uid 1000.
- [ ] The README security-controls list gains the pod hardening rows.
- [ ] PR title is `chore(chart): …`. Status set to `done` in the same PR.
