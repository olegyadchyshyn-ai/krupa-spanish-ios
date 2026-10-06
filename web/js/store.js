// Рушій навчання та збереження прогресу (порт логіки iOS/Android-версії).
//
// Модуль не торкається DOM і працює з будь-яким сховищем із двома методами
// getItem/setItem — тому його можна перевіряти в Node з пам'яттю замість
// localStorage.

// MARK: - Оцінки та фази

export const GRADES = ['AGAIN', 'HARD', 'GOOD', 'EASY'];

export const GRADE_INFO = {
  AGAIN: { title: 'Не знаю', short: 'Не знаю', symbol: '✕', correct: false, xp: 1 },
  HARD: { title: 'Пам\'ятаю з труднощами', short: 'Трудно', symbol: '~', correct: true, xp: 2 },
  GOOD: { title: 'Знаю', short: 'Знаю', symbol: '✓', correct: true, xp: 3 },
  EASY: { title: 'Дуже добре', short: 'Легко', symbol: '★', correct: true, xp: 4 }
};

export const PHASES = {
  NEW: 'Нова',
  LEARNING: 'Вивчається',
  REVIEW: 'На повторенні',
  RELEARNING: 'Переучується'
};

export const GOALS = [
  { id: 'COMMUNICATION', title: 'Спілкування', description: 'Друзі, серіали, музика, інтернет' },
  { id: 'RELOCATION', title: 'Переїзд', description: 'Побут, документи, оренда житла, лікарі' },
  { id: 'STUDY', title: 'Навчання', description: 'Іспити, університет, сертифікати DELE' },
  { id: 'TRAVEL', title: 'Подорожі', description: 'Розмови в аеропорту, готелі, кафе, на вулиці' },
  { id: 'WORK', title: 'Робота', description: 'Ділове листування, зустрічі, професійна лексика' }
];

// MARK: - Інтервальне повторення (SM-2, константи оригіналу)

