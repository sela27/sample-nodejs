const { test } = require('node:test');
const assert = require('node:assert/strict');
const request = require('supertest');

const app = require('../app');

test('GET /my-app greets the world', async () => {
    const res = await request(app).get('/my-app');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Hello, World!');
});

test('GET /about describes the app', async () => {
    const res = await request(app).get('/about');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'This is a sample Node.js application for Kubernetes deployment testing.');
});

test('GET /ready reports readiness', async () => {
    const res = await request(app).get('/ready');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Ready');
});

test('GET /live reports liveness', async () => {
    const res = await request(app).get('/live');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'Alive');
});

test('GET /classified answers inside the app', async () => {
    const res = await request(app).get('/classified');
    assert.equal(res.status, 200);
    assert.equal(res.text, 'You should not be here!!!');
});

test('GET on an unknown path is 404', async () => {
    const res = await request(app).get('/no-such-path');
    assert.equal(res.status, 404);
});

// Reads the sample value of root_access_total from Prometheus text output.
function rootAccessTotal(metricsText) {
    const match = metricsText.match(/^root_access_total (\S+)$/m);
    assert.ok(match, 'root_access_total sample is missing from /metrics');
    return Number(match[1]);
}

test('GET /metrics serves Prometheus text with root_access_total', async () => {
    const res = await request(app).get('/metrics');
    assert.equal(res.status, 200);
    assert.match(res.headers['content-type'], /^text\/plain; version=0\.0\.4/);
    assert.match(res.text, /^# TYPE root_access_total counter$/m);
    assert.ok(Number.isFinite(rootAccessTotal(res.text)));
});

test('a request to /my-app increases root_access_total by one', async () => {
    const before = rootAccessTotal((await request(app).get('/metrics')).text);
    await request(app).get('/my-app').expect(200);
    const after = rootAccessTotal((await request(app).get('/metrics')).text);
    assert.equal(after, before + 1);
});
