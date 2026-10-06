# 50. Speaking (тренажер вимови) та AI-діалог

Джерела: `_recon/strings_by_class.txt` (рядкові константи за класами) і дампи smali
(`spec/_work/classes/…`, раніше — `_work/smali/classes*_ui.txt`, на момент написання переміщені).
Довжини файлів-джерел: `SpeakingScreen.kt` — 340 рядків, `AiDialogScreen.kt` — приблизно 430 рядків
(номери рядків нижче — з Compose-метаданих `C(...)...@offsetLlength` і з позицій лямбд `(Файл.kt:NNN)`).

Позначки: **✔** — підтверджено smali/рядками; *(не підтв.)* — висновок за контекстом, точної інструкції не знайдено.

---

# 1. Speaking

## 1.1 Призначення

Екран `SpeakingScreen` — тренажер вимови (говоріння) для одного промпта за раз:

1. показує позицію в черзі (`1 / N`) і смугу прогресу;
2. показує український переклад фрази як завдання («Скажіть уголос:»);
3. дає картку з іспанським текстом/підказкою;
4. дає прослухати зразок TTS — «Зразок» (звичайний темп) і «Повільно» (сповільнений темп);
5. записує голос (`SpeechRecognizer`, дозвіл `RECORD_AUDIO`) і надсилає розпізнаний текст на оцінку;
6. показує блок оцінки вимови `PronunciationResultBlock` (бал, метрики, «Що виправити», «Рекомендації»);
7. дає самооцінку «Вийшло погано» / «Вийшло добре», перехід «Попереднє» / «Наступне» і статистику
   («Спроб», «Середня оцінка»).

## 1.2 `SpeakingPrompt` (`SpeakingViewModel.kt`)

| Поле | Тип | Призначення |
|---|---|---|
| `id` | `String` | ідентифікатор промпта; у `load()` формується з префіксами `"sp_word_"`, `"sp_sent_"`, `"sp_ex_"` ✔ |
| `spanish` | `String` | іспанська фраза — те, що озвучує TTS і що оцінює розпізнавання ✔ |
| `translationUk` | `String` | український переклад — показується як завдання (великий текст, `HeadlineSmall`) ✔ |
| `hintUk` | `String` | підказка українською; для слів збирається як `"З артиклем: <display>. "` + `"Вимова: <pronunciation>. "` + `ipaHint` (розділювач `". "`) ✔ |
| `level` | `Level` | рівень слова/речення (`Word.getLevel()` / рівень профілю) ✔ |
| `grammarTagCode` | `String` | код першої граматичної теґи (`Word.getGrammarTags().firstOrNull()?.code`), інакше `null`-рядок ✔ |

Джерело промптів: приватний `suspend load()` у `SpeakingViewModel` — бере з `AppContainer` слова,
речення та вправи, рівень із `UserProfile`, формує `List<SpeakingPrompt>`, сортує
`sortedByDescending` (клас `SpeakingViewModel$load$$inlined$sortedByDescending$1`; точний критерій сортування — *не підтв.*),
кладе в `queue`. Допоміжний `genderMap()` дає артиклі для «З артиклем: ».

## 1.3 `SpeakingUiState`

Порядок полів — як у конструкторі `SpeakingUiState(Z, Level, List, I, Z, Z, PronunciationResult, String, I, I, Z)` ✔

| # | Поле | Тип | Значення за замовчуванням ✔ |
|---|---|---|---|
| 1 | `loading` | `Boolean` | `true` |
| 2 | `level` | `Level` | `Level.A0` |
| 3 | `queue` | `List<SpeakingPrompt>` | `emptyList()` |
| 4 | `currentIndex` | `Int` | `0` |
| 5 | `isListening` | `Boolean` | `false` (стан запису) |
| 6 | `attempted` | `Boolean` | `false` (чи була спроба для поточного промпта) |
| 7 | `result` | `PronunciationResult?` | `null` (результат оцінки) |
| 8 | `error` | `String?` | `null` |
| 9 | `completed` | `Int` | `0` (кількість завершених спроб) |
| 10 | `averageScore` | `Int` | `0` (середній бал 0…100) |
| 11 | `speechAvailable` | `Boolean` | `false` |

Обчислювані властивості (гетери в smali): `getCurrent(): SpeakingPrompt` — поточний промпт
(`queue[currentIndex]`), `getTotal(): Int` — розмір черги (використовується в лічильнику `"N / total"`).

Увага: `speechAvailable` у `SpeakingScreen` **не читається** — екран перевіряє
`SpanishSpeechRecognizer.isAvailable()` напряму ✔ (див. 1.7).

## 1.4 `SpeakingViewModel`

