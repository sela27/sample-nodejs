// Drives scripts/sast-gate.js against a fake SonarQube Cloud Web API.
const { test } = require('node:test');
const assert = require('node:assert/strict');

const { run } = require('../scripts/sast-gate');

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

async function gate(argv, api, env = {}, fileOverrides = {}) {
  const lines = [];
  const files = { 'sonar-project.properties': PROPERTIES, '.scannerwork/report-task.txt': REPORT_TASK, ...fileOverrides };
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

test('a PR blocks on BLOCKER or CRITICAL in standard mode, or a SECURITY impact of BLOCKER or HIGH in MQR mode, and on nothing else', async () => {
  const impact = (softwareQuality, severity) => ({ severity: 'MAJOR', impacts: [{ softwareQuality, severity }] });
  const api = fakeApi({
    tasks: [prTask],
    issues: {
      7: [
        issue('B1', { severity: 'BLOCKER' }),
        issue('B2', { severity: 'CRITICAL' }),
        issue('B3', impact('SECURITY', 'BLOCKER')),
        issue('B4', impact('SECURITY', 'HIGH')),
        issue('N1', impact('SECURITY', 'MEDIUM')),
        issue('N2', impact('MAINTAINABILITY', 'HIGH')),
      ],
    },
  });
  const { code, output } = await gate(['--pull-request', '7'], api);
  assert.equal(code, 1);
  assert.match(output, /pull request 7: 6 open vulnerabilities, 4 blocking/);
  for (const key of ['B1', 'B2', 'B3', 'B4']) assert.match(output, new RegExp(`&open=${key}$`, 'm'));
  for (const key of ['N1', 'N2']) assert.doesNotMatch(output, new RegExp(`&open=${key}$`, 'm'));
  assert.match(output, /BLOCKING {2}MAJOR, SECURITY:BLOCKER {2}/);
});

test('reads the project from sonar-project.properties and the task from the scanner file as written', async () => {
  // Comments, blank lines, spaces around "=", CRLF line ends, and the
  // scanner's other keys, whose values hold "=" themselves.
  const files = {
    'sonar-project.properties': '# SonarQube Cloud\r\n! another comment\r\n\r\nsonar.organization = acme\r\nsonar.projectKey=acme_app\r\n',
    '.scannerwork/report-task.txt': [
      'organization=acme',
      'projectKey=acme_app',
      'serverUrl=https://sonar.test',
      'dashboardUrl=https://sonar.test/dashboard?id=acme_app&pullRequest=7',
      'ceTaskId=TASK1',
      'ceTaskUrl=https://sonar.test/api/ce/task?id=TASK1',
    ].join('\r\n'),
  };
  const api = fakeApi({ tasks: [prTask], issues: {} });
  const { code, output } = await gate(['--pull-request', '7'], api, {}, files);
  assert.equal(code, 0, output);
  assert.match(output, /^SAST Gate: acme_app \(organization acme\)$/m);
  assert.deepEqual(api.requests.find((r) => r.path === '/api/ce/task').params, { id: 'TASK1' });
  assert.ok(api.requests.filter((r) => r.path === '/api/issues/search').every((r) => r.params.componentKeys === 'acme_app'));
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

test('trailing slashes on SONAR_HOST_URL are dropped', async () => {
  const api = fakeApi({ tasks: [prTask], issues: { 7: [issue('P1', { severity: 'BLOCKER' })] } });
  const { output } = await gate(['--pull-request', '7'], api, { SONAR_HOST_URL: 'https://sonar.test//' });
  assert.match(output, /https:\/\/sonar\.test\/project\/issues\?id=acme_app/);
  assert.ok(api.requests.every((r) => r.path.startsWith('/api/')));
});
