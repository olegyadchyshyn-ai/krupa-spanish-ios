# 42. Exercise та Listening (ExerciseContent.kt, ExerciseUiState.kt, ListeningScreen.kt, ListeningViewModel.kt)

**Джерела:** `_recon/strings_by_class.txt` (рядкові константи за класами), дизасембльований smali пакета `ua/krupa/spanish/ui/` (`classes10_ui.txt` — exercise, `classes14_ui.txt` — listening), `content_from_apk/exercises.a0.json`, `exercises.a1.json`, `exercises.a2.json`.

**Позначки в тексті:**
* `L###` / `(Файл.kt:###)` — номери рядків вихідних `.kt`, відновлені з таблиць `positions` у smali;
* рядки **389–435** у позиціях `ExerciseContent.kt` — це віртуальні рядки SMAP для інлайн-коду stdlib/Compose (`Dp.kt`, `_Collections.kt`, `fake.kt`, `Row.kt`, `Column.kt`), а не код застосунку;
* «текст не знайдено» — у дампі рядкових констант відповідного тексту немає;
* «(припущення)» — висновок, який не вдалося підтвердити байткодом.

---

## 1. Exercise — загальне

### 1.1 Призначення та місце в навігації

| Питання | Відповідь |
|---|---|
| Що це | Один універсальний Composable-блок вправи `ExerciseContent(exercise, …)` у файлі `ui/screens/exercise/ExerciseContent.kt`, який за полем `exercise.kind` рендерить один із 9 різних типів завдань |
| Окремий екран? | **Ні.** Окремого екрана вправи немає: `ExerciseContent.kt` не містить ні `Scaffold`, ні `TopAppBar`, ні кнопок перевірки |
| Де використовується | Як вбудований блок у сесії навчання: `SessionScreen.kt` → `ExerciseBlock` (`SessionScreen.kt:504–558`, метадані `C(ExerciseBlock)P(!1,10,9,11!1,8,7,3)507@20276L24,510@20354L1468,557@22272L10,558@22329L11,555@22186L182`). Класи `SessionScreenKt$ExerciseBlock$1..$7` читають `ExerciseUiState.getChecked()/getCorrect()/getGivenAnswer()/getCanCheck()/getSelectedOption()/getOptionOrder()/getSelectedTokens()/getTextAnswer()/isListening()` |
| Публічні Composable у файлі | `ExerciseContent` (64–205), `SpanishStimulus` (207–227), `TextInputAnswer` (234–249), `ChoiceList` (255–274), `AnswerStrip` (281–313), `TokenPool` (320–339), `AudioRow` (347–384), приватна функція `optionsOrDistractors` (386–…, виклик на L387). Усі Composable — `private static final` |

Сигнатура `ExerciseContent` (з анотації `Signature`):

```
ExerciseContent(
    exercise: Exercise,
    optionOrder: List<Int>,        // Java: List<Integer>
    tokenOrder: List<Int>,
    selectedTokens: List<Int>,
    textAnswer: String,
    <Boolean>, <Boolean>,          // два прапорці; за викликами з ExerciseBlock — isListening і speechHeard (припущення:
                                   // у дампі рядків їхні імена не збереглися, бо примітивні типи не проходять checkNotNullParameter)
    onOptionSelected: (Int) -> Unit,
    onTokenToggled: (Int) -> Unit,
    onTextChanged: (String) -> Unit,
    onSpeakText: () -> Unit,
    onSpeakSlowly: () -> Unit,
    onStartListening: () -> Unit,
    modifier: Modifier = Modifier,
)
```

Імена референсних параметрів підтверджені рядками з `checkNotNullParameter`: `"exercise"`, `"optionOrder"`, `"tokenOrder"`, `"selectedTokens"`, `"textAnswer"`, `"onOptionSelected"`, `"onTokenToggled"`, `"onTextChanged"`, `"onSpeakText"`, `"onSpeakSlowly"`, `"onStartListening"`.

### 1.2 `ExerciseUiState` (ExerciseUiState.kt)

`data class`, 11 властивостей конструктора (рядки 4–27 файлу; у класі також `$stable = 8`). Порядок і дефолти відновлені з синтетичного конструктора з маскою `0x7FF` (`<init>:(Ljava/util/List;Ljava/util/List;ILjava/lang/Integer;Ljava/util/List;Ljava/lang/String;ZZZZLjava/lang/String;ILkotlin/jvm/internal/DefaultConstructorMarker;)V`).

| # | Поле | Тип у байткоді | Тип (Kotlin) | Значення за замовчуванням | Рядок |
|---|---|---|---|---|---|
| 1 | `optionOrder` | `Ljava/util/List;` | `List<Int>` | `emptyList()` (маска `0x01`) | 6 |
| 2 | `tokenOrder` | `Ljava/util/List;` | `List<Int>` | `emptyList()` (маска `0x02`) | 8 |
| 3 | `optionCount` | `I` | `Int` | `0` (маска `0x04`) | 9 |
| 4 | `selectedOption` | `Ljava/lang/Integer;` | `Int?` | `null` (маска `0x08`) | 10 |
| 5 | `selectedTokens` | `Ljava/util/List;` | `List<Int>` | `emptyList()` (маска `0x10`) | 11 |
| 6 | `textAnswer` | `Ljava/lang/String;` | `String` | `""` (маска `0x20`) | 12 |
| 7 | `isListening` | `Z` | `Boolean` | `false` (маска `0x40`) | 13 |
| 8 | `speechHeard` | `Z` | `Boolean` | `false` (маска `0x80`) | 14 |
| 9 | `checked` | `Z` | `Boolean` | `false` (маска `0x100`) | 15 |
| 10 | `correct` | `Z` | `Boolean` | `false` (маска `0x200`) | 16 |
| 11 | `givenAnswer` | `Ljava/lang/String;` | `String` | `""` (маска `0x400`) | 17 |

Додатково:
* `component1…component11`, `copy`, `equals`, `hashCode`, `toString` (рядок `toString`: `"ExerciseUiState(optionOrder=…, tokenOrder=…, optionCount=…, selectedOption=…, selectedTokens=…, textAnswer=…, isListening=…, speechHeard=…, checked=…, correct=…, givenAnswer=…)"`).
* **Обчислювана властивість `canCheck`** — у списку полів її немає (тому в `toString`/`copy` вона не входить), але метод `ExerciseUiState.getCanCheck():Z` викликається з екранів сесії (`SessionScreenKt$ExerciseBlock$*`, `SessionScreenKt$SessionContent$*`). Отже, це `val canCheck: Boolean get() = …` — тіло геттера **не відновлено** (див. Прогалини).

### 1.3 Типи вправ

**`ExerciseKind`** (Enums.kt) — 9 значень; у дужках — код із поля/методу `code` (серіалізоване значення з JSON):

