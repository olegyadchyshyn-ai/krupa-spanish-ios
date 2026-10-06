# 52. Екрани «Граматика» та «Прогрес» — точна UI/UX-специфікація

Джерела: `_recon/strings_by_class.txt` (рядкові константи за класами) та дизасембльований smali
(`classes9_ui.txt` — `ua/krupa/spanish/ui/screens/grammar/*`, `classes4_ui.txt` — `.../progress/*`,
`classes7_ui.txt` — `ua/krupa/spanish/ui/components/CommonComponentsKt`).
Номери в дужках виду `(GrammarScreen.kt:78)` — це **номери рядків оригінального Kotlin-файлу**, взяті з
compose-метаданих (`sourceInformation`, `traceEventStart`) і зі smali-таблиць `positions`/SMAP.
Порядок елементів відновлено за порядком викликів у smali та за зростанням зміщень у файлі.

---

# 1. Екран «Граматика» (`GrammarScreen.kt`)

## 1.1 Призначення

Довідник граматики: вертикальний список карток-правил (`GrammarCard`), кожна з яких містить
українське пояснення, іспанський заголовок, «закономірність» (патерн), приклади з озвученням та
підказки для україномовних. Це **не** тренувальний екран — лише перегляд і прослуховування (TTS).
Кількість тем у заголовку показує повний обсяг нотаток, а фільтр за рівнем звужує список.

## 1.2 Звідки беруться граматичні нотатки

| Шар | Файл | Поля |
|---|---|---|
| Assets (`AssetsContentSource.kt`) | `content/grammar.a0a1.json`, `content/grammar.a2.json` | — (лише назви файлів; вміст JSON у дампі відсутній) |
| DTO (`ContentPackDto.kt`) | `GrammarNoteDto` | `id`, `titleUk`, `titleEs`, `level`, `tag`, `explanationUk`, `patternUk`, `tipForUkSpeakersUk`, `commonMistakeUk`, `examples`, `orderIndex` |
| DTO прикладу (`CourseModels.kt`) | `GrammarExample` | `spanish`, `translationUk`, `noteUk` |
| Domain (`CourseModels.kt`) | `GrammarNote` | `id`, `titleUk`, `titleEs`, `level`, `tag`, `explanationUk`, `patternUk`, `tipForUkSpeakersUk`, `commonMistakeUk`, `examples`, `orderIndex` |
| БД (`ContentEntities.kt`) | `GrammarNoteEntity` | `id`, `titleUk`, `titleEs`, `levelCode`, `tagCode`, `explanationUk`, `patternUk`, `tipForUkSpeakersUk`, `commonMistakeUk`, `examples`, `orderIndex`, `contentVersion` |

- Дані на екран надходять **не** з власної в'юмоделі: `GrammarScreen` викликає `LearnViewModelFactory`
  і читає `LearnUiState.grammarNotes` (`GrammarScreen.kt:56`). `LearnUiState` (`LearnViewModel.kt`) має
  поля `loading: Boolean`, `level: Level`, `topicsByLevel: Map<Level, List<TopicSummary>>`,
  `selectedLevel: Level`, `grammarNotes: List<GrammarNote>` (+ похідні `availableLevels`, `visibleTopics`).
- `Level` (`Enums.kt`): константи `A0`, `A1`, `A2`, `B1`, `B2`, `other`; властивості `code`, `titleUk`,
  `descriptionUk`. Рядки `titleUk`/`descriptionUk`: `"Повний нуль"`, `"Перші слова, звуки, прості фрази"`,
  `"Базове спілкування"`, `"Знайомство, числа, час, прості питання"`, `"Повсякденні ситуації"`,
  `"Магазин, транспорт, здоров'я, побут"`, `"Складніша мова"`, `"Розповідь про себе, думки, плани"`,
  `"Вільніше спілкування"`, `"Аргументація, абстрактні теми, нюанси"`.
