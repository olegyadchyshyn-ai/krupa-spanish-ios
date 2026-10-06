// Тимчасова перевірка екранів у Node (не є частиною застосунку).
import { readFileSync, writeFileSync, mkdirSync, rmSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

// Копії екранів з переписаними імпортами: у Node немає index.html,
// тому ../ui.js не резолвиться відносно тимчасової теки.
const tmpDir = '.tmp-views';
rmSync(tmpDir, { recursive: true, force: true });
mkdirSync(tmpDir, { recursive: true });
for (const name of ['words.js', 'word.js', 'grammar.js']) {
  const source = readFileSync('web/js/views/' + name, 'utf8');
  const patched = source.replace(/from '\.\.\/(\w+)\.js'/g, "from '../web/js/$1.js'");
  writeFileSync(tmpDir + '/' + name, patched, 'utf8');
}

class NodeStub {
  constructor(tag, ns) {
    this.tagName = String(tag || 'div').toUpperCase();
    this.ns = ns || null;
    this.childNodes = [];
    this.firstChild = null;
    this.style = {};
    this.dataset = {};
    this.className = '';
    this.value = '';
    this.classList = {
      toggle: () => {},
      add: () => {},
      remove: () => {},
      contains: () => false
    };
    this._attrs = {};
  }
  get children() { return this.childNodes.filter((c) => c instanceof NodeStub); }
  appendChild(child) {
    this.childNodes.push(child);
    this.firstChild = this.childNodes[0] || null;
    child.parentNode = this;
    return child;
  }
  removeChild(child) {
    this.childNodes = this.childNodes.filter((c) => c !== child);
    this.firstChild = this.childNodes[0] || null;
    return child;
  }
  setAttribute(key, value) { this._attrs[key] = String(value); }
  getAttribute(key) { return this._attrs[key] == null ? null : this._attrs[key]; }
  addEventListener(type, fn) {
    this._events = this._events || {};
    (this._events[type] = this._events[type] || []).push(fn);
  }
  fire(type, event) {
    for (const fn of (this._events && this._events[type]) || []) fn(event || {});
  }
  querySelectorAll() { return []; }
}

globalThis.Node = NodeStub;
globalThis.document = {
  createElement: (tag, ns) => new NodeStub(tag, ns),
  createTextNode: (text) => new NodeStub('#text', null).alsoText(text),
  getElementById: () => null,
  head: new NodeStub('head'),
  body: new NodeStub('body'),
  addEventListener: () => {},
  readyState: 'complete'
};
NodeStub.prototype.alsoText = function (text) { this.textContent = String(text); return this; };

const base = 'web/content/';
const read = (name) => JSON.parse(readFileSync(base + name, 'utf8'));
const words = [...read('words.a0.json').words, ...read('words.a1.json').words, ...read('words.a2.json').words];
const grammar = [...read('grammar.a0a1.json').grammar, ...read('grammar.a2.json').grammar];
const byId = (items) => new Map(items.map((item) => [item.id, item]));

const content = {
  words, grammar, sentences: [], exercises: [], listening: [], topics: [], issues: [],
  wordById: byId(words), grammarById: byId(grammar),
  sentenceById: new Map(), exerciseById: new Map(), listeningById: new Map(), topicById: new Map()
};

const cards = {};
const store = {
  profile: { level: 'A0' },
  settings: { showPronunciationHints: true, showIpa: true, autoPlayAudio: true },
  card: (id) => cards[id] || null,
  cardOrCreate(item) {
    const id = item.data.id;
    if (!cards[id]) {
      cards[id] = {
        itemId: id, itemType: 'WORD', phase: 'REVIEW', intervalDays: 30, intervalMinutes: 0,
        ease: 2.5, repetitions: 3, lapses: 0, totalReviews: 6, correctReviews: 5,
        suspended: false, dueAt: Date.now()
      };
    }
    return cards[id];
  },
  upsertCard: (cardItem) => { cards[cardItem.itemId] = cardItem; },
  setSuspended(id, value) { if (cards[id]) cards[id].suspended = value; }
};

const spoken = [];
const app = {
  content,
  store,
  level: 'A0',
  speak: (text) => spoken.push(text),
  navigate: (hash) => spoken.push('nav:' + hash),
  refresh: () => {},
  toast: () => {}
};

const { renderWords } = await import(pathToFileURL(tmpDir + '/words.js').href);
const { renderWord } = await import(pathToFileURL(tmpDir + '/word.js').href);
const { renderGrammarList, renderGrammarDetail } = await import(pathToFileURL(tmpDir + '/grammar.js').href);
const { SrsEngine } = await import(pathToFileURL('web/js/store.js').href);

function count(node) {
  let total = 1;
  for (const child of node.childNodes) {
    if (child instanceof NodeStub) total += count(child);
  }
  return total;
}

function texts(node, out = []) {
  if (node.textContent && !node.childNodes.length) out.push(node.textContent);
  for (const child of node.childNodes) if (child instanceof NodeStub) texts(child, out);
  return out;
}

function findButtons(node, out = []) {
  if (node.tagName === 'BUTTON') out.push(node);
  for (const child of node.childNodes) if (child instanceof NodeStub) findButtons(child, out);
  return out;
}

const report = [];
const wordsView = renderWords(app, { level: 'A1' });
report.push('renderWords(A1): ' + count(wordsView) + ' вузлів');
const wordsButtons = findButtons(wordsView);
report.push('кнопок: ' + wordsButtons.length);
const showMore = wordsButtons.filter((b) => texts(b, []).includes('Показати ще'));
report.push('«Показати ще»: ' + showMore.length);
if (showMore.length) {
  showMore[0]._listeners = null;
}
// Клік по «Показати ще» та фільтрах робимо напряму через повторний рендер.
report.push('renderWords() без параметрів: ' + count(renderWords(app, {})) + ' вузлів');

const word = content.wordById.get('w_a0_hola');
cards[word.id] = {
  itemId: word.id, itemType: 'WORD', phase: 'REVIEW', intervalDays: 30, intervalMinutes: 0,
  ease: 2.5, repetitions: 4, lapses: 1, totalReviews: 6, correctReviews: 5, suspended: false
};
const wordView = renderWord(app, { id: word.id });
report.push('renderWord(існує): ' + count(wordView) + ' вузлів');
report.push('renderWord(немає): ' + renderWord(app, { id: 'nope' }).childNodes.length + ' дочірніх в emptyState');
cards[word.id].suspended = true;
report.push('renderWord(призупинено): ' + count(renderWord(app, { id: word.id })) + ' вузлів');
delete cards[word.id];
report.push('renderWord(без картки): ' + count(renderWord(app, { id: word.id })) + ' вузлів');

const grammarList = renderGrammarList(app);
report.push('renderGrammarList: ' + count(grammarList) + ' вузлів, кнопок ' + findButtons(grammarList).length);
const note = content.grammarById.get('g_a0_articles');
const detail = renderGrammarDetail(app, { id: note.id });
report.push('renderGrammarDetail(' + note.id + '): ' + count(detail) + ' вузлів');
report.push('renderGrammarDetail(немає): ' + count(renderGrammarDetail(app, { id: 'nope' })) + ' вузлів');

// Перевірка, що теги в картці слова ведуть на існуючі правила.
let brokenTags = 0;
for (const item of content.words) {
  for (const tag of item.grammarTags || []) {
    if (!grammar.some((g) => g.tag === tag)) brokenTags += 1;
  }
}
report.push('тегів без правила: ' + brokenTags);
report.push('слів усього: ' + words.length + ', правил: ' + grammar.length);

// MARK: Перевірка взаємодії

function walk(node, out = []) {
  out.push(node);
  for (const child of node.childNodes) if (child instanceof NodeStub) walk(child, out);
  return out;
}

function finded(node, predicate) {
  return walk(node).filter(predicate);
}

try {

const byClass = (node, cls) => finded(node, (n) =>
  String(n.className || n._attrs.class || '').split(' ').includes(cls));
const byText = (node, text) => finded(node, (n) =>
  n.tagName === 'BUTTON' && Array.prototype.some.call(walk(n), (c) => c.textContent === text));

const view = renderWords(app, { level: 'A0' });
const input = finded(view, (n) => n.tagName === 'INPUT')[0];
const posChips = byClass(view, 'chip');
report.push('чипів частин мови: ' + posChips.length);
report.push('діагностика класів: ' + walk(view).slice(0, 60).map((n) => n.tagName + '[' + (n.className || n._attrs.class || '') + ']').join(' '));
report.push('усього вузлів у дереві: ' + walk(view).length + ', list-item: ' + byClass(view, 'list-item').length + ', segmented-item: ' + byClass(view, 'segmented-item').length);
report.push('тексти кнопок: ' + findButtons(view).slice(0, 25).map((b) => texts(b, []).join('|')).join(' / '));

// 1. Пошук іспанською без діакритики.
input.value = 'dias';
input.fire('input', {});
report.push('пошук «dias» → слів у списку: ' + byClass(view, 'list-item').length);
input.value = 'доброго';
input.fire('input', {});
report.push('пошук «доброго» → слів у списку: ' + byClass(view, 'list-item').length);
input.value = '';
input.fire('input', {});
report.push('пошук порожній → слів у списку: ' + byClass(view, 'list-item').length);

// 2. Чип «Іменник».
const nounChip = posChips.find((c) => texts(c, []).join('') === 'Іменник');
nounChip.fire('click', {});
const nounCount = byClass(view, 'list-item').length;
const nounAll = words.filter((w) => w.level === 'A0' && w.partOfSpeech === 'noun').length;
report.push('чип «Іменник»: у списку ' + nounCount + ' (у контенті ' + nounAll + ')');

// 3. Фільтр вивченості.
const learnedCount = byClass(view, 'list-item').length;
report.push('діагностика: текстових вузлів «Ще не вчилися» = ' +
  finded(view, (n) => n.textContent === 'Ще не вчилися').length + ', byText = ' + byText(view, 'Ще не вчилися').length);
report.push('segmented-item тексти: ' + byClass(view, 'segmented-item').map((b) => texts(b, []).join('')).join('<'));
byText(view, 'Ще не вчилися')[0].fire('click', {});
report.push('«Ще не вчилися»: ' + byClass(view, 'list-item').length + ' (без карток — усі)');

// 4. «Показати ще».
const fresh = renderWords(app, { level: 'A0' });
const before = byClass(fresh, 'list-item').length;
byText(fresh, 'Показати ще')[0].fire('click', {});
const after = byClass(fresh, 'list-item').length;
report.push('«Показати ще»: було ' + before + ', стало ' + after);

// 5. Порожній результат.
const empty = renderWords(app, { level: 'A0' });
const emptyInput = finded(empty, (n) => n.tagName === 'INPUT')[0];
emptyInput.value = 'zzzzqqq';
emptyInput.fire('input', {});
report.push('порожній пошук → emptyState: ' + byClass(empty, 'empty-state').length);

// 6. Клік по слову та по кнопці озвучення.
const click = renderWords(app, { level: 'A0' });
byClass(click, 'list-item')[0].fire('click', {});
const iconButtons = byClass(click, 'icon-btn');
iconButtons[0].fire('click', {});
report.push('клік по слову: ' + spoken.filter((s) => String(s).startsWith('nav:')).length +
  ', озвучень: ' + spoken.filter((s) => !String(s).startsWith('nav:')).length);

// 7. Рід «mf».
const mfWord = words.find((w) => w.gender === 'mf');
if (mfWord) report.push('рід mf («' + mfWord.spanish + '»): ' + (renderWord(app, { id: mfWord.id }) ? 'ок' : 'збій'));

// 8. Усі картки слів і правил рендеряться без винятків.
let wordFails = 0;
let grammarFails = 0;
for (const item of words) { try { renderWord(app, { id: item.id }); } catch (error) { wordFails += 1; } }
for (const item of grammar) { try { renderGrammarDetail(app, { id: item.id }); } catch (error) { grammarFails += 1; } }
report.push('помилок рендеру: слова ' + wordFails + ', правила ' + grammarFails);

// 9. Порівняння з SrsEngine.isLearned.
report.push('learnedCount у фільтрі: ' + learnedCount + ', isLearned-карток: ' + Object.keys(cards).length);

// 10. Фільтр «Засвоєні» з реальними картками.
const learnedTarget = words.filter((w) => w.level === 'A0').slice(0, 5);
let learnedHits = 0;
for (const item of learnedTarget) {
  cards[item.id] = {
    itemId: item.id, itemType: 'WORD', phase: 'REVIEW', intervalDays: 30, intervalMinutes: 0,
    ease: 2.5, repetitions: 4, lapses: 0, totalReviews: 5, correctReviews: 5, suspended: false
  };
  if (SrsEngine.isLearned(cards[item.id])) learnedHits += 1;
}
const learnedView = renderWords(app, { level: 'A0' });
byText(learnedView, 'Засвоєні')[0].fire('click', {});
report.push('фільтр «Засвоєні»: у списку ' + byClass(learnedView, 'list-item').length + ' (карток засвоєно: ' + learnedHits + ')');
report.push('позначка ✅ у підрядку: ' + finded(learnedView, (n) => String(n.textContent || '').includes('✅')).length);
report.push('кнопок озвучення у списку: ' + byClass(learnedView, 'icon-btn').length);

// 11. Список граматики: рівні та пошук.
const gv = renderGrammarList(app);
report.push('граматика A0: ' + byClass(gv, 'list-item').length + ' правил');
byText(gv, 'A2')[0].fire('click', {});
report.push('граматика A2: ' + byClass(gv, 'list-item').length + ' правил');
byText(gv, 'Усі')[0].fire('click', {});
const gInput = finded(gv, (n) => n.tagName === 'INPUT')[0];
gInput.value = 'artículo';
gInput.fire('input', {});
report.push('пошук «artículo»: ' + byClass(gv, 'list-item').length + ' правил');
gInput.value = 'артикл';
gInput.fire('input', {});
report.push('пошук «артикл»: ' + byClass(gv, 'list-item').length + ' правил');
gInput.value = 'zzz';
gInput.fire('input', {});
report.push('порожній пошук граматики → emptyState: ' + byClass(gv, 'empty-state').length);
gInput.value = '';
gInput.fire('input', {});
byClass(gv, 'list-item')[0].fire('click', {});
report.push('перехід із правила: ' + spoken.filter((s) => String(s).startsWith('nav:#/grammar/')).length);

// 12. Кнопки на картці слова.
const wv = renderWord(app, { id: learnedTarget[0].id });
const wButtons = findButtons(wv).map((b) => texts(b, []).join(''));
report.push('кнопки картки слова: ' + wButtons.filter((t) => t).join(' | '));
const pause = findButtons(wv).find((b) => texts(b, []).join('') === 'Призупинити');
pause.fire('click', {});
report.push('після «Призупинити»: suspended=' + cards[learnedTarget[0].id].suspended);
const resumeView = renderWord(app, { id: learnedTarget[0].id });
report.push('кнопка «Відновити»: ' + findButtons(resumeView).some((b) => texts(b, []).join('') === 'Відновити'));
const dueButton = findButtons(resumeView).find((b) => texts(b, []).join('').indexOf('Додати до повторення') >= 0);
const dueBefore = cards[learnedTarget[0].id].dueAt;
cards[learnedTarget[0].id].dueAt = 0;
dueButton.fire('click', {});
report.push('«Додати до повторення зараз»: dueAt ' + (cards[learnedTarget[0].id].dueAt > 0 ? 'оновлено' : 'не оновлено') + ' (було ' + dueBefore + ')');

// 13. Інфобокси з тонами.
const detailHtml = finded(renderGrammarDetail(app, { id: 'g_a0_articles' }),
  (n) => String(n.className || '').indexOf('info-') >= 0).map((n) => n.className);
report.push('info-тони в правилі: ' + detailHtml.join(', '));
report.push('кнопка «Тренувати вимову»: ' + findButtons(renderWord(app, { id: learnedTarget[0].id })).some((b) => texts(b, []).join('') === 'Тренувати вимову'));

} catch (error) {
  report.push('ПОМИЛКА ТЕСТУ: ' + error.message + '\n' + error.stack);
}

rmSync(tmpDir, { recursive: true, force: true });
console.log(report.join('\n'));
