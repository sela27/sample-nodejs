# 30: Stretch: monitoring stack

**Spec:** k8s-delivery spec (Stretch)

**What to build:** Prometheus scrapes the app, and Grafana shows the root access counter rising.

**Blocked by:** 19, 25

**Status:** ready-for-agent

**Human step:** screenshot of the Grafana panel. Check Docker Desktop's memory first.

- [ ] kube-prometheus-stack is installed as an ArgoCD child Application at a pinned version, trimmed to what this cluster needs.
- [ ] The ServiceMonitor flag is on in the `dev` values, and the app's Prometheus target is up.
- [ ] A Grafana panel shows `root_access_total` summed across pods, rising after requests to `/my-app`. The screenshot is saved.
- [ ] Cluster memory use after install is recorded in the README.
- [ ] PR title is `chore(cluster): …`. Status set to `done` in the same PR.
