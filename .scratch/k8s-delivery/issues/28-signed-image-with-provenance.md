# 28: Signed image with provenance

**Spec:** k8s-delivery spec (CD on `main`, Supply chain and permissions)

**What to build:** Every pushed image is signed keylessly through GitHub OIDC and carries a build provenance attestation, and anyone can verify both.

**Blocked by:** 15

**Status:** done

**Verified before merge:** both verify commands from the README fail against `1.0.0` (digest `sha256:4dcc50ad686489944f02da7fdc5e24d140925cfdcb83b13bdbdf7087d1953f3e`), which predates signing. `cosign verify` exits 10 with `no signatures found`, run with cosign 3.1.4 from the official image pinned by digest (`sha256:0f06154836d2de34f887a5c273506d52ca43edaa1d9e53e6510fa78a48f69c2d`). `gh attestation verify` gets HTTP 404 from the attestations API for that digest. GHCR has none of the tags a signature or an attestation would be stored under (`sha256-<digest>.sig`, `sha256-<digest>`, `sha256-<digest>.att`). actionlint 1.7.12 passes on the workflows. Signing needs the OIDC token of a real run on `main`, so the green side waits for the next Release.

- [x] The release job signs the pushed image by digest with cosign in keyless mode (with `id-token: write`), and attaches a build provenance attestation (with `attestations: write`). (cosign 3.1.4 as a checksum-pinned binary, like Trivy. The attestation comes from `actions/attest` v4.2.2, which `attest-build-provenance` v4 only wraps, with `push-to-registry: true`. Only the `image` job gets the two permissions.)
- [x] The README shows the exact `cosign verify` command, with the certificate identity and issuer. Verified: it succeeds locally against the latest Release. (The command is in the README section "Image signature and provenance", next to `gh attestation verify`. Verified with the v1.1.0 Release: the README command, run with cosign 3.1.4 from the official image pinned by digest `sha256:0f061548…`, exits 0 against `ghcr.io/sela27/sample-nodejs:1.1.0`, with the claims, the Rekor entry and the certificate chain checked for digest `sha256:ea0adf3f…`.)
- [x] Verified on the next Release after this merges. (Verified with the v1.1.0 Release, run 42843956960: `cosign verify` and the README's `gh attestation verify --deny-self-hosted-runners` both exit 0 against `1.1.0`. The attestation is SLSA provenance v1 for `sha256:ea0adf3f…`, from `refs/heads/main`, run 42843956960, on a GitHub-hosted runner.)
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
