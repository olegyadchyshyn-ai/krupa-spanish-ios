# 30. Екрани Home і Learn — точна специфікація UI/UX

Охоплення: `HomeScreen.kt`, `HomeViewModel.kt`, `LearnScreen.kt`, `LearnViewModel.kt` (пакет `ua.krupa.spanish.ui.screens.home` / `...learn`).

Джерела: рядкові константи з `_recon/strings_by_class.txt` (блоки `ComposableSingletons$*`, `*ScreenKt$*`, `*UiState`, `*ViewModel`) та тіла методів із baksmali-дампів `ua/krupa/spanish/ui/`. Номери рядків у таблицях — це номери рядків **вихідних .kt-файлів**, відновлені з Compose-метаданих (`C(HomeScreen)65@2749L6013:HomeScreen.kt`, `... (HomeScreen.kt:71)`) і з таблиць `positions` smali. Компіляторний шум (метадані груп, `toLowerCase(...)`, `call to 'resume'…`, `$this$item`, `$this$Card`, `$this$LazyColumn`, `C(…)`/`CC(…)`-рядки) у тексти не потрапляє.

---

# 1. Home — `HomeScreen.kt` + `HomeViewModel.kt`

## 1.1. Призначення

Головний екран застосунку: вітання користувача з його рівнем і ціллю, картка прогресу рівня, «Урок дня», блок прострочених повторень, чотири метрики дня, банер слабкого місця та список карток-переходів у розділи (тренування: слухання, говоріння, AI-діалог, слова, налаштування). Дані надходять із `HomeViewModel`, що слухає `ProgressRepository` і `UserRepository` та будує план заняття через `LessonBuilder`.

Публічна сигнатура (з smali):

```kotlin
@Composable
fun HomeScreen(
    container: AppContainer,
    onNavigate: (String) -> Unit,   // маршрут
    onStartSession: (Int) -> Unit,  // хвилини сесії
)   // HomeScreen.kt:57
```

## 1.2. UiState — `HomeUiState` (HomeViewModel.kt)

