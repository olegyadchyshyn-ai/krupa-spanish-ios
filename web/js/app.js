// Точка входу веб-версії: роутер, оболонка з навігацією та станом застосунку.

import { loadContent } from './content.js';
import { createStore, createMemoryStorage, SrsEngine } from './store.js';
import { createTts } from './tts.js';
import { h, clear, toast, errorBanner, progressBar } from './ui.js';

import { renderOnboarding } from './views/onboarding.js';
import { renderHome } from './views/home.js';
import { renderLearn } from './views/learn.js';
import { renderTopic } from './views/topic.js';
import { renderSession } from './views/session.js';
import { renderReview } from './views/review.js';
import { renderWords } from './views/words.js';
import { renderWord } from './views/word.js';
import { renderGrammarList, renderGrammarDetail } from './views/grammar.js';
import { renderListeningList, renderListeningDetail } from './views/listening.js';
import { renderSpeaking } from './views/speaking.js';
import { renderAi } from './views/ai.js';
import { renderProgress, renderProgressDetail } from './views/progress.js';
import { renderSettings, renderBackup, renderAbout, renderDiagnostics } from './views/settings.js';

// MARK: - Маршрути

const ROUTES = [
  { pattern: /^\/?$/, name: 'home', tab: 'home' },
  { pattern: /^\/onboarding$/, name: 'onboarding', fullscreen: true },
  { pattern: /^\/learn$/, name: 'learn', tab: 'learn', title: 'Курс' },
  { pattern: /^\/topic\/(.+)$/, name: 'topic', title: 'Тема' },
  { pattern: /^\/session$/, name: 'session', title: 'Заняття', fullscreen: true },
  { pattern: /^\/review$/, name: 'review', title: 'Повторення', fullscreen: true },
  { pattern: /^\/words$/, name: 'words', tab: 'words', title: 'Слова' },
  { pattern: /^\/words\/(A[0-2])$/, name: 'words', tab: 'words', title: 'Слова' },
  { pattern: /^\/word\/(.+)$/, name: 'word', title: 'Слово' },
  { pattern: /^\/grammar$/, name: 'grammar', title: 'Граматика' },
  { pattern: /^\/grammar\/(.+)$/, name: 'grammarDetail', title: 'Правило' },
  { pattern: /^\/listening$/, name: 'listening', title: 'Аудіювання' },
  { pattern: /^\/listening\/(.+)$/, name: 'listeningDetail', title: 'Аудіювання' },
  { pattern: /^\/speaking$/, name: 'speaking', title: 'Вимова' },
  { pattern: /^\/ai$/, name: 'ai', title: 'Діалог' },
  { pattern: /^\/ai\/(.+)$/, name: 'ai', title: 'Діалог' },
  { pattern: /^\/progress$/, name: 'progress', tab: 'progress', title: 'Прогрес' },
  { pattern: /^\/progress\/details$/, name: 'progressDetail', title: 'Деталі прогресу' },
  { pattern: /^\/settings$/, name: 'settings', tab: 'settings', title: 'Налаштування' },
  { pattern: /^\/backup$/, name: 'backup', title: 'Резервна копія' },
  { pattern: /^\/about$/, name: 'about', title: 'Про застосунок' },
  { pattern: /^\/diagnostics$/, name: 'diagnostics', title: 'Діагностика' }
];

const TABS = [
  { id: 'home', title: 'Головна', icon: '🏠', hash: '#/' },
  { id: 'learn', title: 'Навчання', icon: '📚', hash: '#/learn' },
  { id: 'words', title: 'Слова', icon: '🔤', hash: '#/words' },
  { id: 'progress', title: 'Прогрес', icon: '📊', hash: '#/progress' },
  { id: 'settings', title: 'Налаштування', icon: '⚙️', hash: '#/settings' }
];

// MARK: - Стан застосунку

