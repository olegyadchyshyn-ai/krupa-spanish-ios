// Екран «Прогрес»: зведення, тижнева діаграма, слабкі місця, теми та деталі.
//
// Модуль не торкається DOM на верхньому рівні — усі елементи створюються
// всередині функцій рендеру.

import {
  h, card, sectionHeader, button, progressBar, levelBadge, statTile,
  emptyState, toast, formatDateTime, formatMinutes, weekdayShort, plural
} from '../ui.js';
import { PHASES, GRADE_INFO, GOALS, SrsEngine } from '../store.js';
import { grammarByTag } from '../content.js';

const LEVELS = ['A0', 'A1', 'A2'];

const GRADE_COLORS = {
  AGAIN: 'var(--error)',
  HARD: 'var(--warning)',
  GOOD: 'var(--success)',
  EASY: 'var(--brand)'
};

const TYPE_TITLES = {
  WORD: 'Слово',
  SENTENCE: 'Речення',
  EXERCISE: 'Вправа',
  LISTENING: 'Аудіювання',
  GRAMMAR: 'Граматика'
};

const TYPE_ICONS = {
  WORD: '🔤',
  SENTENCE: '💬',
  EXERCISE: '✏️',
  LISTENING: '🎧',
  GRAMMAR: '📘'
};

const TOPIC_ICONS = {
  greetings: '👋', person: '🧑', polite: '🙏', numbers: '🔢', family: '👨‍👩‍👧',
  food: '🥘', restaurant: '🍽️', shopping: '🛍️', city: '🏙️', transport: '🚌',
  travel: '✈️', home: '🏠', health: '🩺', work: '💼', tech: '💻', weather: '⛅',
  clock: '🕒', hobby: '🎨', opinion: '💭', past: '📜', survival: '🧭',
  verbs: '🔁', errands: '📋'
};

// MARK: - Зведення

export function renderProgress(app) {
  const store = app.store;
  const snapshot = store.snapshot();

  return h('div', { class: 'stack' }, [
    h('div', { class: 'grid-2' }, [
      statTile('Серія днів', snapshot.streakDays, '🔥'),
      statTile('Точність', Math.round(snapshot.accuracy) + ' %', '🎯'),
      statTile('Слів вивчено', snapshot.wordsLearned, '📚'),
      statTile('Хвилин', formatMinutes(snapshot.totalMinutes), '⏱')
    ]),
    todayCard(store, snapshot),
    weekCard(store),
    levelGoalCard(store),
    weakSpotsSection(app),
    topicsSection(app),
    button('Детальніше', {
      icon: '📊',
      className: 'btn-block',
      onClick: () => app.navigate('#/progress/details')
    })
  ]);
}

function kvRow(label, value) {
  return h('div', { class: 'kv-row' }, [
    h('span', { class: 'kv-label', text: label }),
    h('span', { text: value })
  ]);
}

function todayCard(store, snapshot) {
  const stat = store.todayStat();
  const reviews = Math.round(stat.reviews || 0);
  const subtitle = reviews
    ? reviews + ' ' + plural(reviews, 'повторення', 'повторення', 'повторень') + ' сьогодні'
    : 'Сьогодні ще не було занять';

  return card([
    sectionHeader('Сьогодні', subtitle, '📅'),
    h('div', {}, [
      kvRow('Повторень', String(reviews)),
      kvRow('Правильних', String(Math.round(stat.correct || 0))),
      kvRow('Нових карток', String(Math.round(stat.newCards || 0))),
      kvRow('Хвилин', formatMinutes(stat.minutes)),
      kvRow('XP', String(Math.round(stat.xp || 0)))
    ]),
    progressBar(snapshot.goalFraction),
    h('div', { class: 'muted', text: reviews + ' з ' + snapshot.dailyGoal + ' карток' })
  ]);
}

