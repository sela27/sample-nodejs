# 28: Signed image with provenance

**Spec:** k8s-delivery spec (CD on `main`, Supply chain and permissions)

**What to build:** Every pushed image is signed keylessly through GitHub OIDC and carries a build provenance attestation, and anyone can verify both.

**Blocked by:** 15

**Status:** ready-for-agent

- [ ] The release job signs the pushed image by digest with cosign in keyless mode (with `id-token: write`), and attaches a build provenance attestation (with `attestations: write`).
- [ ] The README shows the exact `cosign verify` command, with the certificate identity and issuer. Verified: it succeeds locally against the latest Release.
- [ ] Verified on the next Release after this merges.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