| Метод | Параметри | Що робить |
|---|---|---|
| `state` (getter) | — | `StateFlow<SpeakingUiState>` (з `_state = MutableStateFlow(SpeakingUiState())`, `asStateFlow()`) ✔ |
| `load()` | `suspend`, приватний | вантажить профіль/рівень, добирає слова, речення, вправи; формує `id` (`sp_word_`/`sp_sent_`/`sp_ex_`), `hintUk` для слів (`"З артиклем: "`, `"Вимова: "`, `ipaHint`, розділювач `". "`), сортує чергу, оновлює `queue`/`level`/`loading` ✔ |
| `genderMap()` | `suspend`, приватний | мапа «слово → артикль» (`el`/`la`/`un`/`una`…), використовується у `load()` для рядка `"З артиклем: "` ✔ |
| `next()` | — | перехід до наступного промпта в черзі ✔ |
| `previous()` | — | перехід до попереднього промпта ✔ |
| `selfAssess(correct: Boolean)` | `Boolean` | самооцінка без розпізнавання: додає бал у `scores`, перераховує `averageScore`, збільшує `completed`, ставить `attempted = true` ✔ |
| `setListening(listening: Boolean)` | `Boolean` | оновлює стан запису `isListening` ✔ |
| `submitSpeech(recognized: String)` | `String` | приймає розпізнаний текст від `SpeechRecognizer` і передає на оцінку → `recordAttempt(prompt, score)` ✔ |
| `reportError(message: String)` | `String` | записує текст помилки у `error` (показується банером) ✔ |
| `recordAttempt(prompt, score)` | `SpeakingPrompt`, `Int`, `suspend`, приватний | зберігає бал у `scores`, оновлює `result`/`attempted`/`averageScore`/`completed`; записує виконану вправу з тегом `"speaking"` і назвою `"Вправа на вимову: " + prompt.spanish` ✔ |

Рядкові константи ViewModel: `"Вправа на вимову: "`, `"Вимова: "`, `"З артиклем: "`, `". "`, префікси `"sp_word_"`, `"sp_sent_"`, `"sp_ex_"`, тег `"speaking"`.

## 1.5 Структура екрана `SpeakingScreen` (зверху вниз)

Функція: `SpeakingScreen(container: AppContainer, onBack: () -> Unit)`, `SpeakingScreen.kt:56`.
Корінь — `Box` (р. 70) → `Column` (р. 76); вміст — лямбда `$5` (р. 93).

| Рядок | Composable | Текст / вміст | Дія |
|---|---|---|---|
| 83–88 | `CommonComponentsKt.EmptyState(title, message)` | `"Немає завдань для говоріння"` / `"Спершу пройдіть кілька занять — ми підберемо слова й речення, які ви вже вчите."` | показується, коли `queue` порожня |
| 89 | `Spacer(height = 16.dp)` | — | — |
| 90 | `NavigationComponentsKt.PrimaryActionButton(text, onClick)` | `"Назад"` | `onBack()` |
| 101–104 | `Row` (верхній) | — | — |
| 105–106 | `TextButton(content = lambda-1)` | `"Назад"` | `onBack()` |
| 111–116 | `Text` | лічильник `"${currentIndex + 1} / ${total}"` (StringBuilder: `currentIndex + 1`, `" / "`, `total`) | — |
| 118–123 | `LinearProgressIndicator(progress = { … }, modifier = fillMaxWidth().height(8.dp), strokeCap = Round)` | — | прогрес = `(currentIndex+1)/total` (лямбда `$5$2$1`) |
| 126 | `Text(style = TitleMedium)` | `"Скажіть уголос:"` | — |
| 127 | `Text(style = HeadlineSmall)` | `prompt.translationUk` | — |
| 128–148 | `Card(colors = CardDefaults.cardColors(containerColor = colorScheme.surfaceVariant), modifier = fillMaxWidth())`, вміст — `$5$3` | 1) `Text(prompt.spanish, style = TypeKt.SpanishWordStyle)`; 2) `Text` — розділювач `"•  •  •"`; 3) `Text(prompt.hintUk, style = BodyMedium, color = onSurfaceVariant)` — підказка, прив'язана до `state.attempted` *(точне розгалуження if/else у smali не верифіковане)* | — |
| 156–157 | `Text` (умовно: `if (!state.attempted)`) | `"Послухайте зразок, а потім повторіть уголос."` | — |
| 163–174 | `OutlinedButton(content = lambda-2)` | `"Зразок"` | `tts.initialize()` → `tts.speak(prompt.spanish)` (нормальний темп) |
| 183–186 | `OutlinedButton(content = lambda-3)` | `"Повільно"` | `tts.initialize()` → `tts.setRate(повільніше)` → `tts.speak(prompt.spanish)` → `tts.setRate(назад)` |
| 189 | `if (recognizer.isAvailable())` | — | розгалуження «є розпізнавання / немає» |
| 190–210 | лямбда `$5$5` (onClick кнопки запису) | — | якщо `!recognizer.hasPermission` → `permissionLauncher.launch("android.permission.RECORD_AUDIO")` (р. 193); інакше `viewModel.setListening(true)` (р. 195) і `scope.launch { recognizer.listen(...) }` (р. 196+) |
| 211–218 | `Button(onClick = $5$5, modifier = fillMaxWidth(), shape = RoundedCornerShape(16.dp), contentPadding = PaddingValues(vertical = 18.dp), content = $5$6)` | `if (state.isListening)` → `"Слухаю… говоріть"` (р. 215), інакше → `"Натисніть і говоріть"` (р. 216) | старий/новий стан запису |
| 222–224 | `CommonComponentsKt.InfoBanner(text)` — гілка `else` (розпізнавання недоступне) | `"У системі немає розпізнавання мовлення, тому оцінка вимови недоступна. Слухайте зразок і оцініть себе самі."` | — |
| 229–234 | `InfoBanner(text = state.error)` (якщо `error != null`) | текст помилки з `state.error` (напр. `"Без дозволу на мікрофон оцінка вимови недоступна."`) | — |
| 239–241 | `PronunciationResultBlock(result)` (якщо `result != null`) | див. 1.6 | — |
| 243–253 | `Row` + `OutlinedButton` (р. 247) + `Button` (р. 251) | `"Вийшло погано"` / `"Вийшло добре"` | `viewModel.selfAssess(false)` (р. 246) / `viewModel.selfAssess(true)` (р. 250) |
| 256–264 | `Row` + `OutlinedButton` (р. 258) + `Button` (р. 261) | `"Попереднє"` / `"Наступне"` | `viewModel.previous()` / `viewModel.next()` |
| 265–277 | `Row` + 2 × `MetricCard(title, value, modifier = Modifier.weight(1f), unit, color, icon)` | 1) `"Спроб"` + `"${completed}"` (р. 266–269); 2) `"Середня оцінка"` + `"${averageScore}"` + `"з 100"` (р. 271–275) | — |
| 280 | `Spacer(height = 24.dp)` | — | — |

