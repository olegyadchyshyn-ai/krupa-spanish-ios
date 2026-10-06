# Специфікація навігації, теми та спільних компонентів (Krupa Spanish, Android → SwiftUI / iOS 17)

Джерела: `_recon/strings_by_class.txt` та дисасембльований smali (baksmali, дампи класів). Усі тексти наведено дослівно, у лапках. Позначки: **знайдено** = підтверджено інструкціями smali; **не знайдено** = у дампі відсутнє.

---

# 1. Навігаційні маршрути — `Routes.kt`

`object Routes` (клас `ua/krupa/spanish/ui/navigation/Routes`, `Routes.kt`). Поля — `public static final String` (усі значення взяті з `static fields ... value`).

| Константа | Значення | Тип | Примітка |
|---|---|---|---|
| `HOME` | `"home"` | String | стартовий маршрут |
| `LEARN` | `"learn"` | String | |
| `REVIEW` | `"review"` | String | |
| `WORDS` | `"words"` | String | |
| `LISTENING` | `"listening"` | String | |
| `LISTENING_DETAIL` | `"listening_detail"` | String | база для шаблону `listening_detail/{itemId}` |
| `SPEAKING` | `"speaking"` | String | |
| `AI_DIALOG` | `"ai_dialog"` | String | |
| `GRAMMAR` | `"grammar"` | String | |
| `PROGRESS` | `"progress"` | String | |
| `SETTINGS` | `"settings"` | String | |
| `WORD_DETAIL` | `"word_detail"` | String | база для `word_detail/{wordId}` |
| `TOPIC_DETAIL` | `"topic_detail"` | String | база для `topic_detail/{topicId}` |
| `SESSION` | `"session"` | String | база для `session?kind={kind}&topicId={topicId}&minutes={minutes}` |
| `SESSION_ARG_KIND` | `"kind"` | String | ім'я query-аргументу |
| `SESSION_ARG_TOPIC` | `"topicId"` | String | ім'я query-аргументу |
| `SESSION_ARG_MINUTES` | `"minutes"` | String | ім'я query-аргументу |
| `ONBOARDING` | `"onboarding"` | String | **константа існує**, але окремого `composable("onboarding")` у `AppNavHost` немає (онбординг показується умовою в `AppRoot`, див. §7) |
| `INSTANCE` | — | `Routes` | синтетичне поле singleton (не маршрут) |
| `$stable` | `0` | int | синтетичне поле Compose (не маршрут) |

## 1.1 Функції-хелпери (templating аргументів)