export const SrsEngine = {
  initialEase: 2.5,
  minEase: 1.3,
  maxEase: 2.8,
  learningStepMinutes: 10,
  againStepMinutes: 1,
  relearningStepMinutes: 10,
  easeBonus: 0.15,
  easePenalty: 0.15,
  lapseEasePenalty: 0.2,
  hardEasePenalty: 0.075,
  lapseRatioThreshold: 0.4,
  hardMultiplier: 1.2,
  easyBonus: 1.25,
  graduatingDays: 1,
  easyDays: 4,
  maxDays: 365,
  learnedDays: 21,
  dayMs: 86400000,

  /** Застосовує оцінку до картки, повертає нову картку. */
  apply(grade, card, responseMs) {
    const updated = Object.assign({}, card);
    const ms = Number(responseMs) || 0;
    const previousAverage = updated.averageResponseMs || 0;

    updated.totalReviews = (updated.totalReviews || 0) + 1;
    if (GRADE_INFO[grade].correct) updated.correctReviews = (updated.correctReviews || 0) + 1;
    updated.averageResponseMs = previousAverage === 0
      ? ms
      : (previousAverage * 3 + ms) / 4;
    updated.lastReviewedAt = Date.now();
    if (grade === 'AGAIN') updated.lapses = (updated.lapses || 0) + 1;

    const now = Date.now();
    if (updated.phase === 'NEW' || updated.phase === 'LEARNING') {
      this.applyLearning(grade, updated, now);
    } else if (updated.phase === 'REVIEW') {
      this.applyReview(grade, updated, now, ms);
    } else {
      this.applyRelearning(grade, updated, now);
    }
    return updated;
  },

  applyLearning(grade, card, now) {
    if (grade === 'AGAIN') {
      card.phase = 'LEARNING';
      card.ease = Math.max(this.minEase, card.ease - this.easePenalty);
      card.intervalMinutes = this.againStepMinutes;
      card.intervalDays = 0;
      card.dueAt = now + this.againStepMinutes * 60000;
    } else if (grade === 'HARD') {
      card.phase = 'LEARNING';
      card.ease = Math.max(this.minEase, card.ease - this.easePenalty);
      card.intervalMinutes = this.learningStepMinutes;
      card.intervalDays = 0;
      card.dueAt = now + this.learningStepMinutes * 60000;
    } else if (grade === 'GOOD') {
      card.phase = 'REVIEW';
      card.intervalMinutes = 0;
      card.intervalDays = this.graduatingDays;
      card.repetitions = (card.repetitions || 0) + 1;
      card.dueAt = now + this.graduatingDays * this.dayMs;
    } else {
      card.phase = 'REVIEW';
      card.intervalMinutes = 0;
      card.intervalDays = this.easyDays;
      card.repetitions = (card.repetitions || 0) + 1;
      card.ease = Math.min(this.maxEase, card.ease + this.easeBonus);
      card.dueAt = now + this.easyDays * this.dayMs;
    }
  },

  applyReview(grade, card, now, responseMs) {
    const previous = Math.max(card.intervalDays || 0, 1);
    if (grade === 'AGAIN') {
      card.ease = Math.max(this.minEase, card.ease - this.lapseEasePenalty);
      card.phase = 'RELEARNING';
      card.intervalMinutes = this.relearningStepMinutes;
      card.intervalDays = 0;
      card.dueAt = now + this.relearningStepMinutes * 60000;
      return;
    }
    const speed = this.speedFactor(grade, responseMs, card);
    let base;
    if (grade === 'HARD') {
      const lapseRatio = card.totalReviews > 0 ? (card.lapses || 0) / card.totalReviews : 0;
      if (lapseRatio > this.lapseRatioThreshold) {
        card.ease = Math.max(this.minEase, card.ease - this.hardEasePenalty);
      }
      base = Math.max(card.ease * previous, Math.max(this.hardMultiplier * previous, previous + 1));
    } else if (grade === 'GOOD') {
      base = previous * card.ease;
    } else {
      base = previous * card.ease * this.easyBonus;
      card.ease = Math.min(this.maxEase, card.ease + this.easeBonus);
    }
    card.intervalDays = this.clampInterval(base * speed);
    card.intervalMinutes = 0;
    card.repetitions = (card.repetitions || 0) + 1;
    card.dueAt = now + card.intervalDays * this.dayMs;
  },

  applyRelearning(grade, card, now) {
    if (grade === 'AGAIN') {
      card.intervalMinutes = this.againStepMinutes;
      card.dueAt = now + this.againStepMinutes * 60000;
      return;
    }
    if (grade === 'HARD') {
      card.intervalMinutes = this.relearningStepMinutes;
      card.dueAt = now + this.relearningStepMinutes * 60000;
      return;
    }
    const base = grade === 'EASY' ? 1 * this.easyBonus : 1;
    card.phase = 'REVIEW';
    card.intervalMinutes = 0;
    card.intervalDays = this.clampInterval(base);
    card.repetitions = (card.repetitions || 0) + 1;
    card.dueAt = now + card.intervalDays * this.dayMs;
  },

  speedFactor(grade, responseMs, card) {
    if (grade === 'AGAIN') return 1;
    if (!responseMs || !card.averageResponseMs) return 1;
    const ratio = responseMs / card.averageResponseMs;
    if (ratio < 0.6) return 1.1;
    if (ratio > 1.6) return 0.92;
    return 1;
  },

  clampInterval(days) {
    return Math.min(this.maxDays, Math.max(1, Math.trunc(days)));
  },

  /** Текст інтервалу: «10 хв», «4 дн», «2 міс». */
  intervalLabel(card) {
    if (card.intervalMinutes > 0) {
      const minutes = card.intervalMinutes;
      if (minutes < 60) return minutes + ' хв';
      return Math.round(minutes / 60) + ' год';
    }
    const days = Math.max(0, Math.trunc(card.intervalDays || 0));
    if (days < 1) return 'зараз';
    if (days < 31) return days + ' дн';
    if (days < 365) return Math.round(days / 30) + ' міс';
    return '1 рік';
  },

  previews(card) {
    return GRADES.map((grade) => ({
      grade,
      label: GRADE_INFO[grade].short,
      symbol: GRADE_INFO[grade].symbol,
      interval: this.intervalLabel(this.apply(grade, card, 0))
    }));
  },

  isLearned(card) {
    return card.phase === 'REVIEW' && (card.intervalDays || 0) >= this.learnedDays;
  }
};

// MARK: - Перевірка відповідей

