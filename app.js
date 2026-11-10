const express = require('express');
const promClient = require('prom-client');

const app = express();
const port = process.env.PORT || 8080;
// How long a shutdown waits for open connections before it forces exit. Keep it shorter than
// the pod's termination grace period, less any preStop pause.
const shutdownTimeoutMs = Number(process.env.SHUTDOWN_TIMEOUT_MS) || 10000;

// Create a Registry to register the metrics
const register = new promClient.Registry();

// Enable the collection of default metrics
promClient.collectDefaultMetrics({ register });

const helloWorldCounter = new promClient.Counter({
    name: 'root_access_total',
    help: 'Total number of accesses to the root path',
});
register.registerMetric(helloWorldCounter);



// Define routes
app.get('/my-app', (req, res) => {
    helloWorldCounter.inc();
    res.send('Hello, World!');
});

app.get('/about', (req, res) => {
    res.send('This is a sample Node.js application for Kubernetes deployment testing.');
});

app.get('/ready', (req, res) => {
    res.status(200).send('Ready');
});

app.get('/live', (req, res) => {
    res.status(200).send('Alive');
});

app.get('/classified', (req, res) => {
    res.status(200).send('You should not be here!!!');
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

// Listen only when run as the entrypoint (`node app.js`), so tests can load the app without opening a port.
if (require.main === module) {
    const server = app.listen(port, () => {
        console.log(`Server running on port ${port}`);
    });

    // Graceful shutdown on SIGTERM (Kubernetes, `docker stop`) and SIGINT (Ctrl+C): stop accepting
    // connections, let in-flight requests finish, then exit 0. If connections are still open after
    // shutdownTimeoutMs, exit 1 anyway.
    let closing = false;
    // Runs before Express, so every answer sent while closing tells keep-alive clients to let go.
    server.prependListener('request', (req, res) => {
        if (closing) res.setHeader('Connection', 'close');
    });
    const shutdown = (signal) => {
        if (closing) return;
        closing = true;
        console.log(`${signal} received, closing the server`);
        server.close(() => process.exit(0));
        setTimeout(() => {
            console.error(`Connections still open after ${shutdownTimeoutMs} ms, forcing exit`);
            process.exit(1);
        }, shutdownTimeoutMs).unref();
    };
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
}

module.exports = app;
