// Головний екран: привітання, стан дня, швидкі дії, теми й слабкі місця.

import {
  h, button, card, chip, errorBanner, formatMinutes, levelBadge, plural,
  progressBar, sectionHeader, statTile
} from '../ui.js';

const MAX_CONTINUE_TOPICS = 3;
const WEAK_SPOTS_LIMIT = 5;

const QUICK_ACTIONS = [
  { icon: '🎧', title: 'Аудіювання', sub: 'Розуміти на слух', hash: '#/listening' },
  { icon: '🎤', title: 'Вимова', sub: 'Тренувати звуки', hash: '#/speaking' },
  { icon: '💬', title: 'Діалог', sub: 'Розмова з ботом', hash: '#/ai' },
  { icon: '📘', title: 'Граматика', sub: 'Правила й приклади', hash: '#/grammar' }
];

/** Іконки тем за `iconKey` (дублюється в learn.js — імпорт між екранами заборонений). */
const TOPIC_ICONS = {
  numbers: '🔢', clock: '🕐', family: '👨‍👩‍👧', food: '🍽', restaurant: '🍷',
  shopping: '🛒', home: '🏠', city: '🏙', travel: '✈️', transport: '🚋',
  work: '💼', health: '🩺', weather: '⛅', tech: '💻', hobby: '🎮',
  opinion: '💬', past: '🕰', person: '🧑', polite: '🙏', greetings: '👋',
  verbs: '📖', errands: '✅', survival: '🛟'
};

export function renderHome(app) {
  const store = app.store;
  const snapshot = store.snapshot();
  const today = store.todayStat();
  const dueCount = store.dueCards().length;

  const blocks = [
    headerBlock(app, snapshot),
    todayBlock(app, today, snapshot, dueCount),
    quickBlock(app),
    continueBlock(app),
    weakBlock(app),
    issuesBlock(app)
  ];

  return h('div', { class: 'stack' }, blocks.filter(Boolean));
}

// MARK: - Шапка

function headerBlock(app, snapshot) {
  const name = String(app.store.profile.displayName || '').trim();
  const days = snapshot.streakDays;
  return h('div', { class: 'gradient-header' }, [
    h('div', { class: 'row-between' }, [
      h('div', { class: 'section-title', text: name ? 'Привіт, ' + name + '!' : 'Привіт!' }),
      levelBadge(app.store.profile.level)
    ]),
    h('div', { class: 'muted', text: '🔥 ' + days + ' ' + plural(days, 'день', 'дні', 'днів') + ' поспіль' }),
    h('div', { class: 'muted', text: 'План: ' + app.store.profile.dailyMinutes + ' хв на день' })
  ]);
}

// MARK: - Сьогодні

function todayBlock(app, today, snapshot, dueCount) {
  const goal = snapshot.dailyGoal;
  const reviews = today.reviews;
  return card([
    sectionHeader('Сьогодні', 'Щоденна мета — ' + goal + ' карток', '📅'),
    h('div', { class: 'grid-3' }, [
      statTile('Повторень', reviews, '🔁'),
      statTile('Правильних', today.correct, '✅'),
      statTile('Нових', today.newCards, '✨')
    ]),
    progressBar(snapshot.goalFraction),
    h('div', { class: 'row-between' }, [
      h('div', { class: 'muted', text: reviews + ' з ' + goal + ' карток' }),
      h('div', { class: 'muted', text: 'Час: ' + formatMinutes(snapshot.minutesToday) })
    ]),
    h('div', { class: 'muted', text: 'Чекає карток: ' + dueCount }),
    button('Почати заняття', { icon: '▶️', className: 'btn-block', onClick: () => app.navigate('#/session') }),
    dueCount > 0
      ? button('Повторити (' + dueCount + ')', {
        variant: 'secondary',
        className: 'btn-block',
        onClick: () => app.navigate('#/review')
      })
      : null
  ]);
}

// MARK: - Швидкі дії

function quickBlock(app) {
  return h('div', { class: 'stack' }, [
    sectionHeader('Швидкі дії', 'Окреме тренування без плану', '⚡'),
    h('div', { class: 'quick-grid' }, QUICK_ACTIONS.map((action) => h('button', {
      class: 'quick-card',
      type: 'button',
      onclick: () => app.navigate(action.hash)
    }, [
      h('span', { class: 'quick-icon', text: action.icon }),
      h('span', { class: 'quick-title', text: action.title }),
      h('span', { class: 'quick-sub', text: action.sub })
    ])))
  ]);
}

// MARK: - Продовжити тему

function continueBlock(app) {
  const items = pickContinueTopics(app.store.topicsWithProgress());
  if (!items.length) return null;
  return h('div', { class: 'stack' }, [
    sectionHeader('Продовжити тему', 'Найближчі теми вашого рівня', '📚'),
    h('div', { class: 'list' }, items.map((item) => topicRow(app, item)))
  ]);
}

function topicRow(app, item) {
  const topic = item.topic;
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
      h('div', { class: 'muted', text: 'Вивчено ' + item.learned + ' з ' + item.wordsCount })
    ])
  ]);
}

/** Спочатку теми, які вже початі, далі — ще не торкані. */
function pickContinueTopics(items) {
  const started = items.filter((item) => item.learned > 0 && item.fraction < 1);
  const fresh = items.filter((item) => item.learned === 0);
  const picked = started.concat(fresh).slice(0, MAX_CONTINUE_TOPICS);
  return picked.length ? picked : items.slice(0, MAX_CONTINUE_TOPICS);
}

// MARK: - Слабкі місця

function weakBlock(app) {
  const spots = app.store.weakSpots(WEAK_SPOTS_LIMIT);
  if (!spots.length) return null;
  return card([
    sectionHeader('Слабкі місця', 'Тут найбільше помилок — варто повторити', '⚠️'),
    h('div', { class: 'row', style: { flexWrap: 'wrap' } }, spots.map((spot) => chip(weakLabel(app, spot))))
  ]);
}

function weakLabel(app, spot) {
  const percent = Math.round(spot.rate * 100) + '%';
  if (spot.kind === 'word') {
    const word = app.content.wordById.get(spot.key);
    return (word ? word.spanish : spot.key) + ' · ' + percent;
  }
  const note = app.content.grammar.find((item) => item.tag === spot.key);
  return (note ? note.titleUk : spot.key) + ' · ' + percent;
}

// MARK: - Зауваження до контенту

function issuesBlock(app) {
  const count = (app.content.issues || []).length;
  return count ? errorBanner('Зауважень до контенту: ' + count) : null;
}
