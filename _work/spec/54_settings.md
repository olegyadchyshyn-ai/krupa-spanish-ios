# 54. Екран налаштувань (`SettingsScreen.kt`, `SettingsViewModel.kt`)

Джерела: baksmali-дизасембль `SettingsScreenKt` (+ 21 лямбда-сінглтон і ~45 вкладених лямбд), `SettingsViewModel`, `SettingsUiState`,
`commonComponents/NavigationComponentsKt` (`SectionTitle`, `InfoBanner`, `LabeledValueRow`, `ChoiceChipsRow`),
`domain/model/{UserProfile,Level,LearningGoal,ThemeMode}`, `speech/tts/TtsState`, `data/transfer/ProgressTransfer`.

Екран — одна вертикальна `Column` зі `verticalScroll` (без `Scaffold`, без `TopAppBar`, без `LazyColumn`), 6 секцій-`Card`.
Довжина вихідного файлу — 472 рядки; `SettingsScreen` оголошено на рядку 66.

---

## 1. `SettingsUiState` — повний перелік полів

Порядок полів — як у конструкторі класу; значення за замовчуванням узято з синтетичного конструктора
`SettingsUiState(...I DefaultConstructorMarker)` (усі 12 бітів маски = 1, тобто `SettingsUiState()`).

| Поле | Тип | Призначення | Значення за замовчуванням |
|---|---|---|---|
| `loading` | `Boolean` | Поки `true` — екран показує лише `CircularProgressIndicator` (рядки 94–96) | `true` |
| `profile` | `UserProfile` | Профіль користувача (усі налаштування зберігаються тут) | `UserProfileKt.defaultProfile()` = `UserProfile()` |
| `ttsState` | `TtsState` | Стан синтезу мовлення (голоси, стать, швидкість, готовність) | `TtsState()` |
| `contentCounts` | `String` | Рядок зі зведенням контенту (з налаштування `content_counts`) | `""` |
| `contentIssues` | `List<String>` | Значення налаштувань із ключів `content_issue_*` (проблеми контенту) | `emptyList()` |
| `exportMessage` | `String?` | Повідомлення після експорту (банер) | `null` |
| `importMessage` | `String?` | Повідомлення після імпорту, скидання, перезавантаження контенту (банер) | `null` |
| `busy` | `Boolean` | Триває експорт/імпорт/перезавантаження → рядок «Працюю…» | `false` |
| `wordCount` | `Int` | Слів у курсі (`courses.allWords().size`) | `0` |
| `cardCount` | `Int` | Карток у пам'яті (`srsEngine.allCards().size`) | `0` |
| `speechAvailable` | `Boolean` | Чи доступне розпізнавання мовлення | `false` |
| `speechModelLanguage` | `String` | Назва мовної моделі (на екрані **не використовується**, лише тримається у стані) | `"іспанська (es-ES)"` |

**Дефолти `UserProfile`** (`UserProfile(...)` — синтетичний конструктор, `UserProfile.kt`, рядки 9–24):

| Поле | Тип | За замовчуванням |
|---|---|---|
| `name` | `String` | `""` |
| `level` | `Level` | `Level.A0` |
| `assessmentDone` | `Boolean` | `false` |
| `assessmentScore` | `Int` | `0` |
| `goal` | `LearningGoal` | `LearningGoal.TRAVEL` |
| `dailyMinutes` | `Int` | `20` |
| `startedAt` | `Long` | `System.currentTimeMillis()` |
| `themeMode` | `ThemeMode` | `ThemeMode.SYSTEM` |
| `ttsVoiceGender` | `String` | `"female"` |
| `ttsRate` | `Float` | `1.0f` |
| `showListeningHints` | `Boolean` | `false` |
| `allowExternalAi` | `Boolean` | `false` |
| `aiProviderId` | `String` | `"local"` |
| `aiEndpoint` | `String` | `""` |
| `aiApiKey` | `String` | `""` |
| `aiModel` | `String` | `""` |

Обчислювана властивість `UserProfile.dailyMinutesOptions` = `listOf(10, 20, 30, 45, 60)` (`UserProfile.kt`, рядок 26).

**Дефолти `TtsState`** (`TtsState()`, `SpanishTtsEngine.kt`, рядки 201–213): `ready = false`, `spanishAvailable = false`,
`hasFemaleVoice = true`, `hasMaleVoice = false`, `selectedGender = VoiceGender.FEMALE`, `rate = 1.0f`,
`femaleVoiceName = null`, `maleVoiceName = null`, `error = null`.

---

## 2. `SettingsViewModel` — усі дії

Конструктор `SettingsViewModel(container: AppContainer)` (рядок 41); поля `_state: MutableStateFlow<SettingsUiState>`,
`state: StateFlow<SettingsUiState>`. У `init` запускаються 3 корутини-колектори:

| # | Джерело | Що робить | Рядки |
|---|---|---|---|
| 1 | `users.observeProfile()` | `state = state.copy(profile = value)` | 47–51 |
| 2 | `ttsEngine.state` (`TtsState`) | `state = state.copy(ttsState = value)` | 52–56 |
| 3 | `users.setting("content_counts")`, `users.allSettings()`, `courses.allWords()`, `srsEngine.allCards()`, `speechRecognizer.isAvailable` | `copy(contentCounts = counts ?: "", contentIssues = усі значення ключів, що починаються з "content_issue_", wordCount = allWords().size, cardCount = allCards().size, speechAvailable = isAvailable)` | 57–69 |