function weekCard(store) {
  const days = [];
  for (let i = 6; i >= 0; i--) {
    const date = new Date();
    date.setDate(date.getDate() - i);
    days.push({ date, reviews: Math.round(store.dailyStat(date).reviews || 0) });
  }

  const max = days.reduce((best, day) => Math.max(best, day.reviews), 0);
  const total = days.reduce((sum, day) => sum + day.reviews, 0);

  if (max === 0) {
    return card([
      sectionHeader('Останні 7 днів', null, '📈'),
      emptyState('Ще немає занять', 'Пройдіть перше заняття — і тут з\'явиться статистика.')
    ]);
  }

  return card([
    sectionHeader(
      'Останні 7 днів',
      total + ' ' + plural(total, 'повторення', 'повторення', 'повторень') + ' за тиждень',
      '📈'
    ),
    h('div', { class: 'chart' }, days.map((day) => chartColumn(day, max)))
  ]);
}

function chartColumn(day, max) {
  const height = day.reviews > 0 ? Math.max(3, Math.round((day.reviews / max) * 80)) : 3;
  return h('div', { class: 'chart-col' }, [
    h('div', { class: 'chart-value', text: String(day.reviews) }),
    h('div', {
      class: 'chart-bar' + (day.reviews > 0 ? '' : ' chart-bar-empty'),
      style: { height: height + 'px' },
      title: day.reviews + ' — ' + day.date.toLocaleDateString('uk-UA')
    }),
    h('div', { class: 'chart-label', text: weekdayShort(day.date) })
  ]);
}

function levelGoalCard(store) {
  const profile = store.profile;
  const goal = GOALS.find((item) => item.id === profile.goal);

  return card([
    sectionHeader('Рівень і мета', goal ? goal.description : null, '🎓'),
    h('div', { class: 'row-between' }, [
      h('div', { class: 'row' }, [
        levelBadge(profile.level),
        h('span', { class: 'list-title', text: goal ? goal.title : 'Мета не вибрана' })
      ]),
      h('span', { class: 'muted', text: profile.dailyMinutes + ' хвилин на день' })
    ])
  ]);
}

// MARK: - Слабкі місця та теми

function weakSpotsSection(app) {
  const spots = app.store.weakSpots(8);
  const children = [sectionHeader('Слабкі місця', 'Те, що варто повторити', '⚠️')];

  if (!spots.length) {
    children.push(h('div', { class: 'muted', text: 'Поки що немає слабких місць' }));
    return h('div', { class: 'stack' }, children);
  }

  children.push(h('div', { class: 'list' }, spots.map((spot) => weakSpotRow(app, spot))));
  return h('div', { class: 'stack' }, children);
}

function weakSpotRow(app, spot) {
  const grammar = grammarByTag(app.content, spot.key);
  const word = grammar ? null : app.content.wordById.get(spot.key);
  const title = grammar
    ? (grammar.titleUk || grammar.titleEs || spot.key)
    : word ? word.spanish : spot.key;
  const hash = grammar
    ? '#/grammar/' + encodeURIComponent(grammar.id)
    : word ? '#/word/' + encodeURIComponent(word.id) : null;
  const percent = Math.round(spot.rate * 100) + ' %';
  const subtitle = spot.key + ' · помилок ' + spot.wrong + ' з ' + spot.attempts + ' (' + percent + ')';

  const props = { class: 'list-item' };
  if (hash) {
    props.type = 'button';
    props.onclick = () => app.navigate(hash);
  }

  return h(hash ? 'button' : 'div', props, [
    h('span', { class: 'list-icon', text: grammar ? '📘' : '🔤' }),
    h('div', { class: 'stack', style: { gap: '2px', flex: '1' } }, [
      h('div', { class: 'list-title', text: title }),
      h('div', { class: 'list-sub', text: subtitle })
    ])
  ]);
}

function topicsSection(app) {
  const items = app.store.topicsWithProgress();
  const children = [
    sectionHeader('Теми', 'Прогрес тем рівня ' + app.store.profile.level, '🧩')
  ];

  if (!items.length) {
    children.push(h('div', { class: 'muted', text: 'Для цього рівня ще немає тем' }));
    return h('div', { class: 'stack' }, children);
  }

  children.push(h('div', { class: 'list' }, items.map((entry) => topicRow(app, entry))));
  return h('div', { class: 'stack' }, children);
}

