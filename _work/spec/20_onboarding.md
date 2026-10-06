# 20. Онбординг і тест на рівень

Джерела: `ua/krupa/spanish/ui/screens/onboarding/OnboardingScreen.kt`, `.../OnboardingViewModel.kt`,
`ua/krupa/spanish/learning/assessment/PlacementTest.kt`, а також `ui/AppRoot.kt` (точка входу).
Рядки в дужках (`OnboardingScreen.kt:150`) — номери рядків оригіналу, відновлені з Compose-метаданих
(`C<line>@<offset>L<len>`) і з таблиць `positions` у smali.

---

## 1. Призначення й місце в застосунку

### 1.1 Коли показується

Єдиний вхід — `AppRootKt.AppRoot` (`ui/AppRoot.kt:53+`). Послідовність гілок:

| Умова | Що показується |
| --- | --- |
| `state.loading == true` | `LoadingScreen()` (`AppRoot.kt:55`) |
| `state.needsOnboarding == true` | `OnboardingScreen(container, onFinished)` (`AppRoot.kt:60-62`) |
| `state.contentReady == false` | `ContentMissingScreen()` (`AppRoot.kt:71`) |
| інакше | `AppNavHost(...)` (`AppRoot.kt:112`) |

Умова показу — обчислювана властивість `MainUiState.needsOnboarding` (`ui/MainViewModel.kt`):

```
needsOnboarding = forceOnboarding || (!profileExists && !learningStarted && !loading)
```

(байт-код `MainUiState.getNeedsOnboarding` — послідовні `if-nez` по `forceOnboarding`,
`profileExists`, `learningStarted`, `loading`).

Сигнатура композабла: `OnboardingScreen(container: AppContainer, onFinished: (UserProfile) -> Unit)`
(літерал-лямбда `AppRootKt$AppRoot$2$1` захоплює `onProfileSaved` і `onShowOnboarding`).

### 1.2 Як визначається завершення

1. Користувач на кроці `RESULT` натискає `"Почати навчання"` → `PrimaryActionButton(onClick = { viewModel.finish { onFinished() } })`
   (лямбда `OnboardingScreen$1$8`: `viewModel.finish($onFinished)`).
2. `OnboardingViewModel.finish(onSaved)` у `viewModelScope`:
   * будує `UserProfile`;
   * `container.users.saveProfile(profile)` (`UserRepository`);
   * `onSaved(Unit)` → у `AppRoot` це `{ profile -> onProfileSaved(profile); onShowOnboarding(false) }`,
     тобто після збереження `forceOnboarding` скидається в `false` і онбординг більше не показується.

### 1.3 Що саме зберігається в профіль

З `OnboardingViewModel$finish$1.invokeSuspend` (порядок аргументів конструктора
`UserProfile(String name, Level level, boolean assessmentDone, int assessmentScore, LearningGoal goal, int dailyMinutes, long startedAt, ThemeMode, String, float, boolean, boolean, String, String, String, String)`):

| Поле `UserProfile` | Значення з онбордингу |
| --- | --- |
| `name` | `state.name.trim()` |
| `level` | `state.chosenLevel` (= `manualLevel ?: result?.level ?: Level.A0`) |
| `assessmentDone` | `state.testFinished` (= `result != null`) |
| `assessmentScore` | `state.result.percent` (0, якщо результату немає) |
| `goal` | `state.goal` |
| `dailyMinutes` | `state.dailyMinutes` |
| `startedAt` | `System.currentTimeMillis()` |
| `themeMode`, `ttsRate`, `ttsVoiceGender`, `allowExternalAi`, `showListeningHints`, `aiProviderId`, `aiModel`, `aiEndpoint`, `aiApiKey` | не передаються — беруть дефолтні значення data-класу |

### 1.4 Ініціалізація

* `OnboardingViewModelFactory(container) : ViewModelProvider.Factory` → `OnboardingViewModel(container)`.
* Конструктор VM: `OnboardingUiState()` (усі поля за замовчуванням) → одразу
  `copy(speakingAvailable = container.speechRecognizer.isAvailable)`, потім `MutableStateFlow` + `asStateFlow()`.
* Усі дії VM записують стан як `_state.value = _state.value.copy(...)` (без `update {}`).

---

## 2. `Step` — послідовність кроків

`enum class Step` (`OnboardingViewModel.kt`, порядок з `Step.$values`/`<clinit>`):

| Ordinal | Enum-константа | Що показує | Дії користувача |
| --- | --- | --- | --- |
| 0 | `WELCOME` | Привітання `"KRUPA_Spanish"`, підзаголовок, банер про приватність, поле імені, банер «що далі» | ввести ім'я (необов'язково), `"Далі"` |
| 1 | `GOAL` | `"Навіщо вам іспанська?"` + 5 карток цілей | вибір цілі (одразу, кнопки «підтвердити» немає) |
| 2 | `TIME` | `"Скільки часу на день?"` + чипси `10/20/30/45/60` + `"Обрано: N хв на день"` + приклад розкладу заняття | вибір хвилин; далі `"Далі"` |
| 3 | `TEST_INTRO` | `"Перевіримо рівень"`, опис тесту, банер про відсутній розпізнавач мовлення, банер про зміну рівня | `"Почати тест"` або `"Пропустити тест і почати з A0"` |
| 4 | `TEST` | Питання тесту (прогрес, стимул, аудіо, варіанти, правильна відповідь, самоперевірка) | вибір варіанта / `"Прослухати"` / `"Не знаю"` / `"Сказав правильно"` / `"Пропустити питання"` |
| 5 | `RESULT` | `"Ваш стартовий рівень"`, бал, рекомендація, слабкі теми, вибір рівня вручну | вибір рівня; `"Почати навчання"` |

### 2.1 Точний порядок показу

У `when (state.step)` (лямбда `OnboardingScreen$1`) гілки йдуть **у порядку ordinal**:

| Крок | Виклик | Рядок у `OnboardingScreen.kt` |
| --- | --- | --- |
| `WELCOME` | `WelcomeStep(state.name, ::onNameChanged)` | 84 |
| `GOAL` | `GoalStep(state.goal, ::onGoalSelected)` | 89 |
| `TIME` | `TimeStep(state.dailyMinutes, ::onMinutesSelected)` | 94 |
| `TEST_INTRO` | `TestIntroStep(state.speakingAvailable)` | 99 |
| `TEST` | `TestStep(state, ::answer, ::speak)` | 101 |
| `RESULT` | `ResultStep(state, ::chooseLevel, { viewModel.finish { onFinished() } })` | 112 |

