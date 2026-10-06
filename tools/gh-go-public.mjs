// Робить репозиторій публічним, увімкнює GitHub Pages і перезапускає
// публікацію веб-версії.
//
// Запуск:
//   node tools/gh-go-public.mjs --repo ЛОГІН/НАЗВА --token ghp_xxx

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 2) {
    const key = String(argv[i] || '').replace(/^--/, '');
    if (key) args[key] = argv[i + 1];
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

async function call(url, options) {
  const response = await fetch(url, Object.assign({ headers }, options));
  const text = await response.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch (error) { json = { raw: text }; }
  return { ok: response.ok, status: response.status, json };
}

const api = 'https://api.github.com/repos/' + repo;

// 1. Публічність
const info = await call(api);
if (!info.ok) {
  console.error('Не бачу репозиторій (HTTP ' + info.status + ')');
  process.exit(1);
}

if (info.json.private) {
  console.log('Змінюю видимість на публічну…');
  const patched = await call(api, { method: 'PATCH', body: JSON.stringify({ private: false }) });
  if (!patched.ok) {
    console.error('Не вдалося змінити видимість (HTTP ' + patched.status + '): '
      + JSON.stringify(patched.json).slice(0, 200));
    process.exit(1);
  }
  console.log('Тепер репозиторій публічний: ' + patched.json.html_url);
} else {
  console.log('Репозиторій уже публічний.');
}

// 2. Pages
await new Promise((resolve) => setTimeout(resolve, 3000));
const pagesUrl = api + '/pages';
let pages = await call(pagesUrl);

if (!pages.ok) {
  console.log('Увімкнюю GitHub Pages…');
  const created = await call(pagesUrl, { method: 'POST', body: JSON.stringify({ build_type: 'workflow' }) });
  if (!created.ok) {
    console.error('Не вдалося увімкнути Pages (HTTP ' + created.status + '): '
      + JSON.stringify(created.json).slice(0, 250));
    console.error('Можна зробити вручну: https://github.com/' + repo + '/settings/pages (Source: GitHub Actions)');
    process.exit(1);
  }
  pages = { ok: true, json: created.json };
  console.log('Pages увімкнено.');
}

const siteUrl = (pages.json && (pages.json.html_url || pages.json.url)) || null;
console.log('Адреса веб-версії: ' + (siteUrl || 'з’явиться після першої публікації'));

// 3. Перезапуск публікації
const runs = await call(api + '/actions/runs?per_page=20');
const deployRun = runs.ok
  ? runs.json.workflow_runs.find((run) => run.name === 'Deploy web version (PWA)')
  : null;

if (deployRun) {
  console.log('Перезапускаю «Deploy web version (PWA)» (запуск ' + deployRun.id + ')…');
  const rerun = await call(api + '/actions/runs/' + deployRun.id + '/rerun', { method: 'POST' });
  if (rerun.ok) {
    console.log('Перезапущено: ' + deployRun.html_url);
  } else {
    console.log('Перезапуск не вдався (HTTP ' + rerun.status + ') — зроблю новий коміт пізніше.');
  }
} else {
  console.log('Запуск «Deploy web version» не знайдено — він створиться після наступного пушу.');
}

console.log('');
console.log('Готово. Сторінка налаштувань: https://github.com/' + repo + '/settings/pages');