| Метод | Параметри | Що робить | Вплив на стан / побічні ефекти |
|---|---|---|---|
| `update` (private) | `transform: (UserProfile) -> UserProfile` | Бере `state.profile`, застосовує `transform`, зберігає результат | `users.saveProfile(updated)` (Room); рядки 73–77. Через нього проходять УСІ сеттери нижче |
| `setName` | `value: String` | `copy(name = value)` (без `trim()`) | запис у профіль; рядок 79 |
| `setLevel` | `level: Level` | `copy(level = level)` | запис у профіль; рядок 81 |
| `setGoal` | `goal: LearningGoal` | `copy(goal = goal)` | запис у профіль; рядок 83 |
| `setDailyMinutes` | `minutes: Int` | `copy(dailyMinutes = minutes)` | запис у профіль; рядок 85 |
| `setTheme` | `mode: ThemeMode` | `copy(themeMode = mode)` | запис у профіль (тема застосунку); рядок 87 |
| `setVoiceGender` | `gender: VoiceGender` | `ttsEngine.setVoiceGender(gender)` + `copy(ttsVoiceGender = gender.code)` (`"female"`/`"male"`) | запис у профіль + одразу в TTS-рушій; рядки 90–92 |
| `setRate` | `rate: Float` | `ttsEngine.setRate(rate)` + `copy(ttsRate = rate)` | запис у профіль + одразу в TTS-рушій; рядки 95–97 |
| `setListeningHints` | `enabled: Boolean` | `copy(showListeningHints = enabled)` | запис у профіль; рядок 99 |
| `setAllowExternalAi` | `allowed: Boolean` | `copy(allowExternalAi = allowed)` | запис у профіль; рядок 101 |
| `setAiProvider` | `providerId: String` | `copy(aiProviderId = providerId)` | запис у профіль; рядок 103 |
| `setAiEndpoint` | `endpoint: String` | `copy(aiEndpoint = endpoint.trim())` | запис у профіль; рядок 105 |
| `setAiApiKey` | `key: String` | `copy(aiApiKey = key.trim())` | запис у профіль; рядок 107 |
| `setAiModel` | `model: String` | `copy(aiModel = model.trim())` | запис у профіль; рядок 109 |
| `testVoice` | — | `ttsEngine.speak("Hola. Me llamo Ana. ¿Qué tal?")` у `viewModelScope` | НЕ змінює стан; озвучує тестову фразу; рядки 112–116 |
| `exportProgress` | — | `copy(busy = true, exportMessage = null)` → `progressTransfer.exportToFile()` → `copy(busy = false, exportMessage = report.messageUk)` | Пише файл JSON у «Завантаження» / папку застосунку; рядки 120–125 |
| `importProgress` | `text: String, replaceExisting: Boolean` | `copy(busy = true, importMessage = null)` → `progressTransfer.importFromText(text, replaceExisting)` → `copy(busy = false, importMessage = report.messageUk)` | Запис у БД (профіль/картки/статистика/помилки); рядки 129–134 |
| `clearMessages` | — | `copy(exportMessage = null, importMessage = null)` | **На екрані не викликається** (мертвий публічний API); рядки 137–138 |
| `resetProgress` | — | `users.clearProgress()` → `copy(importMessage = "Прогрес очищено. Контент курсу залишився.")` | Видаляє картки/статистику/помилки/діалоги з БД; `busy` не змінюється; рядки 142–146 |
| `reloadContent` | — | `copy(busy = true)` → `contentSeeder.seedIfNeeded(force = true)` → `copy(busy = false, importMessage = "Контент перезавантажено з файлів застосунку.", wordCount = courses.allWords().size)` | Перезаливає контент курсу з JSON-файлів застосунку; рядки 149–158 |
| `getState` | — | повертає `state: StateFlow<SettingsUiState>` | рядок 44 |
| `SettingsViewModelFactory.create` | `modelClass: Class<T>` | `SettingsViewModel(container)` | — |

---

## 3. Структура екрана зверху вниз

Порядок відновлено за номерами рядків вихідного файлу з `positions`-таблиць smali (усі посилання виду `(SettingsScreen.kt:NNN)`).

1. **рядки 68–74 — стан екрана:** `viewModel = viewModel(factory = SettingsViewModelFactory(container))` (68),
   `state by viewModel.state.collectAsStateWithLifecycle()` (69), `context = LocalContext.current` (70),
   `showResetDialog = remember { mutableStateOf(false) }` (72), `showImportDialog = remember { mutableStateOf(false) }` (73),
   `pendingImport: MutableState<String?>` (74).
2. **рядки 76–92 — `filePicker`**: `rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument())` (76–77);
   callback: `runCatching { context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() } }.getOrNull()`
   → якщо текст не `null`: `pendingImport = text` (86) і `showImportDialog = true` (87); якщо читання не вдалося:
   `viewModel.importProgress("", false)` (89).
