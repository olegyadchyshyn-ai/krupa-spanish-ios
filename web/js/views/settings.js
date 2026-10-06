// Екрани «Налаштування», «Резервна копія», «Про застосунок» і «Діагностика».
//
// Модуль не торкається DOM на верхньому рівні — усі елементи створюються
// всередині функцій рендеру.

import {
  h, card, sectionHeader, button, levelBadge, field, infoBox, errorBanner,
  confirmDialog, toast, clear, formatDateTime
} from '../ui.js';
import { GOALS } from '../store.js';
import { LEVELS } from '../content.js';

const WEB_VERSION = '1.0.0';

const MINUTE_CHOICES = [5, 10, 15, 20, 30];
const CARD_GOAL_CHOICES = [10, 20, 30, 50];
const NEW_CARD_CHOICES = [5, 10, 15, 20];
const REVIEW_CHOICES = [50, 100, 200];

const THEME_CHOICES = [
  { value: 'system', title: 'Як у системі' }, { value: 'light', title: 'Світла' }, { value: 'dark', title: 'Темна' }
];

const VOICE_CHOICES = [
  { value: 'any', title: 'Будь-який' }, { value: 'female', title: 'Жіночий' }, { value: 'male', title: 'Чоловічий' }
];

// MARK: - Дрібні помічники

function kvRow(label, value) {
  return h('div', { class: 'kv-row' }, [
    h('span', { class: 'kv-label', text: label }),
    h('span', { text: String(value) })
  ]);
}

function kvRows(pairs) {
  return h('div', {}, pairs.map((pair) => kvRow(pair[0], pair[1])));
}

/** Підпис над елементом керування (рядок або готовий вузол). */
function labeled(label, control) {
  return h('div', { class: 'stack', style: { gap: '6px' } }, [
    typeof label === 'string' ? h('div', { class: 'list-sub', text: label }) : label,
    control
  ]);
}

function numberChoices(values) {
  return values.map((value) => ({ value, title: String(value) }));
}

/** Рядок із підписом і сегментованим перемикачем. */
function segmentedRow(label, options, value, onSelect) {
  const control = h('div', { class: 'segmented' }, options.map((option) => h('button', {
    class: 'segmented-item' + (option.value === value ? ' active' : ''),
    type: 'button',
    text: option.title,
    onclick: () => onSelect(option.value)
  })));
  return labeled(label, control);
}

/** Рядок із підписом і випадаючим списком. */
function selectRow(label, options, value, onChange) {
  const select = h('select', {
    class: 'field',
    onchange: (event) => onChange(event.target.value)
  }, options.map((option) => h('option', {
    value: option.value,
    selected: option.value === value,
    text: option.title
  })));
  return labeled(label, select);
}

/** Перемикач ✅/⬜ у вигляді рядка списку. */
function toggleRow(title, subtitle, initialValue, onChange) {
  let value = Boolean(initialValue);
  const mark = h('span', { class: 'list-icon', text: value ? '✅' : '⬜' });

  return h('button', {
    class: 'list-item',
    type: 'button',
    onclick: () => {
      value = !value;
      mark.textContent = value ? '✅' : '⬜';
      onChange(value);
    }
  }, [
    mark,
    h('div', { class: 'stack', style: { gap: '2px', flex: '1' } }, [
      h('div', { class: 'list-title', text: title }),
      subtitle ? h('div', { class: 'list-sub', text: subtitle }) : null
    ])
  ]);
}

function linkRow(icon, title, hash, app) {
  return h('button', { class: 'list-item', type: 'button', onclick: () => app.navigate(hash) }, [
    h('span', { class: 'list-icon', text: icon }),
    h('span', { class: 'list-title', text: title }),
    h('span', { class: 'spacer' }),
    h('span', { class: 'list-sub', text: '›' })
  ]);
}

function dateStamp(date) {
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return date.getFullYear() + '-' + month + '-' + day;
}

function formatRate(rate) {
  const text = Number(rate || 0).toFixed(2).replace(/0+$/, '').replace(/\.$/, '');
  return text + '×';
}

