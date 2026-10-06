// Екран «Слова»: рівень, пошук, фільтри, зведення та список слів.
//
// Уся робота з DOM — усередині renderWords; на верхньому рівні модуля лише
// сталі та чистий стан. Контракт: CONTRACT.md, розділ 1.

import {
  h, clear, card, sectionHeader, button, speakButton, chip, emptyState,
  infoBox, levelBadge, progressBar, field
} from '../ui.js';

import {
  wordsOfLevel, normalizeLoose, stripAccents
} from '../content.js';

import { SrsEngine, PHASES } from '../store.js';

const LEVELS = ['A0', 'A1', 'A2'];

const PAGE_SIZE = 100;

/** Частини мови контенту → підпис і чип фільтра. */
const POS_GROUPS = [
  { id: 'all', label: 'Усі', match: null },
  { id: 'noun', label: 'Іменник', match: ['noun'] },
  { id: 'verb', label: 'Дієслово', match: ['verb'] },
  { id: 'phrase', label: 'Фраза', match: ['phrase'] },
  { id: 'adjective', label: 'Прикметник', match: ['adjective'] },
  { id: 'numeral', label: 'Числівник', match: ['numeral'] },
  { id: 'adverb', label: 'Прислівник', match: ['adverb'] },
  {
    id: 'other',
    label: 'Інші',
    match: ['pronoun', 'interjection', 'preposition']
  }
];

const POS_LABELS = {
  noun: 'іменник',
  verb: 'дієслово',
  phrase: 'фраза',
  adjective: 'прикметник',
  numeral: 'числівник',
  adverb: 'прислівник',
  pronoun: 'займенник',
  interjection: 'вигук',
  preposition: 'прийменник'
};

const GENDER_LABELS = {
  m: 'чоловічий рід',
  f: 'жіночий рід',
  mf: 'ч. / ж. рід',
  none: ''
};

const LEARN_FILTERS = [
  { id: 'all', label: 'Усі' },
  { id: 'learned', label: 'Засвоєні' },
  { id: 'new', label: 'Ще не вчилися' }
];

/** Стан екрана (скидається при кожному відкритті розділу «Слова»). */
const state = {
  level: null,
  query: '',
  pos: 'all',
  learn: 'all',
  limit: PAGE_SIZE
};

// MARK: - Хелпери подання

/** Іспанське слово з артиклем, якщо він потрібен. */
function withArticle(word) {
  if (!word.withArticle) return word.spanish;
  if (word.gender === 'm') return 'el ' + word.spanish;
  if (word.gender === 'f') return 'la ' + word.spanish;
  return word.spanish;
}

function posLabel(word) {
  return POS_LABELS[word.partOfSpeech] || word.partOfSpeech || 'слово';
}

function genderLabel(word) {
  return GENDER_LABELS[word.gender] || '';
}

/** Нормалізований рядок для пошуку: без регістру, пунктуації та діакритики. */
function searchKey(text) {
  return stripAccents(normalizeLoose(text)).replace(/\s+/g, '');
}

function matchesQuery(word, key) {
  if (!key) return true;
  const spanish = searchKey(word.spanish) + ' ' + searchKey(withArticle(word));
  const ukrainian = searchKey(word.translationUk);
  return spanish.indexOf(key) >= 0 || ukrainian.indexOf(key) >= 0;
}

function matchesPos(word, posId) {
  const group = POS_GROUPS.find((item) => item.id === posId);
  if (!group || !group.match) return true;
  return group.match.indexOf(word.partOfSpeech) >= 0;
}

function isLearned(store, id) {
  const cardItem = store.card(id);
  return Boolean(cardItem && SrsEngine.isLearned(cardItem));
}

function matchesLearn(store, word, learnId) {
  if (learnId === 'learned') return isLearned(store, word.id);
  if (learnId === 'new') return !isLearned(store, word.id);
  return true;
}

/** Заголовок рядка: іспанське слово + переклад. */
function rowTitle(word) {
  return h('div', {}, [
    h('div', { class: 'word-es', text: withArticle(word) }),
    h('div', { class: 'word-uk', text: word.translationUk })
  ]);
}

/** Підрядок: частина мови, рід, позначки засвоєння й призупинення. */
function rowSub(word, learned, suspended) {
  const parts = [];
  if (learned) parts.push('✅ засвоєно');
  if (suspended) parts.push('⏸ призупинено');
  parts.push(posLabel(word));
  const gender = genderLabel(word);
  if (gender) parts.push(gender);
  return h('div', { class: 'list-sub', text: parts.join(' · ') });
}

// MARK: - Блоки екрана

function levelSelector(current, onPick) {
  const items = LEVELS.map((level) => h('button', {
    class: 'segmented-item' + (level === current ? ' active' : ''),
    type: 'button',
    text: level,
    onclick: () => onPick(level)
  }));
  return h('div', { class: 'segmented' }, items);
}

function learnSelector(current, onPick) {
  const items = LEARN_FILTERS.map((option) => h('button', {
    class: 'segmented-item' + (option.id === current ? ' active' : ''),
    type: 'button',
    text: option.label,
    onclick: () => onPick(option.id)
  }));
  return h('div', { class: 'segmented' }, items);
}

