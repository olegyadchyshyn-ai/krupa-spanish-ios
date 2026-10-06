# 40. Екрани «Слова» (`Words`), «Слово» (`WordDetail`) і «Тема» (`TopicDetail`) — точна UI/UX-специфікація

Джерела: `_recon/strings_by_class.txt` (рядкові константи за класами) та дизасембльований smali
(`_work/smali/classes8_ui.txt` — `ua/krupa/spanish/ui/screens/words/*`, `classes7_ui.txt` —
`ua/krupa/spanish/ui/screens/topic/*`, `classes8_ui.txt`/`classes7_ui.txt` — `ui/learn/LearningComponentsKt`,
`ui/components/*`).

Номери у дужках виду `(WordsScreen.kt:210)` — це **номери рядків оригінального Kotlin-файлу** з
compose-метаданих (`sourceInformation`, `traceEventStart`, SMAP, `positions`). Порядок блоків
відновлено за зростанням цих номерів і за порядком викликів у байт-коді.

> **Важливо (стан джерел під час аналізу).** Каталог `_work/smali/` **зник з диска** приблизно
> посередині роботи (перевірено: `C:\...\Spain\_work\smali` → *не існує*; у `_work` лишився тільки
> `spec/`). Усе, що наведено нижче без позначки «не підтверджено», було прочитано зі smali **до**
> зникнення; частину деталей `TopicDetailViewModel`/`TopicDetailUiState` та `WordRow` довелося
> відновлювати лише з рядкових констант — див. розділ **Прогалини**.

---

## 0. Спільні компоненти, які використовують ці екрани

| Composable | Файл | Роль |
|---|---|---|
| `MetricCard(title, value, modifier, caption, color, icon)` | `ui/components/CommonComponents.kt:73` | плитка-метрика (підпис, число, дрібний підпис) |
| `LabeledValueRow(label, value, modifier)` | `CommonComponents.kt:176` | рядок «підпис — значення» |
| `InfoBanner(text, modifier, containerColor, contentColor, icon)` | `CommonComponents.kt:242` | інформаційна плашка |
| `SectionTitle(title, modifier)` | `CommonComponents.kt:36` | заголовок секції |
| `EmptyState(title, description…)` | `CommonComponents.kt:200` | порожній стан |
| `PrimaryActionButton(text, onClick, modifier, enabled, icon)` | `ui/components/NavigationComponents.kt` | велика кнопка дії |
| `WordRow(word, card, onClick, onSpeak, modifier)` | `ui/learn/LearningComponents.kt:134` | рядок слова у списку (використовують Words і TopicDetail) |
| `CircularProgressIndicator`, `LinearProgressIndicator` | Material3 | індикатори завантаження/міцності |

`WordRow` (детально — поза межами цього файлу): рядкова картка слова; у її лямбдах знайдено
розділювач `" · "` і підписи станів **`"нове"`**, **`"у навчанні"`**, **`"засвоєно"`**,
**`"важке"`**, **`"ще не вчилося"`** (усі — з малої літери), а також колбек озвучення
(`onSpeak`, `LearningComponents.kt:157`).

Довідкові типи (з `spec/01_models_enums.md`, `spec/02_learning_engine.md`):
`CardPhase` = `NEW` (`"new"`), `LEARNING` (`"learning"`), `REVIEW` (`"review"`), `RELEARNING` (`"relearning"`);
`CardState` має `phase`, `dueAt`, `intervalDays`, `intervalMinutes`, `lapses`, `totalReviews`,
`accuracyPercent`, `itemType`, `itemId`;
`Level` = `A0`, `A1`, `A2`, `B1`, `B2` (`code`/`titleUk`/`descriptionUk`), `Level.mvpLevels = [A0, A1, A2]`.

---

# 1. Екран «Слова» — `WordsScreen.kt` + `WordsViewModel.kt`

## 1.1 Призначення

Словник курсу: один прокручуваний список (не `Scaffold`, без `TopAppBar`) із заголовком-лічильником,
трьома метриками стану пам'яті, полем пошуку, двома рядами чіпів (рівень CEFR + стан
запам'ятовування) і списком слів `WordRow`. Тап по слову відкриває `WordDetail`, кнопка озвучення в
рядку промовляє іспанське слово через TTS.

## 1.2 `WordsUiState` (`WordsViewModel.kt`)

Порядок полів = порядок конструктора (перевірено за `copy$default` / `component1..9`).

| Поле | Тип | Призначення | Замовчування |
|---|---|---|---|
| `loading` | `Boolean` | стан первинного завантаження | `true` |
| `query` | `String` | текст у полі пошуку | `""` |
| `level` | `Level?` | обраний рівень; `null` = «Усі рівні» | `null` |
| `topicId` | `String?` | фільтр за темою (у UI `WordsScreen` не використовується) | `null` |
| `filter` | `WordFilter` | фільтр стану запам'ятовування | `WordFilter.ALL` |
| `allWords` | `List<Word>` | усі слова курсу, `sortedBy { it.frequencyRank }` | `emptyList()` |
| `visible` | `List<Word>` | результат `recompute()`, не більше **300** елементів | `emptyList()` |
| `cards` | `Map<String, CardState>` | картки SRS за `word.id` | `emptyMap()` |
| `topics` | `List<Topic>` | теми курсу, `sortedBy { it.orderIndex }` | `emptyList()` |

Похідні (get-властивості, обчислюються з `cards`/`allWords`):

| Властивість | Формула |
|---|---|
| `totalWords` | `allWords.size` |
| `masteredCount` | `cards.values.count { it.intervalDays >= 21.0 }` |
| `learningCount` | `cards.values.count { it.totalReviews > 0 && it.intervalDays < 21.0 }` |
| `hardCount` | `cards.values.count { it.totalReviews > 0 && it.lapses > 0 && it.accuracyPercent < 70 }` |

Межа «засвоєно» = **21 день** (у метриці підписано як `"інтервал 3+ тижні"`).

