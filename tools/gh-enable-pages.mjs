// Увімкнення GitHub Pages для репозиторію (публікація веб-версії).
//
// Запуск:
//   node tools/gh-enable-pages.mjs --repo ЛОГІН/НАЗВА --token ghp_xxx
//
// На безкоштовному плані Pages працює лише для публічних репозиторіїв —
// скрипт прямо скаже, якщо причина саме в цьому.

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
  console.error('Потрібні --repo ЛОГІН/НАЗВА і --token');
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

const base = 'https://api.github.com/repos/' + repo + '/pages';

// Уже ввімкнено?
const current = await call(base);
if (current.ok) {
  console.log('Pages уже увімкнено: ' + current.json.html_url);
  process.exit(0);
}

console.log('Увімкнюю GitHub Pages (джерело — GitHub Actions)…');
const enabled = await call(base, {
  method: 'POST',
  body: JSON.stringify({ build_type: 'workflow' })
});

if (enabled.ok) {
  console.log('Готово: ' + enabled.json.html_url);
  process.exit(0);
}

const message = JSON.stringify(enabled.json).slice(0, 400);
console.log('Не вдалося увімкнути (HTTP ' + enabled.status + '): ' + message);
console.log('');

if (enabled.status === 409) {
  console.log('Схоже, Pages уже налаштовано в іншому режимі. Перевірте:');
  console.log('  https://github.com/' + repo + '/settings/pages');
} else if (enabled.status === 422 || /private|upgrade|plan/i.test(message)) {
  console.log('Причина, найімовірніше, у плані: на безкоштовному акаунті GitHub Pages');
  console.log('працює лише для ПУБЛІЧНИХ репозиторіїв. Два варіанти:');
  console.log('  1) зробити репозиторій публічним (код стане видимим для всіх);');
  console.log('  2) залишити приватним і користуватися нативною версією (.ipa) —');
  console.log('     веб-версію тоді можна розмістити на іншому хостингу.');
} else if (enabled.status === 403) {
  console.log('У токена немає права керувати Pages. Додайте право «Pages: Read and write»');
  console.log('або увімкніть вручну: https://github.com/' + repo + '/settings/pages');
}
process.exit(1);