| Поле | Тип | Призначення | Значення за замовчуванням |
|---|---|---|---|
| `loading` | `Boolean` | стан первинного завантаження (у розмітці Home **не використовується** — жодного читання `getLoading()` у HomeScreen немає) | `false` |
| `profile` | `UserProfile` | профіль користувача (ім'я, рівень, ціль, денна норма хвилин) | `defaultProfile()` (`UserProfileKt.defaultProfile()`) |
| `progress` | `ProgressSnapshot?` | знімок прогресу (рівень, метрики дня, серія, черга повторень, слабкі місця) | `null` |
| `plan` | `SessionPlan?` | план «Уроку дня» (`reasonUk`, `itemCount`, …) | `null` |

Порядок властивостей (з сигнатури конструктора `(Z, UserProfile, ProgressSnapshot, SessionPlan)V`): `loading`, `profile`, `progress`, `plan`. Конструктор без аргументів `HomeUiState()` задає маску за замовчуванням для всіх чотирьох полів.

Дані, які Home читає з `ProgressSnapshot` (за викликами getter-ів у smali): `level` (`Level.code`, `Level.titleUk`), `levelPercent`, `grammarLearned`, `retentionPercent`, `todayNewWords`, `todayReviews`, `todayMinutes`, `streakDays`, `dueNow`, `weakSpots` (`List<WeakSpot>`: `titleUk`, `mastery`, `stat.attempts`). Для картки «Слова» використовуються два цілочисельні поля, склеєні через `"/"` (точні імена getter-ів не зафіксовано — див. «Прогалини»).

## 1.3. HomeViewModel — дії

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `<init>` | `container: AppContainer` | створює `_state = MutableStateFlow(HomeUiState())`, `state = _state.asStateFlow()`; у `viewModelScope` запускає два колектори | початковий стан — усі поля за замовчуванням |
| колектор №1 (лямбда `HomeViewModel$1$1.emit`) | `ProgressSnapshot` з `container.progressRepository.observeSnapshot()` | на кожну емісію: `_state.value = _state.value.copy(loading = false, progress = snapshot)`; якщо `snapshot.level` відрізняється від попереднього `progress?.level` — викликає `refreshPlan(snapshot.level)` | `loading = false`, `progress = snapshot` |
| колектор №2 (лямбда `HomeViewModel$2$1.emit`) | `UserProfile` з `container.users.observeProfile()` | `_state.value = _state.value.copy(profile = profile)` | `profile = profile` |
| `refreshPlan` | `level: Level` (є `refreshPlan$default`, тобто параметр має значення за замовчуванням) | у `viewModelScope`: бере `_state.value.profile`, робить `profile.copy(level = level)`, викликає `container.lessonBuilder.buildPlan(профіль, profile.dailyMinutes, …)`, результат кладе в стан | `plan = <новий SessionPlan>` |
| `getState()` | — | повертає `StateFlow<HomeUiState>` (`val state`) | — |

## 1.4. Структура екрана зверху вниз

Кореневий контейнер — **`LazyColumn`** (без `Scaffold`/`TopAppBar` — їх у розмітці екрана немає; верхня панель і нижній бар належать оболонці застосунку):

```kotlin
LazyColumn(
    modifier = Modifier.fillMaxWidth(),              // HomeScreen.kt:68
    contentPadding = PaddingValues(16.dp),           // усі сторони 16.dp
    verticalArrangement = Arrangement.spacedBy(14.dp),
) { … }                                              // тіло: HomeScreen.kt:65…236
```

Порядок елементів (усі — `LazyListScope.item`, крім двох `items`):

| № | Рядок HomeScreen.kt | Елемент | Composable-компоненти | Дані |
|---|---|---|---|---|
| 1 | 71 | Вітальний блок (лише коли `profile` є) | `Column`, `Text`, `Spacer(height 4.dp)` | `profile.name`, `profile.level.code`, `profile.goal.titleUk` |
| 2 | 88 (умовно: `progress != null`) | Картка прогресу рівня | `LevelProgressCard(progress)` (приватний) | `ProgressSnapshot` |
| 3 | 91–92 | Підзаголовок «Сьогодні» | `SectionTitle(…)` | `profile.dailyMinutes` |
| 4 | 94–101 | Картка «Урок дня» | `ActionCard(…)` + `Icons.Filled.School` | `plan?.reasonUk`, `plan?.itemCount` |
| 5 | 105–115 | Картка «Повторення» | `ActionCard(…)` + `Icons.Filled.Style` | `progress?.dueNow` |
| 6 | 120–134 | Ряд із двома метриками | `Row`, `MetricCard` ×2 (`Modifier.weight(1f)`) | `todayNewWords`, `todayReviews` |
| 7 | 137–151 | Ряд із двома метриками | `Row`, `MetricCard` ×2 (`Modifier.weight(1f)`) | `todayMinutes` + `profile.dailyMinutes`; `streakDays` |
| 8 | 155–157 (умовно: `progress?.weakSpots?.firstOrNull() != null`) | Банер слабкого місця | `InfoBanner(…)` + `Icons.Filled.Insights` | перший `WeakSpot` |
| 9 | 166–167 | Підзаголовок розділу тренувань | `SectionTitle("Тренування")` | — |
| 10 | 169–176 | Картка «Слухання» | `ActionCard(…)` + `Icons.Filled.GraphicEq` | навігація `listening` |
| 11 | 178–185 | Картка «Говоріння» | `ActionCard(…)` + `Icons.Filled.Mic` | навігація `speaking` |
| 12 | 187–194 | Картка «AI-діалог» | `ActionCard(…)` + `Icons.Filled.RecordVoiceOver` | навігація `ai_dialog` |
| 13 | 196–203 | Картка «Слова» | `ActionCard(…)` + `Icons.Filled.AutoStories` | навігація `words` |
| 14 | 205–212 | Картка «Налаштування» | `ActionCard(…)` + `Icons.Filled.Tune` | навігація `settings` |
| 15 | 216–231 (умовно: `progress?.weakSpots` не порожній) | Підзаголовок «Слабкі теми» + картки тем | `SectionTitle("Слабкі теми")` (рядок 218), `items(weakSpots)`, `Card(containerColor = surface, Modifier.fillMaxWidth())`, `MasteryBar` | `WeakSpot.titleUk`, `.mastery`, `.stat.attempts` |
| 15-альт | 233–234 (`else`) | Порожній відступ замість секції слабких тем | `Spacer(Modifier.height(…))` | — |

Примітки до порядку: рядки відновлені з послідовності викликів `LazyListScope.item$default` / `items` та з таблиці `positions` лямбди `HomeScreen$1` (`0x0005 line=71, 0x001f line=87, 0x003c line=92, 0x0055 line=94, 0x006f line=105, 0x0086 line=120, 0x009a line=137, 0x00b1 line=155, 0x00dd line=167, 0x00eb line=169, 0x0100 line=178, 0x0115 line=187, 0x012a line=196, 0x013f line=205, 0x0154 line=216, 0x016e line=218, 0x017c line=219, 0x01a4 line=234`).

Умова показу картки прогресу — `if (progress != null)`; умова банера — перший елемент `weakSpots` не `null`; умова секції «Слабкі теми» — `weakSpots.isNotEmpty()`.

## 1.5. Внутрішні Composable екрана

### `LevelProgressCard(progress: ProgressSnapshot)` — HomeScreen.kt:238–279 (приватна)

* `Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.secondaryContainer), modifier = Modifier.fillMaxWidth())` (рядки 239–241)
* `Column(Modifier.padding(…))` (точної величини padding у дампі не зафіксовано)
  * `Row(verticalAlignment = Alignment.CenterVertically)`
    * `Text("<code> → <levelPercent>%", style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onSecondaryContainer)` — рядок 247; рядок складено через `StringBuilder`: `level.code` + `" → "` + `levelPercent` (`Int`) + `"%"`
    * `Spacer(Modifier.width(10.dp))` — рядок 251 (у smali `const/16 … #int 10` → `Dp` → `SizeKt.width`)
    * `Text(level.titleUk, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.8f))` — рядки 252–255 (альфа `0.8f` підтверджена в байт-коді)
  * `Spacer(Modifier.height(…))` — рядок 257
  * `LinearProgressIndicator(progress = { … }, modifier = Modifier.fillMaxWidth().height(…dp), color = MaterialTheme.colorScheme.primary, trackColor = MaterialTheme.colorScheme.onSecondaryContainer)` — рядок 258; прогрес обчислюється лямбдою `LevelProgressCard$1$1$2` (`Function0<Float>`)
  * `Spacer` — рядки 263, 264, 267
  * `Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween)` — рядок 268
    * `MiniStat("Слова", "<N>/<M>")` — рядок 272 (склейка двох `Int` через `"/"`)
    * `MiniStat("Граматика", "<grammarLearned>")` — рядок 273 (`ProgressSnapshot.getGrammarLearned()` → `String.valueOf`)
    * `MiniStat("Точність", "<retentionPercent>%")` — рядок 274 (`ProgressSnapshot.getRetentionPercent()` + `"%"`)
* Картка не клікабельна (використано не-clickable перевантаження `CardKt.Card`).

### `MiniStat(labelUk: String, value: String)` — HomeScreen.kt:281–295 (приватна)

* `Column` (вирівнювання за початком, `Arrangement.Top`)
  * `Text(labelUk, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.75f))` — рядки 283–287
  * `Text(value, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.onSecondaryContainer)` — рядки 288–292

### Лямбди-обгортки (для ідентифікації в байт-коді)

| Клас | Рядок | Роль |
|---|---|---|
| `ComposableSingletons$HomeScreenKt.lambda-1$1` | 166 | `SectionTitle("Тренування")` |
| `ComposableSingletons$HomeScreenKt.lambda-2$1` | 217 | `SectionTitle("Слабкі теми")` |
| `ComposableSingletons$HomeScreenKt.lambda-3$1` | 233 | `Spacer(Modifier.height(…))` (гілка `else`) |
| `HomeScreen$1$1` | 71 | вітальний блок |
| `HomeScreen$1$2` | 87–88 | виклик `LevelProgressCard` |
| `HomeScreen$1$3` | 91–92 | `SectionTitle` |
| `HomeScreen$1$4` | 94–101 | «Урок дня» |
| `HomeScreen$1$5` | 105–115 | «Повторення» |
| `HomeScreen$1$6` | 120–134 | метрики «Нових слів» / «Повторень» |
| `HomeScreen$1$7` | 137–151 | метрики «Хвилин» / «Серія днів» |
| `HomeScreen$1$8` | 155–157 | банер слабкого місця |
| `HomeScreen$1$9` | 169–176 | «Слухання» |
| `HomeScreen$1$10` | 178–185 | «Говоріння» |
| `HomeScreen$1$11` | 187–194 | «AI-діалог» |
| `HomeScreen$1$12` | 196–203 | «Слова» |
| `HomeScreen$1$13` | 205–212 | «Налаштування» |
| `HomeScreen$1$14$1` (= `HomeScreen$1$invoke$$inlined$items$default$4`) | 219–230 | вміст картки слабкої теми (`MasteryBar`) |

## 1.6. Спільні компоненти, використані на Home (сигнатури з smali)

| Компонент | Файл | Параметри (у порядку виклику) |
|---|---|---|
| `SectionTitle` | `ui/components/CommonComponentsKt` | `(text: String, modifier: Modifier?)` |
| `ActionCard` | `ui/components/NavigationComponentsKt` | `(titleUk: String, subtitleUk: String, icon: ImageVector, primary: Boolean, onClick: () -> Unit, modifier: Modifier?, trailing: String?)` |
| `MetricCard` | `ui/components/CommonComponentsKt` | `(labelUk: String, value: String, modifier: Modifier?, hintUk: String?, accent: Color, icon: ImageVector?)`; на Home `accent` і `icon` не задані (типові), `modifier = Modifier.weight(1f)` |
| `InfoBanner` | `ui/components/CommonComponentsKt` | `(text: String, modifier: Modifier?, accent: Color, contentColor: Color, icon: ImageVector?)`; на Home колір типові, є іконка `Icons.Filled.Insights` |
| `MasteryBar` | `ui/components/CommonComponentsKt` | `(titleUk: String, percent: Int, modifier: Modifier?, attempts: Int?)`; на Home `modifier = Modifier.padding(horizontal = 14.dp)`, `attempts = spot.stat.attempts` |

## 1.7. УСІ видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Вітання, якщо ім'я порожнє (`name.isBlank()`) | `"Вітаю!"` |
| Вітання, якщо ім'я задане | `"Вітаю, "` + `profile.name` + `"!"` |
| Підзаголовок під вітанням | `"Іспанська Іспанії · рівень "` + `profile.level.code` + `" · ціль: "` + `profile.goal.titleUk.lowercase(Locale.ROOT)` |
| Підзаголовок над «Уроком дня» | `"Сьогодні · "` + `profile.dailyMinutes` + `" хв"` |
| Картка «Урок дня» — заголовок | `"Урок дня"` |
| Картка «Урок дня» — підзаголовок, коли план ще не готовий (`plan?.reasonUk == null`) | `"Формуємо план заняття…"` |
| Картка «Урок дня» — підзаголовок, коли план є | `plan.reasonUk` (динамічний текст із даних) |
| Картка «Урок дня» — правий «trailing» | `plan.itemCount` (число, `String.valueOf`) |
| Картка «Повторення» — заголовок | `"Повторення"` |
| Картка «Повторення» — підзаголовок, коли `dueNow > 0` | `"Чекає карток: "` + `dueNow` |
| Картка «Повторення» — підзаголовок, коли `dueNow <= 0` | `"Прострочених повторень немає"` |
| Картка «Повторення» — правий «trailing» | `dueNow` (число) |
| Метрика 1 | `"Нових слів"`, значення — `progress?.todayNewWords ?: 0`, підпис `"сьогодні"` |
| Метрика 2 | `"Повторень"`, значення — `progress?.todayReviews ?: 0`, підпис `"сьогодні"` |
| Метрика 3 | `"Хвилин"`, значення — `progress?.todayMinutes ?: 0`, підпис `"мета: "` + `profile.dailyMinutes` |
| Метрика 4 | `"Серія днів"`, значення — `progress?.streakDays ?: 0`, підпис `"тримайте темп"` (якщо `streakDays > 0`) або `"почніть сьогодні"` |
| Банер слабкого місця | `"Слабке місце: "` + `weakSpot.titleUk.lowercase(Locale.ROOT)` + `" — "` + `weakSpot.mastery` + `"%. Додали більше вправ на цю тему."` |
| Підзаголовок розділу | `"Тренування"` |
| Картка «Слухання» | заголовок `"Слухання"`, підзаголовок `"Розуміння на слух за рівнями"` |
| Картка «Говоріння» | заголовок `"Говоріння"`, підзаголовок `"Вимова з оцінкою й розбором помилок"` |
| Картка «AI-діалог» | заголовок `"AI-діалог"`, підзаголовок `"Розмова з викладачем або рольова гра"` |
| Картка «Слова» | заголовок `"Слова"`, підзаголовок `"Словник зі станом запам'ятовування"` |
| Картка «Налаштування» | заголовок `"Налаштування"`, підзаголовок `"Профіль, аудіо, експорт прогресу"` |
| Підзаголовок секції слабких тем | `"Слабкі теми"` |
| Картка прогресу: рядок рівня | `progress.level.code` + `" → "` + `progress.levelPercent` + `"%"` |
| Картка прогресу: назва рівня | `progress.level.titleUk` (динамічний текст із даних) |
| Картка прогресу: міністат 1 | підпис `"Слова"`, значення `<N>/<M>` (розділювач — `"/"`) |
| Картка прогресу: міністат 2 | підпис `"Граматика"`, значення `grammarLearned` |
| Картка прогресу: міністат 3 | підпис `"Точність"`, значення `retentionPercent` + `"%"` |

Окремі літерали-фрагменти, які треба зберегти в порту дослівно: `"Вітаю!"`, `"Вітаю, "`, `"!"`, `"Іспанська Іспанії · рівень "`, `" · ціль: "`, `"Сьогодні · "`, `" хв"`, `"Урок дня"`, `"Формуємо план заняття…"`, `"Повторення"`, `"Чекає карток: "`, `"Прострочених повторень немає"`, `"Нових слів"`, `"Повторень"`, `"сьогодні"`, `"Хвилин"`, `"мета: "`, `"Серія днів"`, `"тримайте темп"`, `"почніть сьогодні"`, `"Слабке місце: "`, `" — "`, `"%. Додали більше вправ на цю тему."`, `"Тренування"`, `"Слухання"`, `"Розуміння на слух за рівнями"`, `"Говоріння"`, `"Вимова з оцінкою й розбором помилок"`, `"AI-діалог"`, `"Розмова з викладачем або рольова гра"`, `"Слова"`, `"Словник зі станом запам'ятовування"`, `"Налаштування"`, `"Профіль, аудіо, експорт прогресу"`, `"Слабкі теми"`, `" → "`, `"%"`, `"/"`, `"Граматика"`, `"Точність"`.

УВАГА щодо `"%. Додали більше вправ на цю тему."` — це **не** форматний рядок із `%s`/`%.0f`: у байт-коді він присутній дослівно як `"%. Додали більше вправ на цю тему."` і приклеюється до числа `mastery` (тобто в UI видно, напр., `… — 45%. Додали більше вправ на цю тему.`). У SwiftUI цей фрагмент треба відтворити символ-у-символ.

## 1.8. Стани

| Стан | Що показується | Текст |
|---|---|---|
| loading | Окремого індикатора немає; `HomeUiState.loading` у розмітці не читається. Поки `progress == null` — картка прогресу (пункт 2) не рендериться, метрики показують `0`, підзаголовок «Повторення» — `"Прострочених повторень немає"`. Поки `plan == null` — підзаголовок «Уроку дня» = `"Формуємо план заняття…"`, `trailing` порожній. | `"Формуємо план заняття…"`, `"Прострочених повторень немає"` |
| empty (немає слабких тем) | Банер слабкого місця і секція «Слабкі теми» не показуються; у `else`-гілці додається лише `Spacer`. | текст не знайдено (порожній `Spacer`) |
| empty (немає прострочених повторень) | Картка «Повторення» лишається, підзаголовок змінюється. | `"Прострочених повторень немає"` |
| error | UI помилки в HomeScreen відсутній; окремих текстів помилок немає. | текст не знайдено |
| success | Повний набір: вітання + картка прогресу + «Урок дня» + «Повторення» + 2 ряди метрик + (за наявності) банер і секція слабких тем + 6 карток розділів. | див. 1.7 |

## 1.9. Дії користувача

| Елемент | Дія | Наслідок | Навігація / виклик ViewModel |
|---|---|---|---|
| Картка «Урок дня» | тап | старт сесії | `onStartSession(<хвилини>)` — лямбда `HomeScreen$1$4$1$1` захоплює `onStartSession` і `profile`, тому аргумент береться з профілю (найімовірніше `profile.dailyMinutes`; точний вираз не зафіксовано) |
| Картка «Повторення» | тап | перехід у повторення | `onNavigate("review")` |
| Картка «Слухання» | тап | перехід у слухання | `onNavigate("listening")` |
| Картка «Говоріння» | тап | перехід у говоріння | `onNavigate("speaking")` |
| Картка «AI-діалог» | тап | перехід в AI-діалог | `onNavigate("ai_dialog")` |
| Картка «Слова» | тап | перехід у словник | `onNavigate("words")` |
| Картка «Налаштування» | тап | перехід у налаштування | `onNavigate("settings")` |
| Картка прогресу рівня | — | не клікабельна | — |
| Метрики (`MetricCard`) | — | не клікабельні (у сигнатурі немає `onClick`) | — |
| Банер слабкого місця (`InfoBanner`) | — | не клікабельний | — |
| Картки слабких тем (`Card` + `MasteryBar`) | — | не клікабельні (не-clickable перевантаження `Card`) | — |
| Скрол | вертикальний скрол `LazyColumn` | — | — |

Рядки маршрутів у байт-коді (лямбди `HomeScreen$1$N$1$1`): `listening`, `speaking`, `ai_dialog`, `words`, `settings`, `review`.

## 1.10. Діалоги / підтвердження

Немає. У HomeScreen відсутні `AlertDialog`, `Dialog`, `Snackbar`-хости, `BottomSheet` — жодних діалогових компонентів у розмітці екрана не виявлено.

---

# 2. Learn — `LearnScreen.kt` + `LearnViewModel.kt`

## 2.1. Призначення

Екран навчального курсу: інтро-заголовок, ряд вибору рівня (CEFR), картка з інформацією про вибраний рівень, список карток тем для вибраного рівня, банер-підказка про закриті рівні та блок «Граматика українською». Дані готує `LearnViewModel`: тягне профіль, теми курсу, картки SRS і грамнотатки, групує теми за рівнями та визначає, які теми відкриті.

Публічна сигнатура (з smali):

```kotlin
@Composable
fun LearnScreen(
    container: AppContainer,
    onOpenTopic: (String) -> Unit,   // id теми
)   // LearnScreen.kt:40
```

## 2.2. UiState — `LearnUiState` та `TopicSummary` (LearnViewModel.kt)

`LearnUiState`:

| Поле | Тип | Призначення | Значення за замовчуванням |
|---|---|---|---|
| `loading` | `Boolean` | стан завантаження; після `load()` завжди `false` | не встановлено (конструктор без аргументів використовує маску типових значень; у розмітці екрана `loading` не читається) |
| `level` | `Level` | рівень користувача з профілю (у `load()` = `profile.level`) | не встановлено |
| `topicsByLevel` | `Map<Level, List<TopicSummary>>` | теми, згруповані за рівнями (ключі — `Level.mvpLevels`) | не встановлено (порожня мапа) |
| `selectedLevel` | `Level` | вибраний користувачем рівень; у `load()` ініціалізується `profile.level` | не встановлено |
| `grammarNotes` | `List<GrammarNote>` | грамнотатки, відсортовані через `sortedBy { … }` | не встановлено (порожній список) |

Порядок властивостей (з сигнатури конструктора `(Z, Level, Map, Level, List)V`): `loading`, `level`, `topicsByLevel`, `selectedLevel`, `grammarNotes`.

Похідні властивості (є методи-геттери в байт-коді):

| Властивість | Реалізація | Призначення |
|---|---|---|
| `visibleTopics` | `topicsByLevel[selectedLevel] ?: emptyList()` (LearnViewModel.kt:31) | теми для показу в списку |
| `availableLevels` | обчислювана властивість (`getAvailableLevels()`); точна реалізація не зафіксована | набір рівнів для перемикача |

`TopicSummary` (окремий клас у `LearnViewModel.kt`):

| Поле | Тип | Призначення | Значення за замовчуванням |
|---|---|---|---|
| `topic` | `Topic` | тема курсу (`id`, `level`, назва) | немає (обов'язкове) |
| `wordCount` | `Int` | усього слів у темі (`CourseRepository.wordsByTopic(topic.id).size`) | немає |
| `learnedCount` | `Int` | скільки слів теми вже «вивчено»: картка SRS існує і її `phase != CardPhase.NEW` | немає |
| `unlocked` | `Boolean` | тема відкрита: `topic.level.ordinal <= profile.level.ordinal` | немає |

## 2.3. LearnViewModel — дії

| Метод | Параметри | Що робить | Вплив на стан |
|---|---|---|---|
| `<init>` | `container: AppContainer` | створює `_state = MutableStateFlow(LearnUiState(…))`, `state = _state.asStateFlow()`; запускає в `viewModelScope` корутину, що викликає `load()` | початковий стан (типові значення) |
| `load()` | — (приватна, `suspend`, у `LearnViewModel$load$1`) | 1) `container.users.profile()`; 2) `container.courses.topics().sortedBy { … }`; 3) `container.srsEngine.allCards()`; 4) з карток формує мапу `word`-карток за `itemId`; 5) для кожної теми бере `container.courses.wordsByTopic(topic.id)` і рахує `learnedCount` (картка є і `phase != CardPhase.NEW`), будує `TopicSummary(topic, wordCount, learnedCount, unlocked = topic.level.ordinal <= profile.level.ordinal)`; 6) групує теми за `Level.mvpLevels` у `topicsByLevel`; 7) `container.courses.grammarNotes().sortedBy { … }` | повністю перезаписує стан: `LearnUiState(loading = false, level = profile.level, topicsByLevel = …, selectedLevel = profile.level, grammarNotes = …)` |
| `selectLevel` | `level: Level` | `_state.value = _state.value.copy(selectedLevel = level)` (маска `copy$default` підтверджує: змінюється лише `selectedLevel`) | `selectedLevel = level` (відтак змінюється `visibleTopics`) |
| `getState()` | — | повертає `StateFlow<LearnUiState>` | — |

