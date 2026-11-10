#!/usr/bin/env node
// SAST Gate: after a SonarQube Cloud analysis, fail if any open vulnerability
// at the top severities exists in the project, not only in new code.
//
// Usage: node scripts/sast-gate.js [--pull-request <n>] [--report-only]
//          [--report-task <file>] [--timeout <seconds>]
//   --pull-request <n>  the analysis was of PR <n>; check its findings too
//   --report-only       list the findings but exit 0 (the analysis of main)
//   --report-task       the scanner's task file (default .scannerwork/report-task.txt)
//   --timeout           how long to wait for SonarQube Cloud to process the
//                       analysis (default 300)
// Env: SONAR_TOKEN (required), SONAR_HOST_URL (default https://sonarcloud.io).
// The organization and project key come from sonar-project.properties.
//
// 1. Waits until SonarQube Cloud has processed the analysis the scanner just
//    uploaded (api/ce/task), and checks that it analyzed what was asked: the
//    PR given, or a branch when no PR is given. A PR analysis that silently
//    ran as a branch analysis would otherwise leave nothing to find.
// 2. Lists the open vulnerabilities (api/issues/search, types=VULNERABILITY,
//    resolved=false) on the main branch, which is the whole project as last
//    merged, and with --pull-request also those the PR's analysis raised on
//    the code the PR changes. A PR analysis reports only those.
// 3. Blocks on any at BLOCKER or CRITICAL (standard mode) or with a SECURITY
//    impact of BLOCKER or HIGH (Multi-Quality Rule mode). Both are checked,
//    so the Gate does not depend on which mode the organization uses. The
//    severities are checked here, not by API filters, because the API ignores
//    any parameter it does not know: a misspelt filter would pass silently.
//
// Exit: 0 no blocking finding (or --report-only), 1 blocking findings,
// 2 anything else: no token, the analysis failed or timed out, an API error.
'use strict';

const fs = require('node:fs');

const BLOCKING_SEVERITIES = ['BLOCKER', 'CRITICAL'];
const BLOCKING_SECURITY_IMPACTS = ['BLOCKER', 'HIGH'];

// Reads `key=value` lines, skipping comments and blank lines.
function parseProperties(text) {
  const props = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#') || line.startsWith('!')) continue;
    const i = line.indexOf('=');
    if (i > 0) props[line.slice(0, i).trim()] = line.slice(i + 1).trim();
  }
  return props;
}

// True if the issue blocks a merge in either severity mode.
function isBlocking(issue) {
  if (BLOCKING_SEVERITIES.includes(issue.severity)) return true;
  return (issue.impacts || []).some(
    (impact) => impact.softwareQuality === 'SECURITY' && BLOCKING_SECURITY_IMPACTS.includes(impact.severity),
  );
}

// The severities of an issue as one label, e.g. "BLOCKER, SECURITY:HIGH".
function severityLabel(issue) {
  const parts = [];
  if (issue.severity) parts.push(issue.severity);
  for (const impact of issue.impacts || []) {
    if (impact.softwareQuality === 'SECURITY') parts.push(`SECURITY:${impact.severity}`);
  }
  return parts.join(', ') || 'unknown';
}

// The file path of an issue, without the "<projectKey>:" prefix.
function filePath(issue) {
  const i = issue.component.indexOf(':');
  return i === -1 ? issue.component : issue.component.slice(i + 1);
}

function parseArgs(argv) {
  const opts = { pullRequest: '', reportOnly: false, reportTask: '.scannerwork/report-task.txt', timeout: 300 };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--pull-request') opts.pullRequest = String(argv[++i] || '');
    else if (arg === '--report-only') opts.reportOnly = true;
    else if (arg === '--report-task') opts.reportTask = argv[++i];
    else if (arg === '--timeout') opts.timeout = Number(argv[++i]);
    else throw new Error(`unknown argument: ${arg}`);
  }
  if (opts.pullRequest && !/^[0-9]+$/.test(opts.pullRequest)) throw new Error('--pull-request needs a PR number');
  if (!(opts.timeout > 0)) throw new Error('--timeout needs a number of seconds');
  return opts;
}