- `GrammarTag` (`Enums.kt`): `code`-константи `ARTICLES`, `COGNATES`, `COMPARATIVES`, `CONDITIONAL`,
  `DEMONSTRATIVES`, `FALSE_FRIENDS`, `FUTURE`, `GENDER_NUMBER`, `GUSTAR`, `HAY`, `IMPERATIVE`, `IMPERFECT`,
  `IR_A_INFINITIVE`, `NEGATION`, `NUMBERS`, `PERFECT`, `PERIPHRASIS`, `POLITE`, `POR_PARA`, `POSSESSIVES`,
  `PREPOSITIONS`, `PRESENT_IRREGULAR`, `PRESENT_REGULAR`, `PRETERITE`, `PRONOUNS_OBJECT`, `QUESTION_WORDS`,
  `REFLEXIVE`, `SER_ESTAR`, `SPELLING`, `SUBJUNCTIVE`, `TIME_EXPRESSIONS`, `WORD_ORDER`; рядки `titleUk`, які
  видно на картці: `"Артиклі"`, `"Ввічливість"`, `"Вказівні"`, `"Дієслово + інфінітив"`,
  `"Займенники-додатки"`, `"Заперечення"`, `"Зворотні дієслова"`, `"Майбутній час"`,
  `"Минулий час (imperfecto)"`, `"Минулий час (pretérito indefinido)"`, `"Наказовий спосіб"`,
  `"Питальні слова"`, `"Порівняння"`, `"Порядок слів"`, `"Правопис і наголос"`, `"Прийменники"`,
  `"Присвійні"`, `"Рід і число"`, `"Складений минулий (he hecho)"`, `"Схожі слова (когнати)"`,
  `"Теперішній час (неправильні)"`, `"Теперішній час (правильні)"`, `"Умовний спосіб"`,
  `"Фальшиві друзі перекладача"`, `"Час і дати"`, `"Числа"`, `"Gustar і подібні"`, `"Hay / є"`,
  `"Ir a + інфінітив (майбутнє)"`, `"Por / para"`, `"Ser / estar"`, `"Subjuntivo"`.

## 1.3 Стан екрана

| Поле | Тип | Значення за замовчуванням | Рядок / джерело |
|---|---|---|---|
| `container` | `AppContainer` | — (параметр) | `GrammarScreen.kt:54` |
| `onBack` | `() -> Unit` | — (параметр) | `GrammarScreen.kt:54` |
| `vm` | `LearnViewModel` | `viewModel(factory = LearnViewModelFactory(container))` | `GrammarScreen.kt:56` |
| `state` | `LearnUiState` | `vm.state.collectAsStateWithLifecycle()` | `GrammarScreen.kt:57` |
| `scope` | `CoroutineScope` | `rememberCoroutineScope()` | `GrammarScreen.kt:58` |
| `tts` | `SpanishTtsEngine` | `remember { container.ttsEngine }` | `GrammarScreen.kt:59` |
| `selectedLevel` | `Level?` | `null` (= «Усі») через `remember { mutableStateOf<Level?>(null) }` | `GrammarScreen.kt:60` |
| `notes` | `List<GrammarNote>` | обчислюється: `state.grammarNotes.filter { selectedLevel == null \|\| it.level == selectedLevel }.sortedWith(compareBy({ it.level }, { it.orderIndex }))` | `GrammarScreen.kt:63–68` |
| `expanded` (у кожній картці) | `Boolean` | `false` (згорнуто) через `remember { mutableStateOf(false) }` | `GrammarScreen.kt:124` |
| `text` (у лямбді озвучення) | `String` | — (аргумент `onSpeak`) | `GrammarScreen.kt:111` |

## 1.4 Структура екрана зверху вниз

| Рядок | Елемент |
|---|---|
| 54 | `fun GrammarScreen(container: AppContainer, onBack: () -> Unit)` |
| 56 | `viewModel(factory = LearnViewModelFactory(container))` → `LearnViewModel` |
| 57 | `val state by vm.state.collectAsStateWithLifecycle()` |
| 58 | `rememberCoroutineScope()` |
| 59 | `tts` (SpanishTtsEngine з `container`) |
| 60 | `var selectedLevel by remember { mutableStateOf<Level?>(null) }` |
| 62 | `if (state.loading)` → `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }` |
| 63–68 | обчислення `notes` (фільтр за рівнем + сортування за `level`, потім `orderIndex`) |
| 70 | `LazyColumn(...)` (модифікатор `fillMaxSize`, `contentPadding`; відступи між елементами — рядки 73–74) |
| 76–88 | **item 1 — хедер екрана**: `Column` |
| 78 | `TextButton` → `Icon` + `Spacer` + `Text` `"Назад"` (викликає `onBack`) |
| 79–80 | `Text` `"Граматика"` |
| 82–84 | `Text` `"Пояснення українською: не «вивчи правило», а «чому іспанці будують речення саме так». Усього тем: " + state.grammarNotes.size + "."` |
| 94–107 | **item 2 — рядок фільтра рівня**: `Row` |
| 98 | `FilterChip` `"Усі"` (selected = `selectedLevel == null`) |
| 101–104 | `Level.entries.forEach { level -> FilterChip(selected = selectedLevel == level, onClick = { selectedLevel = level }, label = { Text(level.code) }) }` |
| 111 | `items(notes, key = { it.id })` → `GrammarCard` для кожної нотатки |
| 117 | завершальний `item` зі `Spacer` (нижній відступ списку) |
| 122–218 | `GrammarCard(note, onSpeak)` — див. 1.5 |

