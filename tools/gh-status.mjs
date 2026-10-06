// Стан збірок і сторінок на GitHub: показує останні запуски workflow.
//
// Запуск:
//   node tools/gh-status.mjs --repo ЛОГІН/НАЗВА --token ghp_xxx [--wait]

import { readFile } from 'node:fs/promises';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const key = String(argv[i] || '').replace(/^--/, '');
    if (!key) continue;
    if (key === 'wait') { args.wait = true; continue; }
    args[key] = argv[i + 1];
    i += 1;
  }
  return args;
}

const args = parseArgs(process.argv);
let token = args.token || process.env.GITHUB_TOKEN;
let repo = args.repo;

if (!token || !repo) {
  try {
    const saved = JSON.parse(await readFile('.gh-setup.json', 'utf8'));
    repo = repo || saved.repo;
    token = token || process.env.GITHUB_TOKEN;
  } catch (error) {
    // налаштування ще не створені — нічого страшного
  }
}

if (!token || !repo) {
  console.error('Потрібні --repo ЛОГІН/НАЗВА і --token');
  process.exit(2);
}

const headers = {
  Authorization: 'Bearer ' + token,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'krupa-publisher'
};

async function get(url) {
  const response = await fetch(url, { headers });
  if (!response.ok) {
    console.error('HTTP ' + response.status + ' для ' + url);
    return null;
  }
  return response.json();
}

function icon(run) {
  if (run.status !== 'completed') return '⏳ ' + run.status;
  return run.conclusion === 'success' ? '✅ успішно' : '❌ ' + run.conclusion;
}

async function showOnce() {
  const data = await get('https://api.github.com/repos/' + repo + '/actions/runs?per_page=10');
  if (!data) return null;

  console.log('Репозиторій: ' + repo);
  console.log('Запуски (останні 10):');
  if (!data.workflow_runs.length) {
    console.log('  — ще немає жодного запуску (GitHub може думати 5–20 секунд після пушу)');
  }
  for (const run of data.workflow_runs) {
    console.log('  • ' + run.name + ' — ' + icon(run) + '  [' + run.head_branch + ']');
    console.log('      ' + run.html_url);
  }
  return data.workflow_runs;
}

let runs = await showOnce();

if (args.wait && runs) {
  const pending = () => runs.some((run) => run.status !== 'completed');
  let attempts = 0;
  while (pending() && attempts < 120) {
    await new Promise((resolve) => setTimeout(resolve, 15000));
    attempts += 1;
    runs = await showOnce();
    if (!runs) break;
    console.log('--- очікування (' + attempts + ') ---');
  }
}
