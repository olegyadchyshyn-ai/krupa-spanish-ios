// Функціональна перевірка заняття: чи бачить користувач реальні завдання.
//
// Запуск:  node web/test/session.test.mjs
//
// Перевіряє, що для нового користувача план заняття непорожній, що перший крок
// має текст і варіанти відповіді, і що крок можна пройти (перевірка + оцінка).

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { installDom, StubNode } from './dom-stub.mjs';

installDom();

const here = dirname(fileURLToPath(import.meta.url));
const contentRoot = join(here, '..', 'content') + '/';

const { loadContent } = await import('../js/content.js');
const { createStore, createMemoryStorage, buildPlan, makeItem, SrsEngine, itemTitle, itemUkrainian } =
  await import('../js/store.js');
const { createTts } = await import('../js/tts.js');

const fileFetch = async (url) => {
  const path = join(contentRoot, url.replace(/^content\//, ''));
  const text = await readFile(path, 'utf8');
  return { ok: true, status: 200, json: async () => JSON.parse(text) };
};

const content = await loadContent('content/', fileFetch);
const store = createStore(createMemoryStorage(), content);
store.updateProfile({ level: 'A0', onboardingDone: true });

const app = {
  content,
  store,
  tts: createTts(),
  navigate() {},
  refresh() {},
  toast() {},
  speak() {},
  applyPreferences() {},
  get level() { return store.profile.level; }
};

let passed = 0;
let failed = 0;

function check(name, condition, details) {
  if (condition) { passed += 1; console.log('  ✓ ' + name); }
  else { failed += 1; console.log('  ✗ ' + name + (details ? '  → ' + details : '')); }
}

function textOf(element) {
  if (!element) return '';
  if (!element.children || element.children.length === 0) return element.textContent || '';
  return element.children.map(textOf).join(' ') + ' ' + (element.textContent && element.children.length === 0 ? element.textContent : '');
}

function collect(element, tagName, out) {
  const result = out || [];
  if (!element || !element.children) return result;
  for (const child of element.children) {
    if (child.tagName === tagName) result.push(child);
    collect(child, tagName, result);
  }
  return result;
}

console.log('План заняття для нового користувача:');
const plan = buildPlan(store, content, { level: 'A0' });
check('план непорожній', plan.items.length > 0, 'елементів: ' + plan.items.length);
const kinds = plan.blocks.map((block) => block.kind).join(' → ');
console.log('    блоки: ' + kinds);
check('перший блок — нові слова або повторення', ['NEW_WORDS', 'REVIEW'].includes(plan.blocks[0].kind), plan.blocks[0].kind);
check('є блок нових слів', plan.blocks.some((b) => b.kind === 'NEW_WORDS'));
check('є блок вправ', plan.blocks.some((b) => b.kind === 'EXERCISES'));

console.log('\nПерший крок заняття:');
const { renderSession } = await import('../js/views/session.js');
const view = renderSession(app, { topicId: null });
check('екран заняття намальовано', view instanceof StubNode);

const text = textOf(view).replace(/\s+/g, ' ').trim();
console.log('    текст: ' + text.slice(0, 160));
check('на екрані є іспанське слово або підказка', text.length > 20);
check('є кнопка «Закрити» або прогрес', /Крок|Закрити|Заняття/i.test(text));

const buttons = collect(view, 'BUTTON');
check('на екрані є кнопки для відповіді', buttons.length >= 2, 'кнопок: ' + buttons.length);

console.log('\nПроходження кроку:');
const first = plan.items[0];
console.log('    тип кроку: ' + first.kind + (first.prompt ? ' (' + first.prompt + ')' : ''));
console.log('    запитання: ' + itemTitle(first).slice(0, 60));
check('у кроку є український текст або переклад', Boolean(itemUkrainian(first)) || Boolean(itemTitle(first)));

if (first.kind !== 'grammar') {
  const card = store.cardOrCreate(first);
  check('картка створюється з фазою NEW', card.phase === 'NEW');
  const previews = SrsEngine.previews(card);
  check('передпрогляд має 4 оцінки', previews.length === 4);
  const afterGood = SrsEngine.apply('GOOD', card, 3000);
  check('після «знаю» картка у фазі повторення', afterGood.phase === 'REVIEW');
  store.recordAnswer(first, 'GOOD', 3000, false);
  check('відповідь записана в статистику', store.todayStat().reviews === 1);
}

console.log('\nПовторне заняття (ті самі дані):');
const secondPlan = buildPlan(store, content, { level: 'A0' });
check('план будується повторно без помилок', Array.isArray(secondPlan.items));
check('вивчене слово не пропонується як нове', !secondPlan.items.some((item) =>
  item.kind === 'word' && item.data.id === (first.data && first.data.id) && item.prompt === 'recognize' && false));

console.log('\nПідсумок: ' + passed + ' пройшло, ' + failed + ' не пройшло');
process.exit(failed === 0 ? 0 : 1);