## 1.5 `GrammarCard` — структура картки зверху вниз

`private fun GrammarCard(note: GrammarNote, onSpeak: (String) -> Unit)` (оголошення — `GrammarScreen.kt:122`).

| Рядок | Елемент |
|---|---|
| 124 | `var expanded by remember { mutableStateOf(false) }` |
| 125–131 | `Card(onClick = { expanded = !expanded }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant))` |
| 132 | тіло `Card` (лямбда-контент) |
| 133 | `Column(Modifier.padding(18.dp))` |
| 134 | `Row` — заголовковий блок |
| 135–139 | `Text(note.titleUk, style = titleMedium)` (рядки 136/138/139 — модифікатор, `maxLines`, `overflow`) |
| 142–145 | `Text("${note.titleEs} · ${note.level.code} · ${note.tag.titleUk}", style = bodySmall, color = onSurfaceVariant)` — розділювач `" · "` (пробіл-точка-пробіл) |
| 150 | `Text(if (expanded) "▴" else "▾", style = titleMedium, color = primary)` — індикатор розгортання |
| ~148–206 | `if (expanded) { … }` — розгорнутий вміст |
| 150 | `Text(note.explanationUk, style = bodyLarge)` — повне пояснення |
| 153–156 | `if (note.patternUk.isNotBlank())` → `InfoBanner("Закономірність: " + note.patternUk, containerColor = secondaryContainer, contentColor = onSecondaryContainer)` |
| 161–164 | `note.examples.forEach { example -> Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = surfaceVariant)) { … } }` |
| 167 | вміст картки прикладу: `Column` |
| 169 | `Row` (fillMaxWidth, вертикальне вирівнювання `CenterVertically`) |
| ~171–182 | `Text(example.spanish, …)` |
| 175 | `TextButton(onClick = { onSpeak(example.spanish) })` → `Icon` + `Spacer` + `Text` `"Прослухати"` |
| 182–185 | `Text(example.translationUk, …)` (184/185 — `maxLines`/`overflow`) |
| 188–191 | `if (example.noteUk.isNotBlank())` → `Row { Text(example.noteUk, …) }` |
| 199–202 | `if (note.commonMistakeUk.isNotBlank())` → `InfoBanner("Типова помилка: " + note.commonMistakeUk, containerColor = errorContainer, contentColor = onErrorContainer)` |
| ~203–206 | `if (note.tipForUkSpeakersUk.isNotBlank())` → `InfoBanner("Підказка: " + note.tipForUkSpeakersUk)` (кольори — типові для `InfoBanner`) |
| ~206–212 | `} else {` … `}` — згорнутий стан |
| 209–212 | `Text(note.explanationUk.take(140) + "…", style = bodyMedium, color = onSurfaceVariant)` (211/212 — `maxLines`/`overflow`) |

Поведінка: тап у будь-якому місці картки перемикає `expanded`; у згорнутому стані видно заголовок,
мета-рядок, індикатор `"▾"` і 140-символьний прев'ю пояснення з `"…"`; у розгорнутому — повне пояснення,
патерн, приклади, типову помилку й підказку, індикатор `"▴"`.

## 1.6 Усі видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Хедер, кнопка повернення | `"Назад"` |
| Хедер, заголовок | `"Граматика"` |
| Хедер, опис (перед числом) | `"Пояснення українською: не «вивчи правило», а «чому іспанці будують речення саме так». Усього тем: "` |
| Хедер, після числа | `"."` |
| Чип фільтра | `"Усі"` |
| Чипи рівнів | коди рівнів як є: `"A0"`, `"A1"`, `"A2"`, `"B1"`, `"B2"` (з `Level.code`) |
| Картка, розділювач мета-рядка | `" · "` |
| Картка, індикатор розгорнуто | `"▴"` |
| Картка, індикатор згорнуто | `"▾"` |
| Картка, прев'ю пояснення (згорнуто) | `"…"` (додається після `take(140)`) |
| Картка, банер патерну | `"Закономірність: "` |
| Картка, банер типової помилки | `"Типова помилка: "` |
| Картка, банер підказки | `"Підказка: "` |
| Картка прикладу, кнопка | `"Прослухати"` |
| Системний рядок (не UI) | `"No ViewModelStoreOwner was provided via LocalViewModelStoreOwner"` — технічний виняток `viewModel()`, у списку констант класу |

