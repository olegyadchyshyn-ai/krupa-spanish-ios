// Завантаження та індексація контенту курсу.
//
// Модуль не торкається DOM, тому його можна перевіряти в Node.

export const LEVELS = ['A0', 'A1', 'A2'];

/** Файли контенту в теці `content/`. */
export const CONTENT_FILES = [
  'words.a0.json', 'words.a1.json', 'words.a2.json',
  'sentences.a0.json', 'sentences.a1.json', 'sentences.a2.json',
  'exercises.a0.json', 'exercises.a1.json', 'exercises.a2.json',
  'grammar.a0a1.json', 'grammar.a2.json',
  'listening.a0.json', 'listening.a1.json', 'listening.a2.json',
  'topics.a0.json', 'topics.a1.json', 'topics.a2.json'
];

/** Прибирає пунктуацію та зайві пробіли, лишає наголоси (як в оригіналі). */
export function normalizeLoose(text) {
  return String(text == null ? '' : text)
    .toLowerCase()
    .replace(/[¡¿!?.,;:"«»()[\]…—–]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Прибирає діакритичні знаки: á → a, ñ → n. */
export function stripAccents(text) {
  return String(text == null ? '' : text).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

/** Порожній контент — використовується, якщо файли не завантажились. */
export function emptyContent() {
  return {
    words: [], sentences: [], exercises: [], grammar: [], listening: [], topics: [],
    issues: [], contentVersion: 1,
    wordById: new Map(), sentenceById: new Map(), exerciseById: new Map(),
    grammarById: new Map(), listeningById: new Map(), topicById: new Map()
  };
}

function indexBy(items, key = 'id') {
  const map = new Map();
  for (const item of items) {
    if (item && item[key] != null && !map.has(item[key])) map.set(item[key], item);
  }
  return map;
}

/**
 * Завантажує всі файли контенту.
 * @param {string} base шлях до теки з JSON (за замовчуванням `content/`)
 * @param {Function} fetchImpl функція fetch (щоб можна було тестувати)
 */
export async function loadContent(base, fetchImpl) {
  const doFetch = fetchImpl || (typeof fetch !== 'undefined' ? fetch : null);
  if (!doFetch) throw new Error('fetch недоступний');

  const root = base || 'content/';
  const issues = [];
  const buckets = {
    words: [], sentences: [], exercises: [], grammar: [], listening: [], topics: []
  };
  let contentVersion = 0;

  const results = await Promise.all(CONTENT_FILES.map(async (name) => {
    try {
      const response = await doFetch(root + name);
      if (!response.ok) throw new Error('HTTP ' + response.status);
      return { name, data: await response.json() };
    } catch (error) {
      issues.push(name + ': не вдалося прочитати (' + error.message + ')');
      return null;
    }
  }));

  for (const result of results) {
    if (!result) continue;
    const data = result.data || {};
    if (typeof data.contentVersion === 'number') {
      contentVersion = Math.max(contentVersion, data.contentVersion);
    }
    for (const key of Object.keys(buckets)) {
      const list = data[key];
      if (Array.isArray(list)) buckets[key].push(...list);
    }
  }

  const content = emptyContent();
  content.contentVersion = contentVersion || 1;
  content.issues = issues;

  for (const key of Object.keys(buckets)) {
    const seen = new Set();
    const unique = [];
    for (const item of buckets[key]) {
      if (!item || item.id == null || seen.has(item.id)) continue;
      seen.add(item.id);
      unique.push(item);
    }
    content[key] = unique;
  }

  content.wordById = indexBy(content.words);
  content.sentenceById = indexBy(content.sentences);
  content.exerciseById = indexBy(content.exercises);
  content.grammarById = indexBy(content.grammar);
  content.listeningById = indexBy(content.listening);
  content.topicById = indexBy(content.topics);

  content.issues.push(...validateContent(content));
  return content;
}

/** Перевірка цілісності контенту — повертає перелік зауважень. */
export function validateContent(content) {
  const issues = [];
  const topicIds = new Set(content.topics.map((t) => t.id));

  const orphanWords = content.words.filter((w) => w.topicId && !topicIds.has(w.topicId));
  if (orphanWords.length) issues.push('Слів із невідомою темою: ' + orphanWords.length);

  const noTranslation = content.words.filter((w) => !String(w.translationUk || '').trim());
  if (noTranslation.length) issues.push('Слів без перекладу: ' + noTranslation.length);

  // У вправах «ES → UK» відповідь лежить в answerUk, а answerEs порожнє —
  // це нормально, тому перевіряємо відповідне поле за типом вправи.
  const noAnswer = content.exercises.filter((e) => {
    if (e.kind === 'translation_es_uk') return !String(e.answerUk || '').trim();
    return !String(e.answerEs || '').trim();
  });
  if (noAnswer.length) issues.push('Вправ без правильної відповіді: ' + noAnswer.length);

  for (const level of LEVELS) {
    if (!content.topics.some((t) => t.level === level)) {
      issues.push('Немає тем для рівня ' + level);
    }
  }
  return issues;
}

// MARK: - Вибірки

export function wordsOfLevel(content, level, topicId) {
  return content.words
    .filter((w) => w.level === level && (!topicId || w.topicId === topicId))
    .sort((a, b) => (a.frequencyRank || 0) - (b.frequencyRank || 0));
}

export function sentencesOfLevel(content, level, topicId) {
  return content.sentences.filter((s) => s.level === level && (!topicId || s.topicId === topicId));
}

export function exercisesOfLevel(content, level, topicId, kind) {
  return content.exercises.filter((e) =>
    e.level === level && (!topicId || e.topicId === topicId) && (!kind || e.kind === kind));
}

export function topicsOfLevel(content, level) {
  return content.topics
    .filter((t) => t.level === level)
    .sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0));
}

export function listeningOfLevel(content, level, topicId) {
  return content.listening
    .filter((l) => l.level === level && (!topicId || l.topicId === topicId))
    .sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0));
}

export function grammarOfLevel(content, level) {
  return content.grammar
    .filter((g) => g.level === level)
    .sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0));
}

export function wordsOfTopic(content, topicId) {
  return content.words
    .filter((w) => w.topicId === topicId)
    .sort((a, b) => (a.frequencyRank || 0) - (b.frequencyRank || 0));
}

export function wordsWithTag(content, tag) {
  return content.words.filter((w) => (w.grammarTags || []).includes(tag));
}

export function grammarByTag(content, tag) {
  return content.grammar.find((g) => g.tag === tag) || null;
}

export function grammarByTags(content, tags) {
  return (tags || []).map((tag) => grammarByTag(content, tag)).filter(Boolean);
}
