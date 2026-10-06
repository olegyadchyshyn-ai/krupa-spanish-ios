// Заняття з інтервальним повторенням: спільний кроковий інтерфейс.
//
// `createSessionView` малює будь-який план (заняття або повторення): кроки,
// перевірку відповіді, розбір і кнопки оцінок SRS; `renderSession` і
// `renderReview` лише складають план. Жодних дій із DOM на верхньому рівні.

import {
  h, clear, button, speakButton, progressBar, infoBox, optionRow, field,
  emptyState, confirmDialog, chip, statTile, formatMinutes, plural, ensureStyles
} from '../ui.js';
import {
  buildPlan, buildReviewPlan, checkItem, gradeFor, exerciseChoices, buildTokens,
  shuffleArray, similarity, itemSpanish, itemIsGraded, SrsEngine, GRADE_INFO, BLOCKS
} from '../store.js';
import { wordsOfLevel } from '../content.js';

// MARK: - Екрани

export function renderSession(app, params) {
  const topicId = (params && params.topicId) || null;
  const plan = buildPlan(app.store, app.content, { topicId });
  return createSessionView(app, plan, {
    title: topicId ? 'Заняття з теми' : 'Заняття',
    emptyTitle: 'На сьогодні все зроблено',
    emptyMessage: 'Повторень немає — можна почати нове заняття.',
    emptyActionTitle: 'До курсу',
    emptyAction: () => app.navigate('#/learn')
  });
}

export function renderReview(app) {
  return createSessionView(app, buildReviewPlan(app.store, app.content), reviewOptions(app));
}

/** Порожній стан повторення — ці самі тексти бере `review.js`. */
export function reviewOptions(app) {
  const snapshot = app.store.snapshot();
  const soon = dueSoon(app.store, 24);
  let emptyMessage = 'Наступні картки з\'являться за розкладом інтервального повторення.';
  if (snapshot.dueToday > 0) {
    emptyMessage = 'Ще в черзі: ' + snapshot.dueToday + ' ' + plural(snapshot.dueToday, 'картка', 'картки', 'карток') + '.';
  } else if (soon > 0) {
    emptyMessage = 'На найближчу добу заплановано ' + soon + ' ' + plural(soon, 'картку', 'картки', 'карток') + '.';
  }
  return {
    title: 'Повторення',
    emptyTitle: 'На сьогодні повторень немає',
    emptyMessage,
    emptyActionTitle: 'До курсу',
    emptyAction: () => app.navigate('#/learn')
  };
}

// MARK: - Кроковий інтерфейс