// MARK: - Налаштування

export function renderSettings(app) {
  return h('div', { class: 'stack' }, [
    learningCard(app),
    speechCard(app),
    appearanceCard(app),
    dataCard(app),
    dangerCard(app)
  ]);
}

function learningCard(app) {
  const store = app.store;
  const profile = store.profile;
  const goal = GOALS.find((item) => item.id === profile.goal);

  return card([
    sectionHeader('Навчання', 'Рівень, мета й денні ліміти', '🎯'),
    segmentedRow('Рівень', LEVELS.map((level) => ({ value: level, title: level })), profile.level, (value) => {
      store.updateProfile({ level: value }); app.refresh();
    }),
    selectRow('Мета навчання', GOALS.map((item) => ({ value: item.id, title: item.title })), profile.goal, (value) => {
      store.updateProfile({ goal: value }); app.refresh();
    }),
    goal ? h('div', { class: 'muted', text: goal.description }) : null,
    segmentedRow('Хвилин на день', numberChoices(MINUTE_CHOICES), profile.dailyMinutes, (value) => {
      store.updateProfile({ dailyMinutes: value }); app.refresh();
    }),
    segmentedRow('Щоденна ціль карток', numberChoices(CARD_GOAL_CHOICES), profile.dailyCardGoal, (value) => {
      store.updateProfile({ dailyCardGoal: value }); app.refresh();
    }),
    segmentedRow('Нових карток на день', numberChoices(NEW_CARD_CHOICES), store.settings.newCardsPerDay, (value) => {
      store.updateSettings({ newCardsPerDay: value }); app.refresh();
    }),
    segmentedRow('Повторень на день', numberChoices(REVIEW_CHOICES), store.settings.reviewsPerDay, (value) => {
      store.updateSettings({ reviewsPerDay: value }); app.refresh();
    })
  ]);
}

function speechCard(app) {
  const store = app.store;
  const voiceCount = app.tts ? app.tts.voiceCount : 0;
  const rateLabel = h('span', { class: 'list-sub', text: formatRate(store.profile.ttsRate) });

  const slider = h('input', {
    class: 'field', type: 'range', min: '0.5', max: '1.3', step: '0.05',
    value: String(store.profile.ttsRate),
    oninput: (event) => {
      const rate = Number(event.target.value);
      store.updateProfile({ ttsRate: rate });
      rateLabel.textContent = formatRate(rate);
      app.applyPreferences();
    }
  });

  return card([
    sectionHeader('Звук і мовлення', 'Озвучення іспанською', '🔊'),
    toggleRow('Автоматичне озвучення', 'Озвучувати картки одразу', store.settings.autoPlayAudio,
      (value) => store.updateSettings({ autoPlayAudio: value })),
    labeled(h('div', { class: 'row-between' }, [
      h('span', { class: 'list-sub', text: 'Швидкість мовлення' }),
      rateLabel
    ]), slider),
    selectRow('Голос', VOICE_CHOICES, store.profile.ttsVoice, (value) => {
      store.updateProfile({ ttsVoice: value }); app.applyPreferences();
    }),
    h('div', { class: 'muted', text: 'Доступних іспанських голосів: ' + voiceCount }),
    voiceCount === 0
      ? infoBox('Мовлення', 'Системні іспанські голоси не знайдено — мовлення може не працювати', { tone: 'warning' })
      : null,
    button('Перевірити звук', {
      variant: 'ghost', icon: '🔈', className: 'btn-block',
      onClick: () => app.speak('Hola, esto es una prueba.', true)
    })
  ]);
}

