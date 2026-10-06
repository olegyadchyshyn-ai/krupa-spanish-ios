// Тренування вимови: зразок озвучення, розпізнавання мовлення й оцінка схожості.
//
// Web Speech API є не в усіх браузерах (Safari на iPhone часто без нього),
// тому завжди є резервний шлях — самооцінка «Правильно» / «Ще раз».

import { wordsOfLevel, sentencesOfLevel, normalizeLoose } from '../content.js';
import { similarity, shuffleArray } from '../store.js';
import {
  h, clear, card, sectionHeader, button, speakButton, chip, field,
  statTile, infoBox, emptyState, toast
} from '../ui.js';

const SESSION_SIZE = 20;

const MODES = [
  { id: 'words', title: 'Слова' },
  { id: 'sentences', title: 'Речення' },
  { id: 'custom', title: 'Своя фраза' }
];

function recognitionCtor() {
  if (typeof window === 'undefined') return null;
  return window.SpeechRecognition || window.webkitSpeechRecognition || null;
}

function segmented(activeId, onSelect) {
  return h('div', { class: 'segmented' }, MODES.map((mode) => h('button', {
    class: 'segmented-item' + (mode.id === activeId ? ' active' : ''),
    type: 'button',
    text: mode.title,
    onclick: () => onSelect(mode.id)
  })));
}

function wordEntry(word) {
  return {
    id: word.id, spanish: word.spanish, translationUk: word.translationUk || '',
    pronunciation: word.pronunciation || '', ipaHint: word.ipaHint || ''
  };
}

function sentenceEntry(sentence) {
  return {
    id: sentence.id, spanish: sentence.spanish,
    translationUk: sentence.translationUk || '', pronunciation: '', ipaHint: ''
  };
}

function wordsOf(text) {
  return normalizeLoose(text).split(' ').filter(Boolean);
}

/** Порівнює почуте з очікуваним: схожість звучання та збіг слів. */
function metrics(expected, heard) {
  const expectedWords = wordsOf(expected);
  const heardWords = new Set(wordsOf(heard));
  const matched = expectedWords.filter((word) => heardWords.has(word)).length;
  return {
    sound: Math.max(0, Math.min(100, similarity(expected, heard))),
    matched,
    total: expectedWords.length,
    wordScore: expectedWords.length ? (matched / expectedWords.length) * 100 : 0
  };
}

function recognitionErrorText(code) {
  if (code === 'not-allowed' || code === 'service-not-allowed') {
    return 'Немає доступу до мікрофона. Дозвольте його в налаштуваннях браузера.';
  }
  if (code === 'no-speech') return 'Мовлення не почуто — спробуйте ще раз ближче до мікрофона.';
  if (code === 'audio-capture') return 'Мікрофон недоступний на цьому пристрої.';
  if (code === 'network') return 'Розпізнавання потребує з’єднання з інтернетом.';
  return 'Не вдалося розпізнати мовлення. Оцініть себе самі.';
}

