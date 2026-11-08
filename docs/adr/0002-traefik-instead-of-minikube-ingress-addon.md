# Traefik instead of minikube's ingress addon

minikube's one-command `ingress` addon installs ingress-nginx, which the Kubernetes project retired in March 2026 and no longer patches. We run Traefik, installed by ArgoCD from its official Helm chart, and keep our own `Ingress` free of controller-specific annotations (only `ingressClassName`), so the controller can be swapped without touching the chart.

## Considered Options

- **minikube `ingress` addon (ingress-nginx)**: rejected; shipping an unpatched edge component contradicts the security goals of this project.
- **Gateway API (`HTTPRoute`)**: the modern direction, but the assignment asks for an `Ingress`, and running both would add surface for no gain.
