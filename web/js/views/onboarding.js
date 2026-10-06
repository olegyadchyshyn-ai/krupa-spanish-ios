// Екран першого запуску: вітання, рівень, мета, час на день і мінітест.
//
// Крок зберігається в локальній змінній; після кожної дії перемальовуємо
// лише власний контейнер (не document.body).

import { h, clear, button, card, field, infoBox, levelBadge, optionRow, progressBar } from '../ui.js';
import { GOALS, shuffleArray } from '../store.js';
import { wordsOfLevel } from '../content.js';

const STEP_COUNT = 5; // вітання → рівень → мета → хвилини → тест

const LEVEL_OPTIONS = [
  { code: 'A0', title: 'З нуля', description: 'Перші слова, вимова, найпотрібніші фрази' },
  { code: 'A1', title: 'Базовий', description: 'Прості речення про себе, побут і час' },
  { code: 'A2', title: 'Побутовий', description: 'Магазини, лікар, подорожі, минулий час' }
];

const LEVEL_CODES = ['A0', 'A1', 'A2'];
const MINUTE_OPTIONS = [5, 10, 15, 20, 30];
const TEST_QUOTA = { A0: 3, A1: 2, A2: 2 };
const OPTIONS_PER_QUESTION = 4;

export function renderOnboarding(app) {
  const container = h('div', { class: 'stack' });
  const state = {
    step: 0,
    name: String(app.store.profile.displayName || ''),
    level: app.store.profile.level || 'A0',
    goal: app.store.profile.goal || GOALS[0].id,
    dailyMinutes: app.store.profile.dailyMinutes || 20,
    questions: [],
    index: 0,
    correct: 0,
    choice: null,
    score: 0,
    suggested: 'A0'
  };

  // MARK: Перемальовування

  function draw() {
    clear(container);
    container.appendChild(h('div', { class: 'steps' }, stepDots(state.step)));
    container.appendChild(state.step >= STEP_COUNT ? resultStep() : stepBody());
    container.appendChild(state.step >= STEP_COUNT ? startButtons() : navButtons());
    if (typeof window !== 'undefined') window.scrollTo(0, 0);
  }

  function stepBody() {
    switch (state.step) {
      case 0: return greetingStep();
      case 1: return levelStep();
      case 2: return goalStep();
      case 3: return minutesStep();
      default: return testStep();
    }
  }

  // MARK: Крок 1 — вітання

  function greetingStep() {
    return h('div', { class: 'stack' }, [
      card([
        h('div', { class: 'center' }, [
          h('div', { class: 'empty-icon', text: '🇪🇸' }),
          h('div', { class: 'section-title', text: 'KRUPA Spanish' }),
          h('div', { class: 'muted', text: 'Іспанська мова Іспанії — з нуля до впевненого спілкування' })
        ]),
        field('Ваше ім’я (необов’язково)', {
          value: state.name,
          onInput: (value) => { state.name = value; },
          onSubmit: () => next()
        })
      ]),
      infoBox('Навіщо ім’я?', 'Воно потрібне лише для привітання на головному екрані. Поле можна залишити порожнім.')
    ]);
  }

  // MARK: Крок 2 — рівень

  function levelStep() {
    return card([
      h('div', { class: 'section-title', text: 'З якого рівня почати?' }),
      h('div', { class: 'muted', text: 'Орієнтуйтесь приблизно — рівень завжди можна змінити в налаштуваннях.' }),
      h('div', { class: 'list' }, LEVEL_OPTIONS.map((option) => selectRow(
        option.code === 'A0' ? '🌱' : option.code === 'A1' ? '🌿' : '🌳',
        option.code + ' · ' + option.title,
        option.description,
        state.level === option.code,
        () => { state.level = option.code; draw(); }
      )))
    ]);
  }

  // MARK: Крок 3 — мета

  function goalStep() {
    return card([
      h('div', { class: 'section-title', text: 'Навіщо вам іспанська?' }),
      h('div', { class: 'muted', text: 'Підбір вправ і граматики залежить від мети.' }),
      h('div', { class: 'list' }, GOALS.map((goal) => selectRow(
        goalIcon(goal.id),
        goal.title,
        goal.description,
        state.goal === goal.id,
        () => { state.goal = goal.id; draw(); }
      )))
    ]);
  }

  // MARK: Крок 4 — хвилини на день

  function minutesStep() {
    return card([
      h('div', { class: 'section-title', text: 'Скільки хвилин на день?' }),
      h('div', { class: 'muted', text: 'Краще коротко, але щодня. План заняття підлаштується під цей час.' }),
      h('div', { class: 'segmented' }, MINUTE_OPTIONS.map((minutes) => h('button', {
        class: 'segmented-item' + (state.dailyMinutes === minutes ? ' active' : ''),
        type: 'button',
        text: minutes + ' хв',
        onclick: () => { state.dailyMinutes = minutes; draw(); }
      }))),
      h('div', { class: 'muted', text: 'Обрано: ' + state.dailyMinutes + ' хвилин на день.' })
    ]);
  }

  // MARK: Крок 5 — мінітест

  function testStep() {
    const total = state.questions.length;
    if (!total) {
      return card([
        infoBox('Тест недоступний', 'Не вдалося підібрати слова для тесту. Натисніть «Далі» й оберіть рівень вручну.')
      ]);
    }
    const question = state.questions[Math.min(state.index, total - 1)];
    const answered = state.choice != null;
    const wasCorrect = answered && state.choice === question.word.translationUk;

    return card([
      progressBar((state.index + (answered ? 1 : 0)) / total),
      h('div', { class: 'row-between' }, [
        h('div', { class: 'muted', text: 'Питання ' + (state.index + 1) + ' з ' + total }),
        h('div', { class: 'muted', text: 'Правильно: ' + state.correct })
      ]),
      h('div', { class: 'center' }, [
        h('div', { class: 'word-hero', text: question.word.spanish }),
        h('div', { class: 'muted', text: 'Оберіть правильний переклад' })
      ]),
      h('div', { class: 'stack' }, question.options.map((option) => optionRow(option, {
        state: optionState(option, question, state),
        disabled: answered,
        onClick: () => answer(option)
      }))),
      answered
        ? h('div', { class: 'muted center', text: wasCorrect ? '✅ Правильно' : '❌ Правильний варіант підсвічено' })
        : null
    ]);
  }

  function answer(option) {
    if (state.choice != null || !state.questions.length) return;
    state.choice = option;
    const question = state.questions[state.index];
    if (question && option === question.word.translationUk) state.correct += 1;
    draw();
  }

  // MARK: Результат

  function resultStep() {
    const total = state.questions.length;
    return h('div', { class: 'stack' }, [
      card([
        h('div', { class: 'center' }, [
          h('div', { class: 'empty-icon', text: '🎉' }),
          h('div', { class: 'section-title', text: 'Результат: ' + state.score + '%' }),
          h('div', { class: 'muted', text: total ? 'Правильних відповідей: ' + state.correct + ' з ' + total : 'Тест пропущено' })
        ]),
        h('div', { class: 'row-between' }, [
          h('div', { class: 'list-title', text: 'Пропонований рівень' }),
          levelBadge(state.suggested)
        ]),
        h('div', { class: 'segmented' }, LEVEL_CODES.map((code) => h('button', {
          class: 'segmented-item' + (state.level === code ? ' active' : ''),
          type: 'button',
          text: code,
          onclick: () => { state.level = code; draw(); }
        }))),
        h('div', { class: 'muted', text: 'Це лише пропозиція — рівень можна змінити будь-коли.' })
      ]),
      infoBox('Готово', 'Мета: ' + goalTitle(state.goal) + ' · ' + state.dailyMinutes + ' хв на день.')
    ]);
  }

  // MARK: Кнопки

  function navButtons() {
    const needsAnswer = state.step === 4 && state.questions.length > 0 && state.choice == null;
    return h('div', { class: 'stack' }, [
      h('div', { class: 'grid-2' }, [
        button('Назад', { variant: 'ghost', disabled: state.step === 0, onClick: back }),
        button(nextLabel(), { variant: 'primary', disabled: needsAnswer, onClick: next })
      ]),
      h('div', { class: 'center' }, [
        button('Пропустити', { variant: 'ghost', onClick: skip })
      ])
    ]);
  }

  function startButtons() {
    return button('Почати', { variant: 'primary', className: 'btn-block', onClick: finish });
  }

  function nextLabel() {
    if (state.step !== 4 || !state.questions.length) return 'Далі';
    return state.index + 1 < state.questions.length ? 'Наступне питання' : 'Показати результат';
  }

  // MARK: Дії

  function goTo(step) {
    state.step = step;
    if (step === 4) prepareTest();
    draw();
  }

  function prepareTest() {
    state.questions = buildQuestions(app.content);
    state.index = 0;
    state.correct = 0;
    state.choice = null;
  }

  function back() {
    if (state.step > 0) goTo(state.step - 1);
  }

  function next() {
    if (state.step === 0) app.store.updateProfile({ displayName: state.name.trim() });
    if (state.step < 4) {
      goTo(state.step + 1);
      return;
    }
    if (state.questions.length && state.choice == null) return;
    if (state.index + 1 < state.questions.length) {
      state.index += 1;
      state.choice = null;
      draw();
      return;
    }
    state.score = state.questions.length
      ? Math.round((state.correct / state.questions.length) * 100)
      : 0;
    state.suggested = state.score >= 75 ? 'A2' : state.score >= 40 ? 'A1' : 'A0';
    state.level = state.suggested;
    state.step = STEP_COUNT;
    draw();
  }

  function skip() {
    app.store.updateProfile({ level: 'A0', onboardingDone: true, displayName: state.name.trim() });
    app.navigate('#/');
  }

  function finish() {
    app.store.updateProfile({
      level: state.level,
      goal: state.goal,
      dailyMinutes: state.dailyMinutes,
      assessmentDone: true,
      assessmentScore: state.score,
      onboardingDone: true,
      displayName: state.name.trim()
    });
    app.navigate('#/');
  }

  draw();
  return container;
}