## 1.3 `WordsViewModel` — дії

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `<init>` | `container: AppContainer` | `_state = MutableStateFlow(WordsUiState())`, `queryFlow = MutableStateFlow("")`; запускає дві корутини (див. нижче) | початковий стан |
| (корутина 1, рядки 62–68) | — | `words = container.courses.allWords().sortedBy { it.frequencyRank }`; `topics = container.courses.topics().sortedBy { it.orderIndex }`; `_state.value = _state.value.copy(allWords = words, topics = topics)`; `recompute()`; `refreshCards()` | `allWords`, `topics`, `visible`, `cards` |
| (корутина 2, рядки 70–75) | — | `queryFlow.debounce(200).collectLatest { query -> _state.value = _state.value.copy(query = query); recompute() }` | `query`, `visible` |
| `getState()` | — | повертає `StateFlow<WordsUiState>` | — |
| `onQueryChanged(query: String)` | новий текст | лише `queryFlow.value = query` (стан оновлює корутина 2 після debounce 200 мс) | `query` (із затримкою) |
| `setFilter(filter: WordFilter)` | константа фільтра | `_state.value = _state.value.copy(filter = filter)`; `recompute()` | `filter`, `visible` |
| `setLevel(level: Level?)` | рівень або `null` | `_state.value = _state.value.copy(level = level)`; `recompute()` | `level`, `visible` |
| `setTopic(topicId: String?)` | id теми або `null` | `_state.value = _state.value.copy(topicId = topicId)`; `recompute()` | `topicId`, `visible` |
| `recompute()` (private) | — | фільтрація `allWords` → `visible` (див. 1.4) | `visible` |
| `refreshCards()` (private suspend) | — | `container.srsEngine.allCards().filter { it.itemType == "word" }.associateBy { it.itemId }` → `_state.value = _state.value.copy(cards = …)` | `cards` |

## 1.4 Логіка `recompute()` (вибірка, без сортування)

```kotlin
val current = _state.value
val q = current.query.trim().lowercase(Locale.ROOT)          // Locale.ROOT
val visible = current.allWords.filter { word ->
    val card = current.cards[word.id]
    val matchesFilter = when (current.filter) {
        WordFilter.ALL         -> true
        WordFilter.LEARNING    -> card != null && card.phase != CardPhase.NEW && card.intervalDays < 21.0
        WordFilter.DIFFICULT   -> card != null && card.totalReviews > 0 && card.lapses > 0 && card.accuracyPercent < 70
        WordFilter.MASTERED    -> card != null && card.intervalDays >= 21.0
        WordFilter.NOT_STARTED -> card == null || card.totalReviews == 0
    }
    matchesFilter
        && (q.isEmpty() || word.spanish.lowercase().contains(q) || word.translationUk.lowercase().contains(q))
        && (current.level == null || word.level == current.level)
        && (current.topicId == null || word.topicId == current.topicId)
}.take(300)
_state.value = current.copy(visible = visible)
```

**Порядок списку не змінюється фільтром** — він заданий один раз при завантаженні
(`sortedBy { it.frequencyRank }`, тобто за частотністю, а не за алфавітом).

## 1.5 Структура екрана зверху вниз

Корінь — `Box(Modifier.fillMaxSize())`; `Scaffold`/`TopAppBar` відсутні.

1. **Індикатор завантаження** (`WordsScreen.kt:45`, група `C45@2027L27`).
   `if (state.loading) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }`
   — уся решта вмісту в цей момент не рендериться.
2. **Список** (`WordsScreen.kt:49–53`): `LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp))`.
   Елементи — строго в такому порядку:
   1. **Заголовок + опис словника** — `item` (`WordsScreen.kt:55–66`, лямбда `$3$1`):
      `Column(verticalArrangement = Arrangement.Top, horizontalAlignment = Alignment.Start)`:
      - `Text("Слова", style = MaterialTheme.typography.headlineMedium)` (`:57`);
      - `Spacer(Modifier.height(4.dp))` (`:58`);
      - `Text("Словник курсу: ${state.totalWords} слів. Стан показує, наскільки надійно слово закріпилося в пам'яті.", style = bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)` (`:59–63`).
   2. **Три метрики стану** — `item` (`:68–86`, `$3$2`):
      `Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top)`, три
      `MetricCard` з `Modifier.weight(1f)`: «Засвоєно» + підпис «інтервал 3+ тижні» (значення = `masteredCount`),
      «У навчанні» (`learningCount`), «Важкі» (`hardCount`).
   3. **Пошук** — `item` (`:89–98`, `$3$3`): `OutlinedTextField` (див. 1.10).
   4. **Два ряди чіпів** — `item` (`:100–122`, `$3$4`):
      `Column(verticalArrangement = spacedBy(…), horizontalAlignment = Alignment.Start)`:
      - `Row(spacedBy(…), verticalAlignment = Alignment.Top)` (`:101`):
        `FilterChip(selected = state.level == null, onClick = { viewModel.setLevel(null) }, label = { Text("Усі рівні") })` (`:102–105`), далі
        `Level.mvpLevels.forEach { level -> FilterChip(selected = state.level == level, onClick = { viewModel.setLevel(if (state.level == level) null else level) }, label = { Text(level.code) }) }` (`:108–112`).
        Підпис чіпа рівня — **`Level.code`** (`"A0"`, `"A1"`, `"A2"`), повторний тап знімає вибір.
      - `Row(spacedBy(…), verticalAlignment = Alignment.Top)` (`:115–121`):
        `WordFilter.entries.forEach { filter -> FilterChip(selected = state.filter == filter, onClick = { viewModel.setFilter(filter) }, label = { Text(filter.titleUk) }) }`.
      Обидва ряди — звичайні `Row` (не `LazyRow`, без горизонтального скролу).
   5. **Порожній стан** — умовний `item` (`:128–134`): якщо `state.visible.isEmpty()`, показується
      `EmptyState` із заголовком «Нічого не знайдено» і описом «Спробуйте змінити фільтр або запит пошуку.»
      (`ComposableSingletons$WordsScreenKt.lambda-3`, трейс `WordsScreen.kt:129`).
   6. **Рядки слів** — `items(state.visible)` (`:137–150`, `$3$6`):
      `WordRow(word = word, card = state.cards[word.id], onClick = { onOpenWord(word.id) }, onSpeak = { scope.launch { container.tts.speak(word.spanish) } }, modifier = Modifier)`.
      (у байт-коді лямбди `$3$6$1` — «відкрити слово», `$3$6$2` → `$3$6$2$1` — TTS).
   7. **Завершальний елемент** — `item` (`:151–152`, `ComposableSingletons$WordsScreenKt.lambda-4`, `C150@5869L30`):
      рядкових констант немає; за розміром групи це відступ-«підвал» списку (`Spacer`) — *не підтверджено*.

