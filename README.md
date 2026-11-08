# DevOps Sample Node.js App

## Overview

A lightweight Node.js application. It features basic web endpoints, Prometheus metrics integration, and is designed for Kubernetes deployment and CI/CD pipeline demonstrations.

## Features

- Express.js web server
- Prometheus metrics integration
- Readiness and liveness probe endpoints
- Customizable port via environment variable

## Prerequisites

- Node.js (v22.1.0)

## Quick start

One command brings up a local cluster in which ArgoCD manages everything else from git. You need Docker (Docker Desktop on Windows and macOS), minikube, kubectl and Helm. The script runs from Git Bash on Windows and from bash on Linux and macOS.

```bash
scripts/bootstrap.sh
```

The script starts minikube with the Calico CNI (so NetworkPolicies are enforced) and the metrics-server addon, installs ArgoCD from its pinned Helm chart, and applies the root Application (`gitops/bootstrap/root-app.yaml`). ArgoCD then installs everything declared under `gitops/apps` on `main`. For now that is the Traefik ingress controller ([ADR-0002](docs/adr/0002-traefik-instead-of-minikube-ingress-addon.md)). Re-running the script is safe, because it reuses a running cluster and upgrades ArgoCD in place. It ends by printing how to read the ArgoCD admin password and how to open the ArgoCD UI.

Then start the tunnel in a separate terminal and leave it running. It may ask for admin rights, because it binds ports 80 and 443 on localhost:

```bash
minikube tunnel
```

With the tunnel up, `http://sample-nodejs.127.0.0.1.nip.io/` answers with Traefik's own `404 page not found`, because no app route exists yet. `scripts/verify-bootstrap.sh` checks the whole setup and prints PASS, FAIL or SKIP for each check. The tunnel check runs only while the tunnel is up.

| Variable | Default | Purpose |
| --- | --- | --- |
| `MINIKUBE_PROFILE` | `minikube` | minikube profile and kubectl context |
| `MINIKUBE_CPUS` | `4` | CPUs for the minikube node |
| `MINIKUBE_MEMORY` | `4096` | Memory for the minikube node, in MiB |
| `KUBERNETES_VERSION` | `v1.35.1` | Kubernetes version of the node |
| `ARGOCD_CHART_VERSION` | `10.17.0` (ArgoCD v3.6.1) | `argo/argo-cd` Helm chart version |
| `GIT_REPO_URL` | this repo | Repo the root Application follows |
| `GIT_REVISION` | `main` | Revision the root Application follows. Set it to a pushed branch to try child Applications before they merge, then re-run without it. |

The defaults fit Docker Desktop with about 6 GB of memory. minikube cannot resize an existing cluster, so a new CPU or memory value takes effect only after `minikube delete`. Traefik's version is pinned in `gitops/apps/traefik.yaml` (chart 42.3.1, Traefik v3.7.17).