3. **рядки 94–96 — стан завантаження:** `if (state.loading) { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() } ; return }`.
4. **рядки 101–106 — коренева `Column`:** `Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)`,
   `verticalArrangement = Arrangement.spacedBy(12.dp)`, `horizontalAlignment = Alignment.Start`.
   1. **рядок 108** — `TextButton` «`Назад`» (`onClick = onBack`, `ComposableSingletons$SettingsScreenKt.lambda-1`).
   2. **рядок 114** — `Text("Налаштування", style = MaterialTheme.typography.headlineMedium)`.
   3. **рядок 117** — `SectionTitle("Профіль")`.
   4. **рядки 118–169** — `Card(Modifier.fillMaxWidth())` — секція **Профіль**:
      1. **рядки 120–127** — `OutlinedTextField` (`label = { Text("Ім'я (необов'язково)") }`, `singleLine = true`, `Modifier.fillMaxWidth()`, `onValueChange = viewModel::setName`).
      2. **рядок 129** — `Text("Рівень")`.
      3. **рядки 130–138** — `Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top)` → `Level.mvpLevels.forEach { level -> FilterChip(...) }` (3 чипи: A0, A1, A2).
      4. **рядок 139** — `Text(profile.level.descriptionUk, style = bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)`.
      5. **рядок 145** — `Text("Ціль навчання")`.
      6. **рядки 146–154** — контейнер `Column` (див. Прогалини) → `LearningGoal.entries.forEach { goal -> FilterChip(...) }` (5 чипів).
      7. **рядок 156** — `Text("Час на день")`.
      8. **рядок 157** — `ChoiceChipsRow(options = profile.dailyMinutesOptions, selected = profile.dailyMinutes, label = { it.toString() }, onSelect = viewModel::setDailyMinutes)` (компонент `NavigationComponentsKt.ChoiceChipsRow`).
      9. **рядки 163–164** — `TextButton("Пройти тест рівня ще раз", onClick = onOpenOnboarding)`.
   5. **рядок 171** — `SectionTitle("Вигляд")`.
   6. **рядки 172–186** — `Card` — секція **Вигляд**:
      1. **рядок 174** — `Text("Тема оформлення")`.
      2. **рядки 175–182** — `Row(spacedBy, Alignment.Top)` → `ThemeMode.entries.forEach { mode -> FilterChip(label = { Text(mode.titleUk) }) }` (3 чипи).
   7. **рядок 188** — `SectionTitle("Аудіо та вимова")`.
   8. **рядки 189–261** — `Card` — секція **Аудіо та вимова**:
      1. **рядки 191–192** — `if (!state.ttsState.spanishAvailable) InfoBanner("У системі немає іспанського голосу для синтезу мовлення. Встановіть його: Налаштування Android → Система → Мови та введення → Синтез мовлення → іспанська.")`.
      2. **рядок 201** — `Text("Голос")`.
      3. **рядки 202–208** — `Row(spacedBy, Alignment.Top)` → `VoiceGender.entries.forEach { gender -> FilterChip(selected = ttsState.selectedGender == gender, onClick = { viewModel.setVoiceGender(gender) }, label = { Text(gender.titleUk) }) }` (2 чипи).
      4. **рядки 211–212** — `if (ttsState.selectedGender == VoiceGender.MALE && !ttsState.hasMaleVoice) InfoBanner("Чоловічий голос на цьому пристрої недоступний — використовується жіночий.")`.
      5. **рядок 219** — `Text("Швидкість")`.
      6. **рядки 221–227** — `Row` → `listOf(0.75f, 1.0f, 1.25f).forEach { rate -> FilterChip(selected = abs(ttsState.rate - rate) < 0.01f, onClick = { viewModel.setRate(rate) }, label = { Text(if (rate == 1f) "1×" else "$rate×") }) }` (3 чипи).
      7. **рядки 230–232** — `OutlinedButton("Перевірити голос", onClick = viewModel::testVoice, modifier = fillMaxWidth)`.
      8. **рядки 241–252** — `Column` з `Text("Показувати переклад під час слухання")` (242) + `Text("Корисно на початку, заважає згодом")` (243, `bodySmall`, `onSurfaceVariant`) і `Switch(checked = profile.showListeningHints, onCheckedChange = viewModel::setListeningHints)` (249–251).
      9. **рядки 255–258** — `LabeledValueRow("Розпізнавання мовлення", if (state.speechAvailable) "доступне" else "недоступне")`.
   9. **рядок 263** — `SectionTitle("AI-викладач")`.
   10. **рядки 264–337** — `Card` — секція **AI-викладач**:
       1. **рядок 266** — `InfoBanner("У цій версії працює локальний викладач: діалоги, рольові ситуації й розбір помилок — усе на пристрої, без інтернету.")`.
       2. **рядок 271** — `Text("Провайдер")`.
       3. **рядки 272–280** — `Row(spacedBy, Alignment.Top)` → `container.aiProviders.all().forEach { provider -> FilterChip(selected = profile.aiProviderId == provider.id, onClick = { viewModel.setAiProvider(provider.id) }, label = { Text(provider.titleUk) }) }`.
       4. **рядки 287–298** — `Column` з `Text("Дозволити зовнішні AI-сервіси")` (288) + `Text("Якщо увімкнено, ваші тексти й записи можуть надсилатися на вибраний сервіс. Ключі не зашиті в застосунок — їх вводите ви.")` (289) і `Switch(checked = profile.allowExternalAi, onCheckedChange = viewModel::setAllowExternalAi)` (296–298).
       5. **рядки 302–329** — `if (profile.allowExternalAi) { … }`:
          - **303–311** — `OutlinedTextField(value = profile.aiEndpoint, onValueChange = viewModel::setAiEndpoint, label = { Text("Адреса API (endpoint)") }, placeholder = { Text("https://api.example.com/v1/chat/completions") }, singleLine = true)`;
          - **312–319** — `OutlinedTextField(value = profile.aiApiKey, onValueChange = viewModel::setAiApiKey, label = { Text("Ваш API-ключ") }, singleLine = true)`;
          - **320–326** — `OutlinedTextField(value = profile.aiModel, onValueChange = viewModel::setAiModel, label = { Text("Модель") }, singleLine = true)`;
          - **327–329** — `InfoBanner("Мережеві провайдери з'являться в наступних версіях. Зараз ці поля зберігаються локально, щоб ви могли підготувати налаштування заздалегідь.")`.
   11. **рядок 339** — `SectionTitle("Дані та перенесення")`.
   12. **рядки 340–380** — `Card` — секція **Дані та перенесення**:
       1. **рядки 342–347** — `Text("Прогрес зберігається лише на цьому пристрої. Щоб перенести навчання на інший телефон, збережіть файл JSON і відкрийте його там.", bodySmall, onSurfaceVariant)`.
       2. **рядки 349–351** — `Button("Експортувати прогрес у JSON", onClick = viewModel::exportProgress, modifier = fillMaxWidth)`.
       3. **рядки 355–358** — `OutlinedButton("Імпортувати прогрес з файлу", onClick = { filePicker.launch(arrayOf("application/json", "text/plain", "*/*")) }, modifier = fillMaxWidth)`.
       4. **рядок 364** — `state.exportMessage?.let { InfoBanner(it) }`.
       5. **рядок 365** — `state.importMessage?.let { InfoBanner(it) }`.
       6. **рядки 367–371** — `if (state.busy) Row(verticalAlignment = Alignment.CenterVertically) { CircularProgressIndicator(); Spacer; Text("Працюю…") }`.
       7. **рядки 374–375** — `OutlinedButton("Очистити весь прогрес", onClick = { showResetDialog = true }, modifier = fillMaxWidth)`.
   13. **рядок 382** — `SectionTitle("Діагностика")`.
   14. **рядки 383–416** — `Card` — секція **Діагностика**:
       1. **рядок 385** — `LabeledValueRow("Слів у курсі", state.wordCount.toString())`.
       2. **рядок 386** — `LabeledValueRow("Карток у пам'яті", state.cardCount.toString())`.
       3. **рядки 387–388** — `if (state.contentCounts.isNotBlank()) LabeledValueRow("Контент", state.contentCounts)`.
       4. **рядок 390** — `LabeledValueRow("Розпізнавання мовлення", if (state.speechAvailable) "є" else "немає")`.
       5. **рядок 391** — `LabeledValueRow("Синтез мовлення", if (state.ttsState.ready) "готовий" else "не готовий")`.
       6. **рядки 392–395** — `LabeledValueRow("Доступні голоси", buildString { if (hasFemaleVoice) append("жіночий"); if (hasMaleVoice) append(" + чоловічий") }.ifBlank { "—" })`.
       7. **рядки 397–401** — `if (state.contentIssues.isNotEmpty()) { Spacer(Modifier.height(8.dp)); InfoBanner("Проблеми контенту: " + state.contentIssues.joinToString("; "), containerColor = colorScheme.errorContainer, contentColor = colorScheme.onErrorContainer) }`.
       8. **рядки 405–407** — `Spacer` + `OutlinedButton("Перезавантажити контент курсу", onClick = viewModel::reloadContent, modifier = fillMaxWidth)`.
       9. **рядок 410** — `Text("Корисно після оновлення застосунку: контент перезалиється, а прогрес і картки залишаються.", bodySmall, onSurfaceVariant)`.
   15. **рядок 419** — `Spacer(Modifier.height(30.dp))`.
