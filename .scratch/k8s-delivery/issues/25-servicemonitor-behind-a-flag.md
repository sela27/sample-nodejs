# 25: ServiceMonitor behind a flag

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The chart can expose the app to a Prometheus Operator with one flag, and it stays off by default, so the cluster needs no monitoring CRDs today.

**Blocked by:** 22

**Status:** done

- [x] With `serviceMonitor.enabled: false` (the default), the rendered output is unchanged and contains no ServiceMonitor.
- [x] With the flag on, the chart renders a ServiceMonitor that scrapes `/metrics` on the Service's named port. The NetworkPolicy also admits the monitoring namespace, whose name comes from values.
- [x] The `chart` check covers the flag-on render, either with the ServiceMonitor CRD schema or with a documented skip for that kind.
- [x] The README describes how to turn monitoring on.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
