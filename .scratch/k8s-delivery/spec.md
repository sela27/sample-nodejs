# Spec: Kubernetes delivery for sample-nodejs

Status: ready-for-agent

## Problem Statement

I am a DevOps engineer candidate with a home assignment: take a small Express sample app and show, end to end, how I would ship it to Kubernetes with DevOps and DevSecOps best practices. Today the repo contains only the app (one source file, two dependencies, no tests, no Dockerfile, no chart, no pipeline) plus a pile of AI tooling that has nothing to do with the deliverable. Its locked dependencies already carry one critical and three high vulnerabilities, it calls `listen` at import time so it cannot be tested in-process, it ignores SIGTERM, and it exposes an internal `/classified` endpoint next to its public ones.

The reviewers will judge the result from a repo link, a README and screenshots, because they will not get access to my cluster. They explicitly want to see: a Helm chart with a justified Deployment-vs-StatefulSet choice and rich manifest features; a pipeline with a chosen git workflow and version bumping, SAST that fails on critical findings, an image scan that blocks deployment on high-severity findings, a build that pushes to a private registry, and an ArgoCD GitOps deployment with a justified repo layout.

## Solution

A single public repo that contains the app, its container image definition, its Helm chart, the GitOps manifests ArgoCD watches, the CI/CD workflows, a Bootstrap script for a local minikube cluster, and a README that explains every choice and shows the evidence.

From my perspective as the developer: I open a PR per ticket; every PR runs tests and every Gate (SAST, secrets, IaC misconfiguration, image vulnerabilities); a red Gate makes the merge button unavailable. When I squash-merge a `feat:` or `fix:` PR, the pipeline computes the next Release version, builds and scans the image, pushes it to a private GHCR package only if it is clean, signs it, publishes the Release with an SBOM, and makes a Bump commit. ArgoCD sees the Bump commit and Deploys to the `dev` Environment; ArgoCD, not the pipeline, tells me whether the Deploy is healthy.

From the reviewer's perspective: one Bootstrap command brings up the whole cluster (they need their own GHCR token to pull the private image), the README answers every "why" the assignment asks, and screenshots show the app reachable through the Ingress, `/classified` returning 404, ArgoCD Synced and Healthy, a PR blocked by a real vulnerability that the pipeline caught in the original sample app, a Demo PR blocked by SAST, and a green release run.

## User Stories

### Reviewer

1. As a reviewer, I want one repo link that contains the app, chart, GitOps manifests and pipelines, so that I can evaluate everything in one place.
2. As a reviewer, I want the README to justify Deployment over StatefulSet, so that I can see the candidate reasons about workload types instead of guessing.
3. As a reviewer, I want the README to justify keeping GitOps manifests in the app repo, so that I can see the trade-off was considered.
4. As a reviewer, I want the README to name the git workflow and version-bumping scheme, so that I can see how a commit becomes a version.
5. As a reviewer, I want to see a PR that a Gate blocked because of a real critical dependency vulnerability, so that I know the image Gate actually stops deployments.
6. As a reviewer, I want to see a Demo PR that the SAST Gate blocked, so that I know the SAST Gate fails on critical code findings.
7. As a reviewer, I want to see a green pipeline run on `main` with every stage visible, so that I can follow the release flow.
8. As a reviewer, I want a screenshot of `/my-app` loaded in a browser through the Ingress, so that I know the app is really running behind an Ingress.
9. As a reviewer, I want a screenshot of `/classified` returning 404 through the Ingress, so that I can see internal endpoints are not exposed.
10. As a reviewer, I want a screenshot of the ArgoCD application tree Synced and Healthy, so that I can see GitOps Deploys working.
11. As a reviewer, I want to see that the container image lives in a private registry, so that I know the private-registry requirement is met.
12. As a reviewer, I want to see a GitHub Release with an SBOM attached, so that I can see supply-chain artifacts are produced.
13. As a reviewer, I want to see the SonarQube Cloud dashboard for the project, so that I can see SAST results beyond the pass/fail signal.
14. As a reviewer, I want a single security-controls summary in the README, so that I can check DevSecOps coverage at a glance.
15. As a reviewer, I want an architecture diagram in the README, so that I can understand how the repo, pipeline, registry, ArgoCD and cluster connect.
16. As a reviewer, I want a "what would change in production" section, so that I can see the candidate knows where the local setup is a simplification.
17. As a reviewer, I want one Bootstrap command that recreates the cluster, so that I can reproduce the setup if I choose to.
18. As a reviewer, I want the repo free of unrelated AI tooling, so that I can focus on the DevOps deliverable.
19. As a reviewer, I want a short description of the AI-assisted workflow (grilling, spec, tickets, PR per ticket), so that I understand how the work was produced.
20. As a reviewer, I want ADRs for the non-obvious decisions, so that I can read the reasoning behind choices that deviate from defaults.