Тексти, що приходять з контенту (не захардкоджені на екрані): `titleUk`, `titleEs`, `explanationUk`,
`patternUk`, `tipForUkSpeakersUk`, `commonMistakeUk`, `spanish`, `translationUk`, `noteUk`,
`Level.titleUk/descriptionUk`, `GrammarTag.titleUk`.

## 1.7 Стани loading / empty / error

| Стан | Умова | Вигляд і текст |
|---|---|---|
| Loading | `state.loading == true` (`GrammarScreen.kt:62`) | `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center)` з `CircularProgressIndicator()`. Тексту немає |
| Content | `state.loading == false` | LazyColumn: хедер + чипи + картки |
| Empty (порожній список / фільтр без результатів) | `notes.isEmpty()` | Окремого порожнього стану **немає**; текст не знайдено — список просто містить лише хедер, чипи та нижній `Spacer` |
| Error | — | Окремого стану помилки **немає**; текст не знайдено. Єдиний рядок, пов'язаний з помилкою, — технічний виняток Compose `"No ViewModelStoreOwner was provided via LocalViewModelStoreOwner"` |

## 1.8 Дії користувача

| Дія | Елемент | Наслідок |
|---|---|---|
| Тап «Назад» | `TextButton` у хедері (`:78`) | `onBack()` |
| Тап чипа `"Усі"` | `FilterChip` (`:98`) | `selectedLevel = null` (фільтр вимкнено) |
| Тап чипа рівня | `FilterChip` (`:101–104`) | `selectedLevel = level`; список перераховується |
| Тап по картці | `Card(onClick = …)` (`:128`) | `expanded = !expanded` (розгортання/згортання) |
| Тап `"Прослухати"` | `TextButton` у картці прикладу (`:175`) | `onSpeak(example.spanish)` → `scope.launch { tts.speak(text) }` (TTS-озвучення іспанського тексту) |
| Скрол | `LazyColumn` (`:70`) | прокрутка списку |

---

# 2. Екран «Прогрес» (`ProgressScreen.kt`, `ProgressViewModel.kt`)

## 2.1 Призначення

Екран статистики: поточний рівень і відсоток прогресу до наступного, ключові метрики (слова, серія днів,
точність, швидкість відповіді, хвилини, спроби говоріння), стовпчикова діаграма активності за 14 днів,
слабкі теми з рівнем засвоєння та підсумкова таблиця «Знання мови». Екран **лише читає** дані —
інтерактивних елементів (кнопок, чипів, клікабельних карток) немає.

## 2.2 Стан (`ProgressViewModel` + `ProgressUiState` + `ProgressSnapshot`)

### `ProgressUiState` (`ProgressViewModel.kt`)

| Поле | Тип |
|---|---|
| `loading` | `Boolean` |
| `snapshot` | `ProgressSnapshot` (domain/repository/`ProgressRepository.kt`) |

### `ProgressViewModel`

| Член | Тип / значення |
|---|---|
| `container` | `AppContainer` (параметр конструктора) |
| `_state` | `MutableStateFlow<ProgressUiState>` |
| `state` | `StateFlow<ProgressUiState>` = `_state.asStateFlow()` |
| `init` | `viewModelScope.launch { container.progressRepository.observeSnapshot().collect { … } }` — колектить `ProgressRepository.observeSnapshot()` і оновлює `_state` (внутрішня лямбда `ProgressViewModel$1$1`) |
| `ProgressViewModelFactory(container)` | `ViewModelProvider.Factory`, створює `ProgressViewModel(container)` |

### `ProgressSnapshot` — усі поля

| Поле | Тип / примітка |
|---|---|
| `level` | `Level` (код рівня; на екрані показується `level.code` і `level.titleUk`) |
| `levelPercent` | `Int` — відсоток прогресу рівня |
| `wordsTotal` | `Int` — слів у курсі |
| `wordsStarted` | `Int` — слів почато вчити |
| `wordsMemorized` | `Int` — слів засвоєно (3+ тижні) |
| `canRecallWords` | `Int` (похідне) — слів, які реально згадуються; показується як метрика «Слів засвоєно» |
| `grammarLearned` / `grammarNotesTotal` | `Int` — опрацьовані граматичні теми / усього тем |
| `streakDays` | `Int` — серія днів |
| `retentionPercent` | `Int` — точність, % |
| `averageResponseMs` | `Int` — середній час відповіді; на екрані — через `formattedAverageResponse` |
| `formattedAverageResponse` | `String` (похідне; використовує константи `"—"` і `" с"`) |
| `totalMinutes` | `Int` — хвилин усього |
| `speakingAttempts` | `Int` — спроб говоріння |
| `reviewCount` | `Int` — усього повторень |
| `exercisesDone` | `Int` — вправ виконано |
| `listeningMinutes` | `Int` — хвилин слухання |
| `dailyStats` | `List<DailyStatEntity>` — активність за днями (`dayEpoch: Long`, `minutes: Int`, `reviews: Int`) |
| `weakSpots` | `List<WeakSpot>` — слабкі теми (`tag`, `mastery: Int`, `stat: MistakeStatEntity`, похідне `titleUk`) |
| `mistakeStats` | статистика помилок |
| `topicProgress` | прогрес за темами |
| `dueNow` | `Int` — до повторення зараз |
| `newWordsAvailable` | `Int` — доступні нові слова |
| `todayMinutes` / `todayNewWords` / `todayReviews` | `Int` — активність за сьогодні |

