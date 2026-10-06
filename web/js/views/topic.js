// Екран теми: опис, слова, граматика теми й аудіювання.

import {
  h, button, card, chip, emptyState, levelBadge, plural, progressBar, sectionHeader, speakButton
} from '../ui.js';
import { SrsEngine } from '../store.js';
import { grammarByTags, listeningOfLevel, wordsOfTopic } from '../content.js';

const LISTENING_KINDS = {
  dialogue: 'Діалог',
  monologue: 'Монолог',
  story: 'Історія',
  podcast: 'Подкаст'
};

export function renderTopic(app, { id } = {}) {
  const content = app.content;
  const topic = id ? content.topicById.get(id) : null;

  if (!topic) {
    return emptyState('Тему не знайдено', 'Можливо, посилання застаріле. Оберіть тему зі списку курсу.', {
      icon: '🔍',
      actionTitle: 'До курсу',
      onAction: () => app.navigate('#/learn')
    });
  }

  const words = wordsOfTopic(content, topic.id);
  const learned = words.filter((word) => isLearned(app, word.id)).length;
  const grammar = grammarByTags(content, topic.grammarTags);
  const listening = listeningOfLevel(content, topic.level, topic.id);

  return h('div', { class: 'stack' }, [
    topicHeader(app, topic, words.length, learned, grammar.length, listening.length),
    wordsSection(app, words),
    grammarSection(app, grammar),
    listeningSection(app, listening)
  ]);
}

// MARK: - Заголовок теми

function topicHeader(app, topic, wordsCount, learnedCount, grammarCount, listeningCount) {
  const chips = [
    chip(wordsCount + ' ' + plural(wordsCount, 'слово', 'слова', 'слів')),
    chip('вивчено ' + learnedCount)
  ];
  if (grammarCount) chips.push(chip('граматика: ' + grammarCount));
  if (listeningCount) chips.push(chip('аудіювання: ' + listeningCount));

  return card([
    h('div', { class: 'row-between' }, [
      h('div', { class: 'section-title', text: topic.titleUk }),
      levelBadge(topic.level)
    ]),
    h('div', { class: 'word-es', text: topic.titleEs }),
    topic.descriptionUk ? h('div', { class: 'muted', text: topic.descriptionUk }) : null,
    progressBar(wordsCount ? learnedCount / wordsCount : 0, { className: 'progress-thin' }),
    h('div', { class: 'row', style: { flexWrap: 'wrap' } }, chips),
    button('Почати заняття з теми', {
      icon: '▶️',
      className: 'btn-block',
      onClick: () => app.navigate('#/session?topic=' + encodeURIComponent(topic.id))
    })
  ]);
}

// MARK: - Слова теми

function wordsSection(app, words) {
  if (!words.length) return mutedLine('Слова теми: для цієї теми слів ще немає.');
  return h('div', { class: 'stack' }, [
    sectionHeader(
      'Слова теми',
      words.length + ' ' + plural(words.length, 'слово', 'слова', 'слів') + ' — натисніть, щоб відкрити',
      '🔤'
    ),
    h('div', { class: 'list' }, words.map((word) => wordRow(app, word)))
  ]);
}

function wordRow(app, word) {
  return h('div', { class: 'row' }, [
    h('button', {
      class: 'list-item spacer',
      type: 'button',
      onclick: () => app.navigate('#/word/' + encodeURIComponent(word.id))
    }, [
      h('div', { class: 'spacer' }, [
        h('div', { class: 'row' }, [
          h('span', { class: 'word-es', text: word.spanish }),
          isLearned(app, word.id) ? h('span', { class: 'badge', text: '✅' }) : null
        ]),
        h('div', { class: 'word-uk', text: word.translationUk })
      ])
    ]),
    speakButton(() => app.speak(word.spanish, true))
  ]);
}

// MARK: - Граматика теми

function grammarSection(app, notes) {
  if (!notes.length) return mutedLine('Граматика теми: для цієї теми правил ще немає.');
  return h('div', { class: 'stack' }, [
    sectionHeader('Граматика теми', notes.length + ' ' + plural(notes.length, 'правило', 'правила', 'правил'), '📘'),
    h('div', { class: 'list' }, notes.map((note) => h('button', {
      class: 'list-item',
      type: 'button',
      onclick: () => app.navigate('#/grammar/' + encodeURIComponent(note.id))
    }, [
      h('span', { class: 'list-icon', text: '📘' }),
      h('div', { class: 'spacer' }, [
        h('div', { class: 'list-title', text: note.titleUk }),
        h('div', { class: 'list-sub', text: note.patternUk || note.titleEs || '' })
      ])
    ])))
  ]);
}

// MARK: - Аудіювання

function listeningSection(app, items) {
  if (!items.length) return mutedLine('Аудіювання: для цієї теми записів ще немає.');
  return h('div', { class: 'stack' }, [
    sectionHeader('Аудіювання', 'Слухаємо й перевіряємо розуміння', '🎧'),
    h('div', { class: 'list' }, items.map((item) => h('button', {
      class: 'list-item',
      type: 'button',
      onclick: () => app.navigate('#/listening/' + encodeURIComponent(item.id))
    }, [
      h('span', { class: 'list-icon', text: '🎧' }),
      h('div', { class: 'spacer' }, [
        h('div', { class: 'list-title', text: item.titleUk || item.titleEs || item.id }),
        h('div', { class: 'list-sub', text: LISTENING_KINDS[item.kind] || item.kind || 'Аудіо' })
      ]),
      levelBadge(item.level)
    ])))
  ]);
}

// MARK: - Хелпери

function isLearned(app, wordId) {
  const cardItem = app.store.card(wordId);
  return cardItem ? SrsEngine.isLearned(cardItem) : false;
}

function mutedLine(text) {
  return h('div', { class: 'muted', text });
}