Додаткові верхньорівневі елементи, знайдені в метаданих: `Spacer` (р. 89, 280, 309/319/330 всередині блоку оцінки).

## 1.6 `PronunciationResultBlock`

Функція: `PronunciationResultBlock(result: PronunciationResult)`, `SpeakingScreen.kt:284`, тіло — лямбда
`SpeakingScreenKt$PronunciationResultBlock$1` (р. 291–339).

Колір оцінки `scoreColor` (р. 286–288, локальна змінна `scoreColor: Long`):

| Умова | Колір |
|---|---|
| `result.score >= 80` | `MaterialTheme.colorScheme.secondary` |
| інакше `result.score >= 60` | `MaterialTheme.colorScheme.tertiary` |
| інакше | `MaterialTheme.colorScheme.error` |

| Рядок | Елемент | Дослівний текст / формат |
|---|---|---|
| 293 | `Card(colors = CardDefaults.cardColors(containerColor = colorScheme.surfaceVariant), modifier = fillMaxWidth())` | — |
| 296–297 | `Text(style = HeadlineSmall)` | конкатенація: `"Pronunciation: "` + `result.score` + `"/100"` → напр. `Pronunciation: 87/100` (латиниця, без `%`) |
| 301 | `Text(result.summaryUk, style = BodyLarge)` | український підсумок із `PronunciationResult.summaryUk` |
| 304–309 | `LinearProgressIndicator(progress = { result.score / 100f }, color = scoreColor, strokeCap = Round, modifier = fillMaxWidth().height(8.dp))` | шкала 0…1 (лямбда `$1$1$1`: `getScore().toFloat() / 100f`, ділення на 100.0f) |
| 313 | `Text(style = BodyMedium)` | `"Слова: "` + `result.wordAccuracy` + `"%"` |
| 314 | `Text(style = BodyMedium)` | `"Звучання: "` + `result.phoneticScore` + `"%"` |
| 315 | `Text(style = BodyMedium)` | `"Швидкість і плавність: "` + `result.fluencyScore` + `"%"` |
| 319–324 | `if (result.issues.isNotEmpty())`: `Spacer(6.dp)`; `Text("Що виправити", style = TitleSmall)`; цикл `result.issues.take(5)` → `Text(style = BodyMedium)` | `"• "` + `issue.type.titleUk` + `": "` + `issue.explanationUk` |
| 330–333 | `if (result.suggestions.isNotEmpty())`: `Spacer(6.dp)`; `Text("Рекомендації", style = TitleSmall)`; цикл по `result.suggestions` → `Text(style = BodyMedium)` | `"• "` + `suggestion` (без обмеження кількості) |

Структура даних: `PronunciationResult` — `score: Int`, `summaryUk: String`, `wordAccuracy: Int`,
`phoneticScore: Int`, `fluencyScore: Int`, `issues: List<PronunciationIssue>`, `suggestions: List<String>`;
`PronunciationIssue` — `type: IssueType` (має `titleUk`) і `explanationUk: String`.