## 2.3 Структура екрана зверху вниз

| Рядок | Елемент |
|---|---|
| 46 | `fun ProgressScreen(container: AppContainer)` |
| 47 | `viewModel(factory = ProgressViewModelFactory(container))` → `ProgressViewModel` |
| 48 | `val state by vm.state.collectAsStateWithLifecycle()` |
| ~50–55 | `if (state.loading)` → `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }` |
| 57 | `LazyColumn(...)` (інакше — контент нижче) |
| 63–72 | **item 1 — хедер**: `Column` → `Text("Прогрес")` (headlineMedium, рядок 64), `Spacer` (65), `Text("Рівень " + level.code + " — " + level.titleUk + ". Головний показник — скільки слів ви справді згадуєте, а не скільки уроків пройдено.")` (bodyMedium, рядки 66–70) |
| 75 | **item 2 — `LevelCard(progress)`** (див. 2.4) |
| 78–92 | **item 3 — `Row` з двома `MetricCard`**: «Слів засвоєно» (`canRecallWords`, hint `"з " + wordsTotal`) та «Серія днів» (`streakDays`), кожна з `Modifier.weight(1f)` |
| 94–110 | **item 4 — `Row` з двома `MetricCard`**: «Точність» (`"$retentionPercent%"`, hint `"усі повторення"`) та «Швидкість» (`formattedAverageResponse`, hint `"середня відповідь"`) |
| 111–124 | **item 5 — `Row` з двома `MetricCard`**: «Хвилин усього» (`totalMinutes`) та «Спроб говоріння» (`speakingAttempts`) |
| 125 | **item 6 — `SectionTitle("Активність за 14 днів")`** (перед ним `Spacer`) |
| 127 | **item 7 — `ActivityChart(progress)`** (див. 2.5) |
| 130 | **item 8 — `SectionTitle("Слабкі теми")`** — лише якщо `progress.weakSpots.isNotEmpty()` |
| 133 | **item 9 — `items(weakSpots)`**: `Card(Modifier.padding(...)) { MasteryBar(titleUk = spot.titleUk, percent = spot.mastery, attempts = spot.stat.attempts) }` |
| 142 | **item 10 — `InfoBanner("Застосунок автоматично додає більше вправ на ці теми у наступних заняттях.")`** (типові кольори банера) — у тій же умові, що й слабкі теми |
| 148 | **item 11 — `SectionTitle("Знання мови")`** |
| 151–172 | **item 12 — `Card(Modifier.padding(...)) { Column { … 7 × LabeledValueRow … } }`**: «Слів у курсі» (`wordsTotal`), «Слів почато вчити» (`wordsStarted`), «Слів засвоєно (3+ тижні)» (`wordsMemorized`), «Граматичних тем опрацьовано» (`"$grammarLearned з $grammarNotesTotal"`), «Усього повторень» (`reviewCount`), «Вправ виконано» (`exercisesDone`), «Хвилин слухання» (`listeningMinutes`) — рядки 153–159 |
| 166 | **item 13 — `InfoBanner("Статистика з'явиться після першого заняття. Найкорисніше — займатися щодня хоча б 10 хвилин.")`** — лише якщо `progress.dailyStats.isEmpty()` |
| 173–174 | **item 14 — `Spacer(Modifier.height(24.dp))`** (нижній відступ списку) |
| 178–207 | `LevelCard(progress)` (приватний composable) |
| 211–249 | `ActivityChart(progress)` (приватний composable) |

## 2.4 `LevelCard` — повна структура

