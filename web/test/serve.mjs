// Мінімальний статичний сервер для локальної перевірки веб-версії.
//
// Запуск:  node web/test/serve.mjs [порт]
// Потім:   http://localhost:8080
//
// Потрібен лише для перевірки на комп'ютері: у Safari на iPhone застосунок
// відкривається за посиланням GitHub Pages.

import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, normalize, extname } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const port = Number(process.argv[2]) || 8080;

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.webmanifest': 'application/manifest+json; charset=utf-8',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://localhost');
    let path = decodeURIComponent(url.pathname);
    if (path === '/' || path === '') path = '/index.html';

    const safePath = normalize(path).replace(/^(\.\.[/\\])+/, '');
    const filePath = join(root, safePath);

    if (!filePath.startsWith(root)) {
      response.writeHead(403).end('Заборонено');
      return;
    }

    const info = await stat(filePath);
    if (info.isDirectory()) {
      response.writeHead(403).end('Це тека');
      return;
    }

    const data = await readFile(filePath);
    response.writeHead(200, {
      'Content-Type': TYPES[extname(filePath)] || 'application/octet-stream',
      'Cache-Control': 'no-cache'
    });
    response.end(data);
  } catch (error) {
    response.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
    response.end('Не знайдено: ' + request.url);
  }
});

server.listen(port, () => {
  console.log('Веб-версія доступна: http://localhost:' + port);
});