> У байт-коді гілки скомпільовані у зворотному порядку (`ResultStep` першим) — це наслідок
> `$EnumSwitchMapping$0`; порядок у джерелі задають номери рядків 84 → 112.
> Жодного `AnimatedContent`/`Crossfade` навколо `when` немає.

### 2.2 Переходи (`next` / `back` / `skipTest`)

`next()`:

| Поточний крок | Результат |
| --- | --- |
| `WELCOME` | `step = GOAL` |
| `GOAL` | `step = TIME` |
| `TIME` | `step = TEST_INTRO` |
| `TEST_INTRO` | `step = TEST` |
| `TEST` | без змін |
| `RESULT` | без змін |

`back()`:

| Поточний крок | Результат |
| --- | --- |
| `WELCOME` | без змін |
| `GOAL` | `step = WELCOME` |
| `TIME` | `step = GOAL` |
| `TEST_INTRO` | `step = TIME` |
| `TEST` | якщо `questionIndex > 0` → `questionIndex - 1`, інакше `step = TEST_INTRO` |
| `RESULT` | `step = TEST` |

`skipTest()`: `result = PlacementTest.evaluate(emptyMap())`, `manualLevel = Level.A0`, `step = RESULT`.

Кнопка `"Назад"` показується лише коли `state.canGoBack` (`step != WELCOME`).

### 2.3 Що видно в `OnboardingUiState`

Стан — єдине джерело істини: `step` визначає екран, `canGoBack` — наявність кнопки «Назад»,
`chosenLevel`/`testFinished`/`question`/`progressFraction` — похідні для UI (див. §3).

---

## 3. `OnboardingUiState` — повний перелік полів

Data-клас, 9 полів; конструктор
`(Step, String, LearningGoal, int, int, Map, PlacementTest.TestResult, Level, boolean)`.

| Поле | Тип | Призначення | Значення за замовчуванням |
| --- | --- | --- | --- |
| `step` | `Step` | поточний крок онбордингу | `Step.WELCOME` (перший показаний екран) |
| `name` | `String` | ім'я користувача з `WelcomeStep` (обрізається до 40 символів у `onNameChanged`) | не встановлено (дефолт data-класу; див. «Прогалини») |
| `goal` | `LearningGoal` | обрана ціль | не встановлено (див. «Прогалини») |
| `dailyMinutes` | `Int` | хвилин на день | не встановлено (див. «Прогалини») |
| `questionIndex` | `Int` | індекс поточного питання тесту | `0` |
| `answers` | `Map<String, Boolean>` | `questionId → правильність` | `emptyMap()` |
| `result` | `PlacementTest.TestResult?` | результат тесту (є після останньої відповіді або скіпа) | `null` |
| `manualLevel` | `Level?` | рівень, обраний вручну на `RESULT` | `null` |
| `speakingAvailable` | `Boolean` | чи доступне розпізнавання мовлення | `false`, потім `container.speechRecognizer.isAvailable` |

Обчислювані властивості (не поля):

| Властивість | Тип | Обчислення |
| --- | --- | --- |
| `canGoBack` | `Boolean` | `step != Step.WELCOME` |
| `chosenLevel` | `Level` | `manualLevel ?: result?.level ?: Level.A0` |
| `testFinished` | `Boolean` | `result != null` |
| `question` | `PlacementTest.Question?` | `PlacementTest.questions.getOrNull(questionIndex)` |
| `progressFraction` | `Float` | `if (questions.isEmpty()) 0f else questionIndex / questions.size` |

Рівність/`hashCode`/`toString` — стандартні для data-класу (`toString` починається з `OnboardingUiState(step=`).

---

## 4. `OnboardingViewModel` — дії

| Метод | Параметри | Що робить | Вплив на стан |
| --- | --- | --- | --- |
| `next()` | — | наступний крок по `when` (§2.2) | `copy(step = …)` |
| `back()` | — | попередній крок; на `TEST` — крок назад по питаннях | `copy(step = …)` / `copy(questionIndex = questionIndex - 1)` |
| `skipTest()` | — | пропуск тесту з рівнем A0 | `copy(step = RESULT, result = PlacementTest.evaluate(emptyMap()), manualLevel = Level.A0)` |
| `chooseLevel(level)` | `Level` | ручний вибір рівня на `RESULT` | `copy(manualLevel = level)` |
| `onNameChanged(value)` | `String` | запис імені (обрізає до 40) | `copy(name = value.take(40))` |
| `onGoalSelected(goal)` | `LearningGoal` | вибір цілі | `copy(goal = goal)` |
| `onMinutesSelected(minutes)` | `Int` | вибір хвилин на день | `copy(dailyMinutes = minutes)` |
| `answer(questionId, correct)` | `String`, `Boolean` | фіксує відповідь: `answers + (questionId to correct)`; `nextIndex = questionIndex + 1` | якщо `nextIndex < questions.size` → `copy(questionIndex = nextIndex, answers = answers)`; інакше → `copy(step = RESULT, answers = answers, result = PlacementTest.evaluate(answers))` |
| `finish(onSaved)` | `(Unit) -> Unit` | `viewModelScope.launch { … saveProfile(profile); onSaved(Unit) }` | стан не змінює |
| `getState()` | — | повертає `StateFlow<OnboardingUiState>` | — |

Публічне поле `state: StateFlow<OnboardingUiState>`; приватні `_state: MutableStateFlow`, `container: AppContainer`.

---

## 5. Екран — детально по кожному кроці

### 5.0 Спільний каркас `OnboardingScreen` (`OnboardingScreen.kt:63-142`)

