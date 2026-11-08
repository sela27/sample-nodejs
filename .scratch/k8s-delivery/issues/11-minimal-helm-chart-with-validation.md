# 11: Minimal Helm chart with chart validation

**Spec:** k8s-delivery spec (Helm chart)

**What to build:** The chart renders a Deployment with probes and resources, a ClusterIP Service, and a Traefik Ingress that exposes only the Public paths. The `dev` values set the host and the image. CI lints the chart and validates the rendered output against Kubernetes schemas.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] The chart lives in the GitOps directory (ADR-0001), with chart defaults and a separate `dev` values file. That file sets the image repository to `ghcr.io/sela27/sample-nodejs`, documents the tag placeholder, and sets the host to `sample-nodejs.127.0.0.1.nip.io`.
- [ ] Deployment: startup and liveness probes on `/live`, readiness probe on `/ready`, container port 8080, and resources from values.
- [ ] Service: ClusterIP, port 80 to 8080.
- [ ] Ingress: `ingressClassName: traefik`, no controller-specific annotations, Prefix paths for `/my-app` and `/about` only, and the host from values.
- [ ] Standard `app.kubernetes.io/*` labels.
- [ ] Job `chart` runs `helm lint`, then renders with the `dev` values and runs kubeconform in strict mode against a pinned Kubernetes version. `chart` is added to the required checks.
- [ ] The README gains a "Helm chart" section, including the Deployment-vs-StatefulSet justification.
- [ ] PR title is `chore(chart): …`. Chart changes reach the cluster through ArgoCD and never produce a Release. Status set to `done` in the same PR.
