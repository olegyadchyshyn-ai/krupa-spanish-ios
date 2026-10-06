# Контракт веб-версії (PWA) KRUPA Spanish

Веб-версія працює **без збірки й без бібліотек**: звичайні ES-модулі, які
відкриваються у Safari на iPhone і працюють офлайн після першого відкриття.

```
web/
├── index.html              # оболонка
├── manifest.webmanifest    # щоб додавалось на екран «Домівки»
├── sw.js                   # офлайн-кеш
├── css/app.css             # дизайн-система (класи вже готові)
├── content/*.json          # 17 файлів контенту (копія з iOS-версії)
├── icons/                  # іконки 180/192/512
├── js/
│   ├── app.js              # роутер + оболонка + стан
│   ├── content.js          # завантаження й вибірки контенту
│   ├── store.js            # SRS, перевірка відповідей, прогрес, план заняття
│   ├── tts.js              # синтез іспанського мовлення
│   ├── ui.js               # DOM-хелпери й компоненти
│   └── views/*.js          # екрани
└── test/logic.test.mjs     # тести логіки (node web/test/logic.test.mjs)
```

---

## 1. Що має експортувати кожен екран

```js
export function renderHome(app) { /* ... */ return element; }
```

- Функція **повертає `HTMLElement`** (не рядок, не масив).
- Параметри маршруту приходять другим аргументом: `renderWord(app, { id })`.
- **Нічого не робити з DOM на верхньому рівні модуля** — інакше файл не
  імпортується в Node під час перевірок. Уся робота — всередині функції.

Імена функцій за маршрутами (їх викликає `app.js`):

| Файл | Експорт | Хеш |
|---|---|---|
| `views/onboarding.js` | `renderOnboarding(app)` | `#/onboarding` |
| `views/home.js` | `renderHome(app)` | `#/` |
| `views/learn.js` | `renderLearn(app)` | `#/learn` |
| `views/topic.js` | `renderTopic(app, { id })` | `#/topic/<id>` |
| `views/session.js` | `renderSession(app, { topicId })` | `#/session` |
| `views/review.js` | `renderReview(app)` | `#/review` |
| `views/words.js` | `renderWords(app, { level })` | `#/words`, `#/words/A1` |
| `views/word.js` | `renderWord(app, { id })` | `#/word/<id>` |
| `views/grammar.js` | `renderGrammarList(app)`, `renderGrammarDetail(app, { id })` | `#/grammar`, `#/grammar/<id>` |
| `views/listening.js` | `renderListeningList(app)`, `renderListeningDetail(app, { id })` | `#/listening`, `#/listening/<id>` |
| `views/speaking.js` | `renderSpeaking(app)` | `#/speaking` |
| `views/ai.js` | `renderAi(app, { scenarioId })` | `#/ai`, `#/ai/<id>` |
| `views/progress.js` | `renderProgress(app)`, `renderProgressDetail(app)` | `#/progress`, `#/progress/details` |
| `views/settings.js` | `renderSettings(app)`, `renderBackup(app)`, `renderAbout(app)`, `renderDiagnostics(app)` | `#/settings`, `#/backup`, `#/about`, `#/diagnostics` |

---

## 2. Об'єкт `app`

```js
app.content    // контент курсу (див. розділ 3)
app.store      // прогрес і рушій (див. розділ 4)
app.tts        // синтез мовлення: speak(text), speakLines([...]), stop(), speaking, voiceCount
app.navigate('#/learn')     // перехід
app.refresh()               // перемалювати поточний екран
app.toast('Готово')         // коротке повідомлення
app.speak('hola', true)     // озвучити (true — навіть якщо автозвук вимкнено)
app.level                   // поточний рівень ('A0'|'A1'|'A2')
app.applyPreferences()      // застосувати тему/швидкість мовлення (викликати після зміни в налаштуваннях)
```

## 3. Контент (`app.content`)

Поля: `words`, `sentences`, `exercises`, `grammar`, `listening`, `topics`,
`wordById`/`sentenceById`/`exerciseById`/`grammarById`/`listeningById`/`topicById` (Map),
`issues` (зауваження), `contentVersion`.

Імпорт хелперів із `../content.js`:

