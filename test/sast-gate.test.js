// Drives scripts/sast-gate.js against a fake SonarQube Cloud Web API.
const { test } = require('node:test');
const assert = require('node:assert/strict');

const { isBlocking, parseProperties, run } = require('../scripts/sast-gate');

const PROPERTIES = 'sonar.organization=acme\nsonar.projectKey=acme_app\n# a comment\n';
const REPORT_TASK = 'projectKey=acme_app\nceTaskId=TASK1\n';

const issue = (key, fields) => ({
  key, project: 'acme_app', component: `acme_app:${fields.file || 'app.js'}`, line: 10,
  rule: 'javascript:S2076', type: 'VULNERABILITY', message: `issue ${key}`, ...fields,
});

// A fake API: `tasks` are the successive api/ce/task answers, `issues` maps
// "main" or a PR number to that scope's issues. Records every request.
function fakeApi({ tasks, issues }) {
  const requests = [];
  let taskCall = 0;
  const fetch = async (url, init) => {
    const u = new URL(url);
    requests.push({ path: u.pathname, params: Object.fromEntries(u.searchParams), auth: init.headers.Authorization });
    let body;
    if (u.pathname === '/api/ce/task') {
      body = { task: tasks[Math.min(taskCall, tasks.length - 1)] };
      taskCall += 1;
    } else if (u.pathname === '/api/issues/search') {
      const all = issues[u.searchParams.get('pullRequest') || 'main'] || [];
      const ps = Number(u.searchParams.get('ps'));
      const p = Number(u.searchParams.get('p'));
      body = { paging: { pageIndex: p, pageSize: ps, total: all.length }, issues: all.slice((p - 1) * ps, p * ps) };
    } else {
      return { ok: false, status: 404, text: async () => 'not found' };
    }
    return { ok: true, status: 200, json: async () => body };
  };
  return { fetch, requests };
}

async function gate(argv, api, env = {}) {
  const lines = [];
  const files = { 'sonar-project.properties': PROPERTIES, '.scannerwork/report-task.txt': REPORT_TASK };
  const code = await run(argv, { SONAR_TOKEN: 'tok', SONAR_HOST_URL: 'https://sonar.test', ...env }, {
    fetch: api.fetch,
    readFile: (file) => files[file],
    sleep: async () => {},
    out: (line) => lines.push(line),
    pollMs: 0,
    pageSize: 2,
  });
  return { code, output: lines.join('\n') };
}

const prTask = { componentKey: 'acme_app', status: 'SUCCESS', pullRequest: '7' };
const mainTask = { componentKey: 'acme_app', status: 'SUCCESS', branch: 'main' };