export function renderSpeaking(app) {
  const state = {
    mode: 'words', queue: [], index: 0, custom: '', showTranslation: false,
    heard: '', interim: '', result: null, error: '', recognizing: false,
    recognition: null, micTimer: null, done: 0, scored: 0, scoreSum: 0
  };
  const supported = Boolean(recognitionCtor());
  const root = h('div', { class: 'stack' });
  const modesHost = h('div', {});
  const statsHost = h('div', {});
  const phraseHost = h('div', { class: 'stack' });
  const actionHost = h('div', { class: 'stack' });
  const resultHost = h('div', { class: 'stack' });
  const micFill = h('div', { class: 'mic-fill' });
  const micBar = h('div', { class: 'mic-bar' }, [micFill]);
  root.appendChild(statsHost);
  root.appendChild(h('div', { class: 'stack' }, [
    sectionHeader('Джерело фраз', 'Оберіть, що тренувати', '🎚️'),
    modesHost
  ]));
  root.appendChild(phraseHost);
  root.appendChild(actionHost);
  root.appendChild(resultHost);

  // MARK: Фрази

  function currentEntry() {
    if (state.mode === 'custom') {
      const text = state.custom.trim();
      if (!text) return null;
      return { id: 'custom', spanish: text, translationUk: '', pronunciation: '', ipaHint: '' };
    }
    return state.queue[state.index] || null;
  }

  function reloadQueue() {
    const level = app.store.profile.level;
    if (state.mode === 'words') {
      state.queue = shuffleArray(wordsOfLevel(app.content, level)).slice(0, SESSION_SIZE).map(wordEntry);
    } else if (state.mode === 'sentences') {
      state.queue = shuffleArray(sentencesOfLevel(app.content, level)).slice(0, SESSION_SIZE).map(sentenceEntry);
    } else {
      state.queue = [];
    }
    state.index = 0;
  }

  function resetAttempt() {
    state.heard = '';
    state.interim = '';
    state.result = null;
    state.error = '';
  }

  function setMode(mode) {
    if (state.mode === mode) return;
    abortRecognition();
    state.mode = mode;
    state.showTranslation = false;
    resetAttempt();
    reloadQueue();
    renderAll();
  }

  function nextPhrase() {
    abortRecognition();
    state.showTranslation = false;
    resetAttempt();
    if (state.mode !== 'custom') {
      state.index += 1;
      if (state.index >= state.queue.length) reloadQueue();
    }
    renderAll();
  }

  // MARK: Озвучення

  function speakSlow(text) {
    // app.speak не приймає швидкості, тому додатково просимо tts повільніше.
    app.speak(text, true);
    app.tts.speak(text, { rateOverride: 0.6 });
  }

  // MARK: Оцінка

  function finishAttempt(score, heard, selfAssessed) {
    const entry = currentEntry();
    if (!entry) return;
    const data = heard ? metrics(entry.spanish, heard) : null;
    const finalScore = Math.max(0, Math.min(100, data ? data.sound : score));
    state.result = {
      score: finalScore, sound: Math.round(finalScore),
      matched: data ? data.matched : 0, total: data ? data.total : 0,
      wordScore: data ? Math.round(data.wordScore) : 0, heard: heard || '',
      expected: entry.spanish, selfAssessed: Boolean(selfAssessed)
    };
    state.done += 1;
    state.scored += 1;
    state.scoreSum += finalScore;
    app.store.bumpTodayStat((stat) => ({ speaking: (stat.speaking || 0) + 1 }));
    renderStats();
    renderResult();
  }

  /** Резервний шлях: фіксуємо спробу без оцінки й пропонуємо повторити. */
  function retryAttempt() {
    abortRecognition();
    state.done += 1;
    app.store.bumpTodayStat((stat) => ({ speaking: (stat.speaking || 0) + 1 }));
    resetAttempt();
    renderStats();
    renderActions();
    renderResult();
    toast('Спробу зараховано — повторіть фразу');
  }

  function selfAssess(score) {
    finishAttempt(score, '', true);
    renderActions();
  }

  // MARK: Запис і розпізнавання

  function startRecording() {
    const Ctor = recognitionCtor();
    if (!Ctor || !currentEntry()) return;
    abortRecognition();
    resetAttempt();
    let recognition;
    try {
      recognition = new Ctor();
    } catch (error) {
      state.error = 'Не вдалося запустити розпізнавання мовлення.';
      renderActions();
      return;
    }

    recognition.lang = 'es-ES';
    recognition.interimResults = true;
    recognition.continuous = false;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
      let interim = '';
      let finalText = '';
      for (let i = event.resultIndex; i < event.results.length; i += 1) {
        const result = event.results[i];
        const transcript = result[0] ? result[0].transcript : '';
        if (result.isFinal) finalText += ' ' + transcript;
        else interim += ' ' + transcript;
      }
      if (finalText.trim()) state.heard = (state.heard + ' ' + finalText).trim();
      state.interim = interim.trim();
      renderActions();
    };
    recognition.onerror = (event) => {
      state.recognizing = false;
      stopPulse();
      state.error = recognitionErrorText(event && event.error);
      renderActions();
    };
    recognition.onend = () => {
      state.recognizing = false;
      stopPulse();
      const heard = (state.heard || state.interim || '').trim();
      if (!state.result && heard) finishAttempt(0, heard, false);
      else if (!state.result) state.error = 'Нічого не почули. Спробуйте ще раз ближче до мікрофона.';
      renderActions();
    };
    state.recognition = recognition;
    state.recognizing = true;
    try {
      recognition.start();
    } catch (error) {
      state.recognizing = false;
      state.error = 'Мікрофон зайнятий — закрийте інші застосунки.';
      renderActions();
      return;
    }
    startPulse();
    renderActions();
  }

  function stopRecording() {
    const recognition = state.recognition;
    state.recognizing = false;
    stopPulse();
    if (recognition) {
      try {
        recognition.stop();
      } catch (error) {
        // Уже зупинено — нічого не робимо.
      }
    }
    renderActions();
  }
  function abortRecognition() {
    const recognition = state.recognition;
    state.recognizing = false;
    state.recognition = null;
    stopPulse();
    if (!recognition) return;
    recognition.onresult = null;
    recognition.onerror = null;
    recognition.onend = null;
    try {
      recognition.abort();
    } catch (error) {
      // Розпізнавання вже завершено.
    }
  }

  // Web Speech API не дає рівня сигналу, тому показуємо рівномірне пульсування.
  function startPulse() {
    stopPulse();
    const startedAt = Date.now();
    state.micTimer = setInterval(() => {
      if (!root.isConnected) {
        abortRecognition();
        return;
      }
      if (!state.recognizing) {
        stopPulse();
        return;
      }
      const level = 0.35 + 0.5 * Math.abs(Math.sin((Date.now() - startedAt) / 280));
      micFill.style.width = Math.round(level * 100) + '%';
    }, 120);
  }

  function stopPulse() {
    if (state.micTimer) clearInterval(state.micTimer);
    state.micTimer = null;
    micFill.style.width = '0%';
  }

  // MARK: Рендер

  function renderModes() {
    clear(modesHost);
    modesHost.appendChild(segmented(state.mode, setMode));
  }

  function renderStats() {
    clear(statsHost);
    const average = state.scored ? Math.round(state.scoreSum / state.scored) : 0;
    statsHost.appendChild(h('div', { class: 'grid-2' }, [
      statTile('Фраз опрацьовано', state.done, '🎤'),
      statTile('Середня оцінка', state.scored ? average + ' / 100' : '—', '⭐')
    ]));
  }

  function customField() {
    return field('Наприклад: Me gusta mucho el café', {
      value: state.custom,
      onInput: (value) => {
        state.custom = value;
      },
      onSubmit: (value) => {
        state.custom = value;
        resetAttempt();
        renderAll();
      }
    });
  }

  function phraseCard(entry) {
    const hints = [];
    if (app.store.settings.showPronunciationHints && entry.pronunciation) {
      hints.push(chip('Вимова: ' + entry.pronunciation));
    }
    if (app.store.settings.showIpa && entry.ipaHint) hints.push(chip('[' + entry.ipaHint + ']'));
    return card(h('div', { class: 'stack' }, [
      h('div', { class: 'session-prompt', text: 'Повторіть за зразком' }),
      h('div', { class: 'session-spanish', text: entry.spanish }),
      h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
        speakButton(() => app.speak(entry.spanish, true), 'Зразок'),
        button('Повільно', { variant: 'secondary', onClick: () => speakSlow(entry.spanish) }),
        entry.translationUk
          ? button(state.showTranslation ? 'Сховати переклад' : 'Показати переклад', {
            variant: 'secondary',
            onClick: () => {
              state.showTranslation = !state.showTranslation;
              renderPhrase();
            }
          })
          : null
      ]),
      state.showTranslation && entry.translationUk ? infoBox('Переклад', entry.translationUk) : null,
      hints.length ? h('div', { class: 'row', style: { flexWrap: 'wrap' } }, hints) : null
    ]));
  }

  function renderPhrase() {
    clear(phraseHost);
    if (state.mode === 'custom') {
      phraseHost.appendChild(card(h('div', { class: 'stack' }, [
        h('div', { class: 'list-title', text: 'Своя фраза' }),
        h('div', { class: 'list-sub', text: 'Напишіть фразу іспанською — і тренуйте її вимову.' }),
        customField()
      ])));
    }
    const entry = currentEntry();
    if (!entry) {
      const message = state.mode === 'custom'
        ? 'Введіть фразу вище, щоб почати тренування.'
        : 'Для рівня ' + app.store.profile.level + ' немає матеріалу. Спробуйте інший рівень.';
      phraseHost.appendChild(emptyState('Немає фраз', message, { icon: '🎤' }));
      return;
    }
    phraseHost.appendChild(phraseCard(entry));
  }

  function selfAssessmentRow() {
    return h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
      button('Правильно', { onClick: () => selfAssess(100) }),
      button('Ще раз', { variant: 'secondary', onClick: retryAttempt })
    ]);
  }

  function renderActions() {
    clear(actionHost);
    if (!currentEntry()) return;
    if (state.error) actionHost.appendChild(infoBox('Мікрофон', state.error, { tone: 'error' }));
    if (!supported) {
      actionHost.appendChild(infoBox(
        'Самооцінка',
        'Розпізнавання мовлення недоступне в цьому браузері — оцініть себе самі',
        { tone: 'warning' }
      ));
      actionHost.appendChild(selfAssessmentRow());
      return;
    }

    micBar.style.display = state.recognizing ? '' : 'none';
    actionHost.appendChild(micBar);
    const heard = (state.heard + ' ' + state.interim).trim();
    if (state.recognizing || heard) {
      actionHost.appendChild(h('div', {
        class: 'center muted',
        text: heard ? 'Почуто: ' + heard : 'Слухаємо… говоріть іспанською'
      }));
    }

    actionHost.appendChild(h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
      state.recognizing
        ? button('Зупинити', { variant: 'danger', icon: '⏹', onClick: stopRecording })
        : button('Записати', { icon: '🎤', onClick: startRecording })
    ]));

    if (state.error) actionHost.appendChild(selfAssessmentRow());
  }

  function renderResult() {
    clear(resultHost);
    const result = state.result;
    if (!result) return;
    const score = Math.round(result.score);
    const ring = h('div', { class: 'ring' }, [
      h('div', { class: 'ring-inner' }, [
        h('div', { class: 'ring-score', text: String(score) }),
        h('div', { class: 'ring-caption', text: 'з 100' })
      ])
    ]);
    ring.style.setProperty('--ring-value', score + '%');
    const rows = [h('div', { class: 'kv-row' }, [
      h('span', { class: 'kv-label', text: 'Звучання' }),
      h('span', { text: result.sound + ' зі 100' })
    ])];
    if (result.heard) {
      rows.push(h('div', { class: 'kv-row' }, [
        h('span', { class: 'kv-label', text: 'Слова' }),
        h('span', { text: result.matched + ' з ' + result.total + ' (' + result.wordScore + '%)' })
      ]));
    }

    resultHost.appendChild(card(h('div', { class: 'stack' }, [
      h('div', { class: 'center', text: 'Результат спроби' }),
      ring,
      h('div', {}, rows),
      h('div', { class: 'word-example', text: result.expected }),
      result.heard ? h('div', { class: 'muted', text: 'Почуто: ' + result.heard }) : null,
      result.selfAssessed
        ? infoBox('Самооцінка', 'Оцінку поставили ви — браузер не має розпізнавання мовлення.', { tone: 'warning' })
        : null,
      h('div', { class: 'row', style: { flexWrap: 'wrap' } }, [
        button('Ще раз', {
          variant: 'secondary',
          onClick: () => {
            resetAttempt();
            renderActions();
            renderResult();
          }
        }),
        button('Наступна фраза', { onClick: nextPhrase })
      ])
    ])));
  }

  function renderAll() {
    renderModes();
    renderStats();
    renderPhrase();
    renderActions();
    renderResult();
  }

  reloadQueue();
  renderAll();
  return root;
}
