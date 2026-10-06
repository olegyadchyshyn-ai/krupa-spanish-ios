// Завантажує готовий .ipa з GitHub Actions на цей комп'ютер.
//
// Використовує HTTPS-стек Node (на відміну від PowerShell і git, які в цьому
// середовищі впираються в обмеження TLS).
//
// Запуск:
//   node tools/download-ipa.mjs --repo ЛОГІН/НАЗВА --token ghp_xxx [--out .]
//
// Токен потрібен лише на час завантаження (права: Actions — Read).
// Після використання його можна відкликати: https://github.com/settings/tokens

import { mkdtemp, writeFile, readdir, copyFile, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { createWriteStream } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';

const run = promisify(execFile);

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 2) {
    const key = String(argv[i] || '').replace(/^--/, '');
    const value = argv[i + 1];
    if (key) args[key] = value;
  }
  return args;
}

const args = parseArgs(process.argv);
const repo = args.repo;
const token = args.token || process.env.GITHUB_TOKEN;
const artifactName = args.artifact || 'KrupaSpanish-unsigned-ipa';
const outputDirectory = resolve(args.out || '.');

if (!repo || !token) {
  console.error('Потрібні параметри: --repo ЛОГІН/НАЗВА --token ТОКЕН [--out тека]');
  process.exit(2);
}

const headers = {
  Authorization: 'Bearer ' + token,
  Accept: 'application/vnd.github+json',
  'X-GitHub-Api-Version': '2022-11-28',
  'User-Agent': 'krupa-spanish-downloader'
};

async function api(url) {
  const response = await fetch(url, { headers });
  if (!response.ok) {
    const text = await response.text();
    const hint = response.status === 401
      ? 'Токен недійсний або протермінований. Створіть новий: https://github.com/settings/tokens'
      : response.status === 404
        ? 'Репозиторій не знайдено, або в токена немає доступу до нього (перевірте написання ЛОГІН/НАЗВА).'
        : response.status === 403
          ? 'Доступ заборонено: можливо, у токена немає права Actions: Read.'
          : 'Несподівана відповідь GitHub.';
    console.error('Помилка: ' + hint);
    console.error('Деталі: HTTP ' + response.status + ' — ' + text.slice(0, 200));
    process.exit(1);
  }
  return response;
}

console.log('Шукаю артефакт «' + artifactName + '» у ' + repo + '…');

const listResponse = await api('https://api.github.com/repos/' + repo + '/actions/artifacts?per_page=50');
const list = await listResponse.json();

if (!list.artifacts || list.artifacts.length === 0) {
  console.error('Артефактів немає. Спершу дочекайтеся завершення збірки: https://github.com/' + repo + '/actions');
  process.exit(1);
}

const artifact = list.artifacts
  .filter((item) => item.name === artifactName && !item.expired)
  .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))[0];

if (!artifact) {
  console.error('Артефакт «' + artifactName + '» не знайдено. Доступні:');
  for (const item of list.artifacts) {
    console.error('  • ' + item.name + ' (' + item.created_at + (item.expired ? ', протермінований' : '') + ')');
  }
  process.exit(1);
}

console.log('Знайдено: ' + artifact.name + ', створено ' + artifact.created_at
  + ', розмір ' + Math.round(artifact.size_in_bytes / 1024) + ' КБ');

const workDir = await mkdtemp(join(tmpdir(), 'krupa-ipa-'));
const zipPath = join(workDir, 'artifact.zip');

console.log('Завантажую архів…');
const downloadResponse = await api(artifact.archive_download_url);
await pipeline(Readable.fromWeb(downloadResponse.body), createWriteStream(zipPath));

console.log('Розпаковую…');
// Використовуємо tar (є у Windows 10+ і в macOS): він уміє і zip.
try {
  await run('tar', ['-xf', zipPath, '-C', workDir]);
} catch (error) {
  await run('powershell', ['-NoProfile', '-Command',
    'Expand-Archive -LiteralPath "' + zipPath + '" -DestinationPath "' + workDir + '" -Force']);
}

const entries = await readdir(workDir, { recursive: true });
const ipaRelative = entries.find((name) => String(name).toLowerCase().endsWith('.ipa'));
if (!ipaRelative) {
  console.error('В архіві немає .ipa — перевірте лог збірки.');
  process.exit(1);
}

const source = join(workDir, ipaRelative);
const target = join(outputDirectory, 'KrupaSpanish.ipa');
await copyFile(source, target);
const info = await stat(target);

await rm(workDir, { recursive: true, force: true });

console.log('');
console.log('Готово: ' + target);
console.log('Розмір: ' + (info.size / (1024 * 1024)).toFixed(1) + ' МБ');
console.log('');
console.log('Далі: передайте файл людині, яка підключить iPhone кабелем до комп’ютера');
console.log('і встановить застосунок через Sideloadly (інструкція: docs/install-ios-17.md).');
