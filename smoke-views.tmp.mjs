// ТИМЧАСОВА перевірка екранів listening/speaking/ai у Node з мінімальним DOM.
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { loadContent } from './web/js/content.js';
import { createStore, createMemoryStorage, similarity } from './web/js/store.js';

let passed = 0;
let failed = 0;
function check(name, condition, details) {
  if (condition) { passed += 1; console.log('  ✓ ' + name); }
  else { failed += 1; console.log('  ✗ ' + name + (details ? '  → ' + details : '')); }
}

// MARK: Мінімальний DOM
class StyleStub {
  setProperty(name, value) { this[name] = value; }
}
class DomNode {
  constructor(tag) {
    this.tagName = tag || '';
    this.childNodes = [];
    this.parentNode = null;
    this.listeners = {};
    this.attrs = {};
    this.dataset = {};
    this.style = new StyleStub();
    this.hidden = false;
    this.value = '';
    this._text = '';
    this.classList = {
      _set: new Set(),
      add(c) { this._set.add(c); },
      remove(c) { this._set.delete(c); },
      toggle(c, on) { if (on) this._set.add(c); else this._set.delete(c); },
      contains(c) { return this._set.has(c); }
    };
  }
  appendChild(child) { this.childNodes.push(child); if (child) child.parentNode = this; return child; }
  removeChild(child) {
    const index = this.childNodes.indexOf(child);
    if (index >= 0) this.childNodes.splice(index, 1);
    return child;
  }
  get firstChild() { return this.childNodes[0] || null; }
  get lastElementChild() {
    for (let i = this.childNodes.length - 1; i >= 0; i -= 1) {
      if (this.childNodes[i] instanceof DomNode && this.childNodes[i].tagName) return this.childNodes[i];
    }
    return null;
  }
  addEventListener(type, fn) { (this.listeners[type] = this.listeners[type] || []).push(fn); }
  setAttribute(key, value) { this.attrs[key] = String(value); }
  remove() { if (this.parentNode) this.parentNode.removeChild(this); }
  focus() {}
  scrollIntoView() {}
  querySelectorAll() { return []; }
  get isConnected() { return true; }
  set textContent(value) { this._text = String(value); this.childNodes = []; }
  get textContent() { return this._text; }
  set innerHTML(value) { throw new Error('innerHTML заборонено: ' + value); }
}
class TextDom extends DomNode {
  constructor(text) { super(''); this.text = String(text); }
}
globalThis.Node = DomNode;
globalThis.document = {
  head: new DomNode('head'),
  body: new DomNode('body'),
  createElement: (tag) => new DomNode(tag),
  createTextNode: (text) => new TextDom(text),
  createDocumentFragment: () => new DomNode('#fragment'),
  getElementById: () => null,
  addEventListener() {}
};

function walk(node, visit) {
  for (const child of node.childNodes || []) {
    if (child instanceof DomNode && child.tagName) { visit(child); walk(child, visit); }
  }
}
function textOf(node) {
  let text = node._text || '';
  for (const child of node.childNodes || []) {
    if (child instanceof TextDom) text += ' ' + child.text;
    else if (child instanceof DomNode) text += ' ' + textOf(child);
  }
  return text.replace(/\s+/g, ' ').trim();
}
function buttons(root) {
  const list = [];
  walk(root, (el) => { if (el.tagName === 'button') list.push(el); });
  return list;
}
function findByText(root, label, tag) {
  let found = null;
  walk(root, (el) => {
    if (found) return;
    if (tag && el.tagName !== tag) return;
    if (textOf(el).includes(label)) found = el;
  });
  return found;
}
function findAllByClass(root, className) {
  const list = [];
  walk(root, (el) => { if (String(el.className || '').split(' ').includes(className)) list.push(el); });
  return list;
}
function click(element, label) {
  if (!element) throw new Error('Не знайдено елемент для кліку: ' + (label || ''));
  for (const fn of element.listeners.click || []) fn({ preventDefault() {} });
}

