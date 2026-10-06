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

import { writeFile, stat } from 'node:fs/promises';
import { inflateRawSync } from 'node:zlib';
import { join, resolve } from 'node:path';

/**
 * Мінімальний читач ZIP: повертає [{ name, content }].
 * Підтримує методи 0 (без стиснення) і 8 (deflate) — саме їх використовує
 * GitHub для архівів артефактів.
 */
function extractZip(buffer) {
  let eocd = -1;
  const minOffset = Math.max(0, buffer.length - 66000);
  for (let i = buffer.length - 22; i >= minOffset; i -= 1) {
    if (buffer.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('Файл не схожий на ZIP-архів');

  const count = buffer.readUInt16LE(eocd + 10);
  let offset = buffer.readUInt32LE(eocd + 16);
  const directory = [];

  for (let i = 0; i < count; i += 1) {
    if (buffer.readUInt32LE(offset) !== 0x02014b50) break;
    const method = buffer.readUInt16LE(offset + 10);
    const compressedSize = buffer.readUInt32LE(offset + 20);
    const nameLength = buffer.readUInt16LE(offset + 28);
    const extraLength = buffer.readUInt16LE(offset + 30);
    const commentLength = buffer.readUInt16LE(offset + 32);
    const localOffset = buffer.readUInt32LE(offset + 42);
    const name = buffer.toString('utf8', offset + 46, offset + 46 + nameLength);
    directory.push({ name, method, compressedSize, localOffset });
    offset += 46 + nameLength + extraLength + commentLength;
  }

  const entries = [];
  for (const entry of directory) {
    if (entry.name.endsWith('/')) continue;
    const header = entry.localOffset;
    if (buffer.readUInt32LE(header) !== 0x04034b50) continue;
    const nameLength = buffer.readUInt16LE(header + 26);
    const extraLength = buffer.readUInt16LE(header + 28);
    const start = header + 30 + nameLength + extraLength;
    const raw = buffer.subarray(start, start + entry.compressedSize);
    const content = entry.method === 0 ? Buffer.from(raw) : inflateRawSync(raw);
    entries.push({ name: entry.name, content });
  }
  return entries;
}

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

console.log('Завантажую архів…');
const downloadResponse = await api(artifact.archive_download_url);
const archive = Buffer.from(await downloadResponse.arrayBuffer());
console.log('Розпаковую (' + Math.round(archive.length / 1024) + ' КБ)…');

// Розпаковуємо ZIP власними силами: у середовищі з обмеженнями запуск
// зовнішніх програм (tar, powershell) може бути заблокований.
const entries = extractZip(archive);
const ipaEntry = entries.find((entry) => entry.name.toLowerCase().endsWith('.ipa'));
if (!ipaEntry) {
  console.error('В архіві немає .ipa — перевірте лог збірки.');
  console.error('Вміст архіву: ' + entries.map((entry) => entry.name).join(', '));
  process.exit(1);
}

const target = join(outputDirectory, 'KrupaSpanish.ipa');
await writeFile(target, ipaEntry.content);
const info = await stat(target);

console.log('');
console.log('Готово: ' + target);
console.log('Розмір: ' + (info.size / (1024 * 1024)).toFixed(1) + ' МБ');
console.log('');
console.log('Далі: передайте файл людині, яка підключить iPhone кабелем до комп’ютера');
console.log('і встановить застосунок через Sideloadly (інструкція: docs/install-ios-17.md).');
