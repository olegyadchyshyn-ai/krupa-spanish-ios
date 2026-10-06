// Екран «Картка слова»: `#/word/<id>`.
//
// Показує переклад, вимову, приклад, нотатки, граматичні теги та прогрес
// повторень. Уся робота з DOM — усередині renderWord.

import {
  h, card, sectionHeader, button, speakButton, chip, emptyState, infoBox,
  levelBadge, progressBar
} from '../ui.js';

import { grammarByTag } from '../content.js';

import { SrsEngine, PHASES, makeItem } from '../store.js';

const GENDER_LABELS = {
  m: 'чоловічий рід',
  f: 'жіночий рід',
  mf: 'ч./ж. рід',
  none: ''
};

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

// MARK: - Хелпери подання

/** Іспанське слово з артиклем, якщо він потрібен. */
function withArticle(word) {
  if (!word.withArticle) return word.spanish;
  if (word.gender === 'm') return 'el ' + word.spanish;
  if (word.gender === 'f') return 'la ' + word.spanish;
  return word.spanish;
}

function partOfSpeechLabel(word) {
  return POS_LABELS[word.partOfSpeech] || word.partOfSpeech || 'слово';
}

function genderLabel(word) {
  return GENDER_LABELS[word.gender] || '';
}

function percent(correct, total) {
  if (!total) return '—';
  return Math.round((correct / total) * 100) + '%';
}

/** Рядок «підпис — значення» для блоку прогресу. */
function kvRow(label, value) {
  return h('div', { class: 'kv-row' }, [
    h('span', { class: 'kv-label', text: label }),
    h('span', { text: String(value) })
  ]);
}

/** Рядок з іспанським прикладом і кнопкою озвучення. */
function exampleRow(app, spanish, ukrainian) {
  return h('div', { class: 'stack' }, [
    h('div', { class: 'row-between' }, [
      h('div', { class: 'word-example', text: spanish || '' }),
      speakButton(() => app.speak(spanish, true), 'Прослухати приклад')
    ]),
    ukrainian ? h('div', { class: 'word-uk', text: ukrainian }) : null
  ]);
}

// MARK: - Блоки картки

function heroBlock(app, word) {
  return card([
    h('div', { class: 'row-between' }, [
      h('div', { class: 'word-hero', text: withArticle(word) }),
      speakButton(() => app.speak(word.spanish, true), 'Прослухати: ' + word.spanish)
    ]),
    metaRow(word),
    h('div', { class: 'word-hero', text: word.translationUk || '' })
  ]);
}

/** Рівень, частина мови, рід і множина. */
function metaRow(word) {
  const parts = [partOfSpeechLabel(word)];
  const gender = genderLabel(word);
  if (gender) parts.push(gender);
  if (word.plural) parts.push('мн.: ' + word.plural);

  return h('div', { class: 'row' }, [
    levelBadge(word.level),
    h('span', { class: 'list-sub', text: parts.join(' · ') })
  ]);
}

function pronunciationBlock(app, word) {
  const settings = app.store.settings;
  const showHints = settings.showPronunciationHints && word.pronunciation;
  const showIpa = settings.showIpa && word.ipaHint;
  if (!showHints && !showIpa) return null;

  const parts = [];
  if (showHints) parts.push(infoBox('Вимова', word.pronunciation));
  if (showIpa) parts.push(infoBox('Підказка щодо звуків', word.ipaHint));
  parts.push(button('Тренувати вимову', {
    variant: 'secondary',
    className: 'btn-block',
    onClick: () => app.navigate('#/speaking')
  }));

  return card([sectionHeader('Вимова', 'Слухайте й повторюйте вголос', '🗣')].concat(parts));
}

function exampleBlock(app, word) {
  if (!word.exampleEs && !word.exampleUk) return null;
  return card([
    sectionHeader('Приклад', 'Слово в живому реченні', '💬'),
    exampleRow(app, word.exampleEs, word.exampleUk)
  ]);
}