### Developer

21. As a developer, I want the app to be importable without starting a server, so that I can test it through HTTP in-process.
22. As a developer, I want tests for every endpoint's status and body, so that changes to routes are caught before merge.
23. As a developer, I want a test that the metrics endpoint exposes the root access counter and that it increases after a hit on `/my-app`, so that the metrics contract is protected.
24. As a developer, I want a test that the server exits cleanly on SIGTERM, so that graceful shutdown cannot regress silently.
25. As a developer, I want the app to stop accepting connections and finish in-flight requests on SIGTERM, so that rollouts do not drop requests.
26. As a developer, I want the port configurable through an environment variable, so that the chart controls it.
27. As a developer, I want a multi-stage Dockerfile, so that build-time tooling never reaches the runtime image.
28. As a developer, I want the runtime image to contain no npm or npx, so that the image Gate is not tripped by tooling the app never runs.
29. As a developer, I want the image to run as a non-root user, so that a compromised process has fewer privileges.
30. As a developer, I want the base image pinned by digest, so that builds are reproducible and changes arrive only through Dependabot PRs.
31. As a developer, I want a Dockerfile linter in CI, so that Dockerfile anti-patterns are caught.
32. As a developer, I want a branch per ticket and a PR per ticket, so that progress is easy to follow and every change goes through the Gates.
33. As a developer, I want my PR title to follow Conventional Commits and decide the version on squash merge, so that versioning needs no manual step.
34. As a developer, I want `docs:` and `chore:` merges to produce no Release, so that README edits do not ship a new image.
35. As a developer, I want chart-only changes to reach the cluster without a Release, so that configuration fixes do not need a fake version bump.
36. As a developer, I want each ticket's status updated in the same PR that completes it, so that the tracker reflects reality.

### Pipeline and Gates

37. As a developer, I want SAST to run on every PR and fail when any vulnerability of the top severities exists anywhere in the code, so that critical code findings block merge regardless of SonarQube's new-code period.
38. As a developer, I want secret scanning on every PR, so that leaked credentials block merge.
39. As a developer, I want IaC misconfiguration scanning of the Dockerfile and chart that fails on high and critical findings, so that insecure manifests block merge.
40. As a developer, I want the chart linted and its rendered output validated against Kubernetes schemas, so that broken manifests never reach ArgoCD.
41. As a developer, I want the image built and scanned on every PR without being pushed, so that vulnerable images are caught before merge and nothing is published from a PR.
42. As a developer, I want the image Gate to fail on high and critical vulnerabilities including unfixed ones, so that the assignment's "any high" rule is enforced literally.
43. As a developer, I want a documented, justified exceptions list for the image Gate, so that an accepted risk is explicit and reviewable rather than a disabled check.
44. As a developer, I want the image re-scanned on `main` before push, so that vulnerabilities published between PR and merge are still caught.
45. As a developer, I want the image pushed only after the Gate passes, so that a vulnerable image never reaches the registry.
46. As a developer, I want the Release tag created only after the image is pushed, so that no Release exists without an image.
47. As a developer, I want the pipeline to stop early when the merged commits warrant no Release, so that no-op runs are cheap.
48. As a developer, I want release runs serialized, so that two quick merges cannot race on versions or Bump commits.
49. As a developer, I want the image signed keylessly and a provenance attestation attached, so that consumers can verify where the image came from.
50. As a developer, I want a CycloneDX SBOM attached to each Release, so that the image's contents are auditable.
51. As a developer, I want every third-party action pinned by full commit SHA, so that a hijacked tag (as happened to the Trivy actions in March 2026) cannot run in my pipeline.
52. As a developer, I want each job to request only the token permissions it needs, so that a compromised step has minimal reach.
53. As a developer, I want Dependabot PRs for npm, the base image and actions, so that dependencies stay patched without manual tracking.
54. As a developer, I want SonarQube analysis of `main` as well, so that the dashboard reflects the released code.

### Repo protection

