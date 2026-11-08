# 27: SBOM on every Release

**Spec:** k8s-delivery spec (CD on `main`)

**What to build:** Every Release carries a CycloneDX SBOM of the pushed image as a GitHub Release asset.

**Blocked by:** 15

**Status:** ready-for-agent

**Human step:** screenshot of a GitHub Release with the SBOM attached.

- [ ] The release job generates a CycloneDX SBOM of the pushed image, by digest, and semantic-release attaches it to the GitHub Release.
- [ ] Verified on the next Release after this merges: the asset is present and parses as CycloneDX.
- [ ] The README supply-chain section describes the SBOM.
- [ ] PR title is `ci: …`. Status set to `done` in the same PR.