```js
wordsOfLevel(content, level, topicId)      // за частотою
sentencesOfLevel(content, level, topicId)
exercisesOfLevel(content, level, topicId, kind)
topicsOfLevel(content, level)              // за orderIndex
listeningOfLevel(content, level, topicId)
grammarOfLevel(content, level)
wordsOfTopic(content, topicId)
wordsWithTag(content, tag)
grammarByTag(content, tag) / grammarByTags(content, tags)
normalizeLoose(text) / stripAccents(text)  // для пошуку
```

Структури даних (ключові поля):

- **Word**: `id, spanish, translationUk, partOfSpeech, gender ('m'|'f'|'mf'|'none'), plural, pronunciation, ipaHint, exampleEs, exampleUk, level, topicId, withArticle, grammarTags[], notesUk, cognateNoteUk, frequencyRank`
- **Sentence**: `id, spanish, translationUk, level, topicId, kind, grammarTags[], wordIds[], audioHint`
- **Exercise**: `id, kind, level, topicId, grammarTag, promptUk, promptEs, answerEs, answerUk, distractors[], tokens[], gapText, gapAnswer, relatedWordIds[], explanationUk, difficulty`
  Типи (`kind`): `multiple_choice`, `translation_uk_es`, `translation_es_uk`, `fill_gap`, `sentence_build`, `listening`, `speaking`, `dictation`, `match_pairs`.
  **Важливо:** у `translation_es_uk` відповідь у `answerUk`, а `answerEs` порожнє.
- **GrammarNote**: `id, tag, level, titleEs, titleUk, explanationUk, patternUk, examples[{spanish, translationUk, noteUk}], commonMistakeUk, tipForUkSpeakersUk, orderIndex`
- **ListeningItem**: `id, level, topicId, titleEs, titleUk, kind, orderIndex, lines[{speaker, spanish, translationUk}], keyWords[{spanish, translationUk}], comprehensionQuestions[{questionUk, options[], correctIndex, explanationUk}]`
- **Topic**: `id, level, titleEs, titleUk, descriptionUk, iconKey, orderIndex, grammarTags[]`

## 4. Прогрес і рушій (`app.store`)

```js
store.profile / store.settings          // читання
store.updateProfile({ level: 'A1' })    // часткове оновлення
store.updateSettings({ autoPlayAudio: false })

store.card(id)                          // картка SRS або null
store.cardOrCreate(item)                // картка для елемента заняття
store.upsertCard(card)                  // зберегти картку
store.setSuspended(id, true)            // призупинити/відновити
store.dueCards() / store.newCards()
store.dailyStat(date) / store.todayStat()
store.recordAnswer(item, grade, responseMs, usedHint)   // записати відповідь
store.weakSpots(limit) / store.weakGrammarTags()
store.snapshot()                        // зведення для екрана прогресу
store.topicsWithProgress(level)         // [{ topic, wordsCount, learned, fraction }]
store.streakDays / store.longestStreak
store.exportJSON() / store.importJSON(text, 'replace'|'merge') / store.reset()
store.data                              // { cards, dailyStats, mistakes, reviewLog, conversations }
```

Оцінки: `GRADES = ['AGAIN','HARD','GOOD','EASY']`, підписи в `GRADE_INFO`
(`{ title, short, symbol, correct, xp }`), фази в `PHASES`
(`NEW/LEARNING/REVIEW/RELEARNING` → «Нова», «Вивчається», «На повТоренні», «Переучується»).

```js
SrsEngine.previews(card)   // [{ grade, label, symbol, interval }] — для кнопок оцінок
SrsEngine.intervalLabel(card) / SrsEngine.isLearned(card)

makeItem('word'|'sentence'|'exercise'|'grammar'|'listening', data, prompt)
   // prompt: 'recognize' | 'recall' | 'listen' | 'buildSentence' (для слова/речення)
itemTitle(item) / itemSpanish(item) / itemUkrainian(item)
itemGrammarTags(item) / itemIsGraded(item) / itemContentId(item)
checkItem(item, answer) -> { correct, message, correctAnswer, explanation }
gradeFor(item, answer, usedHint) -> 'AGAIN'|'HARD'|'GOOD'
exerciseChoices(exercise, true)  // варіанти з перемішуванням
buildTokens(exercise)            // токени для складання речення

buildPlan(store, content, { level, topicId }) -> { blocks:[{kind, items[]}], items[] }
buildReviewPlan(store, content) -> той самий формат
BLOCKS[kind] -> { title, icon }   // NEW_WORDS, REVIEW, GRAMMAR, EXERCISES, LISTENING, SPEAKING
```