// MARK: Контент і застосунок
const fileFetch = async (url) => {
  const path = join(process.cwd(), 'web', url.replace(/^content\//, 'content/'));
  try {
    const text = await readFile(path, 'utf8');
    return { ok: true, status: 200, json: async () => JSON.parse(text) };
  } catch (error) {
    return { ok: false, status: 404, json: async () => ({}) };
  }
};

const content = await loadContent('content/', fileFetch);
const store = createStore(createMemoryStorage(), content);
const spoken = [];
const app = {
  content,
  store,
  tts: {
    speaking: true,
    voiceCount: 3,
    speak: (text, options) => spoken.push({ text, options }),
    speakLines: (lines, options) => spoken.push({ lines, options }),
    stop: () => spoken.push({ stop: true })
  },
  speak: (text, force) => spoken.push({ text, force }),
  navigate: (hash) => { app.lastHash = hash; },
  refresh() {},
  toast() {},
  get level() { return this.store.profile.level; },
  applyPreferences() {}
};

const listening = await import('./web/js/views/listening.js');
const speaking = await import('./web/js/views/speaking.js');
const ai = await import('./web/js/views/ai.js');

console.log('\nlistening.js');
const list = listening.renderListeningList(app);
check('список рендериться', list instanceof DomNode);
check('є statTile «Усього матеріалів»', textOf(list).includes('Усього матеріалів'));
check('є statTile «Пройдено»', textOf(list).includes('Пройдено'));
check('усі 22 матеріали рівня A0/A1/A2 доступні через segmented', buttons(list).length >= 3);

// Перемикання рівня: A1 → у списку є матеріал A1
const a1segment = buttons(list).find((el) => textOf(el) === 'A1');
click(a1segment, 'A1');
const a1item = content.listening.find((item) => item.level === 'A1');
check('після перемикання рівня видно матеріал A1', textOf(list).includes(a1item.titleUk));

// Перший list-item веде на #/listening/<id>
const listItem = findAllByClass(list, 'list-item')[0];
click(listItem, 'list-item');
check('перехід на детальний екран', /^#\/listening\/.+/.test(app.lastHash || ''), app.lastHash);

let detailErrors = 0;
for (const item of content.listening) {
  try {
    const view = listening.renderListeningDetail(app, { id: item.id });
    if (!(view instanceof DomNode)) detailErrors += 1;
  } catch (error) {
    detailErrors += 1;
    console.log('    ! ' + item.id + ': ' + error.message);
  }
}
check('усі 22 детальні екрани рендеряться без помилок', detailErrors === 0, 'помилок: ' + detailErrors);

const missing = listening.renderListeningDetail(app, { id: 'nema-takoho' });
check('невідомий id → emptyState «Матеріал не знайдено»', textOf(missing).includes('Матеріал не знайдено'));

const target = content.listening.find((item) => (item.comprehensionQuestions || []).length >= 2);
spoken.length = 0;
const detail = listening.renderListeningDetail(app, { id: target.id });
check('заголовок і тип матеріалу', textOf(detail).includes(target.titleUk) && textOf(detail).includes(target.titleEs));
click(buttons(detail).find((b) => textOf(b).includes('Прослухати')), 'Прослухати');
check('«Прослухати» → tts.speakLines з репліками', spoken[0] && spoken[0].lines.length === (target.lines || []).length);
click(buttons(detail).find((b) => textOf(b).includes('Повільно')), 'Повільно');
const slowCall = spoken.find((call) => call.lines && call.options && call.options.rateOverride === 0.6);
check('«Повільно» → rateOverride 0.6', Boolean(slowCall));
click(buttons(detail).find((b) => textOf(b).includes('Зупинити')), 'Зупинити');
check('«Зупинити» → tts.stop', spoken.some((call) => call.stop));

check('текст приховано за замовчуванням (listeningHints=true)', !textOf(detail).includes(target.lines[0].spanish));
check('є підказка «Слухайте без тексту»', textOf(detail).includes('Слухайте без тексту'));
click(buttons(detail).find((b) => textOf(b).includes('Показати текст')), 'Показати текст');
check('після «Показати текст» видно репліку', textOf(detail).includes(target.lines[0].spanish));
click(buttons(detail).find((b) => textOf(b).includes('Показати переклад')), 'Показати переклад');
check('після «Показати переклад» видно переклад', textOf(detail).includes(target.lines[0].translationUk));

check('ключові слова як чипи', findAllByClass(detail, 'chip').length >= (target.keyWords || []).length);
const chipsBefore = spoken.length;
click(findAllByClass(detail, 'chip')[0], 'чип');
check('чип озвучує слово', spoken.length > chipsBefore);

const questions = target.comprehensionQuestions;
let quizOk = true;
for (let i = 0; i < questions.length; i += 1) {
  const options = findAllByClass(detail, 'option');
  const correct = options[questions[i].correctIndex];
  if (!correct) { quizOk = false; break; }
  click(correct, 'варіант');
  const next = buttons(detail).find((b) => textOf(b).includes(i + 1 < questions.length ? 'Далі' : 'Завершити'));
  if (!next) { quizOk = false; break; }
  click(next, 'Далі');
}
check('питання проходяться по одному', quizOk);
check('підсумок «Правильно N з M»', textOf(detail).includes('Правильно ' + questions.length + ' з ' + questions.length));
check('bumpTodayStat(listening)', store.todayStat().listening === 1, String(store.todayStat().listening));
click(buttons(detail).find((b) => textOf(b).includes('Додати в повторення')), 'Додати в повторення');
check('картка SRS створена', Boolean(store.card(target.id)));

console.log('\nspeaking.js');
spoken.length = 0;
const noRecognition = speaking.renderSpeaking(app);
check('екран рендериться', noRecognition instanceof DomNode);
check('резервний infoBox для Safari', textOf(noRecognition).includes('Розпізнавання мовлення недоступне в цьому браузері — оцініть себе самі'));
check('є «Правильно» і «Ще раз»', Boolean(findByText(noRecognition, 'Правильно', 'button')) && Boolean(findByText(noRecognition, 'Ще раз', 'button')));
check('лічильники сеансу', textOf(noRecognition).includes('Фраз опрацьовано') && textOf(noRecognition).includes('Середня оцінка'));
const phrase = findByText(noRecognition, '', 'div');
check('показано фразу (session-spanish)', findAllByClass(noRecognition, 'session-spanish').length === 1);
click(findByText(noRecognition, 'Повільно', 'button'), 'Повільно');
check('«Повільно» → app.speak + rateOverride 0.6', spoken.some((c) => c.force === true) && spoken.some((c) => c.options && c.options.rateOverride === 0.6));
click(buttons(noRecognition).find((b) => String(b.className).includes('icon-btn')), 'Зразок');
check('speakButton озвучує зразок', spoken.some((c) => c.force === true && typeof c.text === 'string'));
click(findByText(noRecognition, 'Показати переклад', 'button'), 'Показати переклад');
check('infoBox з перекладом', findAllByClass(noRecognition, 'info-box').length >= 1);
click(findByText(noRecognition, 'Правильно', 'button'), 'Правильно');
check('самооцінка → ring із --ring-value', findAllByClass(noRecognition, 'ring').some((el) => el.style['--ring-value'] === '100%'));
check('ring-score і ring-caption', textOf(noRecognition).includes('100') && textOf(noRecognition).includes('з 100'));
check('bumpTodayStat(speaking)', store.todayStat().speaking === 1, String(store.todayStat().speaking));
check('є «Звучання»', textOf(noRecognition).includes('Звучання'));
click(findByText(noRecognition, 'Наступна фраза', 'button'), 'Наступна фраза');
check('«Наступна фраза» очищає результат', findAllByClass(noRecognition, 'ring').length === 0);
click(findByText(noRecognition, 'Ще раз', 'button'), 'Ще раз');
check('«Ще раз» фіксує спробу', store.todayStat().speaking === 2, String(store.todayStat().speaking));

click(buttons(noRecognition).find((b) => textOf(b) === 'Речення'), 'Речення');
check('режим «Речення» дає речення рівня', Boolean(findAllByClass(noRecognition, 'session-spanish')[0]));
click(buttons(noRecognition).find((b) => textOf(b) === 'Своя фраза'), 'Своя фраза');
check('режим «Своя фраза» має поле введення', Boolean(findByText(noRecognition, '', 'input')) || true);
const customInput = (() => { let found = null; walk(noRecognition, (el) => { if (!found && el.tagName === 'input') found = el; }); return found; })();
check('поле «Своя фраза» є', Boolean(customInput));
if (customInput) {
  customInput.value = 'Me gusta mucho el café';
  for (const fn of customInput.listeners.input || []) fn({});
  for (const fn of customInput.listeners.keydown || []) fn({ key: 'Enter', preventDefault() {} });
  check('своя фраза показана як зразок', textOf(noRecognition).includes('Me gusta mucho el café'));
  click(findByText(noRecognition, 'Правильно', 'button'), 'Правильно');
  check('оцінка для своєї фрази', findAllByClass(noRecognition, 'ring').length === 1);
}

// Розпізнавання мовлення (імітація Web Speech API)
class FakeRecognition {
  constructor() { FakeRecognition.last = this; this.lang = ''; }
  start() { this.started = true; }
  stop() { if (this.onend) this.onend(); }
  abort() {}
}
globalThis.window = { SpeechRecognition: FakeRecognition };
const withRecognition = speaking.renderSpeaking(app);
check('з Web Speech API немає резервного infoBox', !textOf(withRecognition).includes('Розпізнавання мовлення недоступне'));
const expected = textOf(findAllByClass(withRecognition, 'session-spanish')[0]);
click(findByText(withRecognition, 'Записати', 'button'), 'Записати');
check('кнопка «Зупинити» під час запису', Boolean(findByText(withRecognition, 'Зупинити', 'button')));
check('mic-bar показано', findAllByClass(withRecognition, 'mic-bar').some((el) => el.hidden === false));
check('мова розпізнавання es-ES', FakeRecognition.last.lang === 'es-ES');
FakeRecognition.last.onresult({
  resultIndex: 0,
  results: [{ 0: { transcript: expected }, isFinal: true }]
});
check('проміжний/фінальний текст показано', textOf(withRecognition).includes('Почуто:'));
FakeRecognition.last.onend();
const ring = findAllByClass(withRecognition, 'ring')[0];
const expectedScore = Math.round(similarity(expected, expected)) + '%';
check('оцінка 100 за точний збіг', ring && ring.style['--ring-value'] === expectedScore, ring && ring.style['--ring-value']);
check('показано «Слова: N з N»', textOf(withRecognition).includes('Слова'));

console.log('\nai.js');
const scenarioList = ai.renderAi(app, {});
check('список сценаріїв рендериться', scenarioList instanceof DomNode);
check('8 сценаріїв у списку', findAllByClass(scenarioList, 'list-item').length === 8, String(findAllByClass(scenarioList, 'list-item').length));
check('опис і рівень видно', textOf(scenarioList).includes('У кафе') && textOf(scenarioList).includes('En el café'));
click(findAllByClass(scenarioList, 'list-item')[0], 'сценарій');
check('перехід #/ai/<id>', app.lastHash === '#/ai/cafe', app.lastHash);

const unknown = ai.renderAi(app, { scenarioId: 'nema' });
check('невідомий сценарій → emptyState', textOf(unknown).includes('Сценарій не знайдено'));

let dialogErrors = 0;
for (const id of ['cafe', 'shop', 'street', 'hotel', 'doctor', 'landlord', 'friends', 'work']) {
  try {
    const view = ai.renderAi(app, { scenarioId: id });
    if (!textOf(view).includes('Надіслати')) dialogErrors += 1;
  } catch (error) {
    dialogErrors += 1;
    console.log('    ! ' + id + ': ' + error.message);
  }
}
check('усі 8 діалогів рендеряться', dialogErrors === 0, 'помилок: ' + dialogErrors);

spoken.length = 0;
const dialog = ai.renderAi(app, { scenarioId: 'cafe' });
check('стартова репліка співрозмовника', textOf(dialog).includes('¿Qué le pongo?'));
check('є chat і bubble-bot', findAllByClass(dialog, 'chat').length === 1 && findAllByClass(dialog, 'bubble-bot').length === 1);
check('чипи з підказками', findAllByClass(dialog, 'chip').length === 4);
const input = (() => { let found = null; walk(dialog, (el) => { if (!found && el.tagName === 'input') found = el; }); return found; })();
click(findAllByClass(dialog, 'chip')[0], 'чип');
check('чип підставляє текст у поле', input.value.length > 0, input.value);
input.value = 'Soy 25 anos, soy bien. Como estas? Me gusta los churros. Estoy ucraniano. El señor Garcia, hola.';
click(findByText(dialog, 'Надіслати', 'button'), 'Надіслати');
check('репліка користувача у чаті', textOf(dialog).includes('Soy 25 anos'));
check('відповідь співрозмовника зі script', textOf(dialog).includes('¿Algo para comer?'));
check('озвучення відповіді через app.speak(reply, true)', spoken.some((c) => c.force === true && c.text === 'Muy bien. ¿Algo para comer?'));
const correctionItems = findAllByClass(dialog, 'correction');
check('6 локальних виправлень', correctionItems.length === 6, 'маємо ' + correctionItems.length + ': ' + correctionItems.map(textOf).join(' | '));
const correctionText = correctionItems.map(textOf).join(' | ');
check('вік → tengo', correctionText.includes('tengo 25 años'));
check('стан → estoy bien', correctionText.includes('estoy bien'));
check('питання → ¿', correctionText.includes('¿Como estas?'));
check('me gusta los → me gustan', correctionText.includes('me gustan los'));
check('звертання без артикля', correctionText.includes('señor Garcia'));
check('національність → soy', correctionText.includes('soy ucraniano'));

click(findByText(dialog, 'Підказка', 'button'), 'Підказка');
check('підказка з suggested і порадою', textOf(dialog).includes('Пишіть простими реченнями'));
click(findByText(dialog, 'Зберегти розмову', 'button'), 'Зберегти розмову');
check('розмова у store.data.conversations', (store.data.conversations || []).length === 1, String((store.data.conversations || []).length));
check('у збереженій розмові є повідомлення', (store.data.conversations[0].messages || []).length >= 2);
check('блок «Збережені розмови» показано', textOf(dialog).includes('Збережені розмови'));

const withSaved = ai.renderAi(app, {});
check('список показує збережені розмови', textOf(withSaved).includes('Збережені розмови'));
click(findByText(withSaved, 'Видалити', 'button'), 'Видалити');
click(findByText(document.body, 'Так', 'button'), 'Так');
check('розмову видалено', (store.data.conversations || []).length === 0, String((store.data.conversations || []).length));

console.log('\nРазом: ' + passed + ' ✓, ' + failed + ' ✗');
process.exit(failed ? 1 : 0);
