# 03: Container image

**Spec:** k8s-delivery spec (Container image)

**What to build:** `docker build` produces a small image based on `node:24-alpine` that runs as non-root and has no npm in it. Running the image serves the app.

**Blocked by:** 01

**Status:** done

- [x] The build is multi-stage. The base image is pinned by digest, with the tag kept in a comment. The build stage installs production dependencies only, from the lockfile.
- [x] The runtime stage contains only the app source and its production dependencies. npm, npx and corepack are absent (running `npm` inside the container fails).
- [x] The container runs as the `node` user (uid 1000) and exposes 8080.
- [x] The dockerignore keeps tests, git metadata, docs, the tracker directory and tooling out of the build context.
- [x] Locally: the image builds, and running it returns 200 on `/ready` and "Hello, World!" on `/my-app`.
- [x] The README prerequisite moves to Node 24. A "Container image" section explains the base-image choice using the Trivy baseline from the spec.
- [x] PR title is `build: …`. Status set to `done` in the same PR.
