# 02: Make the app testable through its HTTP interface

**Spec:** k8s-delivery spec (Seam 1)

**What to build:** The app can be loaded without opening a port, and tests drive every endpoint through real HTTP requests. `npm test` runs them. This is the prefactor that opens Seam 1.

**Blocked by:** 01

**Status:** done

- [x] Loading the app module does not listen. Running it as the entrypoint listens on `PORT` (default 8080) and prints the same startup line as before.
- [x] Routes and response bodies are unchanged.
- [x] Tests use Node's built-in test runner, with supertest as a dev dependency. They cover status and body for `/my-app`, `/about`, `/ready`, `/live` and `/classified`, and 404 for an unknown path.
- [x] A metrics test asserts the Prometheus content type, that `root_access_total` is present, and that its value increases by one after a request to `/my-app`.
- [x] The placeholder failing test script is replaced, and `npm test` passes locally.
- [x] The README gains a "Running tests" section.
- [x] PR title is `test: …` (no Release). Status set to `done` in the same PR.