export const AnswerCheck = {
  /** Порівняння: наголоси важливі, регістр і пунктуація — ні. */
  check(user, expected, allowTypo) {
    const userText = String(user == null ? '' : user).trim();
    const expectedText = String(expected == null ? '' : expected).trim();
    if (!userText || !expectedText) return { correct: false, message: 'Порожня відповідь' };

    const strict = (text) => text.replace(/\s+/g, ' ').toLowerCase();
    if (strict(userText) === strict(expectedText)) {
      return { correct: true, message: 'Правильно!' };
    }

    const looseUser = normalizeLoose(userText);
    const looseExpected = normalizeLoose(expectedText);
    if (looseUser === looseExpected) return { correct: true, message: 'Правильно.' };
    if (looseUser.replace(/ /g, '') === looseExpected.replace(/ /g, '')) {
      return { correct: true, message: 'Правильно.' };
    }

    if (stripAccents(looseUser) === stripAccents(looseExpected)) {
      return { correct: false, message: 'Неправильний наголос — це змінює значення слова.' };
    }

    if (allowTypo) {
      const words = looseExpected.split(' ').filter(Boolean);
      if (words.length >= 3) {
        const distance = levenshtein(looseUser, looseExpected);
        if (distance <= (looseExpected.length <= 12 ? 1 : 2)) {
          return { correct: true, message: 'Майже — невеличка одруківка.' };
        }
      }
    }
    return { correct: false, message: 'Не зовсім.' };
  },

  anyOf(user, variants) {
    for (const variant of variants || []) {
      const result = this.check(user, variant);
      if (result.correct) return result;
    }
    return { correct: false, message: 'Не зовсім.' };
  }
};