const app = {
  content: null,
  store: null,
  tts: null,
  route: null,
  params: {},
  container: null,
  headerTitle: null,
  nav: null,

  navigate(hash) {
    if (location.hash === hash) {
      this.render();
    } else {
      location.hash = hash;
    }
  },

  refresh() {
    this.render();
  },

  toast,

  /** Поточний рівень користувача. */
  get level() {
    return this.store.profile.level;
  },

  /** Застосовує тему та налаштування мовлення до інтерфейсу. */
  applyPreferences() {
    const theme = this.store.profile.theme;
    const dark = theme === 'dark' || (theme === 'system' && window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
    document.documentElement.dataset.theme = dark ? 'dark' : 'light';
    this.tts.configure({
      rate: this.store.profile.ttsRate,
      gender: this.store.profile.ttsVoice
    });
  },

  /** Озвучує текст, якщо ввімкнено автозвук. */
  speak(text, force) {
    if (!text) return;
    if (!force && !this.store.settings.autoPlayAudio) return;
    this.tts.speak(text);
  },

  // MARK: Рендер

  render() {
    const parsed = parseHash();
    const matched = ROUTES.find((route) => route.pattern.test(parsed.path));
    const params = Object.assign({}, parsed.query, parsed.params);

    if (!matched) {
      location.hash = '#/';
      return;
    }

    if (!this.store.profile.onboardingDone && matched.name !== 'onboarding') {
      location.hash = '#/onboarding';
      return;
    }

    this.route = matched;
    this.params = params;
    this.headerTitle.textContent = matched.title || 'KRUPA Spanish';
    document.body.classList.toggle('fullscreen-view', Boolean(matched.fullscreen));

    const view = buildView(matched.name, params);
    clear(this.container);
    if (view) this.container.appendChild(view);

    this.updateNav(matched);
    window.scrollTo(0, 0);
  },

  updateNav(matched) {
    if (matched.fullscreen) {
      this.nav.hidden = true;
      return;
    }
    this.nav.hidden = false;
    for (const button of this.nav.querySelectorAll('.nav-item')) {
      button.classList.toggle('nav-active', button.dataset.tab === matched.tab);
    }
  }
};

function buildView(name, params) {
  switch (name) {
    case 'onboarding': return renderOnboarding(app);
    case 'home': return renderHome(app);
    case 'learn': return renderLearn(app);
    case 'topic': return renderTopic(app, { id: params.id });
    case 'session': return renderSession(app, { topicId: params.topic || null });
    case 'review': return renderReview(app);
    case 'words': return renderWords(app, { level: wordsLevel(params) });
    case 'word': return renderWord(app, { id: params.id });
    case 'grammar': return renderGrammarList(app);
    case 'grammarDetail': return renderGrammarDetail(app, { id: params.id });
    case 'listening': return renderListeningList(app);
    case 'listeningDetail': return renderListeningDetail(app, { id: params.id });
    case 'speaking': return renderSpeaking(app);
    case 'ai': return renderAi(app, { scenarioId: params.id || null });
    case 'progress': return renderProgress(app);
    case 'progressDetail': return renderProgressDetail(app);
    case 'settings': return renderSettings(app);
    case 'backup': return renderBackup(app);
    case 'about': return renderAbout(app);
    case 'diagnostics': return renderDiagnostics(app);
    default: return renderHome(app);
  }
}

/**
 * Рівень зі шляху `#/words/A1` (маршрут зіставляє його як `id`)
 * або з параметра `?level=`.
 */
function wordsLevel(params) {
  const candidate = String(params.level || params.id || '').toUpperCase();
  return ['A0', 'A1', 'A2'].includes(candidate) ? candidate : null;
}

/** Розбирає hash виду `#/word/w_a0_hola?hint=1`. */
function parseHash() {
  const raw = (location.hash || '#/').replace(/^#/, '');
  const [path, queryString] = raw.split('?');
  const query = {};
  if (queryString) {
    for (const pair of queryString.split('&')) {
      const [key, value] = pair.split('=');
      if (key) query[decodeURIComponent(key)] = decodeURIComponent(value || '');
    }
  }
  const route = ROUTES.find((item) => item.pattern.test(path));
  const params = {};
  if (route) {
    const match = path.match(route.pattern);
    if (match && match[1]) params.id = decodeURIComponent(match[1]);
  }
  return { path, query, params };
}

// MARK: - Оболонка

function buildShell() {
  const headerTitle = h('div', { class: 'header-title', text: 'KRUPA Spanish' });
  const backButton = h('button', {
    class: 'header-back',
    type: 'button',
    text: '‹',
    'aria-label': 'Назад',
    onclick: () => history.back()
  });

  const header = h('header', { class: 'app-header' }, [backButton, headerTitle]);
  const container = h('main', { class: 'app-main' });

  const nav = h('nav', { class: 'app-nav' }, TABS.map((tab) => h('button', {
    class: 'nav-item',
    type: 'button',
    dataset: { tab: tab.id },
    onclick: () => app.navigate(tab.hash)
  }, [
    h('span', { class: 'nav-icon', text: tab.icon }),
    h('span', { class: 'nav-title', text: tab.title })
  ])));

  document.body.appendChild(header);
  document.body.appendChild(container);
  document.body.appendChild(nav);

  app.headerTitle = headerTitle;
  app.container = container;
  app.nav = nav;
}

function renderLoading(message) {
  const container = app.container || document.body;
  clear(container);
  container.appendChild(h('div', { class: 'loading' }, [
    h('div', { class: 'spinner' }),
    h('div', { class: 'loading-text', text: message || 'Завантаження…' })
  ]));
}

function renderFatal(error) {
  clear(app.container);
  app.container.appendChild(h('div', { class: 'fatal' }, [
    h('div', { class: 'empty-icon', text: '⚠️' }),
    h('div', { class: 'empty-title', text: 'Не вдалося завантажити застосунок' }),
    h('div', { class: 'empty-message', text: String(error && error.message ? error.message : error) }),
    h('div', { class: 'empty-message', text: 'Перевірте інтернет і перезавантажте сторінку.' })
  ]));
}

// MARK: - Старт

async function boot() {
  buildShell();
  renderLoading('Готуємо курс…');

  try {
    const content = await loadContent('content/');
    const storage = safeStorage();
    const store = createStore(storage, content);
    const tts = createTts();

    app.content = content;
    app.store = store;
    app.tts = tts;
    app.applyPreferences();

    if (window.matchMedia) {
      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => app.applyPreferences());
    }

    window.addEventListener('hashchange', () => app.render());

    if (content.issues.length) {
      console.warn('Зауваження до контенту:', content.issues);
    }

    app.render();

    if ('serviceWorker' in navigator && location.protocol.startsWith('http')) {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    }
  } catch (error) {
    console.error(error);
    renderFatal(error);
  }
}

/** localStorage може бути недоступним у приватному режимі Safari. */
function safeStorage() {
  try {
    const probe = '__krupa_probe__';
    window.localStorage.setItem(probe, '1');
    window.localStorage.removeItem(probe);
    return window.localStorage;
  } catch (error) {
    console.warn('localStorage недоступний — прогрес не збережеться між сеансами.');
    return createMemoryStorage();
  }
}

export { app, SrsEngine, progressBar, errorBanner };

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
}
