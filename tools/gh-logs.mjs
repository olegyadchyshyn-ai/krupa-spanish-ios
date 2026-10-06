// Читає логи запусків GitHub Actions і показує помилки.
//
// Запуск:
//   node tools/gh-logs.mjs --repo ЛОГІН/НАЗВА --token ghp_xxx [--run ID] [--workflow "Build iOS IPA"]

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const key = String(argv[i] || '').replace(/^--/, '');
    if (!key) continue;
    args[key] = argv[i + 1];
    i += 1;
  }
  return args;
}

const args = parseArgs(process.argv);
const token = args.token || process.env.GITHUB_TOKEN;
const repo = args.repo;

if (!token || !repo) {
  console.error('Потрібні --repo і --token');
  process.exit(2);
}

const headers = {
  Authorization: 'Bearer ' + token,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'krupa-publisher'
};

async function getJson(url) {
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error('HTTP ' + response.status + ' для ' + url);
  return response.json();
}

let runId = args.run;

if (!runId) {
  const runs = await getJson('https://api.github.com/repos/' + repo + '/actions/runs?per_page=20');
  const wanted = args.workflow
    ? runs.workflow_runs.find((run) => run.name === args.workflow)
    : runs.workflow_runs[0];
  if (!wanted) {
    console.error('Запусків не знайдено.');
    process.exit(1);
  }
  runId = wanted.id;
  console.log('Запуск: ' + wanted.name + ' — ' + wanted.status + '/' + wanted.conclusion);
  console.log(wanted.html_url);
}

const jobs = await getJson('https://api.github.com/repos/' + repo + '/actions/runs/' + runId + '/jobs');

for (const job of jobs.jobs) {
  console.log('');
  console.log('Завдання: ' + job.name + ' — ' + job.conclusion);
  for (const step of job.steps || []) {
    const mark = step.conclusion === 'success' ? '✓' : step.conclusion === 'skipped' ? '–' : '✗';
    console.log('  ' + mark + ' ' + step.name + (step.conclusion !== 'success' && step.conclusion !== 'skipped' ? '  (' + step.conclusion + ')' : ''));
  }

  if (job.conclusion === 'success') continue;

  console.log('  --- фрагменти логу з помилками ---');
  const response = await fetch('https://api.github.com/repos/' + repo + '/actions/jobs/' + job.id + '/logs', { headers });
  if (!response.ok) {
    console.log('  (лог недоступний: HTTP ' + response.status + ')');
    continue;
  }
  const log = await response.text();
  const lines = log.split(/\r?\n/);
  const interesting = lines.filter((line) =>
    /error:|##\[error\]|Error:|fatal:|error \[|cannot find|❌|No such file/.test(line));

  const shown = interesting.slice(0, 40);
  for (const line of shown) console.log('  ' + line.trim().slice(0, 220));
  if (!shown.length) {
    console.log('  (рядків зі словом error не знайдено — показую останні 25 рядків логу)');
    for (const line of lines.slice(-25)) console.log('  ' + line.trim().slice(0, 200));
  }
}