function topicRow(app, entry) {
  const topic = entry.topic;
  const learned = entry.learned + ' з ' + entry.wordsCount;

  return h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => app.navigate('#/topic/' + encodeURIComponent(topic.id))
  }, [
    h('span', { class: 'list-icon', text: TOPIC_ICONS[topic.iconKey] || '📘' }),
    h('div', { class: 'stack', style: { gap: '6px', flex: '1' } }, [
      h('div', { class: 'row-between' }, [
        h('span', { class: 'list-title', text: topic.titleEs }),
        h('span', { class: 'list-sub', text: learned })
      ]),
      progressBar(entry.fraction),
      h('div', { class: 'list-sub', text: topic.titleUk })
    ])
  ]);
}

// MARK: - Деталі прогресу

export function renderProgressDetail(app) {
  const store = app.store;
  const cards = Object.values(store.cards);

  if (!cards.length) {
    return h('div', { class: 'stack' }, [
      emptyState('Ще немає даних', 'Пройдіть перше заняття — і тут з\'явиться детальна статистика.', {
        icon: '📊',
        actionTitle: 'До курсу',
        onAction: () => app.navigate('#/learn')
      })
    ]);
  }

  const snapshot = store.snapshot();
  const strength = averageStrength(cards);

  return h('div', { class: 'stack' }, [
    summaryCard(snapshot),
    phaseCard(cards),
    levelCard(cards),
    card([
      sectionHeader('Міцність знань', 'Середня впевненість у картках', '💪'),
      h('div', { class: 'grid-2' }, [
        statTile('Міцність', Math.round(strength) + ' %', '💪'),
        statTile('Усього карток', cards.length, '🗂')
      ]),
      h('div', { class: 'muted', text: 'Показник враховує правильні відповіді та зриви у картках.' })
    ]),
    logSection(store),
    button('Скопіювати звіт', {
      variant: 'secondary',
      icon: '📋',
      className: 'btn-block',
      onClick: () => copyReport(app)
    })
  ]);
}

function summaryCard(snapshot) {
  return card([
    sectionHeader('Зведення', 'За весь час навчання', '📈'),
    h('div', {}, [
      kvRow('Загальні повторення', String(Math.round(snapshot.totalReviews))),
      kvRow('Найдовша серія', snapshot.longestStreak + ' ' + plural(snapshot.longestStreak, 'день', 'дні', 'днів')),
      kvRow('Точність', Math.round(snapshot.accuracy) + ' %'),
      kvRow('Карток на сьогодні', String(snapshot.dueToday)),
      kvRow('Усього хвилин', formatMinutes(snapshot.totalMinutes)),
      kvRow('XP', String(Math.round(snapshot.totalXP)))
    ])
  ]);
}

function phaseCard(cards) {
  const total = cards.length || 1;
  const rows = Object.keys(PHASES).map((phase) => {
    const count = cards.filter((item) => item.phase === phase).length;
    const fraction = count / total;
    return h('div', { class: 'stack', style: { gap: '4px' } }, [
      h('div', { class: 'row-between' }, [
        h('span', { text: PHASES[phase] }),
        h('span', { class: 'list-sub', text: count + ' (' + Math.round(fraction * 100) + ' %)' })
      ]),
      progressBar(fraction)
    ]);
  });

  return card([sectionHeader('Розподіл за фазами', cards.length + ' карток усього', '🔁')].concat(rows));
}

function levelCard(cards) {
  const rows = LEVELS.map((level) => {
    const count = cards.filter((item) => item.levelCode === level).length;
    const fraction = cards.length ? count / cards.length : 0;
    return h('div', { class: 'stack', style: { gap: '4px' } }, [
      h('div', { class: 'row-between' }, [
        levelBadge(level),
        h('span', { class: 'list-sub', text: count + ' ' + plural(count, 'картка', 'картки', 'карток') })
      ]),
      progressBar(fraction)
    ]);
  });

  return card([sectionHeader('Розподіл за рівнями', 'Скільки карток на кожному рівні', '🎚')].concat(rows));
}