Точні рядки-константи блоку: `"Pronunciation: "`, `"/100"`, `"%"`, `"Слова: "`, `"Звучання: "`,
`"Швидкість і плавність: "`, `"Що виправити"`, `"• "`, `": "`, `"Рекомендації"`.

## 1.7 Дозволи та помилки

| Стан | Умова | Що показується / робиться |
|---|---|---|
| Дозвіл відсутній | `!recognizer.hasPermission` при натисканні кнопки запису | системний запит `"android.permission.RECORD_AUDIO"` через `permissionLauncher.launch(...)` (р. 193) ✔ |
| Відмова в дозволі | результат ланчера (клас `$permissionLauncher$1`) | `viewModel.reportError("Без дозволу на мікрофон оцінка вимови недоступна.")` → банер помилки на екрані ✔ |
| Розпізнавання недоступне | `!recognizer.isAvailable()` | замість кнопки запису — `InfoBanner` з текстом `"У системі немає розпізнавання мовлення, тому оцінка вимови недоступна. Слухайте зразок і оцініть себе самі."` (р. 223) + доступні кнопки самооцінки |
| Помилка розпізнавання/мережі | `state.error != null` | `InfoBanner(state.error)` (р. 229–234) |
| Кнопки переходу в системні налаштування | — | **текст не знайдено**: окремої кнопки «Налаштування» у `SpeakingScreen.kt` немає; перехід до налаштувань не реалізовано ✔ |

## 1.8 Дії — точні підписи (усі з smali)

| Підпис (дослівно) | Тип елемента | Рядок |
|---|---|---|
| `"Назад"` | `PrimaryActionButton` (порожній стан) | 90 |
| `"Назад"` | `TextButton` (верхній лівий) | 106 |
| `"Зразок"` | `OutlinedButton` | 169 |
| `"Повільно"` | `OutlinedButton` | 184 |
| `"Натисніть і говоріть"` | `Button` (текст, стан спокою) | 216 |
| `"Слухаю… говоріть"` | `Button` (текст, стан запису) | 215 |
| `"Вийшло погано"` | `OutlinedButton` | 247 |
| `"Вийшло добре"` | `Button` | 251 |
| `"Попереднє"` | `OutlinedButton` | 258 |
| `"Наступне"` | `Button` | 261 |
| `"Спроб"` / `"Середня оцінка"` / `"з 100"` | `MetricCard` (підпис / значення / одиниця) | 266–275 |

## 1.9 Таблиця `Елемент | Дія | Наслідок | Навігація`

| Елемент | Дія | Наслідок | Навігація |
|---|---|---|---|
| «Назад» (порожній стан і верхній лівий) | tap | `onBack()` | вихід з екрана (навігація — у холдері, не в цьому файлі) |
| Лічильник `N / M` + `LinearProgressIndicator` | — | показ прогресу черги | — |
| «Зразок» | tap | TTS озвучує `prompt.spanish` у нормальному темпі | — |
| «Повільно» | tap | TTS тимчасово знижує темп (`setRate`), озвучує, повертає темп | — |
| Кнопка запису «Натисніть і говоріть» | tap | якщо дозвіл є: `setListening(true)` + запуск розпізнавання; після `Result` → `submitSpeech(recognized)` → оцінка | — |
| Кнопка запису «Слухаю… говоріть» | tap/авто | стан запису активний | — |
| Дозвіл відсутній | tap | системний діалог дозволу `RECORD_AUDIO` | — |
| «Вийшло погано» | tap | `selfAssess(false)` → бал 0 у статистику, `attempted = true` | — |
| «Вийшло добре» | tap | `selfAssess(true)` → бал 100 у статистику | — |
| «Попереднє» / «Наступне» | tap | зміна `currentIndex`, новий промпт | всередині екрана |
| Показ `PronunciationResultBlock` | авто | при `result != null` | — |
| Помилка | авто | банер `InfoBanner(state.error)` | — |

---

# 2. AiDialog

## 2.1 Призначення

`AiDialogScreen` — діалоговий тренажер іспанської з «AI-викладачем»: користувач обирає режим
(`AIConversationMode`) і ситуацію (`AIScenario`), веде чат іспанською (текст і/або голос),
а наприкінці отримує розбір помилок (`AICorrection`) з поясненнями українською.
Провайдер діалогу — локальний (офлайн, `LocalAIProvider`) або зовнішній (потребує інтернету).

## 2.2 `AiPhase` (enum, `AiDialogViewModel.kt`)

Порядок констант (= `ordinal`) ✔: `SETUP` (0) → `CHAT` (1) → `REVIEW` (2).