55. As a developer, I want `main` protected so that merging requires a PR with all required Gates green, so that the Gates are blocking, not advisory.
56. As a developer, I want squash merge to be the only merge method, so that each PR becomes exactly one Conventional Commit.
57. As a developer, I want the pipeline's Bump commit to bypass the PR requirement through a dedicated deploy key, so that protection and automation coexist.
58. As a developer, I want the Bump commit marked to skip CI, so that it does not trigger another pipeline run.
59. As a developer, I want the protection rules applied by a script, so that they are reproducible and reviewable.

### Cluster operator

60. As an operator, I want one idempotent Bootstrap script, so that I can recreate the cluster from scratch or re-run it safely.
61. As an operator, I want minikube started with a CNI that enforces NetworkPolicy, so that the chart's NetworkPolicy is real.
62. As an operator, I want metrics-server available, so that the HPA can scale on CPU.
63. As an operator, I want ArgoCD to be the only component installed from outside git, so that everything else is managed by GitOps.
64. As an operator, I want an app-of-apps root Application, so that Traefik and the app are declared in git.
65. As an operator, I want the GHCR pull secret created at Bootstrap from an environment variable, so that the secret never enters git (ADR-0003).
66. As an operator, I want the Bootstrap script to fail with a clear message when the token variable is missing, so that I do not end up with an ImagePullBackOff to debug.
67. As an operator, I want all component versions pinned (ArgoCD, Traefik), so that a Bootstrap run today and next week produce the same cluster.
68. As an operator, I want the Bootstrap script to print how to get the ArgoCD admin password, how to start the tunnel, and the app URL, so that I know the next manual steps.
69. As an operator, I want automated sync with prune and self-heal, so that drift from git is corrected without me.
70. As an operator, I want a smoke-test script that checks Public paths and internal paths through the Ingress, so that I can verify a Deploy in one command.
71. As an operator, I want Traefik exposed on localhost through `minikube tunnel` with a nip.io host, so that the app is reachable from my browser without editing the hosts file.

### Workload behaviour

72. As an operator, I want readiness, liveness and startup probes on the app's health endpoints, so that Kubernetes routes traffic only to healthy pods and restarts stuck ones.
73. As an operator, I want CPU and memory requests and limits, so that the scheduler can place pods and one pod cannot starve the node.
74. As an operator, I want the app's configuration in a ConfigMap with a checksum that triggers a rollout on change, so that config changes take effect predictably.
75. As an operator, I want a dedicated ServiceAccount without an auto-mounted token, so that the pod has no Kubernetes API credentials it does not need.
76. As an operator, I want a hardened security context (non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, default seccomp), so that the container follows the restricted Pod Security profile.
77. As an operator, I want an HPA between two and five replicas on CPU, so that the app scales with load.
78. As an operator, I want a PodDisruptionBudget, so that voluntary disruptions keep at least one pod serving.
79. As an operator, I want a NetworkPolicy that admits traffic to the app port only from the Ingress controller (and from monitoring when enabled), so that `/classified` and `/metrics` are not reachable from arbitrary pods.
80. As an operator, I want rolling updates that never reduce available pods, so that a broken Release leaves the previous version serving.
81. As an operator, I want a broken Release to show as Degraded in ArgoCD and be undone with a `git revert` of the Bump commit, so that rollback is a git operation.
82. As an operator, I want the Ingress to expose only `/my-app` and `/about`, so that everything else is internal by default.
83. As an operator, I want a ServiceMonitor behind a flag that is off by default, so that monitoring can be switched on later without a chart change.
84. As an operator, I want TLS on the Ingress behind a flag that is off by default, so that HTTPS can be switched on later without a chart change.

### Stretch

85. As a reviewer, I want, if time allows, a Grafana view of the root access counter, so that the metrics endpoint is shown in use.
86. As a reviewer, I want, if time allows, HTTPS through cert-manager with a self-signed issuer, so that the TLS path is demonstrated end to end.

## Implementation Decisions

### Repo and process