| Рядок | Елемент |
|---|---|
| 179 | `Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer))` |
| 183 | `Column(Modifier.padding(18.dp))` |
| 184–187 | `Text("${progress.level.code} → ${progress.levelPercent}%", style = headlineSmall, color = onSecondaryContainer)` — розділювач `" → "`, суфікс `"%"` |
| 189 | `Spacer` |
| 190–196 | `LinearProgressIndicator(progress = { levelPercent / 100f }, modifier = Modifier.fillMaxWidth().height(...), color = MaterialTheme.colorScheme.primary, trackColor = primary.copy(alpha = …), strokeCap = StrokeCap.Round)` (рядки 195/196 — висота й колір; точний коефіцієнт альфи треку не встановлено) |
| 199 | `Spacer` |
| 200–204 | `Text("Прогрес рівня рахується зі слів, які ви вже почали вчити, і граматичних тем, у яких маєте понад 60% правильних відповідей.", style = bodySmall, color = onSecondaryContainer)` |

Текстів-заголовків рівня на картці немає: показуються лише `code` і відсоток. Назва рівня
(`level.titleUk`) виводиться тільки в хедері екрана.

## 2.5 `ActivityChart` — як малюється

| Рядок | Елемент |
|---|---|
| 211 | `fun ActivityChart(progress: ProgressSnapshot)` |
| 213 | `val days = progress.dailyStats.take(14).reversed()` |
| 214 | `val maxValue = days.maxOf { it.minutes + it.reviews }.coerceAtLeast(1)` |
| 215 | `val formatter = SimpleDateFormat("dd.MM", Locale("uk", "UA"))` |
| 216–217 | `Card { Column(Modifier.padding(18.dp)) { … } }` |
| 219–222 | якщо `days.isEmpty()` → `Text("Даних ще немає", style = bodyMedium, color = onSurfaceVariant)` |
| 225 | інакше → `Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Bottom)` |
| 231 | усередині `days.forEach { day -> ActivityBar(label = formatter.format(Date(day.dayEpoch)), value = day.minutes + day.reviews, maxValue = maxValue, modifier = …) }` |
| 238 | `Spacer` |
| 239–242 | `Text("Стовпчик = хвилини заняття плюс кількість повторень за день.", style = bodySmall, color = onSurfaceVariant)` |

`ActivityBar` (`CommonComponents.kt:268`, спільний компонент):

| Аспект | Значення |
|---|---|
| Параметри | `ActivityBar(label: String, value: Int, maxValue: Int, modifier: Modifier = …)` |
| Висота стовпчика | `value * 70f / maxValue` (dp), тобто максимум 70 dp; обчислюється як `int-to-float → mul → div` |
| Контейнер | `Column` → `Box(Modifier.width(20.dp).height(70.dp))` (фіксовані 20 × 70 dp), стовпчик малюється `Canvas` |
| Підпис | під стовпчиком `Text(label)` дрібним стилем, `color = onSurfaceVariant` |
| Підказка/підпис значення | окремого тултіпа немає; значення передається лише для висоти |

Підсумок: діаграма — 14 стовпчиків (по одному на день), підписи `dd.MM` у локалі `uk-UA`,
максимум = найбільше значення `minutes + reviews` серед цих днів (мінімум 1, щоб уникнути ділення на 0).

## 2.6 Метрики: `MetricCard`, `LabeledValueRow`, `MasteryBar`

### `MetricCard` (`CommonComponents.kt:73`)

`MetricCard(labelUk: String, value: String, modifier: Modifier = …, hintUk: String? = null, accent: Color = …, icon: ImageVector? = null)`

Порядок зверху вниз: `[Icon (якщо є), tint = primary]` → `Text(labelUk, style = labelMedium, color = onSurfaceVariant)`
→ `Spacer` → `Text(value, style = headlineSmall, color = onSurface)` → `[Spacer + Text(hintUk, style = bodySmall, color = onSurfaceVariant)]`
(рядки 84–112 файлу компонента). Картка — `Card` з `containerColor = surface` і рамкою `outlineVariant`.

### `LabeledValueRow` (`CommonComponents.kt:176`)

`LabeledValueRow(labelUk: String, value: String, modifier: Modifier = …)` — рядок «підпис → значення»
(у коді екрана підпис передається як перший аргумент, значення — як другий).

### `MasteryBar` (`CommonComponents.kt:126`)

`MasteryBar(titleUk: String, percent: Int, modifier: Modifier = …, attempts: Int? = null, colorOverride: Color? = null)`