| Константа | ordinal | Що показує фаза |
|---|---|---|
| `SETUP` | 0 | вибір режиму, ситуації, інформація про провайдера, кнопка `"Почати діалог"` |
| `CHAT` | 1 | чат: бульбашки реплік, індикатор «Викладач друкує…», поле вводу, кнопки `"Надіслати"`, `"Говорити"`, `"Завершити"` |
| `REVIEW` | 2 | «Розбір діалогу»: кількість реплік, картки корекцій або банер «помилок не знайдено», «Що далі» з `"Ще один діалог"` / `"На головну"` |

Диспетчеризація — у `AiDialogScreen` (р. 62): за `state.phase` викликається `SetupPhase` / `ChatPhase` / `ReviewPhase`.

## 2.3 Моделі повідомлень і корекцій

| Клас | Поля (типи) |
|---|---|
| `ChatMessage` (`AiDialogViewModel.kt`) ✔ | `fromUser: Boolean`, `spanish: String`, `hintUk: String`, `timestamp: Long`; конструктор `(Z, String, String, J)` |
| `AIMessage` (`AIProvider.kt`) | `fromUser: Boolean`, `spanish: String`, `hintUk: String` |
| `AICorrection` (`AIProvider.kt`) | `wrongText: String`, `correctText: String`, `explanationUk: String` |
| `AIRequest` (`AIProvider.kt`) | `mode: AIConversationMode`, `scenario: AIScenario?`, `level: Level`, `topicTitleUk: String?`, `history: List<AIMessage>`, `focusWords: List<String>` |
| `AIResponse` (`AIProvider.kt`) | `spanish: String?`, `hintUk: String?`, `corrections: List<AICorrection>`, `error: String?` |
| `LocalAIProvider.ScriptLine` | `spanish: String`, `hintUk: String` |

## 2.4 `AIConversationMode` (`AIProvider.kt`) — 4 режими

Поля: `code: String`, `titleUk: String`, `descriptionUk: String` ✔. Порядок оголошення (= `ordinal`) і значення ✔:

| # | Константа | `code` | Назва (дослівно) | Опис (дослівно) |
|---|---|---|---|---|
| 1 | `TEACHER` | `"teacher"` | `"Вчитель"` | `"Пояснює помилки українською, розбирає граматику"` |
| 2 | `PARTNER` | `"partner"` | `"Співрозмовник"` | `"Говорить лише іспанською, як носій"` |
| 3 | `HINTS` | `"hints"` | `"Іспанська + підказки"` | `"Іспанською, але з перекладом і допомогою"` |
| 4 | `ROLEPLAY` | `"roleplay"` | `"Рольова гра"` | `"Реалістична ситуація: ресторан, готель, лікар…"` |

## 2.5 `AIScenario` (`AIProvider.kt`) — 9 сценаріїв

Поля: `code: String`, `titleUk: String`, `openingSpanish: String`, `openingHintUk: String` ✔.
Порядок оголошення (= `ordinal`) і значення ✔:

| # | Константа | `code` | Назва (укр., дослівно) | Перша репліка іспанською (дослівно) | Український відповідник (`openingHintUk`) |
|---|---|---|---|---|---|
| 1 | `INTRODUCTIONS` | `"introductions"` | `"Знайомство"` | `"¡Hola! Me llamo Ana. ¿Y tú? ¿Cómo te llamas?"` | `"Привіт! Мене звати Ана. А ти?"` |
| 2 | `RESTAURANT` | `"restaurant"` | `"Ресторан"` | `"Buenas tardes, bienvenido. ¿Mesa para cuántas personas?"` | `"Доброго дня, вітаю. Столик на скільки осіб?"` |
| 3 | `SHOP` | `"shop"` | `"Магазин"` | `"Hola, ¿le puedo ayudar en algo?"` | `"Вітаю, можу чимось допомогти?"` |
| 4 | `HOTEL` | `"hotel"` | `"Готель"` | `"Buenas noches. ¿Tiene una reserva a su nombre?"` | `"Доброго вечора. У вас є бронювання?"` |
| 5 | `AIRPORT` | `"airport"` | `"Аеропорт"` | `"Buenos días. ¿Me enseña su pasaporte, por favor?"` | `"Доброго ранку. Покажіть, будь ласка, паспорт."` |
| 6 | `DOCTOR` | `"doctor"` | `"Лікар"` | `"Buenos días. Cuénteme, ¿qué le pasa?"` | `"Доброго ранку. Розкажіть, що вас турбує?"` |
| 7 | `WORK` | `"work"` | `"Робота"` | `"Hola, soy Marta de recursos humanos. Cuéntame un poco sobre ti."` | `"Вітаю, я Марта з відділу кадрів. Розкажи трохи про себе."` |
| 8 | `RENTING` | `"renting"` | `"Оренда житла"` | `"Hola, ¿llama por el piso del centro? Todavía está disponible."` | `"Вітаю, ви телефонуєте щодо квартири в центрі? Вона ще вільна."` |
| 9 | `FREE_TALK` | `"free_talk"` | `"Вільна розмова"` | `"¡Hola! ¿Qué tal? ¿Cómo llevas el español?"` | `"Привіт! Як справи? Як тобі дається іспанська?"` |

