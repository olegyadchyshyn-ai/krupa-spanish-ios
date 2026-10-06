// Перевірка .ipa: що це коректний пакет iOS і що всередині є потрібні файли.
//
// Запуск:  node tools/inspect-ipa.mjs KrupaSpanish.ipa

import { readFile } from 'node:fs/promises';
import { inflateRawSync } from 'node:zlib';
import { basename } from 'node:path';

const file = process.argv[2] || 'KrupaSpanish.ipa';
const buffer = await readFile(file);

// Той самий мінімальний читач ZIP, що й у завантажувачі.
function listZip(buf) {
  let eocd = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 66000); i -= 1) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error('не ZIP');
  const count = buf.readUInt16LE(eocd + 10);
  let offset = buf.readUInt32LE(eocd + 16);
  const entries = [];
  for (let i = 0; i < count; i += 1) {
    if (buf.readUInt32LE(offset) !== 0x02014b50) break;
    const method = buf.readUInt16LE(offset + 10);
    const compressedSize = buf.readUInt32LE(offset + 20);
    const uncompressedSize = buf.readUInt32LE(offset + 24);
    const nameLength = buf.readUInt16LE(offset + 28);
    const extraLength = buf.readUInt16LE(offset + 30);
    const commentLength = buf.readUInt16LE(offset + 32);
    const localOffset = buf.readUInt32LE(offset + 42);
    entries.push({
      name: buf.toString('utf8', offset + 46, offset + 46 + nameLength),
      method,
      compressedSize,
      uncompressedSize,
      localOffset
    });
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

function readEntry(buf, entry) {
  const header = entry.localOffset;
  const nameLength = buf.readUInt16LE(header + 26);
  const extraLength = buf.readUInt16LE(header + 28);
  const start = header + 30 + nameLength + extraLength;
  const raw = buf.subarray(start, start + entry.compressedSize);
  return entry.method === 0 ? Buffer.from(raw) : inflateRawSync(raw);
}

let entries;
try {
  entries = listZip(buffer);
} catch (error) {
  console.error('Файл ' + basename(file) + ' не є ZIP-архівом — це не .ipa.');
  process.exit(1);
}

const apps = entries.filter((entry) => /^Payload\/[^/]+\.app\/$/.test(entry.name));
const hasInfoPlist = entries.some((entry) => /^Payload\/[^/]+\.app\/Info\.plist$/.test(entry.name));
const icon = entries.find((entry) => /^Payload\/[^/]+\.app\/AppIcon/.test(entry.name));
const assets = entries.find((entry) => /^Payload\/[^/]+\.app\/Assets\.car$/.test(entry.name));
const contentFiles = entries.filter((entry) => /^Payload\/[^/]+\.app\/.*\.json$/.test(entry.name));
const executable = apps.length
  ? entries.find((entry) => new RegExp('^Payload/' + basename(apps[0].name) + '/' + basename(apps[0].name).replace(/\.app$/, '') + '$').test(entry.name))
  : null;

console.log('Файл: ' + basename(file));
console.log('Розмір: ' + (buffer.length / (1024 * 1024)).toFixed(2) + ' МБ');
console.log('Записів у архіві: ' + entries.length);
console.log('');

const checks = [
  ['є тека Payload/<Застосунок>.app', apps.length === 1, apps.length ? apps[0].name : 'не знайдено'],
  ['є Info.plist', hasInfoPlist, ''],
  ['є скомпільовані ресурси (Assets.car)', Boolean(assets), ''],
  ['є іконка застосунку', Boolean(icon), icon ? icon.name : ''],
  ['є виконуваний файл', Boolean(executable), executable ? executable.name : ''],
  ['у пакет включено контент курсу (JSON)', contentFiles.length >= 17, 'файлів: ' + contentFiles.length]
];

let failed = 0;
for (const [title, ok, detail] of checks) {
  if (!ok) failed += 1;
  console.log((ok ? '  ✓ ' : '  ✗ ') + title + (detail ? ' — ' + detail : ''));
}

console.log('');
if (failed === 0) {
  console.log('Пакет коректний: файл можна встановлювати на iPhone (iOS 17+) через Sideloadly.');
} else {
  console.log('Знайдено проблем: ' + failed + '. Перевірте лог збірки.');
  process.exit(1);
}
