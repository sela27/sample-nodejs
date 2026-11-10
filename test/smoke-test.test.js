// scripts/smoke-test.sh over HTTPS. The Ingress serves a self-signed
// certificate (cert-manager), so the script must verify it against the CA
// from the certificate's secret rather than skip verification, unless
// --insecure says so.
//
// curl and kubectl are replaced by stubs that log their arguments, so no
// network or cluster is touched. The stub curl answers like the app behind the
// Ingress: 200 on /my-app and /about, 404 on the internal paths.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const script = path.join(__dirname, '..', 'scripts', 'smoke-test.sh');
const HOST = 'sample-nodejs.127.0.0.1.nip.io';
const CA_PEM = '-----BEGIN CERTIFICATE-----\nstub-ca\n-----END CERTIFICATE-----\n';

const CURL_STUB = `#!/bin/sh
# Logs one line per call: the arguments, then the content of the --cacert file.
out=""; cacert=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    --output) out="$2"; shift ;;
    --cacert) cacert="$2"; shift ;;
    --silent|--insecure|--max-time|--write-out|--header|--connect-to) ;;
  esac
  prev="$1"; url="$1"; shift
done
printf 'curl %s\\n' "$ORIG_ARGS" >> "$STUB_LOG"
[ -n "$cacert" ] && printf 'cacert-content %s\\n' "$(tr '\\n' '|' < "$cacert")" >> "$STUB_LOG"
case "$url" in
  */my-app) printf 'Hello, World!' > "$out"; printf 200 ;;
  */about) : > "$out"; printf 200 ;;
  *) : > "$out"; printf 404 ;;
esac
`;

// The wrapper keeps the original argument list for the log.
const CURL_WRAPPER = `#!/bin/sh
ORIG_ARGS="$*" exec sh "$STUB_DIR/curl-real" "$@"
`;

const KUBECTL_STUB = `#!/bin/sh
printf 'kubectl %s\\n' "$*" >> "$STUB_LOG"
case "$*" in
  *port-forward*)
    printf 'Forwarding from 127.0.0.1:34567 -> 8443\\n'
    exec sleep 30 ;;
  *'ca\\.crt'*) printf '%s' "$STUB_CA_B64" ;;
  *) exit 1 ;;
esac
`;

function run(t, args, extraEnv = {}) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'smoke-stubs-'));
    t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
    const log = path.join(dir, 'calls.log');
    fs.writeFileSync(log, '');
    fs.writeFileSync(path.join(dir, 'curl-real'), CURL_STUB);
    fs.writeFileSync(path.join(dir, 'curl'), CURL_WRAPPER, { mode: 0o755 });
    fs.writeFileSync(path.join(dir, 'kubectl'), KUBECTL_STUB, { mode: 0o755 });

    const env = {};
    for (const [key, value] of Object.entries(process.env)) {
        if (!['BASE_URL', 'APP_HOST', 'CA_CERT'].includes(key)) env[key] = value;
    }
    const pathKey = Object.keys(env).find((key) => key.toUpperCase() === 'PATH') || 'PATH';
    env[pathKey] = `${dir}${path.delimiter}${env[pathKey] || ''}`;
    env.STUB_LOG = log;
    env.STUB_DIR = dir;
    env.STUB_CA_B64 = Buffer.from(CA_PEM).toString('base64');
    Object.assign(env, extraEnv);

    const result = spawnSync('bash', [script, ...args], { env, encoding: 'utf8', timeout: 60000 });
    const calls = fs.readFileSync(log, 'utf8').split('\n').filter(Boolean);
    return { ...result, calls, curlCalls: calls.filter((c) => c.startsWith('curl ')) };
}

test('over HTTPS it verifies the certificate against the CA from the secret', (t) => {
    const result = run(t, [], { BASE_URL: `https://${HOST}` });

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.calls.some((c) => /^kubectl .*get secret .*sample-nodejs-dev-tls/.test(c)), 'the CA was not read from the secret');
    assert.equal(result.curlCalls.length, 5);
    for (const call of result.curlCalls) {
        assert.match(call, /--cacert /);
        assert.doesNotMatch(call, /--insecure|\s-k(\s|$)/);
        assert.match(call, new RegExp(`https://${HOST}/`));
    }
    assert.ok(result.calls.includes('cacert-content -----BEGIN CERTIFICATE-----|stub-ca|-----END CERTIFICATE-----|'));
});

test('over HTTPS with CA_CERT it trusts that file and reads no secret', (t) => {
    const caFile = path.join(os.tmpdir(), `smoke-ca-${process.pid}.pem`);
    fs.writeFileSync(caFile, CA_PEM);
    t.after(() => fs.rmSync(caFile, { force: true }));
    const result = run(t, [], { BASE_URL: `https://${HOST}`, CA_CERT: caFile });

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(result.calls.filter((c) => c.startsWith('kubectl ')), []);
    for (const call of result.curlCalls) assert.match(call, /--cacert /);
});

test('--insecure skips verification and reads no secret', (t) => {
    const result = run(t, ['--insecure'], { BASE_URL: `https://${HOST}` });

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(result.calls.filter((c) => c.startsWith('kubectl ')), []);
    for (const call of result.curlCalls) {
        assert.match(call, /--insecure/);
        assert.doesNotMatch(call, /--cacert/);
    }
});

test('--port-forward --https forwards Traefik 443 and still checks the certificate for the Ingress host', (t) => {
    const result = run(t, ['--port-forward', '--https']);

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.calls.some((c) => /^kubectl .*port-forward service\/traefik :443/.test(c)), 'port 443 was not forwarded');
    for (const call of result.curlCalls) {
        assert.match(call, /--cacert /);
        assert.match(call, new RegExp(`--connect-to ${HOST}::127\\.0\\.0\\.1:34567`));
        assert.match(call, new RegExp(`https://${HOST}/`));
    }
});

test('plain HTTP keeps working: no certificate options, no secret read', (t) => {
    const result = run(t, [], { BASE_URL: `http://${HOST}` });

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(result.calls.filter((c) => c.startsWith('kubectl ')), []);
    for (const call of result.curlCalls) assert.doesNotMatch(call, /--cacert|--insecure/);
});

test('--port-forward without --https forwards port 80', (t) => {
    const result = run(t, ['--port-forward']);

    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.ok(result.calls.some((c) => /^kubectl .*port-forward service\/traefik :80$/.test(c)));
});
