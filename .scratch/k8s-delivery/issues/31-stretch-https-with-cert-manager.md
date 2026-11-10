# 31: Stretch: HTTPS with cert-manager

**Spec:** k8s-delivery spec (Stretch)

**What to build:** The app is served over HTTPS through the Ingress, with a certificate issued by cert-manager from a self-signed issuer.

**Blocked by:** 19, 26

**Status:** done

**Human step:** screenshot of the app over HTTPS. Done 2026-11-10: `docs/screenshots/31-app-over-https.png` shows `/my-app` over HTTPS with the browser's "Not secure" warning and the certificate viewer open (issued that day, valid 90 days).

- [x] cert-manager is installed as an ArgoCD child Application at a pinned version (chart v1.21.3), together with a self-signed ClusterIssuer (its own Application, with a retry policy). Verified on the cluster after the merge on 2026-11-10: both Applications Synced and Healthy, `selfsigned-issuer` Ready.
- [x] The TLS flag is on in the `dev` values. A certificate is issued (Ready) and `https://sample-nodejs.127.0.0.1.nip.io/my-app` serves the app, with the expected self-signed browser warning. Verified after the merge with `curl` against the secret's CA through the tunnel; the browser screenshot is `docs/screenshots/31-app-over-https.png`.
- [x] The smoke test accepts an HTTPS base URL. Checked before the merge against stubbed curl and kubectl (`test/smoke-test.test.js`), and after it against the real certificate: it passes with the CA verified through the tunnel and with `--port-forward --https`.
- [x] The README documents this.
- [x] PR title is `chore(cluster): …`. Status set to `done` in the same PR.

**Verified after the merge** (2026-11-10): ArgoCD synced both Applications; the Certificate is Ready and `ca.crt` is filled; the smoke test passes over HTTPS (tunnel and `--port-forward --https`) and over HTTP (tunnel and `--port-forward`); `verify-bootstrap.sh` passes. Cluster memory went from about 2.6 GiB to 2.89 GiB of 4 GiB (README, "HTTPS"). Still open: the screenshot of the app over HTTPS, a human step.