```
Column(
    modifier = Modifier.fillMaxSize().padding(...),
    verticalArrangement = Arrangement.spacedBy(...),
    horizontalAlignment = Alignment.Start
) {
    if (state.canGoBack)                                                       // :76
        TextButton(onClick = { viewModel.back() }) { Text("Назад") }           // :77

    when (state.step) { /* §5.1-5.6 */ }                                       // :84-117

    if (state.step != Step.TEST && state.step != Step.RESULT) {                // :120
        Spacer(Modifier.height(4.dp))                                          // :121
        PrimaryActionButton(                                                   // :121-131
            title = if (state.step == Step.TEST_INTRO) "Почати тест" else "Далі",
            onClick = { viewModel.next() }
        )
    }
    if (state.step == Step.TEST_INTRO)                                         // :132
        TextButton(onClick = { viewModel.skipTest() },
                   modifier = Modifier.fillMaxWidth()) { Text("Пропустити тест і почати з A0") }  // :136
}
```

| Елемент | Текст дослівно | Стан / умова |
| --- | --- | --- |
| Кнопка-посилання | `"Назад"` | лише якщо `state.canGoBack` (тобто не на `WELCOME`) |
| Основна кнопка | `"Далі"` / `"Почати тест"` | `"Почати тест"` — лише на `TEST_INTRO`; **не показується** на `TEST` і `RESULT`; завжди активна |
| Кнопка-посилання | `"Пропустити тест і почати з A0"` | лише на `TEST_INTRO`, `Modifier.fillMaxWidth()` |

**Індикатора «Крок N з 4» в застосунку немає** — прогрес показується лише всередині тесту
(`"Питання N з 12"`, §5.5). Це не прогалина, а відсутній елемент.

### 5.1 `WelcomeStep` (`OnboardingScreen.kt:144-176`)

```
Column(spacedBy, Start) {
    Text("KRUPA_Spanish", style = Typography.displaySmall)                        // :147
    Text("Іспанська мова Іспанії — з нуля до впевненого спілкування.",
         style = Typography.titleMedium, color = colorScheme.onSurfaceVariant)    // :150-151
    Spacer(Modifier.height(8.dp))                                                 // :152
    InfoBanner("Без реєстрації, без пароля й без акаунта. Увесь прогрес зберігається
                лише на цьому пристрої — і його можна перенести файлом JSON.")     // :155-158 (кольори типові)
    Spacer(Modifier.height(8.dp))                                                 // :157
    Text("Як до вас звертатися? (необов'язково)", style = Typography.titleSmall)  // :159
    OutlinedTextField(                                                            // :160-168
        value = name,
        onValueChange = { viewModel.onNameChanged(it) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        shape = RoundedCornerShape(14.dp),
        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
        placeholder = { Text("Ім'я") },      // label = null
    )
    Spacer(Modifier.height(8.dp))                                                 // :169
    InfoBanner("Далі — три короткі питання й тест на 12 завдань. Це займе близько трьох хвилин.",
               containerColor = colorScheme.secondaryContainer,
               contentColor   = colorScheme.onSecondaryContainer)                 // :169-175
}
```

Тексти дослівно: `"KRUPA_Spanish"`, `"Іспанська мова Іспанії — з нуля до впевненого спілкування."`,
`"Без реєстрації, без пароля й без акаунта. Увесь прогрес зберігається лише на цьому пристрої — і його можна перенести файлом JSON."`,
`"Як до вас звертатися? (необов'язково)"`, `"Ім'я"`, `"Далі — три короткі питання й тест на 12 завдань. Це займе близько трьох хвилин."`

Валідації немає: поле необов'язкове, кнопка `"Далі"` активна завжди.
Після натискання — `next()` → `GOAL`.

### 5.2 `GoalStep` (`OnboardingScreen.kt:178-196`)

```
Column(spacedBy, Start) {
    Text("Навіщо вам іспанська?", style = Typography.headlineSmall)                       // :181
    Text("Ціль впливає на теми, які застосунок пропонуватиме частіше.",
         style = Typography.bodyMedium, color = colorScheme.onSurfaceVariant)             // :184-185
    for (goal in LearningGoal.entries) {                                                  // :187
        SelectableCard(                                                                   // :189-192
            title    = goal.titleUk,
            subtitle = goal.descriptionUk,
            selected = goal == selected,
            onClick  = remember(goal) { { onSelect(goal) } }
        )
    }
}
```

Варіанти — у порядку оголошення `LearningGoal` (5 карток):

| # | Enum | Заголовок (`titleUk`) | Підзаголовок (`descriptionUk`) |
| --- | --- | --- | --- |
| 0 | `TRAVEL` | `"Подорожі"` | `"Розмови в аеропорту, готелі, кафе, на вулиці"` |
| 1 | `WORK` | `"Робота"` | `"Ділове листування, зустрічі, професійна лексика"` |
| 2 | `STUDY` | `"Навчання"` | `"Іспити, університет, сертифікати DELE"` |
| 3 | `RELOCATION` | `"Переїзд"` | `"Побут, документи, оренда житла, лікарі"` |
| 4 | `COMMUNICATION` | `"Спілкування"` | `"Друзі, серіали, музика, інтернет"` |

Активний варіант — той, у якого `goal == state.goal` (візуально виділений, див. §7.2).
Натискання одразу викликає `onGoalSelected(goal)`; кнопки «продовжити» на кроці немає.

### 5.3 `TimeStep` (`OnboardingScreen.kt:198-222`)

```
Column(spacedBy, Start) {
    Text("Скільки часу на день?", style = Typography.headlineSmall)                        // :200
    Text("Застосунок сам складе заняття з потрібних частин: повторення, нові слова,
          граматика, аудіювання, говоріння.",
         style = Typography.bodyMedium, color = colorScheme.onSurfaceVariant)              // :204-206
    ChoiceChipsRow(                                                                        // :212-217
        options  = listOf(10, 20, 30, 45, 60),
        selected = minutes,
        labelOf  = { it.toString() },          // підписи — просто числа, без « хв»
        onSelect = { onSelect(it) }
    )
    Text("Обрано: " + minutes + " хв на день",                                             // :215-217
         style = Typography.bodyMedium, color = colorScheme.onSurfaceVariant)
    Spacer(Modifier.height(<dp>))                                                          // :219
    ExampleSplit(minutes)                                                                  // :221
}
```

| Параметр | Значення |
| --- | --- |
| Варіанти хвилин | `10`, `20`, `30`, `45`, `60` (рівно 5; `listOf(10, 20, 30, 45, 60)`) |
| Підпис чипса | `"10"`, `"20"`, `"30"`, `"45"`, `"60"` — `String.valueOf(it)` |
| Обраний | той, що дорівнює `state.dailyMinutes` |
| Текст-підсумок | шаблон `"Обрано: %d хв на день"` → напр. `"Обрано: 20 хв на день"` |
| Після натискання | `onMinutesSelected(v)` → `dailyMinutes = v`; одразу перемальовується підсумок і `ExampleSplit` |

