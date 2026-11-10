#!/usr/bin/env node
// Sends a steady stream of GET requests and counts what comes back, so a
// rollout or a rollback can be judged by numbers: how many requests got
// through, and how many returned something other than 200 or failed to
// connect at all.
//
// Usage: node scripts/request-loop.js [options]
//   --url <url>       what to request (default http://127.0.0.1:8080/my-app)
//   --host <name>     Host header to send, for an Ingress rule matched by host
//   --rps <n>         requests started per second (default 20)
//   --timeout <ms>    per-request timeout; a timeout counts as an error (default 5000)
//   --duration <s>    stop after this many seconds (default: until SIGINT or SIGTERM)
//
// Every non-200 response and every error is logged on stderr with a time stamp.
// On exit it prints one summary line on stdout:
//   total=<n> ok=<n> non200=<n> errors=<n>
// and exits 0 if every request returned 200, else 1.
//
// Each request opens its own connection, so the loop does not stick to the
// one pod a keep-alive connection was opened to.
'use strict';

const http = require('http');

const args = process.argv.slice(2);
function option(name, fallback) {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
}

const url = new URL(option('url', 'http://127.0.0.1:8080/my-app'));
const host = option('host', '');
const rps = Number(option('rps', 20));
const timeoutMs = Number(option('timeout', 5000));
const duration = Number(option('duration', 0));

const stats = { total: 0, ok: 0, non200: 0, errors: 0 };
let inFlight = 0;
let stopping = false;

function log(message) {
  console.error(`${new Date().toISOString()} ${message}`);
}

function once() {
  stats.total += 1;
  inFlight += 1;
  const headers = host ? { Host: host } : {};
  const req = http.request(
    { hostname: url.hostname, port: url.port || 80, path: url.pathname + url.search, headers, agent: false, timeout: timeoutMs },
    (res) => {
      res.resume();
      res.on('end', () => {
        inFlight -= 1;
        if (res.statusCode === 200) {
          stats.ok += 1;
        } else {
          stats.non200 += 1;
          log(`non-200: ${res.statusCode}`);
        }
      });
    },
  );
  req.on('timeout', () => req.destroy(new Error('timeout')));
  req.on('error', (err) => {
    inFlight -= 1;
    stats.errors += 1;
    log(`error: ${err.message}`);
  });
  req.end();
}

const timer = setInterval(once, 1000 / rps);

function stop() {
  if (stopping) return;
  stopping = true;
  clearInterval(timer);
  // Let the requests already sent finish (or time out) before counting.
  const wait = setInterval(() => {
    if (inFlight > 0) return;
    clearInterval(wait);
    console.log(`total=${stats.total} ok=${stats.ok} non200=${stats.non200} errors=${stats.errors}`);
    process.exit(stats.ok === stats.total ? 0 : 1);
  }, 50);
}

process.on('SIGINT', stop);
process.on('SIGTERM', stop);
if (duration > 0) setTimeout(stop, duration * 1000);