function summaryBlock(total, learned) {
  const fraction = total ? learned / total : 0;
  return card([
    sectionHeader('Словник рівня', 'За частотою вживання', '🔤'),
    h('div', { class: 'list-sub', text: 'Усього слів: ' + total + ' · засвоєно: ' + learned }),
    progressBar(fraction)
  ]);
}

function emptyStateFor(query, pos, learn) {
  const hasFilter = Boolean(normalizeLoose(query)) || pos !== 'all' || learn !== 'all';
  const message = hasFilter
    ? 'Змініть фільтр або пошуковий запит.'
    : 'На цьому рівні контент ще не завантажено.';
  return emptyState('Слів не знайдено', message);
}

// MARK: - Рендер

/** Екран словника: `#/words` або `#/words/A1`. */
export function renderWords(app, params) {
  const options = params || {};
  const requested = options.level || app.store.profile.level;
  if (state.level !== requested) state.limit = PAGE_SIZE;
  state.level = LEVELS.indexOf(requested) >= 0 ? requested : app.store.profile.level;
  state.query = '';
  state.pos = 'all';
  state.learn = 'all';

  const root = h('div', { class: 'stack' });
  const levelSlot = h('div', {});
  const content = h('div', { class: 'stack' });
  const summarySlot = h('div', {});
  const resultsSlot = h('div', { class: 'stack' });

  const searchField = field('Пошук іспанською або українською…', {
    value: state.query,
    onInput: (value) => {
      state.query = value || '';
      state.limit = PAGE_SIZE;
      renderResults();
    }
  });

  const posSlot = h('div', { class: 'row' });
  const learnSlot = h('div', {});

  function renderLevels() {
    clear(levelSlot);
    levelSlot.appendChild(levelSelector(state.level, (level) => {
      state.level = level;
      state.limit = PAGE_SIZE;
      renderAll();
    }));
  }

  function renderPosChips() {
    clear(posSlot);
    for (const group of POS_GROUPS) {
      posSlot.appendChild(chip(group.label, {
        active: state.pos === group.id,
        onClick: () => {
          state.pos = group.id;
          state.limit = PAGE_SIZE;
          renderAll();
        }
      }));
    }
  }

  function renderLearn() {
    clear(learnSlot);
    learnSlot.appendChild(learnSelector(state.learn, (id) => {
      state.learn = id;
      state.limit = PAGE_SIZE;
      renderAll();
    }));
  }

  function renderResults() {
    const store = app.store;
    const all = wordsOfLevel(app.content, state.level);
    const key = searchKey(state.query);
    const filtered = all.filter((word) =>
      matchesQuery(word, key) &&
      matchesPos(word, state.pos) &&
      matchesLearn(store, word, state.learn));

    const learned = filtered.filter((word) => isLearned(store, word.id)).length;

    clear(summarySlot);
    summarySlot.appendChild(summaryBlock(filtered.length, learned));

    clear(resultsSlot);

    if (!filtered.length) {
      resultsSlot.appendChild(emptyStateFor(state.query, state.pos, state.learn));
      return;
    }

    resultsSlot.appendChild(sectionHeader(
      'Список слів',
      'Показано ' + Math.min(state.limit, filtered.length) + ' із ' + filtered.length,
      '📄'
    ));

    const list = h('div', { class: 'list' });
    for (const word of filtered.slice(0, state.limit)) {
      const cardItem = store.card(word.id);
      list.appendChild(wordRow(app, word, cardItem));
    }
    resultsSlot.appendChild(list);

    if (filtered.length > state.limit) {
      resultsSlot.appendChild(button('Показати ще', {
        variant: 'secondary',
        className: 'btn-block',
        onClick: () => {
          state.limit += PAGE_SIZE;
          renderResults();
        }
      }));
    }
  }

  function renderAll() {
    renderLevels();
    renderPosChips();
    renderLearn();
    renderResults();
  }

  content.appendChild(summarySlot);
  content.appendChild(searchField);
  content.appendChild(posSlot);
  content.appendChild(learnSlot);
  content.appendChild(resultsSlot);

  root.appendChild(card([
    sectionHeader('Словник', 'Оберіть рівень, знайдіть слово або відфільтруйте за частиною мови', '📚'),
    levelSlot
  ]));
  root.appendChild(content);
  root.appendChild(infoBox(
    'Як читати список',
    'Натисніть на слово, щоб відкрити картку з прикладом, нотатками та прогресом повторень.'
  ));

  renderAll();
  return root;
}

/** Один рядок списку: клікабельна частина та окрема кнопка озвучення. */
function wordRow(app, word, cardItem) {
  const learned = Boolean(cardItem && SrsEngine.isLearned(cardItem));
  const suspended = Boolean(cardItem && cardItem.suspended);
  const phase = cardItem ? (PHASES[cardItem.phase] || cardItem.phase) : null;

  const main = h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => app.navigate('#/word/' + word.id)
  }, [
    h('div', { class: 'row' }, [levelBadge(word.level)]),
    rowTitle(word),
    rowSub(word, learned, suspended),
    phase ? h('div', { class: 'list-sub', text: 'Фаза: ' + phase }) : null
  ]);

  return h('div', { class: 'row' }, [
    h('div', { style: { flex: '1' } }, main),
    speakButton(() => app.speak(word.spanish, true), 'Прослухати: ' + word.spanish)
  ]);
}