export function createSessionView(app, plan, options) {
  const opts = options || {};
  const items = (plan && plan.items) || [];
  const settings = app.store.settings;
  const box = el('stack');

  if (!items.length) {
    box.appendChild(emptyState(
      opts.emptyTitle || 'На сьогодні все зроблено',
      opts.emptyMessage || 'Повторень немає — можна почати нове заняття.',
      { icon: '✅', actionTitle: opts.emptyActionTitle || 'До курсу', onAction: opts.emptyAction || (() => app.navigate('#/learn')) }
    ));
    return box;
  }

  ensureSessionStyles();
  const kinds = blockKinds(plan, items);
  const state = {
    index: 0, answer: '', feedback: null, usedHint: false, recommended: null,
    correct: 0, wrong: 0, results: 0, startedAt: Date.now(), sessionStartedAt: Date.now()
  };
  let step = null;
  const speak = (value) => { if (value) app.speak(value, true); };
  const ghost = (title, onClick) => button(title, { variant: 'ghost', onClick });
  const sec = (title, onClick, icon) => button(title, { variant: 'secondary', icon, onClick });

  function prepareStep() {
    const item = items[state.index];
    const data = { item };
    if (item.kind === 'exercise') {
      const ex = item.data;
      if (ex.kind === 'multiple_choice' || ex.kind === 'translation_es_uk') data.choices = exerciseOptions(ex, app);
      else if (ex.kind === 'sentence_build') data.tokens = tokenState(shuffleArray(buildTokens(ex)));
      else if (ex.kind === 'match_pairs') Object.assign(data, prepareMatch(ex, app));
      else if (ex.kind === 'dictation' || ex.kind === 'listening') speak(ex.answerEs);
    } else if (item.kind === 'listening') {
      data.questions = item.data.comprehensionQuestions || [];
      data.answers = [];
      data.question = 0;
      data.chosen = null;
      data.showText = false;
      data.showTranslation = false;
    } else if (item.kind === 'word' || item.kind === 'sentence') {
      if (item.prompt === 'recognize') data.choices = translationChoices(item, app);
      else if (item.prompt === 'buildSentence') data.tokens = tokenState(shuffleArray(sentenceTokens(item)));
      else if (item.prompt === 'listen') speak(spanishText(item));
    }
    return data;
  }

  function render() {
    clear(box);
    if (state.index >= items.length) {
      box.appendChild(buildSummary());
      return;
    }
    if (!step) step = prepareStep();
    appendAll(box, [
      buildTop(),
      ...buildBody(),
      state.feedback ? buildFeedback() : null,
      buildReveal(),
      state.feedback || !itemIsGraded(step.item) ? buildActions() : null
    ]);
  }

  function buildTop() {
    const block = BLOCKS[kinds[state.index]] || { title: 'Заняття', icon: '📖' };
    return el('session-top', [
      el('row-between', [
        text('session-prompt', (opts.title || 'Заняття') + ' · ' + block.icon + ' ' + block.title),
        ghost('Закрити', () => confirmDialog('Закрити заняття? Прогрес збережеться.', () => app.navigate('#/')))
      ]),
      progressBar(state.index / items.length),
      text('session-title', 'Крок ' + (state.index + 1) + ' з ' + items.length)
    ]);
  }

  function buildBody() {
    const item = step.item;
    if (item.kind === 'grammar') return buildGrammarBody(item.data);
    if (item.kind === 'listening') return buildListeningBody(item);
    if (item.kind === 'word' || item.kind === 'sentence') return buildCardBody(item);
    return buildExerciseBody(item.data);
  }

  function buildGrammarBody(note) {
    const nodes = [
      text('session-spanish', note.titleEs),
      text('session-title', note.titleUk),
      infoBox('Схема', note.patternUk),
      note.explanationUk ? text('muted', note.explanationUk) : null
    ];
    const examples = note.examples || [];
    if (examples.length) {
      nodes.push(text('session-prompt', 'Приклади'));
      nodes.push(el('list', examples.map((example) => el('list-item', [
        el('list-body', [
          h('div', { class: 'list-title word-es', text: example.spanish || '' }),
          example.translationUk ? text('list-sub', example.translationUk) : null,
          example.noteUk ? h('div', { class: 'list-sub muted', text: example.noteUk }) : null
        ]),
        speakButton(() => speak(example.spanish))
      ]))));
    }
    nodes.push(infoBox('Типова помилка', note.commonMistakeUk, { tone: 'error' }));
    nodes.push(infoBox('Порада для україномовних', note.tipForUkSpeakersUk, { tone: 'success' }));
    return nodes;
  }

  function buildCardBody(item) {
    const data = item.data;
    const spanish = spanishText(item);
    if (item.prompt === 'recognize') {
      // Для слова показуємо іспанське й обираємо переклад; для речення —
      // навпаки, бо `checkItem` для речень завжди звіряє іспанський текст.
      const isSentence = item.kind === 'sentence';
      return [
        text('session-prompt', isSentence ? 'Оберіть іспанське речення' : 'Оберіть переклад'),
        el('row-between', [
          isSentence ? text('session-title', data.translationUk) : text('session-spanish', spanish),
          isSentence ? null : speakButton(() => speak(spanish))
        ]),
        buildOptions(step.choices, recognizeCorrect(item))
      ];
    }
    if (item.prompt === 'listen') {
      return [
        text('session-prompt', 'Прослухайте та напишіть іспанською'),
        sec('Повторити', () => { state.usedHint = true; speak(spanish); }, '🔊'),
        buildInput('Напишіть, що почули…')
      ];
    }
    if (item.prompt === 'buildSentence') {
      return [
        text('session-prompt', 'Складіть речення зі слів'),
        text('session-title', sentenceHint(item)),
        buildTokensView()
      ];
    }
    const nodes = [text('session-prompt', 'Напишіть іспанською'), text('session-title', data.translationUk)];
    if (data.partOfSpeech) nodes.push(text('muted', 'Частина мови: ' + data.partOfSpeech));
    nodes.push(buildInput('Напишіть іспанською…'));
    return nodes;
  }

  function buildExerciseBody(ex) {
    const prompt = ex.promptUk || '';
    switch (ex.kind) {
      case 'multiple_choice':
      case 'translation_es_uk':
        return [
          ex.kind === 'translation_es_uk' && ex.promptEs
            ? el('row-between', [text('session-spanish', ex.promptEs), speakButton(() => speak(ex.promptEs))])
            : null,
          text('session-prompt', prompt || 'Оберіть правильний варіант'),
          buildOptions(step.choices, ex.answerUk || ex.answerEs)
        ];
      case 'translation_uk_es':
        return [text('session-prompt', prompt || 'Перекладіть іспанською'), buildInput('Напишіть іспанською…')];
      case 'dictation':
        return [
          text('session-prompt', prompt || 'Прослухайте й запишіть речення'),
          audioButton('Прослухати ще раз', ex.answerEs),
          buildInput('Напишіть, що почули…')
        ];
      case 'fill_gap':
        return [
          text('session-prompt', prompt || 'Вставте пропущене слово'),
          text('session-spanish', gapSentence(ex)),
          buildInput('Впишіть пропущене слово…')
        ];
      case 'sentence_build':
        return [
          text('session-prompt', prompt || 'Складіть речення зі слів'),
          ex.answerUk ? text('session-title', ex.answerUk) : null,
          buildTokensView()
        ];
      case 'match_pairs':
        return [text('session-prompt', prompt || 'Зіставте пари'), buildPairsBody()];
      case 'listening':
        return [
          text('session-prompt', prompt || 'Прослухайте та напишіть'),
          audioButton('Прослухати', ex.answerEs),
          buildInput('Напишіть, що почули…')
        ];
      case 'speaking':
        return buildSpeakingBody(ex);
      default:
        return [text('session-prompt', prompt || 'Дайте відповідь'), buildInput('Ваша відповідь…')];
    }
  }

  function audioButton(title, value) {
    return sec(title, () => { state.usedHint = true; speak(value); }, '🔊');
  }

  // MARK: Відповідь, токени, пари

  function buildInput(placeholder) {
    const answered = Boolean(state.feedback);
    const input = field(placeholder, {
      value: state.answer,
      onInput: (value) => { state.answer = value; },
      onSubmit: (value) => submitAnswer(value)
    });
    if (answered) input.disabled = true;
    return el('composer', [input, answered ? null : button('Перевірити', { onClick: () => submitAnswer(input.value) })]);
  }

  function buildOptions(options, correctText) {
    const answered = Boolean(state.feedback);
    return el('stack', (options || []).map((value) => optionRow(value, {
      state: answered
        ? (value === correctText ? 'correct' : value === state.answer ? 'wrong' : null)
        : (value === state.answer ? 'selected' : null),
      disabled: answered,
      onClick: () => submitAnswer(value)
    })));
  }

  function buildTokensView() {
    const tokens = step.tokens;
    const answered = Boolean(state.feedback);
    const token = (word, index) => h('button', {
      class: 'token' + (tokens.picked.includes(index) ? ' token-used' : ''),
      type: 'button',
      disabled: answered,
      text: word,
      onclick: () => toggleToken(index)
    });
    const nodes = [
      el('tokens', tokens.pool.map(token)),
      el('answer-line', tokens.picked.length
        ? tokens.picked.map((index) => token(tokens.pool[index], index))
        : text('muted', 'Натискайте слова — вони з\'являться тут.'))
    ];
    if (!answered) {
      nodes.push(el('row', [
        button('Перевірити', { onClick: () => submitAnswer(tokensAnswer()) }),
        ghost('Очистити', () => { tokens.picked = []; render(); })
      ]));
    }
    return el('stack', nodes);
  }

  function tokensAnswer() {
    return step.tokens.picked.map((index) => step.tokens.pool[index]).join(' ');
  }

  function toggleToken(index) {
    if (state.feedback) return;
    const picked = step.tokens.picked;
    step.tokens.picked = picked.includes(index) ? picked.filter((value) => value !== index) : picked.concat(index);
    render();
  }

  /** Дві колонки: іспанське слово ↔ українське значення (і дистрактори). */
  function buildPairsBody() {
    const answered = Boolean(state.feedback);
    const column = (list, side, picked) => el('pair-col', list.map((entry) => {
      const value = side === 'es' ? entry.es : entry.uk;
      const done = side === 'es' ? step.matched.includes(entry.es) : Boolean(entry.key && step.matched.includes(entry.key));
      return h('button', {
        class: 'pair-item' + (done ? ' pair-done' : picked === value ? ' pair-active' : ''),
        type: 'button',
        disabled: answered || done,
        text: value,
        onclick: () => pickPair(side, value)
      });
    }));
    return el('pairs', [column(step.pairs, 'es', step.pickedLeft), column(step.right, 'uk', step.pickedRight)]);
  }

  function pickPair(side, value) {
    if (state.feedback) return;
    if (side === 'es') step.pickedLeft = step.pickedLeft === value ? null : value;
    else step.pickedRight = step.pickedRight === value ? null : value;
    if (!step.pickedLeft || !step.pickedRight) {
      render();
      return;
    }
    const option = step.right.find((entry) => entry.uk === step.pickedRight);
    if (option && option.key === step.pickedLeft) {
      step.matched.push(step.pickedLeft);
      if (step.matched.length >= step.pairs.length) {
        submitAnswer(step.answerForCheck, {
          message: 'Усі пари зібрано!',
          correct: true,
          recommended: state.usedHint ? 'HARD' : 'GOOD'
        });
        return;
      }
    } else {
      state.usedHint = true;
      app.toast('Не так — спробуйте іншу пару');
    }
    step.pickedLeft = null;
    step.pickedRight = null;
    render();
  }

  // MARK: Говоріння

  function buildSpeakingBody(ex) {
    const answer = ex.answerEs || '';
    const nodes = [
      text('session-prompt', ex.promptUk || 'Скажіть уголос'),
      el('row-between', [text('session-spanish', answer), speakButton(() => speak(answer))])
    ];
    if (state.feedback) return nodes;
    nodes.push(sec('Прослухати зразок', () => speak(answer), '🔊'));
    const Recognition = speechRecognition();
    if (Recognition) {
      nodes.push(button(step.recording ? 'Слухаю…' : 'Записати', {
        icon: '🎤',
        disabled: Boolean(step.recording),
        onClick: () => startRecognition(Recognition, answer)
      }));
      if (step.transcript) nodes.push(text('muted', 'Почуто: ' + step.transcript));
      return nodes;
    }
    nodes.push(text('session-prompt', 'Вимовте вголос, потім оцініть себе'));
    nodes.push(el('row', [
      sec('Правильно', () => submitAnswer(answer, {
        message: 'Так тримати!', correct: true, recommended: state.usedHint ? 'HARD' : 'GOOD'
      })),
      ghost('Ще раз', () => { state.usedHint = true; speak(answer); })
    ]));
    return nodes;
  }

  function startRecognition(Recognition, answer) {
    const recognition = new Recognition();
    recognition.lang = 'es-ES';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    step.recording = true;
    render();
    recognition.onresult = (event) => {
      const transcript = (event.results && event.results[0] && event.results[0][0].transcript) || '';
      step.recording = false;
      step.transcript = transcript;
      const result = checkSpeech(step.item, transcript, answer);
      submitAnswer(transcript, { correct: result.correct, message: result.message });
    };
    recognition.onerror = () => { step.recording = false; app.toast('Не вдалося розпізнати мовлення'); render(); };
    recognition.onend = () => { if (step.recording) { step.recording = false; render(); } };
    try { recognition.start(); } catch (error) { step.recording = false; }
  }

  // MARK: Аудіювання (діалог)

  function buildListeningBody(item) {
    const data = item.data;
    const lines = data.lines || [];
    const speakLines = (rate) => app.tts.speakLines(lines.map((line) => line.spanish), rate ? { rateOverride: rate } : undefined);
    const toggle = (key) => () => {
      step[key] = !step[key];
      if (step.answers.length < step.questions.length) state.usedHint = true;
      render();
    };
    const nodes = [
      text('session-prompt', 'Аудіювання'),
      text('session-title', data.titleUk),
      text('session-spanish', data.titleEs),
      el('row', [button('Прослухати діалог', { icon: '🎧', onClick: () => speakLines(0) }), sec('Повільно', () => speakLines(0.6))]),
      el('row', [
        ghost(step.showText ? 'Сховати текст' : 'Показати текст', toggle('showText')),
        ghost(step.showTranslation ? 'Сховати переклад' : 'Показати переклад', toggle('showTranslation'))
      ]),
      el('list', lines.map((line) => el('list-item', [
        el('list-body', [
          text('session-prompt', line.speaker),
          step.showText ? h('div', { class: 'list-title word-es', text: line.spanish || '' }) : text('list-sub', '•••'),
          step.showTranslation ? text('list-sub', line.translationUk) : null
        ]),
        speakButton(() => speak(line.spanish))
      ])))
    ];
    const keyWords = data.keyWords || [];
    if (keyWords.length && settings.listeningHints !== false) {
      nodes.push(text('session-prompt', 'Ключові слова'));
      nodes.push(el('tokens', keyWords.map((word) => chip(
        word.spanish + (word.translationUk ? ' — ' + word.translationUk : ''),
        { onClick: () => speak(word.spanish) }
      ))));
    }
    return nodes.concat(buildQuestions());
  }

  function buildQuestions() {
    const questions = step.questions;
    const index = step.question;
    if (!questions.length) return [button('Діалог прослухано', { onClick: finishListening })];
    const question = questions[index];
    const answered = typeof step.answers[index] === 'boolean';
    const nodes = [
      text('session-prompt', 'Питання ' + (index + 1) + ' з ' + questions.length),
      text('session-title', question.questionUk),
      el('stack', (question.options || []).map((value, optionIndex) => optionRow(value, {
        state: answered
          ? (optionIndex === question.correctIndex ? 'correct' : step.chosen === optionIndex ? 'wrong' : null)
          : (step.chosen === optionIndex ? 'selected' : null),
        disabled: answered,
        onClick: () => {
          step.chosen = optionIndex;
          step.answers[index] = optionIndex === question.correctIndex;
          render();
        }
      })))
    ];
    if (!answered) return nodes;
    if (question.explanationUk) nodes.push(text('muted', question.explanationUk));
    const last = index + 1 >= questions.length;
    nodes.push(button(last ? 'Завершити' : 'Наступне питання', {
      onClick: () => {
        if (last) finishListening();
        else { step.question += 1; step.chosen = null; render(); }
      }
    }));
    return nodes;
  }

  function finishListening() {
    const total = step.questions.length;
    const right = step.answers.filter(Boolean).length;
    submitAnswer(itemSpanish(step.item) || '', {
      correct: !total || right === total,
      message: total ? 'Правильно ' + right + ' з ' + total : 'Діалог прослухано',
      correctAnswer: '',
      recommended: !total || right === total ? 'GOOD' : right * 2 >= total ? 'HARD' : 'AGAIN'
    });
  }

  // MARK: Розбір, оцінки, підсумок

  function submitAnswer(value, overrides) {
    if (state.feedback) return;
    const patch = overrides || {};
    state.answer = value == null ? '' : String(value);
    const result = evaluate(step.item, state.answer);
    state.feedback = {
      correct: typeof patch.correct === 'boolean' ? patch.correct : result.correct,
      message: patch.message || result.message,
      correctAnswer: patch.correctAnswer !== undefined ? patch.correctAnswer : (result.correctAnswer || ''),
      explanation: result.explanation || ''
    };
    if (patch.recommended) state.recommended = patch.recommended;
    else if (!state.recommended) {
      state.recommended = state.feedback.correct ? (state.usedHint ? 'HARD' : 'GOOD') : 'AGAIN';
    }
    render();
  }

  function buildFeedback() {
    const feedback = state.feedback;
    return el('feedback ' + (feedback.correct ? 'feedback-correct' : 'feedback-wrong'), [
      text('feedback-title', feedback.message || (feedback.correct ? 'Правильно!' : 'Не зовсім')),
      feedback.correctAnswer ? text('muted', 'Правильна відповідь: ' + feedback.correctAnswer) : null,
      feedback.explanation ? text('muted', feedback.explanation) : null
    ]);
  }

  function buildReveal() {
    const item = step.item;
    if (!state.feedback || (item.kind !== 'word' && item.kind !== 'sentence')) return null;
    const data = item.data;
    const nodes = [];
    if (data.exampleEs && data.exampleEs !== state.feedback.explanation) {
      nodes.push(infoBox('Приклад', data.exampleEs + (data.exampleUk ? ' — ' + data.exampleUk : '')));
    }
    if (item.kind === 'sentence' && data.audioHint) nodes.push(infoBox('Підказка вимови', data.audioHint));
    if (item.kind === 'word' && settings.showPronunciationHints && data.pronunciation) {
      nodes.push(infoBox('Вимова', data.pronunciation));
    }
    if (item.kind === 'word' && settings.showIpa && data.ipaHint) nodes.push(infoBox('Наголос та IPA', data.ipaHint));
    if (data.notesUk && data.notesUk !== state.feedback.explanation) nodes.push(infoBox('Нотатка', data.notesUk));
    if (data.cognateNoteUk) nodes.push(infoBox('Схоже на українське', data.cognateNoteUk, { tone: 'success' }));
    return nodes.length ? el('stack', nodes) : null;
  }

  function buildActions() {
    const item = step.item;
    if (!itemIsGraded(item)) {
      return el('stack', [
        text('muted', 'Довідкова картка — оцінки немає.'),
        button('Далі', { onClick: () => advance(null) })
      ]);
    }
    const previews = SrsEngine.previews(app.store.cardOrCreate(item));
    const recommended = state.recommended || gradeFor(item, state.answer, state.usedHint);
    return el('stack', [
      text('session-prompt', 'Оцініть, як було (натисніть, щоб змінити)'),
      el('grades', previews.map((preview) => h('button', {
        class: 'grade-btn grade-' + preview.grade + (preview.grade === recommended ? ' grade-recommended' : ''),
        type: 'button',
        'aria-label': GRADE_INFO[preview.grade].title,
        onclick: () => advance(preview.grade)
      }, [
        h('span', { class: 'grade-symbol', text: preview.symbol }),
        h('span', { class: 'grade-label', text: preview.label }),
        h('span', { class: 'grade-interval', text: preview.interval })
      ])))
    ]);
  }

  function advance(grade) {
    if (grade) {
      app.store.recordAnswer(step.item, grade, Date.now() - state.startedAt, state.usedHint);
      state.results += 1;
      if (GRADE_INFO[grade].correct) state.correct += 1;
      else state.wrong += 1;
    }
    state.index += 1;
    state.answer = '';
    state.feedback = null;
    state.usedHint = false;
    state.recommended = null;
    state.startedAt = Date.now();
    step = null;
    render();
  }

  function buildSummary() {
    const accuracy = state.results ? Math.round((state.correct / state.results) * 100) + '%' : '—';
    return el('stack', [
      h('div', { class: 'gradient-header' }, [
        text('section-title', 'Заняття завершено'),
        text('muted', 'Опрацьовано ' + items.length + ' ' + plural(items.length, 'крок', 'кроки', 'кроків'))
      ]),
      el('grid-2', [
        statTile('Правильно', state.correct, '✓'),
        statTile('Помилок', state.wrong, '✕'),
        statTile('Точність', accuracy, '🎯'),
        statTile('Час', formatMinutes((Date.now() - state.sessionStartedAt) / 60000), '⏱')
      ]),
      button('Ще заняття', { onClick: () => app.navigate('#/session') }),
      button('Завершити', { variant: 'secondary', onClick: () => app.navigate('#/') })
    ]);
  }

  render();
  return box;
}