- The repo is the existing public fork `sela27/sample-nodejs`. The GitOps manifests live in a dedicated directory inside it that ArgoCD watches (ADR-0001).
- AI tooling leaves the tracked tree and is ignored from then on: the agent skill directories, the skills lock file, the agent docs and the agent instructions file. The assignment text file also leaves the tree. History is not rewritten. Before the cleanup merges, the skills are copied to the user-level skills directory and the agent instructions are kept as a local, untracked file, so that the workflow keeps working in the main checkout and in worktrees after the files disappear from git.
- ADRs and the glossary stay in the repo as documentation.
- Spec and tickets are markdown files in the local tracker directory, committed to git. Each ticket's PR updates that ticket's status line.
- Git workflow: GitHub Flow. One short-lived branch per ticket, cut from `origin/main`, named `<type>/<NN>-<slug>`. Merges happen only through PRs on GitHub, squash only, so the PR title is the Conventional Commit that drives versioning.
- The Release version tracks the app image. Only changes to the app or its production dependencies use `feat` or `fix`. Chart, cluster, CI, build, test and docs changes use non-releasing types (`chore(chart)`, `chore(cluster)`, `ci`, `build`, `test`, `docs`); chart changes reach the cluster through ArgoCD with no Release.

### App

- The app module builds and exports the Express app without listening; the server listens only when the module is run as the entrypoint. Routes and responses stay exactly as they are.
- On SIGTERM the server stops accepting connections, lets in-flight requests finish, and exits with code 0; a timeout shorter than the pod's termination grace period forces exit if connections linger.
- The listening port comes from an environment variable with the current default (8080).
- Dependencies stay on Express 4. The vulnerable transitive versions are fixed by a lockfile update inside the existing semver range, in a dedicated `fix(deps)` PR made after the image Gate has been seen failing on them.
- The README's Node prerequisite moves to Node 24 (Active LTS).

### Container image

- Multi-stage build on `node:24-alpine`, pinned by digest. The build stage installs production dependencies from the lockfile. The runtime stage copies only the app source and production dependencies, removes npm, npx and corepack, runs as the built-in `node` user (uid 1000), and exposes port 8080.
- A dockerignore file keeps tests, git metadata, docs and tooling out of the build context.
- The image is built with BuildKit in GitHub Actions.
- Registry: private GHCR package `ghcr.io/sela27/sample-nodejs`. The pipeline pushes with the workflow token. The cluster pulls with a classic PAT that has only `read:packages`, because GitHub Packages does not support fine-grained PATs.
- Image tags: the Release version and `sha-<short>`. Manifests never reference `latest`.

### Helm chart

- Workload: Deployment, not StatefulSet. The app keeps no disk, no database and no per-pod identity; the in-memory metrics counter is per-pod by design and Prometheus sums it across pods, so it is not state that needs a StatefulSet.
- Probes: startup and liveness on `/live`, readiness on `/ready`.
- Service: ClusterIP, service port 80 to container port 8080.
- Ingress: class `traefik`, no controller-specific annotations, host from values (default for `dev`: `sample-nodejs.127.0.0.1.nip.io`), paths limited to the Public paths `/my-app` and `/about`.
- Resources: CPU and memory requests and limits, tunable through values.
- ConfigMap with `PORT` and `NODE_ENV`, consumed as environment variables; a checksum of it on the pod template triggers a rollout on change.
- Dedicated ServiceAccount with `automountServiceAccountToken: false`, referencing the pull secret by name.
- Pod and container security context meeting the restricted Pod Security profile: non-root, uid 1000, read-only root filesystem, no privilege escalation, all capabilities dropped, `RuntimeDefault` seccomp.
- HPA (autoscaling/v2), 2–5 replicas at 70% CPU. While the HPA is enabled, the Deployment does not set `replicas`, so ArgoCD and the HPA do not fight over it.
- PodDisruptionBudget with `minAvailable: 1`.
- NetworkPolicy selecting the app pods: ingress to the app port allowed only from the Traefik namespace, plus the monitoring namespace when the ServiceMonitor flag is on. Egress is not restricted.
- Rolling update with `maxUnavailable: 0` and `maxSurge: 1`, a termination grace period that exceeds the app's shutdown timeout, and a short preStop pause so the endpoint is removed before shutdown starts.
- Off-by-default flags: ServiceMonitor, and Ingress TLS with a cert-manager issuer annotation.
- Chart defaults hold everything Environment-independent. Each Environment has its own values file; the `dev` values hold the image tag (the target of the Bump commit) and the host. Adding an Environment means adding a values file and an Application, with no chart change.

### GitOps and cluster

- One root Application (app-of-apps) points at the directory of child Applications: Traefik (official chart, pinned version, Service of type LoadBalancer) and `sample-nodejs-dev` (our chart with the `dev` values, own namespace).
- Child Applications use automated sync with prune and self-heal, and create their namespaces. ArgoCD reads the public repo without credentials.
- Traefik replaces minikube's retired ingress-nginx addon (ADR-0002).
- Deploy verification belongs to ArgoCD: Synced plus Healthy, where Healthy follows our readiness probe. The pipeline does not reach the cluster, and there is no self-hosted runner, because on a public repo a fork PR could run code on the host.