### 5.4 `TestIntroStep` (`OnboardingScreen.kt:249-271`)

```
Column(spacedBy, Start) {
    Text("Перевіримо рівень", style = Typography.headlineSmall)                            // :251
    Text("12 завдань: слова, граматика, розуміння, аудіювання, переклад і складання
          речень. Якщо не знаєте відповіді — просто натисніть «Не знаю»:
          так результат буде чеснішим.",
         style = Typography.bodyLarge)                                                      // :252-256
    if (!speakingAvailable)                                                                 // :258
        InfoBanner("У системі не знайдено сервіс розпізнавання мовлення.
                    Вправи на говоріння працюватимуть у режимі самоперевірки.")             // :258-262
    InfoBanner("Рівень можна буде змінити вручну в будь-який момент у Налаштуваннях.",
               containerColor = colorScheme.secondaryContainer,
               contentColor   = colorScheme.onSecondaryContainer)                           // :264-268
}
```

Тексти дослівно: `"Перевіримо рівень"`,
`"12 завдань: слова, граматика, розуміння, аудіювання, переклад і складання речень. Якщо не знаєте відповіді — просто натисніть «Не знаю»: так результат буде чеснішим."`,
`"У системі не знайдено сервіс розпізнавання мовлення. Вправи на говоріння працюватимуть у режимі самоперевірки."`,
`"Рівень можна буде змінити вручну в будь-який момент у Налаштуваннях."`

Перший банер має **типові** кольори `InfoBanner` (`tertiaryContainer`/`onTertiaryContainer`) — у виклику
кольори не передаються (маска дефолтів `0b1110`); другий банер — `secondaryContainer`/`onSecondaryContainer`.
Єдине використання параметра `speakingAvailable` — умова показу першого банера.

Кнопки кроку — у спільному футері: `"Почати тест"` (→ `next()` → `TEST`) і
`"Пропустити тест і почати з A0"` (→ `skipTest()` → `RESULT` з рівнем A0 і `percent = 0`).

### 5.5 `TestStep` (`OnboardingScreen.kt:277-378`)

```
val question = state.question ?: return                                        // :280
Column(spacedBy, Start) {
    Text("Питання " + (state.questionIndex + 1) + " з " + PlacementTest.questions.size,
         style = Typography.labelLarge, color = colorScheme.onSurfaceVariant)   // :283-284
    LinearProgressIndicator(                                                    // :286-293
        progress = { state.progressFraction },
        modifier = Modifier.fillMaxWidth().height(<dp>),
        strokeCap = StrokeCap.Round, …
    )
    Text(question.promptUk, style = getPromptStyle())                           // :295-296

    if (question.stimulusEs.isNotBlank() && !question.isAudio) {                // :296
        Card(modifier = Modifier.fillMaxWidth(),
             colors = CardDefaults.cardColors(containerColor = colorScheme.surfaceVariant)) {
            Text(question.stimulusEs)                                           // :298-311
        }
    }
    if (question.isAudio) {                                                     // :312
        OutlinedButton(onClick = { onSpeak(question.stimulusEs) },
                       modifier = Modifier.fillMaxWidth(),
                       shape = RoundedCornerShape(14.dp),
                       contentPadding = PaddingValues(...)) {
            Text("Прослухати")                                                  // :318
        }
    }
    if (question.options.isNotEmpty()) {                                        // :326
        question.options.forEachIndexed { index, option ->
            OutlinedButton(onClick = { onAnswer(question.id, index == question.correctOption) },
                           modifier = Modifier.fillMaxWidth(),
                           shape = RoundedCornerShape(14.dp),
                           contentPadding = PaddingValues(...)) {
                Text(option)                                                    // :332-334
            }
        }
    }
    Text("Скажіть уголос, а потім порівняйте з відповіддю.",
         style = Typography.bodyMedium, color = colorScheme.onSurfaceVariant)   // :343-344
    Card(modifier = Modifier.fillMaxWidth(),
         colors = CardDefaults.cardColors(containerColor = colorScheme.secondaryContainer)) {
        Column(spacedBy) {
            Text("Правильна відповідь")                                         // :351
            Text(question.correctAnswer)                                        // :353
        }
    }                                                                           // :346-355
    Row(horizontalArrangement = spacedBy, verticalAlignment = Alignment.Top) {
        OutlinedButton(onClick = { onAnswer(question.id, false) },
                       modifier = Modifier.weight(1f)) { Text("Не знаю") }      // :357-360
        Button(onClick = { onAnswer(question.id, true) },
               modifier = Modifier.weight(1f)) { Text("Сказав правильно") }     // :361-366
    }
    TextButton(onClick = { onAnswer(question.id, false) },
               modifier = Modifier.fillMaxWidth()) { Text("Пропустити питання") }  // :368-370
}
```

Усі видимі тексти кроку:

| Текст дослівно | Де | Умова |
| --- | --- | --- |
| `"Питання "` + `(questionIndex + 1)` + `" з "` + `questions.size` | шапка | завжди (напр. `"Питання 1 з 12"`) |
| стимул `question.stimulusEs` | картка `surfaceVariant` | лише якщо стимул непорожній **і** `isAudio == false` |
| `"Прослухати"` | `OutlinedButton` | лише якщо `question.isAudio == true` |
| текст варіанта (`question.options[i]`) | `OutlinedButton` на всю ширину, по одному на варіант | лише якщо `options` непорожній |
| `"Скажіть уголос, а потім порівняйте з відповіддю."` | підказка | завжди |
| `"Правильна відповідь"` + `question.correctAnswer` | картка `secondaryContainer` | завжди |
| `"Не знаю"` | `OutlinedButton`, `weight(1f)` | завжди |
| `"Сказав правильно"` | `Button`, `weight(1f)` | завжди |
| `"Пропустити питання"` | `TextButton` на всю ширину | завжди |

**Прогрес тесту**: дробовий `LinearProgressIndicator` зі значенням `state.progressFraction`
(= `questionIndex / questions.size`, тобто 0 на першому питанні й 11/12 на останньому) та текст
`"Питання N з 12"` (`LabelLarge`, `onSurfaceVariant`).

