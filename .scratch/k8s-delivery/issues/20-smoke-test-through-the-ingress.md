# 20: Smoke test through the Ingress

**Spec:** k8s-delivery spec (Smoke test, Seam 2)

**What to build:** One command verifies a Deploy from outside the cluster: the Public paths answer 200, and the internal paths answer 404.

**Blocked by:** 19

**Status:** ready-for-agent

**Human step:** screenshots of `/classified` returning 404 in the browser, and of the ArgoCD application tree Synced and Healthy.

- [ ] A bash script with an overridable host checks: 200 and the expected body from `/my-app`, 200 from `/about`, and 404 from `/classified`, `/metrics` and `/ready`.
- [ ] It prints PASS or FAIL per path and exits non-zero on any failure.
- [ ] It passes against `dev`.
- [ ] Both screenshots are saved.
- [ ] The README gains a "Verifying a Deploy" section.
- [ ] PR title is `test: …`. Status set to `done` in the same PR.
