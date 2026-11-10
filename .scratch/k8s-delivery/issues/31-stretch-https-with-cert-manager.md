# 31: Stretch: HTTPS with cert-manager

**Spec:** k8s-delivery spec (Stretch)

**What to build:** The app is served over HTTPS through the Ingress, with a certificate issued by cert-manager from a self-signed issuer.

**Blocked by:** 19, 26

**Status:** done

**Human step:** screenshot of the app over HTTPS.

- [ ] cert-manager is installed as an ArgoCD child Application at a pinned version, together with a self-signed ClusterIssuer. The manifests are in this PR (chart v1.21.3, and the issuer as its own Application with a retry policy); that ArgoCD syncs both is verified after the merge, because ArgoCD tracks `main`.
- [ ] The TLS flag is on in the `dev` values (done and checked by `check-chart.sh` in this PR; the issued certificate and the HTTPS answer are verified after the merge). A certificate is issued and `https://sample-nodejs.127.0.0.1.nip.io/my-app` serves the app, with the expected self-signed browser warning.
- [x] The smoke test accepts an HTTPS base URL. Checked before the merge against stubbed curl and kubectl (`test/smoke-test.test.js`); a run against the real certificate is verified after the merge.
- [x] The README documents this.
- [x] PR title is `chore(cluster): …`. Status set to `done` in the same PR.

**Verified after the merge** (ArgoCD tracks `main`): ArgoCD syncs cert-manager and the issuer on the live cluster; the Certificate becomes Ready; `https://sample-nodejs.127.0.0.1.nip.io/my-app` serves the app with that certificate; `scripts/smoke-test.sh --port-forward --https` passes against it. A follow-up PR ticks the criteria that depend on this and records the cluster's memory after the install.
