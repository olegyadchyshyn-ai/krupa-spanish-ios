# 32. Session і Review — заняття та повторення (`SessionScreen.kt`, `SessionViewModel.kt`, `SessionUiState.kt`, `SessionPlan.kt`, `SessionStep.kt`, `ReviewScreen.kt`, `ReviewViewModel.kt`)

> **Джерела.** Рядкові константи класів — `_recon\strings_by_class.txt`; порядок і структура UI — baksmali-дизасембль (файли `classes*_ui.txt`, зокрема `classes13_ui.txt` для `Session*` і `classes8_ui.txt` для `Review*`), номери рядків узяті з compose-метаданих вигляду `(SessionScreen.kt:NNN)`.
> **Застереження щодо шляхів.** Під час роботи робочу теку реорганізували: каталог `_work\` (з дампами smali) зник, а теку зі спеками перенесено в `Spain\spec\` (поруч уже лежать `02_learning_engine.md`, `05_ios_port_contract.md`). Тому файл записано саме в `Spain\spec\32_session_review.md` — у ту саму теку, де лежать інші пронумеровані специфікації.
> Тексти наведено дослівно; у лапках — точні рядки з APK. Там, де висновок реконструйовано з байткоду, а не з рядкової константи, це позначено окремо.

---

## 1. Session — загальне

### 1.1 Призначення

`SessionScreen` — екран одного заняття (уроку). Він послідовно проводить користувача по списку кроків (`List<SessionStep>`): нові слова (інтро + флешкарта), вправи, граматичні нотатки, аудіювання й фінальний підсумок. Екран використовує `SessionViewModel`, який:

1) будує план заняття (`LessonBuilder` → `SessionPlan`), 2) перетворює його в кроки, 3) веде індекс поточного кроку й лічильники, 4) пише результати в SRS-рушій, трекер помилок і статистику активності, 5) формує крок-підсумок.

Вхід: `SessionScreen(container: AppContainer, topicId: String, minutes: Int, onExit: () -> Unit)` (сигнатура з байткоду: `(Lua/krupa/spanish/core/AppContainer;Ljava/lang/String;ILkotlin/jvm/functions/Function0;...)V`). `topicId` порожній (`""`) → денне заняття; непорожній → заняття по темі.

### 1.2 `buildDailySession` vs `buildTopicSession`

| Аспект | `buildDailySession(minutes)` | `buildTopicSession(topicId)` |
|---|---|---|
| Джерело плану | `lessonBuilder.buildPlan(minutes, …)` (активності/блоки вибирає `LessonBuilder`) | власна збірка з репозиторіїв: `courses.topic(topicId)`, `courses.wordsByTopic(topicId)`, `courses.sentencesByLevel(topic.level)`, `courses.exercisesByLevel(topic.level)`, `courses.grammarByTag(tag)` |
| Порядок кроків | як у `plan.blocks` (кожен блок має `kind` і `items`) | слова (`wordToSteps`) → граматика (`grammar_…`) → вправи (`ex_…`) → речення (`sent_…`) |
| Параметр | хвилини = `maxOf(profile.dailyMinutes, minutes)` | хвилини не використовуються |
| Фільтр | `StudyItem.isNew` з плану (`WordItem.word`, `isNew`) | `WordItem.isNew` не задається планом — для теми слова подаються як нові/наявні за карткою |
| Обґрунтування | `SessionPlan.reasonUk` (формує `LessonBuilder`) | `reasonUk` не використовується |

Спільне: обидві повертають `List<SessionStep>`, які далі кладуться в стан як `steps`, `currentIndex = 0`, `exercise = initialExerciseState(steps.firstOrNull())`.

### 1.3 `SessionPlan` та супутні типи

`SessionPlan` (файл `SessionPlan.kt`, `toString`: `SessionPlan(totalMinutes=…, blocks=…, reasonUk=…)`):

| Поле | Тип | Призначення |
|---|---|---|
| `totalMinutes` | `Int` | Загальна тривалість заняття в хвилинах (з `LessonBuilder`/профілю) |
| `blocks` | `List<SessionBlock>` | Блоки заняття в порядку проходження |
| `reasonUk` | `String` | Українське пояснення, чому план такий (використовує Home/Learning, у UI сесії не рендериться) |

`SessionBlock` (`toString`: `SessionBlock(kind=…, items=…, minutes=…, titleUk=…)`, порядок параметрів конструктора: `kind, minutes, titleUk, items`):

| Поле | Тип | Призначення |
|---|---|---|
| `kind` | `SessionBlockKind` | Тип блоку (визначає, як трактувати `items`) |
| `items` | `List<StudyItem>` | Елементи блоку |
| `minutes` | `Int` | Скільки хвилин відведено блоку |
| `titleUk` | `String` | Українська назва блоку (для плану/агенди) |

`SessionBlockKind` — enum з полями `code: String`, `titleUk: String` (порядок оголошення з `<clinit>`):

| Константа | `code` | `titleUk` |
|---|---|---|
| `REVIEW` | `review` | `"Повторення"` |
| `NEW_WORDS` | `new_words` | `"Нові слова"` |
| `GRAMMAR` | `grammar` | `"Граматика"` |
| `EXERCISES` | `exercises` | `"Вправи"` |
| `LISTENING` | `listening` | `"Аудіювання"` |
| `SPEAKING` | `speaking` | `"Говоріння"` |

Є `SessionBlockKind.Companion.fromCode(code)`.

`StudyItem` — sealed-клас елементів плану:

| Підтип | Поля | Тип |
|---|---|---|
| `WordItem` | `word`, `isNew` | `Word`, `Boolean` |
| `ExerciseItem` | `exercise` | `Exercise` |
| `GrammarItem` | `note` | `GrammarNote` |
| `ListeningItemRef` | `item` | `ListeningItem` |
| `SentenceItem` | `sentence` | `Sentence` |

### 1.4 `SessionUiState`

Оголошення (номери рядків `SessionUiState.kt` з `positions`):

| # рядка | Поле | Тип | Значення за замовчуванням |
|---|---|---|---|
| 8 | `loading` | `Boolean` | `true` |
| 9 | `steps` | `List<SessionStep>` | `emptyList()` |
| 10 | `currentIndex` | `Int` | `0` |
| 11 | `exercise` | `ExerciseUiState?` | `null` |
| 13 | `revealed` | `Boolean` | `false` |
| 14 | `finished` | `Boolean` | `false` |
| 15 | `message` | `String?` | `null` |
| 16 | `answeredCount` | `Int` | `0` |
| 17 | `correctCount` | `Int` | `0` |
| 18 | `newWordsCount` | `Int` | `0` |
| 19 | `mistakeTags` | `Set<String>` | `emptySet()` |

Обчислювані властивості того ж класу (реалізація з байткоду):

| Рядок | Властивість | Реалізація |
|---|---|---|
| 12 | `currentStep: SessionStep?` | `steps.getOrNull(currentIndex)` |
| 23 | `totalSteps: Int` | `steps.size` |
| 26 | `progressFraction: Float` | `if (steps.isEmpty()) 0f else (currentIndex.toFloat() / steps.size).coerceIn(0f, 1f)` |
| 28 | `isEmpty: Boolean` | `!loading && steps.isEmpty()` |

> Зверніть увагу: `progressFraction` базується на `currentIndex / steps.size` (тобто 0 на першому кроці), а не на `(currentIndex+1)/size`. Лічильник «Крок N з M» показує саме `currentIndex + 1`.
> Полів часу/таймера в `SessionUiState` немає: час заняття (`sessionStart`) і час кроку (`stepStart`) живуть у ViewModel як `Long` (`System.currentTimeMillis()`).

### 1.5 `SessionViewModel`

Конструктор: `SessionViewModel(container: AppContainer, topicId: String, minutes: Int)`; фабрика `SessionViewModelFactory(container, topicId, minutes)` (оголошена у файлі `ReviewViewModel.kt`, рядки 284–291). Поля: `_state: MutableStateFlow<SessionUiState>`, `state: StateFlow<SessionUiState>`, `stepStart: Long`, `sessionStart: Long`, `lastFeedbackCorrect: Boolean?`, `minutes: Int`, `topicId: String`.

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `load` | — (suspend) | `users.profile()`; `_state.value = state.copy(loading = true)`; далі `if (topicId.isNotBlank()) buildTopicSession(topicId) else buildDailySession(maxOf(profile.dailyMinutes, minutes))`; `sessionStart = stepStart = now` | Новий стан: `loading=false`, `steps=…`, `currentIndex=0`, `exercise = initialExerciseState(steps.firstOrNull())` |
| `buildDailySession` | `minutes: Int` | `users.profile()` → `lessonBuilder.buildPlan(minutes, …)` → `planToSteps(plan)` | Повертає `List<SessionStep>` (стан не змінює) |
| `buildTopicSession` | `topicId: String` | Збирає кроки теми: слова (`wordToSteps`), граматика (`GrammarStep` з id `grammar_<id>`), вправи (`ExerciseStep` з id `ex_<id>`), речення (`sentenceToExercise` → `ExerciseStep` з id `sent_<id>`) | Повертає `List<SessionStep>` |
| `planToSteps` | `plan: SessionPlan` | Ітерує `plan.blocks` → `block.items`; `WordItem` → `wordToSteps(word, block.kind, isNew)`; `ExerciseItem` → `ExerciseStep("ex_"+id, kind, exercise)`; `GrammarItem` → `GrammarStep("grammar_"+id, kind, note)`; `ListeningItemRef` → `ListeningStep("listen_"+id, kind, item)`; `SentenceItem` → `ExerciseStep("sent_"+id, kind, sentenceToExercise(sentence))` | Повертає `List<SessionStep>` |
| `wordToSteps` | `word: Word, blockKind: SessionBlockKind, isNew: Boolean` | `card = srsEngine.cardFor(word.id, "word")`; `showIntro = isNew && (card == null \|\| card.totalReviews == 0)`; якщо `showIntro` — додає `WordIntro("intro_"+word.id, blockKind, word)`; далі завжди `Flashcard("card_"+word.id, …)`: `card = card ?: newCardState(word)`, `frontEs = word.display`, `frontUk = word.translationUk`, `backEs = word.display`, `backUk = word.translationUk`, `exampleEs`, `exampleUk`, `genderNoteUk = genderNote(word)`, `cognateNoteUk = word.cognateNoteUk`, `pronunciation = word.pronunciation`, `askSpanish = showIntro` | Повертає `List<SessionStep>` (1 або 2 кроки) |
| `newCardState` | `word: Word` | `srsEngine.ensureCard(itemType="word", itemId=word.id, level=word.level.code, topicId, grammarTags)` | Повертає `CardState` |
| `genderNote` | `word: Word` | Якщо `word.partOfSpeech == NOUN`: `"Чоловічий рід: el "` / `"Жіночий рід: la "` / `"Спільний рід: el/la "` + `word.spanish` + `pluralSuffix(word)`; інакше — порожній рядок | — |
| `pluralSuffix` | `word: Word` | `if (word.plural.isNotBlank()) ", множина: " + word.plural else ""` | — |
| `sentenceToExercise` | `sentence: Sentence` | Будує `Exercise` типу перекладу: `id = "sent_"+sentence.id`, рівень/тема/теги з речення, `answerEs = sentence.spanish`, `answerUk = sentence.translationUk`, `promptUk = "Перекладіть українською"` | Повертає `Exercise` |
| `initialExerciseState` | `step: SessionStep` | `if (step is ExerciseStep) exerciseState(step.exercise) else null` | — |
| `exerciseState` | `exercise: Exercise` | Формує `ExerciseUiState`: `optionOrder` / `tokenOrder` (перемішані `tokens + distractors` для відповідних типів), `textAnswer = ""`, `checked = false`, `correct = false` | — |
| `optionsFor` | `exercise: Exercise` | Варіанти відповіді: `tokens`/`distractors`/`gapAnswer`/`answerEs` залежно від `kind` | — |
| `recordCard` | `step: Flashcard, grade: Grade, responseMs: Long` (suspend) | `srsEngine.ensureCard(...)` → `srsEngine.review(..., grade, responseMs)`; `users.addActivity(...)`; при помилці — `mistakeTracker.record(level, frontEs, backEs, genderNoteUk, …)` | Пише SRS/статистику, стан не змінює |
| `recordExercise` | `exercise: Exercise, correct: Boolean, responseMs: Long` | `srsEngine.ensureCard("exercise", …)` → `srsEngine.review(exercise.grammarTag.code, kind.code, correct, responseMs)`; `users.addActivity(...)`; при помилці — `mistakeTracker.record(...)` | Пише SRS/статистику |
| `recordListening` | `step: ListeningStep` | `users.addActivity(...)` (фіксує прослуховування) | Пише статистику |
| `advance` | `step: SessionStep, grade: Grade?` (suspend) | Обчислює `correct`: для `Flashcard` — `grade != Grade.AGAIN`; для `ExerciseStep` — `lastFeedbackCorrect == true`; інакше `null`. Скидає `lastFeedbackCorrect = null`, `stepStart = now`. Оновлює лічильники й переходить далі | `answeredCount += (correct != null ? 1 : 0)`; `correctCount += (correct == true ? 1 : 0)`; `newWordsCount += (step is Flashcard && step.card.isNew ? 1 : 0)`; `mistakeTags += exercise.grammarTag.titleUk`, якщо `correct == false` і крок — вправа. Якщо `currentIndex + 1 >= steps.size` → `finishSession(newState)`, інакше `state = newState.copy(currentIndex + 1, exercise = initialExerciseState(steps[next]), revealed = false)` |
| `rateStep` | `grade: Grade` | `step = state.currentStep ?: return`; `responseMs = now - stepStart`; запускає `recordCard/recordExercise` і `advance(step, grade)` | Через `advance` |
| `checkAnswer` | — | Перевіряє відповідь поточного `ExerciseStep` залежно від `kind` (порівняння тексту/токенів/опції через `AnswerCheck.compare`), пише `ExerciseUiState(correct, checked=true, …)` і запам'ятовує `lastFeedbackCorrect` | Оновлює `exercise.correct/checked`; `state.copy(exercise = …)` |
| `finishSession` | `state: SessionUiState` | `minutes = max(1, (now - sessionStart)/60000)`; створює `Summary(id="summary", answered, correct, minutes, newWords, weakTags = mistakeTags.toList())`; додає крок у `steps` і ставить `currentIndex = steps.size`, `exercise = null`, `finished = true`; далі `commitSessionTime(minutes)` | Новий стан з кроком-підсумком |
| `commitSessionTime` | — | Якщо `state.finished` → вихід. Інакше `elapsed = max(1, (now - sessionStart)/60000)` і фіксує час у статистиці (окрема корутина) | Пише статистику; стан не змінює |
| `gradeHints` | — | `if (currentStep is Flashcard) srsScheduler.preview(step.card, now) else emptyList()` | — |
| `setRevealed` | — | Показує відповідь флешкарти | `state.copy(revealed = true)` |
| `selectOption` | `index: Int` | Вибір варіанта у вправі | `exercise.copy(selectedOption = index)` → `state.copy(exercise = …)` |
| `toggleToken` | `index: Int` | Додає/прибирає токен зі `selectedTokens` | `state.copy(exercise = …)` |
| `updateTextAnswer` | `text: String` | Ввід текстової відповіді | `state.copy(exercise = …)` |
| `updateSpeechInput` | `text: String` | Запис розпізнаного мовлення | `state.copy(exercise = …)` |
| `setListening` | `listening: Boolean` | Прапорець активного слухання/запису | `state.copy(exercise = …)` |
| `getState` | — | Повертає `StateFlow<SessionUiState>` | — |

---

## 2. `SessionStep` — типи кроків

`SessionStep` — sealed-клас (`SessionStep.kt`). Реалізації та їхні поля (порядок параметрів конструктора — з байткоду):

| Тип кроку | Поля (порядок конструктора) | Примітки |
|---|---|---|
| `WordIntro` | `id: String`, `blockKind: SessionBlockKind`, `word: Word` | id: `"intro_<wordId>"` |
| `Flashcard` | `id: String`, `blockKind`, `card: CardState`, `frontEs: String`, `frontUk: String`, `backEs: String`, `backUk: String`, `exampleEs: String`, `exampleUk: String`, `genderNoteUk: String`, `cognateNoteUk: String`, `pronunciation: String`, `askSpanish: Boolean` | id: `"card_<wordId>"` |
| `ExerciseStep` | `id: String`, `blockKind`, `exercise: Exercise` | id: `"ex_<id>"` або `"sent_<id>"` |
| `GrammarStep` | `id: String`, `blockKind`, `note: GrammarNote` | id: `"grammar_<id>"` |
| `ListeningStep` | `id: String`, `blockKind`, `item: ListeningItem` | id: `"listen_<id>"` |
| `Summary` | `id: String`, `answered: Int`, `correct: Int`, `minutes: Int`, `newWords: Int`, `weakTags: List<String>` | id: `"summary"` |

Допоміжні типи з того ж файлу: `AnswerCheck(correct: Boolean, expected: String, explanationUk: String, grade: …, issues: …)` + `AnswerCheck.Companion.compare(...)` (нормалізація відповіді: `toLowerCase`, розбиття за `\s+`, ігнорування пунктуації `[¡¿!?.,;:\"«»()\[\]…—–]`).

Відповідність «тип кроку → блок» (з `SessionContent`):

| Тип кроку | Composable-блок | Що показує | Дії |
|---|---|---|---|
| `WordIntro` | `WordIntroBlock` (SessionScreen.kt:297) | Картка нового слова + приклад + нотатки | `PrimaryActionButton("Зрозуміло, далі")` → `rateStep(Grade.GOOD)` |
| `Flashcard` | `FlashcardBlock` (370) + `FlashcardButtons` (451) | Обличчя картки, приклад, нотатки, кнопка прослуховування | `"Показати відповідь"` → `setRevealed()`; далі 4 кнопки оцінки → `rateStep(grade)` |
| `ExerciseStep` | `ExerciseBlock` (504) + `FeedbackBlock` (777) | Вправа (спільний `ExerciseContent`) | `"Перевірити"` → `checkAnswer()`; після перевірки `FeedbackBlock` з `"Далі"` → `rateStep(Grade.GOOD)` |
| `GrammarStep` | `GrammarBlock` (564) | Заголовок, закономірність, приклади, типова помилка, підказка | Внизу `PrimaryActionButton("Далі")` → `rateStep(Grade.GOOD)` |
| `ListeningStep` | `ListeningBlock` (635) | Заголовок, репліки, ключові слова, питання | Кнопки всередині блоку (прослухати/завершити) |
| `Summary` | `SummaryBlock` (736) | Підсумок заняття | `PrimaryActionButton("На головну")` → `onFinish()` |

---

## 3. Блоки заняття — детально

Порядок елементів нижче — за номерами рядків `SessionScreen.kt` (зростання), тексти — дослівно.

### 3.1 `LoadingBlock` (SessionScreen.kt:162–167)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 163 | `Column(horizontalAlignment = CenterHorizontally, verticalArrangement = Top)` | — |
| 164–165 | `CircularProgressIndicator()` | — |
| 166 | `Spacer(height = …)` | — |
| 167 | `Text(…, style = MaterialTheme.typography…)` | `"Складаємо заняття…"` |

Показується, коли `state.loading == true` (рядок 141 у `SessionScreen`). Жодних кнопок.

### 3.2 `WordIntroBlock` (SessionScreen.kt:297–357)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 299 | `Column(verticalArrangement = spacedBy(…), horizontalAlignment = Start)` | — |
| 300–301 | `Text(…)` | `"Нове слово"` (власний стиль/колір з `MaterialTheme`) |
| 303–321 | `Card` (картка слова) | — |
| 305 | ↳ `Text(word.display, style = TypeKt.spanishWordStyle)` | `word.display` |
| 313–314 | ↳ за умови `word.pronunciation.isNotBlank()`: `Spacer` + `Text("[" + word.pronunciation + "]")` | `[вимова]` |
| 316–317 | ↳ `Spacer` + `Text(word.translationUk)` | переклад |
| 325–326 | `OutlinedButton` (лейбл — синглтон, рядок 326) | `"Прослухати"` (відтворює іспанське слово) |
| 332 | `InfoBanner(text = "Вимова: " + word.ipaHint)` | `"Вимова: …"` |
| 335–344 | `Card` (приклад) | — |
| 336–337 | ↳ `Text("Приклад")` | `"Приклад"` |
| 338–339 | ↳ `Spacer` + `Text(word.exampleEs)` | іспанський приклад |
| 341–344 | ↳ `Text(word.exampleUk, …)` за умови, що він не порожній | український переклад прикладу |
| 351 | `InfoBanner(text = word.notesUk)` (якщо не порожній) | нотатка до слова |
| 354–357 | `InfoBanner(text = word.cognateNoteUk, colors = secondaryContainer/onSecondaryContainer)` (якщо не порожній) | «фальшивий друг»/споріднене слово |
| 249 | `PrimaryActionButton("Зрозуміло, далі")` (у `SessionContent`) | перехід далі |

Перехід далі: `PrimaryActionButton("Зрозуміло, далі")` → `SessionViewModel.rateStep(Grade.GOOD)` (лямбда `SessionContent$1$12`).

### 3.3 `FlashcardBlock` (SessionScreen.kt:370–453)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 371 | `Column(verticalArrangement = spacedBy(…), horizontalAlignment = Start)` | — |
| 372–378 | `Text(if (step.askSpanish) "Згадайте, як це іспанською" else "Що це означає?", style = TypeKt.promptStyle)` | **`"Згадайте, як це іспанською"`** / **`"Що це означає?"`** |
| 376–408 | `Card(colors = surfaceVariant)` — обличчя картки | див. нижче |
| 412–419 | `Card` — приклад (лише після показу відповіді, і лише якщо `exampleEs` не порожній) | `Text(exampleEs)`, `Text(exampleUk)` |
| 426–429 | `InfoBanner(step.genderNoteUk)` (якщо не порожній, після показу відповіді) | напр. `"Чоловічий рід: el libro, множина: los libros"` |
| 429–432 | `InfoBanner(step.cognateNoteUk, colors = secondaryContainer/onSecondaryContainer)` (якщо не порожній, після показу відповіді) | — |
| 435–453 | `OutlinedButton` (лейбл — синглтон, рядок 436) | **`"Прослухати вимову"`** (озвучує іспанський бік картки; у Review аналогічна кнопка читає саме `backEs`) |

Обличчя картки (`FlashcardBlock$1$1`, рядки 380–408; у дужках — умова з байткоду):

| Рядок | Елемент | Текст/стиль |
|---|---|---|
| 387 | якщо `askSpanish`: `Text(step.frontUk, typography.headlineMedium, textAlign = Center)` | українське слово/переклад |
| 389–390 | і якщо `revealed`: `Spacer(14.dp)` + `Text(step.backEs, spanishWordStyle, Center)` | іспанська відповідь |
| 392–393 | і якщо `pronunciation.isNotBlank()`: `Spacer(4.dp)` + `Text("[" + pronunciation + "]", bodyLarge, onSurfaceVariant)` | `[вимова]` |
| 401 | інакше (не `askSpanish`): `Text(step.frontEs, spanishWordStyle, Center)` | іспанське слово |
| 402–404 | і якщо `revealed`: `Spacer(12.dp)` + `Text(step.backUk, headlineSmall)` | український переклад |

Тобто **приклад, нотатки й кнопка `"Прослухати вимову"` з'являються тільки після `revealed = true`**.

### 3.4 `FlashcardButtons` (SessionScreen.kt:451–481)

| Рядок | Умова | Елемент | Текст |
|---|---|---|---|
| 453–458 | `!revealed` | `PrimaryActionButton` | **`"Показати відповідь"`** → `setRevealed()` |
| 460–461 | `revealed` | `Text(…, labelLarge, onSurfaceVariant)` | **`"Наскільки добре ви згадали?"`** |
| 465–481 | `revealed` | `OutlinedButton` × 4 (по одному на кожну `Grade.entries`), `RoundedCornerShape(14.dp)`, `contentPadding` по вертикалі 14.dp; всередині `Row(SpaceBetween, CenterVertically)`: `Text(symbol + "  " + titleUk, bodyLarge)` і під ним `Text(GradePreview.intervalLabel, labelMedium, onSurfaceVariant)` | див. таблицю оцінок нижче |

Кнопки оцінки SRS (порядок `Grade.entries` і точні підписи з `<clinit>` enum `Grade`):

| Порядок | Константа | `symbol` | `titleUk` | Підпис кнопки (symbol + 2 пробіли + title) | Підказка інтервалу |
|---|---|---|---|---|---|
| 0 | `AGAIN` | `"✕"` | `"Не знаю"` | **`"✕  Не знаю"`** | `GradePreview.intervalLabel` |
| 1 | `HARD` | `"~"` | `"Пам'ятаю з труднощами"` | **`"~  Пам'ятаю з труднощами"`** | `GradePreview.intervalLabel` |
| 2 | `GOOD` | `"✓"` | `"Знаю"` | **`"✓  Знаю"`** | `GradePreview.intervalLabel` |
| 3 | `EASY` | `"★"` | `"Дуже добре"` | **`"★  Дуже добре"`** | `GradePreview.intervalLabel` |

`GradePreview(grade: Grade, intervalLabel: String)`; `intervalLabel` дає `SrsScheduler.preview(card, now)`; словник підписів у `SrsScheduler.humanInterval`: `"сьогодні"` (≤0 днів), `"менш ніж за день"` (0…1 дня), далі `"через N дн"`, `"через N міс"`, `"через N р"` (порогові значення 1 / 30 / 365 днів).

Натискання кнопки оцінки → `SessionViewModel.rateStep(grade)` (лямбда `SessionContent$1$14`).

### 3.5 `ExerciseBlock` (SessionScreen.kt:504–560)

| Рядок | Елемент | Примітки |
|---|---|---|
| 507–510 | `ExerciseContent(exercise, optionOrder, tokenOrder, selectedTokens, textAnswer, isListening, …, onSelectOption, onToggleToken, onTextAnswer, onSpeak…)` | Спільний компонент екрана вправ (`ui/screens/exercise/ExerciseContentKt.ExerciseContent`) — уся візуальна частина вправи там |
| 548–551 | `if (розпізнаний текст не порожній && exercise.kind != SPEAKING)` → `Text("Почуто: " + text, bodyMedium, onSurfaceVariant)` | **`"Почуто: "`** |
| до 551 | `InfoBanner(…, colors = errorContainer/onErrorContainer)` | Банер помилки розпізнавання мовлення (`SpanishSpeechRecognizer.Event.Failed.reasonUk`) |

Особливості: `ExerciseBlock` читає `ExerciseUiState.optionOrder/tokenOrder/selectedTokens/textAnswer/isListening` і підписує зворотні виклики на `selectOption`, `toggleToken`, `updateTextAnswer`, `updateSpeechInput`, `setListening`. Розпізнавання мовлення виконує `ExerciseBlock$6` (`SpanishSpeechRecognizer.listen(...)`), а результат пишеться у ViewModel (`Event.Final.text` → `updateSpeechInput`, `Event.Failed.reasonUk` → банер помилки).

### 3.6 `FeedbackBlock` (SessionScreen.kt:777–821)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 777 | `FeedbackBlock(correct: Boolean, expected: String, given: String, explanationUk: String, onNext: () -> Unit)` | — |
| 778–802 | `Column(verticalArrangement = spacedBy(…), horizontalAlignment = Start)` | — |
| 780–812 | `Card(colors = if (correct) secondaryContainer else errorContainer)` | — |
| 789–798 | ↳ `Row(CenterVertically, spacedBy(…))`: `Icon(if (correct) Check else Close)` + `Spacer` + `Text(if (correct) "Правильно" else "Не зовсім")` | **`"Правильно"`** / **`"Не зовсім"`** |
| 802–805 | ↳ `Text("Правильно: " + expected, …)` | **`"Правильно: "`** |
| 808–811 | ↳ `Text("Ви відповіли: " + given, bodyMedium, onSurfaceVariant)` (якщо `given` не порожній) | **`"Ви відповіли: "`** |
| 816 | ↳ `Text(explanationUk)` (якщо не порожній) | пояснення з вправи |
| 820–821 | `Spacer` + `PrimaryActionButton("Далі")` | **`"Далі"`** → `rateStep(Grade.GOOD)` (лямбда `SessionContent$1$15`) |

Показується замість `"Перевірити"`, коли `ExerciseUiState.checked == true` (рядок 264 у `SessionContent`); `expected` обчислює `SessionScreenKt.expectedAnswerFor(step)`.

### 3.7 `GrammarBlock` (SessionScreen.kt:564–624)

| Рядок | Елемент | Текст |
|---|---|---|
| 566–569 | `Column(...)` + заголовок блоку: `Text(note.titleEs, …)` і `Text(note.titleUk, …)` | — |
| 570–571 | `Card` №1 (`GrammarBlock$1$1`) | — |
| 583–612 | `Card` №2 (`GrammarBlock$1$2$1`) | — |
| 583–590 | ↳ `Row`: `Text(note.titleEs, weight(1f))` + `OutlinedButton` (`Icon` + `Text`) | **`"Прослухати"`** |
| 598–601 | ↳ `Text("Закономірність: " + note.patternUk)` | **`"Закономірність: "`** |
| 604–611 | ↳ для кожного `GrammarExample`: `Text(example.spanish)` + `TextButton("Прослухати")` + `Text(example.translationUk)` + `Text(example.noteUk)` | **`"Прослухати"`** |
| 617–620 | ↳ `Text("Типова помилка: " + note.commonMistakeUk)` (якщо не порожній) | **`"Типова помилка: "`** |
| 624 | ↳ `Text("Підказка: " + note.tipForUkSpeakersUk)` (якщо не порожній) | **`"Підказка: "`** |
| 280 | `PrimaryActionButton("Далі")` (у `SessionContent`) | **`"Далі"`** → `rateStep(Grade.GOOD)` (лямбда `SessionContent$1$17`) |

### 3.8 `ListeningBlock` (SessionScreen.kt:635–731)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 637 | `Column(...)` | — |
| 638–639 | `Text(item.titleEs, …)`, `Text(item.titleUk, …)` | — |
| 641–649 | `PrimaryActionButton(label, icon = Icons.Filled.VolumeUp)` | **`"Прослухати повністю"`** (запуск озвучення діалогу) |
| 642–646 | `Card` на кожну репліку (`ListeningBlock$1$1$1`, рядок 653) | — |
| 659 | ↳ `Text("$speaker: $spanish")` | роздільник **`": "`** |
| 661–662 | ↳ `Text(line.translationUk)` (коли увімкнено переклад) | — |
| 665 | ↳ `TextButton` | **`"Повторити репліку"`** |
| 670–677 | `TextButton` перемикач перекладу (`ListeningBlock$1$3`, рядок 671) | **`"Показати переклад"`** / **`"Сховати переклад"`** |
| 675–683 | `Card` ключових слів (`ListeningBlock$1$4`, рядок 679) | — |
| 679–680 | ↳ `Text("Ключові слова")` | **`"Ключові слова"`** |
| 681–683 | ↳ для кожного `WordGloss`: `Text("$spanish — $translationUk")` | роздільник **`" — "`** |
| 693–722 | `Card` на кожне питання (`ListeningBlock$1$5$1`, рядок 694) | — |
| 695–696 | ↳ `Text(question.questionUk)` | — |
| 700–717 | ↳ `OutlinedButton` на кожен варіант відповіді (`question.options`), `correctIndex` визначає правильний | — |
| 716–722 | ↳ після відповіді: `Text(…)` з кольором `secondaryContainer`/`onSecondaryContainer` (правильно) або `errorContainer`/`onErrorContainer` (неправильно) | **`"✓ Правильно. " + question.explanationUk`** або **`"✕ Правильна відповідь: " + question.options[question.correctIndex] + ". " + question.explanationUk`** |
| 731 | `PrimaryActionButton` (без іконки) | **`"Завершити слухання"`** |

### 3.9 `SummaryBlock` (SessionScreen.kt:736–766)

| Рядок | Елемент | Текст |
|---|---|---|
| 737 | `SummaryBlock(step: SessionStep.Summary, onFinish: () -> Unit)` | — |
| 738–741 | `Column(verticalArrangement = spacedBy(…), horizontalAlignment = Start)` + `Text(…, headline…)` | **`"Заняття завершено"`** |
| 743–751 | `Card` зі статистикою (`SummaryBlock$1$1`) | — |
| 744–745 | ↳ `Text("Відповідей: " + step.answered)` | **`"Відповідей: "`** |
| 748 | ↳ `Text("Правильно: " + step.correct)`, а також відсоток `correct/answered` у дужках зі знаком `%` (у байткоді є рядки `" ("` та `"%)"`) | **`"Правильно: "`** |
| 750 | ↳ `Text("Нових слів: " + step.newWords)` | **`"Нових слів: "`** |
| 751 | ↳ `Text("Хвилин: " + step.minutes)` | **`"Хвилин: "`** |
| 755 | `InfoBanner("Помилки були в темах: " + weakTags.joinToString() + ". Застосунок додасть більше вправ на них.")` (якщо `weakTags` не порожній) | **`"Помилки були в темах: "`**, **`". Застосунок додасть більше вправ на них."`** |
| 760–764 | `InfoBanner("Наступні повторення вже заплановано. Найкращий результат — заходити щодня хоча б на кілька хвилин.")` | дослівно |
| 766 | `PrimaryActionButton("На головну")` | **`"На головну"`** → `onFinish()` |

---

## 4. `SessionScreen` — верхній рівень (SessionScreen.kt:70–160)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 71–84 | Каркас екрана (колонка) з відступами | — |
| 109–110 | `Column(verticalArrangement = Top, horizontalAlignment = Start)` | — |
| 115–119 | `Row(SpaceBetween, CenterVertically)`: `Text("Заняття", headline…)` + `TextButton` (синглтон, рядок 120) | Заголовок **`"Заняття"`**; кнопка виходу — **`"Вийти"`** |
| 131–132 | `LinearProgressIndicator(progress = state.progressFraction, strokeCap = Round)` | `progressFraction = currentIndex / steps.size` |
| 134–135 | `Text("Крок " + (currentIndex + 1) + " з " + totalSteps, labelLarge?, onSurfaceVariant)` | **`"Крок "`** + **`" з "`** (тобто «Крок 3 з 12») |
| 141 | `if (state.loading) LoadingBlock()` | — |
| 142–148 | `else if (state.isEmpty) EmptyState(title, message)` | **`"Немає що повторювати"`**, **`"На сьогодні занять немає. Додайте нові теми в розділі «Навчання» або змініть рівень у налаштуваннях."`** |
| 148 | інакше → `SessionContent(container, state, viewModel, speechListening, onExit, onFinish, scope)` | — |
| 89–107 | `LaunchedEffect(step)`: автопрогравання TTS | `WordIntro` → `word.spanish`; `Flashcard` → `frontEs`, але **лише коли `askSpanish == false`**; `ExerciseStep` → `exercise.answerEs` **лише для `ExerciseKind.LISTENING` і `ExerciseKind.DICTATION`**; інакше — нічого. Перед озвученням викликається `SpanishTtsEngine.initialize()` |
| 64 / `SessionScreen$1` | `DisposableEffect(Unit) { onDispose { viewModel.commitSessionTime() } }` | Фіксація часу заняття при виході з екрана (якщо сесію не завершено) |
| `RecordAudio` | Дозвіл на мікрофон | `android.permission.RECORD_AUDIO` запитується через `rememberLauncherForActivityResult` («permissionLauncher»); стан `speechListening` (MutableState) передається в `SessionContent` |

**Кнопка виходу та її підтвердження.** У `SessionScreen` кнопка `"Вийти"` викликає переданий ззовні `onExit` напряму. **Діалогу підтвердження в цьому файлі немає** (`AlertDialog`/`Dialog` у `SessionScreenKt` не викликаються, рядка підтвердження серед констант класу теж немає). Якщо підтвердження існує, воно реалізоване у навігаційному хості (`AppNav`), який у надані джерела не входив.

---

## 5. Review — окремий екран

### 5.1 Призначення та черга карток

`ReviewScreen` — сесія повторення SRS. Чергу формує `ReviewViewModel.load()`:

1. `srsEngine.dueCards(60, now)` — до 60 карток, термін яких настав;
2. `srsEngine.weakest(15)` — 15 найслабших карток;
3. `lessonBuilder.buildReviewItems(due, weakest)` → `List<StudyItem>`;
4. кожен елемент перетворюється у крок:
   - `WordItem` → `srsEngine.cardFor(word.id, "word")` → `SessionStep.Flashcard(id = "card_" + word.id, …)`;
   - `ExerciseItem` → `SessionStep.ExerciseStep(id = "ex_" + id)`;
   - `SentenceItem` → `Exercise(id = "sent_" + id, promptUk = "Перекладіть українською")` → `SessionStep.ExerciseStep`;
5. стан: `SessionUiState(steps = …, currentIndex = 0, exercise = exerciseState(перший ExerciseStep))`.

Поля картки-флешкарти в Review (з байткоду): `frontEs = word.display`, `frontUk = word.translationUk`, `backEs = word.display`, `backUk = word.translationUk`, `exampleEs`, `exampleUk`, `genderNoteUk` (для іменників: `"Чоловічий рід: el "` / `"Жіночий рід: la "` + `word.spanish`; інакше порожній рядок), `cognateNoteUk`, `pronunciation`, **`askSpanish = true`** (тобто підказка завжди `"Згадайте іспанською"`, а обличчя картки — українське слово).
На відміну від заняття, у Review **немає кроку `WordIntro`** і немає кроків `GrammarStep`/`ListeningStep` (рядки `"grammar_"`, `"listen_"` у цьому ViewModel відсутні).

### 5.2 `ReviewViewModel`

Файл `ReviewViewModel.kt` також містить `ReviewViewModelFactory(container)` (рядки 279–281) і `SessionViewModelFactory(container, topicId, minutes)` (рядки 284–291).

Поля та значення за замовчуванням:

| Поле | Тип | Початкове значення |
|---|---|---|
| `_state` | `MutableStateFlow<SessionUiState>` | `SessionUiState()` — тобто `loading = true`, `steps = emptyList()`, `currentIndex = 0`, `exercise = null`, `revealed = false`, `finished = false`, `message = null`, `answeredCount = 0`, `correctCount = 0`, `newWordsCount = 0`, `mistakeTags = emptySet()` |
| `state` | `StateFlow<SessionUiState>` | `_state.asStateFlow()` |
| `stepStart` | `Long` | `System.currentTimeMillis()` (у конструкторі) |
| `sessionStart` | `Long` | `System.currentTimeMillis()` (у конструкторі) |
| `lastCorrect` | `Boolean?` | `null` |
| `container` | `AppContainer` | — |

У конструкторі одразу запускається `load()`.

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `load` | — (suspend) | `dueCards(60, now)` → `weakest(15)` → `buildReviewItems(...)` → побудова кроків; напр. `SessionUiState(steps = …, currentIndex = 0, exercise = exerciseState(first))` | Замінює стан повністю (у т.ч. `loading = false`) |
| `advance` | `state: SessionUiState, step: SessionStep, lastCorrect: Boolean?` | `lastCorrect = null`; `stepStart = now`; `next = state.currentIndex + 1`; якщо `next >= steps.size` → будує `Summary(id = "summary", answered, correct, minutes = max(1, (now - sessionStart)/60000), newWords = 0, weakTags = emptyList())`, додає його в `steps`, `currentIndex = steps.size` (тобто на підсумок), `exercise = null`, `finished = true`; інакше — `currentIndex = next`, `exercise = exerciseState(next)` для вправ | `answeredCount += (lastCorrect != null ? 1 : 0)`, `correctCount += (lastCorrect == true ? 1 : 0)` |
| `rate` | `grade: Grade` | `step = state.currentStep ?: return`; `responseMs = now - stepStart`; `correct = if (step is Flashcard) grade != Grade.AGAIN else if (step is ExerciseStep) lastCorrect == true else null`; у корутині фіксує SRS-відповідь (`rate$1`), потім викликає `advance(state, step, correct)` | Через `advance` |
| `reveal` | — | Показ відповіді | `state.copy(revealed = true)` |
| `check` | — | Перевірка текстової відповіді вправи (`AnswerCheck.compare`), пише `correct`/`checked` і `lastCorrect` | `state.copy(exercise = …)` |
| `selectOption` | `index: Int` | Вибір варіанта | `state.copy(exercise = …)` |
| `toggleToken` | `index: Int` | Додати/прибрати токен | `state.copy(exercise = …)` |
| `updateText` | `text: String` | Ввід відповіді | `state.copy(exercise = …)` |
| `exerciseState` | `step: ExerciseStep` | Формує `ExerciseUiState` (порядок опцій/токенів) | — |
| `gradeHints` | — | `if (currentStep is Flashcard) SrsScheduler.preview(card, now) else emptyList()` | — |
| `getState` | — | `StateFlow` | — |

### 5.3 `ReviewScreen` (ReviewScreen.kt:56–122)

| Рядок | Елемент | Текст/параметри |
|---|---|---|
| 57–62 | Каркас екрана (з `viewModel = viewModel(factory = ReviewViewModelFactory(container))`) | — |
| 71 | `if (state.loading)` → `CircularProgressIndicator()` | — |
| 75–93 | `else if (state.isEmpty)` → `Column`: `EmptyState(title, message)`, `Spacer`, `PrimaryActionButton` | **`"Усе повторено"`**, **`"На зараз прострочених карток немає. Найкраще працює, якщо заходити на кілька хвилин щодня — тоді інтервали працюють на вас."`**, **`"На головну"`** |
| 81–87 | інакше: `Column` + `Text("Повторення", headlineSmall)` + `Spacer` | **`"Повторення"`** |
| 90–93 | `Text("Картка " + … + " з " + …, labelLarge, onSurfaceVariant)` + `Spacer` + `LinearProgressIndicator(progress = state.progressFraction)` | **`"Картка "`** + **`" з "`** (напр. «Картка 3 з 12»); прогрес — `currentIndex / steps.size` |
| 97–115 | `ReviewStep(container, state, viewModel, …)` | — |

### 5.4 `ReviewStep` (ReviewScreen.kt:137–299)

Верхній рівень: `val step = state.currentStep ?: return`.

| Рядок | Умова | Елемент | Текст/параметри |
|---|---|---|---|
| 142–148 | `step is Flashcard` | `Text(if (step.askSpanish) "Згадайте іспанською" else "Що це означає?", promptStyle)` | **`"Згадайте іспанською"`** / **`"Що це означає?"`** |
| 150–173 | | `Card(surfaceVariant)` — обличчя картки | `askSpanish` → `Text(frontUk, headlineMedium, Center)`; інакше `Text(frontEs, spanishWordStyle, Center)`; і якщо `revealed` — `Spacer` + `Text(backEs \| backUk)`; якщо `pronunciation` не порожній — `Spacer` + `Text("[" + pronunciation + "]")` |
| 203–216 | `revealed` | `Card` прикладу (якщо `exampleEs` не порожній) | `Text(exampleEs)`, `Text(exampleUk)` |
| 195–197 | `revealed` і `genderNoteUk` не порожній | `InfoBanner(genderNoteUk)` | — |
| 197–200 | `revealed` і `cognateNoteUk` не порожній | `InfoBanner(cognateNoteUk, secondaryContainer/onSecondaryContainer)` | — |
| 204 | `revealed` | `OutlinedButton` (лейбл — синглтон) | **`"Прослухати"`** (озвучує `backEs`) |
| 203–212 | `revealed` | `Text("Наскільки добре ви згадали?", labelLarge, onSurfaceVariant)` | **`"Наскільки добре ви згадали?"`** |
| 216–232 | `revealed` | 4 × `OutlinedButton(onClick = { viewModel.rate(grade) })`, всередині `Row(SpaceBetween, CenterVertically)`: `Text(symbol + "  " + titleUk, bodyLarge)` + `Text(intervalLabel, labelMedium, onSurfaceVariant)` | Ті самі підписи, що й у занятті (див. 3.4) |
| 239 | `!revealed` | `PrimaryActionButton` | **`"Показати відповідь"`** → `viewModel.reveal()` |
| 244–275 | `step is ExerciseStep` | `ExerciseContent(...)` (той самий спільний компонент) | — |
| 260–273 | `exercise.checked` | `Card(colors = if (correct) secondaryContainer else errorContainer)` + `Icon` + `Text("Правильно")` (єдиний підпис успіху в цьому файлі), `Text("Правильно: " + expected)`, `InfoBanner(exercise.explanationUk, відповідні кольори)` | **`"Правильно"`**, **`"Правильно: "`** |
| 273 | `exercise.checked` | `PrimaryActionButton` | **`"Далі"`** |
| 275 | `exercise.canCheck` | `PrimaryActionButton` | **`"Перевірити"`** → `viewModel.check()` |
| 284–299 | `step is Summary` | `Text("Повторення завершено", headlineMedium)`; `Card` зі статистикою: `Text("Карток: " + answered)`, `Text("Правильно: " + correct)`, `Text("Хвилин: " + minutes)`; `InfoBanner("Наступні повторення вже розставлені за часом. Чим краще ви згадуєте, тим довшими стають інтервали.")`; `PrimaryActionButton("На головну")` | **`"Повторення завершено"`**, **`"Карток: "`**, **`"Правильно: "`**, **`"Хвилин: "`**, текст банера дослівно, **`"На головну"`** |

### 5.5 Кнопки оцінки SRS — точні підписи та маппінг

У Review (як і в занятті) кнопки будуються ітеруванням `Grade.entries`, тому порядок і підписи такі:

| Позиція | Константа | Точний підпис на кнопці | Підказка під підписом |
|---|---|---|---|
| 1 | `AGAIN` | `"✕  Не знаю"` | `intervalLabel` з `SrsScheduler.preview` |
| 2 | `HARD` | `"~  Пам'ятаю з труднощами"` | те саме |
| 3 | `GOOD` | `"✓  Знаю"` | те саме |
| 4 | `EASY` | `"★  Дуже добре"` | те саме |

(Роздільник між символом і назвою — рівно **два пробіли**; це видно з `StringBuilder.append("  ")` у байткоді.)

### 5.6 Переворот картки, статистика, завершення

* **Переворот картки**: стан `SessionUiState.revealed`; у Review його вмикає `viewModel.reveal()` (кнопка `"Показати відповідь"`). До перевороту видно лише обличчя картки (в Review — українське слово, бо `askSpanish = true`); після перевороту додаються: іспанська відповідь `backEs` (стиль `spanishWordStyle`), приклад, бейджі роду/споріднених слів, кнопка `"Прослухати"` і рядок оцінок `"Наскільки добре ви згадали?"` + 4 кнопки SRS.
* **Статистика сесії**: лічильники живуть у `SessionUiState.answeredCount/correctCount` і показуються у фінальному кроці `Summary`: `"Карток: N"`, `"Правильно: N"`, `"Хвилин: N"` (у Review `newWords = 0` і `weakTags = emptyList()`, тому банерів про нові слова/слабкі теми там немає).
* **Екран завершення**: окремого екрана немає — коли після останньої картки `currentIndex` вказує на крок `Summary`, `ReviewStep` рендерить картку `"Повторення завершено"` з підсумком і банером про інтервали та кнопкою `"На головну"`; паралельно `finished = true`.
* Якщо черга порожня (`isEmpty = !loading && steps.isEmpty()`), замість кроків показується `EmptyState` `"Усе повторено"` + `"На головну"`.

### 5.7 Дії користувача

| Дія | Видима реакція | Виклик |
|---|---|---|
| Натиснути `"Показати відповідь"` | Розкриваються відповідь, приклад, нотатки, кнопка прослуховування і 4 кнопки оцінки | `ReviewViewModel.reveal()` |
| Натиснути `"Прослухати"` | TTS озвучує `backEs` | `ReviewStep$3` (читає `step.backEs`) |
| Натиснути кнопку оцінки | Фіксується SRS-відповідь, лічильники оновлюються, показується наступна картка (або підсумок) | `ReviewViewModel.rate(grade)` → `advance(...)` |
| Вибрати варіант у вправі | Варіант підсвічується | `ReviewViewModel.selectOption(i)` |
| Натиснути токен | Токен додається/прибирається зі складеного речення | `ReviewViewModel.toggleToken(i)` |
| Ввести текст | Оновлюється поле відповіді | `ReviewViewModel.updateText(text)` |
| Натиснути `"Перевірити"` | Показується картка результату з `"Правильно"`/`"Правильно: …"` | `ReviewViewModel.check()` |
| Натиснути `"Далі"` | Перехід до наступного кроку; лічильник `answeredCount`/`correctCount` оновлюється | `ReviewViewModel.rate(...)` з `Grade.GOOD` (лямбда `ReviewStep$12/13/…`) |
| Натиснути `"На головну"` | Вихід із екрана повторення | `onFinished()` |

---

## Прогалини

1. **Шлях до файлу.** Вихідний шлях `_work\spec\32_session_review.md` під час роботи перестав існувати (каталог `_work\` видалено/переміщено). Файл записано в `Spain\spec\32_session_review.md` — поруч з іншими пронумерованими спеками (`02_learning_engine.md`, `05_ios_port_contract.md`).
2. **Smali-дампи `_work\smali\classes*_ui.txt` видалено** під час сесії; частину деталей довелося дочитувати з робочої копії дизасемблю в `%TEMP%\dsh-ctDS1R\krupa_ios\disasm\classes*.txt`, а деякі ранні витяги збереглися лише в контексті цієї сесії.
3. **Кнопка виходу**: діалогу підтвердження в `SessionScreen.kt` не знайдено — `"Вийти"` викликає `onExit` напряму. Чи є підтвердження у навігаційному хості (`AppNav`), не встановлено (файл не входив у надані джерела).
4. **`ListeningBlock`**: у байткоді обидві кнопки — `"Прослухати повністю"` (з іконкою `Icons.Filled.VolumeUp`, одразу після заголовків) і `"Завершити слухання"` (внизу, без іконки) — рендеряться **безумовно**; жодного розгалуження за станом відтворення не знайдено. Можливо, це особливість декомпіляції, а не задум; логіку «одна кнопка перемикається» підтвердити не вдалося.
5. **Точні стилі/кольори** для частини елементів встановлено лише частково (наприклад, стиль підпису `"Нове слово"`, `"Повторення"` у Review — `headlineSmall`, точні `TextStyle` для заголовків блоків). Кольори банерів і карток звірено там, де в байткоді явно викликаються `ColorScheme.get…`.
6. **`GradePreview.intervalLabel`**: словник підписів (`"сьогодні"`, `"менш ніж за день"`, `"через N дн/міс/р"`) і пороги (1/30/365 днів) відновлено, але точну формулу інтервалів для коротких проміжків (`SrsScheduler.preview`) у межах цього завдання не декодовано повністю.
7. **`ExerciseBlock` / `ReviewStep` (гілка вправ)**: сама візуальна частина вправи живе у спільному `ExerciseContent` (`ui/screens/exercise/ExerciseContent.kt`) і в цій специфікації не розкрита (окремий екран/спека). Також не встановлено, який саме текст показує заголовок картки результату в Review при **неправильній** відповіді: серед рядкових констант `ReviewScreen.kt` є лише `"Правильно"` (рядка `"Не зовсім"` немає, він є тільки в `SessionScreen.kt`).
8. **`WordIntroBlock`**: точний стиль підпису `"Нове слово"` і те, чи це `Text` заголовка блоку з `TypeKt`, визначено лише за послідовністю викликів (`MaterialTheme.typography` + `colorScheme`), без відновлення конкретних імен стилів.
9. **`SessionViewModel.buildTopicSession`**: порядок «слова → граматика → вправи → речення» відновлено з порядку викликів у байткоді; можливі проміжні фільтри (`topicId`, `level`) застосовуються через репозиторії (`wordsByTopic`, `sentencesByLevel(...).filter { topicId }`, `exercisesByLevel(...).filter { topicId }`), але точні умови фільтрації речень/вправ за темою не верифіковано порядково.
10. **Дублювання `frontEs`/`backEs` і `frontUk`/`backUk`** (обидва беруться з `word.display` та `word.translationUk`) підтверджено байткодом, але чи це навмисно в початковому коді (напр. для різних сторін картки в майбутньому) — не встановлено.