Усі — `public final`, приймають `String`, повертають `String`, з `checkNotNullParameter` (ім'я параметра з вбудованого рядка перевірки):

| Метод (smali) | Рядок у `Routes.kt` | Тіло (конкатенація `StringBuilder`) | Ім'я параметра |
|---|---|---|---|
| `wordDetail(String)` | 38 | `"word_detail/" + wordId` | `wordId` |
| `listeningDetail(String)` | 40 | `"listening_detail/" + itemId` | `itemId` |
| `topicDetail(String)` | 42 | `"topic_detail/" + topicId` | `topicId` |

Сесія окремого хелпера не має: рядок сесії будується конкатенацією на місці виклику в `AppNavHost`:

* `"session?minutes=" + minutes` (`AppRootKt$AppNavHost$1$1$2`, `AppRoot.kt:123-124`);
* `"session?topicId=" + topicId + "&minutes=" + minutes` (`AppRootKt$AppNavHost$1$13$2`, `AppRoot.kt`).

## 1.2 Таблиця маршрутів графа

| Маршрут | Шаблон | Аргументи (`navArgument`) | Екран |
|---|---|---|---|
| `home` | `"home"` | — | `HomeScreen` |
| `learn` | `"learn"` | — | `LearnScreen` |
| `review` | `"review"` | — | `ReviewScreen` |
| `words` | `"words"` | — | `WordsScreen` |
| `listening` | `"listening"` | — | `ListeningScreen` |
| `listening_detail/{itemId}` | `"listening_detail/{itemId}"` | `itemId` | `ListeningDetailScreen` (той самий файл `ListeningScreen.kt`) |
| `speaking` | `"speaking"` | — | `SpeakingScreen` |
| `ai_dialog` | `"ai_dialog"` | — | `AiDialogScreen` |
| `grammar` | `"grammar"` | — | `GrammarScreen` |
| `progress` | `"progress"` | — | `ProgressScreen` |
| `settings` | `"settings"` | — | `SettingsScreen` |
| `word_detail/{wordId}` | `"word_detail/{wordId}"` | `wordId` | `WordDetailScreen` |
| `topic_detail/{topicId}` | `"topic_detail/{topicId}"` | `topicId` | `TopicDetailScreen` |
| `session?kind={kind}&topicId={topicId}&minutes={minutes}` | `"session?kind={kind}&topicId={topicId}&minutes={minutes}"` | `kind` (defaultValue `"daily"`), `topicId`, `minutes` | `SessionScreen` |

Примітка: для `kind` у `AppNavHost$1$14` знайдено `const-string "daily"` → значення за замовчуванням `"daily"` (**знайдено**); типи `navArgument` (StringType/IntType/NullableType) у дампі не відображені явно — **не знайдено**.

---

# 2. Нижня навігація — `enum class BottomDestination`

`enum class BottomDestination(route: String, titleUk: String, icon: ImageVector)` — `Routes.kt:50-53` (конструктор), оголошення констант — рядки 55–59. Порядок `$values` = порядок оголошення (порядок вкладок).

| Enum-константа | `route` | `titleUk` (дослівно) | Іконка (material-icons) | ordinal | Рядок `Routes.kt` |
|---|---|---|---|---|---|
| `HOME` | `"home"` | `"Головна"` | `Icons.Filled.Home` (`filled/HomeKt.getHome`) | 0 | 55 |
| `LEARN` | `"learn"` | `"Навчання"` | `Icons.Filled.School` (`filled/SchoolKt.getSchool`) | 1 | 56 |
| `REVIEW` | `"review"` | `"Повторення"` | `Icons.Filled.Style` (`filled/StyleKt.getStyle`) | 2 | 57 |
| `LISTENING` | `"listening"` | `"Слухання"` | `Icons.Filled.GraphicEq` (`filled/GraphicEqKt.getGraphicEq`) | 3 | 58 |
| `PROGRESS` | `"progress"` | `"Прогрес"` | `Icons.Filled.Insights` (`filled/InsightsKt.getInsights`) | 4 | 59 |

**Як вибирається іконка:** окремої мапи `when`/`entries` НЕМАЄ. Іконка — це властивість самого enum-константа (instance field `icon:Landroidx/compose/ui/graphics/vector/ImageVector;`, геттер `getIcon()`; рядок `Routes.kt:53`), тому відповідність «константа → іконка» зашита в конструкторі (див. таблицю). Еквівалент для SwiftUI: `enum BottomTab { case home, learn, review, listening, progress }` з `var icon: String` (`house`, `graduationcap`, `square.stack.3d.up`, `waveform`, `chart.line.uptrend.xyaxis`).

**Порядок вкладок у нижньому барі:** ітерація по `BottomDestination.entries` (у smali — `AppRootKt$EntriesMappings.entries$0:Lkotlin/enums/EnumEntries;` + `BottomDestination.getRoute()`), тобто **Головна → Навчання → Повторення → Слухання → Прогрес** (`HOME, LEARN, REVIEW, LISTENING, PROGRESS`). Порядок визначається `AppRoot` (показ бару) і `KrupaBottomBar` (рендер), а не окремим списком.

Вибір активної вкладки: `showBottomBar = BottomDestination.entries.any { it.route == currentRoute }`, де `currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route ?: "home"` (`AppRoot.kt:75-79`, локальні змінні `showBottomBar`, `currentRoute`, `backStackEntry$delegate`).

---

# 3. Другорядна навігація — `enum class SecondaryDestination`

`enum class SecondaryDestination(route: String, titleUk: String, descriptionUk: String, icon: ImageVector)` — `Routes.kt:63-67`, константи — рядки 69–73 (порядок оголошення = `$values`).

| Enum-константа | `route` | Заголовок (`titleUk`) | Опис (`descriptionUk`) | Іконка | ordinal | Рядок |
|---|---|---|---|---|---|---|
| `WORDS` | `"words"` | `"Слова"` | `"Словник і стан запам'ятовування"` | `Icons.Filled.AutoStories` | 0 | 69 |
| `SPEAKING` | `"speaking"` | `"Говоріння"` | `"Вимова й оцінка мовлення"` | `Icons.Filled.Mic` | 1 | 70 |
| `AI_DIALOG` | `"ai_dialog"` | `"AI-діалог"` | `"Розмова з викладачем"` | `Icons.Filled.RecordVoiceOver` | 2 | 71 |
| `GRAMMAR` | `"grammar"` | `"Граматика"` | `"Пояснення українською"` | `Icons.Filled.School` | 3 | 72 |
| `SETTINGS` | `"settings"` | `"Налаштування"` | `"Профіль, аудіо, дані"` | `Icons.Filled.Tune` | 4 | 73 |

**Де показуються в UI:** у досліджених файлах (`AppRoot.kt`, `NavigationComponents.kt`) посилань на `SecondaryDestination` **не виявлено** — ні в `AppRoot`/`AppNavHost` (там використовується лише `BottomDestination`), ні в `KrupaBottomBar`/`ActionCard`/`ChoiceChipsRow`/`PrimaryActionButton`. За призначенням (заголовок + опис + іконка) це список карток другорядних розділів — імовірно рендериться через `ActionCard` на екрані «Профіль/Налаштування» або «Головна», але **точне місце використання в межах цього завдання не встановлено** (див. «Прогалини»).

---

# 4. `NavigationComponents.kt`

Клас `ua/krupa/spanish/ui/components/NavigationComponentsKt`. **Жодного тексту інтерфейсу у файлі немає** — усі підписи приходять параметрами (у блоці рядкових констант класу немає жодного кириличного рядка; є лише `currentRoute`, `icon`, `labelOf`, `onClick`, `onNavigate`, `onSelect`, `options`, `subtitleUk`, `title`, `titleUk` — це імена параметрів/локальних змінних). Тому для всіх функцій нижче: **«текст не знайдено» (усі тексти — параметри)**.

## 4.1 `KrupaBottomBar` (`NavigationComponents.kt:35`)

* **Сигнатура (smali):** `(Ljava/lang/String;Lkotlin/jvm/functions/Function1;Landroidx/compose/runtime/Composer;I)V` → `fun KrupaBottomBar(currentRoute: String, onNavigate: (BottomDestination) -> Unit)` (ім'я `currentRoute` підтверджено рядком-константою класу; `onNavigate` — з імені поля лямбди `$navController`/рядкових імен класу).
* **Структура UI (зверху вниз):**
  * `NavigationBar` (`material3/NavigationBarKt;.NavigationBar-HsRjFd4:(Modifier;JJFLWindowInsets;LFunction3;...)`) — аргументи `containerColor`/`contentColor`/`tonalElevation` у байткоді нульові → використано **типові кольори Material3** (`NavigationBarDefaults`); `Modifier` — дефолтний;
  * контент-лямбда `$KrupaBottomBar$1` (`NavigationComponents.kt:40`) — прохід по **всіх** `BottomDestination.entries`, для кожного:
    * `NavigationBarItem` (виклик на `NavigationComponents.kt:57-62`), де
      * `icon` = `Icon(destination.icon, modifier = Modifier.size(24.dp))` (лямбда `$KrupaBottomBar$1$1$2`, `NavigationComponents.kt:45`) — розмір іконки **24 dp** (знайдено: `const/16 …, #int 24` → `Dp.constructor-impl` → `SizeKt.size-3ABfNKs`);
      * `label` = `Text(destination.titleUk)` (лямбда `$KrupaBottomBar$1$1$3`, `NavigationComponents.kt:52`);
      * `selected` = порівняння `destination.route` з `currentRoute` (`Intrinsics.areEqual`);
      * `onClick` = лямбда `$KrupaBottomBar$1$1$1$1` → виклик `onNavigate(destination)`.
  * Один `remember` у контент-лямбді (`CC(remember)` у метаданих `$KrupaBottomBar$1`).
* **Тексти дослівно:** текст не знайдено (джерело підписів — `BottomDestination.titleUk`, див. §2).
* **Кольори/розміри з smali:** розмір іконки 24 dp (знайдено); `NavigationBar` без явних кольорів (значення 0 → типові) — знайдено; `tonalElevation` не задано — знайдено.
* **Використовується в:** `AppRoot` — `AppRootKt$AppRoot$5$1` (`AppRoot.kt:82`), як `bottomBar` у `Scaffold`.

Примітка для порту: рядок виділення вкладок у `AppRoot` — `navigate(destination.route) { popUpTo("home") … }` (лямбди `$AppRoot$5$1$1` → `NavOptionsBuilder`, `$AppRoot$5$1$1$1` → `PopUpToBuilder` з `const-string "home"`); точні прапорці (`saveState`/`restoreState`/`launchSingleTop`) у дампі не вичитані.

## 4.2 `ActionCard` (`NavigationComponents.kt:82`)

* **Сигнатура (smali):** `(Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/graphics/vector/ImageVector;ZLkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;Ljava/lang/String;…)V` → `fun ActionCard(titleUk: String, subtitleUk: String, icon: ImageVector, enabled: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier, trailingText: String)` — імена `titleUk`, `subtitleUk`, `icon`, `onClick` підтверджені рядковими константами класу; імена 4-го (`Boolean`) і 7-го (`String`) параметрів **не знайдено**.
* **Структура UI:**
  * `Card(onClick = onClick, modifier = Modifier.fillMaxWidth().padding(18.dp), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(…), border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant))` — `Card` **клікабельний** (перший параметр — `Function0`);
  * контент (`$ActionCard$1`, `NavigationComponents.kt:103`):
    * `Row` (вирівнювання по вертикалі — `rowMeasurePolicy`),
      * `Icon(icon, modifier = Modifier.size(30.dp))`;
      * `Spacer(Modifier.width(16.dp))`;
      * `Column`:
        * `Text(titleUk)` (рядок 111),
        * `Spacer(Modifier.height(2.dp))`,
        * `Text(subtitleUk)` (рядок 121/123);
      * `Spacer(Modifier.width(12.dp))`;
      * `Text(trailingText)` (рядок 128-132).
* **Тексти дослівно:** текст не знайдено (усі — параметри).
* **Кольори/розміри:** padding картки **18 dp**, форма **RoundedCornerShape(18.dp)**, іконка **30 dp**, проміжок іконка→текст **16 dp**, проміжок заголовок→підзаголовок **2 dp**, проміжок текст→трейлінг **12 dp**, товщина рамки **1 dp** (`BorderStroke`), колір рамки `colorScheme.outlineVariant` — усе **знайдено**; `cardColors` викликано з нульовими кольорами → типові `CardDefaults` (знайдено).
* **Використовується в:** у межах досліджених дампів викликів з екранів не виявлено (є лише `$default`-міст `$ActionCard$2`) — **не встановлено**.

## 4.3 `ChoiceChipsRow` (`NavigationComponents.kt:147`)

* **Сигнатура (smali):** `(Ljava/util/List;Ljava/lang/Object;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;Landroidx/compose/ui/Modifier;…)V` → `fun <T> ChoiceChipsRow(options: List<T>, selected: T, onSelect: (T) -> Unit, labelOf: (T) -> String, modifier: Modifier = Modifier)`; імена `options`, `labelOf`, `onSelect` підтверджені рядковими константами класу, ім'я `selected` — **не знайдено**.
* **Структура UI:**
  * `Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp))`;
  * для кожного `option` зі списку — одна «чипса»:
    * якщо `option == selected` → `Button(onClick = { onSelect(option) }, contentPadding = PaddingValues(…) ) { Text(labelOf(option)) }` (лямбди `$1$1$1` — onClick, `$1$1$2` — контент `Text`, `NavigationComponents.kt:160`);
    * інакше → `OutlinedButton(onClick = { onSelect(option) }, contentPadding = PaddingValues(…) ) { Text(labelOf(option)) }` (лямбди `$1$1$3` — onClick, `$1$1$4` — контент `Text`, `NavigationComponents.kt:168`).
  * У класі є один порожній рядковий літерал `""` (джерело — ймовірно `contentDescription` або значення за замовчуванням).
* **Тексти дослівно:** текст не знайдено (підпис — результат `labelOf(option)`).
* **Кольори/розміри:** `fillMaxWidth`, `Arrangement.spacedBy(8.dp)`, `PaddingValues` з **12 dp** (окремо для `Button` і `OutlinedButton`) — **знайдено**; кольори — типові `ButtonDefaults`/`OutlinedButton` (**не задані**).
* **Використовується в:** у межах досліджених дампів викликів з екранів не виявлено — **не встановлено**.

## 4.4 `PrimaryActionButton` (`NavigationComponents.kt:183`)

* **Сигнатура (smali):** `(Ljava/lang/String;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;ZLandroidx/compose/ui/graphics/vector/ImageVector;…)V` → `fun PrimaryActionButton(label: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true, icon: ImageVector? = null)` (ім'я `label` — з рядкових констант класу; інші імена **не знайдено**).
* **Структура UI:**
  * `Button(onClick = onClick, modifier = Modifier.fillMaxWidth(), enabled = enabled, contentPadding = PaddingValues(16.dp), colors = ButtonDefaults.buttonColors(…))`;
  * контент (`$PrimaryActionButton$1`, `NavigationComponents.kt:194`):
    * `Icon(icon, contentDescription = null, modifier = Modifier.size(22.dp))` — лише якщо `icon != null`;
    * `Spacer(Modifier.width(10.dp))`;
    * `Text(label)` (рядки 195–196).
* **Тексти дослівно:** текст не знайдено (усі — параметри).
* **Кольори/розміри:** `fillMaxWidth`, `contentPadding` **16 dp**, іконка **22 dp**, проміжок **10 dp** — **знайдено**; `buttonColors` викликано з нулями (типові кольори) — знайдено.
* **Використовується в:** `TopicDetailScreen` — кнопка «Почати заняття з теми (N хв)» з іконкою `Icons.Filled.PlayArrow` (`TopicDetailScreen.kt`; у smali `filled/PlayArrowKt.getPlayArrow` + `NavigationComponentsKt;.PrimaryActionButton` з тим самим рядком-конкатенацією `"Почати заняття з теми (" + minutes + " хв)"`).

---

# 5. `CommonComponents.kt`

Клас `ua/krupa/spanish/ui/components/CommonComponentsKt`. Єдиний знайдений текстовий літерал у файлі — **`"Спроб: "`** (плюс технічний `"%"`); усі решта підписів — параметри.

## 5.1 `SectionTitle` (`CommonComponents.kt:36`)

* **Сигнатура (smali):** `(Ljava/lang/String;Landroidx/compose/ui/Modifier;…)V` → `fun SectionTitle(title: String, modifier: Modifier = Modifier)`.
* **Структура UI:** один `Text(title, modifier = Modifier.padding(8.dp))` (`padding-qDBjuR0$default` з одним значущим аргументом **8 dp**).
* **Тексти дослівно:** текст не знайдено (параметр). Реальні виклики: `"Граматика теми"`, `"Слова теми (…)"` (див. нижче «Використовується в»).
* **Кольори/розміри:** padding 8 dp — знайдено; колір і стиль не задані (успадковуються з `MaterialTheme`).
* **Використовується в:** `TopicDetailScreen` (`ComposableSingletons$TopicDetailScreenKt$lambda-3$1` → `"Граматика теми"`; `lambda-5`-подібна лямбда → `"Слова теми (" + count + ")"`), тобто в списку `LazyColumn` екрана теми.

## 5.2 `SectionHeaderWithAction` (`CommonComponents.kt:51`)

* **Сигнатура (smali):** `(Ljava/lang/String;Ljava/lang/String;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;…)V` → `fun SectionHeaderWithAction(titleUk: String, actionTitle: String, onAction: () -> Unit, modifier: Modifier = Modifier)` — імена `titleUk`, `actionTitle`, `onAction` присутні в рядкових константах класу (точне закріплення за параметрами — **ймовірно**, не доведено).
* **Структура UI:**
  * `Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp))`,
    * `Text(titleUk)`;
    * розтяжка (weight) — `Spacer`/порожній елемент;
    * `TextActionButton(actionTitle, onAction)` (виклик `CommonComponentsKt;.TextActionButton` з `SectionHeaderWithAction$2`).
* **Тексти дослівно:** текст не знайдено.
* **Кольори/розміри:** `fillMaxWidth`, padding 8 dp — знайдено.
* **Використовується в:** у досліджених дампах прямих викликів з екранів не виявлено (компонент викликає `TextActionButton` всередині файлу) — **не встановлено**.

## 5.3 `MetricCard` (`CommonComponents.kt:73`)

* **Сигнатура (smali):** `(Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/Modifier;Ljava/lang/String;Landroidx/compose/ui/graphics/Color;Landroidx/compose/ui/graphics/vector/ImageVector;…)V` → `fun MetricCard(title: String, value: String, modifier: Modifier = Modifier, subtitle: String, accent: Color, icon: ImageVector)`; імена `title`, `value` підтверджені рядковими константами класу, імена `subtitle`/`accent` — **не знайдено**.
* **Структура UI (зверху вниз):**
  * `Card(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(…), elevation = CardDefaults.cardElevation(…), border = BorderStroke(1.dp, …))` (неклікабельний варіант `Card`, `NavigationComponents`-стиль);
  * контент (`$MetricCard$1`, `CommonComponents.kt:84`):
    * `Column(modifier = Modifier.padding(16.dp))`:
      * `Row`:
        * `Icon(icon, tint = accent, modifier = Modifier.size(20.dp))`,
        * `Spacer(Modifier.width(8.dp))`,
        * `Text(title)` (рядок 90);
      * `Spacer(Modifier.height(6.dp))`;
      * `Text(value)` (рядок 93/95);
      * `Spacer(Modifier.height(4.dp))`;
      * `Text(subtitle)` (рядок 101-105).
* **Тексти дослівно:** текст не знайдено.
* **Кольори/розміри:** форма `RoundedCornerShape(18.dp)`, рамка `BorderStroke(1.dp, …)`, padding 16 dp, іконка 20 dp, проміжки 8/6/4 dp — **знайдено**; `cardColors` — типові (значення 0); колір-акцент передається параметром і застосовується до `Icon` (`tint`) — знайдено.
* **Використовується в:** не встановлено (у досліджених дампах — лише `$default`-міст `$MetricCard$2`).

## 5.4 `MasteryBar` (`CommonComponents.kt:126`)

* **Сигнатура (smali):** `(Ljava/lang/String;ILandroidx/compose/ui/Modifier;Ljava/lang/Integer;…)V` → `fun MasteryBar(titleUk: String, percent: Int, modifier: Modifier = Modifier, attempts: Int? = null)`; ім'я `titleUk` — з рядкових констант класу; імена `percent`/`attempts` — **не знайдено** (типи: `I` та `Ljava/lang/Integer;` — 4-й параметр nullable).
* **Структура UI (зверху вниз):**
  * `Column(modifier = Modifier.fillMaxWidth().padding(6.dp))`:
    * `Row(modifier = Modifier.fillMaxWidth())`:
      * `Text(titleUk)` (рядок прогресу, ліва частина рядка),
      * `Text("<percent>%")` — у байткоді літерал `"%"`, приєднується до числа через `StringBuilder` (права частина);
    * `Spacer(Modifier.height(6.dp))`;
    * `LinearProgressIndicator(progress = { percent / 100f }, modifier = Modifier.fillMaxWidth().height(10.dp))` — провайдер прогресу — лямбда `$MasteryBar$1$2$1`;
    * `Spacer(Modifier.height(4.dp))`;
    * `Text("Спроб: " + attempts)` — літерал `"Спроб: "` (з пробілом після двокрапки), далі число.
* **Тексти дослівно:** `"Спроб: "`, `"%"` — **знайдено**; решта — параметри.
* **Кольори/розміри:** `fillMaxWidth`, padding 6 dp, висота треку прогресу **10 dp**, проміжки 6 dp і 4 dp — **знайдено**; кольори індикатора не задані (типові).
* **Використовується в:** не встановлено (є `$default`-міст `$MasteryBar$2`).

## 5.5 `LabeledValueRow` (`CommonComponents.kt:176`)

* **Сигнатура (smali):** `(Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/Modifier;…)V` → `fun LabeledValueRow(labelUk: String, value: String, modifier: Modifier = Modifier)` — **обидва імена підтверджені** рядками `checkNotNullParameter` (`"labelUk"`, `"value"`).
* **Структура UI:**
  * `Row(modifier = Modifier.fillMaxWidth().padding(6.dp))`:
    * `Text(labelUk)` (приглушений колір);
    * `Spacer(Modifier.weight(1f))` — у байткоді `const/high16 …, #int 1065353216 // #3f80` = `1.0f`;
    * `Text(value)` (акцентований, вирівняний праворуч).
* **Тексти дослівно:** текст не знайдено.
* **Кольори/розміри:** `fillMaxWidth`, padding 6 dp, `weight(1f)` — **знайдено**; точні `colorScheme`-слоти для тексту — не вичитані окремо (у дампі лише `Text--4IGK_g` з нульовими кольорами → успадкування локального кольору).
* **Використовується в:** не встановлено (є `$default`-міст `$LabeledValueRow$2`).

## 5.6 `EmptyState` (`CommonComponents.kt:200`)

* **Сигнатура (smali):** `(Ljava/lang/String;Ljava/lang/String;Landroidx/compose/ui/Modifier;…)V` → `fun EmptyState(titleUk: String, descriptionUk: String, modifier: Modifier = Modifier)` — **обидва імена підтверджені** рядками `checkNotNullParameter`.
* **Структура UI:**
  * `Column(modifier = Modifier.fillMaxWidth().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally)`:
    * `Text(titleUk)`;
    * `Spacer(Modifier.height(8.dp))`;
    * `Text(descriptionUk)` (вирівнювання по центру).
* **Тексти дослівно:** текст не знайдено.
* **Кольори/розміри:** `fillMaxWidth`, padding **24 dp**, проміжок **8 dp** — **знайдено**.
* **Використовується в:** не встановлено (є `$default`-міст `$EmptyState$2`).

## 5.7 `TextActionButton` (`CommonComponents.kt:228`)

* **Сигнатура (smali):** `(Ljava/lang/String;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;…)V` → `fun TextActionButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier)`.
* **Структура UI:** `TextButton(onClick = onClick, modifier = modifier) { Text(text) }` — контент-лямбда `$TextActionButton$1` (`$this$TextButton`, `CommonComponents.kt:230`).
* **Тексти дослівно:** текст не знайдено (параметр).
* **Кольори/розміри:** не задані (типові `TextButton`).
* **Використовується в:** всередині файлу — `SectionHeaderWithAction` (`CommonComponents.kt:52-60`).

## 5.8 `ActivityBar` (`CommonComponents.kt:268`)

* **Сигнатура (smali):** `(Ljava/lang/String;IILandroidx/compose/ui/Modifier;…)V` → `fun ActivityBar(titleUk: String, wordCount: Int, reviewCount: Int, modifier: Modifier = Modifier)`; імена числових параметрів **не знайдено** (типи: два `I`).
* **Структура UI (частково):**
  * `Column` з `Arrangement`/`Alignment` (`columnMeasurePolicy`) — зовнішній контейнер (дві вкладені `Column`-лямбди в метаданих `C(ActivityBar)P(!1,3)270@8753L894`);
  * елемент шириною **20 dp** і висотою **70 dp** (стовпчик/бар);
  * `Canvas` — лямбда `$ActivityBar$1$1$1` з параметром `$this$Canvas:Landroidx/compose/graphics/drawscope/DrawScope` → стовпчики малюються вручну на `Canvas`;
  * `Spacer(Modifier.height(6.dp))`;
  * `Text(...)` (рядок 274-292 у метаданих).
* **Тексти дослівно:** текст не знайдено (підпис — параметр `titleUk`).
* **Кольори/розміри:** ширина 20 dp, висота 70 dp, проміжок 6 dp, ще одне значення 4 dp — **знайдено**; точний порядок і кількість барів, а також формула їх висоти — **не встановлено**.
* **Використовується в:** не встановлено (є `$default`-міст `$ActivityBar$2`).

---

# 6. `LearningComponents.kt`

Клас `ua/krupa/spanish/ui/learn/LearningComponentsKt` (**знайдено** в дизасемблі: `classes17_ui.txt`, рядки 3313+; хелпери-лямбди `$TopicCard$1/$2`, `$TopicMasteryRow$1/$2`, `$WordRow$1/$2`, `ComposableSingletons$LearningComponentsKt$lambda-1$1`).

## 6.1 `TopicCard` (`LearningComponents.kt:46`)

* **Сигнатура (smali):** `(Lua/krupa/spanish/domain/model/Topic;IIZLkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;…)V` → `fun TopicCard(topic: Topic, wordCount: Int, learnedCount: Int, unlocked: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier)`; імена `topic`, `onClick` підтверджені рядками `checkNotNullParameter`; імена `wordCount`/`learnedCount`/`unlocked` — у порядку типів (два `I`, далі `Z`) — **ймовірно**.
* **Обчислення відсотка (знайдено в байткоді):** `percent = if (wordCount == 0) 0 else learnedCount * 100 / wordCount` (`mul-int/lit8 …, #int 100` → `div-int`; гілка `if-nez` на нуль).
* **Структура UI:**
  * `Card(onClick = onClick, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(surface, surfaceVariant), border = BorderStroke(1.dp, colorScheme.outlineVariant))` — клікабельний;
  * контент (`$TopicCard$1`, `LearningComponents.kt:59-120`), зверху вниз:
    * `Column` (кілька вкладених `Row`/`Column` за метаданими `C59@2370L2920`, `C61@2497L703`, `C64@2656L10`);
    * заголовок теми (`topic.titleUk` — див. §1 файлу моделей), рядок `"<learnedCount> з <wordCount> слів"` (літерали `" з "` і `"слів"`),
    * індикатор прогресу (`LinearProgressIndicator`-подібний елемент у лямбді `$TopicCard$1$1$2$1`, що повертає `Float` від `percent`),
    * підписи стану: `"Вивчено "`, `"Пройдено"`, `"Почати"`, `"Заблоковано"`, `"Відкриється на вищому рівні"`.
* **Тексти дослівно (усі — з блоку класу `LearningComponentsKt$TopicCard$1`):**
  * `" з "`
  * `"слів"`
  * `"Вивчено "`
  * `"Пройдено"`
  * `"Почати"`
  * `"Заблоковано"`
  * `"Відкриється на вищому рівні"`
* **Кольори/розміри:** форма `RoundedCornerShape(18.dp)`, рамка `BorderStroke(1.dp, outlineVariant)`, `fillMaxWidth` — **знайдено**; кольори картки — `surface` + `surfaceVariant` (знайдено).
* **Використовується в:** `LearnScreen` (передає `wordCount`/`learnedCount`/`unlocked`) — за призначенням і метаданими `TopicCard` (прямий виклик з екрана в межах інших дампів не перевірено).

## 6.2 `TopicMasteryRow` (`LearningComponents.kt:205`)

* **Сигнатура (smali):** `(Ljava/lang/String;IILandroidx/compose/ui/Modifier;…)V` → `fun TopicMasteryRow(titleUk: String, percent: Int, attempts: Int, modifier: Modifier = Modifier)`; ім'я `titleUk` підтверджено рядковою константою класу.
* **Структура UI:** `Card` (метадані `C210@8496L177` — уся лямбда `$TopicMasteryRow$1`), контент — `Text(titleUk)` + числові підписи (`C(TopicMasteryRow)P(3,2)206@8336L343`). Деталі внутрішньої розкладки (Row/Column, прогрес) — **не вичитані** (аналогічні до `MasteryBar`).
* **Тексти дослівно:** текст не знайдено (усі — параметри; числові значення формуються з `percent`/`attempts`).
* **Кольори/розміри:** не встановлено.
* **Використовується в:** `ProgressScreen` (рядок «тема — відсоток — спроби») — **не підтверджено** викликом.

## 6.3 `WordRow` (`LearningComponents.kt:134`)

* **Сигнатура (smali):** `(Lua/krupa/spanish/domain/model/Word;Lua/krupa/spanish/learning/srs/CardState;Lkotlin/jvm/functions/Function0;Lkotlin/jvm/functions/Function0;Landroidx/compose/ui/Modifier;…)V` → `fun WordRow(word: Word, card: CardState, onSpeak: () -> Unit, onClick: () -> Unit, modifier: Modifier = Modifier)`; імена `word`, `onSpeak`, `onClick` підтверджені рядковими константами класу.
* **Структура UI:**
  * `Card(...)` (метадані `C157@6453L1686`) — клікабельний рядок;
  * контент (`$WordRow$1`, `LearningComponents.kt:157-187`):
    * `Column`:
      * `Row`: іспанське слово + `Text(" · ")` + переклад (літерал `" · "` з пробілами);
      * підпис статусу (`statusLabel`, колір `statusColor`) — параметри лямбди `$WordRow$1`: `(onSpeak, word, statusLabel: String, statusColor: J, card: CardState, strength: I)`;
    * кнопка/іконка озвучення: `OutlinedButton` з `Icons.Filled.VolumeUp` і `Text("Прослухати")` — спільна лямбда `ComposableSingletons$LearningComponentsKt$lambda-1$1` (`LearningComponents.kt:188-191`, `$this$OutlinedButton`);
    * індикатор сили запам'ятовування: лямбда `$WordRow$1$1$1$1$1` з полем `$strength:I`, повертає `Float` → `progress = { strength / 100f }`.
* **Тексти дослівно:**
  * `" · "` (з `$WordRow$1`);
  * `"Прослухати"` (з `ComposableSingletons$LearningComponentsKt$lambda-1$1`); там же — `Icons.Filled.VolumeUp`;
  * підписи станів картки (з головного класу `LearningComponentsKt`): `"важке"`, `"засвоєно"`, `"нове"`, `"у навчанні"`, `"ще не вчилося"` — це повний набір літералів; **точне зіставлення кожного підпису з `CardPhase` (NEW/LEARNING/REVIEW) не встановлено** (5 підписів на 3 фази → імовірно, частина залежить від додаткових полів `CardState`, напр. `repetitions == 0` або `suspended`).
  * Текст слова/перекладу — з моделі `Word` (не літерали).
* **Кольори/розміри:** `statusColor` передається параметром (тип `J` = `Color`) — знайдено; точні значення dp/співвідношення не вичитані.
* **Використовується в:** `WordsScreen`, `TopicDetailScreen` («Слова теми»), `ReviewScreen` (за призначенням; прямий виклик підтверджено лише для `TopicDetailScreen` — там є лямбда створення `WordRow`).

---

# 7. `AppRoot.kt` — структура застосунку

Клас `ua/krupa/spanish/ui/AppRootKt` (`AppRoot.kt`). Метадані методів: `AppRoot (AppRoot.kt:53)`, `AppNavHost (AppRoot.kt:111)`, `LoadingScreen (AppRoot.kt:247)`, `ContentMissingScreen (AppRoot.kt:264)`.

## 7.1 `AppRoot` Composable (структура зверху вниз)

Сигнатура (smali): `(Lua/krupa/spanish/core/AppContainer;Lua/krupa/spanish/ui/MainUiState;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function1;…)V` → `fun AppRoot(container: AppContainer, state: MainUiState, onProfileSaved: (UserProfile) -> Unit, onShowOnboarding: (Boolean) -> Unit)` (імена підтверджені `checkNotNullParameter`: `"container"`, `"state"`, `"onProfileSaved"`, `"onShowOnboarding"`).

Порядок гілок (нумерація рядків `AppRoot.kt` — з `positions` байткоду):

1. **рядок 55:** `if (state.loading) { LoadingScreen(); return }` — `LoadingScreen(composer, 0)`, далі `return`.
2. **рядок 60-63:** `if (state.needsOnboarding) { val onDone = remember { … }; OnboardingScreen(container, onDone); return }` — виклик `ui/screens/onboarding/OnboardingScreenKt.OnboardingScreen(AppContainer, Function1)`, лямбда-обгортка `$AppRoot$2$1` (параметри `onProfileSaved`, `onShowOnboarding`).
3. **рядок 71-73:** `if (!state.contentReady) { ContentMissingScreen(); return }`.
4. **рядок 76:** `val navController = rememberNavController()` (`NavHostControllerKt.rememberNavController`).
5. **рядок 77-79:** `val backStackEntry by navController.currentBackStackEntryAsState()`; `val currentRoute = backStackEntry?.destination?.route ?: "home"`; `val showBottomBar = BottomDestination.entries.any { it.route == currentRoute }`.
6. **рядок 81-82:** лямбда `bottomBar` (`$AppRoot$5(showBottomBar, currentRoute, navController)`).
7. **рядок 96:** лямбда `content` (`$AppRoot$6(container, navController, onShowOnboarding)`), тип `Function3` (отримує `PaddingValues`).
8. **рядок 104:** `Scaffold(...)`.

**Scaffold — фактичні аргументи (smali `material3/ScaffoldKt;.Scaffold-TvnljyQ`):**
`Scaffold(modifier = null, topBar = null, bottomBar = { … }, snackbarHost = null, floatingActionButton = null, containerColor = не задано, contentColor = не задано, contentWindowInsets = типові) { padding -> AppNavHost(container, navController, padding, onShowOnboarding) }`.

| Слот Scaffold | Значення | Доказ |
|---|---|---|
| `modifier` | відсутній (`null`/0) | байткод, регістр `Modifier` = 0 |
| `topBar` | **відсутній** (`null`) | байткод |
| `bottomBar` | `{ if (showBottomBar) KrupaBottomBar(currentRoute, onNavigate = { navController.navigate(it.route) { popUpTo("home") … } }) }` | `$AppRoot$5$1`, `AppRoot.kt:82`; `$AppRoot$5$1$1`, `$AppRoot$5$1$1$1` |
| `snackbarHost` | **відсутній** (`null`) | байткод |
| `floatingActionButton` | **відсутній** (`null`) | байткод |
| `containerColor` / `contentColor` | не задані (типові `colorScheme.background`/`onBackground`) | байткод (0) |
| `content` | `{ padding -> AppNavHost(container, navController, padding, onShowOnboarding) }` | `$AppRoot$6`, рядок `padding` = 96 |

**Отже: застосунок не має top bar, FAB і snackbar на рівні `AppRoot`.** Заголовки екранів і кнопки «назад» задаються **всередині самих екранів** (напр., у `TopicDetailScreen` є власна кнопка «Назад» з `Icons.Filled.ArrowBack`: `$this$OutlinedButton`/`$this$TextButton` → `Icon(ArrowBack, Modifier.size(20.dp))` + `Spacer(8.dp)` + `Text("Назад")`). У межах `AppRoot.kt` **текстів заголовків немає** — «текст не знайдено».

## 7.2 `AppNavHost` (сигнатура + перелік `composable(...)` у порядку коду)

Сигнатура (smali): `(Lua/krupa/spanish/core/AppContainer;Landroidx/navigation/NavHostController;Landroidx/compose/foundation/layout/PaddingValues;Lkotlin/jvm/functions/Function0;…)V` → `fun AppNavHost(container: AppContainer, navController: NavHostController, padding: PaddingValues, onShowOnboarding: () -> Unit)`.

Виклик графа: `NavHost(navController, startDestination = "home", modifier = Modifier.padding(padding), …, builder = $AppNavHost$1(container, navController, onShowOnboarding))` — `startDestination` = **`"home"`** (знайдено: `const-string "home"`), `enter/exit` transition-лямбди — `null` (не задані).

| # | Рядок `AppRoot.kt` | `route` | `navArgument` | Екран (Composable) |
|---|---|---|---|---|
| 1 | 118 | `"home"` | — | `HomeScreen` |
| 2 | 128 | `"learn"` | — | `LearnScreen` |
| 3 | 135 | `"review"` | — | `ReviewScreen` |
| 4 | 142 | `"words"` | — | `WordsScreen` |
| 5 | 149 | `"listening"` | — | `ListeningScreen` |
| 6 | 156 | `"listening_detail/{itemId}"` | `itemId` | `ListeningDetailScreen` |
| 7 | 164 | `"speaking"` | — | `SpeakingScreen` |
| 8 | 171 | `"ai_dialog"` | — | `AiDialogScreen` |
| 9 | 178 | `"grammar"` | — | `GrammarScreen` |
| 10 | 185 | `"progress"` | — | `ProgressScreen` |
| 11 | 189 | `"settings"` | — | `SettingsScreen` |
| 12 | 197 | `"word_detail/{wordId}"` | `wordId` (читається через `entry.arguments`) | `WordDetailScreen` |
| 13 | 205 | `"topic_detail/{topicId}"` | `topicId` | `TopicDetailScreen` |
| 14 | 236 | `"session?kind={kind}&topicId={topicId}&minutes={minutes}"` | `kind` (default `"daily"`), `topicId`, `minutes` | `SessionScreen` |

Кожен `composable(...)` має власну анімовану лямбду (`$1$N`, `$13$N`, `$17$N` — з `AnimatedContentScope`), тобто переходи виконуються через `NavHost` з `AnimatedContentScope` (типові анімації Navigation-Compose).

## 7.3 `LoadingScreen` (`AppRoot.kt:247`) і `ContentMissingScreen` (`AppRoot.kt:264`)

**`LoadingScreen`** — `(Composer, I)V`, без параметрів:

* `Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center)`;
* `Column(horizontalAlignment = CenterHorizontally)`:
  * `CircularProgressIndicator()` (`material3/ProgressIndicatorKt;.CircularProgressIndicator-LxG7B9w`, без явних кольорів/розмірів);
  * `Spacer` (проміжок **16 dp**);
  * `Text("Готуємо курс…")` — знак `…` (U+2026) у тексті, як у джерелі.
* Умова показу: `state.loading == true` (перша гілка `AppRoot`).
* Тексти дослівно: **`"Готуємо курс…"`**.

**`ContentMissingScreen`** — `(Composer, I)V`, без параметрів:

* `Box(modifier = Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center)`;
* `Column(horizontalAlignment = CenterHorizontally)`:
  * `Text("Контент курсу не знайдено")`;
  * `Spacer` (проміжок **12 dp**);
  * `Text("Перевстановіть застосунок або перевірте цілісність файлів контенту.")`.
* Умова показу: `state.contentReady == false` (третя гілка `AppRoot`).
* Тексти дослівно: **`"Контент курсу не знайдено"`**, **`"Перевстановіть застосунок або перевірте цілісність файлів контенту."`**.

## 7.4 Умова «онбординг vs основний граф»

```
loading            → LoadingScreen (і вихід)
needsOnboarding    → OnboardingScreen(container, onDone) (і вихід)
!contentReady      → ContentMissingScreen (і вихід)
інакше             → Scaffold { bottomBar = KrupaBottomBar (лише на 5 головних маршрутах), content = AppNavHost }
```
Поле стану — `MainUiState.needsOnboarding` (геттер `getNeedsOnboarding()Z`), джерело — `MainViewModel` (§9).

## 7.5 Переходи між екранами (`Звідки | Дія | Куди`)

| Звідки | Дія (лямбда в smali) | Куди (маршрут) |
|---|---|---|
| `HomeScreen` (118) | `$1$1$1`: `{ route: String -> navController.navigate(route) }` | довільний маршрут, переданий рядком (напр. `Routes.WORDS`, `Routes.SPEAKING`, `Routes.AI_DIALOG`, `Routes.GRAMMAR`, `Routes.SETTINGS`) |
| `HomeScreen` (118) | `$1$1$2`: `{ minutes: Int -> navController.navigate("session?minutes=$minutes") }` | `session?minutes={minutes}` |
| `LearnScreen` (128) | `$2$1`: `{ topicId -> navController.navigate(Routes.topicDetail(topicId)) }` | `topic_detail/{topicId}` |
| `WordsScreen` (142) | `$4$1`: `{ wordId -> navController.navigate(Routes.wordDetail(wordId)) }` | `word_detail/{wordId}` |
| `ListeningScreen` (149) | `$5$1`: `{ itemId -> navController.navigate(Routes.listeningDetail(itemId)) }` | `listening_detail/{itemId}` |
| `TopicDetailScreen` (205) | `$13$2`: `{ topicId, minutes -> navController.navigate("session?topicId=$topicId&minutes=$minutes") }` | `session?topicId={topicId}&minutes={minutes}` |
| `SettingsScreen` (189) | `$11$1`: `navController.popBackStack()` | назад |
| `WordDetailScreen` (197) | `$12$1`: `navController.popBackStack()` | назад |
| `TopicDetailScreen` (205) | `$13$1`: `navController.popBackStack()` | назад |
| `SessionScreen` (236) | `$17$1`: `navController.popBackStack()` | назад |
| Будь-який екран з нижнім баром | `$AppRoot$5$1$1`: `{ destination -> navController.navigate(destination.route) { popUpTo("home") … } }` | `home`/`learn`/`review`/`listening`/`progress` |
| `AppRoot` | `onShowOnboarding(Boolean)` → `MainViewModel.showOnboarding(Z)` | прапорець онбордингу |
| Онбординг | `onProfileSaved(UserProfile)` → `MainViewModel.saveProfile(UserProfile)` | збереження профілю |

Для екранів `ReviewScreen` (135), `ListeningDetailScreen` (156), `SpeakingScreen` (164), `AiDialogScreen` (171), `GrammarScreen` (178), `ProgressScreen` (185) у дампі видно лямбди «назад» (`$3$1`, `$6$1`, `$7$1`, `$8$1`, `$9$1`, `$10`), але конкретний виклик (`popBackStack()` / `navigate(...)`) у цих класах **не вичитано** — див. «Прогалини».

---

# 8. Тема — `Theme.kt`, `Color.kt`, `Type.kt`

## 8.1 `Color.kt` (`Lua/krupa/spanish/ui/theme/ColorKt`, рядки 14–41 вихідного файлу)

Усі 22 поля — `private/public static final long` (`J`), обчислюються у `<clinit>` як `Color(<long>)`. **Усі значення знайдено** (інструкції `const-wide v0, … #00000000AARRGGBB` → `androidx/compose/ui/graphics/ColorKt;.Color:(J)J` → `sput-wide … ColorKt;-><FIELD>:J`):

| Поле | ARGB hex | Приблизний опис | Рядок `Color.kt` | Джерело |
|---|---|---|---|---|
| `SpainRed` | `0xFFC1272D` | основний червоний (прапор Іспанії) — `primary` | 14 | знайдено |
| `SpainRedDark` | `0xFF8E1B20` | темний червоний — `onPrimaryContainer` (light) / `primaryContainer` (dark) | 15 | знайдено |
| `SpainGold` | `0xFFF1BF00` | золотий — `secondary` (dark) | 16 | знайдено |
| `SpainGoldDark` | `0xFFA87E00` | темне золото — `secondary` (light) | 17 | знайдено |
| `Bone` | `0xFFFAF6EC` | теплий фон «кістка» — `background` | 20 | знайдено |
| `BoneSurface` | `0xFFFFFDF7` | поверхня карток — `surface` | 21 | знайдено |
| `Ink` | `0xFF221A16` | основний текст — `onBackground`/`onSurface` | 22 | знайдено |
| `InkMuted` | `0xFF5C4F45` | приглушений текст — `onSurfaceVariant` | 23 | знайдено |
| `Line` | `0xFFE4DACB` | лінії/роздільники — `outline` | 24 | знайдено |
| `Night` | `0xFF17110F` | темний фон — `background` (dark) | 27 | знайдено |
| `NightSurface` | `0xFF211917` | темна поверхня — `surface` (dark) | 28 | знайдено |
| `NightElevated` | `0xFF2C2220` | підвищена поверхня — `surfaceVariant` (dark) | 29 | знайдено |
| `NightLine` | `0xFF3D302C` | лінії в темній темі — `outline` (dark) | 30 | знайдено |
| `BoneText` | `0xFFF3EBDF` | світлий текст для темної теми — `onBackground`/`onSurface` (dark) | 31 | знайдено |
| `Success` | `0xFF2E7D4F` | успіх | 34 | знайдено |
| `SuccessLight` | `0xFFB7E4C7` | світлий успіх (контейнер) | 35 | знайдено |
| `Warning` | `0xFFB36B00` | попередження | 36 | знайдено |
| `WarningLight` | `0xFFFFE0A3` | світле попередження | 37 | знайдено |
| `Error` | `0xFFB3261E` | помилка — `error` | 38 | знайдено |
| `ErrorLight` | `0xFFF9DEDC` | контейнер помилки — `errorContainer` | 39 | знайдено |
| `Info` | `0xFF2A5C8A` | інформація — `tertiary` (light) | 40 | знайдено |
| `InfoLight` | `0xFFCFE3F5` | світла інформація — `tertiaryContainer` | 41 | знайдено |

Полів без знайдених значень **немає**.

## 8.2 `Theme.kt` (`Lua/krupa/spanish/ui/theme/ThemeKt`)

* **Composable-функції у файлі:** `KrupaSpanishTheme` (`Theme.kt:68`) — єдина; плюс приватні `val LightColors` (рядки 11–35) і `val DarkColors` (рядок 38+).
* **Сигнатура (smali):** `(Lua/krupa/spanish/domain/model/ThemeMode;Lkotlin/jvm/functions/Function2;Landroidx/compose/runtime/Composer;II)V` → `fun KrupaSpanishTheme(themeMode: ThemeMode, content: @Composable () -> Unit)`.
* **Dark mode:** підтримується через `ThemeMode` (enum з `domain/model/UserProfile.kt`: `SYSTEM`, `LIGHT`, `DARK`) + `androidx/compose/foundation/DarkThemeKt;.isSystemInDarkTheme()`:
  * `themeMode == SYSTEM` → `isSystemInDarkTheme()`;
  * `themeMode == LIGHT` → `false`;
  * `themeMode == DARK` → `true`;
  * далі `val colorScheme = if (dark) ThemeKt.DarkColors else ThemeKt.LightColors`.
* **Динамічні кольори:** **відсутні** — у дампі немає жодного виклику `dynamicLightColorScheme`/`dynamicDarkColorScheme` (знайдено: їх немає).
* **Схеми:** `lightColorScheme(...)` (`Theme.kt:11`) і `darkColorScheme(...)` (`Theme.kt:38`) зі статичними кольорами; обидві — `$default`-виклики, маски дефолтів `mask0 = 0xF0380010`, `mask1 = 0x0000000F`.
* **Типографіка і форми:** `MaterialTheme(colorScheme = …, shapes = <не задано → типові Shapes Material3>, typography = TypeKt.AppTypography, content = content)` — `Shapes` **не перевизначено** (нуль у регістрі), додаткових `CompositionLocalProvider`/`SideEffect` (статус-бар тощо) у файлі **немає**.

**Слоти `LightColors`** (24 явні аргументи; решта — дефолти Material3):

| Слот | Значення | Слот | Значення |
|---|---|---|---|
| `primary` | `ColorKt.SpainRed` `0xFFC1272D` | `onBackground` | `ColorKt.Ink` `0xFF221A16` |
| `onPrimary` | `Color.White` | `surface` | `ColorKt.BoneSurface` `0xFFFFFDF7` |
| `primaryContainer` | `Color(0xFFFFDAD8)` | `onSurface` | `ColorKt.Ink` `0xFF221A16` |
| `onPrimaryContainer` | `ColorKt.SpainRedDark` `0xFF8E1B20` | `surfaceVariant` | `Color(0xFFF0E8DA)` |
| `secondary` | `ColorKt.SpainGoldDark` `0xFFA87E00` | `onSurfaceVariant` | `ColorKt.InkMuted` `0xFF5C4F45` |
| `onSecondary` | `Color.White` | `error` | `ColorKt.Error` `0xFFB3261E` |
| `secondaryContainer` | `Color(0xFFFFEFC2)` | `onError` | `Color.White` |
| `onSecondaryContainer` | `Color(0xFF3B2E00)` | `errorContainer` | `ColorKt.ErrorLight` `0xFFF9DEDC` |
| `tertiary` | `ColorKt.Info` `0xFF2A5C8A` | `onErrorContainer` | `Color(0xFF410E0B)` |
| `onTertiary` | `Color.White` | `outline` | `ColorKt.Line` `0xFFE4DACB` |
| `tertiaryContainer` | `ColorKt.InfoLight` `0xFFCFE3F5` | `outlineVariant` | `Color(0xFFEFE6D8)` |
| `onTertiaryContainer` | `Color(0xFF0B2B45)` | решта (inverse*, scrim, surfaceTint, surfaceContainer*, surfaceDim) | дефолти Material3 |
| `background` | `ColorKt.Bone` `0xFFFAF6EC` | | |

**Слоти `DarkColors`** (24 явні аргументи):

| Слот | Значення | Слот | Значення |
|---|---|---|---|
| `primary` | `Color(0xFFFF8A8A)` | `background` | `ColorKt.Night` `0xFF17110F` |
| `onPrimary` | `Color(0xFF5F1216)` | `onBackground` | `ColorKt.BoneText` `0xFFF3EBDF` |
| `primaryContainer` | `Color(0xFF8E1B20)` | `surface` | `ColorKt.NightSurface` `0xFF211917` |
| `onPrimaryContainer` | `Color(0xFFFFDAD8)` | `onSurface` | `ColorKt.BoneText` `0xFFF3EBDF` |
| `secondary` | `ColorKt.SpainGold` `0xFFF1BF00` | `surfaceVariant` | `ColorKt.NightElevated` `0xFF2C2220` |
| `onSecondary` | `Color(0xFF3B2E00)` | `onSurfaceVariant` | `Color(0xFFD8C9BC)` |
| `secondaryContainer` | `Color(0xFF5A4600)` | `error` | `Color(0xFFFFB4AB)` |
| `onSecondaryContainer` | `Color(0xFFFFEFC2)` | `onError` | `Color(0xFF690005)` |
| `tertiary` | `Color(0xFF9CCBFB)` | `errorContainer` | `Color(0xFF93000A)` |
| `onTertiary` | `Color(0xFF00344F)` | `onErrorContainer` | `Color(0xFFFFDAD6)` |
| `tertiaryContainer` | `Color(0xFF1B4A70)` | `outline` | `ColorKt.NightLine` `0xFF3D302C` |
| `onTertiaryContainer` | `ColorKt.InfoLight` `0xFFCFE3F5` | `outlineVariant` | `Color(0xFF322724)` |
| | | решта | дефолти Material3 |

* **Форми/заокруглення та відступи:** у `Theme.kt` **власних `Shapes` і відступів немає** (Material3 `Shapes()` за замовчуванням). Заокруглення задаються локально в компонентах: `RoundedCornerShape(18.dp)` (картки `ActionCard`, `TopicCard`, `MetricCard`).

## 8.3 `Type.kt` (`Lua/krupa/spanish/ui/theme/TypeKt`)

Визначено: `AppTypography: Typography` (рядки метаданих — `TypeKt.<clinit>`), `SpanishWordStyle: TextStyle`, `PromptStyle: TextStyle`. Усі стилі — з `fontFamily = FontFamily.Default` (системний шрифт), `letterSpacing` **не задано**, інші поля — дефолтні.

`AppTypography` (15 слотів `Typography`; 12 задані, 3 — дефолти Material3 `displayLarge`, `displayMedium`, `headlineLarge`; маска дефолтів `0b1011`):

| Слот `Typography` | fontSize | fontWeight | lineHeight |
|---|---|---|---|
| `displaySmall` | 34 sp | `FontWeight.Bold` | 40 sp |
| `headlineMedium` | 28 sp | `FontWeight.Bold` | 28 sp |
| `headlineSmall` | 24 sp | `FontWeight.SemiBold` | 30 sp |
| `titleLarge` | 22 sp | `FontWeight.SemiBold` | 22 sp |
| `titleMedium` | 19 sp | `FontWeight.SemiBold` | 25 sp |
| `titleSmall` | 17 sp | `FontWeight.Medium` | 23 sp |
| `bodyLarge` | 18 sp | `FontWeight.Normal` | 26 sp |
| `bodyMedium` | 16 sp | `FontWeight.Normal` | 16 sp |
| `bodySmall` | 14 sp | `FontWeight.Normal` | 20 sp |
| `labelLarge` | 20 sp | `FontWeight.SemiBold` | 21 sp |
| `labelMedium` | 21 sp | `FontWeight.Medium` | 21 sp |
| `labelSmall` | 12 sp | `FontWeight.Medium` | 12 sp |
| `displayLarge`, `displayMedium`, `headlineLarge` | — | — | не задані (дефолти Material3) |

Додаткові стилі:

| Поле | fontSize | fontWeight | lineHeight | Примітка |
|---|---|---|---|---|
| `SpanishWordStyle` | 32 sp | `FontWeight.Bold` | 32 sp | іспанське слово у великому поданні |
| `PromptStyle` | не задано (`TextUnit.Unspecified`, у байткоді `getSp(0)`) | `FontWeight.Medium` | не задано | підказка; розмір успадковується від батьківського стилю |

Отже типографіка **кастомна** (не дефолтна Material3).

---

# 9. `MainActivity.kt` / `MainViewModel.kt`

## 9.1 `MainActivity.kt`

**Дизасембльованого тіла `MainActivity` у наданих дампах немає** (дампи містили лише пакет `ua/krupa/spanish/ui/`; клас `ua/krupa/spanish/MainActivity` у них відсутній). Нижче — усе, що відновлюється з `_recon/strings_by_class.txt` (рядки 3914–3930), тобто **частково**:

| Факт | Доказ |
|---|---|
| `onCreate` встановлює Compose-контент через вкладені лямбди: `MainActivity$onCreate$1` (`MainActivity.kt:23`), вкладений композабл `MainActivity$onCreate$1$1` (`MainActivity.kt:27`) | метадані `C23@812L52,24@908L29,26@951L314:MainActivity.kt`, `C27@1018L233` |
| Використовується `viewModel(...)` з фабрикою (`MainViewModelFactory`) | `CC(viewModel)P(3,2,1)` + рядок помилки `"No ViewModelStoreOwner was provided via LocalViewModelStoreOwner"` |
| Контейнер застосунку береться з `Application`: `(application as SpanishApp).container` | рядок `"null cannot be cast to non-null type ua.krupa.spanish.SpanishApp"` |
| Колбек `onProfileSaved` → `viewModel.saveProfile(profile)` | `MainActivity$onCreate$1$1$1`: поля `p0`, `saveProfile`; тип `saveProfile(Lua/krupa/spanish/domain/model/UserProfile;)V` |
| Колбек `onShowOnboarding` → `viewModel.showOnboarding(flag)` | `MainActivity$onCreate$1$1$2`: `showOnboarding(Z)V` |
| Тема/перший екран: перший показаний екран визначає `AppRoot` (`loading` → `LoadingScreen`, `needsOnboarding` → `OnboardingScreen`, далі граф зі `startDestination = "home"`); тема — `KrupaSpanishTheme(themeMode = profile.themeMode)` (з `ThemeKt`) | §7, §8.2 |
| Edge-to-edge (`enableEdgeToEdge`) та орієнтація | **не встановлено** (тіло `MainActivity` відсутнє). У `AndroidManifest.xml` (`_apk_extract/AndroidManifest.xml`, бінарний AXML) **немає атрибута `screenOrientation`** — орієнтація не фіксується; присутні атрибути `configChanges`, `windowSoftInputMode`, `allowBackup`, `dataExtractionRules`, `fullBackupContent`, `supportsRtl`, `largeHeap`; `versionName = "1.0.0-mvp"`; label застосунку — `"KRUPA_Spanish"`; дозволи: `INTERNET`, `RECORD_AUDIO`, `ACCESS_NETWORK_STATE`, `DUMP`; компоненти: `TTS_SERVICE`, `RecognitionService`, `PreviewActivity` |

## 9.2 `MainViewModel.kt`

Клас `ua/krupa/spanish/ui/MainViewModel` + `MainUiState` + `MainViewModelFactory` (усі — `MainViewModel.kt`). Клас знайдено в дизасемблі (`classes12_ui.txt`, рядки 9015+).

* **Поля:** `container: AppContainer` (private), `_state: MutableStateFlow` (private), `state: StateFlow` (public).
* **Конструктор:** `MainViewModel(container: AppContainer)` (ім'я `container` — з `checkNotNullParameter`); у `<init>` створюється `MutableStateFlow(MainUiState(...))` і `asStateFlow()`.
* **`bootstrap()`:** `bootstrap:()V` — запускає корутину (`BuildersKt.launch`) з тілом `MainViewModel$bootstrap$1`; усередині — `collect`/`emit` по потоці профілю (`MainViewModel$bootstrap$1$2.emit(UserProfile, Continuation)`) → оновлює `_state`. Точний перелік кроків (читання профілю, перевірка наявності контенту, підрахунок слів) у витягу не деталізовано — **частково**.
* **`saveProfile(profile: UserProfile)`:** `saveProfile:(Lua/krupa/spanish/domain/model/UserProfile;)V` — `launch` + `MainViewModel$saveProfile$1` (ім'я `profile` — з рядкової константи), зберігає профіль через `container`.
* **`showOnboarding(show: Boolean)`:** `showOnboarding:(Z)V` — копіює стан із `forceOnboarding = show` (поле `forceOnboarding` у `MainUiState.toString`).
* **`getState(): StateFlow`** — публічний геттер стану.
* **`MainUiState`** — `data class` з полями (порядок з `toString`/`MainUiState(loading=`): `loading: Boolean`, `profileExists: Boolean`, `profile: UserProfile?`, `learningStarted: Boolean`, `forceOnboarding: Boolean`, `contentReady: Boolean`, `wordCount: Int`, плюс похідне `needsOnboarding` (геттер `getNeedsOnboarding()Z`, використовується в `AppRoot`); у `toString` також `MainUiState(loading=…, profileExists=…, profile=…, learningStarted=…, forceOnboarding=…, contentReady=…, wordCount=…)`.
* **`MainViewModelFactory(container: AppContainer)`:** реалізує `ViewModelProvider.Factory`; `create(Class)` повертає `MainViewModel(container)` (ім'я параметра/поля — `container`).
* **Перший екран:** `MainActivity` → `AppRoot(container, state, …)`; при `loading = true` (початковий стан) показується **`LoadingScreen`** («Готуємо курс…»), тобто це перший видимий екран до завершення `bootstrap()`.

---

## Прогалини

1. **Тіло `MainActivity.kt` відсутнє в дизасемблі** (дампи містили лише пакет `ua/krupa/spanish/ui/`): не встановлено `enableEdgeToEdge`, `setContent`-обгортку, `requestedOrientation`, точний виклик `viewModel(factory = …)`, порядок виклику `bootstrap()`. Частково компенсовано рядковими константами та `AndroidManifest.xml` (орієнтація не фіксується).
2. **`AppNavHost`: «назад»-лямбди екранів** `ReviewScreen` (135), `ListeningDetailScreen` (156), `SpeakingScreen` (164), `AiDialogScreen` (171), `GrammarScreen` (178), `ProgressScreen` (185) — наявність лямбд видно, конкретний виклик (`popBackStack()` vs `navigate(...)`) не вичитано.
3. **`SecondaryDestination`: місце використання в UI не встановлено** (у дампах `AppRoot.kt`/`NavigationComponents.kt` посилань немає; імовірно — список карток на екрані «Профіль/Налаштування»/«Головна» через `ActionCard`).
4. **`KrupaBottomBar`:** точні значення `containerColor`/`contentColor`/`tonalElevation` (у байткоді нулі → дефолти), `contentDescription` іконки та наявність `windowInsets`/`label`-поведінки (`alwaysShowLabel`) не підтверджені; прапорці `NavOptionsBuilder` (`saveState`/`restoreState`/`launchSingleTop`) у `navigate(destination.route)` не вичитані.
5. **`ChoiceChipsRow`: ім'я параметра `selected`** та джерело порожнього літерала `""` не встановлені; виклики з екранів не знайдені.
6. **`ActionCard`: імена 4-го (`Boolean`) і 7-го (`String`) параметрів** не встановлені; виклики з екранів не знайдені.
7. **`CommonComponents.kt`:** параметричні імена `MetricCard` (`subtitle`, `accent`), `MasteryBar` (`percent`, `attempts`), `ActivityBar` (два `Int`), `SectionTitle` (`title` vs `titleUk`), `SectionHeaderWithAction` (`titleUk`/`actionTitle`/`onAction`) — відновлені за типами й рядковими константами класу, але **не доведені**; точні `colorScheme`-слоти текстів у `LabeledValueRow`/`EmptyState`/`SectionTitle` не вичитані.
8. **`ActivityBar`:** внутрішня структура (кількість стовпчиків, формула висоти, джерело даних `wordCount`/`reviewCount`, наявність підписів) не встановлена — підтверджено лише `Canvas`, розміри 20/70/6/4 dp і фінальний `Text`.
9. **`TopicMasteryRow`:** деталі розкладки (Row/Column, наявність `LinearProgressIndicator`, форматування відсотка й «спроб») не вичитані; аналогічно — точні dp-значення в `TopicCard` і `WordRow`.
10. **`WordRow`: зіставлення підписів `"нове"`, `"у навчанні"`, `"засвоєно"`, `"важке"`, `"ще не вчилося"` з `CardPhase`** (NEW/LEARNING/REVIEW) не встановлено; також не встановлено, які саме поля `Word` виводяться в рядку (слово, переклад, транскрипція, рід).
11. **`AppRoot`:** точні значення `contentWindowInsets`, `containerColor`/`contentColor` Scaffold (у байткоді нулі → дефолти) і поведінка `bottomBar` при `showBottomBar = false` (гілка повертає порожній композабл — перевірено лише наявність прапорця).
12. **`MainViewModel.bootstrap()`:** точна послідовність дій (які саме сховища/перевірки викликаються, як обчислюються `wordCount`, `learningStarted`, `profileExists`, `contentReady`) не вичитана з корутинного тіла.
13. **Типи `navArgument`** (`StringType`/`IntType`) для `itemId`, `wordId`, `topicId`, `minutes`, `kind` у дампі не відображені (лише самі виклики `navArgument`).
14. **Кольори/розміри компонентів**, де в байткоді стоять нулі (напр., кольори `Text` у `CommonComponents`), не відрізняються від «дефолт Material3» — у звіті позначено як «не задано».
15. Вихідні smali-дампи (`_work/smali/*_ui.txt`), використані для цього звіту, **були видалені з робочого простору під час роботи** (їх замінено на `spec/_work/classes/`, де класів UI-пакета немає); тому частину деталей (пункти 4–11) неможливо перепроверити без повторного baksmali.