| Enum-константа | `code` | Українська назва (`titleUk`) |
|---|---|---|
| `DICTATION` | `dictation` | `"Диктант"` |
| `FILL_GAP` | `fill_gap` | `"Пропущене слово"` |
| `LISTENING` | `listening` | `"Аудіювання"` |
| `MATCH_PAIRS` | `match_pairs` | `"Зіставлення пар"` |
| `MULTIPLE_CHOICE` | `multiple_choice` | `"Вибір відповіді"` |
| `SENTENCE_BUILD` | `sentence_build` | `"Складання речення"` |
| `SPEAKING` | `speaking` | `"Говоріння"` |
| `TRANSLATION_ES_UK` | `translation_es_uk` | `"Переклад іспанською → українською"` |
| `TRANSLATION_UK_ES` | `translation_uk_es` | `"Переклад українською → іспанською"` |

Примітка: у дампі рядків константи та підписи відсортовані абеткою, тому відповідність «константа → підпис» відновлена за змістом; коди (`dictation`, `fill_gap`, …) — точні.

**Унікальні значення `kind` у файлах контенту** (усі 9 присутні в кожному файлі):

| `kind` | `exercises.a0.json` | `exercises.a1.json` | `exercises.a2.json` |
|---|---|---|---|
| `dictation` | 7 | 8 | 8 |
| `fill_gap` | 16 | 18 | 39 |
| `listening` | 12 | 12 | 12 |
| `match_pairs` | 4 | 4 | 12 |
| `multiple_choice` | 22 | 26 | 30 |
| `sentence_build` | 18 | 22 | 31 |
| `speaking` | 7 | 8 | 10 |
| `translation_es_uk` | 18 | 20 | 26 |
| `translation_uk_es` | 22 | 26 | 28 |

Інших значень `kind` у цих файлах немає (тобто 9 = повний перелік).

### 1.4 Мапа `kind` → Composable-блок

`ExerciseContent` містить `when (exercise.kind)` (L75), який компілятор звів до `ExerciseContentKt$WhenMappings.$EnumSwitchMapping$0` + `packed-switch`. Ключі мапи (порядок = порядок гілок у вихідному коді, тобто зростання номерів рядків):

| Ключ | Enum-константа | Рядки гілки | Блок, який рендериться |
|---|---|---|---|
| 1 | `TRANSLATION_ES_UK` | 76–81 | `SpanishStimulus` + `TextInputAnswer` (підпис `"Переклад українською"`) |
| 2 | `TRANSLATION_UK_ES` | 85–90 | `SpanishStimulus` + `TextInputAnswer` (підпис `"Переклад іспанською"`) |
| 3 | `MULTIPLE_CHOICE` | 94–99 | `SpanishStimulus` + `ChoiceList(optionsOrDistractors(exercise))` |
| 4 | `LISTENING` | 103–113 | `AudioRow` + `ChoiceList(optionsOrDistractors(exercise))` |
| 5 | `SENTENCE_BUILD` | 117–133 | `Text("Натискайте слова у правильному порядку:")` + `AnswerStrip` + `Spacer` + `TokenPool` |
| 6 | `FILL_GAP` | 137–149 | `SpanishStimulus(gapText)` + (`ChoiceList(gapAnswer + distractors)` **або** `TextInputAnswer("Пропущене слово")`) |
| 7 | `DICTATION` | 154–165 | `AudioRow` + `TextInputAnswer("Запишіть те, що почули")` |
| 8 | `SPEAKING` | 169–186 | `SpanishStimulus(answerEs)` + `Text("Скажіть це вголос — застосунок перевірить вимову.")` + `AudioRow` + `Text("Почуто: …")` |
| 9 | `MATCH_PAIRS` | 191–198 | `Text("Оберіть слово, яке відповідає темі:")` + `ChoiceList(tokens.ifEmpty { distractors })` |

Гілок у байткоді 9 — усі значення `ExerciseKind` оброблені, «невідомого» типу вправи немає.

---

## 2. Блоки вправи — детально

### 2.0 `ExerciseContent` — каркас (L64–205)

Структура зверху вниз:

1. **L67** — `Column(modifier = Modifier.fillMaxWidth(), …)`; **L68** — `verticalArrangement = Arrangement.spacedBy(<крок>)`, горизонтальне вирівнювання — `Alignment.Start` (`Alignment$Companion.getStart`). Точні значення `dp` у текстовому дампі не збереглися (див. Прогалини).
2. **L71–72** — умовний заголовок-інструкція:
   `if (exercise.promptUk.isNotBlank()) Text(exercise.promptUk, style = promptStyle)` — стиль береться з теми: `ua.krupa.spanish.ui.theme.TypeKt.getPromptStyle()`.
3. **L75** — `when (exercise.kind)` → один із 9 блоків (див. 1.4). Деталі кожної гілки:

| Гілка | Точний вміст (за рядками) |
|---|---|
| `TRANSLATION_ES_UK` (76–81) | **77**: `SpanishStimulus(text = exercise.promptEs.ifBlank { exercise.answerEs }, speak = false)` → байткод: `getPromptEs` → `StringsKt.isBlank` → якщо порожній, береться `getAnswerEs`; **78**: `TextInputAnswer(text = textAnswer, onValueChange = onTextChanged, placeholder = "Переклад українською", spanishKeyboard = false)` |
| `TRANSLATION_UK_ES` (85–90) | **86**: `if (exercise.promptEs.isNotBlank()) SpanishStimulus(exercise.promptEs, speak = false)`; **87**: `TextInputAnswer(textAnswer, onTextChanged, "Переклад іспанською", spanishKeyboard = false)` |
| `MULTIPLE_CHOICE` (94–99) | **95**: `if (exercise.promptEs.isNotBlank()) SpanishStimulus(exercise.promptEs, speak = false)`; **96**: `ChoiceList(optionsOrDistractors(exercise), optionOrder, onOptionSelected)` (L97 — виклик `optionsOrDistractors`) |
| `LISTENING` (103–113) | **104**: `AudioRow(isListening, speechHeard, onSpeakText, onSpeakSlowly, onStartListening)`; **110**: `ChoiceList(optionsOrDistractors(exercise), optionOrder, onOptionSelected)` (L111 — побудова списку) |
| `SENTENCE_BUILD` (117–133) | **118**: `Text("Натискайте слова у правильному порядку:", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)`; **123**: `AnswerStrip(exercise.tokens, tokenOrder, onTokenToggled)`; **128**: `Spacer(Modifier.height(<dp>))`; **129**: `TokenPool(exercise.tokens, tokenOrder, selectedTokens, onTokenToggled)` (L124/L130 — `getTokens`) |
| `FILL_GAP` (137–149) | **138**: `SpanishStimulus(exercise.gapText.replace("___", "____"), speak = false)` — саме такий порядок аргументів `StringsKt.replace$default(text, "___", "____")`, тобто три підкреслення замінюються на чотири; **139–140**: `if (exercise.distractors.isNotEmpty())` → `ChoiceList(listOf(exercise.gapAnswer) + exercise.distractors.filter { it.isNotBlank() }, optionOrder, onOptionSelected)` (фільтр непорожніх — інлайн-цикл `ArrayList.add`); **146**: інакше `TextInputAnswer(textAnswer, onTextChanged, "Пропущене слово", spanishKeyboard = false)` |
| `DICTATION` (154–165) | **155**: `AudioRow(isListening, speechHeard, onSpeakText, onSpeakSlowly, onStartListening)`; **161**: `TextInputAnswer(textAnswer, onTextChanged, "Запишіть те, що почули", spanishKeyboard = **true**)` — єдина гілка, де передано `true` |
| `SPEAKING` (169–186) | **170**: `SpanishStimulus(exercise.answerEs, speak = false)`; **171**: `Text("Скажіть це вголос — застосунок перевірить вимову.", bodyMedium, onSurfaceVariant)`; **176**: `AudioRow(…)`; **183–185**: якщо розпізнаний текст непорожній (`StringsKt.isBlank`) — `Text("Почуто: " + <розпізнаний текст>, bodyMedium)` (L185 — літерал `"Почуто: "` з пробілом у кінці; джерело другого рядка — рядковий параметр `textAnswer`, припущення) |
| `MATCH_PAIRS` (191–198) | **192**: `Text("Оберіть слово, яке відповідає темі:", bodyMedium, onSurfaceVariant)`; **197**: `ChoiceList(if (exercise.tokens.isEmpty()) exercise.distractors else exercise.tokens, optionOrder, onOptionSelected)` |