## 2.4. Структура екрана зверху вниз

Каркас екрана (з Compose-метаданих класу `LearnScreenKt`):

```kotlin
@Composable
fun LearnScreen(container: AppContainer, onOpenTopic: (String) -> Unit) {   // :40
    val viewModel = viewModel(factory = LearnViewModelFactory(container))   // :42
    val state by viewModel.state.collectAsStateWithLifecycle()              // :43–44
    Box(Modifier.fillMaxSize()) {                                           // :45 (27 символів — саме такий вираз)
        LazyColumn(…) {                                                     // :49 (група 49@2078L3870 → рядки 49–146)
            …
        }
    }
}
```

`Scaffold`/`TopAppBar` у розмітці LearnScreen немає. Параметри `LazyColumn` (contentPadding, verticalArrangement) зафіксувати не вдалося.

Порядок елементів списку:

| № | Рядки LearnScreen.kt | Елемент | Composable-компоненти | Дані |
|---|---|---|---|---|
| 1 | 55–66 | Інтро-заголовок: `Text("Навчання")`, `Spacer`, `Text(<опис курсу>)` | `Column`, `Text` ×2, `Spacer` | статичні тексти |
| 2 | 69–84 | Ряд вибору рівня: `Row`, усередині inline-цикл (`forEach`) по рівнях; на кожен рівень — чип із підписом | `Row` + компонент-чип (не-inline composable; у списку рядкових констант класу жодних `C(...)`-метаданих чипа немає, тому це зовнішній composable), підпис чипа — `Text(<level.code>)` (рядок 77) | `state.availableLevels`, `state.selectedLevel`, `viewModel.selectLevel` |
| 3 | 85–116 | `Card` з інформацією про вибраний рівень; вміст — `Column` із `Row`-ами та текстовими блоками (рядки 91–114); один із текстів склеюється з двох значень через `" — "` | `Card`, `Column`, `Row`, `Text` | `state` (лише читання; `viewModel` ця лямбда **не** захоплює) |
| 4 | 117–122 (умовно) | Банер-підказка про закритий рівень | `InfoBanner` (без іконки, типові кольори) | `state.selectedLevel.code` |
| 5 | 136–142 | Блок «Граматика українською»: заголовок (136–137) + опис (138–142) | `Text`/`SectionTitle` + `Text` | `grammarNotes` (кількість тем) |
| 6 | 149–159 (`items`) | Список карток тем | `items(count = visibleTopics.size, key = …, contentType = …, itemContent = …)` → `LearningComponentsKt.TopicCard(topic, wordCount, learnedCount, unlocked, onClick, modifier)` | `LearnUiState.visibleTopics` |

