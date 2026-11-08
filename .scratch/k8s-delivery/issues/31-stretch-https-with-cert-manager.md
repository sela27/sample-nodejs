# 31: Stretch: HTTPS with cert-manager

**Spec:** k8s-delivery spec (Stretch)

**What to build:** The app is served over HTTPS through the Ingress, with a certificate issued by cert-manager from a self-signed issuer.

**Blocked by:** 19, 26

**Status:** ready-for-agent

**Human step:** screenshot of the app over HTTPS.

- [ ] cert-manager is installed as an ArgoCD child Application at a pinned version, together with a self-signed ClusterIssuer.
- [ ] The TLS flag is on in the `dev` values. A certificate is issued and `https://sample-nodejs.127.0.0.1.nip.io/my-app` serves the app, with the expected self-signed browser warning.
- [ ] The smoke test accepts an HTTPS base URL.
- [ ] The README documents this.
- [ ] PR title is `chore(cluster): …`. Status set to `done` in the same PR.
