// Курс: вибір рівня, запуск заняття й список тем із прогресом.

import { h, clear, button, card, chip, emptyState, levelBadge, plural, progressBar, sectionHeader } from '../ui.js';

const LEVELS = [
  { code: 'A0', title: 'З нуля' },
  { code: 'A1', title: 'Базовий' },
  { code: 'A2', title: 'Побутовий' }
];

/** Іконки тем за `iconKey` (дублюється в home.js — імпорт між екранами заборонений). */
const TOPIC_ICONS = {
  numbers: '🔢', clock: '🕐', family: '👨‍👩‍👧', food: '🍽', restaurant: '🍷',
  shopping: '🛒', home: '🏠', city: '🏙', travel: '✈️', transport: '🚋',
  work: '💼', health: '🩺', weather: '⛅', tech: '💻', hobby: '🎮',
  opinion: '💬', past: '🕰', person: '🧑', polite: '🙏', greetings: '👋',
  verbs: '📖', errands: '✅', survival: '🛟'
};

export function renderLearn(app) {
  const container = h('div', { class: 'stack' });
  let level = app.store.profile.level || 'A0';
  if (!LEVELS.some((item) => item.code === level)) level = 'A0';

  function draw() {
    clear(container);
    container.appendChild(levelSegmented());
    container.appendChild(levelSummary());
    container.appendChild(sessionCard());
    container.appendChild(topicsSection());
  }

  // MARK: Рівні

  function levelSegmented() {
    return h('div', { class: 'segmented' }, LEVELS.map((item) => h('button', {
      class: 'segmented-item' + (item.code === level ? ' active' : ''),
      type: 'button',
      text: item.code + ' · ' + item.title,
      onclick: () => {
        level = item.code;
        draw();
      }
    })));
  }

  function levelSummary() {
    const items = app.store.topicsWithProgress(level);
    const words = items.reduce((sum, item) => sum + item.wordsCount, 0);
    const learned = items.reduce((sum, item) => sum + item.learned, 0);
    return h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
      chip(items.length + ' ' + plural(items.length, 'тема', 'теми', 'тем')),
      chip(words + ' ' + plural(words, 'слово', 'слова', 'слів')),
      chip('вивчено ' + learned)
    ]);
  }

  // MARK: Заняття

  function sessionCard() {
    return card([
      sectionHeader('Заняття на сьогодні', 'Повторення, нові слова, граматика, вправи й аудіювання', '▶️'),
      button('Почати заняття', {
        variant: 'primary',
        className: 'btn-block',
        onClick: () => app.navigate('#/session')
      })
    ]);
  }

  // MARK: Теми

  function topicsSection() {
    const items = app.store.topicsWithProgress(level);
    if (!items.length) {
      return emptyState(
        'Тем поки немає',
        'Для рівня ' + level + ' ще немає тем. Оберіть інший рівень угорі.',
        { icon: '📚' }
      );
    }
    return h('div', { class: 'stack' }, [
      sectionHeader('Теми рівня ' + level, 'Оберіть тему, щоб побачити слова й граматику', '🗂'),
      h('div', { class: 'list' }, items.map((item) => topicRow(item)))
    ]);
  }

  function topicRow(item) {
    const topic = item.topic;
    const words = item.wordsCount + ' ' + plural(item.wordsCount, 'слово', 'слова', 'слів');
    return h('button', {
      class: 'list-item',
      type: 'button',
      onclick: () => app.navigate('#/topic/' + encodeURIComponent(topic.id))
    }, [
      h('span', { class: 'list-icon', text: TOPIC_ICONS[topic.iconKey] || '📚' }),
      h('div', { class: 'spacer' }, [
        h('div', { class: 'row-between' }, [
          h('span', { class: 'list-title', text: topic.titleUk }),
          levelBadge(topic.level)
        ]),
        h('div', { class: 'list-sub', text: topic.titleEs }),
        progressBar(item.fraction, { className: 'progress-thin' }),
        h('div', { class: 'muted', text: words + ' · вивчено ' + item.learned })
      ])
    ]);
  }

  draw();
  return container;
}