function appearanceCard(app) {
  const store = app.store;

  return card([
    sectionHeader('Вигляд', 'Тема й підказки', '🎨'),
    segmentedRow('Тема', THEME_CHOICES, store.profile.theme, (value) => {
      store.updateProfile({ theme: value }); app.applyPreferences(); app.refresh();
    }),
    toggleRow('Підказки про вимову', 'Показувати підказки до іспанських слів', store.settings.showPronunciationHints,
      (value) => store.updateSettings({ showPronunciationHints: value })),
    toggleRow('Транскрипція IPA', 'Показувати IPA у картках слів', store.settings.showIpa,
      (value) => store.updateSettings({ showIpa: value })),
    toggleRow('Підказки в аудіюванні', 'Показувати ключові слова', store.settings.listeningHints,
      (value) => store.updateSettings({ listeningHints: value }))
  ]);
}

function dataCard(app) {
  return card([
    sectionHeader('Дані', 'Копії, діагностика, інформація', '🗄'),
    h('div', { class: 'list' }, [
      linkRow('💾', 'Резервна копія', '#/backup', app),
      linkRow('🩺', 'Діагностика', '#/diagnostics', app),
      linkRow('ℹ️', 'Про застосунок', '#/about', app)
    ])
  ]);
}

function dangerCard(app) {
  const store = app.store;

  return card([
    sectionHeader('Небезпечна зона', 'Дії, які не можна скасувати', '⚠️'),
    h('div', { class: 'muted', text: 'Скидання видалить картки, статистику та історію відповідей на цьому пристрої.' }),
    button('Скинути весь прогрес', {
      variant: 'danger', icon: '🗑', className: 'btn-block',
      onClick: () => confirmDialog('Скинути весь прогрес? Дію не можна скасувати.', () => {
        store.reset();
        app.refresh();
        toast('Прогрес скинуто');
      })
    })
  ]);
}

// MARK: - Резервна копія

export function renderBackup(app) {
  const store = app.store;
  const container = h('div', { class: 'stack' });
  const errorSlot = h('div', { class: 'stack' });
  const status = h('div', { class: 'list-sub', text: 'Файл ще не вибрано' });
  const textArea = field('Вставте вміст файлу копії (JSON)', { multiline: true, rows: 6 });
  let fileText = '';

  function showError(message) {
    clear(errorSlot);
    const banner = errorBanner(message);
    if (banner) errorSlot.appendChild(banner);
  }

  function applyImport(mode) {
    const pasted = String(textArea.value || '').trim();
    const text = pasted || fileText;
    if (!text) {
      showError('Спочатку виберіть файл копії або вставте його вміст.');
      return;
    }
    try {
      store.importJSON(text, mode);
      toast(mode === 'merge' ? 'Прогрес об\'єднано' : 'Прогрес відновлено з копії');
      app.refresh();
    } catch (error) {
      showError('Не вдалося прочитати копію: ' + (error && error.message ? error.message : String(error)));
    }
  }

  const fileInput = h('input', {
    class: 'field', type: 'file', accept: '.json,application/json',
    onchange: (event) => {
      const file = event.target.files && event.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        fileText = String(reader.result || '');
        status.textContent = 'Файл: ' + file.name + ' (' + Math.max(1, Math.round(file.size / 1024)) + ' КБ)';
        showError('');
      };
      reader.onerror = () => showError('Не вдалося прочитати файл.');
      reader.readAsText(file);
    }
  });

  container.appendChild(card([
    sectionHeader('Створити копію', 'Один файл з усім прогресом', '💾'),
    infoBox('Навіщо це', 'Файл з\'явиться у «Файли» або в «Завантаження». Збережіть його в iCloud Drive чи надішліть собі — і прогрес можна відновити на будь-якому пристрої.'),
    kvRows([
      ['Карток у копії', Object.keys(store.cards).length],
      ['Записів у журналі', (store.data.reviewLog || []).length],
      ['Дата копії', formatDateTime(new Date())]
    ]),
    button('Створити файл копії', {
      icon: '⬇️', className: 'btn-block',
      onClick: () => downloadBackup(app)
    })
  ]));

  container.appendChild(card([
    sectionHeader('Відновити', 'Замінити або об\'єднати з поточним', '📥'),
    labeled('Файл копії (.json)', h('div', { class: 'stack', style: { gap: '6px' } }, [fileInput, status])),
    labeled('Або вставте вміст файлу', textArea),
    errorSlot,
    button('Об\'єднати з поточним', {
      variant: 'secondary', icon: '🔀', className: 'btn-block',
      onClick: () => applyImport('merge')
    }),
    button('Замінити прогрес', {
      variant: 'danger', icon: '♻️', className: 'btn-block',
      onClick: () => confirmDialog('Замінити весь поточний прогрес даними з копії?', () => applyImport('replace'))
    }),
    h('div', { class: 'muted', text: 'Об\'єднання бере картки й дні з кращим результатом, заміна повністю замінює прогрес.' })
  ]));

  return container;
}

