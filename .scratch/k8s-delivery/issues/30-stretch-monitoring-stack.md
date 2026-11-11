# 30: Stretch: monitoring stack

**Spec:** k8s-delivery spec (Stretch)

**What to build:** Prometheus scrapes the app, and Grafana shows the root access counter rising.

**Blocked by:** 19, 25

**Status:** done

**Human step:** screenshot of the Grafana panel. Check Docker Desktop's memory first.

**Done on minikube (2026-11-11):** from this branch, with `root` and `sample-nodejs-dev` pointed at it. ArgoCD needed about two hours to fetch the chart, as GitHub Pages served its index at 2 to 50 KB/s that day; its fetch timeouts went up to five minutes on the way. Grafana 13 was OOM-killed under its first 256 MiB limit and now has 512 MiB. The README's Monitoring section has the timeline.

- [x] kube-prometheus-stack is installed as an ArgoCD child Application at a pinned version, trimmed to what this cluster needs. (`gitops/apps/kube-prometheus-stack.yaml`, chart 93.1.2: the operator, one Prometheus and Grafana; Alertmanager, the exporters, the default rules and dashboards and the control-plane scrapes are off)
- [x] The ServiceMonitor flag is on in the `dev` values, and the app's Prometheus target is up. (`serviceMonitor.enabled: true` in `values-dev.yaml`; both app pods `up` in Prometheus, synced on `sample-nodejs-dev`'s last retry once the CRD existed)
- [x] A Grafana panel shows `root_access_total` summed across pods, rising after requests to `/my-app`. The screenshot is saved. (dashboard `sample-nodejs`; 50 requests raised `sum(root_access_total)` by exactly 50, and a 30-minute run of 3517 requests by exactly 3517; `docs/screenshots/30-grafana-root-access-total.png`)
- [x] Cluster memory use after install is recorded in the README. (README, Monitoring: `docker stats` 2.81 to 3.47 GiB of 4 GiB, node heap 2.84 GiB, per-container table)
- [x] PR title is `chore(cluster): …`. Status set to `done` in the same PR. (PR #41)