5. **рядки 422–443** — `if (showResetDialog) AlertDialog(…)` — діалог скидання прогресу (див. §5.1).
6. **рядки 444–468** — `if (showImportDialog && pendingImport != null) AlertDialog(…)` — діалог вибору режиму імпорту (див. §5.2).

---

## 4. Усі видимі тексти (дослівно)

### 4.0. Каркас екрана

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка | Значення/варіанти |
|---|---|---|---|---|
| Кнопка повернення | `TextButton` | `"Назад"` | — | `onClick = onBack` (рядок 108) |
| Заголовок екрана | `Text` (`headlineMedium`) | `"Налаштування"` | — | рядок 114 |
| Плейсхолдер завантаження | `Box` + `CircularProgressIndicator` | текст не знайдено | — | рядки 94–96 |

### 4.1. Секція `"Профіль"` (Card, рядки 118–169)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка (дослівно) | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"Профіль"` | — | рядок 117 |
| Ім'я | `OutlinedTextField` (`singleLine = true`) | мітка: `"Ім'я (необов'язково)"` | placeholder відсутній | `profile.name` (за замовчуванням `""`); запис без `trim()` |
| Рівень — підпис | `Text` | `"Рівень"` | — | рядок 129 |
| Рівень — вибір | `FilterChip` × `Level.mvpLevels` | текст чипа = `level.code` | під чипами — `Text(profile.level.descriptionUk)` (`bodySmall`, `onSurfaceVariant`) | `A0` → `"Повний нуль"` / `"Перші слова, звуки, прості фрази"`; `A1` → `"Базове спілкування"` / `"Знайомство, числа, час, прості питання"`; `A2` → `"Повсякденні ситуації"` / `"Магазин, транспорт, здоров'я, побут"`. У чипах — лише коди `A0`, `A1`, `A2` (MVP-рівні); `B1` (`"Вільніше спілкування"` / `"Розповідь про себе, думки, плани"`) і `B2` (`"Складніша мова"` / `"Аргументація, абстрактні теми, нюанси"`) у чипах не показуються |
| Ціль навчання — підпис | `Text` | `"Ціль навчання"` | — | рядок 145 |
| Ціль навчання — вибір | `FilterChip` × `LearningGoal.entries` | текст чипа = `goal.titleUk` | — | `"Подорожі"` (TRAVEL / `travel` / `"Розмови в аеропорту, готелі, кафе, на вулиці"`), `"Робота"` (WORK / `work` / `"Ділове листування, зустрічі, професійна лексика"`), `"Навчання"` (STUDY / `study` / `"Іспити, університет, сертифікати DELE"`), `"Переїзд"` (RELOCATION / `relocation` / `"Побут, документи, оренда житла, лікарі"`), `"Спілкування"` (COMMUNICATION / `communication` / `"Друзі, серіали, музика, інтернет"`) |
| Час на день — підпис | `Text` | `"Час на день"` | — | рядок 156 |
| Час на день — вибір | `ChoiceChipsRow` (`NavigationComponentsKt`) | текст чипа = `minutes.toString()` (без одиниць) | — | `10`, `20`, `30`, `45`, `60` (`profile.dailyMinutesOptions`); за замовчуванням `20` |
| Повторний тест рівня | `TextButton` | `"Пройти тест рівня ще раз"` | — | `onClick = onOpenOnboarding` (рядок 164) |

### 4.2. Секція `"Вигляд"` (Card, рядки 172–186)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"Вигляд"` | — | рядок 171 |
| Тема оформлення — підпис | `Text` | `"Тема оформлення"` | — | рядок 174 |
| Тема оформлення — вибір | `FilterChip` × `ThemeMode.entries` | текст чипа = `mode.titleUk` | — | `"Як у системі"` (SYSTEM / `system`, за замовчуванням), `"Світла"` (LIGHT / `light`), `"Темна"` (DARK / `dark`) |

### 4.3. Секція `"Аудіо та вимова"` (Card, рядки 189–261)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка (дослівно) | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"Аудіо та вимова"` | — | рядок 188 |
| Немає іспанського голосу | `InfoBanner` (показується, якщо `!ttsState.spanishAvailable`) | `"У системі немає іспанського голосу для синтезу мовлення. Встановіть його: Налаштування Android → Система → Мови та введення → Синтез мовлення → іспанська."` | — | рядок 192 |
| Голос — підпис | `Text` | `"Голос"` | — | рядок 201 |
| Голос — вибір | `FilterChip` × `VoiceGender.entries` | текст чипа = `gender.titleUk` | — | `"Жіночий голос"` (FEMALE / `female`, за замовчуванням), `"Чоловічий голос"` (MALE / `male`) |
| Чоловічий голос недоступний | `InfoBanner` (якщо обрано MALE і `!hasMaleVoice`) | `"Чоловічий голос на цьому пристрої недоступний — використовується жіночий."` | — | рядок 212 |
| Швидкість — підпис | `Text` | `"Швидкість"` | — | рядок 219 |
| Швидкість — вибір | `FilterChip` × `listOf(0.75f, 1.0f, 1.25f)` | текст чипа = `"1×"` для `1.0f`, інакше `"$rate×"` (тобто `"0.75×"`, `"1.25×"`) | вибраний, якщо `abs(ttsState.rate - rate) < 0.01f` | `0.75×`, `1×`, `1.25×`; за замовчуванням `1.0` |
| Перевірка голосу | `OutlinedButton` (fillMaxWidth) | `"Перевірити голос"` | — | озвучує фразу `"Hola. Me llamo Ana. ¿Qué tal?"`; рядок 230 |
| Переклад під час слухання | `Switch` + два `Text` | `"Показувати переклад під час слухання"` | `"Корисно на початку, заважає згодом"` | `profile.showListeningHints` (за замовчуванням `false`) |
| Розпізнавання мовлення | `LabeledValueRow` | `"Розпізнавання мовлення"` | — | `"доступне"` / `"недоступне"` |

### 4.4. Секція `"AI-викладач"` (Card, рядки 264–337)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка (дослівно) | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"AI-викладач"` | — | рядок 263 |
| Пояснення | `InfoBanner` | `"У цій версії працює локальний викладач: діалоги, рольові ситуації й розбір помилок — усе на пристрої, без інтернету."` | — | рядок 266 |
| Провайдер — підпис | `Text` | `"Провайдер"` | — | рядок 271 |
| Провайдер — вибір | `FilterChip` × `aiProviders.all()` | текст чипа = `provider.titleUk` (значення постачає `AIProviderRegistry`) | — | вибір за `profile.aiProviderId == provider.id`; за замовчуванням `"local"` |
| Дозвіл зовнішніх сервісів | `Switch` + два `Text` | `"Дозволити зовнішні AI-сервіси"` | `"Якщо увімкнено, ваші тексти й записи можуть надсилатися на вибраний сервіс. Ключі не зашиті в застосунок — їх вводите ви."` | `profile.allowExternalAi` (за замовчуванням `false`) |
| Адреса API (показується лише якщо дозвіл увімкнено) | `OutlinedTextField` (`singleLine = true`) | мітка: `"Адреса API (endpoint)"` | placeholder: `"https://api.example.com/v1/chat/completions"` | `profile.aiEndpoint` (`""`); зберігається з `trim()` |
| API-ключ (лише якщо дозвіл увімкнено) | `OutlinedTextField` (`singleLine = true`) | мітка: `"Ваш API-ключ"` | placeholder відсутній; поле **не** маскується (`VisualTransformation` не задано) | `profile.aiApiKey` (`""`); зберігається з `trim()` |
| Модель (лише якщо дозвіл увімкнено) | `OutlinedTextField` (`singleLine = true`) | мітка: `"Модель"` | placeholder відсутній | `profile.aiModel` (`""`); зберігається з `trim()` |
| Пояснення під полями | `InfoBanner` | `"Мережеві провайдери з'являться в наступних версіях. Зараз ці поля зберігаються локально, щоб ви могли підготувати налаштування заздалегідь."` | — | рядок 328 |

### 4.5. Секція `"Дані та перенесення"` (Card, рядки 340–380)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка (дослівно) | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"Дані та перенесення"` | — | рядок 339 |
| Пояснення | `Text` (`bodySmall`, `onSurfaceVariant`) | `"Прогрес зберігається лише на цьому пристрої. Щоб перенести навчання на інший телефон, збережіть файл JSON і відкрийте його там."` | — | рядок 342 |
| Експорт | `Button` (fillMaxWidth) | `"Експортувати прогрес у JSON"` | — | `onClick = viewModel::exportProgress`; рядок 349 |
| Імпорт | `OutlinedButton` (fillMaxWidth) | `"Імпортувати прогрес з файлу"` | — | `onClick = filePicker.launch(arrayOf("application/json", "text/plain", "*/*"))`; рядки 355–358 |
| Повідомлення експорту | `InfoBanner` (умовно) | текст береться зі стану `exportMessage` (див. §6) | — | рядок 364 |
| Повідомлення імпорту | `InfoBanner` (умовно) | текст береться зі стану `importMessage` (див. §6) | — | рядок 365 |
| Індикатор роботи | `CircularProgressIndicator` + `Spacer` + `Text` | `"Працюю…"` | — | показується, коли `state.busy == true`; рядки 367–371 |
| Скидання прогресу | `OutlinedButton` (fillMaxWidth) | `"Очистити весь прогрес"` | — | `onClick = { showResetDialog = true }`; рядок 375 |

### 4.6. Секція `"Діагностика"` (Card, рядки 383–416)

| Елемент | Тип контрола | Підпис (дослівно) | Додатковий опис/підказка (дослівно) | Значення/варіанти |
|---|---|---|---|---|
| Заголовок секції | `SectionTitle` | `"Діагностика"` | — | рядок 382 |
| Слова | `LabeledValueRow` | `"Слів у курсі"` | — | `state.wordCount` |
| Картки | `LabeledValueRow` | `"Карток у пам'яті"` | — | `state.cardCount` |
| Контент | `LabeledValueRow` (умовно, лише якщо `contentCounts` не порожній) | `"Контент"` | — | `state.contentCounts` |
| Розпізнавання | `LabeledValueRow` | `"Розпізнавання мовлення"` | — | `"є"` / `"немає"` |
| Синтез | `LabeledValueRow` | `"Синтез мовлення"` | — | `"готовий"` / `"не готовий"` |
| Голоси | `LabeledValueRow` | `"Доступні голоси"` | — | `"жіночий"`, `" + чоловічий"`, `"жіночий + чоловічий"`; якщо порожньо — `"—"` |
| Проблеми контенту | `InfoBanner` у кольорах помилки (`errorContainer` / `onErrorContainer`) | `"Проблеми контенту: "` + `contentIssues.joinToString("; ")` | — | показується лише якщо список непорожній; рядки 397–401 |
| Перезавантаження | `OutlinedButton` (fillMaxWidth) | `"Перезавантажити контент курсу"` | — | `onClick = viewModel::reloadContent`; рядок 407 |
| Пояснення | `Text` (`bodySmall`, `onSurfaceVariant`) | `"Корисно після оновлення застосунку: контент перезалиється, а прогрес і картки залишаються."` | — | рядок 410 |

---

## 5. Діалоги та підтвердження

### 5.1. Діалог скидання прогресу (`AlertDialog`, рядки 423–443)

| Елемент | Дослівний текст | Дія / наслідок |
|---|---|---|
| Заголовок (`title`) | `"Очистити прогрес?"` | рядок 424 (лямбда `lambda-15`) |
| Текст (`text`) | `"Будуть видалені всі картки, статистика, помилки й діалоги. Контент курсу залишиться. Дію не можна скасувати."` | рядок 426 (`lambda-16`) |
| Кнопка підтвердження (`confirmButton`, `TextButton`) | `"Очистити"` | `viewModel.resetProgress()` (432) і `showResetDialog = false` (435); у БД викликається `users.clearProgress()`; у банер імпорту пише `"Прогрес очищено. Контент курсу залишився."` |
| Кнопка скасування (`dismissButton`, `TextButton`) | `"Скасувати"` | лише `showResetDialog = false` (438) |
| `onDismissRequest` (тап поза діалогом / кнопка «назад») | — | `showResetDialog = false` (424) |

### 5.2. Діалог імпорту прогресу (`AlertDialog`, рядки 444–468)

Показується лише коли `showImportDialog == true` **і** `pendingImport != null` (файл уже прочитано).

| Елемент | Дослівний текст | Дія / наслідок |
|---|---|---|
| Заголовок (`title`) | `"Імпорт прогресу"` | рядок 446 (`lambda-20`) |
| Текст (`text`) | `"Замінити наявний прогрес даними з файлу чи додати їх до поточного?"` | рядок 447 (`lambda-21`) |
| `confirmButton` (`TextButton`) | `"Замінити"` | `viewModel.importProgress(pendingImport!!, replaceExisting = true)` (450–451), `showImportDialog = false` (452), `pendingImport = null` (454). Наслідок: `usersDao.clearProgress()` перед вставкою — наявний прогрес видаляється |
| `dismissButton` — кнопка 1 (`TextButton` у `Row`) | `"Додати"` | `viewModel.importProgress(pendingImport!!, replaceExisting = false)` (466), потім `showImportDialog = false` (460), `pendingImport = null` (461). Наслідок: дані додаються до наявного прогресу |
| `dismissButton` — кнопка 2 (`TextButton` у `Row`) | `"Скасувати"` | лише `showImportDialog = false` (464) і `pendingImport = null` (465) |
| `onDismissRequest` | — | `showImportDialog = false` (446) |

> Порядок кнопок у `AlertDialog`: ліва/основна — `"Замінити"`, праворуч у `Row` — `"Додати"` і `"Скасувати"`.

### 5.3. Помилки та результат перевірки голосу

Окремих діалогів немає: результат перевірки голосу — лише звук (без тексту й без діалогу),
помилки імпорту/експорту — банери `InfoBanner` зі стану (див. §6).

---

## 6. Стани

| Стан | Умова | Що показує екран | Дослівні тексти |
|---|---|---|---|
| **loading** | `state.loading == true` | `Box(fillMaxSize, Center) { CircularProgressIndicator() }`; решта екрана не рендериться | текст не знайдено (лише індикатор) |
| **success (контент)** | `state.loading == false` | повна `Column` з 6 секціями | див. §4 |
| **busy** | `state.busy == true` | рядок з `CircularProgressIndicator` у секції «Дані та перенесення» | `"Працюю…"` |
| **exportMessage** | `state.exportMessage != null` | `InfoBanner` у секції «Дані та перенесення» | `"Прогрес збережено у «Завантаження»: "` + ім'я файлу; `"Прогрес збережено у папці застосунку: "` + ім'я файлу; `"Не вдалося зберегти прогрес: "` + `e.message` |
| **importMessage** | `state.importMessage != null` | `InfoBanner` у секції «Дані та перенесення» | `"Прогрес відновлено. "` + `"Карток: "` + N + `", "` + `"днів статистики: "` + N + `", "` + `"помилок: "` + N + `"."`; `"Файл створено новішою версією застосунку (формат "` + ver + `")."`; `"Помилка під час імпорту: "` + `e.message`; `"Файл пошкоджений або це не файл прогресу KRUPA_Spanish: "` + `e.message`; `"Прогрес очищено. Контент курсу залишився."`; `"Контент перезавантажено з файлів застосунку."` |
| **error (контент)** | `state.contentIssues.isNotEmpty()` | `InfoBanner` у кольорах `errorContainer`/`onErrorContainer` у секції «Діагностика» | `"Проблеми контенту: "` + `contentIssues.joinToString("; ")` |
| **AI-помилки** | — | **текст не знайдено** — у `SettingsScreen`/`SettingsViewModel` немає жодного тексту про помилку AI, відсутній API-ключ чи невдалу перевірку AI | — |
| **Помилка читання файлу** | `runCatching{…}.getOrNull() == null` | діалог імпорту не відкривається; одразу `importProgress("", false)` → банер з текстом помилки від `ProgressTransfer` | `"Файл пошкоджений або це не файл прогресу KRUPA_Spanish: "` + `e.message` |

Повідомлення `ImportReport.warnings` (зокрема `"У файлі немає даних про навчання."`) **не виводяться** в UI —
`SettingsViewModel.importProgress` бере зі звіту лише `messageUk`.

---

## 7. Дії користувача

| Елемент | Дія | Наслідок | Побічні ефекти (профіль / файл / БД) |
|---|---|---|---|
| «Назад» | тап | `onBack()` — вихід з екрана | — |
| Поле «Ім'я (необов'язково)» | введення тексту | `setName(value)` на кожне натискання | `users.saveProfile(copy(name = value))` (без `trim()`) |
| Чип рівня (`A0`/`A1`/`A2`) | тап | `setLevel(level)` | запис `level` у профіль |
| Чип цілі | тап | `setGoal(goal)` | запис `goal` у профіль |
| Чип «Час на день» | тап | `setDailyMinutes(minutes)` | запис `dailyMinutes` (10/20/30/45/60) |
| «Пройти тест рівня ще раз» | тап | `onOpenOnboarding()` | профіль не змінюється |
| Чип теми | тап | `setTheme(mode)` | запис `themeMode`; тема застосунку застосовується одразу |
| Чип голосу | тап | `setVoiceGender(gender)` | `ttsEngine.setVoiceGender(gender)` + запис `ttsVoiceGender` (`"female"`/`"male"`) |
| Чип швидкості | тап | `setRate(rate)` | `ttsEngine.setRate(rate)` + запис `ttsRate` |
| «Перевірити голос» | тап | озвучення `"Hola. Me llamo Ana. ¿Qué tal?"` | стан не змінюється |
| Switch «Показувати переклад під час слухання» | перемикання | `setListeningHints(enabled)` | запис `showListeningHints` |
| Чип провайдера AI | тап | `setAiProvider(id)` | запис `aiProviderId` |
| Switch «Дозволити зовнішні AI-сервіси» | перемикання | `setAllowExternalAi(allowed)` | запис `allowExternalAi`; показує/ховає 3 текстові поля |
| Поля endpoint / ключ / модель | введення | `setAiEndpoint` / `setAiApiKey` / `setAiModel` | запис відповідного поля з `trim()` |
| «Експортувати прогрес у JSON» | тап | `exportProgress()` | `busy=true`; створюється файл `krupa_spanish_progress_<yyyy-MM-dd_HHmm>.json` у «Завантаження» (або в `files/exports`); `exportMessage` = текст звіту; `busy=false` |
| «Імпортувати прогрес з файлу» | тап | відкривається системний пікер (`application/json`, `text/plain`, `*/*`) | профіль/БД не змінюються |
| Вибір файлу в пікері | вибір | текст читається у UTF-8 → `pendingImport` + `showImportDialog = true` | якщо читання не вдалося — `importProgress("", false)` і банер помилки |
| Діалог імпорту: «Замінити» | тап | `importProgress(text, true)` | `busy=true`; `usersDao.clearProgress()` і вставка даних із файлу (профіль, картки, статистика, помилки, діалоги); `importMessage` = `"Прогрес відновлено. Карток: N, днів статистики: N, помилок: N."`; `busy=false` |
| Діалог імпорту: «Додати» | тап | `importProgress(text, false)` | те саме, але без очищення наявного прогресу |
| Діалог імпорту: «Скасувати» / тап поза | тап | закриття діалогу | `pendingImport = null` |
| «Очистити весь прогрес» | тап | відкривається діалог підтвердження | — |
| Діалог скидання: «Очистити» | тап | `resetProgress()` | `users.clearProgress()`; `importMessage = "Прогрес очищено. Контент курсу залишився."` |
| Діалог скидання: «Скасувати» / тап поза | тап | закриття | — |
| «Перезавантажити контент курсу» | тап | `reloadContent()` | `busy=true`; `contentSeeder.seedIfNeeded(force = true)`; `wordCount` перечитується; `importMessage = "Контент перезавантажено з файлів застосунку."`; `busy=false` |