function logSection(store) {
  const log = (store.data.reviewLog || []).slice(-20).reverse();
  const children = [sectionHeader('Останні відповіді', 'До 20 останніх записів', '🕒')];

  if (!log.length) {
    children.push(h('div', { class: 'muted', text: 'Журнал відповідей порожній' }));
    return h('div', { class: 'stack' }, children);
  }

  children.push(h('div', { class: 'list' }, log.map((entry) => logRow(entry))));
  return h('div', { class: 'stack' }, children);
}

function logRow(entry) {
  const info = GRADE_INFO[entry.grade] || { title: entry.grade, symbol: '•' };
  const type = TYPE_TITLES[entry.itemType] || 'Картка';
  const meta = formatDateTime(entry.at) + ' · ' + Math.round(entry.responseMs || 0) + ' мс';

  return h('div', { class: 'list-item' }, [
    h('span', { class: 'list-icon', text: TYPE_ICONS[entry.itemType] || '•' }),
    h('div', { class: 'stack', style: { gap: '2px', flex: '1' } }, [
      h('div', { class: 'row-between' }, [
        h('span', { class: 'list-title', text: type }),
        h('span', {
          text: info.title,
          style: {
            color: GRADE_COLORS[entry.grade] || 'var(--text)',
            fontSize: '13px',
            fontWeight: '600'
          }
        })
      ]),
      h('div', { class: 'list-sub', text: meta })
    ])
  ]);
}

// MARK: - Міцність знань

function averageStrength(cards) {
  const reviewed = cards.filter((item) => (item.totalReviews || 0) > 0);
  if (!reviewed.length) return 0;

  if (typeof SrsEngine.strength === 'function') {
    const sum = reviewed.reduce((acc, item) => acc + normalizePercent(SrsEngine.strength(item)), 0);
    return sum / reviewed.length;
  }
  if (typeof SrsEngine.retention === 'function') {
    const sum = reviewed.reduce((acc, item) => acc + normalizePercent(SrsEngine.retention(item)), 0);
    return sum / reviewed.length;
  }

  const total = reviewed.reduce((acc, item) => acc + (item.totalReviews || 0), 0);
  const correct = reviewed.reduce((acc, item) => acc + (item.correctReviews || 0), 0);
  return total ? (correct / total) * 100 : 0;
}

/** Приводить частку (0…1) до відсотків, а відсотки лишає як є. */
function normalizePercent(value) {
  const number = Number(value) || 0;
  return number > 0 && number <= 1 ? number * 100 : number;
}

// MARK: - Звіт

function copyReport(app) {
  const text = buildReport(app);
  try {
    if (!navigator.clipboard || typeof navigator.clipboard.writeText !== 'function') {
      throw new Error('clipboard недоступний');
    }
    navigator.clipboard.writeText(text).then(
      () => toast('Скопійовано'),
      () => toast('Не вдалося скопіювати')
    );
  } catch (error) {
    toast('Не вдалося скопіювати');
  }
}

function buildReport(app) {
  const store = app.store;
  const snapshot = store.snapshot();
  const goal = GOALS.find((item) => item.id === store.profile.goal);
  const cards = Object.values(store.cards);

  return [
    'KRUPA Spanish — звіт про прогрес',
    'Дата: ' + formatDateTime(new Date()),
    'Рівень: ' + store.profile.level,
    'Мета: ' + (goal ? goal.title : '—'),
    'Серія днів: ' + snapshot.streakDays + ' (найдовша: ' + snapshot.longestStreak + ')',
    'Точність: ' + Math.round(snapshot.accuracy) + ' %',
    'Вивчено слів: ' + snapshot.wordsLearned,
    'Усього повторень: ' + Math.round(snapshot.totalReviews),
    'Витрачено часу: ' + formatMinutes(snapshot.totalMinutes),
    'XP: ' + Math.round(snapshot.totalXP),
    'Карток на сьогодні: ' + snapshot.dueToday,
    'Усього карток: ' + cards.length,
    'Міцність знань: ' + Math.round(averageStrength(cards)) + ' %'
  ].join('\n');
}