Лямбди, за якими відновлено порядок:

| Клас | Рядок | Примітка |
|---|---|---|
| `ComposableSingletons$LearnScreenKt.lambda-1$1` | 55 | інтро-блок (елемент № 1) |
| `LearnScreenKt$LearnScreen$3$1` | 69 | ряд рівнів; захоплює `State` **і `LearnViewModel`** (єдине місце, звідки викликається `selectLevel`) |
| `LearnScreenKt$LearnScreen$3$1$1$1$2` | 77 | лямбда вмісту чипа: `Text(<level.code>)` (група `C77@3239L16`, 16 символів) |
| `LearnScreenKt$LearnScreen$3$2` | 85 | картка рівня; захоплює лише `State` |
| `LearnScreenKt$LearnScreen$3$2$1` | 91 | вміст картки (рядки 91–114) |
| `LearnScreenKt$LearnScreen$3$4` | 118 | банер-підказка |
| `LearnScreenKt$LearnScreen$3$1`…`$3$6` | 136 | блок граматики |
| `LearnScreenKt$LearnScreen$3$invoke$$inlined$items$default$4` | 149, 427–434 | лямбда елемента списку → `TopicCard` |
| `LearnScreenKt$LearnScreen$3$5$1` | — | `onClick` картки теми (`Function0`), захоплює `onOpenTopic` і `TopicSummary` |

