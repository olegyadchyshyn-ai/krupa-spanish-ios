// Аудіювання: перелік матеріалів за рівнем і детальний екран із питаннями.

import { listeningOfLevel } from '../content.js';
import { makeItem } from '../store.js';
import {
  h, clear, card, sectionHeader, button, speakButton, levelBadge, chip,
  statTile, emptyState, infoBox, optionRow, plural, toast
} from '../ui.js';

const LEVELS = ['A0', 'A1', 'A2'];

const KIND_TITLES = {
  dialogue: 'Діалог',
  story: 'Історія',
  monologue: 'Монолог',
  podcast: 'Подкаст'
};

function kindTitle(kind) {
  return KIND_TITLES[kind] || 'Аудіоматеріал';
}

function spanishLines(item) {
  return (item.lines || []).map((line) => line.spanish).filter(Boolean);
}

function findItem(app, id) {
  const map = app.content.listeningById;
  const found = id && map && typeof map.get === 'function' ? map.get(id) : null;
  if (found) return found;
  return (app.content.listening || []).find((entry) => entry.id === id) || null;
}

function reviewed(app, id) {
  const srsCard = app.store.card(id);
  return Boolean(srsCard && (srsCard.totalReviews || 0) > 0);
}

function wrapRow(children) {
  return h('div', { class: 'row', style: { flexWrap: 'wrap' } }, children);
}

function segmented(items, activeId, onSelect) {
  return h('div', { class: 'segmented' }, items.map((item) => h('button', {
    class: 'segmented-item' + (item.id === activeId ? ' active' : ''),
    type: 'button',
    text: item.title,
    onclick: () => onSelect(item.id)
  })));
}

// MARK: - Список матеріалів

export function renderListeningList(app) {
  const root = h('div', { class: 'stack' });
  const levelHost = h('div', {});
  const listHost = h('div', { class: 'stack' });
  let level = LEVELS.includes(app.store.profile.level) ? app.store.profile.level : 'A0';

  const materials = app.content.listening || [];
  const passed = materials.filter((item) => reviewed(app, item.id)).length;

  root.appendChild(h('div', { class: 'grid-2' }, [
    statTile('Усього матеріалів', materials.length, '🎧'),
    statTile('Пройдено', passed, '✅')
  ]));
  root.appendChild(levelHost);
  root.appendChild(listHost);

  function renderLevels() {
    clear(levelHost);
    levelHost.appendChild(segmented(
      LEVELS.map((code) => ({ id: code, title: code })),
      level,
      (code) => {
        level = code;
        renderLevels();
        renderList();
      }
    ));
  }

  function renderList() {
    clear(listHost);
    const items = listeningOfLevel(app.content, level);
    if (!items.length) {
      listHost.appendChild(emptyState(
        'Немає матеріалів',
        'Для рівня ' + level + ' аудіювань ще немає. Оберіть інший рівень.',
        { icon: '🎧' }
      ));
      return;
    }
    listHost.appendChild(sectionHeader(
      'Матеріали рівня ' + level,
      plural(items.length, 'матеріал', 'матеріали', 'матеріалів'),
      '🎧'
    ));
    listHost.appendChild(h('div', { class: 'list' }, items.map((item) => listRow(app, item))));
  }

  renderLevels();
  renderList();
  return root;
}

function listRow(app, item) {
  const count = spanishLines(item).length;
  return h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => app.navigate('#/listening/' + item.id)
  }, [
    h('span', { class: 'list-icon', text: reviewed(app, item.id) ? '✅' : '🎧' }),
    h('div', { style: { flex: '1', minWidth: '0' } }, [
      h('div', { class: 'list-title', text: item.titleUk }),
      h('div', { class: 'word-es', text: item.titleEs }),
      h('div', {
        class: 'list-sub',
        text: kindTitle(item.kind) + ' · ' + count + ' ' + plural(count, 'репліка', 'репліки', 'реплік')
      })
    ]),
    levelBadge(item.level)
  ]);
}

// MARK: - Детальний екран

function headerCard(item, count) {
  return card(h('div', { class: 'stack' }, [
    wrapRow([
      levelBadge(item.level),
      h('span', { class: 'muted', text: kindTitle(item.kind) }),
      h('span', { class: 'muted', text: count + ' ' + plural(count, 'репліка', 'репліки', 'реплік') })
    ]),
    h('div', { class: 'session-title', text: item.titleUk }),
    h('div', { class: 'word-es', text: item.titleEs })
  ]));
}

