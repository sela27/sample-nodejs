# 27: SBOM on every Release

**Spec:** k8s-delivery spec (CD on `main`)

**What to build:** Every Release carries a CycloneDX SBOM of the pushed image as a GitHub Release asset.

**Blocked by:** 15

**Status:** done

**Human step:** screenshot of a GitHub Release with the SBOM attached. Done 2026-11-10: `docs/screenshots/27-release-with-sbom.png` shows `v1.1.0` with `sample-nodejs-1.1.0.cdx.json` among its assets.

- [x] The release job generates a CycloneDX SBOM of the pushed image, by digest, and semantic-release attaches it to the GitHub Release.
- [x] Verified on the next Release after this merges: the asset is present and parses as CycloneDX. (Verified with the v1.1.0 Release, run 42843956960: `sample-nodejs-1.1.0.cdx.json` is attached, `cyclonedx/cyclonedx-cli:0.33.1 validate --fail-on-errors` prints `BOM validated successfully.`, it is CycloneDX 1.7 with 98 components, and its RepoDigest is the `1.1.0` digest `sha256:ea0adf3f…`.)
- [x] The README supply-chain section describes the SBOM.
- [x] PR title is `ci: …`. Status set to `done` in the same PR.