4. **L203** — кінець `when`; **L205** — кінець функції (у позиціях — `0x06ea line=433` — це SMAP-рядок, не код).

### 2.1 `SpanishStimulus(text: String, speak: Boolean)` — L207–227

| Порядок | Елемент | Деталі з байткоду |
|---|---|---|
| 1 | `Card` (L209) | `modifier = Modifier.fillMaxWidth()` (L210), `shape = RoundedCornerShape(<dp>)` (L211), `colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)` (L212) |
| 2 | вміст картки (лямбда `…$SpanishStimulus$1`, L213) | `Column` (L218–222) → `Text(text, style = TypeKt.getSpanishWordStyle())` (L220; стиль із теми, виклик `getSpanishWordStyle` на L222) |

Текстів усередині немає (текст береться з `exercise`). Параметр `speak` у тілі **не впливає** ні на що видиме: у байткоді `ExerciseContent` він завжди передається `false` (`const/4 … #int 0`), а в самому `SpanishStimulus` його використання не спостерігається (лише прокидання в restart-лямбду) — див. Прогалини.

### 2.2 `TextInputAnswer(text: String, onValueChange: (String) -> Unit, placeholder: String, spanishKeyboard: Boolean)` — L234–249

| Порядок | Елемент | Деталі з байткоду |
|---|---|---|
| 1 | `OutlinedTextField` (L235) | `value = text` (L237), `onValueChange = onValueChange` (L238 — саме ця назва в locals), `modifier = Modifier.fillMaxWidth()` (L239), `placeholder = { Text(placeholder) }` (L239–240, лямбда `…$TextInputAnswer$1` рендерить `Text` на L240), `textStyle = MaterialTheme.typography.bodyLarge` (L241), `shape = RoundedCornerShape(**14.dp**)` (L245), `keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done)` (L246), `keyboardActions = KeyboardActions()` (L247), `maxLines = 3`, `minLines = 1`. Аргументи на L242–244 у байткоді згорнулися в дефолти (значення не відновлені) |
| 2 | — | Жодного `Icon`, кольору стану, `isError` чи підпису поза `placeholder` немає. Параметр `spanishKeyboard` у тілі не використовується для жодного видимого ефекту (єдине читання — розв'язання дефолту; див. Прогалини) |

Як відповідає користувач: вводить текст у поле (1–3 рядки), IME-дія — «Done». Текст підказки — це `placeholder` (той рядок, який передає `ExerciseContent`), а не `label`.

### 2.3 `ChoiceList(options: List<String>, optionOrder: List<Int>, onOptionSelected: (Int) -> Unit)` — L255–274

| Порядок | Елемент | Деталі |
|---|---|---|
| 1 | `Column` (L256) | `verticalArrangement = Arrangement.spacedBy(<dp>)` (L257), `horizontalAlignment = Alignment.Start` |
| 2 | для кожного елемента `options` (цикл `forEachIndexed`, `java.util.Iterator` на L473) | `OutlinedButton` (L260): `onClick = { onOptionSelected(index) }` (L261), `modifier = Modifier.fillMaxWidth()` (L262), `shape = RoundedCornerShape(<dp>)` (L263), `contentPadding = PaddingValues(…)` (L264), вміст — `Text(option)` (L266, лямбда `…$ChoiceList$1$1$2`) |

Кольорів «правильно/неправильно» тут **немає** (жодного звернення до `ColorScheme`), виділення вибраного варіанта теж немає. Другий параметр `optionOrder` у тілі не читається (порядок варіантів визначає сам список `options`).

### 2.4 `AnswerStrip(tokens: List<String>, selected: List<Int>, onTokenToggled: (Int) -> Unit)` — L281–313

| Порядок | Елемент | Деталі |
|---|---|---|
| 1 | `Card` (L283) | `modifier = Modifier.fillMaxWidth()` (L284), `shape = RoundedCornerShape(**14.dp**)` (L285 — `const/16 #int 14`), `colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)` (L286) |
| 2 | вміст (лямбда `…$AnswerStrip$1`): `FlowRow` (L287) | `modifier = Modifier.fillMaxWidth().padding(<dp>)` (L290–291), `horizontalArrangement = Arrangement.spacedBy(<dp>)` (L292), `verticalArrangement = Arrangement.spacedBy(<dp>)` (L293) |
| 3 | якщо `selected.isEmpty()` (L295) | `Text("Тут з'явиться ваше речення", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)` (L296–299) |
| 4 | інакше — для кожного індексу з `selected` (L303) | `Button` (L303): `onClick = { onTokenToggled(index) }` (L304, лямбда `…$1$1$1$1$1`), `shape = RoundedCornerShape(<dp>)` (L305), `contentPadding = PaddingValues(…)` (L306), вміст — `Text(tokens.getOrNull(index) ?: "", style = MaterialTheme.typography.bodyLarge)` (L307–308; рядок-фолбек — порожній `""`) |

Як відповідає користувач: зібране речення показується як низ «чипів»-кнопок; тап по чипу прибирає слово з відповіді (той самий колбек `onTokenToggled`, що й у `TokenPool`).

### 2.5 `TokenPool(tokens: List<String>, tokenOrder: List<Int>, selectedTokens: List<Int>, onTokenToggled: (Int) -> Unit)` — L320–339

| Порядок | Елемент | Деталі |
|---|---|---|
| 1 | `FlowRow` (L321–322) | `modifier = Modifier.fillMaxWidth()` (L323), `horizontalArrangement = Arrangement.spacedBy(<dp>)` (L324), `verticalArrangement = Arrangement.spacedBy(<dp>)` (L325) |
| 2 | для кожного токена (L327–329, `forEachIndexed`) | умова `!selectedTokens.contains(index)` (`java.util.List.contains`, L328) → показується лише невикористаний токен |
| 3 | `OutlinedButton` (L330) | `onClick = { onTokenToggled(index) }` (L331), `shape = RoundedCornerShape(<dp>)` (L332), `contentPadding = PaddingValues(horizontal = …, vertical = …)` (L333), вміст — `Text(token)` (L335, лямбда `…$TokenPool$1$1$2`) |

### 2.6 `AudioRow(isListening: Boolean, speechHeard: Boolean, onSpeakText: () -> Unit, onSpeakSlowly: () -> Unit, onStartListening: () -> Unit)` — L347–384

Порядок елементів (усі — в одному `Row`, L348–351: `modifier = Modifier.fillMaxWidth()`, `horizontalArrangement = Arrangement.spacedBy(<dp>)`, `verticalAlignment = Alignment.Top`):

| # | Елемент | Рядки | Точний вміст / дія |
|---|---|---|---|
| 1 | `OutlinedButton` (перша, `onClick = onSpeakText`) | 353–362 | вага в `Row` (`RowScope.weight`, L356), `shape = RoundedCornerShape(<dp>)` (L357), `contentPadding = PaddingValues(…)` (L358); вміст (ComposableSingleton `lambda-1`, метадані `C359@12845L87,360@12945L28,361@12986L18`): `Spacer` (L361) + **`Text("Прослухати")`** (L362) |
| 2 | `OutlinedButton` (друга, `onClick = onSpeakSlowly`) | 364–370 | `shape = RoundedCornerShape(<dp>)` (L367), `contentPadding = PaddingValues(…)` (L368); вміст (`lambda-2`, `C369@13277L13`): **`Text("0.75×")`** (L370) |
| 3 | `Button` (залита, `onClick = onStartListening`) | 373–380 | `shape = RoundedCornerShape(<dp>)` (L375), `contentPadding = PaddingValues(…)` (L376); вміст (лямбда `…$AudioRow$1$1`): `Spacer` (L379) + **`Text(if (isListening) "Слухаю…" else "Говорити")`** (L380) |

Тексти дослівно: `"Прослухати"`, `"0.75×"`, `"Слухаю…"`, `"Говорити"`. Другий параметр (`speechHeard`) у тілі `AudioRow` не читається — він потрібен лише для інвалідації рекомпозиції (припущення).

### 2.7 `optionsOrDistractors(exercise: Exercise): List<String>` — L386–…

Логіка (L387, тіло циклу L590–591 у SMAP-нумерації): якщо `exercise.answerEs.isNotBlank()` → `listOf(exercise.answerEs) + exercise.distractors`, інакше → `exercise.distractors`. Використовується в гілках `MULTIPLE_CHOICE` та `LISTENING`.

### 2.8 Зворотний зв'язок «правильно/неправильно» та кнопки перевірки

У `ExerciseContent.kt` **немає жодного** елемента зворотного зв'язку: ані кольорів `error`/`primary`, ані іконок ✓/✕, ані текстів «Правильно»/«Спробуйте ще», ані кнопок «Перевірити»/«Показати відповідь»/«Далі». Ці елементи живуть у `SessionScreen.kt` (класи `SessionScreenKt`, `SessionScreenKt$ExerciseBlock$*`, `SessionScreenKt$FeedbackBlock$*`), тому їхні точні підписи наведено довідково:

| Текст (дослівно) | Клас-власник (файл) |
|---|---|
| `"Перевірити"` | `SessionScreenKt` (SessionScreen.kt) |
| `"Показати відповідь"` | `SessionScreenKt` |
| `"Далі"` | `SessionScreenKt` |
| `"Зрозуміло, далі"` | `SessionScreenKt` |
| `"Правильно"` | `SessionScreenKt$ExerciseBlock$1` |
| `"Правильно: "` | `SessionScreenKt$ExerciseBlock$1` |
| `"Підказка: "` | `SessionScreenKt` |
| `"Почуто: "` | `SessionScreenKt` |
| `"Прослухати повністю"`, `"Завершити слухання"` | `SessionScreenKt` |
| `"Вимова: "`, `"Закономірність: "`, `"Типова помилка: "` | `SessionScreenKt` |

Кнопки `"Спробуйте ще"` у дампі рядків **не знайдено** (наявні лише варіанти для мовлення: `"Спробуйте ще раз, промовляючи повільніше й чіткіше."`, `"Не розчув. Спробуйте сказати чіткіше."`, `"Помилку на боці застосунку. Спробуйте ще раз."` — класи розпізнавання мовлення, поза цим файлом).

Що робить `ExerciseBlock` зі станом (за викликами геттерів `ExerciseUiState`): читає `checked`, `correct`, `givenAnswer`, `canCheck`, `selectedOption`, `optionOrder`, `selectedTokens`, `textAnswer`, `isListening` і передає їх у `ExerciseContent`/`FeedbackBlock`; саме там вирішується, коли показувати правильну відповідь (`"Правильно: "` + `givenAnswer`) і коли активна кнопка `"Перевірити"` (`canCheck`).

### 2.9 Зведена таблиця дій у блоці вправи

| Елемент | Дія користувача | Наслідок |
|---|---|---|
| `ChoiceList` / `TokenPool` / `AnswerStrip` (варіант, токен, чип) | тап | `onOptionSelected(index)` / `onTokenToggled(index)` — у стані сесії змінюється `selectedOption` або `selectedTokens` |
| `TextInputAnswer` (поле) | введення тексту | `onTextChanged(newValue)` → `ExerciseUiState.textAnswer` |
| `AudioRow` → `"Прослухати"` | тап | `onSpeakText()` — озвучення іспанського тексту (TTS) |
| `AudioRow` → `"0.75×"` | тап | `onSpeakSlowly()` — озвучення у сповільненому темпі |
| `AudioRow` → `"Говорити"` | тап | `onStartListening()` — старт розпізнавання мовлення; на час запису підпис стає `"Слухаю…"` (`isListening = true`) |
| `"Перевірити"` / `"Показати відповідь"` / `"Далі"` | тап | у `SessionScreen.kt` (поза цим файлом): перевірка відповіді, показ правильної, перехід до наступного кроку |

---

## 3. Listening — список

### 3.1 Призначення та структура (`ListeningScreen.kt`, `ListeningScreen` L60–…)

Призначення: каталог аудіоматеріалів (діалоги/розповіді/подкасти) з фільтром за рівнем; тап по картці відкриває екран прослуховування (`ListeningDetailScreen`).

| Порядок зверху вниз | Рядки | Елемент і деталі |
|---|---|---|
| 1 | 62–63 | `viewModel(factory = ListeningViewModelFactory(container))` + `collectAsStateWithLifecycle()` |
| 2 | 65–66 | **loading**: `if (state.loading) Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }` |
| 3 | 70–73 | `LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(…), verticalArrangement = Arrangement.spacedBy(<dp>))` |
| 3.1 | 75–84 | `item { … }` — **заголовок** (не `TopAppBar`): `Column(verticalArrangement = spacedBy, horizontalAlignment = Start)` → `Text("Слухання", style = MaterialTheme.typography.headlineMedium)` (L77) → `Spacer(Modifier.height(<dp>))` (L78) → `Text("Мета — розуміти загальний зміст, а не кожне слово. Слухайте кілька разів, переклад відкривайте лише за потреби.", style = bodyMedium, color = onSurfaceVariant)` (L79–83) |
| 3.2 | 88–94 | `item { Row(horizontalArrangement = Arrangement.spacedBy(<dp>)) { … } }` — **фільтр за рівнем**: по `state.levelsWithContent` → `FilterChip(selected = level == state.currentLevel, onClick = { selectLevel(level) }, label = { Text(level.code) })` (L90–94). Підпис чипа — код рівня (`A0`, `A1`, `A2`, `B1`, `B2`); чипа «Усі» тут немає |
| 3.3 | 100–101 | `item { LevelHint(state.currentLevel) }` — банер-підказка для вибраного рівня (L152–162) |
| 3.4 | 102–103 | **empty**: `if (state.visible.isEmpty()) item { EmptyState(title = "Для цього рівня матеріалів немає", subtitle = "Оберіть інший рівень — матеріали додаються поступово.") }` (`ui/components/CommonComponentsKt.EmptyState`) |
| 3.5 | 111–113 | `items(state.visible, key = { it.id }) { item -> ListeningItemCard(…) }` — список карток (клік → `onOpenItem(item.id)`) |
| 3.6 | 148 | `item { Spacer(Modifier.height(<dp>)) }` — хвіст списку |

`LevelHint(level)` (L152–162): `when (level)` → п'ять текстів, далі `InfoBanner(text)` (`CommonComponentsKt.InfoBanner-t6yy7ic`, L161) + лямбда `…$LevelHint$1` (L162, слот іконки/вмісту):

| Рівень | Текст (дослівно) |
|---|---|
| `A0` | `"A0 — дуже прості речення з візуальною опорою. Слухайте й повторюйте вголос."` (L155) |
| `A1` | `"A1 — короткі діалоги про щоденні справи. Намагайтеся вловити, хто що робить."` (L156) |
| `A2` | `"A2 — побутові історії з минулими часами. Звертайте увагу на послідовність подій."` (L157) |
| `B1` | `"B1 — нормальна розмовна мова зі зв'язками між думками."` (L158) |
| `B2` | `"B2 — подкасти й інтерв'ю з абстрактними темами."` (L159) |
| інші значення | гілки немає → `NoWhenBranchMatchedException` (запобіжник компілятора) |

### 3.2 `ListeningUiState` (ListeningViewModel.kt)

`data class`, 4 властивості конструктора `(Z, Level, List, Level)` — тобто `(loading, level, items, currentLevel)`; `toString`: `"ListeningUiState(loading=…, currentLevel=…, items=…, level=…)"`. Клас також має **обчислювані** властивості `visible` і `levelsWithContent` (окремі геттери з тілом).

| Поле | Тип | Значення за замовчуванням | Призначення |
|---|---|---|---|
| `loading` | `Boolean` | не підтверджено (ймовірно `true`) | показ `CircularProgressIndicator` |
| `level` | `Level` | не підтверджено | рівень користувача (з профілю) |
| `items` | `List<ListeningItem>` | не підтверджено (ймовірно `emptyList()`) | усі завантажені матеріали |
| `currentLevel` | `Level` | не підтверджено | вибраний фільтр рівня (порівнюється з `level` у `FilterChip.selected`) |

| Обчислювана властивість | Що робить (за байткодом) |
|---|---|
| `visible: List<ListeningItem>` | новий `ArrayList`; перебір `items`, додаються лише ті, у яких `item.level` дорівнює поточному рівню (`ListeningItem.getLevel`, L20; яке саме поле — `level` чи `currentLevel` — у дампі не розрізнити) |
| `levelsWithContent: List<Level>` | `Level.Companion.getMvpLevels` (L23) → залишаються лише ті рівні, для яких у `items` є хоча б один матеріал (подвійний цикл L107–110) |

### 3.3 `ListeningViewModel` (ListeningViewModel.kt)

| Метод | Параметри | Що робить |
|---|---|---|
| `<init>` (конструктор) | `container: AppContainer` | L34: створює `MutableStateFlow<ListeningUiState>`; L38–44: в `init` запускає корутину — L39: `container.users` → `UserRepository.profile` (бере рівень користувача), L40: `container.courses` → `CourseRepository.listeningItems`, L40–41: сортує матеріали за `orderIndex` (інлайн `sortedBy`, компаратор `ListeningViewModel$1$invokeSuspend$$inlined$sortedBy$1.compare` порівнює `getOrderIndex`), L41/L44: зіставляє рівень профілю з рівнями матеріалів, L42: `state.value = ListeningUiState(loading = false, …, items = …, …)` |
| `state` (геттер `getState`) | — | публічний потік стану; екран збирає його через `collectAsStateWithLifecycle()` |
| `selectLevel` | `level: Level` | L52: `state.value = state.value.copy(<поле рівня> = level)` (виклик `copy$default`) — перемикання фільтра; рядок-параметр `"level"` підтверджує ім'я |
| `ListeningViewModelFactory.create` | `modelClass: Class<*>` | L58: створює `ListeningViewModel(container)`; фабрика має конструктор `(container: AppContainer)` |

### 3.4 Картка елемента аудіювання (`ListeningScreenKt$ListeningScreen$3$4$2`, L118–141)

`Card(onClick = { onOpenItem(item.id) }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(<dp>), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface), border = BorderStroke(<dp>, MaterialTheme.colorScheme.outlineVariant))` (метадані гілки `C118@5034L1387`), вміст — `Column(Modifier.padding(<dp>))`:

| Порядок | Елемент | Джерело даних | Стиль |
|---|---|---|---|
| 1 | `Icon` `Icons.Filled.GraphicEq` (L121–125) | — | `tint = MaterialTheme.colorScheme.primary`, `modifier = Modifier.size(<dp>)` |
| 2 | `Spacer(Modifier.width(<dp>))` | — | L127 |
| 3 | `Text(item.titleUk, …)` (L129) | `ListeningItem.titleUk` | `MaterialTheme.typography.titleMedium` |
| 4 | `Text(item.titleEs, …)` (L130–133) | `ListeningItem.titleEs` | `MaterialTheme.typography.bodySmall`, `color = onSurfaceVariant` |
| 5 | `Spacer(Modifier.height(<dp>))` (L137) | — | — |
| 6 | `Text("…", …)` (L138–142) | `item.kind.titleUk` + `item.lines.size` + `item.comprehensionQuestions.size` | `MaterialTheme.typography.labelSmall`, `color = onSurfaceVariant` |

Рядок метаданих збирається конкатенацією з літералами `" · реплік: "` та `" · питань: "`, тобто має вигляд:
`<ListeningKind.titleUk> · реплік: <lines.size> · питань: <comprehensionQuestions.size>`.

**Чого на картці немає:** тривалості, прогресу прослуховування, позначки «пройдено», рівня (рівень видно лише на екрані деталей у рядку метаданих). У моделі `ListeningItem` немає полів тривалості/прогресу/«виконано» (поля: `id`, `titleUk`, `titleEs`, `level`, `kind`, `topicId`, `orderIndex`, `lines`, `keyWords`, `comprehensionQuestions`), тому ці показники відображати нема з чого.

### 3.5 Стани та всі тексти списку (дослівно)

| Стан | Текст / елемент |
|---|---|
| **loading** | `CircularProgressIndicator()` по центру; текстів немає |
| **empty** (для вибраного рівня) | `"Для цього рівня матеріалів немає"`, `"Оберіть інший рівень — матеріали додаються поступово."` (`EmptyState`) |
| **error** | **текст не знайдено**: у `ListeningUiState` немає поля помилки, у `ListeningScreen.kt` немає гілки помилки |
| Заголовок | `"Слухання"` |
| Підзаголовок-порада | `"Мета — розуміти загальний зміст, а не кожне слово. Слухайте кілька разів, переклад відкривайте лише за потреби."` |
| Підказки рівнів | `"A0 — …"`, `"A1 — …"`, `"A2 — …"`, `"B1 — …"`, `"B2 — …"` (повні тексти в 3.1) |
| Чипи рівнів | коди `A0`, `A1`, `A2`, `B1`, `B2` (з `Level.code`) |
| Метадані картки | `" · реплік: "`, `" · питань: "`, назва типу аудіо (`ListeningKind.titleUk`: `"Діалог"`, `"Розповідь"`, `"Подкаст"`, `"Історія"` — парування `MONOLOGUE`/`STORY` з підписами див. у Прогалинах) |
| Інші рядки цього ж файлу (належать деталям) | `"Назад"`, `"Повільно 0.75×"`, `"Зупинити"`, `"Повторити"`, `"Показати переклад"`, `"Сховати переклад"`, `"Текст"`, `"Ключові слова"`, `"Перевірте розуміння"`, `"Матеріал не знайдено"`, `"Слухати повністю"`, `"Відтворюється…"`, `"Завершити"`, `"Відповідей"`, `"Правильно"`, `"✓ Правильно. "`, `"✕ Правильна відповідь: "`, `". "`, `":"` |

---

## 4. ListeningDetail — екран прослуховування

### 4.1 `ListeningDetailUiState` (ListeningViewModel.kt)

`data class`, 2 властивості (рядок 61 файлу): конструктор `(Z, Lua/krupa/spanish/domain/model/ListeningItem;)`, `toString`: `"ListeningDetailUiState(loading=…, item=…)"`.

| Поле | Тип | Значення за замовчуванням | Призначення |
|---|---|---|---|
| `loading` | `Boolean` | не підтверджено (ймовірно `true`) | показ `CircularProgressIndicator` |
| `item` | `ListeningItem?` | `null` | матеріал; `null` (і не loading) → текст `"Матеріал не знайдено"` |

### 4.2 Структура `ListeningDetailScreen` зверху вниз (L168–390)

| Порядок | Рядки | Елемент |
|---|---|---|
| 1 | 172–174 | `viewModel(factory = ListeningDetailViewModelFactory(container, itemId))` + `state` |
| 2 | 176 | `val tts = container.ttsEngine` (`SpanishTtsEngine`) |
| 3 | 178–179 | **loading**: `Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }` |
| 4 | 183–186 | **не знайдено**: `if (state.item == null) Box(Modifier.fillMaxSize(), Alignment.Center) { Text("Матеріал не знайдено", style = MaterialTheme.typography.titleMedium) }` |
| 5 | 197–206 | локальна функція `playAll` (див. 4.3) |
| 6 | 210–213 | `Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(…), verticalArrangement = Arrangement.spacedBy(<dp>), horizontalAlignment = Alignment.Start)` |
| 6.1 | 215–218 | **кнопка повернення**: `TextButton(onClick = onBack)` → `Icon(Icons.Filled.ArrowBack, Modifier.size(<dp>))` + `Spacer(Modifier.width(<dp>))` + `Text("Назад")` |
| 6.2 | 221 | **заголовок**: `Text(item.titleUk, style = MaterialTheme.typography.headlineSmall)` |
| 6.3 | 222–225 | **метадані**: `Text("<titleEs> · <kind.titleUk> · <level.code>", style = bodyMedium, color = onSurfaceVariant)` — літерал-розділювач `" · "` |
| 6.4 | 228–230 | **головна кнопка плеєра**: `PrimaryActionButton(onClick = playAll, text = if (<відтворюється>) "Відтворюється…" else "Слухати повністю", icon = Icons.Filled.PlayArrow)` (`ui/components/NavigationComponentsKt.PrimaryActionButton`) |
| 6.5 | 234–248 | **ряд плеєра**: `Row(horizontalArrangement = Arrangement.spacedBy(<dp>))` з двома `OutlinedButton` однакової ваги: `"Повільно 0.75×"` (L244–245) і `"Зупинити"` (L246–249) |
| 6.6 | 252 | **секція транскрипту**: `SectionTitle("Текст")` (`CommonComponentsKt.SectionTitle`) |
| 6.7 | 253–287 | для кожної репліки `item.lines` — `Card` (L254) з `modifier = Modifier.fillMaxWidth()` (L255) і `colors = CardDefaults.cardColors(containerColor = if (<репліка поточна>) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface)` (L256–260): `Row(Modifier.padding(<dp>), verticalAlignment = Alignment.Top)` → `Text("<speaker>: ", style = titleSmall)` (L266–269; конкатенація `speaker` + літерал `":"`) → `Spacer(Modifier.width(<dp>))` → `Column(Modifier.weight(1f))`: `Text(line.spanish, style = bodyLarge)` (L271–272) і, якщо увімкнено переклад, `Text(line.translationUk, style = bodyMedium, color = onSurfaceVariant)` (L273–277) → `TextButton(onClick = { … tts.speak(line.spanish) })`, вміст — `Icon(Icons.Filled.VolumeUp, contentDescription = "Повторити", Modifier.size(<dp>))` (L281–282) |
| 6.8 | 289–290 | **перемикач перекладу**: `TextButton(Modifier.fillMaxWidth()) { Text(if (showTranslation) "Сховати переклад" else "Показати переклад") }` |
| 6.9 | 293–295 | якщо `item.keyWords.isNotEmpty()` → `SectionTitle("Ключові слова")` + `Card(Modifier.fillMaxWidth(), colors = cardColors(containerColor = surfaceVariant))` |
| 6.10 | 298–309 | вміст картки слів: `Column(Modifier.padding(<dp>), verticalArrangement = spacedBy(<dp>))` → для кожного `WordGloss`: `Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Top)` → `Text(word.spanish, style = bodyLarge, …)` + `Text(word.translationUk, style = bodyMedium, color = onSurfaceVariant)` |
| 6.11 | 317–318 | якщо `item.comprehensionQuestions.isNotEmpty()` → `SectionTitle("Перевірте розуміння")` |
| 6.12 | 321–353 | для кожного питання — `Card(Modifier.fillMaxWidth())` з карткою питання (див. 4.4) |
| 6.13 | 365–375 | **метрики**: `Row(horizontalArrangement = spacedBy(<dp>))` з двома `MetricCard(Modifier.weight(1f), …)` (`CommonComponentsKt.MetricCard-jM_yU8I`): значення — кількість відповідей, підпис `"Відповідей"` (L367–370); значення — кількість правильних, підпис `"Правильно"` (L372–375) |
| 6.14 | 378–382 | **завершення**: `PrimaryActionButton(onClick = { recordListening(<відповідей>, <правильних>); onBack() }, text = "Завершити")` |
| 6.15 | 387 | `Spacer(Modifier.height(<dp>))` — нижній відступ |

**Прогресу відтворення (смуги/слайдера/відсотків) на екрані немає** — `Slider`/`LinearProgressIndicator` у файлі не викликаються; єдиний індикатор прогресу — підсвічування поточної репліки (`primaryContainer`) і підпис кнопки `"Відтворюється…"`. **`LevelHint` на цьому екрані не використовується** (лише у списку, див. 3.1).

### 4.3 Локальний стан і плеєр

| Стан (L191–196) | Тип | Ініціалізація | Використання |
|---|---|---|---|
| `showTranslation` | `MutableState<Boolean>` | `remember { mutableStateOf(false) }` (L191) | L257, L289–290 |
| `currentIndex` | `MutableIntState` (лямбди `lambda$9`/`lambda$10`) | `remember { mutableIntStateOf(…) }` | підсвічування репліки (L257), підпис головної кнопки (L229), встановлюється в `playAll` (L201 — індекс репліки, L204 — скидання) |
| `answeredCount` | `MutableIntState` (`lambda$12`/`lambda$13`) | `remember { mutableIntStateOf(0) }` | метрика `"Відповідей"` (L367–369) |
| `correctCount` | `MutableIntState` (`lambda$15`/`lambda$16`) | `remember { mutableIntStateOf(0) }` | метрика `"Правильно"` (L372–374) |
| `selectedByQuestion` | `SnapshotStateMap<Int, Int>` | `remember { mutableStateMapOf() }` | вибраний варіант для кожного питання; читається при відмальовуванні варіантів (L296 — `SnapshotStateMap.get`) і пишеться при тапі (L329) |

Дії плеєра (з байткоду):

* `playAll` (L197–206): `scope.launch { tts.initialize(); item.lines.forEachIndexed { i, line -> currentIndex = i; tts.speak(line.spanish) }; currentIndex = <скидання> }` — репліки ставляться в чергу TTS послідовно, без `delay`.
* «Повільно 0.75×» (L235–241): `scope.launch { tts.initialize(); tts.setRate(0.75f); item.lines.forEach { tts.speak(it.spanish) }; tts.setRate(1f) }` (значення `0.75f`/`1f` — з підпису кнопки й типового відновлення темпу; самі константи float у текстовому дампі не збереглися, див. Прогалини).
* «Зупинити» (L246–247): `tts.stop()`.
* «Повторити» на репліці (L281): `scope.launch { tts.initialize(); tts.speak(line.spanish) }`.

### 4.4 Питання на розуміння (картка питання, L321–353)

| Порядок | Рядки | Елемент |
|---|---|---|
| 1 | 322–323 | `Column(Modifier.padding(<dp>))` → `Text(question.questionUk, style = MaterialTheme.typography.titleSmall)` |
| 2 | 324 | `Spacer(Modifier.height(<dp>))` |
| 3 | 325–341 | для кожного варіанта `question.options`: `OutlinedButton` (L326) з `modifier = Modifier.fillMaxWidth()` (L334), `shape = RoundedCornerShape(<dp>)` (L335), вміст — `Text(option, style = MaterialTheme.typography.bodyLarge, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())` (L336–341) |
| 4 | 344 | `Spacer(Modifier.height(<dp>))` |
| 5 | 347–357 | **зворотний зв'язок** (показується після вибору варіанта): `Text(text, style = MaterialTheme.typography.bodyMedium, color = if (<відповідь правильна>) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.error)` (L348, L355–357) |

Точні тексти зворотного зв'язку (конкатенація рядків, L350–353):

* правильно: `"✓ Правильно. "` + `question.explanationUk` (літерал із пробілом у кінці);
* неправильно: `"✕ Правильна відповідь: "` + `question.options[question.correctIndex]` + `". "` + `question.explanationUk`;
* кольори: `secondary` — для правильного варіанта, `error` — для неправильного.

### 4.5 Дії користувача — таблиця

| Елемент | Дія | Наслідок |
|---|---|---|
| `TextButton` `"Назад"` (з іконкою `ArrowBack`) | тап | `onBack()` — повернення до списку аудіювання |
| `PrimaryActionButton` `"Слухати повністю"` / `"Відтворюється…"` (іконка `PlayArrow`) | тап | `playAll`: ініціалізація TTS → послідовне озвучення всіх реплік; `currentIndex` = індекс репліки, що звучить; після останньої — скидання |
| `OutlinedButton` `"Повільно 0.75×"` | тап | TTS зі швидкістю 0.75× → озвучення всіх реплік → повернення звичайного темпу |
| `OutlinedButton` `"Зупинити"` | тап | `tts.stop()` — мовлення зупиняється |
| `Icon(VolumeUp)` з `contentDescription = "Повторити"` у картці репліки | тап | повторне озвучення однієї репліки (`line.spanish`) |
| `TextButton` `"Показати переклад"` / `"Сховати переклад"` | тап | перемикає `showTranslation`; під кожною реплікою з'являється/зникає `translationUk` |
| `OutlinedButton` — варіант відповіді на питання | тап | `selectedByQuestion[qIndex] = optionIndex`; `answeredCount` = кількість елементів у мапі; `correctCount` = кількість збігів із `correctIndex`; у картці питання з'являється рядок `"✓ Правильно. …"` або `"✕ Правильна відповідь: …"` |
| `PrimaryActionButton` `"Завершити"` | тап | `recordListening(answeredCount, correctCount)` (запис активності) → одразу `onBack()` |
| Вертикальний свайп | скрол | `Modifier.verticalScroll(rememberScrollState())` на всій колонці |

### 4.6 Фіксація завершення (`recordListening`) і зміна прогресу

| Крок | Деталі |
|---|---|
| Виклик (UI) | L381–382: кнопка `"Завершити"` → `ListeningDetailViewModel.recordListening(<кількість відповідей>, <кількість правильних>)`, далі `onBack()` |
| Реалізація | `ListeningDetailViewModel.recordListening` (L83) → `viewModelScope.launch { … }`; у корутині `ListeningDetailViewModel$recordListening$1.invokeSuspend` L84: `container.users` → `UserRepository.addActivity$default(...)` (запис активності «слухання» в профіль користувача) |
| Що змінюється у прогресу | У профіль додається запис активності (`UserRepository.addActivity`); власне поле «пройдено» в моделі `ListeningItem` відсутнє, тому позначки «прослухано» на картці списку немає. Скільки саме параметрів і з якими значеннями передається в `addActivity` — **не відновлено** (див. Прогалини) |
| Стан екрана | `ListeningDetailViewModel` створюється з `(container, itemId)`; L75–77: у `init` читає `CourseRepository.listeningItems`, знаходить матеріал з `id == itemId` і кладе `ListeningDetailUiState(loading = false, item = знайдений)` |

### 4.7 Усі тексти екрана деталей (дослівно)

| Текст | Де |
|---|---|
| `"Назад"` | кнопка повернення (L218) |
| `" · "` | розділювач у рядку метаданих (L223) |
| `"Слухати повністю"` | головна кнопка плеєра (L229) |
| `"Відтворюється…"` | головна кнопка плеєра під час відтворення (L229) |
| `"Повільно 0.75×"` | кнопка повільного відтворення (L245) |
| `"Зупинити"` | кнопка зупинки (L249) |
| `"Текст"` | заголовок секції транскрипту (L252) |
| `":"` | після імені мовця (`speaker + ":"`, L267) |
| `"Повторити"` | `contentDescription` іконки `VolumeUp` у картці репліки (L282) |
| `"Показати переклад"` | перемикач перекладу, вимкнений (L290) |
| `"Сховати переклад"` | перемикач перекладу, увімкнений (L290) |
| `"Ключові слова"` | заголовок секції (L294) |
| `"Перевірте розуміння"` | заголовок секції питань (L318) |
| `"✓ Правильно. "` | зворотний зв'язок, правильна відповідь (L350) |
| `"✕ Правильна відповідь: "` | зворотний зв'язок, неправильна відповідь (L353) |
| `". "` | розділювач перед поясненням (L353) |
| `"Відповідей"` | підпис метрики (L367) |
| `"Правильно"` | підпис метрики (L372) |
| `"Завершити"` | кнопка завершення (L378) |
| `"Матеріал не знайдено"` | стан «елемент відсутній» (L186) |

Текстів помилок (мережа/TTS) на цьому екрані **не знайдено** — усі повідомлення про помилки мовлення належать класам розпізнавання/TTS (`ua/krupa/spanish/speech/...`).

---

## Прогалини

1. **`ExerciseUiState.canCheck`** — тіло обчислюваної властивості не відновлено (геттер `getCanCheck():Z` викликається з екранів сесії; поля немає, тому в `copy`/`equals`/`toString` вона не входить). Невідомо, з яких саме полів вона виводиться.
2. **Два `Boolean`-параметри `ExerciseContent`** — їхні імена не збереглися в дампі (примітивні типи не проходять `checkNotNullParameter`); за місцем використання ототожнено з `isListening` і `speechHeard` (припущення).
3. **Параметр `speak` у `SpanishStimulus`** — у байткоді тіла не впливає ні на що видиме; у `ExerciseContent` завжди передається `false`. Призначення не встановлено.
4. **Параметр `spanishKeyboard` у `TextInputAnswer`** — у тілі не використовується (єдине читання — розв'язання дефолту аргументу); `true` передано лише в гілці `DICTATION`. Чи впливає він на тип клавіатури в іншій збірці — не встановлено. Також не відновлено, які аргументи `OutlinedTextField` записані на рядках 242–244 (у байткоді згорнулися в дефолти).
5. **Другий параметр `optionOrder` у `ChoiceList`** — у тілі функції не читається (порядок варіантів визначає сам список `options`); де саме формується перемішаний порядок — поза цим файлом.
6. **Числові значення `dp`** (відступи `Arrangement.spacedBy`, `PaddingValues`, `RoundedCornerShape`, `Spacer`, розміри іконок) у текстовому дампі smali не збереглися, крім підтверджених: `RoundedCornerShape(14.dp)` у `SpanishStimulus` та в `TextInputAnswer`, `RoundedCornerShape(14.dp)` у картці `AnswerStrip`, `maxLines = 3`, `minLines = 1`, `ImeAction.Done`.
7. **Джерело рядка `"Почуто: …"`** у гілці `SPEAKING` — конкатенація з літералом `"Почуто: "` підтверджена, але який саме рядок додається (найімовірніше `textAnswer`, єдиний String-параметр блоку) — не встановлено.
8. **Іконка в кнопці `"Прослухати"` (AudioRow)** — метадані лямбди містять групу на рядку 359 (87 символів), але виклик `Icon` у ній не підтверджено (у лямбді достовірно є `Spacer` L361 і `Text("Прослухати")` L362).
9. **`ListeningUiState`: значення за замовчуванням** для `loading`, `level`, `items`, `currentLevel` — не вичитані (маска дефолтного конструктора є, тіло — ні). Також не розрізнено, яке саме поле (`level` чи `currentLevel`) використовує обчислювана `visible` і яке оновлює `selectLevel`.
10. **`ListeningDetailUiState.loading`** — значення за замовчуванням не підтверджено (ймовірно `true`).
11. **`UserRepository.addActivity`** — точний перелік і значення аргументів виклику з `recordListening` (тип активності, лічильники, тривалість) не відновлено; відомо лише, що виклик іде з `viewModelScope.launch` у `ListeningDetailViewModel` (L83–84).
12. **`tts.setRate`** — значення float (очікувано `0.75f` і `1f`) у текстовому дампі не збереглися; підтверджено лише самі виклики.
13. **Скидне значення `currentIndex`** (позначка «нічого не відтворюється») — не підтверджено; логіка UI припускає значення поза межами `0..lines.size-1` (найімовірніше `-1`).
14. **Парування `ListeningKind.MONOLOGUE` / `STORY` з підписами** `"Розповідь"` / `"Історія"` — у дампі рядків константи та підписи відсортовані абеткою, тому відповідність не підтверджена (сам перелік підписів точний: `"Діалог"`, `"Історія"`, `"Подкаст"`, `"Розповідь"`).
15. **Внутрішній вигляд зовнішніх Composable** `EmptyState`, `InfoBanner`, `SectionTitle`, `MetricCard`, `PrimaryActionButton` (`ui/components/CommonComponents.kt`, `NavigationComponents.kt`) — поза охопленням цього файлу (їхні іконки/кольори/відступи не аналізувалися).
16. **Кнопки перевірки відповіді** (`"Перевірити"`, `"Показати відповідь"`, `"Далі"`, `"Правильно"`, `"Правильно: "`) та кольори/іконки зворотного зв'язку для звичайних вправ лежать у `SessionScreen.kt` (`ExerciseBlock`, `FeedbackBlock`) і в цій специфікації наведені лише довідково — їхня точна розкладка потребує окремої специфікації екрана сесії.
17. **Директорія джерел змінилася під час роботи**: шляхи `_work\smali\*.txt` і `content_from_apk\*.json`, з яких знято структуру та підрахунки, на момент запису файлу вже переміщені/відсутні; усі наведені дані отримані з цих файлів до переміщення, а `_recon/strings_by_class.txt` перевірено повторно (без змін).
