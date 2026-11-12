// scripts/request-loop.js against a local server. Each test runs the script
// for one second and reads its summary line and exit code, the way the
// rollout and rollback demos read it.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const http = require('node:http');
const path = require('node:path');

const script = path.join(__dirname, '..', 'scripts', 'request-loop.js');

// Starts a server that answers every request with handler, and returns its port.
async function serve(t, handler) {
  const server = http.createServer(handler);
  t.after(() => {
    server.closeAllConnections();
    server.close();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server.address().port;
}

// Runs the loop for one second. Resolves with its exit code and summary
// counts, or rejects if it has not exited 5 s after it should have stopped.
function runLoop(port, extraArgs = []) {
  const args = [script, '--url', `http://127.0.0.1:${port}/my-app`, '--rps', '10', '--duration', '1', ...extraArgs];
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, args, { stdio: ['ignore', 'pipe', 'ignore'] });
    let stdout = '';
    child.stdout.on('data', (chunk) => { stdout += chunk; });
    const killer = setTimeout(() => {
      child.kill('SIGKILL');
      reject(new Error('the loop did not exit within 5 s of its --duration'));
    }, 6000);
    child.on('exit', (code) => {
      clearTimeout(killer);
      const counts = Object.fromEntries(
        [...stdout.matchAll(/(\w+)=(\d+)/g)].map(([, key, value]) => [key, Number(value)]),
      );
      resolve({ code, counts, stdout });
    });
  });
}

function assertCountsAddUp(counts) {
  assert.equal(counts.ok + counts.non200 + counts.errors, counts.total, `the counts do not add up: ${JSON.stringify(counts)}`);
}

test('counts every 200 as ok and exits 0', async (t) => {
  const port = await serve(t, (req, res) => res.end('Hello, World!'));
  const { code, counts } = await runLoop(port);
  assert.ok(counts.total > 0);
  assert.equal(counts.ok, counts.total);
  assertCountsAddUp(counts);
  assert.equal(code, 0);
});

test('counts a response other than 200 as non200 and exits 1', async (t) => {
  const port = await serve(t, (req, res) => {
    res.statusCode = 503;
    res.end();
  });
  const { code, counts } = await runLoop(port);
  assert.ok(counts.total > 0);
  assert.equal(counts.non200, counts.total);
  assertCountsAddUp(counts);
  assert.equal(code, 1);
});

test('counts a response that breaks off before its end as an error and still exits', async (t) => {
  const port = await serve(t, (req, res) => {
    res.writeHead(200, { 'Content-Length': '100' });
    res.write('part of the body');
    setTimeout(() => res.socket.destroy(), 20);
  });
  const { code, counts } = await runLoop(port);
  assert.ok(counts.total > 0);
  assert.equal(counts.errors, counts.total);
  assertCountsAddUp(counts);
  assert.equal(code, 1);
});

test('counts a response whose body stalls past --timeout as an error and still exits', async (t) => {
  const port = await serve(t, (req, res) => {
    res.writeHead(200, { 'Content-Length': '100' });
    res.write('part of the body');
  });
  const { code, counts } = await runLoop(port, ['--timeout', '300']);
  assert.ok(counts.total > 0);
  assert.equal(counts.errors, counts.total);
  assertCountsAddUp(counts);
  assert.equal(code, 1);
});
