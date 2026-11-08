# 17: Graceful shutdown on SIGTERM

**Spec:** k8s-delivery spec (App, Seam 1)

**What to build:** On SIGTERM the server stops accepting connections, lets in-flight requests finish, and exits with code 0. A timeout forces exit if connections linger.

**Blocked by:** 02

**Scheduling note:** this ticket is placed after 16 on purpose. Its `feat` merge is the first Release after the Bump commit exists, so it is what verifies ticket 16.

**Status:** ready-for-agent

- [ ] SIGTERM and SIGINT close the server, and the process exits 0 once it has closed. A documented timeout (shorter than the pod's termination grace period) forces exit.
- [ ] A process-level test starts the entrypoint on an ephemeral port as a child process, gets 200 from `/ready`, sends SIGTERM, and asserts exit code 0 within the timeout. The test is skipped on Windows.
- [ ] Verified locally: `docker stop` on the container returns promptly, not after the 10-second kill.
- [ ] PR title is `feat(app): …`. Merging it produces `v1.1.0` and a Bump commit that sets the `dev` tag to `1.1.0`.
- [ ] The README notes the shutdown behaviour.
- [ ] Status set to `done` in the same PR.
