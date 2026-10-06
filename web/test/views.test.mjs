// Перевірка, що всі модулі імпортуються й експортують потрібні функції.
//
// Ловить найпоширеніші помилки структури: забутий export, помилковий шлях
// імпорту, звернення до DOM на верхньому рівні модуля (такий файл не
// імпортується в Node — тест це показує).
//
// Запуск:  node web/test/views.test.mjs

const MODULES = [
  // Ядро
  ['content.js', ['loadContent', 'wordsOfLevel', 'normalizeLoose']],
  ['store.js', ['createStore', 'SrsEngine', 'AnswerCheck', 'buildPlan', 'buildReviewPlan', 'makeItem', 'checkItem']],
  ['tts.js', ['createTts']],
  ['ui.js', ['h', 'card', 'button', 'optionRow', 'progressBar', 'emptyState', 'bubble', 'ensureStyles']],
  // Екрани
  ['views/onboarding.js', ['renderOnboarding']],
  ['views/home.js', ['renderHome']],
  ['views/learn.js', ['renderLearn']],
  ['views/topic.js', ['renderTopic']],
  ['views/session.js', ['renderSession', 'createSessionView']],
  ['views/review.js', ['renderReview']],
  ['views/words.js', ['renderWords']],
  ['views/word.js', ['renderWord']],
  ['views/grammar.js', ['renderGrammarList', 'renderGrammarDetail']],
  ['views/listening.js', ['renderListeningList', 'renderListeningDetail']],
  ['views/speaking.js', ['renderSpeaking']],
  ['views/ai.js', ['renderAi']],
  ['views/progress.js', ['renderProgress', 'renderProgressDetail']],
  ['views/settings.js', ['renderSettings', 'renderBackup', 'renderAbout', 'renderDiagnostics']]
];

let failed = 0;

async function checkModule(path, expected) {
  const url = new URL('../js/' + path, import.meta.url);
  try {
    const module = await import(url.href);
    const missing = expected.filter((name) => {
      const value = module[name];
      return typeof value !== 'function' && typeof value !== 'object';
    });
    if (missing.length) {
      failed += 1;
      console.log('  ✗ ' + path + ' — немає експортів: ' + missing.join(', '));
    } else {
      console.log('  ✓ ' + path);
    }
  } catch (error) {
    failed += 1;
    console.log('  ✗ ' + path + ' — не імпортується: ' + error.message);
  }
}

console.log('Модулі веб-версії:');
for (const [path, expected] of MODULES) {
  await checkModule(path, expected);
}

console.log('\n' + (failed === 0
  ? 'Усі ' + MODULES.length + ' модулів на місці.'
  : 'Проблемних модулів: ' + failed));

process.exit(failed === 0 ? 0 : 1);