function notesBlock(word) {
  const boxes = [];
  if (word.notesUk) boxes.push(infoBox('Нотатка', word.notesUk));
  if (word.cognateNoteUk) boxes.push(infoBox('Схоже на англійське', word.cognateNoteUk, { tone: 'success' }));
  if (!boxes.length) return null;
  return card([sectionHeader('Нотатки', 'Те, що варто запам\'ятати', '📝')].concat(boxes));
}

function tagsBlock(app, word) {
  const tags = word.grammarTags || [];
  if (!tags.length) return null;

  const chips = tags.map((tag) => {
    const note = grammarByTag(app.content, tag) || null;
    return chip(note ? note.titleUk : tag, {
      onClick: note ? () => app.navigate('#/grammar/' + note.id) : null
    });
  });

  return card([
    sectionHeader('Граматика', 'Натисніть тег, щоб відкрити правило', '📘'),
    h('div', { class: 'row' }, chips)
  ]);
}

/** Прогрес картки SRS: фаза, інтервал, точність, керування. */
function progressBlock(app, word) {
  const store = app.store;
  const item = store.card(word.id);
  if (!item) {
    return card([
      sectionHeader('Прогрес', 'Це слово ще не входить до повторень', '📈'),
      button('Додати до повторення зараз', {
        variant: 'secondary',
        className: 'btn-block',
        onClick: () => {
          const created = store.cardOrCreate(makeItem('word', word));
          created.dueAt = Date.now();
          store.upsertCard(created);
          app.toast('Слово додано до повторення');
          app.refresh();
        }
      })
    ]);
  }

  const rows = [
    kvRow('Фаза', PHASES[item.phase] || item.phase),
    kvRow('Інтервал', SrsEngine.intervalLabel(item)),
    kvRow('Точність', percent(item.correctReviews || 0, item.totalReviews || 0)),
    kvRow('Повторень', item.repetitions || 0),
    kvRow('Зривів', item.lapses || 0)
  ];
  rows.push(kvRow('Засвоєно', SrsEngine.isLearned(item) ? 'так' : 'ще ні'));
  if (item.suspended) rows.push(kvRow('Стан', 'призупинено'));

  const buttons = [
    button(item.suspended ? 'Відновити' : 'Призупинити', {
      variant: item.suspended ? 'primary' : 'ghost',
      onClick: () => {
        store.setSuspended(word.id, !item.suspended);
        app.refresh();
      }
    }),
    button('Додати до повторення зараз', {
      variant: 'secondary',
      onClick: () => {
        const target = store.cardOrCreate(makeItem('word', word));
        target.dueAt = Date.now();
        store.upsertCard(target);
        app.toast('Слово буде в наступному повторенні');
        app.refresh();
      }
    })
  ];

  return card([
    sectionHeader('Прогрес', 'Дані інтервального повторення', '📈'),
    h('div', {}, rows),
    progressBar(item.totalReviews ? (item.correctReviews || 0) / item.totalReviews : 0),
    h('div', { class: 'row' }, buttons)
  ]);
}

// MARK: - Рендер

/** Картка слова за ідентифікатором. */
export function renderWord(app, params) {
  const options = params || {};
  const word = app.content.wordById.get(options.id);

  if (!word) {
    return emptyState(
      'Слово не знайдено',
      'Можливо, посилання застаріле або слово прибрали з контенту.',
      {
        icon: '🔍',
        actionTitle: 'До словника',
        onAction: () => app.navigate('#/words')
      }
    );
  }

  const blocks = [
    heroBlock(app, word),
    pronunciationBlock(app, word),
    exampleBlock(app, word),
    notesBlock(word),
    tagsBlock(app, word),
    progressBlock(app, word),
    button('Назад до словника', {
      variant: 'ghost',
      className: 'btn-block',
      onClick: () => app.navigate('#/words')
    })
  ];

  return h('div', { class: 'stack' }, blocks);
}