**Позначення вибраної відповіді відсутнє**: варіанти — звичайні `OutlinedButton` без стану
`selected`; вибір не підсвічується, бо одразу фіксується й перегортає питання
(`onAnswer(id, index == correctOption)`), а наступний кадр показує вже нове питання.
Правильність не показується користувачеві (бали не виводяться).

**Що відбувається після натискання**:

| Кнопка | Виклик | Наслідок |
| --- | --- | --- |
| варіант відповіді | `onAnswer(question.id, index == question.correctOption)` | якщо це не останнє питання → `questionIndex + 1`; якщо останнє → `step = RESULT`, `result = evaluate(answers)` |
| `"Прослухати"` | `onSpeak(question.stimulusEs)` | озвучує стимул (TTS через `container.ttsEngine`, запуск у `rememberCoroutineScope`) |
| `"Не знаю"` | `onAnswer(question.id, false)` | те саме, що «неправильна відповідь» |
| `"Сказав правильно"` | `onAnswer(question.id, true)` | те саме, що «правильна відповідь» |
| `"Пропустити питання"` | `onAnswer(question.id, false)` | питання зараховується як неправильне |

> У байт-коді між циклом варіантів (`:326-340`) і кінцем функції **немає жодного розгалуження**,
> тому блок `:341-368` (підказка, правильна відповідь, `"Не знаю"`/`"Сказав правильно"`,
> `"Пропустити питання"`) рендериться для **кожного** питання, зокрема й для множинного вибору.

### 5.6 `ResultStep` (`OnboardingScreen.kt:379-435`)

```
val result = state.result ?: return                                            // :380
Column(spacedBy, Start) {
    Text("Ваш стартовий рівень", style = Typography.headlineSmall)              // :383
    if (state.manualLevel == null) {                                            // :386
        Card(modifier = Modifier.fillMaxWidth(),
             colors = CardDefaults.cardColors(containerColor = colorScheme.primary)) {
            Column(spacedBy) {
                Text(result.level.code + " — " + result.level.titleUk,         // :391-395
                     style = Typography.headlineSmall, color = colorScheme.onPrimary)
                Text("Бал: " + result.score + " з " + result.maxScore +
                     " (" + result.percent + "%)",                             // :396-401
                     style = Typography.bodyMedium, color = colorScheme.onPrimary)
            }
        }
    }
    Text(result.recommendationUk, style = Typography.bodyLarge)                 // :404-405
    if (result.weakAreasUk.isNotEmpty())                                        // :406
        InfoBanner("Варто підсилити: " + result.weakAreasUk +
                   ". Застосунок додаватиме більше вправ на ці теми.",
                   icon = Icons.Filled.Insights)                                // :406-411
    if (state.manualLevel != null)                                              // :412
        Text("Обрано вручну: " + state.manualLevel.code + " — " + state.manualLevel.titleUk,
             style = Typography.bodyLarge)                                      // :412-415
    Spacer(Modifier.height(4.dp))                                               // :418
    Text("Рівень можна змінити:", style = Typography.titleSmall)                // :419-420
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {                  // :420-430
        for (level in Level.mvpLevels) {                                        // :422
            SelectableCard(
                title    = level.code + " — " + level.titleUk,
                subtitle = level.descriptionUk,
                selected = level == state.chosenLevel,
                onClick  = remember(level) { { onLevelChosen(level) } }
            )                                                                   // :424-429
        }
    }
    Spacer(Modifier.height(8.dp))                                               // :431
    PrimaryActionButton(title = "Почати навчання", onClick = onStart)           // :432-435
}
```

Тексти дослівно:

| Текст | Умова |
| --- | --- |
| `"Ваш стартовий рівень"` | завжди |
| `"<code> — <titleUk>"` (напр. `"A1 — Базове спілкування"`) у картці `primary` | лише якщо `manualLevel == null` |
| `"Бал: <score> з <maxScore> (<percent>%)"` (напр. `"Бал: 9 з 12 (75%)"`) | лише якщо `manualLevel == null` |
| `result.recommendationUk` — одне з чотирьох речень (§6.5) | завжди |
| `"Варто підсилити: <weakAreasUk>. Застосунок додаватиме більше вправ на ці теми."` | лише якщо `weakAreasUk` непорожній; банер з іконкою `Icons.Filled.Insights` |
| `"Обрано вручну: <code> — <titleUk>"` | лише якщо `manualLevel != null` |
| `"Рівень можна змінити:"` | завжди |
| картки рівнів: заголовок `"<code> — <titleUk>"`, підзаголовок `descriptionUk` | `mvpLevels = [A0, A1, A2]` |
| `"Почати навчання"` | завжди; `PrimaryActionButton` → `finish { onFinished() }` |

Варіанти ручного вибору рівня (лише MVP-рівні, порядок `A0 → A1 → A2`):

| Рівень | Заголовок картки | Підзаголовок |
| --- | --- | --- |
| `A0` | `"A0 — Повний нуль"` | `"Перші слова, звуки, прості фрази"` |
| `A1` | `"A1 — Базове спілкування"` | `"Знайомство, числа, час, прості питання"` |
| `A2` | `"A2 — Повсякденні ситуації"` | `"Магазин, транспорт, здоров'я, побут"` |

