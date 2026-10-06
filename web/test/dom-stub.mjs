// Мінімальна заглушка DOM, щоб викликати екрани у Node і зловити помилки
// виконання (звернення до неіснуючих полів, забуті функції тощо).
//
// Це не повноцінний браузер: потрібно лише, щоб код екранів виконувався
// без ReferenceError і повертав вузол.

class StubNode {}

class StubClassList {
  constructor() { this.set = new Set(); }
  add(...names) { names.forEach((name) => this.set.add(name)); }
  remove(...names) { names.forEach((name) => this.set.delete(name)); }
  contains(name) { return this.set.has(name); }
  toggle(name, force) {
    const shouldAdd = force === undefined ? !this.set.has(name) : Boolean(force);
    if (shouldAdd) this.set.add(name); else this.set.delete(name);
    return shouldAdd;
  }
  get value() { return Array.from(this.set).join(' '); }
}

class StubElement extends StubNode {
  constructor(tagName) {
    super();
    this.tagName = String(tagName || 'div').toUpperCase();
    this.children = [];
    this.childNodes = this.children;
    this.attributes = {};
    this.dataset = {};
    this.style = {};
    this.classList = new StubClassList();
    this.listeners = {};
    this.parentNode = null;
    this._text = '';
    this.value = '';
    this.hidden = false;
    this.disabled = false;
    this.checked = false;
    this.selected = false;
  }

  get className() { return this.classList.value; }
  set className(value) {
    this.classList.set = new Set(String(value || '').split(/\s+/).filter(Boolean));
  }

  get textContent() {
    if (this.children.length === 0) return this._text;
    return this.children.map((child) => child.textContent || '').join('') + this._text;
  }
  set textContent(value) { this._text = String(value == null ? '' : value); this.children.length = 0; }

  set innerHTML(value) { this._text = String(value == null ? '' : value); this.children.length = 0; }
  get innerHTML() { return this._text; }

  get firstChild() { return this.children[0] || null; }

  appendChild(child) {
    if (!child) return child;
    if (child instanceof StubFragment) {
      for (const inner of child.children.slice()) this.appendChild(inner);
      return child;
    }
    child.parentNode = this;
    this.children.push(child);
    return child;
  }

  insertBefore(child, reference) {
    const index = this.children.indexOf(reference);
    child.parentNode = this;
    if (index < 0) this.children.push(child);
    else this.children.splice(index, 0, child);
    return child;
  }

  removeChild(child) {
    const index = this.children.indexOf(child);
    if (index >= 0) this.children.splice(index, 1);
    child.parentNode = null;
    return child;
  }

  remove() { if (this.parentNode) this.parentNode.removeChild(this); }

  setAttribute(name, value) { this.attributes[name] = String(value); }
  getAttribute(name) { return this.attributes[name] === undefined ? null : this.attributes[name]; }
  removeAttribute(name) { delete this.attributes[name]; }

  addEventListener(type, handler) {
    (this.listeners[type] = this.listeners[type] || []).push(handler);
  }
  removeEventListener(type, handler) {
    const list = this.listeners[type] || [];
    const index = list.indexOf(handler);
    if (index >= 0) list.splice(index, 1);
  }

  /** Викликає обробник (для тестів). */
  dispatch(type, event) {
    for (const handler of this.listeners[type] || []) handler(event || { type, preventDefault() {} });
  }
  click() { this.dispatch('click'); }
  focus() {}
  blur() {}

  querySelectorAll() { return []; }
  querySelector() { return null; }

  getBoundingClientRect() { return { width: 320, height: 200, top: 0, left: 0 }; }
}

class StubFragment extends StubElement {
  constructor() { super('#fragment'); }
}

class StubText extends StubNode {
  constructor(text) { super(); this._text = String(text == null ? '' : text); }
  get textContent() { return this._text; }
  set textContent(value) { this._text = String(value == null ? '' : value); }
}

function createDocument() {
  const body = new StubElement('body');
  const head = new StubElement('head');
  const documentElement = new StubElement('html');
  const byId = new Map();

  const document = {
    body,
    head,
    documentElement,
    readyState: 'complete',
    createElement: (tag) => new StubElement(tag),
    createTextNode: (text) => new StubText(text),
    createDocumentFragment: () => new StubFragment(),
    getElementById: (id) => byId.get(id) || null,
    querySelector: () => null,
    querySelectorAll: () => [],
    addEventListener: () => {},
    removeEventListener: () => {},
    _registerId(id, element) { byId.set(id, element); }
  };
  return document;
}

/** Встановлює глобальні об'єкти браузера. Повертає document. */
export function installDom() {
  const document = createDocument();
  const storage = new Map();

  globalThis.Node = StubNode;
  globalThis.Element = StubElement;
  globalThis.HTMLElement = StubElement;
  globalThis.document = document;

  globalThis.window = {
    document,
    location: { hash: '#/', href: 'http://localhost/', protocol: 'http:', origin: 'http://localhost' },
    history: { back() {}, pushState() {} },
    localStorage: {
      getItem: (key) => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => storage.set(key, String(value)),
      removeItem: (key) => storage.delete(key)
    },
    matchMedia: () => ({ matches: false, addEventListener() {}, removeEventListener() {} }),
    speechSynthesis: null,
    SpeechSynthesisUtterance: undefined,
    addEventListener: () => {},
    scrollTo: () => {},
    requestAnimationFrame: (fn) => setTimeout(fn, 0)
  };

  setGlobal('localStorage', window.localStorage);
  setGlobal('navigator', { userAgent: 'node-test', serviceWorker: undefined, clipboard: { writeText: async () => {} } });
  setGlobal('location', window.location);
  setGlobal('history', window.history);

  return document;
}

/** Деякі глобальні властивості в Node доступні лише для читання. */
function setGlobal(name, value) {
  try {
    globalThis[name] = value;
  } catch (error) {
    Object.defineProperty(globalThis, name, { value, configurable: true, writable: true });
  }
}

export { StubNode, StubElement, StubText, StubFragment };
