// Хелпери для побудови DOM: короткий синтаксис без фреймворків.
//
// Усі функції працюють лише всередині виклику (жодних дій на верхньому рівні),
// тому модулі можна імпортувати й перевіряти в Node.

/**
 * Створює елемент.
 * h('div', { class: 'card', onclick: fn }, [child, 'текст'])
 */
export function h(tag, props, children) {
  const element = document.createElement(tag || 'div');
  if (props) {
    for (const [key, value] of Object.entries(props)) {
      if (value == null || value === false) continue;
      if (key === 'class' || key === 'className') {
        element.className = value;
      } else if (key === 'text') {
        element.textContent = value;
      } else if (key === 'html') {
        element.innerHTML = value;
      } else if (key === 'dataset') {
        Object.assign(element.dataset, value);
      } else if (key === 'style' && typeof value === 'object') {
        Object.assign(element.style, value);
      } else if (key.startsWith('on') && typeof value === 'function') {
        element.addEventListener(key.slice(2).toLowerCase(), value);
      } else if (key === 'disabled' || key === 'checked' || key === 'selected') {
        element[key] = Boolean(value);
      } else {
        element.setAttribute(key, value);
      }
    }
  }
  append(element, children);
  return element;
}

export function append(parent, children) {
  if (children == null || children === false) return parent;
  if (Array.isArray(children)) {
    for (const child of children) append(parent, child);
    return parent;
  }
  if (children instanceof Node) {
    parent.appendChild(children);
    return parent;
  }
  parent.appendChild(document.createTextNode(String(children)));
  return parent;
}

export function clear(element) {
  while (element.firstChild) element.removeChild(element.firstChild);
  return element;
}

export function frag(children) {
  const fragment = document.createDocumentFragment();
  append(fragment, children);
  return fragment;
}

/**
 * Додає блок CSS один раз (захист від дублювання при повторних рендерах).
 * Використовуйте для стилів, яких немає в css/app.css, з унікальним id.
 */
export function ensureStyles(id, css) {
  if (typeof document === 'undefined') return;
  if (document.getElementById(id)) return;
  const style = document.createElement('style');
  style.id = id;
  style.textContent = css;
  document.head.appendChild(style);
}

// MARK: - Готові компоненти

export function card(children, options) {
  const opts = options || {};
  return h('div', { class: 'card' + (opts.className ? ' ' + opts.className : '') }, children);
}

export function sectionHeader(title, subtitle, icon) {
  return h('div', { class: 'section-header' }, [
    icon ? h('span', { class: 'section-icon', text: icon }) : null,
    h('div', {}, [
      h('div', { class: 'section-title', text: title }),
      subtitle ? h('div', { class: 'section-subtitle', text: subtitle }) : null
    ])
  ]);
}

export function button(title, options) {
  const opts = options || {};
  return h('button', {
    class: 'btn' + (opts.variant ? ' btn-' + opts.variant : ' btn-primary') + (opts.className ? ' ' + opts.className : ''),
    type: 'button',
    disabled: opts.disabled,
    onclick: opts.onClick
  }, [
    opts.icon ? h('span', { class: 'btn-icon', text: opts.icon }) : null,
    h('span', { text: title })
  ]);
}

/** Кнопка-іконка (озвучення). */
export function speakButton(onClick, label) {
  return h('button', {
    class: 'icon-btn',
    type: 'button',
    title: label || 'Прослухати',
    'aria-label': label || 'Прослухати',
    onclick: onClick
  }, '🔊');
}

export function progressBar(fraction, options) {
  const opts = options || {};
  const value = Math.min(1, Math.max(0, fraction || 0));
  return h('div', { class: 'progress' + (opts.className ? ' ' + opts.className : '') }, [
    h('div', { class: 'progress-fill', style: { width: (value * 100).toFixed(1) + '%' } })
  ]);
}

export function levelBadge(level) {
  return h('span', { class: 'badge badge-level badge-' + level, text: level });
}

export function chip(text, options) {
  const opts = options || {};
  const tag = opts.onClick ? 'button' : 'span';
  return h(tag, {
    class: 'chip' + (opts.active ? ' chip-active' : '') + (opts.className ? ' ' + opts.className : ''),
    type: opts.onClick ? 'button' : null,
    onclick: opts.onClick
  }, text);
}

export function statTile(title, value, icon, options) {
  const opts = options || {};
  return h('div', { class: 'stat-tile' + (opts.className ? ' ' + opts.className : '') }, [
    h('div', { class: 'stat-icon', text: icon || '•' }),
    h('div', { class: 'stat-value', text: String(value) }),
    h('div', { class: 'stat-title', text: title })
  ]);
}

