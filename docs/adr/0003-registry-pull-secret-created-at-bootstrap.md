# Registry pull secret is created at Bootstrap, outside git

Everything in the cluster comes from git except one object: the image pull secret for the private GHCR package. The Bootstrap script creates it from an environment variable, and the chart only references it by name. Encrypting it into git (Sealed Secrets) would tie it to a controller key that is regenerated whenever the local cluster is recreated, and would not let anyone else pull the private image anyway.

## Considered Options

- **Sealed Secrets**: rejected for a disposable local cluster; key backup and re-sealing would cost more than the secret is worth.
- **SOPS or External Secrets Operator**: need a repo-server plugin or an external secret store; that is the production path (External Secrets with a cloud secret manager, or workload identity with no token at all), not a local one.

## Update (2026-11-11): Grafana's admin login

Grafana's admin login, added with the monitoring stack, follows the same decision, so the cluster now has two objects that do not come from git. Bootstrap creates the Secret `monitoring/grafana-admin` with a random password, only when it does not exist yet, and the kube-prometheus-stack Application names it in `grafana.admin.existingSecret`. A password in the Application's values would be in the public repo. Leaving it to the Grafana chart does not work with ArgoCD either: the chart keeps an existing password through a `lookup`, which `helm template` cannot do, so every render would generate a new password and ArgoCD would keep rewriting the Secret.