Умова показу банера (№ 4) у байт-коді: гілка `if-gt selectedLevel.ordinal, level.ordinal` **пропускає** елемент, тобто пункт рендериться, коли `state.selectedLevel.ordinal <= state.level.ordinal` (`LearnScreen.kt:117–118`, лямбда `LearnScreen$3$3` у `let`). Оскільки `level` і `selectedLevel` в `load()` обидва дорівнюють `profile.level`, банер видно вже в початковому стані; змістовна інтерпретація цієї умови суперечлива — див. «Прогалини».

## 2.5. УСІ видимі тексти (дослівно)

| Місце в UI | Текст |
|---|---|
| Заголовок екрана (елемент № 1) | `"Навчання"` |
| Опис курсу (елемент № 1) | `"Курс побудований за рівнями CEFR. Кожна тема — це набір слів, граматика й вправи, які разом ведуть до наступного рівня."` |
| Підпис чипа рівня (елемент № 2) | `level.code` — динамічний текст із даних (напр. `A1`); літералів у коді немає |
| Текст у картці рівня (елемент № 3, рядки 99–110) | склейка двох значень через літерал `" — "` (напр. `<код рівня> — <назва рівня>`); точні операнди не зафіксовано |
| Банер-підказка (елемент № 4) | `"Теми цього рівня відкриються, коли ви перейдете на "` + `selectedLevel.code` + `". Рівень можна змінити вручну в Налаштуваннях."` |
| Заголовок блоку граматики (елемент № 5) | `"Граматика українською"` |
| Опис блоку граматики (елемент № 5) | `"Пояснення не «вивчи правило», а «чому іспанці кажуть саме так». Доступно "` + `<кількість>` + `" тем."` |
| Картки тем (елемент № 6) | тексти всередині `TopicCard` (назва теми, кількості слів) — поза межами чотирьох файлів завдання; текст не знайдено |

