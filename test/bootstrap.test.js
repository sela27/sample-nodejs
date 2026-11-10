// scripts/bootstrap.sh needs GHCR_PULL_TOKEN to create the registry pull
// secret (ADR-0003). Without it, the script must stop at once with a message
// that says what to set, before it starts a cluster or installs anything.
//
// The cluster tools are replaced by stubs that log their name and fail, so
// this test never reaches a real cluster, and it shows whether any tool ran.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const script = path.join(__dirname, '..', 'scripts', 'bootstrap.sh');
const tools = ['docker', 'minikube', 'kubectl', 'helm'];

// A temp directory of stub tools, removed after the test. Returns the
// directory and the file the stubs log their calls to.
function stubTools(t) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'bootstrap-stubs-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const log = path.join(dir, 'calls.log');
    fs.writeFileSync(log, '');
    for (const tool of tools) {
        fs.writeFileSync(path.join(dir, tool), `#!/bin/sh\necho ${tool} >> "$STUB_LOG"\nexit 1\n`, { mode: 0o755 });
    }
    return { dir, log };
}

// Runs the script with the stubs first on PATH. `token` undefined leaves
// GHCR_PULL_TOKEN out of the environment altogether.
function bootstrap(t, token) {
    const stubs = stubTools(t);
    const env = {};
    for (const [key, value] of Object.entries(process.env)) {
        if (key !== 'GHCR_PULL_TOKEN') env[key] = value;
    }
    // Windows names the variable Path, so find it whatever its case.
    const pathKey = Object.keys(env).find((key) => key.toUpperCase() === 'PATH') || 'PATH';
    env[pathKey] = `${stubs.dir}${path.delimiter}${env[pathKey] || ''}`;
    env.STUB_LOG = stubs.log;
    if (token !== undefined) env.GHCR_PULL_TOKEN = token;
    const result = spawnSync('bash', [script], { env, encoding: 'utf8', timeout: 30000 });
    return { ...result, toolsRun: fs.readFileSync(stubs.log, 'utf8').split('\n').filter(Boolean) };
}

for (const [name, token] of [['unset', undefined], ['empty', '']]) {
    test(`stops with a clear message when GHCR_PULL_TOKEN is ${name}, before running any tool`, (t) => {
        const result = bootstrap(t, token);

        assert.notEqual(result.status, 0, 'the script went on without a token');
        assert.match(result.stderr, /GHCR_PULL_TOKEN/);
        assert.match(result.stderr, /read:packages/, 'the message does not say which token to create');
        assert.deepEqual(result.toolsRun, [], 'the script ran cluster tools before checking the token');
    });
}
