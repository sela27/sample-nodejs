# GitOps manifests live in the app repo

ArgoCD pulls the deployment manifests from a dedicated directory inside this app repo instead of a separate GitOps repo. With a single service, a single environment and a single maintainer, a second repo would add a cross-repo token and an extra checkout step while bringing almost none of its benefits, so we keep everything in one place and let ArgoCD watch only that directory.

## Considered Options

- **Separate GitOps repo**: rejected for now. It earns its cost when there are several services sharing one GitOps repo, several environments, or deploy permissions that must differ from code permissions; that is the point at which we would split.

## Consequences

- The pipeline commits the image-tag bump straight to `main` of this repo. Because `main` is protected by a ruleset (PR required, required status checks), the bot pushes with a deploy key that is on the ruleset's bypass list, and marks the commit `[skip ci]` so it does not start another run.
- Bump commits from the pipeline land in the same history as code commits, so local branches need a pull after each Release.