function downloadBackup(app) {
  try {
    const text = app.store.exportJSON();
    const name = 'krupa_spanish_progress_' + dateStamp(new Date()) + '.json';
    const blob = new Blob([text], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = h('a', { href: url, download: name, style: { display: 'none' } });

    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
    toast('Файл копії створено');
  } catch (error) {
    toast('Не вдалося створити файл копії');
  }
}

// MARK: - Про застосунок

export function renderAbout(app) {
  const store = app.store;
  const content = app.content;
  const goal = GOALS.find((item) => item.id === store.profile.goal);

  return h('div', { class: 'stack' }, [
    card([
      h('div', { class: 'center' }, [
        h('div', { class: 'word-hero', text: 'KRUPA Spanish' }),
        h('div', { class: 'muted', text: 'Веб-версія ' + WEB_VERSION + ' · іспанська для україномовних' })
      ]),
      h('div', { class: 'row', style: { justifyContent: 'center' } }, [
        levelBadge(store.profile.level),
        h('span', { class: 'list-sub', text: goal ? goal.title : 'Мета не вибрана' })
      ]),
      kvRows([
        ['Рівень', store.profile.level],
        ['Мета', goal ? goal.title : '—'],
        ['Хвилин на день', store.profile.dailyMinutes],
        ['Початок навчання', formatDateTime(store.profile.startedAt)]
      ])
    ]),
    card([
      sectionHeader('Про застосунок', 'Навіщо і як', 'ℹ️'),
      h('div', { class: 'muted', text: 'KRUPA Spanish — курс іспанської для україномовних: слова, речення, вправи, граматика, аудіювання та діалоги в одному місці. Картки повторюються за інтервальним повторенням (SM-2): застосунок показує слово саме тоді, коли його варто згадати.' }),
      h('div', { class: 'muted', text: 'Іспанський текст озвучується системним синтезом мовлення, а у «Вимові» можна тренувати розпізнавання голосу. Це веб-версія застосунку KRUPA Spanish для iPhone, iPad та Android — прогрес зберігається лише на цьому пристрої, тож робіть резервні копії.' })
    ]),
    card([
      sectionHeader('Контент', 'Скільки вже в курсі', '📚'),
      kvRows([
        ['Слів', content.words.length], ['Речень', content.sentences.length],
        ['Вправ', content.exercises.length], ['Граматичних тем', content.grammar.length],
        ['Аудіювань', content.listening.length], ['Тем', content.topics.length],
        ['Версія контенту', content.contentVersion || 1]
      ])
    ]),
    card([
      sectionHeader('Офлайн і встановлення', 'Щоб навчатися без інтернету', '📶'),
      infoBox('Інтернет не потрібен', 'Після першого відкриття курс і прогрес працюють офлайн — інтернет для навчання не потрібен.', { tone: 'success' }),
      infoBox('Екран «Домівки»', 'Щоб додати на екран «Домівки»: Поділитися → На екран «Домівки».')
    ])
  ]);
}

// MARK: - Діагностика

export function renderDiagnostics(app) {
  const content = app.content;
  const store = app.store;
  const tts = app.tts || {};
  const issues = content.issues || [];
  const storageOk = localStorageWorks();
  const sizeKb = (byteSize(store.exportJSON()) / 1024).toFixed(1);
  const recognition = typeof window !== 'undefined'
    && Boolean(window.SpeechRecognition || window.webkitSpeechRecognition);

  const report = [
    'KRUPA Spanish — діагностика',
    'Дата: ' + formatDateTime(new Date()),
    'Слів: ' + content.words.length + ', речень: ' + content.sentences.length,
    'Вправ: ' + content.exercises.length + ', граматики: ' + content.grammar.length,
    'Аудіювань: ' + content.listening.length + ', тем: ' + content.topics.length,
    'Версія контенту: ' + (content.contentVersion || 1),
    'Зауваження контенту: ' + (issues.length ? issues.join('; ') : 'немає'),
    'localStorage: ' + (storageOk ? 'працює' : 'недоступний'),
    'Карток: ' + Object.keys(store.cards).length,
    'Записів у журналі: ' + (store.data.reviewLog || []).length,
    'Розмір JSON: ' + sizeKb + ' КБ',
    'Синтез мовлення: ' + (tts.available ? 'доступний' : 'недоступний'),
    'Іспанських голосів: ' + (tts.voiceCount || 0),
    'Розпізнавання мовлення: ' + (recognition ? 'підтримується' : 'не підтримується')
  ].join('\n');

  return h('div', { class: 'stack' }, [
    card([
      sectionHeader('Контент', 'Що завантажено з файлів курсу', '📚'),
      kvRows([
        ['Слів', content.words.length], ['Речень', content.sentences.length],
        ['Вправ', content.exercises.length], ['Граматики', content.grammar.length],
        ['Аудіювань', content.listening.length], ['Тем', content.topics.length],
        ['Версія контенту', content.contentVersion || 1]
      ]),
      issues.length
        ? labeled('Зауваження (' + issues.length + ')', h('div', { class: 'stack', style: { gap: '4px' } },
          issues.map((issue) => h('div', { class: 'muted', text: '• ' + issue }))))
        : infoBox('Перевірка контенту', 'Зауважень немає', { tone: 'success' })
    ]),
    card([
      sectionHeader('Сховище', 'localStorage і розмір прогресу', '💾'),
      kvRows([
        ['localStorage', storageOk ? 'працює' : 'недоступний'],
        ['Карток', Object.keys(store.cards).length],
        ['Записів у журналі', (store.data.reviewLog || []).length],
        ['Розмір збереженого JSON', sizeKb + ' КБ']
      ]),
      storageOk
        ? null
        : infoBox('Увага', 'Сховище недоступне (наприклад, приватний режим) — прогрес не збережеться після закриття вкладки.', { tone: 'warning' })
    ]),
    card([
      sectionHeader('Мовлення', 'Синтез і розпізнавання', '🔊'),
      kvRows([
        ['Синтез мовлення', tts.available ? 'доступний' : 'недоступний'],
        ['Іспанських голосів', tts.voiceCount || 0],
        ['Розпізнавання мовлення', recognition ? 'підтримується' : 'не підтримується'],
        ['Швидкість мовлення', formatRate(store.profile.ttsRate)]
      ]),
      !tts.available || !tts.voiceCount
        ? infoBox('Мовлення', 'Системні іспанські голоси не знайдено — мовлення може не працювати', { tone: 'warning' })
        : null
    ]),
    button('Перевірити звук', {
      variant: 'secondary', icon: '🔈', className: 'btn-block',
      onClick: () => app.speak('Hola', true)
    }),
    button('Скопіювати звіт', {
      variant: 'ghost', icon: '📋', className: 'btn-block',
      onClick: () => copyText(report)
    })
  ]);
}

function localStorageWorks() {
  try {
    const key = '__krupa_diag__';
    window.localStorage.setItem(key, '1');
    const value = window.localStorage.getItem(key);
    window.localStorage.removeItem(key);
    return value === '1';
  } catch (error) {
    return false;
  }
}

function byteSize(text) {
  if (typeof TextEncoder === 'function') return new TextEncoder().encode(text).length;
  return String(text).length;
}

function copyText(text) {
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