// MARK: - Дрібні хелпери DOM

function el(className, children) {
  return h('div', { class: className }, children);
}

function text(className, value) {
  return h('div', { class: className, text: value == null ? '' : String(value) });
}

function appendAll(parent, children) {
  for (const child of children || []) if (child) parent.appendChild(child);
}

/** Який блок плану відповідає кожному кроку (для назви у шапці). */
function blockKinds(plan, items) {
  const kinds = new Array(items.length).fill('REVIEW');
  let cursor = 0;
  for (const block of (plan && plan.blocks) || []) {
    for (const item of block.items || []) {
      if (cursor >= kinds.length) break;
      kinds[cursor] = block.kind;
      cursor += 1;
    }
  }
  return kinds;
}

function ensureSessionStyles() {
  ensureStyles('session-extra-styles', [
    '.grade-btn.grade-recommended { outline: 3px solid var(--text); outline-offset: 2px; }',
    '.list-body { flex: 1; }',
    '.answer-line .token { padding: 6px 10px; }'
  ].join('\n'));
}

// MARK: - Дані кроку

function spanishText(item) {
  if (item.kind === 'word' && item.prompt === 'recognize') return itemSpanish(item);
  return item.data.spanish || item.data.answerEs || '';
}

function sentenceTokens(item) {
  const value = item.kind === 'word' ? (item.data.exampleEs || item.data.spanish) : item.data.spanish;
  return String(value || '').split(' ').filter(Boolean);
}