### Bootstrap

- One idempotent bash script, runnable from Git Bash on Windows and natively on Linux and macOS. Steps: check prerequisites; start minikube with the Calico CNI and enough CPU and memory; enable the metrics-server addon; install ArgoCD from its Helm chart at a pinned version; create the app namespace and the pull secret from `GHCR_PULL_TOKEN` (fail with a clear message if it is unset); apply the root Application; wait for the Applications to become Healthy; print how to read the ArgoCD admin password, the `minikube tunnel` instruction and the app URL.
- `minikube tunnel` stays a manual foreground step. The script does not start it.

### Smoke test

- A bash script that, through the Ingress host, expects 200 from `/my-app` and `/about`, and 404 from `/classified`, `/metrics` and `/ready`. It exits non-zero on any mismatch and prints a per-path result.

### CI on pull requests

- Required, blocking jobs: unit tests; Dockerfile lint; chart lint plus schema validation of the rendered chart; secret scan (gitleaks); SAST; IaC misconfiguration scan (Trivy config, fails on HIGH and CRITICAL); image build without push followed by the image Gate (Trivy, fails on HIGH and CRITICAL, unfixed included).
- SAST is SonarQube Cloud (free for public repos). The scanner uploads the analysis, then an explicit Gate step queries the SonarQube Web API for open issues of type vulnerability at the top severities (Blocker and Critical in standard mode, Blocker and High in MQR mode) across the whole project, not just new code, and fails if there are any. It does not rely on the built-in quality gate, because "Sonar way" only checks new code and custom gates may not be on the free plan.
- Image Gate exceptions live in a Trivy ignore file in which every entry carries a justification and the reason it is safe.
- The job names are the required status checks in the ruleset.

### CD on `main`

- Triggered by a push to `main`, serialized by a concurrency group that does not cancel in-progress runs. A push whose message carries `[skip ci]` (the Bump commit) does not trigger it.
- Order: compute the next version with semantic-release in dry-run mode, and stop if there is none; build the image tagged with the version and `sha-<short>`; run the image Gate; push to GHCR; sign the image keylessly with cosign through GitHub OIDC and attach a build provenance attestation; generate a CycloneDX SBOM; let semantic-release create the `v<version>` tag and the GitHub Release with the SBOM attached; make the Bump commit that sets the `dev` image tag, pushed over SSH with the deploy key and marked `[skip ci]`.
- semantic-release config: release branch `main`, Conventional Commits preset, release notes, GitHub release. No npm publish and no commit back to `package.json`, because the git tag is the source of truth for the version. The first Release is 1.0.0.
- SonarQube analysis also runs on `main` for the dashboard. It reports only and is not a Gate there.

### Supply chain and permissions

- Every third-party action is pinned by full commit SHA, with the version in a trailing comment.
- The workflow default token permission is read-only. Each job elevates only what it needs: package write for push, contents write for the Release, id-token write for signing and attestation, attestations write for attestation.
- Dependabot covers npm, Docker and GitHub Actions on a weekly schedule.

### Repo protection

- A repository ruleset on `main` requires a PR (zero approvals, since there is a single maintainer), requires the CI jobs as status checks, and blocks force-push and deletion. Its bypass list contains only the pipeline's deploy key.
- The deploy key is generated for this purpose with write access. Its private half is an Actions secret used only by the Bump commit step.
- Squash merge is the only merge method enabled on the repo.
- A script applies the ruleset and merge settings through `gh api`.

### Evidence strategy

- The PR that adds the image Gate is expected to be red, because the Gate catches the real vulnerabilities in the sample's locked dependencies. It is screenshotted with merging blocked. A second commit in the same PR fixes the lockfile and turns it green, and the PR is titled `fix(deps): …` so it drives the first Release. The fix cannot be a separate PR from `main`, because that PR would not contain the not-yet-merged Gate and so could never satisfy the required check.
- A Demo PR introduces a deliberately vulnerable snippet (for example, command injection from a query parameter) to show the SAST Gate blocking. It is closed without merging.
- The README is built up incrementally: each ticket adds its own section, and a final ticket polishes it. Screenshots go in a docs screenshots directory. Tickets that produce evidence say exactly what to capture and how to name the file.