export function emptyState(title, message, options) {
  const opts = options || {};
  return h('div', { class: 'empty-state' }, [
    h('div', { class: 'empty-icon', text: opts.icon || '📚' }),
    h('div', { class: 'empty-title', text: title }),
    h('div', { class: 'empty-message', text: message }),
    opts.actionTitle ? button(opts.actionTitle, { onClick: opts.onAction, className: 'empty-action' }) : null
  ]);
}

export function errorBanner(message, onRetry) {
  if (!message) return null;
  return h('div', { class: 'error-banner' }, [
    h('span', { class: 'error-icon', text: '⚠️' }),
    h('span', { class: 'error-text', text: message }),
    onRetry ? h('button', { class: 'link-btn', type: 'button', text: 'Повторити', onclick: onRetry }) : null
  ]);
}

export function infoBox(title, text, options) {
  if (!text) return null;
  const opts = options || {};
  return h('div', { class: 'info-box' + (opts.tone ? ' info-' + opts.tone : '') }, [
    h('div', { class: 'info-title', text: title }),
    h('div', { class: 'info-text', text })
  ]);
}

/** Варіант відповіді (для вправ із вибором). */
export function optionRow(text, options) {
  const opts = options || {};
  return h('button', {
    class: 'option' + (opts.state ? ' option-' + opts.state : ''),
    type: 'button',
    disabled: opts.disabled,
    onclick: opts.onClick
  }, [
    h('span', { class: 'option-text', text }),
    opts.state === 'correct' ? h('span', { class: 'option-mark', text: '✓' }) : null,
    opts.state === 'wrong' ? h('span', { class: 'option-mark', text: '✕' }) : null
  ]);
}

export function field(placeholder, options) {
  const opts = options || {};
  const input = h(opts.multiline ? 'textarea' : 'input', {
    class: 'field',
    placeholder,
    value: opts.value || '',
    rows: opts.multiline ? (opts.rows || 4) : null,
    autocapitalize: 'none',
    autocorrect: 'off',
    spellcheck: 'false',
    onkeydown: (event) => {
      if (event.key === 'Enter' && !opts.multiline && opts.onSubmit) {
        event.preventDefault();
        opts.onSubmit(input.value);
      }
    }
  });
  if (opts.onInput) input.addEventListener('input', () => opts.onInput(input.value));
  return input;
}

/** Бульбашка чату (для AI-діалогів). */
export function bubble(text, isUser, extras) {
  return h('div', { class: 'bubble' + (isUser ? ' bubble-user' : ' bubble-bot') }, [
    h('div', { class: 'bubble-text', text }),
    extras || null
  ]);
}

export function confirmDialog(message, onConfirm) {
  const overlay = h('div', { class: 'overlay' });
  const close = () => overlay.remove();
  overlay.appendChild(h('div', { class: 'dialog' }, [
    h('div', { class: 'dialog-text', text: message }),
    h('div', { class: 'dialog-actions' }, [
      button('Скасувати', { variant: 'ghost', onClick: close }),
      button('Так', { variant: 'danger', onClick: () => { close(); onConfirm(); } })
    ])
  ]));
  document.body.appendChild(overlay);
}

export function toast(message) {
  const element = h('div', { class: 'toast', text: message });
  document.body.appendChild(element);
  setTimeout(() => element.classList.add('toast-visible'), 10);
  setTimeout(() => {
    element.classList.remove('toast-visible');
    setTimeout(() => element.remove(), 300);
  }, 2200);
}

/** Форматує дату українською: «1 січня 2025, 18:45». */
export function formatDateTime(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  try {
    return date.toLocaleString('uk-UA', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch (error) {
    return date.toLocaleString();
  }
}

export function formatMinutes(minutes) {
  const value = Math.max(0, Math.round(minutes || 0));
  if (value < 60) return value + ' хв';
  const hours = Math.floor(value / 60);
  const rest = value % 60;
  return rest ? hours + ' год ' + rest + ' хв' : hours + ' год';
}

/** Підпис дня тижня українською (пн…нд). */
export function weekdayShort(date) {
  const names = ['нд', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];
  return names[new Date(date).getDay()];
}

export function plural(count, one, few, many) {
  const value = Math.abs(count) % 100;
  const last = value % 10;
  if (value > 10 && value < 20) return many;
  if (last > 1 && last < 5) return few;
  if (last === 1) return one;
  return many;
}