## 1.6 Усі видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Заголовок списку | `"Слова"` |
| Підзаголовок | `"Словник курсу: "` + `{totalWords}` + `" слів. Стан показує, наскільки надійно слово закріпилося в пам'яті."` |
| Метрика 1 (підпис) | `"Засвоєно"` |
| Метрика 1 (дрібний підпис) | `"інтервал 3+ тижні"` |
| Метрика 2 (підпис) | `"У навчанні"` |
| Метрика 3 (підпис) | `"Важкі"` |
| Плейсхолдер поля пошуку | `"Пошук іспанською або українською"` |
| Чіп «усі рівні» | `"Усі рівні"` |
| Чіпи рівнів | `Level.code` → `"A0"`, `"A1"`, `"A2"` (набір = `Level.mvpLevels`) |
| Чіпи фільтра | `"Усі"`, `"У навчанні"`, `"Важкі"`, `"Засвоєні"`, `"Ще не вчилися"` |
| Порожній стан — заголовок | `"Нічого не знайдено"` |
| Порожній стан — опис | `"Спробуйте змінити фільтр або запит пошуку."` |
| Рядок слова (з `WordRow`) | `word.spanish`, `word.translationUk`, розділювач `" · "`, стан: `"нове"` / `"у навчанні"` / `"засвоєно"` / `"важке"` / `"ще не вчилося"` |

## 1.7 Стани

| Стан | Що показується | Текст |
|---|---|---|
| **loading** (`loading == true`) | на весь екран по центру `CircularProgressIndicator`; список/пошук/чіпи не рендеряться | — (тексту немає) |
| **empty** (`visible.isEmpty()`) | заголовок, метрики, пошук і чіпи **лишаються**; замість рядків — `EmptyState` | `"Нічого не знайдено"` / `"Спробуйте змінити фільтр або запит пошуку."` |
| **error** | окремого стану помилки немає: у `WordsUiState` немає поля помилки, `try/catch` у `recompute()`/`refreshCards()` відсутні | текст не знайдено |
| **success** | `LazyColumn` із 7 типів елементів (заголовок, метрики, пошук, чіпи, рядки, «підвал») | див. 1.6 |

## 1.8 Дії користувача

| Елемент | Дія | Наслідок | Навігація |
|---|---|---|---|
| Поле пошуку | введення тексту | `onQueryChanged(text)` → `queryFlow` → (debounce 200 мс) `query` у стані → `recompute()` | — |
| Чіп `"Усі рівні"` | тап | `setLevel(null)` | — |
| Чіп рівня (`A0`/`A1`/`A2`) | тап | `setLevel(level)`; повторний тап на обраному → `setLevel(null)` | — |
| Чіп фільтра стану | тап | `setFilter(filter)` (повторний тап лишає той самий фільтр обраним, зняти вибір не можна — `ALL` грає роль «скинути») | — |
| Рядок слова (`WordRow`) | тап по картці | `onOpenWord(word.id)` | → `WordDetailScreen` (маршрут `word_{wordId}`) |
| Кнопка озвучення в рядку | тап | `scope.launch { container.tts.speak(word.spanish) }` | — |

## 1.9 Діалоги / підтвердження

Немає. Жодних `AlertDialog`, `ModalBottomSheet` чи підтверджень на екрані не знайдено.

## 1.10 Пошук у «Словах» (окремо)

| Аспект | Значення |
|---|---|
| Компонент | `OutlinedTextField` (`WordsScreen.kt:89–98`) |
| `value` | `state.query` |
| `onValueChange` | `viewModel::onQueryChanged` (лямбда `$3$3$1`) |
| `modifier` | `Modifier.fillMaxWidth()` |
| Плейсхолдер | `{ Text("Пошук іспанською або українською") }` (`ComposableSingletons…lambda-1`, `WordsScreen.kt:93`) |
| `singleLine` | `true` |
| `shape` | `RoundedCornerShape(14.dp)` |
| `leadingIcon` / `trailingIcon` | **відсутні** (у байт-коді обидва аргументи = `null`) |
| Кнопка очищення (хрестик) | **НЕМАЄ**; очистити можна лише вручну, стерши текст |
| Поведінка | значення йде у `queryFlow`; стан `query` оновлюється через `debounce(200 ms)` + `collectLatest`, далі `recompute()` |
| Нормалізація | `query.trim().lowercase(Locale.ROOT)` |
| За чим шукає | `word.spanish.lowercase().contains(q) \|\| word.translationUk.lowercase().contains(q)` (транскрипція, приклади й нотатки не враховуються) |
| Обмеження | результат ріжеться `take(300)` |

## 1.11 `WordFilter` — усі константи, підписи, порядок і вплив на список

Файл — `WordsViewModel.kt` (enum нижче за `WordsUiState`), поле-властивість — `titleUk` (тип `String`),
геттер `getTitleUk()`.

Порядок оголошення (з `<clinit>` / `$values()`):
`ALL`, `LEARNING`, `DIFFICULT`, `MASTERED`, `NOT_STARTED`.

| # | Константа | `titleUk` (дослівно) | Умова входження слова у список (`recompute`) | Стан запам'ятовування |
|---|---|---|---|---|
| 0 | `ALL` | `"Усі"` | `true` | будь-який (у т.ч. без картки) |
| 1 | `LEARNING` | `"У навчанні"` | `card != null && card.phase != CardPhase.NEW && card.intervalDays < 21.0` | картка вже не «нова», але інтервал менший за 3 тижні (фази `LEARNING`/`REVIEW`/`RELEARNING` з малим інтервалом) |
| 2 | `DIFFICULT` | `"Важкі"` | `card != null && card.totalReviews > 0 && card.lapses > 0 && card.accuracyPercent < 70` | були повторення, є зриви (`lapses > 0`) і точність < 70 % |
| 3 | `MASTERED` | `"Засвоєні"` | `card != null && card.intervalDays >= 21.0` | інтервал ≥ 21 дня («3+ тижні») |
| 4 | `NOT_STARTED` | `"Ще не вчилися"` | `card == null \|\| card.totalReviews == 0` | картки немає або жодного повторення |

Додатково (перевірено в `WordsViewModel$WhenMappings`): мапінг enum→гілка `when` = **ALL→1, LEARNING→2,
DIFFICULT→3, MASTERED→4, NOT_STARTED→5**; фільтр **не сортує** список, лише звужує його (порядок — за
`frequencyRank`). Фільтр не впливає на `cards`/метрики — метрики рахуються по всьому `cards`.

---

# 2. Екран «Слово» — `WordDetailScreen.kt` + `WordDetailViewModel.kt`

## 2.1 Призначення