Літерали-фрагменти для порту: `"Навчання"`, `"Курс побудований за рівнями CEFR. Кожна тема — це набір слів, граматика й вправи, які разом ведуть до наступного рівня."`, `" — "`, `"Теми цього рівня відкриються, коли ви перейдете на "`, `". Рівень можна змінити вручну в Налаштуваннях."`, `"Граматика українською"`, `"Пояснення не «вивчи правило», а «чому іспанці кажуть саме так». Доступно "`, `" тем."`.

Зверніть увагу: у тексті опису граматики вжиті українські лапки-«ялинки» `«…»` — їх треба відтворити дослівно.

## 2.6. Стани

| Стан | Що показується | Текст |
|---|---|---|
| loading | Окремого індикатора завантаження в розмітці LearnScreen немає; `loading` у жодній лямбді екрана не читається. До завершення `load()` список порожній (Box + порожній LazyColumn). | текст не знайдено |
| empty (немає тем для вибраного рівня) | `visibleTopics` порожній → секція карток тем не рендерить жодного елемента; заголовки, картка рівня й блок граматики лишаються. | текст не знайдено (порожній список) |
| error | Обробки помилок і текстів помилок у LearnScreen/LearnViewModel немає. | текст не знайдено |
| success | Інтро + ряд чипів рівнів + картка рівня + (умовно) банер + блок граматики + картки тем. | див. 2.5 |
| закриті теми | Картки тем із `unlocked = false` рендеряться компонентом `TopicCard` (візуальне позначення «закрито» — поза межами чотирьох файлів). | текст не знайдено |

