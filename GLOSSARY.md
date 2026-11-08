# sample-nodejs delivery

How a change to this sample app travels from a pull request to running in the Kubernetes cluster, and the checks it must pass on the way.

## Language

### Changes and versions

**Release**:
A new semantic version of the app: a git tag, a GitHub Release and a container image that all carry the same version. Only `feat` and `fix` changes produce one.
_Avoid_: build, deploy

**Bump commit**:
The commit the pipeline makes to point an Environment at a new Release's image.
_Avoid_: deploy commit, tag update

**Demo PR**:
A pull request opened only to show a Gate blocking a change; it is closed, never merged.
_Avoid_: test PR

### Safety

**Gate**:
A pipeline check whose failure blocks a merge or a publish, as opposed to one that only reports.
_Avoid_: check, scan (when blocking is meant)

**Public path**:
An app path reachable from outside the cluster. Everything that is not a Public path is internal by default.
_Avoid_: route, endpoint (when exposure is meant)

### Running

**Environment**:
A named place the app runs, described by its own settings in git. Only `dev` exists today.
_Avoid_: stage, namespace

**Deploy**:
ArgoCD bringing an Environment in line with what git says it should run. A Bump commit or a chart change causes it; the pipeline never deploys directly.
_Avoid_: release, rollout

**Bootstrap**:
The one-time setup that takes an empty cluster to the point where ArgoCD manages everything else from git.
_Avoid_: install, provisioning
