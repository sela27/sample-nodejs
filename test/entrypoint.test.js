const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn, spawnSync } = require('node:child_process');
const net = require('node:net');
const path = require('node:path');

const root = path.join(__dirname, '..');

function freePort() {
    return new Promise((resolve, reject) => {
        const probe = net.createServer();
        probe.once('error', reject);
        probe.listen(0, () => {
            const { port } = probe.address();
            probe.close(() => resolve(port));
        });
    });
}

// Resolves with the first line `node app.js` prints, the startup line.
function startupLine(child) {
    return new Promise((resolve, reject) => {
        let stdout = '';
        const timer = setTimeout(() => reject(new Error(`no startup line within 5s, got: ${stdout}`)), 5000);
        child.stdout.on('data', (chunk) => {
            stdout += chunk;
            const newline = stdout.indexOf('\n');
            if (newline !== -1) {
                clearTimeout(timer);
                resolve(stdout.slice(0, newline).trim());
            }
        });
        child.once('exit', (code) => {
            clearTimeout(timer);
            reject(new Error(`app exited early with code ${code}`));
        });
    });
}

// Resolves once check() is true, polling every 10 ms; rejects with what after ms.
function waitFor(check, what, ms = 5000) {
    return new Promise((resolve, reject) => {
        const deadline = Date.now() + ms;
        const poll = async () => {
            if (await check()) return resolve();
            if (Date.now() > deadline) return reject(new Error(`timed out waiting for ${what}`));
            setTimeout(poll, 10);
        };
        poll();
    });
}

// Resolves true if a new TCP connection to port is refused.
function connectionRefused(port) {
    return new Promise((resolve) => {
        const probe = net.connect(port, '127.0.0.1');
        probe.once('connect', () => {
            probe.destroy();
            resolve(false);
        });
        probe.once('error', (err) => resolve(err.code === 'ECONNREFUSED'));
    });
}

// Resolves with the exit code and signal of the child, or rejects if it is still running after ms.
function exitWithin(child, ms) {
    return new Promise((resolve, reject) => {
        const timer = setTimeout(() => reject(new Error(`app still running ${ms} ms after the signal`)), ms);
        child.once('exit', (code, signal) => {
            clearTimeout(timer);
            resolve({ code, signal });
        });
    });
}

test('loading the app module does not open a port', () => {
    // A module that listened would keep the process alive until the timeout kills it.
    const result = spawnSync(process.execPath, ['-e', "require('./app')"], {
        cwd: root,
        timeout: 5000,
    });
    assert.equal(result.signal, null, 'the process had to be killed, so loading the app opened a port');
    assert.equal(result.status, 0, result.stderr.toString());
});

test('node app.js listens on PORT and prints the startup line', async (t) => {
    const port = await freePort();
    const child = spawn(process.execPath, ['app.js'], {
        cwd: root,
        env: { ...process.env, PORT: String(port) },
    });
    t.after(() => child.kill());

    assert.equal(await startupLine(child), `Server running on port ${port}`);

    const res = await fetch(`http://127.0.0.1:${port}/ready`);
    assert.equal(res.status, 200);
    assert.equal(await res.text(), 'Ready');
});

// Windows has no POSIX signals: killing a child there ends it outright, so the shutdown path never runs.
const noPosixSignals = process.platform === 'win32' && 'Windows does not deliver POSIX signals to a child process';

// Starts `node app.js` on a free port with extra environment variables and waits for its startup line.
async function startApp(t, env = {}) {
    const port = await freePort();
    const child = spawn(process.execPath, ['app.js'], {
        cwd: root,
        env: { ...process.env, PORT: String(port), ...env },
    });
    t.after(() => child.kill('SIGKILL'));
    await startupLine(child);
    return { child, port };
}

// Opens a connection that has a /ready request in flight: two pipelined requests in one write, the
// second without its final blank line. The answer to the first proves the server has read the start
// of the second. finish() sends the missing blank line.
async function holdRequestInFlight(t, port) {
    const socket = net.connect(port, '127.0.0.1');
    t.after(() => socket.destroy());
    const held = { received: '', closed: false };
    held.answers = () => held.received.split('\r\n\r\nReady').length - 1;
    held.finish = () => socket.write('\r\n');
    socket.setEncoding('utf8');
    socket.on('data', (chunk) => { held.received += chunk; });
    socket.on('error', () => {});
    socket.on('close', () => { held.closed = true; });

    socket.write('GET /ready HTTP/1.1\r\nHost: localhost\r\n\r\nGET /ready HTTP/1.1\r\nHost: localhost\r\n');
    await waitFor(() => held.answers() === 1, 'the answer to the first request');
    return held;
}

// SIGTERM is what Kubernetes and `docker stop` send; SIGINT is Ctrl+C.
for (const signal of ['SIGTERM', 'SIGINT']) {
    test(`node app.js exits 0 on ${signal} once the server has closed`, { skip: noPosixSignals }, async (t) => {
        const { child, port } = await startApp(t);

        const res = await fetch(`http://127.0.0.1:${port}/ready`);
        assert.equal(res.status, 200);
        await res.text();

        const exited = exitWithin(child, 5000);
        child.kill(signal);
        assert.deepEqual(await exited, { code: 0, signal: null });
    });
}

test('on SIGTERM node app.js refuses new connections, answers the request in flight and closes its connection', { skip: noPosixSignals }, async (t) => {
    const { child, port } = await startApp(t);
    const held = await holdRequestInFlight(t, port);

    const exited = exitWithin(child, 5000);
    child.kill('SIGTERM');
    await waitFor(() => connectionRefused(port), 'new connections to be refused');

    held.finish();
    await waitFor(() => held.answers() === 2 || held.closed, 'the answer to the request in flight');
    assert.equal(held.answers(), 2, `the request in flight got no answer, received: ${held.received}`);
    // A keep-alive client, such as a proxy's connection pool, must not hold the shutdown open.
    const inFlightAnswer = held.received.slice(held.received.indexOf('Ready') + 'Ready'.length);
    assert.match(inFlightAnswer, /\r\nConnection: close\r\n/i);
    await waitFor(() => held.closed, 'the server to close the connection', 1000);

    assert.deepEqual(await exited, { code: 0, signal: null });
});

test('on SIGTERM node app.js exits 1 once SHUTDOWN_TIMEOUT_MS passes with a request still in flight', { skip: noPosixSignals }, async (t) => {
    const { child, port } = await startApp(t, { SHUTDOWN_TIMEOUT_MS: '500' });
    await holdRequestInFlight(t, port);

    const signalledAt = Date.now();
    const exited = exitWithin(child, 3000);
    child.kill('SIGTERM');
    assert.deepEqual(await exited, { code: 1, signal: null });
    assert.ok(Date.now() - signalledAt >= 500, 'the app exited before the timeout passed');
});