## 2.7. Дії користувача

| Елемент | Дія | Наслідок | Навігація / виклик ViewModel |
|---|---|---|---|
| Чип рівня в ряду (елемент № 2) | тап | вибір іншого рівня; список тем перебудовується (`visibleTopics`) і умовний банер переоцінюється | `LearnViewModel.selectLevel(level)` |
| Картка теми (елемент № 6) | тап | відкриття теми | `onOpenTopic(<id теми>)` — лямбда `LearnScreen$3$5$1` захоплює `onOpenTopic` і `TopicSummary`; точний вираз (`.topic.id`) не зафіксовано |
| Картка рівня (елемент № 3) | — | не клікабельна (лямбда не має доступу до `viewModel`) | — |
| Банер-підказка | — | не клікабельний | — |
| Скрол | вертикальний скрол `LazyColumn` | — | — |

## 2.8. Діалоги / підтвердження

Немає. У LearnScreen відсутні `AlertDialog`, `Dialog`, `Snackbar`-хости, `BottomSheet`.

---

## Прогалини

1. **Знищене джерело.** Під час аналізу теку `_work\smali\` (baksmali-дампи `classes*_ui.txt`) було видалено стороннім процесом. Частину фактів знято до видалення; усе, що не встигли прочитати, позначено нижче. Рядкові константи (`_recon/strings_by_class.txt`) збереглися, тому **всі видимі тексти обох екранів вичерпні** — прогалини стосуються лише структури/стилів.
2. **Learn, рядок рівня (елемент № 2, LearnScreen.kt:69–84).** Точний компонент чипа (material3 `FilterChip` vs власний компонент із `ui/components`) і повний набір аргументів не встановлено: у класі `LearnScreen$3$1` немає жодного рядкового літерала й жодного `C(<Component>)`-рядка. Достовірно: це `Row` з inline-циклом (група `*74@3060L276`), підпис чипа — `Text(<level.code>)` (рядок 77), лямбда захоплює `LearnViewModel` (тобто це єдине місце виклику `selectLevel`).
3. **Learn, картка рівня (елемент № 3, LearnScreen.kt:85–116).** Відомо: `Card`, усередині `Column`, `Row`, кілька текстових блоків (рядки 92, 93, 95, 99, 102, 106, 107, 109, 110) і один складений текст із розділювачем `" — "`. Невідомо: які саме значення склеюються, які стилі/кольори використано, чи є всередині `LinearProgressIndicator`/`MasteryBar`.
4. **Learn, банер-підказка: суперечлива умова.** За байт-кодом пункт показується при `selectedLevel.ordinal <= level.ordinal`, але текст банера («Теми цього рівня відкриються, коли ви перейдете на …») логічно відповідає протилежному випадку (`selectedLevel` вище за рівень користувача). Імовірна особливість/помилка оригіналу; для порту потрібне рішення власника продукту.
5. **Learn, стилі тексту.** Для `"Навчання"`, опису курсу, заголовка й опису блоку граматики конкретні `MaterialTheme.typography.*` та кольори не зафіксовано (відомо лише, що це `Text`-елементи з типографікою теми).
6. **Learn, параметри `LazyColumn`** (contentPadding, verticalArrangement, modifier) — не зафіксовано.
7. **Learn, початкові значення `LearnUiState`** (конструктор без аргументів: `loading`, `level`, `selectedLevel`, `topicsByLevel`, `grammarNotes`) і реалізація похідної властивості `availableLevels` — не зафіксовано.
8. **Learn, джерело числа в описі граматики** (`"…Доступно " + N + " тем."`) — точний вираз (найімовірніше `state.grammarNotes.size`) не підтверджено.
9. **Learn, `onClick` картки теми** — точний вираз (`onOpenTopic(summary.topic.id)`) не підтверджено; відомо лише, що лямбда `LearnScreen$3$5$1` захоплює `onOpenTopic` і `TopicSummary`.
10. **Home, `Accuracy`/`Слова` у картці прогресу** — точні getter-и `ProgressSnapshot` для значення `<N>/<M>` («Слова») не зафіксовано (склейка двох `Int` через `"/"`).
11. **Home, точні `dp`** для `Column(Modifier.padding(…))` у `LevelProgressCard`, для `Spacer(Modifier.height(…))` (рядки 257, 263, 264, 267) та для `LinearProgressIndicator(...height(…dp))`, а також `Spacer` у `else`-гілці (рядок 233) не зафіксовано.
12. **Home, аргумент `onStartSession`** — лямбда захоплює `profile` і `onStartSession`, тому аргумент походить із профілю; чи це саме `profile.dailyMinutes`, не підтверджено.
13. **Home, `levelPercent` і `Level.titleUk`** — семантика полів відома з викликів, але сама модель `Level` (порядок констант, `code`, `titleUk`, `mvpLevels`) у межах цих чотирьох файлів не описана; її треба взяти зі специфікації моделей.
14. **Спільні компоненти** (`ActionCard`, `MetricCard`, `InfoBanner`, `MasteryBar`, `SectionTitle`, `TopicCard`) описані лише за сигнатурами викликів; їхня внутрішня розмітка — предмет окремих розділів специфікації.