Позначений як обраний той рівень, що дорівнює `state.chosenLevel` (тобто після ручного вибору —
саме обраний, до вибору — рівень із результату тесту; після `skipTest` — `A0`).
Натискання картки → `chooseLevel(level)` (екран одразу перемальовується: замість картки з балом
з'являється `"Обрано вручну: …"`).

---

## 6. Placement test

### 6.1 Джерело й формат

* `object PlacementTest` (`learning/assessment/PlacementTest.kt`): `INSTANCE`, `questions: List<Question>`, `evaluate(answers: Map<String, Boolean>): TestResult`.
* Питань — **12**, у коді (id `"pt_01"`…`"pt_12"`, підтверджується текстом `"…тест на 12 завдань…"` і `"12 завдань: …"`).
* Отримання питання в UI: `state.question` → `PlacementTest.questions.getOrNull(questionIndex)`.
* Поля `Question` (з дескриптора та рядкових констант класу `PlacementTest$Question`):

| Поле | Тип | Використання в UI |
| --- | --- | --- |
| `id` | `String` | ключ у `answers` |
| `kind` | (enum, напр. `ExerciseKind`) | у UI онбордингу не читається |
| `level` | `Level` | для `byLevel` і вибору рівня |
| `promptUk` | `String` | заголовок питання |
| `stimulusEs` | `String` | картка стимулу (текстові питання) та джерело для TTS |
| `options` | `List<String>` | варіанти відповіді |
| `correctOption` | `Int` | індекс правильної опції |
| `correctAnswer` | `String` | текст у картці `"Правильна відповідь"` |
| `tokens` | `List<String>` | для завдань на складання речення (у UI `TestStep` не використовується) |
| `tag` | `GrammarTag` | для `wrongTags` |
| `weight` | `Int` | вага в балах |
| `explanationUk` | `String` | у UI онбордингу не показується |
| `isAudio` | `Boolean` | ховає стимул, показує `"Прослухати"` |

### 6.2 Як рахується результат

`evaluate(answers)` (псевдокод за байт-кодом; див. також `spec/02_learning_engine.md` §7.2):

```
score = 0; maxScore = 0; byLevelPoints = LinkedHashMap<Level, Pair<Int,Int>>()
for (q in questions) {
    correct = (answers[q.id] == true)
    maxScore += q.weight
    if (correct) score += q.weight
    byLevelPoints[q.level] = (correct ? +q.weight : 0) to +q.weight
}
percent = if (maxScore == 0) 0 else score * 100 / maxScore        // цілочисельне ділення
level = найвищий з mvpLevels (A2 → A1 → A0), у якого (correct*100/total) >= 60; інакше A0
byLevel = percent за кожним рівнем (0, якщо total == 0)
wrongTags = questions.filter { answers[it.id] != true }.map { it.tag }.distinct()
```

| Питання | Відповідь |
| --- | --- |
| Скільки всього балів | сума `weight` усіх 12 питань (`maxScore`) |
| Поріг рівня | ≥ 60 % ваг **у межах рівня**, перевірка від вищого рівня до нижчого |
| Рівень за замовчуванням | `A0` (зокрема при `skipTest()` — `evaluate(emptyMap())`) |
| Що зберігається | `result.percent` → `UserProfile.assessmentScore`; `result != null` → `assessmentDone = true` |

### 6.3 Тексти питань (дослівно, з `PlacementTest`)

Питання (`promptUk`) — 12 рядків:

1. `"Як іспанською «привіт»?"`
2. `"Перекладіть іспанською: «Дякую»"`
3. `"Виберіть правильну форму: Yo ___ estudiante."`
4. `"Виберіть правильний артикль: ___ casa"`
5. `"Як сказати «Мені подобається кава»?"`
6. `"Заповніть пропуск: «Я йду до магазину» — Voy ___ supermercado."`
7. `"Заповніть пропуск: «Я вивчаю іспанську два роки» — Estudio español ___ dos años."`
8. `"Виберіть правильний минулий час: Ayer ___ al cine."`
9. `"Перекладіть іспанською: «Я вже поїв»"`
10. `"Складіть речення: «Я хочу каву»"`
11. `"Прослухайте й виберіть, що почули"`
12. `"Прослухайте речення й виберіть переклад"`

Пояснення (`explanationUk`) — 12 рядків:

* `"«Hola» — універсальне вітання будь-коли."`
* `"«Gracias» — дякую."`
* `"Професія й статус — це ser: soy estudiante."`
* `"«Casa» — жіночого роду, тому la casa."`
* `"У конструкції gustar підмет — сама річ: me gusta el café."`
* `"a + el завжди зливається в al."`
* `"«Desde hace» описує дію, яка почалася в минулому й триває досі."`
* `"«Ayer» вимагає завершеного минулого: fui (pretérito indefinido)."`
* `"He comido — складений минулий час, коли результат важливий зараз."`
* `"Після querer дія стоїть в інфінітиві, але тут дія — іменник: quiero un café."`
* `"«Buenos días» — доброго ранку."`
* `"«Ir a + інфінітив» — найпростіший спосіб сказати про майбутнє."`

Іспанські рядки банку (варіанти, правильні відповіді, стимули) — повний перелік:

`"hola"`, `"gracias"`, `"adiós"`, `"Buenas noches"`, `"Buenos días"`, `"Hasta luego"`, `"Mucho gusto"`,
`"soy"`, `"estoy"`, `"tengo"`, `"hago"`, `"voy"`, `"quiero"`, `"fui"`, `"la"`, `"el"`, `"los"`, `"las"`,
`"un"`, `"de"`, `"en"`, `"por"`, `"para"`, `"al"`, `"a el"`, `"durante"`, `"desde hace"`,
`"por favor"`, `"café"`, `"Yo"`, `"Yo quiero un café"`, `"Me gusta el café"`, `"Me gustan el café"`,
`"Me gusto el café"`, `"Yo gusto café"`, `"Ya he comido"`, `"he ir"`, `"iba a ir"`,
`"Mañana voy a visitar a mi familia"`.

Українські рядки-варіанти для аудіопитання: `"Завтра я відвідаю свою родину"`, `"Учора я відвідав свою родину"`,
`"Сьогодні я з родиною"`, `"Я хочу велику родину"`.

### 6.4 Реконструкція банку (id ↔ текст)

Точного зіставлення `id` з текстами в наявних джерелах **немає** (`PlacementTest.kt` не входив у витяг
`ui/`, а повний smali було видалено під час роботи). Нижче — реконструкція за парами
«питання ↔ пояснення ↔ правильна відповідь»; рівні взято з `spec/02_learning_engine.md` §7.1
(A0 — 1 питання, A1 — 7, A2 — 4), і вона дає ті самі 12 питань і той самий розподіл рівнів:

| id | Рівень | `promptUk` | Правильна відповідь | `explanationUk` |
| --- | --- | --- | --- | --- |
| `pt_01` | A0 | Як іспанською «привіт»? | `hola` | «Hola» — універсальне вітання будь-коли. |
| `pt_02` | A1 | Перекладіть іспанською: «Дякую» | `gracias` | «Gracias» — дякую. |
| `pt_03` | A1 | Виберіть правильну форму: Yo ___ estudiante. | `soy` | Професія й статус — це ser: soy estudiante. |
| `pt_04` | A1 | Виберіть правильний артикль: ___ casa | `la` | «Casa» — жіночого роду, тому la casa. |
| `pt_05` | A1 | Як сказати «Мені подобається кава»? | `Me gusta el café` | У конструкції gustar підмет — сама річ: me gusta el café. |
| `pt_06` | A1 | Заповніть пропуск: «Я йду до магазину» — Voy ___ supermercado. | `al` | a + el завжди зливається в al. |
| `pt_07` | A1 | Заповніть пропуск: «Я вивчаю іспанську два роки» — Estudio español ___ dos años. | `desde hace` | «Desde hace» описує дію, яка почалася в минулому й триває досі. |
| `pt_08` | A1 | Виберіть правильний минулий час: Ayer ___ al cine. | `fui` | «Ayer» вимагає завершеного минулого: fui (pretérito indefinido). |
| `pt_09` | A1 | Перекладіть іспанською: «Я вже поїв» | `Ya he comido` | He comido — складений минулий час, коли результат важливий зараз. |
| `pt_10` | A2 | Складіть речення: «Я хочу каву» | `Yo quiero un café` | Після querer дія стоїть в інфінітиві, але тут дія — іменник: quiero un café. |
| `pt_11` | A2 | Прослухайте й виберіть, що почули | `Buenos días` | «Buenos días» — доброго ранку. |
| `pt_12` | A2 | Прослухайте речення й виберіть переклад | `Mañana voy a visitar a mi familia` | «Ir a + інфінітив» — найпростіший спосіб сказати про майбутнє. |

Розподіл варіантів (реконструкція; у коді вони існують, але поштучне прикріплення не підтверджено):

* Дієслово `ser` (pt_03): `soy`, `estoy`, `tengo`, `hago`.
* Артикль (pt_04): `la`, `el`, `los`, `las`.
* `gustar` (pt_05): `Me gusta el café`, `Me gustan el café`, `Me gusto el café`, `Yo gusto café`.
* Прийменник напрямку (pt_06): `al`, `a el`, `en`, `de`, `para`, `por`.
* Часова конструкція (pt_07): `desde hace`, `durante`, `por`, `para`.
* Минулий час (pt_08): `fui`, `voy`, `he ir`, `iba a ir`.
* Переклад «Дякую» (pt_02): `gracias`, `hola`, `por favor`, `adiós`.
* Переклад «Я вже поїв» (pt_09): `Ya he comido`, …
* Складання речення (pt_10): `tokens` = `Yo`, `quiero`, `un`, `café`; цільове речення `Yo quiero un café`.
* Аудіопитання (pt_11): правильна відповідь `Buenos días`.
* Аудіопереклад (pt_12): варіанти — `"Завтра я відвідаю свою родину"`, `"Учора я відвідав свою родину"`,
  `"Сьогодні я з родиною"`, `"Я хочу велику родину"`; стимул — `"Mañana voy a visitar a mi familia"`.

### 6.5 Тексти результату (`PlacementTest$TestResult`)

`recommendationUk` — чотири варіанти за `percent` (пороги 85 / 60 / 35):

| Умова | Текст дослівно |
| --- | --- |
| `percent >= 85` | `"Чудовий старт. Починаємо з рівня "` + `level.code` + `" — матеріал буде посильним, але не нудним."` |
| `percent >= 60` | `"Хороший результат. Стартуємо з рівня "` + `level.code` + `" і швидко закриємо прогалини."` |
| `percent >= 35` | `"Основа є. Почнемо з рівня "` + `level.code` + `" і приділимо більше уваги слабким темам."` |
| інакше | `"Почнемо з самого початку — це нормально: так фундамент буде міцним."` |

`weakAreasUk` = `wrongTags.joinToString(", ") { it.titleUk.lowercase(Locale.ROOT) }`, для порожнього
списку — порожній рядок (тоді банер `"Варто підсилити: …"` не показується).

---

## 7. `ExampleSplit` і `SelectableCard`

### 7.1 `ExampleSplit(minutes: Int)` (`OnboardingScreen.kt:224-247`)

Приватний композабл без власних кнопок: показує, як виглядатиме заняття обраної тривалості.

```
Card(
    modifier = Modifier.fillMaxWidth(),
    shape    = RoundedCornerShape(16.dp),
    colors   = CardDefaults.cardColors(containerColor = colorScheme.surfaceVariant)
) {
    Column(verticalArrangement = Arrangement.spacedBy(<dp>)) {
        Text("Приклад заняття на " + minutes + " хв", style = Typography.titleSmall)   // :237
        Text("$review хв — повторення",   style = Typography.bodyMedium)              // :238
        Text("$words хв — нові слова",    style = Typography.bodyMedium)              // :239
        Text("$grammar хв — граматика",   style = Typography.bodyMedium)              // :240
        Text("$exercises хв — вправи",    style = Typography.bodyMedium)              // :241
        Text("$listening хв — аудіювання",style = Typography.bodyMedium)              // :242
        Text("$speaking хв — говоріння",  style = Typography.bodyMedium)              // :243
    }
}
```

Розподіл хвилин (усі значення — `max(…, 1)`, тобто мінімум 1 хв; цілочисельне усічення):

| Рядок | Формула | При `minutes = 20` |
| --- | --- | --- |
| `review` (повторення) | `(minutes * 0.25).toInt()` | 5 |
| `words` (нові слова) | `(minutes * 0.25).toInt()` | 5 |
| `grammar` (граматика) | `(minutes * 0.2).toInt()` | 4 |
| `exercises` (вправи) | `minutes - review - words - grammar - listening - speaking` | 3 |
| `listening` (аудіювання) | `(minutes * 0.15).toInt()` | 3 |
| `speaking` (говоріння) | `(minutes * 0.1).toInt()` | 2 |

Порядок рядків у картці — саме такий (повторення → нові слова → граматика → вправи → аудіювання → говоріння);
порядок відповідає списку `SessionBlockKind.code` = `review`, `new_words`, `grammar`,
`exercises`, `listening`, `speaking`.

Викликається з `TimeStep` (`ExampleSplit(minutes = state.dailyMinutes)`, рядок 221).

### 7.2 `SelectableCard(title, subtitle, selected, onClick)` (`OnboardingScreen.kt:442-490`)

```
Card(
    onClick  = onClick,
    modifier = Modifier.fillMaxWidth(),
    colors   = CardDefaults.cardColors(
        containerColor = if (selected) colorScheme.primaryContainer else colorScheme.surface,
        contentColor   = if (selected) colorScheme.onPrimaryContainer else colorScheme.onSurface
    ),
    border   = BorderStroke(1.dp, if (selected) colorScheme.primary else colorScheme.outlineVariant)
) {
    Column(spacedBy) {
        Row(verticalAlignment = …) {
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = Typography.titleMedium)                  // :466
            }
            if (selected) Text("✓", style = Typography.titleLarge, color = colorScheme.primary)  // :468-471
        }
        Text(
            subtitle,
            style = Typography.bodyMedium,
            color = if (selected) colorScheme.onPrimaryContainer else colorScheme.onSurfaceVariant
        )                                                                    // :476-483
    }
}
```

| Параметр | Тип | Опис |
| --- | --- | --- |
| `title` | `String` | заголовок (`TitleMedium`) |
| `subtitle` | `String` | підзаголовок (`BodyMedium`) |
| `selected` | `Boolean` | стан виділення |
| `onClick` | `() -> Unit` | клік по всій картці (Card з `onClick`) |

Візуальні стани (кольори з `MaterialTheme.colorScheme`):

| Елемент | `selected == true` | `selected == false` |
| --- | --- | --- |
| Контейнер картки | `primaryContainer` | `surface` |
| Контент (базовий) | `onPrimaryContainer` | `onSurface` |
| Рамка (`BorderStroke(1.dp, …)`) | `primary` | `outlineVariant` |
| Підзаголовок | `onPrimaryContainer` | `onSurfaceVariant` |
| Галочка | `Text("✓")`, `TitleLarge`, `primary` | не показується |

Використовується у `GoalStep` (картки цілей) і `ResultStep` (картки рівнів A0/A1/A2).

### 7.3 Допоміжні компоненти, які використовує онбординг

| Компонент | Модуль | Опис |
| --- | --- | --- |
| `InfoBanner(text, modifier = Modifier, containerColor = tertiaryContainer, contentColor = onTertiaryContainer, icon: ImageVector? = null)` | `CommonComponents.kt:242-260` | `Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor, contentColor))` з `Row(Modifier.fillMaxWidth().padding(…), horizontalArrangement = Arrangement.SpaceBetween)`: текст і (за наявності) іконка |
| `PrimaryActionButton(title, onClick, modifier = Modifier, enabled = true, icon = null)` | `NavigationComponents.kt:183-201` | `Button(Modifier.fillMaxWidth(), contentPadding = PaddingValues(…), colors = ButtonDefaults.buttonColors(containerColor = primary, contentColor = onPrimary))` з `Row { Text(title) }` |
| `ChoiceChipsRow(options, selected, labelOf, onSelect, modifier = Modifier)` | `NavigationComponents.kt:147-…` | `Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(…), verticalAlignment = Alignment.Top)`; для кожного `option`: `if (option == selected) Button(Modifier.weight(1f)) … else OutlinedButton(Modifier.weight(1f)) …`, підпис — `Text(labelOf(option))` |

Використання в онбордингу: `InfoBanner` — `WelcomeStep` (×2), `TestIntroStep` (×2), `ResultStep` (×1);
`PrimaryActionButton` — футер `OnboardingScreen` та `ResultStep`; `ChoiceChipsRow` — `TimeStep`.

---

## Прогалини

1. **`weight` для 8 з 12 питань `PlacementTest`** — у наявному витягу читаються лише `pt_01` = 1,
   `pt_05` = 3, `pt_06` = 3, `pt_09` = 4, `pt_10` = 5 (див. `spec/02_learning_engine.md` §7.1, §12.7).
   Впливає на `percent` і на поріг 60 % у межах рівня.
2. **Зіставлення `id` (`pt_01`…`pt_12`) з текстами питань** — первинного smali `PlacementTest` у витягу
   не було; таблиця §6.4 — реконструкція (сходиться за кількістю питань і розподілом рівнів A0/A1/A2).
3. **Поштучні `options`, `stimulusEs`, `tokens` кожного питання** — наведено лише повний перелік рядків,
   без гарантованого прикріплення до `id`.
4. **Значення за замовчуванням `OnboardingUiState`** для `name`, `goal`, `dailyMinutes` — у синтетичному
   конструкторі (`<init>(…, DefaultConstructorMarker)`), який не зберігся у витягу. Підтверджено лише
   `step = WELCOME`, `questionIndex = 0`, `answers = emptyMap()`, `result = null`, `manualLevel = null`,
   `speakingAvailable = false` (далі `container.speechRecognizer.isAvailable`).
5. **Точні `dp`**: висота `LinearProgressIndicator` у `TestStep`, `contentPadding` кнопок `"Прослухати"`
   та варіантів, `PaddingValues`/`spacedBy` у `ChoiceChipsRow` і `SelectableCard`, `Spacer` перед
   `ExampleSplit` — значення не відновлено (smali `_work/smali` було видалено під час роботи).
6. **`getPromptStyle()`** (`ui/theme/TypeKt`) для `question.promptUk` — вміст `TextStyle` не відновлено.
7. **Позиція іконки в `InfoBanner`** (до/після тексту) — у байт-коді видно `Arrangement.SpaceBetween`
   і захоплені `icon`+`text`, але порядок викликів у лямбді не вдалося підтвердити.
8. **Чи є `Question.kind` enum-ом** (напр. `ExerciseKind`) — тип поля не підтверджено; у UI онбордингу
   `kind`, `tag`, `weight`, `explanationUk`, `tokens` не читаються взагалі.
9. **Умова показу першого `InfoBanner` у `WelcomeStep`** — за відсутністю викликів `ColorScheme` поруч
   з викликом банер використовує типові кольори `InfoBanner` (`tertiaryContainer`/`onTertiaryContainer`),
   але відповідний дефолт-масковий регістр остаточно не перевірено.
10. **Точний вміст `Level.mvpLevels`** — `listOf(A0, A1, A2)` підтверджено лише через
    `spec/01_models_enums.md` §2.1 (у витягу `ui/` класу `Level` немає).
