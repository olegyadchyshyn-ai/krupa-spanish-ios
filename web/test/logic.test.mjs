// Тести логіки веб-версії: контент, SRS, перевірка відповідей, план заняття.
//
// Запуск:  node web/test/logic.test.mjs
//
// Тести працюють без браузера: fetch підмінюється читанням файлів із диска,
// localStorage — сховищем у пам'яті.

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

import { loadContent, wordsOfLevel, topicsOfLevel } from '../js/content.js';
import {
  createStore, createMemoryStorage, SrsEngine, AnswerCheck,
  buildPlan, checkItem, gradeFor, dayKey, GRADE_INFO
} from '../js/store.js';

const here = dirname(fileURLToPath(import.meta.url));
const contentRoot = join(here, '..', 'content') + '/';

let passed = 0;
let failed = 0;

function check(name, condition, details) {
  if (condition) {
    passed += 1;
    console.log('  ✓ ' + name);
  } else {
    failed += 1;
    console.log('  ✗ ' + name + (details ? '  → ' + details : ''));
  }
}

function group(title) {
  console.log('\n' + title);
}

// Підміна fetch: читаємо файли з диска.
const fileFetch = async (url) => {
  const path = join(contentRoot, url.replace(/^content\//, ''));
  try {
    const text = await readFile(path, 'utf8');
    return { ok: true, status: 200, json: async () => JSON.parse(text) };
  } catch (error) {
    return { ok: false, status: 404, json: async () => ({}) };
  }
};

const content = await loadContent('content/', fileFetch);

group('Контент');
check('усі 17 файлів прочитано без зауважень', content.issues.length === 0, content.issues.join('; '));
check('слів 1492', content.words.length === 1492, 'маємо ' + content.words.length);
check('речень 432', content.sentences.length === 432, 'маємо ' + content.sentences.length);
check('вправ 466', content.exercises.length === 466, 'маємо ' + content.exercises.length);
check('граматичних тем 34', content.grammar.length === 34, 'маємо ' + content.grammar.length);
check('аудіювань 22', content.listening.length === 22, 'маємо ' + content.listening.length);
check('тем 24', content.topics.length === 24, 'маємо ' + content.topics.length);
check('індекси за id працюють', content.wordById.size === content.words.length);
check('рівні A0/A1/A2 мають теми',
  ['A0', 'A1', 'A2'].every((level) => topicsOfLevel(content, level).length > 0));
check('слова рівня A0 сортовані за частотою', (() => {
  const list = wordsOfLevel(content, 'A0').slice(0, 50);
  for (let i = 1; i < list.length; i++) {
    if ((list[i - 1].frequencyRank || 0) > (list[i].frequencyRank || 0)) return false;
  }
  return true;
})());

group('Перевірка відповідей');
check('точний збіг', AnswerCheck.check('hola', 'hola').correct);
check('регістр не важливий', AnswerCheck.check('HOLA', 'hola').correct);
check('пунктуація не важлива', AnswerCheck.check('¿Cómo estás?', 'como estas').correct === false);
check('наголос важливий', AnswerCheck.check('como estas', 'cómo estás').correct === false);
check('зайві пробіли не важливі', AnswerCheck.check('  la   casa ', 'la casa').correct);
check('порожня відповідь — хибна', AnswerCheck.check('', 'hola').correct === false);
check('одруківка в довгому реченні приймається', AnswerCheck.check('yo quiero un caf', 'yo quiero un cafe', true).correct);
check('одруківка не приймається без дозволу', AnswerCheck.check('yo quiero un caf', 'yo quiero un cafe', false).correct === false);
check('варіант із кількох відповідей', AnswerCheck.anyOf('la casa', ['el coche', 'la casa']).correct);

group('Інтервальне повторення');
const newCard = {
  itemId: 'w_a0_hola', itemType: 'WORD', phase: 'NEW', dueAt: Date.now(),
  intervalMinutes: 0, intervalDays: 0, ease: 2.5, repetitions: 0, lapses: 0,
  totalReviews: 0, correctReviews: 0, averageResponseMs: 0, suspended: false
};

const afterGood = SrsEngine.apply('GOOD', newCard, 3000);
check('«знаю» на новій картці → фаза повторення', afterGood.phase === 'REVIEW', afterGood.phase);
check('інтервал випуску 1 день', afterGood.intervalDays === 1, String(afterGood.intervalDays));

const afterAgain = SrsEngine.apply('AGAIN', newCard, 3000);
check('«не знаю» → фаза навчання', afterAgain.phase === 'LEARNING', afterAgain.phase);
check('крок навчання 1 хв', afterAgain.intervalMinutes === 1, String(afterAgain.intervalMinutes));
check('легкість зменшилась на 0.15', Math.abs(afterAgain.ease - 2.35) < 1e-9, String(afterAgain.ease));
check('зрив зафіксовано', afterAgain.lapses === 1);

const inReview = Object.assign({}, afterGood, {
  intervalDays: 10, ease: 2.5, totalReviews: 3, correctReviews: 3, averageResponseMs: 2000
});
const reviewGood = SrsEngine.apply('GOOD', inReview, 2000);
check('повторення: інтервал зростає за легкістю', reviewGood.intervalDays === 25, String(reviewGood.intervalDays));

const reviewEasy = SrsEngine.apply('EASY', inReview, 2000);
check('«легко» дає бонус 1.25', reviewEasy.intervalDays === 31, String(reviewEasy.intervalDays));
check('«легко» підвищує легкість до 2.65', Math.abs(reviewEasy.ease - 2.65) < 1e-9, String(reviewEasy.ease));

// Швидкість відповіді порівнюється з ОНОВЛЕНИМ середнім (як у порту):
// average = (старе*3 + нове)/4, і вже до нього відноситься responseMs.
const fastCard = Object.assign({}, inReview, { averageResponseMs: 4000 });
check('швидка відповідь дає множник 1.1',
  SrsEngine.apply('GOOD', fastCard, 1000).intervalDays === 27,
  String(SrsEngine.apply('GOOD', fastCard, 1000).intervalDays));

const slowCard = Object.assign({}, inReview, { averageResponseMs: 1000 });
check('повільна відповідь дає множник 0.92',
  SrsEngine.apply('GOOD', slowCard, 20000).intervalDays === 23,
  String(SrsEngine.apply('GOOD', slowCard, 20000).intervalDays));

const reviewAgain = SrsEngine.apply('AGAIN', inReview, 2000);
check('«не знаю» у повторенні → переучування', reviewAgain.phase === 'RELEARNING', reviewAgain.phase);
check('штраф зриву 0.2', Math.abs(reviewAgain.ease - 2.3) < 1e-9, String(reviewAgain.ease));

check('легкість не перевищує 2.8', SrsEngine.apply('EASY', Object.assign({}, inReview, { ease: 2.8 }), 1000).ease <= 2.8);
check('легкість не падає нижче 1.3', SrsEngine.apply('AGAIN', Object.assign({}, inReview, { ease: 1.3 }), 1000).ease >= 1.3);
check('інтервал не перевищує 365 днів',
  SrsEngine.apply('EASY', Object.assign({}, inReview, { intervalDays: 300, ease: 2.8 }), 1000).intervalDays <= 365);

check('підпис інтервалу для хвилин', SrsEngine.intervalLabel({ intervalMinutes: 10, intervalDays: 0 }) === '10 хв');
check('підпис інтервалу для днів', SrsEngine.intervalLabel({ intervalMinutes: 0, intervalDays: 4 }) === '4 дн');
check('підпис інтервалу для місяців', SrsEngine.intervalLabel({ intervalMinutes: 0, intervalDays: 60 }) === '2 міс');
check('вивченим вважається з 21 дня',
  SrsEngine.isLearned({ phase: 'REVIEW', intervalDays: 21 }) && !SrsEngine.isLearned({ phase: 'REVIEW', intervalDays: 20 }));
check('передпрогляд дає 4 оцінки', SrsEngine.previews(newCard).length === 4);

group('Збереження прогресу та заняття');
const storage = createMemoryStorage();
const store = createStore(storage, content);
store.updateProfile({ level: 'A0', onboardingDone: true, dailyCardGoal: 20 });

const plan = buildPlan(store, content, { level: 'A0' });
check('план містить елементи', plan.items.length > 0, 'елементів: ' + plan.items.length);
check('перший блок — повторення або нові слова',
  plan.blocks.length > 0 && ['REVIEW', 'NEW_WORDS'].includes(plan.blocks[0].kind),
  plan.blocks.length ? plan.blocks[0].kind : 'порожній план');
check('нових слів не більше 8',
  (plan.blocks.find((b) => b.kind === 'NEW_WORDS') || { items: [] }).items.length <= 8);

const word = wordsOfLevel(content, 'A0')[0];
const item = { kind: 'word', data: word, prompt: 'recall' };
check('перевірка слова: правильна відповідь', checkItem(item, word.spanish).correct);
check('перевірка слова: хибна відповідь', checkItem(item, 'zzz').correct === false);
check('оцінка за правильної відповіді — GOOD', gradeFor(item, word.spanish, false) === 'GOOD');
check('оцінка з підказкою — HARD', gradeFor(item, word.spanish, true) === 'HARD');
check('оцінка за помилки — AGAIN', gradeFor(item, 'zzz', false) === 'AGAIN');

store.recordAnswer(item, 'GOOD', 4000, false);
const card = store.card(word.id);
check('картка створена й оновлена', card && card.totalReviews === 1, card ? String(card.totalReviews) : 'немає');
check('статистика дня: одне повторення', store.todayStat().reviews === 1, String(store.todayStat().reviews));
check('серія днів = 1', store.streakDays === 1, String(store.streakDays));
check('знімок прогресу має точність 100%', Math.round(store.snapshot().accuracy) === 100);
check('журнал відповідей поповнився', store.data.reviewLog.length === 1);

store.recordAnswer(item, 'AGAIN', 2000, false);
check('помилка потрапила у слабкі місця після 3 спроб', (() => {
  store.recordAnswer(item, 'AGAIN', 2000, false);
  return store.weakSpots(10).some((spot) => spot.key === word.id);
})());

const exportText = store.exportJSON();
const storage2 = createMemoryStorage();
const store2 = createStore(storage2, content);
store2.importJSON(exportText, 'replace');
check('експорт/імпорт зберігає картки', Object.keys(store2.cards).length === Object.keys(store.cards).length);
check('ключ дня має формат yyyy-MM-dd', /^\d{4}-\d{2}-\d{2}$/.test(dayKey(new Date())));
check('оцінок усього 4', Object.keys(GRADE_INFO).length === 4);

console.log('\nПідсумок: ' + passed + ' пройшло, ' + failed + ' не пройшло');
process.exit(failed === 0 ? 0 : 1);