Картка одного слова: велика іспанська форма, транскрипція, український переклад, кнопки озвучення
(звичайна та сповільнена 0.75×), блок мовних характеристик (частина мови, рід, множина, рівень, тема,
частотність), блок стану SRS («Стан пам'яті») і картка прикладу з озвученням. Екран **призначений лише
для перегляду** — кнопок оцінки/вивчення (Again/Hard/Good/Easy) тут немає.

## 2.2 `WordDetailUiState` (`WordDetailViewModel.kt`)

Порядок полів = порядок конструктора `(Z, Word, String, Z, I, I, I, String, String)`.

| Поле | Тип | Призначення | Замовчування |
|---|---|---|---|
| `loading` | `Boolean` | стан завантаження | `true` |
| `word` | `Word?` | саме слово | `null` |
| `topicTitle` | `String` | українська назва теми слова (`Topic.titleUk`) | `""` |
| `hasCard` | `Boolean` | чи є картка SRS (`cardFor("word", wordId) != null`) | `false` |
| `strength` | `Int` | «міцність» 0…100 (`SrsScheduler.strength(card, now)`) | `0` |
| `totalReviews` | `Int` | кількість повторень картки | `0` |
| `accuracyPercent` | `Int` | точність у відсотках | `0` |
| `intervalLabel` | `String` | людський підпис інтервалу (`describeInterval`) | `""` |
| `nextReviewLabel` | `String` | дата наступного повторення (`formatDate(card.dueAt)`) | `""` |

## 2.3 `WordDetailViewModel` — дії

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `<init>` | `container: AppContainer`, `wordId: String` | `_state = MutableStateFlow(WordDetailUiState())`; `viewModelScope.launch { load() }` | початковий стан → `loading = false` після `load()` |
| `getState()` | — | `StateFlow<WordDetailUiState>` (у екрані — `collectAsStateWithLifecycle()`) | — |
| `load()` (private suspend, рядки 42–58) | — | `word = container.courses.word(wordId)`; `topic = word?.let { container.courses.topic(it.topicId) }`; `card = container.srsEngine.cardFor("word", wordId)`; `now = System.currentTimeMillis()`; збирає новий `WordDetailUiState(loading = false, word = word, topicTitle = topic?.titleUk ?: "", hasCard = card != null, strength = card?.let { SrsScheduler.strength(it, now) } ?: 0, totalReviews = card?.totalReviews ?: 0, accuracyPercent = card?.accuracyPercent ?: 0, intervalLabel = card?.let { describeInterval(it) } ?: "", nextReviewLabel = card?.let { formatDate(it.dueAt) } ?: "")` | усі поля |
| `describeInterval(card)` (private, рядки 61–67) | `CardState` | `intervalMinutes > 0` → `"${intervalMinutes} хв"`; інакше `intervalDays < 1.0` → `"менш ніж день"`; `< 30.0` → `"${intervalDays.toInt()} дн"`; `< 365.0` → `"${(intervalDays / 30).toInt()} міс"`; інакше `"${(intervalDays / 365).toInt()} р"` | `intervalLabel` |
| `formatDate(epochMillis)` (private) | `Long` | `SimpleDateFormat("d MMMM, HH:mm", Locale("uk", "UA")).format(Date(epochMillis))` | `nextReviewLabel` |
| `WordDetailViewModelFactory` | `container`, `wordId` | створює `WordDetailViewModel(container, wordId)` (екран викликає `viewModel(factory = WordDetailViewModelFactory(container, wordId))`) | — |

Зверніть увагу: `describeInterval` використовує `intervalMinutes` **лише** для першої гілки; формат
`"N дн"` показує цілу частину `intervalDays`.

## 2.4 Структура екрана зверху вниз

Корінь — `Box(Modifier.fillMaxSize())`; `Scaffold`/`TopAppBar` відсутні.

1. **Індикатор завантаження** (`WordDetailScreen.kt:60`, група `C60@2695L27`):
   `if (state.loading) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }`.
2. **«Слово не знайдено»** (`:66–67`, `C67@2932L10,67@2884L71`): якщо `state.word == null` —
   `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Слово не знайдено") }`.
3. **Прокручуваний контент** (`:72–207`, група `C(WordDetailScreen)…72@2992L5857`):
   `Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = spacedBy(…))`.
   Елементи в порядку вихідного файлу:
   1. **Кнопка «Назад»** (`:85–88`) — `TextButton(onClick = onBack) { Text("Назад") }`
      (`ComposableSingletons$WordDetailScreenKt.lambda-1`, трейс `:80`). Це єдина навігація назад на екрані.
   2. **Картка слова** (`:89–109`; контент-лямбда `$5$1`, трейс `:90`), `Card(Modifier.fillMaxWidth(), shape = RoundedCornerShape(…))`:
      `Column(Modifier.fillMaxWidth().padding(16.dp))`:
      - `Text(word.fullForm, style = spanishWordStyle)` (`:96`);
      - `if (word.pronunciation.isNotBlank())`: `Spacer(Modifier.height(…))` + `Text("[" + word.pronunciation + "]")` (`:98–102`);
      - `Spacer(Modifier.height(…))` (`:105`);
      - `Text(word.translationUk)` (`:106`).
      (`fullForm` — форма з артиклем: `el `/`la ` + `spanish`, залежно від `withArticle`.)
   3. **Кнопки озвучення** (`:110–130`, група `C111@4580L365,119@4958L382`): `Row(spacedBy(…), verticalAlignment = Alignment.Top)`
      із двох `OutlinedButton` однакової ширини (`Modifier.weight(1f)`): «Звичайно» та «0.75× повільно» (див. 2.7).
   4. **Картка мовних характеристик** (`:132–147`; контент-лямбда `$5$3`, трейс `:133`) —
      `Card(Modifier.fillMaxWidth())` → `Column(Modifier.padding(16.dp))` із `LabeledValueRow` (див. 2.6).
   5. **Картка стану SRS** (`:148–168`; контент-лямбда `$5$4`, трейс `:149`) —
      `if (state.hasCard) Card(Modifier.fillMaxWidth())` → `Column(Modifier.padding(16.dp))` (див. 2.9);
      `else` — `InfoBanner("Це слово ще не зустрічалося в заняттях — воно з'явиться у наступних уроках.")` (`:168`).
   6. **Плашка транскрипції** (`:172`) — `if (word.ipaHint.isNotBlank()) InfoBanner("Вимова: " + word.ipaHint)`.
   7. **Картка прикладу** (`:176–190`; контент-лямбда `$5$5`, трейс `:177`) —
      `if (word.exampleEs.isNotBlank()) Card(Modifier.fillMaxWidth())`:
      `Column(padding(16.dp))`: `Text("Приклад")` (`:178`), `Spacer`, `Text(word.exampleEs)` (`:179`),
      `if (word.exampleUk.isNotBlank()) Text(word.exampleUk)` (`:180`), `Spacer`,
      `TextButton(onClick = { scope.launch { container.tts.speak(word.exampleEs) } }) { Text("Прослухати приклад") }` (`:182–189`, лямбда `lambda-4`, трейс `:191`).
   8. **Плашка нотаток** (`:197`) — `if (word.notesUk.isNotBlank()) InfoBanner(word.notesUk)`.
   9. **Плашка когнатів** (`:200–203`) — `if (word.cognateNoteUk.isNotBlank()) InfoBanner(word.cognateNoteUk, …)`;
      у байт-коді для цієї плашки беруться кольори з `MaterialTheme.colorScheme.secondaryContainer` (є гілка з іншими кольорами, ніж у плашки `notesUk`).
   10. **Завершальний відступ** (`:207`) — `Spacer(Modifier.height(…))`.

## 2.5 Усі видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Кнопка назад | `"Назад"` |
| Транскрипція у картці слова | `"["` + `{word.pronunciation}` + `"]"` |
| Кнопка озвучення 1 | `"Звичайно"` |
| Кнопка озвучення 2 | `"0.75× повільно"` |
| Рядок «частина мови» | label `"Частина мови"` |
| Рядок «рід» | label `"Рід"` |
| Рядок «множина» | label `"Множина"`; значення-заглушка `"не вживається"` |
| Рядок «рівень» | label `"Рівень"` |
| Рядок «тема» | label `"Тема"` |
| Рядок «частотність» | label `"Частотність"`; значення `"№"` + `{frequencyRank}` + `" у курсі"` |
| Заголовок картки SRS | `"Стан пам'яті"` |
| Показник міцності | label `"Міцність"`; значення `{strength}` + `"%"` |
| Показник повторень | label `"Повторень"` |
| Показник точності | label `"Точність"`; значення `{accuracyPercent}` + `"%"` |
| Показник інтервалу | label `"Інтервал"` |
| Наступне повторення | label `"Наступне повторення"` |
| Плашка, якщо картки немає | `"Це слово ще не зустрічалося в заняттях — воно з'явиться у наступних уроках."` |
| Плашка вимови | `"Вимова: "` + `{word.ipaHint}` (пробіл після двокрапки є) |
| Заголовок картки прикладу | `"Приклад"` |
| Кнопка озвучення прикладу | `"Прослухати приклад"` |
| Стан «слово не знайдено» | `"Слово не знайдено"` |
| Підписи інтервалу (з VM) | `" хв"`, `"менш ніж день"`, `" дн"`, `" міс"`, `" р"` |
| Формат дати | шаблон `"d MMMM, HH:mm"`, локаль `"uk"` / `"UA"` |

## 2.6 Поля картки слова (детально)

**Картка слова** (перша, `:89–109`):

| Поле `Word` | Як показується |
|---|---|
| `fullForm` | `Text`, стиль `ua.krupa.spanish.ui.theme.TypeKt.spanishWordStyle` — головний «великий» рядок |
| `pronunciation` | лише якщо не порожнє: `Spacer` + `Text("[" + pronunciation + "]")` |
| `translationUk` | після `Spacer`: `Text(translationUk)` |

**Картка мовних характеристик** (друга, `LabeledValueRow(label, value)` у порядку викликів):

| # | Label | Значення | Умова показу |
|---|---|---|---|
| 1 | `"Частина мови"` | `word.partOfSpeech.titleUk` (`"іменник"`, `"дієслово"`, `"прикметник"`, `"прислівник"`, `"займенник"`, `"прийменник"`, `"сполучник"`, `"вигук"`, `"артикль"`, `"числівник"`, `"фраза"`) | завжди |
| 2 | `"Рід"` | `word.gender.titleUk` | **лише якщо `word.partOfSpeech == PartOfSpeech.NOUN`** |
| 3 | `"Множина"` | `word.plural`, а якщо порожнє — `"не вживається"` | у тому ж блоці, що й «Рід» (тобто для іменників) |
| 4 | `"Рівень"` | `word.level.code` → `"A0"`, `"A1"`, `"A2"`, `"B1"`, `"B2"` | завжди |
| 5 | `"Тема"` | `state.topicTitle` (з `Topic.titleUk`) | завжди |
| 6 | `"Частотність"` | `"№" + word.frequencyRank + " у курсі"` | завжди |

Прикладів і граматичних нотаток у цій картці немає — приклад окремою карткою, нотатки — `InfoBanner`
(`word.notesUk`, `word.cognateNoteUk`). Окремих «форм дієслів» на екрані **немає**: показуються лише
`plural` (множина) і `fullForm` (форма з артиклем).

## 2.7 Кнопки озвучення (детально)

| Кнопка | Текст | Дія (`scope.launch`) |
|---|---|---|
| 1 | `"Звичайно"` | `tts.initialize()`; `tts.speak(word.spanish)` (`speak$default` з `rate` за замовчуванням) |
| 2 | `"0.75× повільно"` | `tts.initialize()`; `tts.setRate(0.75f)`; `tts.speak(word.spanish)`; `tts.setRate(1.0f)` — після промовляння швидкість повертається до 1.0 |
| 3 | `"Прослухати приклад"` (у картці прикладу) | `scope.launch { container.tts.speak(word.exampleEs) }` |

Обидві кнопки 1–2 — `OutlinedButton` з однаковою вагою (`Modifier.weight(1f)`), у одному `Row`.
TTS-об'єкт у екрані — `remember { container.tts }` / `ttsEngine` (у байт-коді `SpanishTtsEngine`).

## 2.8 Кнопки оцінки / вивчення

**На екрані їх немає.** Перевірено весь байт-код `WordDetailScreen`: єдині інтерактивні елементи —
`TextButton("Назад")`, два `OutlinedButton` озвучення та `TextButton("Прослухати приклад")`.
Оцінювання (grade) відбувається в сесії занять, а не тут; у `WordDetailViewModel` немає методів
`grade`/`review`/`ensureCard` — лише читання стану (`word`, `topic`, `cardFor`).

## 2.9 Стан SRS (детально)

| Елемент | Дані | Джерело |
|---|---|---|
| Наявність картки | `state.hasCard` | `srsEngine.cardFor("word", wordId) != null` |
| Заголовок | `"Стан пам'яті"` | `:150` |
| Прогрес-бар | `LinearProgressIndicator(progress = { state.strength / 100f }, Modifier.fillMaxWidth().height(…))` (`:152`) | `strength` = `SrsScheduler.strength(card, System.currentTimeMillis())` |
| `"Міцність"` | `"$strength%"` | `state.strength` |
| `"Повторень"` | `"$totalReviews"` | `card.totalReviews` |
| `"Точність"` | `"$accuracyPercent%"` | `card.accuracyPercent` |
| `"Інтервал"` | `intervalLabel` | `describeInterval(card)`: `"N хв"` / `"менш ніж день"` / `"N дн"` / `"N міс"` / `"N р"` |
| `"Наступне повторення"` | `nextReviewLabel` | `formatDate(card.dueAt)` → `d MMMM, HH:mm` (uk-UA) |
| Якщо картки немає | `InfoBanner("Це слово ще не зустрічалося в заняттях — воно з'явиться у наступних уроках.")` | `:168` |

Поля `phase`, `lapses`, `ease`, `repetitions`, `averageResponseMs` у UI **не показуються**.

## 2.10 Стани

| Стан | Що показується | Текст |
|---|---|---|
| **loading** | `Box(fillMaxSize, Center)` + `CircularProgressIndicator` | — |
| **empty / not found** (`word == null`) | `Box(fillMaxSize, Center)` + `Text` | `"Слово не знайдено"` |
| **error** | окремого стану немає (немає поля помилки; `load()` не має `try/catch`) | текст не знайдено |
| **success (є картка SRS)** | картка слова → кнопки озвучення → характеристики → `Card("Стан пам'яті")` → решта | див. 2.5 |
| **success (картки немає)** | те саме, але замість картки SRS — `InfoBanner` | `"Це слово ще не зустрічалося в заняттях — воно з'явиться у наступних уроках."` |
| **умовні блоки** | `ipaHint` порожній → плашки «Вимова» немає; `exampleEs` порожній → картки прикладу немає; `exampleUk` порожній → другого рядка прикладу немає; `notesUk`/`cognateNoteUk` порожні → відповідних плашок немає | — |

## 2.11 Дії користувача

| Елемент | Дія | Наслідок | Навігація |
|---|---|---|---|
| `TextButton "Назад"` | тап | `onBack()` | повернення на попередній екран (у навігації — `WordsScreen`) |
| `OutlinedButton "Звичайно"` | тап | TTS промовляє `word.spanish` | — |
| `OutlinedButton "0.75× повільно"` | тап | TTS промовляє `word.spanish` зі швидкістю 0.75× і повертає 1.0 | — |
| `TextButton "Прослухати приклад"` | тап | TTS промовляє `word.exampleEs` | — |
| Скрол | свайп | `verticalScroll` усього контенту (картки не в `LazyColumn`) | — |

## 2.12 Діалоги / підтвердження

Немає.

---

# 3. Екран «Тема» — `TopicDetailScreen.kt` + `TopicDetailViewModel.kt`

## 3.1 Призначення

Деталі теми курсу: назва українською та іспанською, опис, картка-агрегат «У цій темі» (кількість
слів/вправ/речень + перелік граматики), кнопка старту заняття з теми, список слів теми (ті самі
`WordRow`, що в «Словах») і список граматичних нотаток теми.

## 3.2 `TopicDetailUiState` (`TopicDetailViewModel.kt`)

Назви полів — дослівно з рядкових констант класу (`TopicDetailUiState(loading=…`, `, topic=`, `, words=`,
`, cards=`, `, exerciseCount=`, `, sentenceCount=`, `, listeningCount=`, `, suggestedMinutes=`,
`, grammarNotes=`). Типи виведені з використання у `TopicDetailScreen` (виклики `getWords()`,
`getCards()`, `getGrammarNotes()`, `getTopic()`, `getWordCount()`, `getExerciseCount()`,
`getSentenceCount()`, `getListeningCount()`, `getSuggestedMinutes()`).

| Поле | Тип | Призначення | Замовчування |
|---|---|---|---|
| `loading` | `Boolean` | стан завантаження (перший параметр конструктора) | `true` *(не підтверджено)* |
| `topic` | `Topic?` | тема | `null` *(не підтверджено)* |
| `words` | `List<Word>` | слова теми | `emptyList()` *(не підтверджено)* |
| `cards` | `Map<String, CardState>` | картки SRS за `word.id` | `emptyMap()` *(не підтверджено)* |
| `exerciseCount` | `Int` | к-сть вправ теми | `0` *(не підтверджено)* |
| `sentenceCount` | `Int` | к-сть речень теми | `0` *(не підтверджено)* |
| `listeningCount` | `Int` | к-сть аудіоматеріалів теми (керує плашкою про відсутність аудіо) | `0` *(не підтверджено)* |
| `suggestedMinutes` | `Int` | рекомендована тривалість заняття (у тексті кнопки) | `0` *(не підтверджено)* |
| `grammarNotes` | `List<GrammarNote>` | граматичні нотатки теми | `emptyList()` *(не підтверджено)* |

Похідна властивість: `wordCount` = `words.size` (використовується в картці «У цій темі»; окремого поля
конструктора немає).

## 3.3 `TopicDetailViewModel` — дії

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `<init>` | `container: AppContainer`, `topicId: String` | створює `MutableStateFlow(TopicDetailUiState())` і запускає завантаження у `viewModelScope` (у класі є `TopicDetailViewModel$1` — корутина з `<init>` та `TopicDetailViewModel$load$1` — suspend-продовження `load`) | початковий стан |
| `getState()` | — | `StateFlow<TopicDetailUiState>` (екран читає через `collectAsStateWithLifecycle()`) | — |
| `load()` (private suspend) | — | збирає повний стан теми: `topic`, `words`, `cards`, `exerciseCount`, `sentenceCount`, `listeningCount`, `suggestedMinutes`, `grammarNotes` (у рядкових константах класу присутні `"container"`, `"topicId"`, `"word"` — останнє вказує на фільтр карток за типом `"word"`, як у `WordsViewModel.refreshCards`) — **точні виклики репозиторію/SrsEngine не підтверджено** | усі поля |
| `TopicDetailViewModelFactory` | `container`, `topicId` | створює `TopicDetailViewModel(container, topicId)` (`viewModel(factory = TopicDetailViewModelFactory(container, topicId))`) | — |

## 3.4 Структура екрана зверху вниз

Корінь — `Box(Modifier.fillMaxSize())`; `Scaffold`/`TopAppBar` відсутні.

1. **Індикатор завантаження** (`TopicDetailScreen.kt:59`, група `C59@2457L27`):
   `if (state.loading) Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }`.
2. **«Тему не знайдено»** (`:65–66`): якщо `state.topic == null` —
   `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text("Тему не знайдено") }`.
3. **Список** (`:71–…`, група `71@2756L4680`, лямбда `TopicDetailScreen$5`):
   `LazyColumn(Modifier.fillMaxSize(), …)`. Елементи — строго в такому порядку:
   1. **Шапка теми** — `item` (`:77–92`, `$5$1`): `Column`:
      `Text(topic.titleUk, headlineMedium)` (`:78`);
      `Text(topic.titleEs, titleMedium, color = onSurfaceVariant)` (`:83`);
      `if (topic.descriptionUk.isNotBlank()) { Spacer(Modifier.height(…)); Text(topic.descriptionUk, bodyLarge) }` (`:86–91`).
   2. **Картка «У цій темі»** — `item` (`:97–120`, `$5$2` → контент `$5$2$1`, трейс `:101`):
      `Card(…)` → `Column(Modifier.padding(16.dp))`:
      - `Text("У цій темі", style = titleSmall, color = onSecondaryContainer)` (`:102`);
      - `Spacer(Modifier.height(8.dp))` (`:104`/`:105`);
      - `Text("${state.wordCount} слів · ${state.exerciseCount} вправ · ${state.sentenceCount} речень")` (`:108`, складено з `" слів · "`, `" вправ · "`, `" речень"`);
      - `if (state.grammarNotes.isNotEmpty()) { Spacer(…); Text("Граматика: " + state.grammarNotes.joinToString(", ") { it.titleUk }) }` (`:115–119`, розділювач `", "`).
   3. **Кнопка старту заняття** — `item` (`:127–133`, `$5$3`):
      `PrimaryActionButton(text = "Почати заняття з теми (${state.suggestedMinutes} хв)", onClick = { onStartLesson(topicId, state.suggestedMinutes) })`
      (`onClick` — лямбда `$5$3$1$1` із полями `$onStartLesson`, `$topicId`, `$state$delegate`).
   4. **Плашка про відсутність аудіо** — умовний `item` (`:136`, `ComposableSingletons…lambda-2`):
      додається, **тільки якщо `state.listeningCount == 0`** (перевірка перед додаванням елемента, `:135`);
      `InfoBanner("Для цієї теми поки немає окремого аудіоматеріалу — слухання буде з речень теми.")`.
   5. **Заголовок «Слова теми»** — `item` (`:144–145`, `$5$4`):
      `SectionTitle("Слова теми (${state.words.size})")`.
   6. **Рядки слів** — `items(state.words)` (`:148–150`):
      `WordRow(word = word, card = state.cards[word.id], onClick = { /* порожньо */ }, onSpeak = { scope.launch { container.tts.speak(word.spanish) } }, modifier = Modifier)`.
      `onClick` — порожня лямбда `$5$5$1` (`invoke():V` містить лише `return-void`), тобто **тап по слову в темі нікуди не веде**.
   7. **Заголовок «Граматика теми»** — `item` (`:164–165`, `ComposableSingletons…lambda-3`): `SectionTitle("Граматика теми")`.
   8. **Картки граматичних нотаток** — `items(state.grammarNotes)` (`:169`; контент `$5$6$1`, трейс `:170`):
      `Card(…)` → `Column(Modifier.padding(16.dp))`:
      - `Text(note.titleUk)` (`:171`);
      - `if (note.explanationUk.isNotBlank()) { Spacer(…); Text(…обрізаний explanationUk + "…") }` (`:172–173`);
      - `if (note.patternUk.isNotBlank()) { Spacer(…); Text("Закономірність: " + note.patternUk) }` (`:178–182`).
   9. **Завершальний елемент** — `item` (`:189–191`, `ComposableSingletons…lambda-4`, `C189@7398L30`):
      `Spacer(Modifier.height(…))`.

## 3.5 Усі видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Кнопка назад | `"Назад"` (`lambda-1`, `:79`) — див. примітку нижче |
| Стан «тему не знайдено» | `"Тему не знайдено"` |
| Картка-агрегат, заголовок | `"У цій темі"` |
| Картка-агрегат, рядок статистики | `{wordCount}` + `" слів · "` + `{exerciseCount}` + `" вправ · "` + `{sentenceCount}` + `" речень"` |
| Картка-агрегат, граматика | `"Граматика: "` + `titleUk` нотаток, з'єднані `", "` |
| Кнопка старту | `"Почати заняття з теми ("` + `{suggestedMinutes}` + `" хв)"` |
| Плашка без аудіо | `"Для цієї теми поки немає окремого аудіоматеріалу — слухання буде з речень теми."` |
| Заголовок секції слів | `"Слова теми ("` + `{words.size}` + `")"` |
| Заголовок секції граматики | `"Граматика теми"` |
| Картка нотатки, патерн | `"Закономірність: "` + `{note.patternUk}` |
| Картка нотатки, обрізання | суфікс `"…"` |
| Рядок слова (`WordRow`) | `word.spanish`, `word.translationUk`, `" · "`, стан з `"нове"` / `"у навчанні"` / `"засвоєно"` / `"важке"` / `"ще не вчилося"` |

Примітка: кнопка «Назад» належить до `ComposableSingletons$TopicDetailScreenKt.lambda-1`
(`TopicDetailScreen.kt:79`); у самому `LazyColumn` `item` для неї не створюється (лямбда зареєстрована
в сінглтоні, тому її виклик у байт-коді головного методу не зберігся) — **місце кнопки «Назад» у
верстці TopicDetail не підтверджено**; за аналогією з `WordDetailScreen` вона, найімовірніше, стоїть
над списком або першим елементом списку.

## 3.6 Що показується для теми

| Блок | Дані | Тексти |
|---|---|---|
| Назва | `topic.titleUk` (великий), `topic.titleEs` (другорядний) | — |
| Опис | `topic.descriptionUk`, показується лише якщо не порожній | — |
| Прогрес (агрегат) | `wordCount`, `exerciseCount`, `sentenceCount`, перелік `grammarNotes[].titleUk` | `"У цій темі"`, `" слів · "`, `" вправ · "`, `" речень"`, `"Граматика: "`, `", "` |
| Старт заняття | `suggestedMinutes` | `"Почати заняття з теми (N хв)"` |
| Аудіо | `listeningCount == 0` → плашка | `"Для цієї теми поки немає окремого аудіоматеріалу — слухання буде з речень теми."` |
| Список слів | `words` + `cards[word.id]` (стан SRS у рядку) | `"Слова теми (N)"` |
| Граматика | `grammarNotes`: `titleUk`, `explanationUk` (обрізаний), `patternUk` | `"Граматика теми"`, `"Закономірність: "` |
| Окремої смуги прогресу теми | Не знайдено: у `TopicDetailScreen` немає `LinearProgressIndicator` (є лише `CircularProgressIndicator` завантаження) | — |

## 3.7 Стани

| Стан | Що показується | Текст |
|---|---|---|
| **loading** | `Box(fillMaxSize, Center)` + `CircularProgressIndicator` | — |
| **empty / not found** (`topic == null`) | `Box(fillMaxSize, Center)` + `Text` | `"Тему не знайдено"` |
| **empty (немає слів)** | окремого порожнього стану для списку слів немає — заголовок `"Слова теми (0)"` і жодного рядка | текст не знайдено |
| **empty (немає граматики)** | заголовок `"Граматика теми"` лишається, список порожній; картка-агрегат не показує рядок `"Граматика: …"` | — |
| **аудіо відсутнє** | додатковий `item` з `InfoBanner` | `"Для цієї теми поки немає окремого аудіоматеріалу — слухання буде з речень теми."` |
| **error** | окремого стану немає (поле помилки відсутнє) | текст не знайдено |
| **success** | 9 типів елементів `LazyColumn` (див. 3.4) | — |

## 3.8 Дії користувача

| Елемент | Дія | Наслідок | Навігація |
|---|---|---|---|
| Кнопка `"Назад"` | тап | `onBack()` | повернення назад |
| `PrimaryActionButton "Почати заняття з теми (N хв)"` | тап | `onStartLesson(topicId, state.suggestedMinutes)` | → екран сесії занять (`SessionScreen`) з темою |
| Рядок слова (`WordRow`) | тап по картці | порожня лямбда (`$5$5$1` нічого не робить) | **навігації немає** |
| Кнопка озвучення в рядку слова | тап | `scope.launch { container.tts.speak(word.spanish) }` | — |
| Скрол | свайп | `LazyColumn` | — |

## 3.9 Діалоги / підтвердження

Немає.

---

# 4. Зведення маршрутів і параметрів екранів

| Екран | Параметри | Ключі ViewModel / фабрики | Навігаційні наслідки |
|---|---|---|---|
| `WordsScreen(container, onOpenWord)` | `onOpenWord: (String) -> Unit` | `WordsViewModelFactory(container)` | `onOpenWord(word.id)` → WordDetail |
| `WordDetailScreen(container, wordId, onBack)` | `wordId: String`, `onBack: () -> Unit` | ключ `"word_" + wordId`, `WordDetailViewModelFactory(container, wordId)` | `onBack()` |
| `TopicDetailScreen(container, topicId, onBack, onStartLesson)` | `topicId: String`, `onBack: () -> Unit`, `onStartLesson: (String, Int) -> Unit` | ключ `"topic_" + topicId`, `TopicDetailViewModelFactory(container, topicId)` | `onBack()`; `onStartLesson(topicId, minutes)` → сесія |

Ключі ViewModel видно з рядкових констант: `"word_"` (`WordDetailScreenKt`) і `"topic_"` (`TopicDetailScreenKt`);
у `WordsScreenKt` ключа немає.

---

## Прогалини

1. **Джерела smali зникли під час роботи.** Каталог `C:\...\Spain\_work\smali\` (усі 12 файлів
   `classes*_ui.txt`) перестав існувати приблизно на середині аналізу; зараз у `_work` є лише `spec/`.
   Через це частину деталей не вдалося довичитати. Усе інше в цьому файлі відновлено зі smali до його
   зникнення та з `_recon/strings_by_class.txt`, який зберігся.
2. `TopicDetailUiState`: точні **типи та порядок параметрів конструктора** і **значення за
   замовчуванням** (відомо лише: перший параметр — `loading`, назви полів — з `toString`/`copy`).
3. `TopicDetailViewModel.load()`: які саме методи `CourseRepository`/`SrsEngine` викликаються, як
   рахуються `exerciseCount`, `sentenceCount`, `listeningCount` і особливо `suggestedMinutes`
   (формула не встановлена). Наявність рядка `"word"` у константах класу лише натякає на фільтр
   карток `itemType == "word"`.
4. `WordRow` (`ui/learn/LearningComponents.kt:134`): внутрішня верстка рядка (порядок елементів,
   іконки, розміри) не досліджена — це поза межами трьох завданих екранів. Відомі лише розділювач
   `" · "` і підписи станів `"нове"`, `"у навчанні"`, `"засвоєно"`, `"важке"`, `"ще не вчилося"`.
5. Останній `item` у `WordsScreen` (`lambda-4`, `WordsScreen.kt:150`): рядкових констант немає,
   вміст не встановлено (ймовірно `Spacer`-відступ); у `TopicDetailScreen` аналогічний `lambda-4`
   (`:189`) точно `Spacer`.
6. Поріг обрізання `note.explanationUk` у граматичній картці `TopicDetailScreen` (додається `"…"`) —
   числова межа не встановлена.
7. `Level.mvpLevels` = `[A0, A1, A2]` узято з сусідньої специфікації (`spec/01_models_enums.md`,
   `spec/02_learning_engine.md`, де він перевірений по `classes13.txt:6769-6782`); у моєму дампі
   (`classes8_ui.txt`) перевірити не вдалося, бо файл зник.
8. Точні значення `Dp`-відступів (`Spacer(height = …)`, `padding(16.dp)`, `RoundedCornerShape(…)`,
   `spacedBy(…)`) зафіксовані лише там, де вони були очевидні з байт-коду (`16.dp` для padding
   карток/списків, `14.dp` для форми поля пошуку, `4.dp` під заголовком «Слова», `10.dp` між
   метриками й між елементами `LazyColumn`, `8.dp` у картці «У цій темі»); решта — не встановлені.
9. Для `Level` у чіпах рівнів: підпис = `Level.code`, але чи є на чіпі додатковий текст (напр.
   `titleUk`) — не встановлено; `Level.titleUk`/`descriptionUk` на цих трьох екранах не
   використовуються.
10. Чи використовується `WordsUiState.topicId`/`topics`/`WordsViewModel.setTopic` у якомусь іншому UI
    (наприклад, фільтр за темою з екрана теми) — у `WordsScreen` цих викликів немає, інші екрани не
    досліджувалися.
11. Стани помилок: у жодному з трьох екранів немає UI для помилки завантаження; чи є обробка винятків
    у в'юмоделях — частково не встановлено (у `WordsViewModel`/`WordDetailViewModel` `try/catch` у
    прочитаних методах не було).