| Рядок | Елемент |
|---|---|
| 133 | `Column(Modifier.fillMaxWidth())` |
| 138–140 | `Row(Modifier.fillMaxWidth())`: `Text(titleUk, style = bodyLarge, color = onSurface)` + `Text("$percent%", style = titleSmall)`; колір відсотка: `percent >= 75` → `secondary`; `45 <= percent < 75` → `Color(0xFFB36B00)`; `percent < 45` → `error` |
| 149 | `Spacer` |
| 150–156 | `LinearProgressIndicator(progress = { percent / 100f }, modifier = Modifier.fillMaxWidth().height(...), trackColor = surfaceVariant, …)` |
| 160–164 | якщо `attempts != null` → `Spacer` + `Text("Спроб: " + attempts, style = bodySmall, color = onSurfaceVariant)` |

## 2.7 Усі видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Хедер, заголовок | `"Прогрес"` |
| Хедер, рядок рівня (початок) | `"Рівень "` |
| Хедер, розділювач | `" — "` |
| Хедер, продовження | `". Головний показник — скільки слів ви справді згадуєте, а не скільки уроків пройдено."` |
| Секція діаграми | `"Активність за 14 днів"` |
| Секція слабких тем | `"Слабкі теми"` |
| Банер під слабкими темами | `"Застосунок автоматично додає більше вправ на ці теми у наступних заняттях."` |
| Секція статистики | `"Знання мови"` |
| Банер, коли немає днів активності | `"Статистика з'явиться після першого заняття. Найкорисніше — займатися щодня хоча б 10 хвилин."` |
| Діаграма, порожній стан | `"Даних ще немає"` |
| Діаграма, легенда | `"Стовпчик = хвилини заняття плюс кількість повторень за день."` |
| Метрика 1 (підпис) | `"Слів засвоєно"` |
| Метрика 1 (підказка) | `"з "` + `wordsTotal` |
| Метрика 2 (підпис) | `"Серія днів"` |
| Метрика 3 (підпис) | `"Точність"` |
| Метрика 3 (підказка) | `"усі повторення"` |
| Метрика 4 (підпис) | `"Швидкість"` |
| Метрика 4 (підказка) | `"середня відповідь"` |
| Метрика 5 (підпис) | `"Хвилин усього"` |
| Метрика 6 (підпис) | `"Спроб говоріння"` |
| Рядок «Знання мови» 1 | `"Слів у курсі"` |
| Рядок 2 | `"Слів почато вчити"` |
| Рядок 3 | `"Слів засвоєно (3+ тижні)"` |
| Рядок 4 | `"Граматичних тем опрацьовано"` (значення `"$grammarLearned з $grammarNotesTotal"`) |
| Рядок 5 | `"Усього повторень"` |
| Рядок 6 | `"Вправ виконано"` |
| Рядок 7 | `"Хвилин слухання"` |
| `LevelCard`, головний рядок | `level.code` + `" → "` + `levelPercent` + `"%"` |
| `LevelCard`, пояснення | `"Прогрес рівня рахується зі слів, які ви вже почали вчити, і граматичних тем, у яких маєте понад 60% правильних відповідей."` |
| `MasteryBar`, підпис спроб | `"Спроб: "` + `attempts` |
| `MasteryBar`, значення | `"$percent%"` |
| `ProgressSnapshot.formattedAverageResponse` | `"—"` (коли даних немає) та суфікс `" с"` (секунди) |
| Дані днів (підписи стовпчиків) | формат `"dd.MM"`, локаль `Locale("uk", "UA")` |

## 2.8 Формати чисел, відсотків, часу

| Показник | Формат | Приклад вигляду |
|---|---|---|
| Слова, серія днів, повторення, вправи, хвилини, спроби | ціле число як є (`Int.toString()`), без одиниць — одиниця винесена в підпис (`"Хвилин усього"`, `"Хвилин слухання"`) | `"120"`, `"3"` |
| Точність | `"$retentionPercent%"` | `"78%"` |
| Прогрес рівня (`LevelCard`) | `"${level.code} → ${levelPercent}%"` | `"A2 → 45%"` |
| Майстерність слабкої теми | `"$percent%"` | `"62%"` |
| Граматичні теми | `"$grammarLearned з $grammarNotesTotal"` | `"12 з 40"` |
| Слова засвоєно (метрика) | значення — ціле число, підказка `"з $wordsTotal"` | `"120"` + `"з 900"` |
| Середня відповідь | `ProgressSnapshot.formattedAverageResponse`; при відсутності даних — `"—"`, інакше число + `" с"` | `"—"` / `"2.4 с"` (точне округлення не встановлено) |
| Підписи днів у діаграмі | `SimpleDateFormat("dd.MM", Locale("uk", "UA"))` | `"05.03"` |
| Форми множини | **відсутні** — у GrammarScreen/ProgressScreen немає жодного рядка з плюралізацією чи `pluralStringResource`; усі підписи в однині/іменникові без числа | — |
| Плейсхолдери `%s`/`%d`/`%.1f` | **у цих екранах не використовуються**: усі рядки склеюються конкатенацією (`StringBuilder.append`), відсоток — літерал `"%"` | — |

