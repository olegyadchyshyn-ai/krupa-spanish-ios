// Екран «Граматика»: список правил (`#/grammar`) і деталі правила
// (`#/grammar/<id>`). Уся робота з DOM — усередині функцій рендеру.

import {
  h, clear, card, sectionHeader, button, speakButton, emptyState, infoBox,
  levelBadge, field
} from '../ui.js';

import {
  grammarOfLevel, wordsWithTag, normalizeLoose, stripAccents
} from '../content.js';

const LEVELS = ['A0', 'A1', 'A2'];

const LEVEL_FILTERS = [
  { id: 'A0', label: 'A0' },
  { id: 'A1', label: 'A1' },
  { id: 'A2', label: 'A2' },
  { id: 'all', label: 'Усі' }
];

/** Обрізає довгий текст, щоб рядок списку лишався читабельним. */
const SUB_LIMIT = 130;

/** Максимум слів у блоці «Слова з цим правилом». */
const WORDS_LIMIT = 20;

/** Стан списку (пошук і рівень не скидаються після повернення з правила). */
const state = {
  level: null,
  query: ''
};

// MARK: - Хелпери подання

function searchKey(text) {
  return stripAccents(normalizeLoose(text)).replace(/\s+/g, '');
}

function truncate(text, limit) {
  const value = String(text == null ? '' : text).trim();
  if (value.length <= limit) return value;
  return value.slice(0, limit - 1).trimEnd() + '…';
}

function matchesQuery(note, key) {
  if (!key) return true;
  const haystack = [
    note.titleUk, note.titleEs, note.tag, note.patternUk
  ].map(searchKey).join(' ');
  return haystack.indexOf(key) >= 0;
}

function levelSelector(current, onPick) {
  const items = LEVEL_FILTERS.map((option) => h('button', {
    class: 'segmented-item' + (option.id === current ? ' active' : ''),
    type: 'button',
    text: option.label,
    onclick: () => onPick(option.id)
  }));
  return h('div', { class: 'segmented' }, items);
}

// MARK: - Список правил

function grammarRow(app, note) {
  return h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => app.navigate('#/grammar/' + note.id)
  }, [
    h('div', { class: 'row' }, [levelBadge(note.level)]),
    h('div', {}, [
      h('div', { class: 'list-title', text: note.titleUk || note.titleEs || note.tag }),
      note.titleEs ? h('div', { class: 'word-es', text: note.titleEs }) : null,
      note.patternUk ? h('div', { class: 'list-sub', text: truncate(note.patternUk, SUB_LIMIT) }) : null
    ])
  ]);
}

/** Список граматичних правил із фільтром рівня та пошуком. */
export function renderGrammarList(app) {
  if (state.level == null) state.level = app.level || app.store.profile.level;
  const root = h('div', { class: 'stack' });
  const levelSlot = h('div', {});
  const summarySlot = h('div', {});
  const listSlot = h('div', { class: 'stack' });

  const searchField = field('Пошук правила…', {
    value: state.query,
    onInput: (value) => {
      state.query = value || '';
      renderList();
    }
  });

  function renderLevels() {
    clear(levelSlot);
    levelSlot.appendChild(levelSelector(state.level, (level) => {
      state.level = level;
      renderLevels();
      renderList();
    }));
  }

  function renderList() {
    const notes = state.level === 'all'
      ? app.content.grammar.slice()
      : grammarOfLevel(app.content, state.level);
    const key = searchKey(state.query);
    const filtered = notes.filter((note) => matchesQuery(note, key));

    clear(summarySlot);
    summarySlot.appendChild(card([
      sectionHeader('Правила', 'Оберіть рівень або знайдіть правило за назвою', '📘'),
      h('div', { class: 'list-sub', text: 'Знайдено: ' + filtered.length })
    ]));

    clear(listSlot);
    if (!filtered.length) {
      listSlot.appendChild(emptyState(
        'Правил не знайдено',
        'Змініть рівень або пошуковий запит.',
        { icon: '📘' }
      ));
      return;
    }

    const list = h('div', { class: 'list' }, filtered.map((note) => grammarRow(app, note)));
    listSlot.appendChild(list);
  }

  root.appendChild(card([sectionHeader('Граматика', 'Короткі правила простою мовою', '📚'), levelSlot]));
  root.appendChild(searchField);
  root.appendChild(summarySlot);
  root.appendChild(listSlot);

  renderLevels();
  renderList();
  return root;
}