## 2.6 `AiDialogUiState`

| Поле | Тип | Примітка |
|---|---|---|
| `phase` | `AiPhase` | стартова фаза — `SETUP` *(не підтв. точно; за замовчуванням у конструкторі — перший елемент)* |
| `mode` | `AIConversationMode` | вибраний режим |
| `scenario` | `AIScenario` | вибрана ситуація |
| `providerTitle` | `String` | назва активного провайдера (напр. `"Локальний викладач (без інтернету)"` для `LocalAIProvider`) |
| `requiresNetwork` | `Boolean` | чи потрібен інтернет |
| `allowExternalAi` | `Boolean` | чи дозволено зовнішній AI (гейт налаштувань) |
| `messages` | `List<ChatMessage>` | історія чату |
| `input` | `String` | текст у полі вводу |
| `thinking` | `Boolean` | «викладач друкує» |
| `corrections` | `List<AICorrection>` | корекції для фази `REVIEW` |
| `isListening` | `Boolean` | стан запису голосу |
| `speechAvailable` | `Boolean` | чи доступне розпізнавання |

Поля `error` у стані **немає** — помилки провайдера приходять як `AIResponse.error` і, ймовірно,
потрапляють у чат/банер; окремого поля стану не знайдено ✔.

## 2.7 `AiDialogViewModel`

| Метод | Параметри | Що робить |
|---|---|---|
| `state` (getter) | — | `StateFlow<AiDialogUiState>` ✔ |
| `updateInput(text: String)` | `String` | оновлює `input` |
| `setMode(mode: AIConversationMode)` | режим | вибір режиму у фазі `SETUP` |
| `setScenario(scenario: AIScenario)` | сценарій | вибір ситуації |
| `start()` | — | старт діалогу: фаза `CHAT`, перша репліка сценарію |
| `send()` | — | надсилає `input` провайдеру, додає репліку користувача, ставить `thinking`, потім відповідь AI |
| `speak(text: String)` | `String` | озвучує репліку через TTS |
| `setListening(listening: Boolean)` | `Boolean` | стан запису голосу |
| `finish()` | — | завершення діалогу → фаза `REVIEW`, збір корекцій |
| `backToSetup()` | — | повернення до `SETUP` |
| `retry()` | — | повтор останньої невдалої дії (кнопка/лямбда `AiDialogScreen$9`) |
| `previewCorrections(text: String): List<AICorrection>` | `String` | локальний попередній розбір тексту (без мережі) |
| `tagForScenario(scenario): GrammarTag` | `AIScenario` | граматична теґа для сценарію (для запису помилок) |
| `focusWords()`, `recordMistakes(state)`, `saveConversation(state)` | `suspend`, приватні | добір фокус-слів, запис помилок у SRS, збереження діалогу |
| Поля | — | `_state: MutableStateFlow<AiDialogUiState>`, `allCorrections: List<AICorrection>`, `container: AppContainer` ✔ |

Локальні рядки провайдера: тег `"local"`, назва `"Локальний викладач (без інтернету)"`; у `LocalAIProvider`
є скрипти реплік для всіх 9 сценаріїв + пояснення українською (напр. `"Переклад: "`, `"Розберімо помилку. "`,
`"Спробуйте відповісти повним реченням."`, `"Запам'ятайте: "` — див. `strings_by_class.txt`).

## 2.8 Фаза `SETUP` (`SetupPhase`, `AiDialogScreen.kt:123`, тіло 124–180)

| Рядок (прибл.) | Елемент | Текст (дослівно) |
|---|---|---|
| 132 | `TextButton` (лямбда-1) | `"Назад"` → `onBack()` |
| 131–137 | `Text` (заголовок) | `"AI-діалог"` |
| 137–138 | `Text` (опис) | `"Розмова іспанською з викладачем. Помилки не переривають діалог — розбір буде наприкінці."` |
| 141–142 | `Text` (інфо про провайдера) | `"Зараз активний провайдер: "` + `providerTitle` + `". "` + один із рядків: `"Він працює повністю на пристрої й нічого не надсилає назовні."` (локальний) **або** `"Він потребує інтернету — текст ваших реплік буде надіслано на зовнішній сервіс."` (зовнішній) |
| 154–155 | `CommonComponentsKt.SectionTitle` | `"Режим"` |
| 157–161 | цикл `AIConversationMode.entries` → `SelectableRow(title, subtitle, selected, onClick)` | `title = mode.titleUk`, `subtitle = mode.descriptionUk`, `selected = (state.mode == mode)`, `onClick = { onModeSelect(mode) }` — 4 рядки: `"Вчитель"` / `"Співрозмовник"` / `"Іспанська + підказки"` / `"Рольова гра"` |
| 166–167 | `SectionTitle` | `"Ситуація"` |
| 169–178 | цикл `AIScenario.entries` → `SelectableRow` | `title = scenario.titleUk`; `subtitle` — один із рядків сценарію (`openingHintUk` / `openingSpanish`; точне поле *не підтв.*), `selected = (state.scenario == scenario)` — 9 рядків з назвами з табл. 2.5 |
| 179–180 | `NavigationComponentsKt.PrimaryActionButton` | `"Почати діалог"` → `onStart()` |