function backLink(app) {
  return h('button', {
    class: 'link-btn',
    type: 'button',
    text: '‹ Усі матеріали',
    onclick: () => app.navigate('#/listening')
  });
}

export function renderListeningDetail(app, { id } = {}) {
  const item = findItem(app, id);
  if (!item) {
    return emptyState('Матеріал не знайдено', 'Можливо, посилання застаріле. Поверніться до списку аудіювань.', {
      icon: '🎧',
      actionTitle: 'До списку',
      onAction: () => app.navigate('#/listening')
    });
  }

  const lines = item.lines || [];
  const questions = item.comprehensionQuestions || [];
  const showByDefault = !app.store.settings.listeningHints;

  const state = {
    showText: showByDefault,
    showTranslation: showByDefault,
    index: 0,
    answers: questions.map(() => -1),
    correct: 0,
    finished: false,
    playing: false,
    ticks: 0,
    timer: null
  };

  const root = h('div', { class: 'stack' });
  const playerHost = h('div', { class: 'stack' });
  const toggleHost = h('div', { class: 'stack' });
  const linesHost = h('div', { class: 'stack' });
  const wordsHost = h('div', { class: 'stack' });
  const quizHost = h('div', { class: 'stack' });
  const actionsHost = h('div', { class: 'stack' });

  root.appendChild(backLink(app));
  root.appendChild(headerCard(item, lines.length));
  root.appendChild(playerHost);
  root.appendChild(toggleHost);
  root.appendChild(linesHost);
  root.appendChild(wordsHost);
  root.appendChild(quizHost);
  root.appendChild(actionsHost);

  // MARK: Програвач

  const status = h('div', { class: 'muted' });
  const stopButton = button('Зупинити', { variant: 'ghost', icon: '⏹', onClick: stopPlayback });

  playerHost.appendChild(wrapRow([
    button('Прослухати', { icon: '▶️', onClick: () => play(false) }),
    button('Повільно', { variant: 'secondary', icon: '🐢', onClick: () => play(true) }),
    stopButton
  ]));
  playerHost.appendChild(status);

  function play(slow) {
    const content = spanishLines(item);
    if (!content.length) {
      toast('У цьому матеріалі немає реплік');
      return;
    }
    if (slow) app.tts.speakLines(content, { rateOverride: 0.6 });
    else app.tts.speakLines(content);
    state.playing = true;
    state.ticks = 0;
    startTimer();
    refreshStatus();
  }

  function stopPlayback() {
    app.tts.stop();
    state.playing = false;
    stopTimer();
    refreshStatus();
  }

  function startTimer() {
    stopTimer();
    state.timer = setInterval(() => {
      if (!root.isConnected) {
        stopTimer();
        return;
      }
      state.ticks += 1;
      if (state.ticks > 2 && !app.tts.speaking) {
        state.playing = false;
        stopTimer();
      }
      refreshStatus();
    }, 400);
  }

  function stopTimer() {
    if (state.timer) clearInterval(state.timer);
    state.timer = null;
  }

  function refreshStatus() {
    // .btn має display: inline-flex, тому атрибут hidden не діє — ховаємо стилем.
    stopButton.style.display = state.playing ? '' : 'none';
    status.textContent = state.playing
      ? 'Відтворюється…'
      : 'Натисніть «Прослухати», щоб почути матеріал.';
  }

  // MARK: Перемикачі тексту й перекладу

  function renderToggles() {
    clear(toggleHost);
    toggleHost.appendChild(wrapRow([
      button(state.showText ? 'Сховати текст' : 'Показати текст', {
        variant: 'secondary',
        onClick: () => {
          state.showText = !state.showText;
          renderToggles();
          renderLines();
        }
      }),
      button(state.showTranslation ? 'Сховати переклад' : 'Показати переклад', {
        variant: 'secondary',
        onClick: () => {
          state.showTranslation = !state.showTranslation;
          renderToggles();
          renderLines();
        }
      })
    ]));
    if (app.store.settings.listeningHints && !state.showText) {
      toggleHost.appendChild(infoBox(
        'Порада',
        'Слухайте без тексту — так тренується розуміння на слух. Відкрийте текст після першої спроби.',
        { tone: 'warning' }
      ));
    }
  }

  // MARK: Репліки

  function renderLines() {
    clear(linesHost);
    if (!lines.length) {
      linesHost.appendChild(infoBox('Порожньо', 'У цьому матеріалі немає реплік.', { tone: 'warning' }));
      return;
    }
    const rows = lines.map((line) => {
      const head = [];
      if (line.speaker) head.push(h('span', { class: 'list-title', text: line.speaker + ':' }));
      if (state.showText) head.push(h('span', { class: 'word-example', text: line.spanish }));
      if (!head.length) head.push(h('span', { class: 'muted', text: 'Репліка прихована' }));

      return h('div', { class: 'row', style: { alignItems: 'flex-start' } }, [
        h('div', { class: 'stack', style: { flex: '1', gap: '6px' } }, [
          h('div', { class: 'row', style: { alignItems: 'baseline', flexWrap: 'wrap' } }, head),
          state.showTranslation && line.translationUk
            ? h('div', { class: 'word-uk', text: line.translationUk })
            : null
        ]),
        speakButton(() => app.speak(line.spanish, true), 'Прослухати репліку')
      ]);
    });
    linesHost.appendChild(card(h('div', { class: 'stack', style: { gap: '14px' } }, rows)));
  }

  // MARK: Ключові слова

  function renderWords() {
    clear(wordsHost);
    const keyWords = item.keyWords || [];
    if (!keyWords.length) return;
    wordsHost.appendChild(sectionHeader('Ключові слова', 'Натисніть на чип, щоб почути', '🔑'));
    wordsHost.appendChild(wrapRow(keyWords.map((word) => chip(
      word.translationUk ? word.spanish + ' — ' + word.translationUk : word.spanish,
      { onClick: () => app.speak(word.spanish, true) }
    ))));
  }

  // MARK: Питання на розуміння

  function optionState(optionIndex, question, chosen) {
    if (chosen < 0) return null;
    if (optionIndex === question.correctIndex) return 'correct';
    if (optionIndex === chosen) return 'wrong';
    return null;
  }

  function selectAnswer(optionIndex) {
    if (state.answers[state.index] >= 0) return;
    state.answers[state.index] = optionIndex;
    if (optionIndex === questions[state.index].correctIndex) state.correct += 1;
    renderQuiz();
  }

  function nextQuestion() {
    if (state.index + 1 < questions.length) {
      state.index += 1;
      renderQuiz();
      return;
    }
    state.finished = true;
    app.store.bumpTodayStat((stat) => ({ listening: (stat.listening || 0) + 1 }));
    renderQuiz();
  }

  function resetQuiz() {
    state.index = 0;
    state.correct = 0;
    state.finished = false;
    state.answers = questions.map(() => -1);
    renderQuiz();
  }

  function renderQuiz() {
    clear(quizHost);
    if (!questions.length) return;
    quizHost.appendChild(sectionHeader(
      'Перевірте розуміння',
      plural(questions.length, 'питання', 'питання', 'питань'),
      '❓'
    ));

    if (state.finished) {
      quizHost.appendChild(infoBox(
        'Результат',
        'Правильно ' + state.correct + ' з ' + questions.length,
        { tone: state.correct === questions.length ? 'success' : 'warning' }
      ));
      quizHost.appendChild(button('Пройти ще раз', { variant: 'ghost', onClick: resetQuiz }));
      return;
    }

    const question = questions[state.index];
    const chosen = state.answers[state.index];
    const answered = chosen >= 0;

    quizHost.appendChild(card(h('div', { class: 'stack' }, [
      h('div', { class: 'list-sub', text: 'Питання ' + (state.index + 1) + ' з ' + questions.length }),
      h('div', { class: 'list-title', text: question.questionUk }),
      h('div', { class: 'stack' }, (question.options || []).map((option, optionIndex) => optionRow(option, {
        state: optionState(optionIndex, question, chosen),
        disabled: answered,
        onClick: () => selectAnswer(optionIndex)
      }))),
      answered && question.explanationUk
        ? infoBox('Пояснення', question.explanationUk, {
          tone: chosen === question.correctIndex ? 'success' : 'warning'
        })
        : null,
      answered
        ? button(state.index + 1 < questions.length ? 'Далі' : 'Завершити', { onClick: nextQuestion })
        : null
    ])));
  }

  // MARK: Повторення

  function renderActions() {
    clear(actionsHost);
    actionsHost.appendChild(button('Додати в повторення', {
      variant: 'secondary',
      icon: '🔁',
      onClick: () => {
        const exists = Boolean(app.store.card(item.id));
        app.store.cardOrCreate(makeItem('listening', item));
        toast(exists ? 'Уже в повторенні' : 'Додано в повторення');
      }
    }));
  }

  refreshStatus();
  renderToggles();
  renderLines();
  renderWords();
  renderQuiz();
  renderActions();
  return root;
}