test('isBlocking: BLOCKER or CRITICAL in standard mode, SECURITY BLOCKER or HIGH in MQR mode', () => {
  assert.equal(isBlocking({ severity: 'BLOCKER' }), true);
  assert.equal(isBlocking({ severity: 'CRITICAL' }), true);
  assert.equal(isBlocking({ severity: 'MAJOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'HIGH' }] }), true);
  assert.equal(isBlocking({ severity: 'MAJOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'BLOCKER' }] }), true);
  assert.equal(isBlocking({ severity: 'MAJOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'MEDIUM' }] }), false);
  assert.equal(isBlocking({ severity: 'MAJOR', impacts: [{ softwareQuality: 'MAINTAINABILITY', severity: 'HIGH' }] }), false);
});

test('parseProperties skips comments and keeps values with =', () => {
  assert.deepEqual(parseProperties('# c\n\na=1\nb = x=y\r\n'), { a: '1', b: 'x=y' });
});

test('a PR fails on a blocking vulnerability it adds, after waiting for the analysis', async () => {
  const api = fakeApi({
    tasks: [{ ...prTask, status: 'PENDING' }, { ...prTask, status: 'IN_PROGRESS' }, prTask],
    issues: {
      main: [issue('M1', { severity: 'MAJOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'MEDIUM' }] })],
      7: [issue('P1', { severity: 'BLOCKER', file: 'routes/run.js', line: 31 })],
    },
  });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 1);
  assert.match(output, /main branch: 1 open vulnerability, 0 blocking/);
  assert.match(output, /pull request 7: 1 open vulnerability, 1 blocking/);
  assert.match(output, /BLOCKING {2}BLOCKER {2}javascript:S2076 {2}routes\/run\.js:31/);
  assert.match(output, /issues\?id=acme_app&pullRequest=7&open=P1/);
  assert.equal(api.requests.filter((r) => r.path === '/api/ce/task').length, 3);
  const search = api.requests.find((r) => r.path === '/api/issues/search');
  assert.equal(search.params.types, 'VULNERABILITY');
  assert.equal(search.params.resolved, 'false');
  assert.equal(search.params.componentKeys, 'acme_app');
  assert.equal(search.auth, 'Bearer tok');
});

test('a PR also fails on a blocking vulnerability already on main', async () => {
  const api = fakeApi({
    tasks: [prTask],
    issues: { main: [issue('M1', { severity: 'MAJOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'HIGH' }] })] },
  });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 1);
  assert.match(output, /MAJOR, SECURITY:HIGH .*\(main branch\)/);
});

test('a PR passes with only lower-severity vulnerabilities, across pages', async () => {
  const minor = (key) => issue(key, { severity: 'MINOR', impacts: [{ softwareQuality: 'SECURITY', severity: 'LOW' }] });
  const api = fakeApi({ tasks: [prTask], issues: { main: [minor('A'), minor('B'), minor('C')], 7: [] } });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 0);
  assert.match(output, /main branch: 3 open vulnerabilities, 0 blocking/);
  assert.match(output, /PASS/);
  assert.equal(api.requests.filter((r) => r.path === '/api/issues/search' && !r.params.pullRequest).length, 2);
});

test('issues the API should have filtered out do not count', async () => {
  const api = fakeApi({
    tasks: [prTask],
    issues: {
      main: [
        issue('X1', { severity: 'BLOCKER', project: 'other_app' }),
        issue('X2', { severity: 'BLOCKER', resolution: 'FIXED' }),
        issue('X3', { severity: 'BLOCKER', type: 'CODE_SMELL' }),
      ],
    },
  });
  const { code } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 0);
});

test('an analysis that is not of the PR is an error, not a pass', async () => {
  const api = fakeApi({ tasks: [mainTask], issues: {} });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 2);
  assert.match(output, /not of pull request 7 \(it is of branch main\)/);
});

test('a failed analysis is an error', async () => {
  const api = fakeApi({ tasks: [{ ...prTask, status: 'FAILED', errorMessage: 'boom' }], issues: {} });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 2);
  assert.match(output, /TASK1 FAILED: boom/);
});

test('an analysis that is never processed times out', async () => {
  const api = fakeApi({ tasks: [{ ...prTask, status: 'PENDING' }], issues: {} });
  const { code, output } = await gate(['--pull-request', '7', '--timeout', '0.001'], api);
  assert.equal(code, 2);
  assert.match(output, /still PENDING/);
});

test('--report-only lists blocking findings on main but exits 0', async () => {
  const api = fakeApi({ tasks: [mainTask], issues: { main: [issue('M1', { severity: 'CRITICAL' })] } });
  const { code, output } = await gate(['--report-only'], api, { GITHUB_ACTIONS: 'true' });
  assert.equal(code, 0);
  assert.match(output, /REPORT: 1 open vulnerabilities/);
  assert.match(output, /::warning file=app\.js,line=10,title=javascript:S2076::issue M1/);
});

test('no token is an error before any request', async () => {
  const api = fakeApi({ tasks: [prTask], issues: {} });
  const { code, output } = await gate(['--pull-request', '7'], api, { SONAR_TOKEN: '' });
  assert.equal(code, 2);
  assert.match(output, /SONAR_TOKEN is empty/);
  assert.equal(api.requests.length, 0);
});