## 2.9 Фаза `CHAT` (`ChatPhase`, `AiDialogScreen.kt:237`, тіло 238–319)

| Рядок (прибл.) | Елемент | Текст / поведінка |
|---|---|---|
| 240–245 | `Row` (верхній) з двома `Text` і `TextButton` | `Text(state.scenario.titleUk, style = TitleMedium)`; `Text(state.mode.titleUk, style = LabelSmall, color = onSurfaceVariant)`; `TextButton` (лямбда-2) — `"Завершити"` → `onFinish()` (р. 265) |
| 246–269 | `LazyColumn` зі списку `state.messages` | кожен елемент → `ChatBubble(message, onSpeak)` (виклик на р. 252) |
| 282–285 | елемент списку, якщо `state.thinking` | `Text("Викладач друкує…")` (лямбда-3) — індикатор набору |
| 300–308 | `Row` → `OutlinedTextField(value = state.input, onValueChange = onInputChange, modifier = Modifier.weight(1f), placeholder = { Text("Ваша відповідь іспанською") }, shape = RoundedCornerShape(14.dp))` | placeholder-лямбда-4 — `"Ваша відповідь іспанською"` (р. 304) |
| 309–314 | `if (state.speechAvailable) IconButton(onClick = onMic)` з вмістом `$2$3$1` | текст `"Говорити"` (р. 313–314) |
| 318–319 | `Button(onClick = onSend, enabled = state.input.isNotBlank() && !state.thinking, content = lambda-5)` | `"Надіслати"` (р. 319) |

### Бульбашка `ChatBubble(message: ChatMessage, onSpeak: () -> Unit)` — `AiDialogScreen.kt:326`

| Рядок | Елемент | Значення |
|---|---|---|
| 327–337 | вирівнювання та кольори | `fromUser == true` → `Alignment.CenterEnd`, контейнер `colorScheme.primaryContainer`, контент `colorScheme.onPrimaryContainer` (р. 329, 334); `false` → `Alignment.CenterStart`, `colorScheme.surfaceVariant`, `colorScheme.onSurfaceVariant` (р. 331, 336) |
| 339 | `Card(shape = RoundedCornerShape(...), colors = CardDefaults.cardColors(...))` | «хвостик» бульбашки — різні радіуси кутів |
| 350–352 | `Column` усередині картки | — |
| 354 | `Text(message.spanish)` | іспанська репліка |
| 368–369 | `Text(message.hintUk)` | українська підказка/переклад (показується, якщо непорожня) |
| 359 | кнопка прослуховування (лямбда-6) | `"Прослухати"` → `onSpeak(message.spanish)` (TTS) |

Інші рядки бульбашки: `timestamp` (поле `ChatMessage`, використовується під час збереження діалогу; у UI не знайдено відображення часу).

## 2.10 Фаза `REVIEW` (`ReviewPhase`, `AiDialogScreen.kt:385`, тіло 388–429)

| Рядок | Елемент | Текст (дослівно) |
|---|---|---|
| 391–395 | `Text(style = HeadlineMedium)` | `"Розбір діалогу"` |
| 396–398 | `Text(style = BodyLarge)` | `"Ваших реплік: "` + N + `". Ось що варто виправити."` (N — кількість повідомлень користувача) |
| 402–406 | якщо `state.corrections.isEmpty()` → `CommonComponentsKt.InfoBanner(text, containerColor = secondaryContainer, contentColor = onSecondaryContainer)` | `"Типових помилок не знайдено — гарна робота. Спробуйте складнішу ситуацію або режим «Співрозмовник»."` |
| 409–411 | інакше → `SectionTitle` | `"Твої помилки"` |
| 412–420 | на кожну унікальну корекцію (`distinctBy { it.wrongText }`) → `Card(modifier = fillMaxWidth())` з трьома `Text`: | 1) `"${index + 1}. ${wrongText}"` (`TitleSmall`); 2) `"✓ ${correctText}"` (`BodyLarge`, `color = colorScheme.secondary`); 3) `explanationUk` (`BodyMedium`) |
| 426–427 | `SectionTitle` | `"Що далі"` |
| 427–428 | `NavigationComponentsKt.PrimaryActionButton` | `"Ще один діалог"` → `onAgain()` |
| 428–429 | `OutlinedButton` (лямбда-7), `modifier = fillMaxWidth()` | `"На головну"` → `onHome()` |