## 2.9 Стани loading / empty / error

| Стан | Умова | Вигляд і текст |
|---|---|---|
| Loading | `state.loading == true` | `Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center)` з `CircularProgressIndicator()`; тексту немає |
| Content | `state.loading == false` | `LazyColumn` з 14 елементами (див. 2.3) |
| Empty — немає активності | `progress.dailyStats.isEmpty()` | `InfoBanner` `"Статистика з'явиться після першого заняття. Найкорисніше — займатися щодня хоча б 10 хвилин."` |
| Empty — немає слабких тем | `progress.weakSpots.isEmpty()` | Секція `"Слабкі теми"`, картки `MasteryBar` і банер `"Застосунок автоматично додає більше вправ на ці теми у наступних заняттях."` **не показуються** (жодного тексту-замінника немає) |
| Empty — діаграма | `days.isEmpty()` (у `ActivityChart`) | `Text("Даних ще немає")` |
| Error | — | Окремого стану помилки **немає**; текст не знайдено |

## 2.10 Дії користувача

| Дія | Елемент | Наслідок |
|---|---|---|
| Скрол сторінки | `LazyColumn` (`:57`) | прокрутка списку |
| Інших дій немає | — | на екрані відсутні кнопки, чипи, клікабельні картки та посилання; `Card`, `MetricCard`, `LabeledValueRow`, `MasteryBar`, `InfoBanner`, `SectionTitle` викликані в неінтерактивних перевантаженнях |

---

## Прогалини

1. **Вміст JSON** `grammar.a0a1.json` / `grammar.a2.json` — у дампі є лише назви файлів; перелік полів
   наведено за `GrammarNoteDto`, а не за реальними JSON-ключами.
2. **Порівняння `Level.code` → `Level.titleUk`/`descriptionUk`** не встановлено: у дампі рядкових
   констант перелік відсортовано за абеткою, прив'язки до конкретного рівня немає.
3. **Порівняння `GrammarTag.code` → `titleUk`** (32 теги) також не встановлено з тієї ж причини;
   наведено лише повний перелік рядків.
4. **Точні значення відступів/розмірів**: `contentPadding` і `verticalArrangement` (spacedBy) `LazyColumn`
   у GrammarScreen (рядки 73–74), висота треку `LinearProgressIndicator` у `LevelCard`, значення
   `Spacer` у хедері `"Прогрес"` — не витягнуті (dp-константи не потрапили у вибірку smali).
5. **Формат `ProgressSnapshot.formattedAverageResponse`**: точно відомі лише константи `"—"` і `" с"`;
   як саме округлюється число (скільки знаків, чи ділиться на 1000) — не встановлено (клас
   `ProgressRepository.kt` не входив у витягнутий smali).
6. **Колір стовпчика `ActivityBar`** (який саме `colorScheme`-колір заливається на `Canvas`) і точний
   стиль підпису дати — не підтверджено; так само не встановлено, чи є в `ActivityBar` семантичний
   `contentDescription`.
7. **Дефолтні значення `ProgressUiState(loading = …, snapshot = …)`** і точний вміст оновлення стану в
   `ProgressViewModel$1$1` (очікувано `loading = false`, `snapshot = …`) — не підтверджено: відповідні
   рядки smali стали недоступні (каталог `_work\smali` було видалено під час роботи).
8. **Колірна пара банера `"Підказка: "`** у `GrammarCard` — явні кольори в байткоді не передаються
   (тобто типові для `InfoBanner`), але самі дефолтні кольори `InfoBanner` не перевірялися.
9. **Точний склад аргументів першого чипа** (`"Усі"`): `onClick` викликає сетер із константою; за
   логікою фільтра це `selectedLevel = null`, проте пряме значення константи в байткоді не зчитано.
10. **Індикатор `"▴"`/`"▾"`**: за метаданими групи він лежить поза групою заголовкового `Row` (рядки 134–145),
    тобто формально є наступним елементом `Column`; остаточне розташування (праворуч від заголовка чи
    рядком нижче) з байткоду однозначно не встановлено.
11. **Локалізаційні ресурси**: усі тексти знайдено як рядкові константи в класах, тому невідомо, чи
    частина з них дублюється в `strings.xml` (окремого ресурсного дампу не було).
