// Сервіс-воркер: застосунок працює офлайн після першого відкриття.
//
// Стратегія: спершу кеш (миттєво й без мережі), у фоні — оновлення з мережі,
// якщо є інтернет. Контент курсу не змінюється, тому кеш безпечний.

const VERSION = 'krupa-spanish-v1';

const SHELL = [
  './',
  './index.html',
  './manifest.webmanifest',
  './css/app.css',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './js/app.js',
  './js/content.js',
  './js/store.js',
  './js/tts.js',
  './js/ui.js',
  './js/views/onboarding.js',
  './js/views/home.js',
  './js/views/learn.js',
  './js/views/topic.js',
  './js/views/session.js',
  './js/views/review.js',
  './js/views/words.js',
  './js/views/word.js',
  './js/views/grammar.js',
  './js/views/listening.js',
  './js/views/speaking.js',
  './js/views/ai.js',
  './js/views/progress.js',
  './js/views/settings.js',
  './content/words.a0.json',
  './content/words.a1.json',
  './content/words.a2.json',
  './content/sentences.a0.json',
  './content/sentences.a1.json',
  './content/sentences.a2.json',
  './content/exercises.a0.json',
  './content/exercises.a1.json',
  './content/exercises.a2.json',
  './content/grammar.a0a1.json',
  './content/grammar.a2.json',
  './content/listening.a0.json',
  './content/listening.a1.json',
  './content/listening.a2.json',
  './content/topics.a0.json',
  './content/topics.a1.json',
  './content/topics.a2.json'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(VERSION)
      .then((cache) => cache.addAll(SHELL))
      .then(() => self.skipWaiting())
      .catch(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key !== VERSION).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== location.origin) return;

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((response) => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(VERSION).then((cache) => cache.put(request, copy)).catch(() => {});
          }
          return response;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
