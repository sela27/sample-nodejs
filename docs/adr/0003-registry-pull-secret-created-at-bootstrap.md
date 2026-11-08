# Registry pull secret is created at Bootstrap, outside git

Everything in the cluster comes from git except one object: the image pull secret for the private GHCR package. The Bootstrap script creates it from an environment variable, and the chart only references it by name. Encrypting it into git (Sealed Secrets) would tie it to a controller key that is regenerated whenever the local cluster is recreated, and would not let anyone else pull the private image anyway.

## Considered Options

- **Sealed Secrets**: rejected for a disposable local cluster; key backup and re-sealing would cost more than the secret is worth.
- **SOPS or External Secrets Operator**: need a repo-server plugin or an external secret store; that is the production path (External Secrets with a cloud secret manager, or workload identity with no token at all), not a local one.