// Runs the Gate and returns the exit code. Everything it touches outside
// itself comes in through `deps`, so the tests can drive it.
async function run(argv, env, deps = {}) {
  const fetchFn = deps.fetch || globalThis.fetch;
  const readFile = deps.readFile || ((file) => fs.readFileSync(file, 'utf8'));
  const sleep = deps.sleep || ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
  const out = deps.out || ((line) => console.log(line));
  const pollMs = deps.pollMs ?? 5000;
  const pageSize = deps.pageSize ?? 500;
  const inActions = env.GITHUB_ACTIONS === 'true';
  const summary = [];

  let opts;
  try {
    opts = parseArgs(argv);
  } catch (err) {
    out(`::error::${err.message}`);
    return 2;
  }
  const token = env.SONAR_TOKEN || '';
  if (!token) {
    out('::error::SONAR_TOKEN is empty. In Actions it comes from the repo secret; Dependabot PRs read the Dependabot secret of the same name, and PRs from forks get neither.');
    return 2;
  }
  const host = (env.SONAR_HOST_URL || 'https://sonarcloud.io').replace(/\/+$/, '');

  // GET <host>/api/<path>. Retries a network error or a 5xx three times.
  async function api(path, params) {
    const url = `${host}/api/${path}?${new URLSearchParams(params)}`;
    for (let attempt = 1; ; attempt += 1) {
      let res;
      try {
        res = await fetchFn(url, { headers: { Authorization: `Bearer ${token}` } });
      } catch (err) {
        if (attempt >= 3) throw new Error(`${path}: ${err.message}`);
        await sleep(pollMs);
        continue;
      }
      if (res.ok) return res.json();
      if (res.status >= 500 && attempt < 3) {
        await sleep(pollMs);
        continue;
      }
      const body = (await res.text()).slice(0, 300);
      throw new Error(`${path}: HTTP ${res.status} ${body}`);
    }
  }

  try {
    const props = parseProperties(readFile('sonar-project.properties'));
    const organization = props['sonar.organization'];
    const projectKey = props['sonar.projectKey'];
    if (!organization || !projectKey) throw new Error('sonar-project.properties needs sonar.organization and sonar.projectKey');

    const reportTask = parseProperties(readFile(opts.reportTask));
    const taskId = reportTask.ceTaskId;
    if (!taskId) throw new Error(`${opts.reportTask} has no ceTaskId: did the scanner run?`);

    // 1. Wait until the analysis is processed.
    const deadline = Date.now() + opts.timeout * 1000;
    let task;
    for (;;) {
      task = (await api('ce/task', { id: taskId })).task;
      if (task.status === 'SUCCESS') break;
      if (task.status === 'FAILED' || task.status === 'CANCELED') {
        throw new Error(`analysis ${taskId} ${task.status}: ${task.errorMessage || 'no message'}`);
      }
      if (Date.now() >= deadline) throw new Error(`analysis ${taskId} still ${task.status} after ${opts.timeout} s`);
      await sleep(pollMs);
    }
    if (task.componentKey !== projectKey) {
      throw new Error(`analysis ${taskId} is of ${task.componentKey}, not ${projectKey}`);
    }
    if (opts.pullRequest && String(task.pullRequest || '') !== opts.pullRequest) {
      throw new Error(`analysis ${taskId} is not of pull request ${opts.pullRequest} (it is of ${task.pullRequest ? `pull request ${task.pullRequest}` : `branch ${task.branch || 'unknown'}`})`);
    }
    if (!opts.pullRequest && task.pullRequest) {
      throw new Error(`analysis ${taskId} is of pull request ${task.pullRequest}; pass --pull-request ${task.pullRequest}`);
    }
    out(`SAST Gate: ${projectKey} (organization ${organization})`);
    out(`Analysis ${taskId} processed: ${opts.pullRequest ? `pull request ${opts.pullRequest}` : `branch ${task.branch || 'main'}`}`);

    // 2. List the open vulnerabilities in each scope.
    async function vulnerabilities(scope) {
      const found = [];
      for (let page = 1; ; page += 1) {
        const params = { organization, componentKeys: projectKey, types: 'VULNERABILITY', resolved: 'false', ps: String(pageSize), p: String(page) };
        if (scope.pullRequest) params.pullRequest = scope.pullRequest;
        const res = await api('issues/search', params);
        // Belt and braces against an ignored filter: keep only this project's
        // unresolved vulnerabilities.
        for (const issue of res.issues || []) {
          if (issue.project && issue.project !== projectKey) continue;
          if (issue.resolution) continue;
          if (issue.type && issue.type !== 'VULNERABILITY') continue;
          found.push(issue);
        }
        const total = (res.paging && res.paging.total) ?? res.total ?? 0;
        if (page * pageSize >= total || !(res.issues || []).length) break;
      }
      return found;
    }

    const scopes = [{ name: 'main branch', pullRequest: '' }];
    if (opts.pullRequest) scopes.push({ name: `pull request ${opts.pullRequest}`, pullRequest: opts.pullRequest });

    const blocking = [];
    for (const scope of scopes) {
      const found = await vulnerabilities(scope);
      const blocked = found.filter(isBlocking);
      out(`${scope.name}: ${found.length} open ${found.length === 1 ? 'vulnerability' : 'vulnerabilities'}, ${blocked.length} blocking`);
      for (const issue of blocked) blocking.push({ scope, issue });
    }

    // 3. Report, and block unless --report-only.
    if (!blocking.length) {
      out('PASS: no open vulnerability at BLOCKER or CRITICAL, or with a SECURITY impact of BLOCKER or HIGH.');
      summary.push('**SAST Gate passed:** no open vulnerability at the top severities.');
      return 0;
    }
    out('');
    summary.push('| Severity | Rule | Where | Message |', '| --- | --- | --- | --- |');
    for (const { scope, issue } of blocking) {
      const where = issue.line ? `${filePath(issue)}:${issue.line}` : filePath(issue);
      const link = `${host}/project/issues?id=${encodeURIComponent(projectKey)}${scope.pullRequest ? `&pullRequest=${scope.pullRequest}` : ''}&open=${issue.key}`;
      out(`BLOCKING  ${severityLabel(issue)}  ${issue.rule}  ${where}  (${scope.name})`);
      out(`          ${issue.message}`);
      out(`          ${link}`);
      if (inActions) {
        const level = opts.reportOnly ? 'warning' : 'error';
        out(`::${level} file=${filePath(issue)}${issue.line ? `,line=${issue.line}` : ''},title=${issue.rule}::${issue.message}`);
      }
      summary.push(`| ${severityLabel(issue)} | \`${issue.rule}\` | [${where}](${link}) | ${issue.message} |`);
    }
    out('');
    if (opts.reportOnly) {
      out(`REPORT: ${blocking.length} open vulnerabilities at the top severities (report only, not a Gate here).`);
      summary.unshift(`**SAST report:** ${blocking.length} open vulnerabilities at the top severities.`, '');
      return 0;
    }
    out(`FAIL: ${blocking.length} open ${blocking.length === 1 ? 'vulnerability' : 'vulnerabilities'} at the top severities. Fix ${blocking.length === 1 ? 'it' : 'them'} before merging.`);
    summary.unshift(`**SAST Gate failed:** ${blocking.length} open vulnerabilities at the top severities.`, '');
    return 1;
  } catch (err) {
    out(`::error::SAST Gate could not decide: ${err.message}`);
    summary.push(`**SAST Gate error:** ${err.message}`);
    return 2;
  } finally {
    if (env.GITHUB_STEP_SUMMARY && summary.length) {
      (deps.appendFile || fs.appendFileSync)(env.GITHUB_STEP_SUMMARY, `${summary.join('\n')}\n`);
    }
  }
}

module.exports = { parseProperties, isBlocking, severityLabel, run };

if (require.main === module) {
  run(process.argv.slice(2), process.env).then((code) => process.exit(code));
}
