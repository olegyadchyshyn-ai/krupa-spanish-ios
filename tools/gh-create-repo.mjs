// Створює репозиторій на GitHub для публікації застосунку.
//
// Запуск:
//   node tools/gh-create-repo.mjs --token ghp_xxx --name krupa-spanish-ios [--public]
//
// Скрипт нічого не друкує з токена й не зберігає його.

import { writeFile } from 'node:fs/promises';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const key = String(argv[i] || '').replace(/^--/, '');
    if (!key) continue;
    if (key === 'public') { args.public = true; continue; }
    args[key] = argv[i + 1];
    i += 1;
  }
  return args;
}

const args = parseArgs(process.argv);
const token = args.token || process.env.GITHUB_TOKEN;
const name = args.name || 'krupa-spanish-ios';
const isPublic = Boolean(args.public);

if (!token) {
  console.error('Потрібен --token');
  process.exit(2);
}

const headers = {
  Authorization: 'Bearer ' + token,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'krupa-publisher'
};

async function call(url, options) {
  const response = await fetch(url, Object.assign({ headers }, options));
  const text = await response.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (error) { json = { raw: text }; }
  return { ok: response.ok, status: response.status, json };
}

// 1. Хто ми
const me = await call('https://api.github.com/user');
if (!me.ok) {
  console.error('Токен не працює (HTTP ' + me.status + '). Перевірте, що скопійовано весь рядок і токен не протермінований.');
  process.exit(1);
}

const login = me.json.login;
const plan = (me.json.plan && me.json.plan.name) || 'unknown';
console.log('Акаунт: ' + login + ' (план: ' + plan + ')');

// 2. Чи існує репозиторій
const full = login + '/' + name;
const existing = await call('https://api.github.com/repos/' + full);

let repo = existing.json;
if (existing.ok) {
  console.log('Репозиторій уже існує: ' + repo.html_url);
} else if (existing.status === 404) {
  console.log('Створюю репозиторій ' + name + ' (' + (isPublic ? 'публічний' : 'приватний') + ')…');
  const created = await call('https://api.github.com/user/repos', {
    method: 'POST',
    body: JSON.stringify({
      name,
      description: 'KRUPA Spanish — iOS-застосунок і веб-версія для вивчення іспанської мови',
      private: !isPublic,
      has_issues: false,
      has_wiki: false,
      auto_init: false
    })
  });
  if (!created.ok) {
    console.error('Не вдалося створити репозиторій (HTTP ' + created.status + '): '
      + JSON.stringify(created.json).slice(0, 300));
    console.error('Найчастіше причина — у токена немає права створювати репозиторії (scope repo).');
    process.exit(1);
  }
  repo = created.json;
  console.log('Створено: ' + repo.html_url);
} else {
  console.error('Несподівана відповідь GitHub: HTTP ' + existing.status);
  process.exit(1);
}

// 3. Стан Pages (для веб-версії)
const pages = await call('https://api.github.com/repos/' + full + '/pages');
const pagesState = pages.ok
  ? { enabled: true, url: pages.json.html_url, buildType: pages.json.build_type }
  : { enabled: false, status: pages.status, hint: pages.status === 404 ? 'ще не увімкнено' : 'немає доступу' };

const result = {
  login,
  plan,
  repo: full,
  url: repo.html_url,
  private: Boolean(repo.private),
  cloneUrl: repo.clone_url,
  actionsUrl: repo.html_url + '/actions',
  pages: pagesState,
  pagesSupported: plan !== 'free' || !repo.private
};

await writeFile('.gh-setup.json', JSON.stringify(result, null, 2));
console.log('');
console.log('Репозиторій: ' + result.repo);
console.log('Приватний: ' + (result.private ? 'так' : 'ні'));
console.log('GitHub Pages: ' + (pagesState.enabled ? pagesState.url : 'не увімкнено (' + pagesState.hint + ')'));
console.log('Pages доступний для цього репозиторію: ' + (result.pagesSupported ? 'так' : 'НІ — на безкоштовному плані Pages працює лише для публічних репозиторіїв'));
