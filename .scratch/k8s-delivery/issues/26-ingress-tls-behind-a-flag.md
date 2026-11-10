# 26: Ingress TLS behind a flag

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The chart can serve HTTPS through cert-manager with one flag, and it stays off by default.

**Blocked by:** 11

**Status:** done

- [x] With the TLS flag off (the default), the rendered Ingress is unchanged.
- [x] With the flag on, the Ingress gains a TLS section for the host, with a secret name, and a cert-manager cluster-issuer annotation taken from values.
- [x] The `chart` check covers the flag-on render.
- [x] The README explains that production would use Let's Encrypt, and why this local setup would be self-signed.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