// MARK: - Хелпери

function stepDots(step) {
  const active = Math.min(step, STEP_COUNT - 1);
  const dots = [];
  for (let index = 0; index < STEP_COUNT; index++) {
    dots.push(h('div', { class: 'step-dot' + (index <= active ? ' step-dot-active' : '') }));
  }
  return dots;
}

function selectRow(icon, title, subtitle, selected, onClick) {
  return h('button', { class: 'list-item', type: 'button', onclick: onClick }, [
    h('span', { class: 'list-icon', text: icon }),
    h('div', { class: 'spacer' }, [
      h('div', { class: 'list-title', text: title }),
      subtitle ? h('div', { class: 'list-sub', text: subtitle }) : null
    ]),
    selected ? h('span', { class: 'badge', text: '✓ обрано' }) : null
  ]);
}

function optionState(option, question, state) {
  if (state.choice == null) return null;
  if (option === question.word.translationUk) return 'correct';
  return option === state.choice ? 'wrong' : null;
}

function goalIcon(id) {
  switch (id) {
    case 'COMMUNICATION': return '💬';
    case 'RELOCATION': return '🏠';
    case 'STUDY': return '🎓';
    case 'TRAVEL': return '✈️';
    case 'WORK': return '💼';
    default: return '🎯';
  }
}

function goalTitle(id) {
  const goal = GOALS.find((item) => item.id === id);
  return goal ? goal.title : id;
}

/** 7 питань: 3 слова A0, 2 — A1, 2 — A2; дистрактори — інші слова курсу. */
function buildQuestions(content) {
  const pool = LEVEL_CODES.reduce((acc, level) => acc.concat(wordsOfLevel(content, level)), []);
  const chosen = [];
  for (const level of LEVEL_CODES) {
    const words = shuffleArray(wordsOfLevel(content, level)).filter((word) => word.translationUk);
    chosen.push(...words.slice(0, TEST_QUOTA[level]));
  }
  return shuffleArray(chosen).map((word) => ({
    word,
    options: shuffleArray(buildOptions(word, pool))
  }));
}

function buildOptions(word, pool) {
  const values = [word.translationUk];
  for (const candidate of shuffleArray(pool)) {
    if (values.length >= OPTIONS_PER_QUESTION) break;
    const text = candidate.translationUk;
    if (!text || values.includes(text)) continue;
    values.push(text);
  }
  return values;
}
