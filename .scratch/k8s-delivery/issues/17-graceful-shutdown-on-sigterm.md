# 17: Graceful shutdown on SIGTERM

**Spec:** k8s-delivery spec (App, Seam 1)

**What to build:** On SIGTERM the server stops accepting connections, lets in-flight requests finish, and exits with code 0. A timeout forces exit if connections linger.

**Blocked by:** 02

**Scheduling note:** this ticket is placed after 16 on purpose. Its `feat` merge is the first Release after the Bump commit exists, so it is what verifies ticket 16.

**Status:** done

**Verified before merge:** the four new tests in `test/entrypoint.test.js` were run inside a `node:24-alpine` container (the Dockerfile's base digest, Node 24.22.2) with the worktree mounted. Against `main`'s `app.js` all four fail and the two existing entrypoint tests pass. With this PR all 14 tests in `test/app.test.js` and `test/entrypoint.test.js` pass, and the entrypoint tests passed five runs in a row. On the Windows host the four are skipped and the other ten pass.

- [x] SIGTERM and SIGINT close the server, and the process exits 0 once it has closed. A documented timeout (shorter than the pod's termination grace period) forces exit. (`SHUTDOWN_TIMEOUT_MS`, default 10 s, under the default 30 s grace period that the chart keeps for now. The forced exit is code 1. Answers sent while closing carry `Connection: close`, so keep-alive clients do not hold the shutdown open.)
- [x] A process-level test starts the entrypoint on an ephemeral port as a child process, gets 200 from `/ready`, sends SIGTERM, and asserts exit code 0 within the timeout. The test is skipped on Windows. (It also runs for SIGINT. Two more tests cover a request in flight at SIGTERM and the forced exit.)
- [x] Verified locally: `docker stop` on the container returns promptly, not after the 10-second kill. (`docker stop -t 10` on the hardened container: 0.58 s with exit code 0, against 10.66 s with exit code 137 for `main`'s image. This Docker Desktop's own default stop timeout is 1 s, which is why `-t 10` is explicit.)
- [ ] PR title is `feat(app): …`. Merging it produces `v1.1.0` and a Bump commit that sets the `dev` tag to `1.1.0`. The PR title is `feat(app): …`. The Release and the Bump commit are verified after merge.
- [x] The README notes the shutdown behaviour.
- [x] Status set to `done` in the same PR.
