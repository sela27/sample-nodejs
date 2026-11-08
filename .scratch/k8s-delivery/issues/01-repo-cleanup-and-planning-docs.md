# 01: Repo cleanup and planning docs

**Spec:** k8s-delivery spec

**What to build:** The public repo contains only the deliverable and its planning docs. The AI workflow keeps working locally after the tooling leaves git, both in the main checkout and in worktrees.

**Blocked by:** None (can start immediately)

**Status:** done

**Human step:** approve copying the skills into the user-level skills directory (outside the repo).

- [x] The agent skills are available from the user-level skills directory, and the grilling, spec, tickets and implement skills still load in a fresh session, both from the main checkout and from a worktree.
- [x] The agent skill directories, the skills lock file, the agent docs and the agent instructions file are removed from the tracked tree and added to the ignore list.
- [x] The agent instructions survive as a local untracked file, and the PR description explains how to keep them when the main checkout pulls this merge (git will delete the tracked copy there).
- [x] The assignment text file is removed from the tracked tree, with a local copy kept outside git.
- [x] The glossary, ADRs 0001–0003, the spec and every ticket file are committed.
- [x] History is not rewritten and nothing is force-pushed.
- [x] PR title is `chore: …`. This ticket's Status is set to `done` in the same PR.
