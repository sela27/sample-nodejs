// Decides whether the commit being built warrants a Release, and which version.
//
// Runs semantic-release in dry-run mode with the repo's .releaserc.yaml. It
// reads the commits since the last Release tag, logs the verdict for each one
// and the release notes it would publish, and creates no tag and no GitHub
// Release. The version goes to the step output `version`, which stays empty
// when no Release is due, for example when every commit since the last Release
// is a `ci`, `docs`, `chore`, `build` or `test` commit.
//
// Run it from the repo root, so semantic-release finds .releaserc.yaml and
// the git history.
import { appendFileSync } from "node:fs";
import semanticRelease from "semantic-release";

const result = await semanticRelease({ dryRun: true });
const version = result?.nextRelease?.version ?? "";

const message = version
  ? `Next Release: v${version}`
  : "No Release from this commit. The semantic-release log above says why.";
console.log(message);

if (process.env.GITHUB_OUTPUT) {
  appendFileSync(process.env.GITHUB_OUTPUT, `version=${version}\n`);
}
if (process.env.GITHUB_STEP_SUMMARY) {
  appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n`);
}