---

## Прогалини

1. **Точний тип контейнера для чипів «Ціль навчання» (рядки 146–154).** У smali створюється `ColumnKt.columnMeasurePolicy`
   (вертикальний контейнер), тоді як чипи рівня/теми/голосу/швидкості/провайдера — у `RowKt.rowMeasurePolicy`.
   Чи входить підпис `"Ціль навчання"` (рядок 145) усередину цього контейнера — за наявними даними не встановлено.
2. **Кількість і склад провайдерів AI** (`aiProviders.all()` / `AIProvider.titleUk`) — динамічні, у `SettingsScreen` не зашиті;
   конкретні підписи чипів у цьому файлі не знайдено (постачає `AIProviderRegistry`).
3. **Тексти помилок AI та про відсутність API-ключа — текст не знайдено.** У `SettingsScreen`/`SettingsViewModel` таких рядків немає.
4. **Тексти для стану завантаження — текст не знайдено** (лише індикатор без підпису).
5. **`ImportReport.warnings`** (зокрема `"У файлі немає даних про навчання."`) не відображаються в UI — тому в переліку видимих
   текстів вони позначені як такі, що існують у моделі звіту, але не показуються.
6. **`SettingsViewModel.clearMessages()`** на екрані не викликається (мертвий публічний API) — банери не зникають автоматично.
7. **Іконки `InfoBanner`** — `imageVector = null` у всіх викликах; конкретні іконки не встановлені.
8. **`speechModelLanguage`** (`"іспанська (es-ES)"`) у стані є, але на екрані налаштувань не читається — текст ніде не показується.
9. **Клавіатурні опції текстових полів** (`KeyboardOptions`/`KeyboardActions`) не задані (значення за замовчуванням);
   `singleLine = true` — встановлено для всіх 4 полів. Поле API-ключа не маскується.
10. **Значення `level.code` у чипах рівня** — це саме коди `A0/A1/A2` (не `titleUk`); заголовки рівнів (`"Повний нуль"` тощо)
    на цьому екрані не показуються — лише `descriptionUk` обраного рівня під чипами.
11. **`ttsState.femaleVoiceName` / `maleVoiceName`** — динамічні значення з TTS-рушія, у UI налаштувань не виводяться.
12. **Точні відступи/розміри** відомі лише частково: кореневий `padding(16.dp)`, `spacedBy(12.dp)`, `spacedBy(6.dp)` між чипами,
    `Spacer(Modifier.height(30.dp))` перед діалогами, `Spacer(8.dp)` перед банером проблем контенту; решта — типові дефолти `Card`/`Text`.