function sentenceHint(item) {
  if (item.kind === 'word') return item.data.exampleUk || item.data.translationUk || '';
  return item.data.translationUk || '';
}

/** Що вважається правильною відповіддю на кроці «оберіть варіант». */
function recognizeCorrect(item) {
  return item.kind === 'sentence' ? (item.data.spanish || '') : (item.data.translationUk || '');
}

/** Чотири варіанти: правильна відповідь і три чужі елементи того ж рівня. */
function translationChoices(item, app) {
  const data = item.data;
  const correct = recognizeCorrect(item);
  const pool = item.kind === 'word'
    ? wordsOfLevel(app.content, data.level).map((word) => word.translationUk)
    : (app.content.sentences || []).filter((sentence) => sentence.level === data.level).map((sentence) => sentence.spanish);
  const options = [];
  for (const value of shuffleArray(pool)) {
    if (options.length >= 3) break;
    if (value && value !== correct && options.indexOf(value) === -1) options.push(value);
  }
  return shuffleArray([correct].concat(options));
}

/** Варіанти вправ із вибором; якщо дистракторів немає — добираємо з інших вправ рівня. */
function exerciseOptions(exercise, app) {
  const choices = exerciseChoices(exercise, true);
  if (choices.length >= 2) return choices;
  const correct = exercise.answerUk || exercise.answerEs;
  const pool = (app.content.exercises || [])
    .filter((entry) => entry.id !== exercise.id && entry.level === exercise.level)
    .map((entry) => entry.answerUk)
    .filter((value) => value && value !== correct && choices.indexOf(value) === -1);
  return shuffleArray(choices.concat(shuffleArray(pool).slice(0, 3)));
}