export function normalizeLoose(text) {
  return String(text == null ? '' : text)
    .toLowerCase()
    .replace(/[¡¿!?.,;:"«»()[\]…—–]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export function stripAccents(text) {
  return String(text == null ? '' : text).normalize('NFD').replace(/[\u0300-\u036f]/g, '');
}

export function levenshtein(a, b) {
  const s = String(a == null ? '' : a);
  const t = String(b == null ? '' : b);
  if (!s.length) return t.length;
  if (!t.length) return s.length;
  let previous = Array.from({ length: t.length + 1 }, (_, i) => i);
  let current = new Array(t.length + 1).fill(0);
  for (let i = 1; i <= s.length; i++) {
    current[0] = i;
    for (let j = 1; j <= t.length; j++) {
      const cost = s[i - 1] === t[j - 1] ? 0 : 1;
      current[j] = Math.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost);
    }
    previous = current.slice();
  }
  return previous[t.length];
}

export function similarity(a, b) {
  const s = stripAccents(normalizeLoose(a));
  const t = stripAccents(normalizeLoose(b));
  const longest = Math.max(s.length, t.length);
  if (!longest) return 0;
  return Math.max(0, (1 - levenshtein(s, t) / longest) * 100);
}

// MARK: - Елементи заняття

export const PROMPTS = {
  recognize: 'Оберіть переклад',
  recall: 'Напишіть іспанською',
  listen: 'Напишіть, що почули',
  buildSentence: 'Складіть речення'
};

export function makeItem(kind, data, prompt) {
  return { kind, data, prompt: prompt || null };
}

export function itemId(item) {
  return item.kind + ':' + item.data.id + (item.prompt ? ':' + item.prompt : '');
}

export function itemContentId(item) {
  return item.data.id;
}

export function itemType(item) {
  if (item.kind === 'listening') return 'LISTENING';
  if (item.kind === 'exercise') return 'EXERCISE';
  if (item.kind === 'sentence') return 'SENTENCE';
  return 'WORD';
}

export function itemGrammarTags(item) {
  const data = item.data;
  if (item.kind === 'word' || item.kind === 'sentence') return data.grammarTags || [];
  if (item.kind === 'exercise') return data.grammarTag ? [data.grammarTag] : [];
  if (item.kind === 'grammar') return [data.tag];
  return [];
}

export function itemSpanish(item) {
  const data = item.data;
  if (item.kind === 'word') {
    return item.prompt === 'recognize' ? withArticle(data) : data.spanish;
  }
  if (item.kind === 'sentence') return data.spanish;
  if (item.kind === 'exercise') {
    if (data.kind === 'listening' || data.kind === 'dictation') return data.answerEs;
    return data.promptEs || null;
  }
  if (item.kind === 'grammar') return (data.examples && data.examples[0] && data.examples[0].spanish) || null;
  if (item.kind === 'listening') return (data.lines || []).map((l) => l.spanish).join(' ');
  return null;
}

export function itemUkrainian(item) {
  const data = item.data;
  if (item.kind === 'word') return data.translationUk;
  if (item.kind === 'sentence') return data.translationUk;
  if (item.kind === 'exercise') return data.promptUk || null;
  if (item.kind === 'grammar') return data.titleUk;
  if (item.kind === 'listening') return data.titleUk;
  return null;
}

export function itemTitle(item) {
  const data = item.data;
  if (item.kind === 'word') return withArticle(data);
  if (item.kind === 'sentence') return data.spanish;
  if (item.kind === 'exercise') return data.promptEs || data.promptUk;
  if (item.kind === 'grammar') return data.titleEs || data.titleUk;
  if (item.kind === 'listening') return data.titleEs || data.titleUk;
  return '';
}

export function itemIsGraded(item) {
  return item.kind !== 'grammar';
}

export function withArticle(word) {
  if (!word.withArticle) return word.spanish;
  if (word.gender === 'm') return 'el ' + word.spanish;
  if (word.gender === 'f') return 'la ' + word.spanish;
  return word.spanish;
}

/** Варіанти відповіді для вправи з вибором. */
export function exerciseChoices(exercise, shuffle) {
  let items;
  if (exercise.kind === 'translation_es_uk' || exercise.kind === 'multiple_choice') {
    items = [exercise.answerUk].concat(exercise.distractors || []);
  } else {
    items = [exercise.answerEs].concat(exercise.distractors || []);
  }
  items = items.filter((value, index) => value && items.indexOf(value) === index);
  return shuffle ? shuffleArray(items) : items;
}

/** Токени для складання речення. */
export function buildTokens(exercise) {
  if (exercise.tokens && exercise.tokens.length) return exercise.tokens.slice();
  return String(exercise.answerEs || '')
    .replace(/[¿?¡!]/g, '')
    .split(' ')
    .filter(Boolean);
}

export function shuffleArray(list) {
  const copy = list.slice();
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

// MARK: - Перевірка кроку заняття

export function checkItem(item, answer) {
  const data = item.data;

  if (item.kind === 'grammar') {
    return { correct: true, message: 'Прочитано', correctAnswer: '', explanation: '' };
  }

  if (item.kind === 'word') {
    const expected = item.prompt === 'recognize' ? data.translationUk : data.spanish;
    const result = AnswerCheck.check(answer, expected);
    return {
      correct: result.correct,
      message: result.message,
      correctAnswer: expected,
      explanation: result.correct ? (data.notesUk || '') : data.exampleEs
    };
  }

  if (item.kind === 'sentence') {
    const result = AnswerCheck.check(answer, data.spanish);
    return {
      correct: result.correct,
      message: result.message,
      correctAnswer: data.spanish,
      explanation: result.correct ? (data.audioHint || '') : data.translationUk
    };
  }

  if (item.kind === 'listening') {
    const expected = (data.lines && data.lines[0] && data.lines[0].spanish) || '';
    const result = AnswerCheck.check(answer, expected);
    return { correct: result.correct, message: result.message, correctAnswer: expected, explanation: '' };
  }

  // Вправи
  switch (data.kind) {
    case 'multiple_choice':
    case 'translation_es_uk': {
      const result = AnswerCheck.anyOf(answer, [data.answerUk, data.answerEs]);
      return {
        correct: result.correct,
        message: result.message,
        correctAnswer: data.answerUk || data.answerEs,
        explanation: data.explanationUk || ''
      };
    }
    case 'fill_gap': {
      const expected = data.gapAnswer || data.answerEs;
      const result = AnswerCheck.check(answer, expected);
      return { correct: result.correct, message: result.message, correctAnswer: expected, explanation: data.explanationUk || '' };
    }
    case 'match_pairs':
    case 'sentence_build': {
      const result = AnswerCheck.check(answer, data.answerEs);
      return { correct: result.correct, message: result.message, correctAnswer: data.answerEs, explanation: data.explanationUk || '' };
    }
    default: {
      const result = AnswerCheck.check(answer, data.answerEs);
      return { correct: result.correct, message: result.message, correctAnswer: data.answerEs, explanation: data.explanationUk || '' };
    }
  }
}

/** Оцінка для SRS за результатом перевірки. */
export function gradeFor(item, answer, usedHint) {
  if (item.kind === 'grammar') return 'GOOD';
  const result = checkItem(item, answer);
  if (!result.correct) return 'AGAIN';
  return usedHint ? 'HARD' : 'GOOD';
}

// MARK: - План заняття

export const BLOCKS = {
  REVIEW: { title: 'Повторення', icon: '🔄' },
  NEW_WORDS: { title: 'Нові слова', icon: '✨' },
  GRAMMAR: { title: 'Граматика', icon: '📘' },
  EXERCISES: { title: 'Вправи', icon: '✏️' },
  LISTENING: { title: 'Аудіювання', icon: '🎧' },
  SPEAKING: { title: 'Говоріння', icon: '🎤' }
};

export const SESSION_LIMITS = {
  newWordsPerSession: 8,
  reviewItemsPerSession: 60,
  dueCardsLimit: 120,
  exercisesPerSession: 8,
  grammarPerSession: 2,
  listeningPerSession: 1,
  speakingPerSession: 3
};

function promptForWord(store, word, isNew) {
  if (isNew) return 'recognize';
  const card = store.card(word.id);
  if (!card) return 'recognize';
  if ((card.lapses || 0) >= 2) return 'recognize';
  if ((card.intervalDays || 0) >= 7) return 'listen';
  return 'recall';
}

/** Складає план заняття: повторення → нові слова → граматика → вправи → аудіювання → говоріння. */
export function buildPlan(store, content, options) {
  const opts = options || {};
  const level = opts.level || store.profile.level;
  const topicId = opts.topicId || null;
  const blocks = [];

  // 1. Повторення
  const due = store.dueCards().slice(0, SESSION_LIMITS.reviewItemsPerSession);
  const reviewItems = [];
  for (const card of due) {
    const item = itemFromCard(content, card, store);
    if (item) reviewItems.push(item);
  }
  if (reviewItems.length) blocks.push({ kind: 'REVIEW', items: reviewItems });

  // 2. Нові слова
  const remainingToday = Math.max(0, store.settings.newCardsPerDay - store.todayStat().newCards);
  const newLimit = Math.min(SESSION_LIMITS.newWordsPerSession, remainingToday);
  if (newLimit > 0) {
    const candidates = wordsOfLevelSafe(content, level, topicId)
      .filter((word) => !store.card(word.id))
      .slice(0, newLimit);
    if (candidates.length) {
      blocks.push({
        kind: 'NEW_WORDS',
        items: candidates.map((word) => makeItem('word', word, promptForWord(store, word, true)))
      });
    }
  }

  // 3. Граматика
  const topic = topicId ? content.topicById.get(topicId) : null;
  const tags = (topic && topic.grammarTags && topic.grammarTags.length)
    ? topic.grammarTags
    : goalTags(store.profile.goal);
  const grammarNotes = tags
    .map((tag) => content.grammar.find((g) => g.tag === tag))
    .filter(Boolean)
    .filter((note) => levelOrder(note.level) <= levelOrder(level))
    .slice(0, SESSION_LIMITS.grammarPerSession);
  if (grammarNotes.length) {
    blocks.push({ kind: 'GRAMMAR', items: grammarNotes.map((note) => makeItem('grammar', note)) });
  }

  // 4. Вправи (спершу слабкі теми)
  const weakTags = new Set(store.weakGrammarTags());
  let pool = exercisesOfLevel(content, level, topicId);
  if (!pool.length) pool = exercisesOfLevel(content, level);
  const weak = pool.filter((e) => weakTags.has(e.grammarTag));
  const rest = shuffleArray(pool.filter((e) => !weakTags.has(e.grammarTag)));
  const chosen = [];
  const kindCounts = {};
  for (const exercise of weak.concat(rest)) {
    if (chosen.length >= SESSION_LIMITS.exercisesPerSession) break;
    const count = kindCounts[exercise.kind] || 0;
    if (count >= 2) continue;
    kindCounts[exercise.kind] = count + 1;
    chosen.push(exercise);
  }
  if (chosen.length) {
    blocks.push({ kind: 'EXERCISES', items: chosen.map((exercise) => makeItem('exercise', exercise)) });
  }

  // 5. Аудіювання
  const listening = listeningOfLevel(content, level, topicId);
  const listeningPool = listening.length ? listening : listeningOfLevel(content, level);
  if (listeningPool.length) {
    blocks.push({
      kind: 'LISTENING',
      items: listeningPool.slice(0, SESSION_LIMITS.listeningPerSession).map((item) => makeItem('listening', item))
    });
  }

  // 6. Говоріння
  const speakingExercises = exercisesOfLevel(content, level, topicId, 'speaking');
  let speakingItems = speakingExercises.slice(0, SESSION_LIMITS.speakingPerSession)
    .map((exercise) => makeItem('exercise', exercise));
  if (!speakingItems.length) {
    speakingItems = sentencesOfLevel(content, level, topicId)
      .filter((s) => s.spanish.length <= 60)
      .slice(0, SESSION_LIMITS.speakingPerSession)
      .map((sentence) => makeItem('sentence', sentence, 'recall'));
  }
  if (speakingItems.length) blocks.push({ kind: 'SPEAKING', items: speakingItems });

  const items = blocks.reduce((acc, block) => acc.concat(block.items), []);
  return { level, topicId, blocks, items, createdAt: Date.now() };
}

/** План лише з повторень. */
export function buildReviewPlan(store, content) {
  const due = store.dueCards().slice(0, SESSION_LIMITS.reviewItemsPerSession);
  const items = due.map((card) => itemFromCard(content, card, store)).filter(Boolean);
  return {
    level: store.profile.level,
    topicId: null,
    blocks: items.length ? [{ kind: 'REVIEW', items }] : [],
    items,
    createdAt: Date.now()
  };
}

function itemFromCard(content, card, store) {
  if (card.itemType === 'WORD') {
    const word = content.wordById.get(card.itemId);
    return word ? makeItem('word', word, promptForWord(store, word, false)) : null;
  }
  if (card.itemType === 'SENTENCE') {
    const sentence = content.sentenceById.get(card.itemId);
    return sentence ? makeItem('sentence', sentence, 'recall') : null;
  }
  if (card.itemType === 'EXERCISE') {
    const exercise = content.exerciseById.get(card.itemId);
    return exercise ? makeItem('exercise', exercise) : null;
  }
  if (card.itemType === 'LISTENING') {
    const item = content.listeningById.get(card.itemId);
    return item ? makeItem('listening', item) : null;
  }
  return null;
}

function goalTags(goal) {
  switch (goal) {
    case 'COMMUNICATION': return ['present_irregular', 'gustar', 'question_words'];
    case 'RELOCATION': return ['ser_estar', 'articles', 'numbers'];
    case 'STUDY': return ['past_tenses', 'connectors'];
    case 'TRAVEL': return ['polite_forms', 'numbers', 'time_expressions'];
    case 'WORK': return ['past_tenses', 'connectors'];
    default: return ['present_irregular'];
  }
}

function levelOrder(level) {
  return level === 'A0' ? 0 : level === 'A1' ? 1 : 2;
}

function wordsOfLevelSafe(content, level, topicId) {
  return content.words
    .filter((w) => w.level === level && (!topicId || w.topicId === topicId))
    .sort((a, b) => (a.frequencyRank || 0) - (b.frequencyRank || 0));
}

function sentencesOfLevel(content, level, topicId) {
  return content.sentences.filter((s) => s.level === level && (!topicId || s.topicId === topicId));
}

function exercisesOfLevel(content, level, topicId, kind) {
  return content.exercises.filter((e) =>
    e.level === level && (!topicId || e.topicId === topicId) && (!kind || e.kind === kind));
}

function listeningOfLevel(content, level, topicId) {
  return content.listening
    .filter((l) => l.level === level && (!topicId || l.topicId === topicId))
    .sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0));
}