## 2.11 Стани loading / error

| Стан | Ознака | UI |
|---|---|---|
| Очікування відповіді AI | `state.thinking == true` | у `LazyColumn` додається елемент `"Викладач друкує…"` (р. 282–285); кнопка `"Надіслати"` вимкнена (`enabled = input.isNotBlank() && !thinking`) |
| Порожній ввід | `state.input.isBlank()` | `Button("Надіслати")` вимкнена |
| Помилка провайдера | `AIResponse.error != null` | передається як повідомлення/через `retry()`; окремого банера помилки в `AiDialogScreen.kt` **не знайдено** (текст помилки — з провайдера) |
| Дозвіл на мікрофон | `AiDialogScreen$8` / `$8$1$1` | запит `"android.permission.RECORD_AUDIO"` (лямбда `$permissionLauncher$1` у `AiDialogScreen.kt` без власних текстів) |
| Немає розпізнавання | `state.speechAvailable == false` | кнопка `"Говорити"` не показується |

## 2.12 Дії користувача — таблиця

| Елемент | Фаза | Дія | Наслідок | Навігація |
|---|---|---|---|---|
| `"Назад"` | SETUP | tap | `onBack()` | вихід з екрана |
| `SelectableRow` режиму | SETUP | tap | `setMode(mode)` | лишається в SETUP |
| `SelectableRow` ситуації | SETUP | tap | `setScenario(scenario)` | лишається в SETUP |
| `"Почати діалог"` | SETUP | tap | `start()` | SETUP → CHAT |
| `"Завершити"` | CHAT | tap | `finish()` | CHAT → REVIEW |
| `"Надіслати"` | CHAT | tap | `send()` (активна, якщо ввід непорожній і не `thinking`) | лишається в CHAT |
| `"Говорити"` | CHAT | tap | запис голосу → розпізнаний текст у поле/`send` | лишається в CHAT |
| `"Прослухати"` | CHAT (бульбашка) | tap | `speak(message.spanish)` — TTS | — |
| `"Ще один діалог"` | REVIEW | tap | `retry()`/новий діалог (`onAgain`) | REVIEW → SETUP/CHAT |
| `"На головну"` | REVIEW | tap | `onHome()` | вихід з екрана |
| Поле вводу | CHAT | введення | `updateInput(text)` | — |

---

## Прогалини

1. **Розгалуження в картці промпта** (`SpeakingScreen.kt:128–148`): точне `if/else` між `prompt.spanish`,
   розділювачем `"•  •  •"` і `prompt.hintUk` за `state.attempted` не верифіковане (байти smali UI-класів
   `_work/smali/classes*_ui.txt` були переміщені під час роботи; залишились лише витяги не-UI класів у
   `spec/_work/classes/`).
2. **Кнопка переходу в налаштування** при відмові в дозвілі на мікрофон: у `SpeakingScreen.kt` **текст не знайдено**
   (показано лише банер `"Без дозволу на мікрофон оцінка вимови недоступна."`); аналогічно для `AiDialogScreen.kt`.
3. **Поле `SpeakingUiState.speechAvailable`** ніде не читається екраном (екран використовує
   `SpanishSpeechRecognizer.isAvailable()`); де саме його встановлює `load()` — не встановлено.
4. **`subtitle` у `SelectableRow` для сценаріїв** (`SetupPhase`, р. 169–178): обидва рядки беруться з
   `AIScenario`; яке саме поле (`openingHintUk` чи `openingSpanish`) передано — не підтверджено.
5. **Місце виклику `retry()`** та відображення тексту помилки провайдера у `AiDialogScreen`: лямбда
   `AiDialogScreen$9` існує, але прив'язка до конкретного елемента UI не встановлена (немає доступу до smali UI).
6. **`AiDialogUiState.allowExternalAi`** — поле є, місце використання в UI не знайдено.
7. **Критерій сортування** черги в `SpeakingViewModel.load()` (`sortedByDescending { … }`) — не встановлено.
8. **Формат `id`** промптів (`sp_word_`/`sp_sent_`/`sp_ex_`) відомий лише за префіксами; повний шаблон
   (що саме додається після префікса) — текст не знайдено.
9. **Точні номери рядків** для внутрішніх елементів `ChatPhase` (LazyColumn, поле вводу, кнопки) наведені
   за Compose-метаданими і можуть відрізнятися на ±2 рядки; підписи кнопок і лямбд — точні.
10. **`AIMessage` / `AICorrection` / `AIRequest` / `AIResponse`** — поля відновлені з `toString`-констант і
    сигнатур викликів; порядок полів у конструкторах не перевірявся (файл `AIProvider.kt` у дампі smali відсутній).
