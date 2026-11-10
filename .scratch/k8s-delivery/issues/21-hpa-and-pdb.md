# 21: HPA and PodDisruptionBudget

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The app scales between two and five replicas on CPU, and voluntary disruptions always leave at least one pod serving.

**Blocked by:** 19

**Status:** done

- [x] An HPA (autoscaling/v2) with min 2, max 5 and a 70% CPU target, all from values. While the HPA is enabled, the Deployment does not set `replicas`.
- [x] A PodDisruptionBudget with `minAvailable: 1`.
- [x] ArgoCD stays Synced, with no permanent diff on replicas.
- [x] `kubectl get hpa` shows real CPU readings (from metrics-server), and two pods are running.
- [x] Optional: a short load test shows a scale-up, written up in the README.
- [x] The README chart-features list includes the HPA and the PDB.
- [x] PR title is `chore(chart): …`. Status set to `done` in the same PR.