function gapSentence(exercise) {
  const value = String(exercise.gapText || exercise.answerEs || '');
  const answer = String(exercise.gapAnswer || '');
  if (answer && value.indexOf(answer) !== -1) return value.split(answer).join('____');
  return value.indexOf('__') !== -1 ? value : value + ' ____';
}

function tokenState(pool) {
  return { pool: (pool || []).filter(Boolean), picked: [] };
}

/**
 * Пари для `match_pairs`: слова з `relatedWordIds` (іспанське ↔ українське)
 * та дистрактори; якщо слів немає — беремо `answerEs`/`answerUk` вправи.
 */
function prepareMatch(exercise, app) {
  const pairs = [];
  for (const id of exercise.relatedWordIds || []) {
    const word = app.content.wordById.get(id);
    if (word && word.spanish && word.translationUk) pairs.push({ es: word.spanish, uk: word.translationUk });
  }
  if (pairs.length < 2) {
    pairs.length = 0;
    if (exercise.answerEs && exercise.answerUk) pairs.push({ es: exercise.answerEs, uk: exercise.answerUk });
  }
  if (!pairs.length) {
    pairs.push({ es: exercise.answerEs || exercise.promptEs || '—', uk: exercise.answerUk || exercise.promptUk || '—' });
  }
  const extras = (exercise.distractors || []).filter(Boolean);
  if (!extras.length) {
    const pool = wordsOfLevel(app.content, exercise.level)
      .map((word) => word.translationUk)
      .filter((uk) => uk && !pairs.some((pair) => pair.uk === uk));
    extras.push(...shuffleArray(pool).slice(0, Math.max(2, pairs.length)));
  }
  const right = shuffleArray(pairs.map((pair) => ({ uk: pair.uk, key: pair.es })).concat(extras.map((uk) => ({ uk, key: null }))));
  return {
    pairs: pairs,
    right: right,
    matched: [],
    pickedLeft: null,
    pickedRight: null,
    answerForCheck: exercise.answerEs || exercise.answerUk || pairs[0].es
  };
}

