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

    const startupLine = await new Promise((resolve, reject) => {
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
    assert.equal(startupLine, `Server running on port ${port}`);

    const res = await fetch(`http://127.0.0.1:${port}/ready`);
    assert.equal(res.status, 200);
    assert.equal(await res.text(), 'Ready');
});