## Testing Decisions

- A good test drives the system from the outside, through the same interface a real client uses, and asserts on observable behaviour (status codes, bodies, exit codes). It never asserts on internal structure, private functions or template internals. A refactor that keeps behaviour must keep the tests green.
- **Seam 1: the app's HTTP interface (in-process, runs in CI on every PR).** Tests use Node's built-in test runner and supertest against the exported app: status and body for each endpoint; `/metrics` returns Prometheus text containing `root_access_total`, and its value increases after a request to `/my-app`. A process-level test starts the entrypoint on an ephemeral port as a child process, sends SIGTERM and asserts a clean exit with code 0 within a timeout; it is skipped on Windows, where signals are not delivered the same way. supertest is a dev dependency and does not ship in the image.
- **Seam 2: the Environment's Ingress (end to end, local).** The smoke-test script is the only end-to-end test. In one pass it covers the chart, Traefik, the Public path allowlist, the NetworkPolicy path through the Ingress controller, and the ArgoCD Deploy. It runs against the local cluster, not in CI.
- The Dockerfile linter, chart lint, schema validation and Trivy config are Gates on shape, not behavioural tests. The Gates themselves are proven by the first real failure and by the Demo PR, not by tests.
- There is no prior art: the repo has no tests today. Seam 1 is new and is the highest seam available for the app. Making the app importable without listening is the only change needed to open it.
- No chart unit tests (helm-unittest). They would assert template details, and Seam 2 already covers the behaviour.

## Out of Scope

- A separate GitOps repo (ADR-0001 records when we would split).
- More than one Environment, and a promotion flow between Environments. The README describes the promotion flow we would build.
- Sealed Secrets, SOPS or External Secrets Operator (ADR-0003). The README names the production path.
- A managed cloud cluster or IaC for one. Interviewers get screenshots, not cluster access.
- A self-hosted runner, and any pipeline step that talks to the cluster.
- ArgoCD Notifications, and ArgoCD managing its own installation.
- Admission-time signature verification (Kyverno or the Sigstore policy controller), and DAST (OWASP ZAP). Both are listed in the README as next steps.
- An ephemeral kind cluster in CI running the smoke test on every PR. This is the natural next step for Seam 2.
- Gateway API resources alongside the Ingress.
- Let's Encrypt certificates (not possible for a local `127.0.0.1` host).
- An upgrade to Express 5.
- Rewriting git history to remove the already-pushed tooling commit.
- Anti-affinity and topology spread constraints, which mean nothing on a single-node cluster.
- Egress restrictions in the NetworkPolicy.

## Further Notes

- **Steps only the user can perform** (each ticket that needs one stops and gives exact instructions): create the SonarQube Cloud organization and project and add `SONAR_TOKEN`; create the classic PAT with `read:packages` and export it as `GHCR_PULL_TOKEN` for Bootstrap; approve creating the deploy key and its secret and applying the ruleset; run `minikube tunnel`; take the screenshots; possibly raise Docker Desktop's memory.
- **Resource risk:** Docker Desktop currently has about 6.2 GB. ArgoCD, Calico, Traefik, metrics-server and the app need about 4–5 GB inside minikube, which is tight. Raise Docker Desktop to 8 GB before the Bootstrap ticket, and certainly before the monitoring stretch.
- **Scan baseline (2026-11-08, Trivy 0.58.1, HIGH/CRITICAL):** `node:22-alpine` 0/10, `node:24-alpine` 0/6, `node:22-slim` 1/44, distroless `nodejs22-debian12` 1/6, Chainguard `node:latest` 0/0. Every Alpine finding was in the bundled npm, which is why the runtime stage drops npm. The app's own lockfile had 1 critical (`proxy-addr`) and 3 high (`body-parser`, `path-to-regexp`, `express`), all fixable inside the current semver range.
- **Context worth citing in the README:** ingress-nginx was retired by the Kubernetes project in March 2026 (ADR-0002). The `aquasecurity/trivy-action` and `setup-trivy` tags were hijacked on 2026-03-19 (CVE-2026-33634), which is the reason for SHA pinning.
- **Stretch tickets** come last and are optional: kube-prometheus-stack via ArgoCD with the ServiceMonitor flag on; cert-manager with a self-signed ClusterIssuer and the TLS flag on.
- **Vocabulary:** this spec uses the terms in `GLOSSARY.md` (Release, Bump commit, Demo PR, Gate, Public path, Environment, Deploy, Bootstrap).
