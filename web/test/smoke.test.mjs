// Димовий тест: реально малює кожен екран у заглушці DOM і ловить помилки
// виконання (звернення до неіснуючих полів, забуті функції, друкарські помилки).
//
// Запуск:  node web/test/smoke.test.mjs

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { installDom, StubNode } from './dom-stub.mjs';

installDom();

const here = dirname(fileURLToPath(import.meta.url));
const contentRoot = join(here, '..', 'content') + '/';

const { loadContent } = await import('../js/content.js');
const { createStore, createMemoryStorage, buildPlan, makeItem } = await import('../js/store.js');
const { createTts } = await import('../js/tts.js');

const fileFetch = async (url) => {
  const path = join(contentRoot, url.replace(/^content\//, ''));
  try {
    const text = await readFile(path, 'utf8');
    return { ok: true, status: 200, json: async () => JSON.parse(text) };
  } catch (error) {
    return { ok: false, status: 404, json: async () => ({}) };
  }
};

const content = await loadContent('content/', fileFetch);
const store = createStore(createMemoryStorage(), content);
store.updateProfile({ level: 'A0', onboardingDone: true, dailyMinutes: 15 });

const navigations = [];
const app = {
  content,
  store,
  tts: createTts(),
  navigate(hash) { navigations.push(hash); },
  refresh() {},
  toast(message) { navigations.push('toast:' + message); },
  speak() {},
  applyPreferences() {},
  get level() { return store.profile.level; }
};

// Додаємо трохи даних, щоб екрани не були порожні.
const firstWord = content.words.find((w) => w.level === 'A0');
const firstTopic = content.topics.find((t) => t.level === 'A0');
const firstGrammar = content.grammar[0];
const firstListening = content.listening[0];
const plan = buildPlan(store, content, { level: 'A0' });
if (plan.items.length) {
  const item = plan.items[0];
  store.recordAnswer(item, 'GOOD', 3000, false);
  store.recordAnswer(item, 'AGAIN', 3000, false);
}

const CASES = [
  ['views/onboarding.js', 'renderOnboarding', null],
  ['views/home.js', 'renderHome', null],
  ['views/learn.js', 'renderLearn', null],
  ['views/topic.js', 'renderTopic', { id: firstTopic.id }],
  ['views/session.js', 'renderSession', { topicId: null }],
  ['views/review.js', 'renderReview', null],
  ['views/words.js', 'renderWords', { level: 'A0' }],
  ['views/word.js', 'renderWord', { id: firstWord.id }],
  ['views/grammar.js', 'renderGrammarList', null],
  ['views/grammar.js', 'renderGrammarDetail', { id: firstGrammar.id }],
  ['views/listening.js', 'renderListeningList', null],
  ['views/listening.js', 'renderListeningDetail', { id: firstListening.id }],
  ['views/speaking.js', 'renderSpeaking', null],
  ['views/ai.js', 'renderAi', { scenarioId: null }],
  ['views/ai.js', 'renderAi', { scenarioId: 'cafe' }],
  ['views/progress.js', 'renderProgress', null],
  ['views/progress.js', 'renderProgressDetail', null],
  ['views/settings.js', 'renderSettings', null],
  ['views/settings.js', 'renderBackup', null],
  ['views/settings.js', 'renderAbout', null],
  ['views/settings.js', 'renderDiagnostics', null]
];

let passed = 0;
let failed = 0;

function countNodes(element) {
  if (!element || !element.children) return 0;
  return element.children.reduce((sum, child) => sum + 1 + countNodes(child), 0);
}

for (const [file, fn, params] of CASES) {
  const label = file.replace('views/', '') + ' → ' + fn + (params ? ' ' + JSON.stringify(params) : '');
  try {
    const module = await import('../js/' + file);
    const render = module[fn];
    if (typeof render !== 'function') {
      failed += 1;
      console.log('  ✗ ' + label + ' — функції немає');
      continue;
    }
    const element = render(app, params || {});
    if (!(element instanceof StubNode)) {
      failed += 1;
      console.log('  ✗ ' + label + ' — повернуто не вузол DOM');
      continue;
    }
    const nodes = countNodes(element);
    if (nodes === 0) {
      failed += 1;
      console.log('  ✗ ' + label + ' — екран порожній');
      continue;
    }
    passed += 1;
    console.log('  ✓ ' + label + ' (' + nodes + ' вузлів)');
  } catch (error) {
    failed += 1;
    console.log('  ✗ ' + label + ' — помилка: ' + error.message);
  }
}

// Перевіряємо, що обробники подій не падають: натискаємо кнопки на занятті.
try {
  const { renderSession } = await import('../js/views/session.js');
  const session = renderSession(app, { topicId: null });
  const buttons = [];
  (function collect(element) {
    if (!element || !element.children) return;
    for (const child of element.children) {
      if (child.tagName === 'BUTTON') buttons.push(child);
      collect(child);
    }
  })(session);

  let clicks = 0;
  for (const button of buttons.slice(0, 12)) {
    try {
      button.dispatch('click');
      clicks += 1;
    } catch (error) {
      failed += 1;
      console.log('  ✗ клік по кнопці заняття — помилка: ' + error.message);
    }
  }
  console.log('  ✓ обробники заняття: натиснуто кнопок ' + clicks + ' із ' + buttons.length);
  passed += 1;
} catch (error) {
  failed += 1;
  console.log('  ✗ перевірка обробників заняття: ' + error.message);
}

console.log('\nДимовий тест: ' + passed + ' успішно, ' + failed + ' з помилками');
process.exit(failed === 0 ? 0 : 1);
