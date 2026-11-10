# 19: Deploy the app to dev

**Spec:** k8s-delivery spec (GitOps and cluster, Bootstrap), ADR-0003

**What to build:** Bootstrap creates the GHCR pull secret from `GHCR_PULL_TOKEN`. ArgoCD's `sample-nodejs-dev` Application Deploys the chart with the `dev` values, and `/my-app` opens in the browser through the Ingress.

**Blocked by:** 12, 16, 18

**Status:** done

**Human step:** create a classic PAT with only `read:packages` and export it as `GHCR_PULL_TOKEN` before running Bootstrap. Take a browser screenshot of `/my-app`.

- [x] Bootstrap creates the app namespace with the restricted Pod Security labels, and creates the registry pull secret idempotently. It fails with a clear message if `GHCR_PULL_TOKEN` is unset, and never prints the token.
- [x] A `sample-nodejs-dev` child Application uses our chart with the `dev` values, automated sync with prune and self-heal, and its own namespace.
- [ ] ArgoCD shows the Application Synced and Healthy, with pods running as uid 1000.
- [ ] `http://sample-nodejs.127.0.0.1.nip.io/my-app` returns "Hello, World!" in the browser, and the screenshot is saved.
- [ ] After the next Bump commit, ArgoCD Deploys the new tag with no manual step.
- [x] The README Quick start covers the token and the app URL.
- [x] PR title is `chore(cluster): …`. Status set to `done` in the same PR.