// MARK: - Сховище прогресу

export const DEFAULT_PROFILE = {
  level: 'A0',
  goal: 'COMMUNICATION',
  dailyMinutes: 20,
  theme: 'system',
  ttsRate: 0.9,
  ttsVoice: 'any',
  assessmentDone: false,
  assessmentScore: 0,
  onboardingDone: false,
  displayName: '',
  dailyCardGoal: 30,
  startedAt: Date.now()
};

export const DEFAULT_SETTINGS = {
  autoPlayAudio: true,
  showPronunciationHints: true,
  showIpa: false,
  showTranslationFirst: false,
  sessionSize: 20,
  newCardsPerDay: 10,
  reviewsPerDay: 100,
  listeningHints: true,
  haptics: true
};

export function dayKey(date) {
  const d = date ? new Date(date) : new Date();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return d.getFullYear() + '-' + month + '-' + day;
}

export function emptyStat(day) {
  return { day, reviews: 0, correct: 0, newCards: 0, minutes: 0, xp: 0, speaking: 0, listening: 0 };
}

/**
 * Створює сховище прогресу.
 * @param {{getItem:Function,setItem:Function}} storage
 * @param {object} content
 */
export function createStore(storage, content) {
  const KEY = 'krupa-progress-v1';
  let data = load();

  function load() {
    try {
      const raw = storage.getItem(KEY);
      if (!raw) throw new Error('empty');
      const parsed = JSON.parse(raw);
      return {
        profile: Object.assign({}, DEFAULT_PROFILE, parsed.profile || {}),
        settings: Object.assign({}, DEFAULT_SETTINGS, parsed.settings || {}),
        cards: parsed.cards || {},
        dailyStats: parsed.dailyStats || {},
        mistakes: parsed.mistakes || {},
        reviewLog: parsed.reviewLog || [],
        conversations: parsed.conversations || []
      };
    } catch (error) {
      return {
        profile: Object.assign({}, DEFAULT_PROFILE),
        settings: Object.assign({}, DEFAULT_SETTINGS),
        cards: {}, dailyStats: {}, mistakes: {}, reviewLog: [], conversations: []
      };
    }
  }

  function save() {
    try {
      storage.setItem(KEY, JSON.stringify(data));
    } catch (error) {
      // Сховище може бути недоступним (приватний режим) — не ламаємо застосунок.
    }
  }

  const store = {
    data,
    get profile() { return data.profile; },
    get settings() { return data.settings; },
    get cards() { return data.cards; },

    save,

    updateProfile(patch) {
      Object.assign(data.profile, patch);
      save();
    },

    updateSettings(patch) {
      Object.assign(data.settings, patch);
      save();
    },

    card(id) {
      return data.cards[id] || null;
    },

    cardOrCreate(item) {
      const id = itemContentId(item);
      if (data.cards[id]) return data.cards[id];
      const level = item.data.level || data.profile.level;
      const card = {
        itemId: id,
        itemType: itemType(item),
        levelCode: level,
        topicId: item.data.topicId || '',
        grammarTags: itemGrammarTags(item),
        phase: 'NEW',
        dueAt: Date.now(),
        intervalMinutes: 0,
        intervalDays: 0,
        ease: SrsEngine.initialEase,
        repetitions: 0,
        lapses: 0,
        totalReviews: 0,
        correctReviews: 0,
        averageResponseMs: 0,
        firstSeenAt: Date.now(),
        lastReviewedAt: null,
        suspended: false
      };
      data.cards[id] = card;
      save();
      return card;
    },

    upsertCard(card) {
      data.cards[card.itemId] = card;
      save();
    },

    setSuspended(itemId, suspended) {
      const card = data.cards[itemId];
      if (!card) return;
      card.suspended = suspended;
      save();
    },

    dueCards() {
      const now = Date.now();
      return Object.values(data.cards)
        .filter((card) => !card.suspended && card.phase !== 'NEW' && card.dueAt <= now)
        .sort((a, b) => a.dueAt - b.dueAt);
    },

    newCards() {
      return Object.values(data.cards).filter((card) => card.phase === 'NEW' && !card.suspended);
    },

    dailyStat(date) {
      const key = dayKey(date);
      return data.dailyStats[key] || emptyStat(key);
    },

    todayStat() {
      return this.dailyStat(new Date());
    },

    bumpTodayStat(patch) {
      const key = dayKey(new Date());
      const stat = data.dailyStats[key] || emptyStat(key);
      Object.assign(stat, patch(stat));
      data.dailyStats[key] = stat;
      save();
      return stat;
    },

    /** Записує відповідь: картка, журнал, статистика, помилки. */
    recordAnswer(item, grade, responseMs, usedHint) {
      const card = this.cardOrCreate(item);
      const updated = SrsEngine.apply(grade, card, responseMs);
      data.cards[updated.itemId] = updated;

      data.reviewLog.push({
        itemId: updated.itemId,
        itemType: updated.itemType,
        grade,
        at: Date.now(),
        responseMs: responseMs || 0,
        topicId: updated.topicId
      });
      if (data.reviewLog.length > 3000) data.reviewLog.splice(0, data.reviewLog.length - 3000);

      const isFirst = (card.totalReviews || 0) === 0;
      const key = dayKey(new Date());
      const stat = data.dailyStats[key] || emptyStat(key);
      stat.reviews += 1;
      if (GRADE_INFO[grade].correct) stat.correct += 1;
      if (isFirst) stat.newCards += 1;
      stat.minutes += Math.max(0.05, (responseMs || 0) / 60000);
      stat.xp += GRADE_INFO[grade].xp;
      data.dailyStats[key] = stat;

      for (const tag of itemGrammarTags(item)) {
        this.recordMistake(tag, 'grammar', GRADE_INFO[grade].correct);
      }
      if (item.kind === 'word') {
        this.recordMistake(item.data.id, 'word', GRADE_INFO[grade].correct);
      }

      save();
      return updated;
    },

    recordMistake(key, kind, correct) {
      if (!key) return;
      const stat = data.mistakes[key] || { key, kind, attempts: 0, wrong: 0, lastWrongAt: null };
      stat.attempts += 1;
      if (!correct) {
        stat.wrong += 1;
        stat.lastWrongAt = Date.now();
      }
      data.mistakes[key] = stat;
      save();
    },

    weakGrammarTags() {
      return Object.values(data.mistakes)
        .filter((m) => m.kind === 'grammar' && m.attempts >= 2 && m.wrong / m.attempts >= 0.3)
        .sort((a, b) => (b.wrong / b.attempts) - (a.wrong / a.attempts))
        .slice(0, 5)
        .map((m) => m.key);
    },

    weakSpots(limit) {
      return Object.values(data.mistakes)
        .filter((m) => m.attempts >= 3 && m.wrong / m.attempts > 0.3)
        .sort((a, b) => (b.wrong / b.attempts) - (a.wrong / a.attempts))
        .slice(0, limit || 10)
        .map((m) => ({
          key: m.key,
          kind: m.kind,
          attempts: m.attempts,
          wrong: m.wrong,
          rate: m.wrong / m.attempts
        }));
    },

    get streakDays() {
      let streak = 0;
      const cursor = new Date();
      if (this.dailyStat(cursor).reviews === 0) cursor.setDate(cursor.getDate() - 1);
      for (;;) {
        if (this.dailyStat(cursor).reviews > 0) {
          streak += 1;
          cursor.setDate(cursor.getDate() - 1);
        } else break;
      }
      return streak;
    },

    longestStreak() {
      const days = Object.values(data.dailyStats)
        .filter((s) => s.reviews > 0)
        .map((s) => s.day)
        .sort();
      let best = 0;
      let current = 0;
      let previous = null;
      for (const day of days) {
        if (previous) {
          const expected = new Date(previous);
          expected.setDate(expected.getDate() + 1);
          current = dayKey(expected) === day ? current + 1 : 1;
        } else {
          current = 1;
        }
        best = Math.max(best, current);
        previous = day;
      }
      return best;
    },

    snapshot() {
      const cards = Object.values(data.cards);
      const reviewed = cards.filter((c) => (c.totalReviews || 0) > 0);
      const totalReviews = cards.reduce((sum, c) => sum + (c.totalReviews || 0), 0);
      const correct = cards.reduce((sum, c) => sum + (c.correctReviews || 0), 0);
      const learned = reviewed.filter((c) => SrsEngine.isLearned(c)).length;
      const today = this.todayStat();
      const stats = Object.values(data.dailyStats);

      return {
        streakDays: this.streakDays,
        longestStreak: this.longestStreak(),
        totalReviews,
        accuracy: totalReviews ? (correct / totalReviews) * 100 : 0,
        wordsLearned: learned,
        wordsInProgress: reviewed.length - learned,
        dueToday: this.dueCards().length,
        totalMinutes: stats.reduce((sum, s) => sum + (s.minutes || 0), 0),
        totalXP: stats.reduce((sum, s) => sum + (s.xp || 0), 0),
        reviewsToday: today.reviews,
        minutesToday: today.minutes,
        dailyGoal: data.profile.dailyCardGoal || 30,
        goalFraction: Math.min(1, today.reviews / Math.max(1, data.profile.dailyCardGoal || 30))
      };
    },

    topicsWithProgress(level) {
      const target = level || data.profile.level;
      return content.topics
        .filter((topic) => topic.level === target)
        .sort((a, b) => (a.orderIndex || 0) - (b.orderIndex || 0))
        .map((topic) => {
          const words = content.words.filter((w) => w.topicId === topic.id);
          const learned = words.filter((w) => {
            const card = data.cards[w.id];
            return card && SrsEngine.isLearned(card);
          }).length;
          return {
            topic,
            wordsCount: words.length,
            learned,
            fraction: words.length ? learned / words.length : 0
          };
        });
    },

    exportJSON() {
      return JSON.stringify({
        app: 'KRUPA Spanish (web)',
        formatVersion: 1,
        exportedAt: new Date().toISOString(),
        state: data
      }, null, 2);
    },

    importJSON(text, mode) {
      const parsed = JSON.parse(text);
      const incoming = parsed.state || parsed;
      if (!incoming || !incoming.cards) throw new Error('Файл не схожий на резервну копію');

      if (mode === 'merge') {
        for (const [id, card] of Object.entries(incoming.cards)) {
          const existing = data.cards[id];
          if (!existing || (card.totalReviews || 0) > (existing.totalReviews || 0)) {
            data.cards[id] = card;
          }
        }
        for (const [day, stat] of Object.entries(incoming.dailyStats || {})) {
          const existing = data.dailyStats[day];
          if (!existing || stat.reviews > existing.reviews) data.dailyStats[day] = stat;
        }
        for (const [key, mistake] of Object.entries(incoming.mistakes || {})) {
          if (!data.mistakes[key]) data.mistakes[key] = mistake;
        }
      } else {
        data = Object.assign(data, incoming);
      }
      save();
      return true;
    },

    reset() {
      data.profile = Object.assign({}, DEFAULT_PROFILE);
      data.settings = Object.assign({}, DEFAULT_SETTINGS);
      data.cards = {};
      data.dailyStats = {};
      data.mistakes = {};
      data.reviewLog = [];
      data.conversations = [];
      save();
    }
  };

  return store;
}

/** Сховище в пам'яті — для тестів і приватного режиму браузера. */
export function createMemoryStorage() {
  const map = new Map();
  return {
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: (key) => map.delete(key)
  };
}
