# 29: README polish and evidence index

**Spec:** k8s-delivery spec (Evidence strategy, User stories 1–20)

**What to build:** A reviewer can understand and judge the whole project from the README alone: what was built, why, and the proof that it works.

**Blocked by:** 01–28

**Status:** done

- [x] The README has, in order: an overview with a Mermaid architecture diagram; Quick start; pipeline stages and what each Gate blocks; design decisions answering every "why" in the assignment, with links to the ADRs; a security-controls table; an evidence index; what would change in production; and the AI-assisted workflow. (Its eight top-level sections are in that order. The earlier detail sections sit under them, with their anchors unchanged. The diagram was rendered with Mermaid 11.4.1 to check its syntax. The design decisions table answers the assignment's questions, taken from its text in git history: workload type, git workflow, version bumping, CI tool, SAST, image scan, builder, registry, how the pipeline deploys, and the GitOps layout. It also covers the choices with ADRs.)
- [x] Every screenshot from the earlier tickets is present and referenced, and every link resolves. (All 12 files the tickets name are in `docs/screenshots/`, and each is shown where it belongs and listed in the evidence index. Every `#anchor` and relative path in the README, the ADRs and the glossary resolves, by a script that slugs headings the way GitHub does, outside code fences. All 17 external links answered 200 on 2026-11-12. The two cluster-local URLs, the nip.io host and `localhost:3000`, answer only with the tunnel or the port-forward up.)
- [x] The production section names the next steps from the spec's Out of Scope list. (Each item on that list appears there: a separate GitOps repo, more Environments and promotion, External Secrets, a managed cluster from IaC, admission-time signature checks, DAST, the smoke test in a kind cluster in CI, ArgoCD Notifications and self-management, Gateway API, Let's Encrypt, Express 5, anti-affinity and topology spread, and egress rules. Two are not a step to take: the self-hosted runner stays out, for the reason in Design decisions, and history is not rewritten, as How this was built says.)
- [x] PR title is `docs: …`. Status set to `done` in the same PR.