// MARK: - Деталі правила

function exampleCard(app, example, index) {
  return card([
    h('div', { class: 'muted', text: 'Приклад ' + index }),
    h('div', { class: 'row-between' }, [
      h('div', { class: 'word-example', text: example.spanish || '' }),
      speakButton(() => app.speak(example.spanish, true), 'Прослухати приклад')
    ]),
    example.translationUk ? h('div', { class: 'word-uk', text: example.translationUk }) : null,
    example.noteUk ? h('div', { class: 'list-sub', text: example.noteUk }) : null
  ]);
}

function wordRow(app, word) {
  return h('div', { class: 'row' }, [
    h('div', { style: { flex: '1 1 auto', minWidth: '0' } }, h('button', {
      class: 'list-item',
      type: 'button',
      onclick: () => app.navigate('#/word/' + word.id)
    }, [
      h('div', {}, [
        h('div', { class: 'word-es', text: word.spanish }),
        h('div', { class: 'word-uk', text: word.translationUk })
      ])
    ])),
    h('div', { style: { flex: '0 0 44px' } }, [
      speakButton(() => app.speak(word.spanish, true), 'Прослухати: ' + word.spanish)
    ])
  ]);
}

/** Деталі правила: пояснення, приклади, помилка, порада та слова. */
export function renderGrammarDetail(app, params) {
  const options = params || {};
  const note = app.content.grammarById.get(options.id);

  if (!note) {
    return emptyState(
      'Правило не знайдено',
      'Можливо, посилання застаріле або правило прибрали з контенту.',
      {
        icon: '📘',
        actionTitle: 'До граматики',
        onAction: () => app.navigate('#/grammar')
      }
    );
  }

  const blocks = [];

  blocks.push(card([
    h('div', { class: 'row' }, [levelBadge(note.level)]),
    note.titleEs ? h('div', { class: 'word-hero', text: note.titleEs }) : null,
    note.titleUk ? h('div', { class: 'list-title', text: note.titleUk }) : null,
    note.tag ? h('div', { class: 'list-sub', text: 'тег: ' + note.tag }) : null
  ]));

  if (note.patternUk) {
    blocks.push(infoBox('Схема', note.patternUk));
  }

  if (note.explanationUk) {
    blocks.push(card([
      sectionHeader('Пояснення', 'Що це означає і навіщо потрібно', '💡'),
      h('div', {}, note.explanationUk)
    ]));
  }

  const examples = note.examples || [];
  if (examples.length) {
    blocks.push(sectionHeader('Приклади', 'Натисніть 🔊, щоб почути', '🗣'));
    examples.forEach((example, index) => {
      blocks.push(exampleCard(app, example, index + 1));
    });
  }

  if (note.commonMistakeUk) {
    blocks.push(infoBox('Типова помилка', note.commonMistakeUk, { tone: 'error' }));
  }

  if (note.tipForUkSpeakersUk) {
    blocks.push(infoBox('Порада для україномовних', note.tipForUkSpeakersUk, { tone: 'success' }));
  }

  const words = note.tag ? wordsWithTag(app.content, note.tag).slice(0, WORDS_LIMIT) : [];
  if (words.length) {
    blocks.push(sectionHeader('Слова з цим правилом', 'Перші ' + words.length + ' для прикладу', '🔤'));
    blocks.push(h('div', { class: 'list' }, words.map((word) => wordRow(app, word))));
  }

  blocks.push(button('До списку правил', {
    variant: 'ghost',
    className: 'btn-block',
    onClick: () => app.navigate('#/grammar')
  }));

  return h('div', { class: 'stack' }, blocks);
}
