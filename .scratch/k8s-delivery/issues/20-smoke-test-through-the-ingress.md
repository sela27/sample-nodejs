# 20: Smoke test through the Ingress

**Spec:** k8s-delivery spec (Smoke test, Seam 2)

**What to build:** One command verifies a Deploy from outside the cluster: the Public paths answer 200, and the internal paths answer 404.

**Blocked by:** 19

**Status:** done

**Human step:** screenshots of `/classified` returning 404 in the browser, and of the ArgoCD application tree Synced and Healthy.

- [x] A bash script with an overridable host checks: 200 and the expected body from `/my-app`, 200 from `/about`, and 404 from `/classified`, `/metrics` and `/ready`.
- [x] It prints PASS or FAIL per path and exits non-zero on any failure.
- [x] It passes against `dev`.
- [x] Both screenshots are saved. (2026-11-10, after `scripts/smoke-test.sh` passed all five paths through the tunnel: `docs/screenshots/20-classified-404-in-browser.png` and `docs/screenshots/20-argocd-app-tree-synced-healthy.png`. The browser's bookmarks bar was cut out of the copies.)
- [x] The README gains a "Verifying a Deploy" section.
- [x] PR title is `test: …`. Status set to `done` in the same PR.

`scripts/smoke-test.sh` goes through `minikube tunnel` by default, and through its own port-forward to Traefik with `--port-forward`. `APP_HOST` (sent as the `Host` header) and `BASE_URL` override where it points.

The agent proved it can fail before running it green. Every red run exited 1:

- With the tunnel down, the default run got no response on all five paths and said to start the tunnel or use `--port-forward`.
- Through Traefik with a host that has no route (`APP_HOST=no-route.127.0.0.1.nip.io`), `/my-app` and `/about` failed with 404.
- Straight at the app Service (`BASE_URL` on a port-forward to `service/sample-nodejs-dev`, so no Ingress), `/classified`, `/metrics` and `/ready` failed with 200.

Then `scripts/smoke-test.sh --port-forward` passed all five paths against `dev` and exited 0.

One criterion is left for the human, because it needs the tunnel and a browser:

- **Both screenshots.** Start `minikube tunnel`, run `scripts/smoke-test.sh` (all five paths must PASS through the tunnel), then save:
  - `docs/screenshots/20-classified-404-in-browser.png`: `http://sample-nodejs.127.0.0.1.nip.io/classified` in the browser, showing Traefik's `404 page not found`.
  - `docs/screenshots/20-argocd-app-tree-synced-healthy.png`: the `sample-nodejs-dev` application tree in the ArgoCD UI, Synced and Healthy. It turns Healthy only once the tunnel gives the Ingress an address.