## 5. Компоненти з `../ui.js`

`h(tag, props, children)`, `card(children)`, `sectionHeader(title, subtitle, icon)`,
`button(title, { variant: 'primary'|'secondary'|'ghost'|'danger', icon, disabled, onClick })`,
`speakButton(onClick, label)`, `progressBar(fraction, { className })`, `levelBadge(level)`,
`chip(text, { active, onClick })`, `statTile(title, value, icon)`,
`emptyState(title, message, { icon, actionTitle, onAction })`,
`errorBanner(message, onRetry)`, `infoBox(title, text, { tone: 'success'|'warning'|'error' })`,
`optionRow(text, { state: 'selected'|'correct'|'wrong', disabled, onClick })`,
`field(placeholder, { multiline, rows, value, onSubmit, onInput })`,
`bubble(text, isUser, extras)`, `confirmDialog(message, onConfirm)`, `toast(message)`,
`ensureStyles(id, css)` — додати власні стилі один раз (з унікальним id),
`formatDateTime(value)`, `formatMinutes(minutes)`, `weekdayShort(date)`, `plural(n, one, few, many)`.

Готові CSS-класи (використовуйте їх, а не власні): `card`, `section-header`,
`section-title`, `section-subtitle`, `btn btn-primary|btn-secondary|btn-ghost|btn-danger`,
`btn-block`, `icon-btn`, `link-btn`, `progress`, `progress-fill`, `badge`, `badge-A0|A1|A2`,
`chip`, `chip-active`, `stat-tile`, `stat-value`, `stat-title`, `empty-state`, `error-banner`,
`info-box info-success|info-warning|info-error`, `option`, `option-correct`, `option-wrong`,
`option-selected`, `field`, `list`, `list-item`, `list-title`, `list-sub`, `list-icon`,
`word-es`, `word-uk`, `word-hero`, `word-example`, `kv-row`, `kv-label`, `chart`, `chart-col`,
`chart-bar`, `chart-label`, `ring`, `ring-inner`, `ring-score`, `mic-bar`, `mic-fill`,
`bubble`, `bubble-user`, `bubble-bot`, `corrections`, `correction`, `chat`, `composer`,
`session-top`, `session-prompt`, `session-title`, `session-spanish`, `grades`, `grade-btn`,
`grade-AGAIN|grade-HARD|grade-GOOD|grade-EASY`, `tokens`, `token`, `answer-line`, `pairs`,
`pair-col`, `pair-item`, `feedback`, `feedback-correct`, `feedback-wrong`, `overlay`,
`dialog`, `toast`, `gradient-header`, `quick-grid`, `quick-card`, `segmented`,
`segmented-item active`, `steps`, `step-dot`, `stack`, `row`, `row-between`, `grid-2`,
`grid-3`, `muted`, `center`, `spacer`, `loading`, `spinner`.

## 6. Правила коду

1. **Без бібліотек і без збірки** — тільки ES-модулі, `import`/`export`.
2. **Ніяких дій з DOM на верхньому рівні модуля** (перевірка імпорту в Node).
3. Текст інтерфейсу — українською; іспанський текст — шрифтом `word-es`/`word-hero`
   (класи вже задають serif).
4. Ніяких `innerHTML` із даними користувача — лише `text` або `h()`.
5. Кожен файл — до ~450 рядків; довгі частини виносьте в приватні функції
   `function renderXxx(...)` у тому ж файлі (без експорту).
6. Обробляйте три стани: порожній список, помилка, успіх. Порожній —
   через `emptyState(...)`.
7. Озвучення — через `app.speak(...)` або `app.tts.speakLines(...)`,
   кнопка — `speakButton(...)`.
8. Навігація — `app.navigate('#/...')`.
9. Заборонено: `document.write`, `alert`, `eval`, зовнішні CDN, `fetch` до сторонніх доменів.
10. Після зміни налаштувань викликайте `app.applyPreferences()`.
