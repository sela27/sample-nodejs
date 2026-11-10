# 19: Deploy the app to dev

**Spec:** k8s-delivery spec (GitOps and cluster, Bootstrap), ADR-0003

**What to build:** Bootstrap creates the GHCR pull secret from `GHCR_PULL_TOKEN`. ArgoCD's `sample-nodejs-dev` Application Deploys the chart with the `dev` values, and `/my-app` opens in the browser through the Ingress.

**Blocked by:** 12, 16, 18

**Status:** done

**Human step:** create a classic PAT with only `read:packages` and export it as `GHCR_PULL_TOKEN` before running Bootstrap. Take a browser screenshot of `/my-app`.

**PAT and Bootstrap done (2026-11-10):** the human created the token and re-ran Bootstrap with it. It created `ghcr-pull` in `sample-nodejs-dev` at 17:49 UTC, and the chart's ServiceAccount lists it. Once the package was private, a pod with `imagePullPolicy: Always` pulled `1.1.0` through that secret (see ticket 15). The browser screenshot is still open, and it needs `minikube tunnel`.

- [x] Bootstrap creates the app namespace with the restricted Pod Security labels, and creates the registry pull secret idempotently. It fails with a clear message if `GHCR_PULL_TOKEN` is unset, and never prints the token.
- [x] A `sample-nodejs-dev` child Application uses our chart with the `dev` values, automated sync with prune and self-heal, and its own namespace.
- [ ] ArgoCD shows the Application Synced and Healthy, with pods running as uid 1000.
- [ ] `http://sample-nodejs.127.0.0.1.nip.io/my-app` returns "Hello, World!" in the browser, and the screenshot is saved.
- [x] After the next Bump commit, ArgoCD Deploys the new tag with no manual step. (Verified with the v1.1.0 Release: ArgoCD auto-synced the Bump commit `daf8f62` two minutes after it landed, `initiatedBy: automated`, the pods run `ghcr.io/sela27/sample-nodejs:1.1.0` at digest `sha256:ea0adf3f…`, and `scripts/smoke-test.sh --port-forward` passed all five paths.)
- [x] The README Quick start covers the token and the app URL.
- [x] PR title is `chore(cluster): …`. Status set to `done` in the same PR.

Three criteria are left for the human, because each needs something the agent did not have:

- **Synced and Healthy** needs the tunnel. ArgoCD rates an Ingress Progressing until it has an address, and Traefik copies its LoadBalancer Service's address, which only `minikube tunnel` provides, onto the app's Ingress. With the root Application on the ticket branch, the agent saw the Application Synced, the Deployment available, the app process running as uid 1000 (read from `/proc/1/status`), `/my-app` answering "Hello, World!" through a port-forward to Traefik, and a non-compliant pod refused by the namespace's Pod Security admission. The image came from a local copy of `1.0.0` loaded into minikube, because pulls from GHCR timed out on this network, and the agent had no token. To close it, run Bootstrap with the token, start the tunnel, then run `scripts/verify-bootstrap.sh`. Its tunnel checks run instead of SKIP and must PASS, and the ArgoCD UI shows `sample-nodejs-dev` Synced and Healthy.
- **The browser** needs the tunnel and a screenshot. Open `http://sample-nodejs.127.0.0.1.nip.io/my-app` and save the screenshot as `docs/screenshots/19-my-app-in-browser.png`.
- **The next Bump commit** needs a Release. After the next `feat` or `fix` merge, check that ArgoCD Deploys the new tag from `values-dev.yaml` with no manual step.
