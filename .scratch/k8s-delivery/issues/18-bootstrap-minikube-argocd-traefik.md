# 18: Bootstrap: minikube, ArgoCD and Traefik

**Spec:** k8s-delivery spec (Bootstrap, GitOps and cluster), ADR-0002

**What to build:** One idempotent script brings up minikube with Calico and metrics-server, installs a pinned ArgoCD, and applies the root Application. ArgoCD then installs Traefik from git, and Traefik answers on localhost through the tunnel.

**Blocked by:** 01

**Status:** ready-for-agent

**Human step:** if needed, raise Docker Desktop's memory to 8 GB. Run `minikube tunnel` in a separate terminal (it may ask for admin rights).

- [ ] A bash script that runs from Git Bash and on Linux and macOS, in strict mode. It checks for docker, minikube, kubectl and helm and gives a clear message if any is missing.
- [ ] minikube starts with the Calico CNI, with CPU and memory set in variables. Re-running on an existing cluster does not fail.
- [ ] The metrics-server addon is enabled.
- [ ] ArgoCD is installed from its Helm chart at a pinned version. The script waits until it is ready, and re-running upgrades it in place.
- [ ] The root Application (app-of-apps) is applied, pointing at the child-Applications directory on `main` of the public repo.
- [ ] A Traefik child Application uses the official chart at a pinned version, a LoadBalancer Service, automated sync with prune and self-heal, and namespace creation.
- [ ] With the tunnel running, a request to `http://sample-nodejs.127.0.0.1.nip.io/` gets Traefik's own 404 (no app route yet).
- [ ] The script prints how to read the ArgoCD admin password, how to open the ArgoCD UI, and the tunnel instruction.
- [ ] The README gains a "Quick start" section.
- [ ] PR title is `chore(cluster): …`. Status set to `done` in the same PR.