function speechRecognition() {
  if (typeof window === 'undefined') return null;
  return window.SpeechRecognition || window.webkitSpeechRecognition || null;
}

/** Розпізнане мовлення буває без наголосів — приймаємо близький збіг. */
function checkSpeech(item, transcript, expected) {
  const result = checkItem(item, transcript);
  if (result.correct) return result;
  if (expected && similarity(transcript, expected) >= 78) {
    return { correct: true, message: 'Розпізнано — майже точно!', correctAnswer: expected, explanation: result.explanation };
  }
  return result;
}

/**
 * `checkItem` для слова знає лише `spanish`, тому складання речення з
 * `word.exampleEs` перевіряємо як речення — через той самий `checkItem`.
 */
function evaluate(item, answer) {
  if (item.kind === 'word' && item.prompt === 'buildSentence' && item.data.exampleEs) {
    return checkItem({
      kind: 'sentence',
      data: { spanish: item.data.exampleEs, translationUk: item.data.exampleUk, audioHint: item.data.exampleUk }
    }, answer);
  }
  return checkItem(item, answer);
}

function dueSoon(store, hours) {
  const now = Date.now();
  const limit = now + hours * 3600000;
  return Object.values(store.cards || {})
    .filter((card) => !card.suspended && card.dueAt > now && card.dueAt <= limit)
    .length;
}
