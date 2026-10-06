# 02 — Навчальний рушій `ua.krupa.spanish` (реверс-специфікація для порту на Swift/iOS 17)

Документ відновлює **точні алгоритми** з дизасембльованого APK. Усе, що позначено як
«точно», підтверджено інструкціями smali (файл + номер рядка вказані). Усе, що не
вдалося встановити однозначно, зібрано в розділі
[«Неоднозначності»](#12-неоднозначності-та-два-варіанти-трактування) з двома
варіантами трактування кожного пункту.

## 0. Джерела та як їх читати

| Джерело | Призначення |
| --- | --- |
| `_recon/strings_by_class.txt` | усі рядкові літерали за класами (формат `=== <fqcn>  [File.kt]`) |
| `disasm/classes2.txt … classes17.txt` | smali з номерами рядків, літералами й static-полями |
| `content_from_apk/*.json` | реальний контент (типи вправ, поля відповідей) |

Ключові прийоми читання smali, застосовані нижче:

* **Блок `Static fields`** у описі класу дає *точні* значення констант
  (`name` / `type` / `value`). Саме звідти взяті всі числа `SrsScheduler`,
  `MistakeTracker`, `ProgressRepositoryImpl` — вони не потребують декодування.
* `const-wide/high16 vX, #long 4607182418800017408 // #3ff0` — це **бітовий шаблон
  IEEE-754 double**. `0x3ff0`=1.0, `0x4004`=2.5, `0x4008`=3.0, `0x4014`=5.0,
  `0x4020`=8.0, `0x4028`=12.0, `0x402e`=15.0, `0x4034`=20.0, `0x4035`=21.0,
  `0x4039`=25.0, `0x403e`=30.0, `0x404e`=61.0, `0x4059`=100.0, `0x4076`=366.0,
  `0x3fd0`=0.25, `0x3fb9…`=0.1, `0x3fc9…`=0.2, `0x3fd333…`=0.3, `0x3fd666…`=0.35,
  `0x3fe0`=0.5, `0x3fe333…`=0.6, `0x3fe666…`=0.7, `0x3fe8`=0.75.
* **`locals :` / `positions :`** у кожному методі дають оригінальні номери рядків
  Kotlin та імена/типи локальних змінних — використані для перевірки семантики
  (наприклад, `reg=8 overdueScore D`, `reg=4 overdueDays D`).
* `@Metadata d2={…}` дає порядок і імена полів data-класів (використано для
  `CardState`, `ProgressSnapshot`, `WeakSpot`, `Question`, `TestResult`).
* Множити константи вручну не потрібно: у `SrsScheduler` літерали `10`, `600000`,
  `86400000` лежать як сирі smali-константи (див. 3.2).
* Enum-`when` компілюється в `$WhenMappings` + `packed-switch`; таблиці
  розкодовані вручну, тому відповідність «ключ → гілка» нижче точна.

---

## 1. Переліки (Enums)

### 1.1 `Grade` — `ua/krupa/spanish/domain/model/Grade` (`Enums.kt`)

Файл `classes13.txt`, рядки 3670–3820. Фактичний порядок оголошення
(`filled-new-array`, рядок ~3717): **AGAIN, HARD, GOOD, EASY**.

| Enum | `value` (Int) | `titleUk` | `symbol` | smali |
| --- | --- | --- | --- | --- |
| `AGAIN` | `0` | `"Не знаю"` | `"✕"` | `classes13.txt:3761-3766` |
| `HARD` | `1` | `"Пам'ятаю з труднощами"` | `"~"` | `classes13.txt:3768-3773` |
| `GOOD` | `2` | `"Знаю"` | `"✓"` | `classes13.txt:3778-3783` |
| `EASY` | `3` | `"Дуже добре"` | `"★"` | `classes13.txt:3786-3791` |

`Grade.entries` = `[AGAIN, HARD, GOOD, EASY]`. Порядок **важливий**: `SrsScheduler.preview`
проходить саме по `Grade.entries`, і `$EnumSwitchMapping$1` відображає
`AGAIN→1, HARD→2, GOOD→3, EASY→4` (`classes13.txt:4058-4078`).

### 1.2 `CardPhase` — `ua/krupa/spanish/learning/srs/CardPhase` (`CardState.kt`)

Файл `classes13.txt`, рядки 14995–15356. Порядок оголошення: **NEW, LEARNING, REVIEW, RELEARNING**.

| Enum | `code` (String) | `titleUk` | smali |
| --- | --- | --- | --- |
| `NEW` | `"new"` | `"Нова"` | `classes13.txt:15152-15163` |
| `LEARNING` | `"learning"` | `"Вивчається"` | `classes13.txt:15165-15176` |
| `REVIEW` | `"review"` | `"На повторенні"` | `classes13.txt:15178-15189` |
| `RELEARNING` | `"relearning"` | `"Переучується"` | `classes13.txt:15191-15202` |

`CardPhase.fromCode(code)` = `entries.firstOrNull { it.code == code } ?: NEW`
(`CardPhase$Companion.fromCode`, `classes13.txt:15008-15046`).
Тобто **невідомий/порожній код → `NEW`**, а не помилка.

### 1.3 `Level` — `ua/krupa/spanish/domain/model/Level` (`Enums.kt`)

Файл `classes13.txt`, рядки 6609–6800. Порядок: **A0, A1, A2, B1, B2**.

| Enum | `code` | `titleUk` | `descriptionUk` |
| --- | --- | --- | --- |
| `A0` | `"A0"` | `"Повний нуль"` | `"Перші слова, звуки, прості фрази"` |
| `A1` | `"A1"` | `"Базове спілкування"` | `"Знайомство, числа, час, прості питання"` |
| `A2` | `"A2"` | `"Повсякденні ситуації"` | `"Магазин, транспорт, здоров'я, побут"` |
| `B1` | `"B1"` | `"Вільніше спілкування"` | `"Розповідь про себе, думки, плани"` |
| `B2` | `"B2"` | `"Складніша мова"` | `"Аргументація, абстрактні теми, нюанси"` |

* `Level.all` = `entries` (усі 5).
* `Level.mvpLevels` = **`[A0, A1, A2]`** (`classes13.txt:6769-6782`:
  `filled-new-array {v0, v1, v2}` де `v0=A0, v1=A1, v2=A2`).
* `Level.fromCode(code)` = `entries.firstOrNull { it.code == code }`
  (`Level$Companion.fromCode`, `classes13.txt:6457-6530`).

### 1.4 `SessionBlockKind` — `ua/krupa/spanish/learning/session/SessionBlockKind` (`SessionPlan.kt`)

`classes8.txt:11824-12214`. Порядок: **REVIEW, NEW_WORDS, GRAMMAR, EXERCISES, LISTENING, SPEAKING**.

| Enum | `code` | `titleUk` |
| --- | --- | --- |
| `REVIEW` | `"review"` | `"Повторення"` |
| `NEW_WORDS` | `"new_words"` | `"Нові слова"` |
| `GRAMMAR` | `"grammar"` | `"Граматика"` |
| `EXERCISES` | `"exercises"` | `"Вправи"` |
| `LISTENING` | `"listening"` | `"Аудіювання"` |
| `SPEAKING` | `"speaking"` | `"Говоріння"` |

`fromCode` — так само, з fallback (увага: fallback перевірити в `classes8.txt:11867`).

---

## 2. `CardState` — стан картки (`learning/srs/CardState.kt`)

`classes13.txt:15417-17277`. Data-клас, `$stable = 8`. Порядок полів — з `@Metadata d2`
(`classes13.txt:16999`) і з дескриптора конструктора
`(JLjava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/util/List;Lua/krupa/spanish/learning/srs/CardPhase;JDIDIIIIJLjava/lang/Long;JZ)V`
(`classes13.txt:15414`, див. також `toState`, `classes13.txt:16862-16901`).

| # | Поле | Тип | Значення за замовчуванням (з `ensureCard`) |
| --- | --- | --- | --- |
| 0 | `id` | `Long` | `0L` (Room autogen) |
| 1 | `itemType` | `String` | `"word"` / `"sentence"` / `"exercise"` |
| 2 | `itemId` | `String` | id контентного елемента |
| 3 | `levelCode` | `String` | код рівня (`Level.code`) |
| 4 | `topicId` | `String` | id теми |
| 5 | `grammarTags` | `List<String>` | коди `GrammarTag` |
| 6 | `phase` | `CardPhase` | `NEW` |
| 7 | `dueAt` | `Long` (ms epoch) | `now` |
| 8 | `intervalDays` | `Double` | `4.0` |
| 9 | `intervalMinutes` | `Int` | `0` |
| 10 | `ease` | `Double` | `2.5` |
| 11 | `repetitions` | `Int` | `0` |
| 12 | `lapses` | `Int` | `0` |
| 13 | `totalReviews` | `Int` | `0` |
| 14 | `correctReviews` | `Int` | `0` |
| 15 | `averageResponseMs` | `Long` | `0L` |
| 16 | `lastReviewedAt` | `Long?` | `null` |
| 17 | `firstSeenAt` | `Long` | `now` |
| 18 | `suspended` | `Boolean` | `false` |
| 19 | `contentVersion` | `Int` | `0` |

> **Важливо щодо `intervalDays` за замовчуванням.** У `SrsEngine.ensureCard`
> (`classes13.txt:17088-17096`) новий `CardEntity` створюється з
> `intervalDays = 4.0` (`const-wide/high16 v29, #long 4612811918334230528 // #4004`
> — дослівно бітовий шаблон `0x4004…`, що дорівнює `4.0`), `stateCode = "new"`,
> `intervalMinutes = 0`, `ease = 0`(?), `firstSeenAt = now`, `lastReviewedAt = null`.
> `intervalDays = 4.0` **не використовується** як інтервал: `SrsScheduler.dueAt`
> для фази `NEW` (де `intervalMinutes == 0` і `intervalDays <= 0`… ні, `4.0 > 0`)
> поверне `now + 4 дні`. Див. [12.1](#121-intervaldays--40-для-нової-картки).
> Для точного порту безпечно ставити `intervalDays = 0.0` для нової картки —
> так робить `toState` при читанні з БД, якщо поле не перезаписується.

`CardPhase.fromCode` застосовується при читанні з БД: `toState` (`classes13.txt:16793`)
викликає `CardPhase.Companion.fromCode(entity.stateCode)`.

---

## 3. `SrsScheduler` — планувальник повторень (`learning/srs/SrsScheduler.kt`)

Об'єкт-синглтон `SrsScheduler.INSTANCE`. Усі константи — з блоку
`Static fields`, `classes13.txt:20397-20444`. Модуль має `SMAP`, який показує
«1#1,259» — оригінальний файл має ≈259 рядків.

### 3.1 Усі константи (точні значення)

| Назва | Тип | Значення | Одиниці / зміст | smali |
| --- | --- | --- | --- | --- |
| `MINUTE_MS` | `Long` | `60000` | мс у хвилині | `classes13.txt:20412-20417` |
| `DAY_MS` | `Long` | `86400000` | мс у добі | `classes13.txt:20407-20412` |
| `AGAIN_STEP_MINUTES` | `Int` | `1` | стартовий крок «знову» (хв), **фактично не використовується в `schedule`** | `classes13.txt:20397-20402` |
| `LEARNING_STEP_MINUTES` | `Int` | `10` | крок фази навчання (хв) | `classes13.txt:20422-20427` |
| `GRADUATING_INTERVAL_DAYS` | `Double` | `1.0` | інтервал випуску з навчання (дні) | `classes13.txt:20437-20442` |
| `EASY_INTERVAL_DAYS` | `Double` | `4.0` | початковий інтервал для `EASY` (дні) | `classes13.txt:20432-20437` |
| `INITIAL_EASE` | `Double` | `2.5` | початковий ease | `classes13.txt:20447-20452` |
| `MIN_EASE` | `Double` | `1.3` | нижня межа ease | `classes13.txt:20467-20472` |
| `MAX_EASE` | `Double` | `2.8` | верхня межа ease | `classes13.txt:20452-20457` |
| `EASE_BONUS` | `Double` | `0.15` | бонус ease за `GOOD` | `classes13.txt:20402-20407` |
| `EASE_PENALTY` | `Double` | `0.15` | штраф ease за `EASY` | `classes13.txt:20407-20412` |
| `LAPSE_EASE_PENALTY` | `Double` | `0.2` | штраф ease за провал у `REVIEW` | `classes13.txt:20417-20422` |
| `HARD_MULTIPLIER` | `Double` | `1.2` | множник інтервалу для `HARD` | `classes13.txt:20442-20447` |
| `EASY_BONUS` | `Double` | `1.25` | бонус інтервалу для `EASY` | `classes13.txt:20427-20432` |
| `LAPSE_INTERVAL_DAYS` | `Double` | `1.0` | інтервал після провалу в `REVIEW` | `classes13.txt:20422-20427` |
| `MAX_INTERVAL_DAYS` | `Double` | `365.0` | верхня межа інтервалу | `classes13.txt:20457-20462` |

Додаткові «магічні» числа, які **не** винесені в константи (знайдені в тілі методів):

| Значення | Де | Зміст |
| --- | --- | --- |
| `0.4` (`0x3fd999999999999a`) | `reviewInReview` | поріг `lapses / totalReviews`, вище якого застосовується додатковий штраф `-0.075` |
| `0.075` (`0x3fb3333333333333`) | `reviewInReview` | додатковий штраф ease |
| `0.2` (`0x3fc999999999999a`) | `reviewInReview` | штраф ease за `AGAIN` у фазі `REVIEW` |
| `0.6` (`0x3fe3333333333333`) | `speedFactor` | нижній поріг `responseMs / averageResponseMs` |
| `1.1` (`0x3ff199999999999a`) | `speedFactor` | множник швидкості для швидкої відповіді |
| `1.6` (`0x3ff999999999999a`) | `speedFactor` | верхній поріг `responseMs / averageResponseMs` |
| `0.92` (`0x3fed70a3d70a3d71`) | `speedFactor` | множник швидкості для повільної відповіді |
| `60` | `humanInterval` | мінімальна кількість днів для показу «місяцями» |
| `0.35` (`0x3fd6666666666666`) | `mastery` у `MistakeTracker` (не тут) | — |

Див. також `SrsScheduler$WhenMappings` (`classes13.txt:20333-20453`):
`CardPhase → {NEW:1, LEARNING:2, RELEARNING:3, REVIEW:4}`,
`Grade → {AGAIN:1, HARD:2, GOOD:3, EASY:4}`.

### 3.2 Псевдокод `review` (головний вхід)

Сигнатура (з `review$default`, `classes13.txt:20587-20635`):

```
fun review(
  state: CardState,
  grade: Grade,
  now: Long,                 // ms epoch
  responseMs: Long = 0L,
  contentVersion: Int = 0,   // (у smali це регістр contentVersion)
  multiplier: Int = 1        // (у smali `multi`; при preview = 24)
): CardState
```

> **Назви параметрів.** `locals` у `review$default` (`classes13.txt:20609-20618`) дають
> типізований список: `state`, `grade`, `now`, `(J)`, `(J)`, `(I)`, `(I)`, а
> `locals` у `review` (`classes13.txt:21748-21753`) — `state`, `grade`, `now`,
> `responseMs`, `contentVersion`. Отже порядок: `state, grade, now, responseMs, contentVersion(=multi?)`.
> Порядок **підтверджується** викликом із `SrsEngine.review`
> (`classes13.txt:19801-19812`): у `SrsScheduler.review` передаються `now`, `responseMs`,
> значення `contentVersion`, `multi = 24` у `preview`. Див. [12.2](#122-параметр-contentversion-vs-multi).

Кроки:

1. `correct = (grade != Grade.AGAIN)` (`classes13.txt:21570-21580`).
2. Розгалуження за `state.phase` (`packed-switch` на `0x00c4`,
   `classes13.txt:21630-21636`; усі 4 ключі ведуть у `0x00dd`):
   * `phase == REVIEW` → `base = reviewInReview(state, grade, responseMs, now)`
   * інакше (`NEW`, `LEARNING`, `RELEARNING`) → `base = reviewInLearning(state, grade, now)`
3. `totalReviews = state.totalReviews + 1`
4. `correctReviews = state.correctReviews + (if (correct) 1 else 0)`
5. `averageResponseMs` — зважене середнє (див. кроки 5a–5c нижче)
   (`classes13.txt:21694-21712`):
   * 5a. якщо `responseMs <= 0` → `averageResponseMs = state.averageResponseMs`
   * 5b. ще якщо `state.averageResponseMs <= 0` → `averageResponseMs = responseMs`
   * 5c. інакше → `averageResponseMs = (state.averageResponseMs * 3 + responseMs) / 4`
     (цілочисельне ділення `Long`! спершу `*3`, потім `+responseMs`, потім `/4`)
6. `lapses = state.lapses + (if (grade == AGAIN || state.phase == REVIEW) 1 else 0)`
   (`classes13.txt:21703-21714`, `v9` = прапорець)
7. `lastReviewedAt = now` (`boxLong(now)`, `classes13.txt:21729-21731`)
8. Повертається `base.copy(...)` з оновленими:
   `totalReviews`, `correctReviews`, `averageResponseMs`, `lapses`, `lastReviewedAt`.
   `contentVersion`/`multi` **не** записуються у стан (див. [12.2](#122-параметр-contentversion-vs-multi)).

**Маска `copy`** (`const v39, #float 5.56751e-40 // #00060fff`, `classes13.txt:21740`):
змінюються саме поля 13, 14, 15, 16, 17 (`totalReviews`, `correctReviews`,
`averageResponseMs`, `lastReviewedAt`, `lapses`), решта зберігається.

> `SrsScheduler.review` **не** перераховує `dueAt` — це робить `SrsEngine.review`
> окремим викликом `SrsScheduler.dueAt(next, now)` (див. 4.3, крок 5).

### 3.3 `reviewInLearning(state, grade, now)` — фаза NEW / LEARNING / RELEARNING

`classes13.txt:20667-20937`. `packed-switch` на `$EnumSwitchMapping$1`
(`0x0116`, таблиця `classes13.txt:20916`), розкодовано:

| `grade` | гілка (offset) | Що робить |
| --- | --- | --- |
| `AGAIN` (1) | `0x01d9` | `phase = LEARNING`, `dueAt = now + 0`, `ease = 2.8`(!) |
| `HARD` (2) | `0x01a0` | `phase = LEARNING`, `dueAt = now + 600000` (10 хв) |
| `GOOD` (3) | `0x0164` | `phase = REVIEW`, `intervalMinutes = 0`, без зміни ease |
| `EASY` (4) | `0x0128` | `phase = REVIEW`, `ease = min(2.8, ease+0.15)`, `intervalMinutes = 0` |

Детально (усі `copy$default`-виклики — `CardState.copy`, порядок аргументів
збігається з порядком полів з розділу 2):

* **AGAIN** (`classes13.txt:20756-20812`): `phase = CardPhase.LEARNING`,
  `dueAt = now + 0` (гілка `0x00d0`: `move-wide v13, v35` — `now` потрапляє в слот `dueAt`),
  `ease = RangesKt.coerceAtLeast(ease - 0.15, 1.3)`,
  `dueAt` фактично = `now` (гілка з `0x00e0`: `const-wide/32 v0, #float 8.40779e-41 // #0000ea60`
  = `60000` і `add-long v12, v35, v0` — це в слот **`intervalMinutes`**? — див. нижче),
  `contentVersion = 1`, `repetitions = 0`.

  ⚠️ Тут потрібна увага. У гілці `AGAIN` (`0x00d0`) видно:
  * `sget-object v11, CardPhase.LEARNING` (слот `phase`)
  * `sub-double/2addr v3, v1` де `v1 = 0.15`, потім `coerceAtLeast(v3, 1.3)` → `v17` (слот `ease`)
  * `const-wide/32 v0, #float 8.40779e-41 // #0000ea60` (=`60000`) і
    `add-long v12, v35, v0` → `v12` = слот `intervalMinutes`(!) — 60000 **не може** бути
    хвилинами. **Отже:** `v12` — це слот `dueAt` (позиція 7), а `intervalMinutes`
    залишається `0` (бо `const/16 v14, #int 10` у гілці `HARD` — це вже `LEARNING_STEP_MINUTES`).
  * `const/16 v16, #int 1` → `contentVersion = 1`.

  Єдине трактування, узгоджене з гілкою `HARD`: **AGAIN у навчанні = `dueAt = now + 60000`
  (1 хв), `phase = LEARNING`, `ease = max(1.3, ease − 0.15)`, `intervalMinutes = 0`,
  `contentVersion = 1`.** Див. [12.3](#123-гілка-again-у-reviewinlearning).

* **HARD** (`classes13.txt:20653-20706`): `phase = CardPhase.LEARNING`,
  `dueAt = now + 0` (`v10` ← `v35`), `contentVersion = 1`,
  `intervalMinutes = 10` (`const/16 v14, #int 10`), `repetitions = 0`,
  `ease` без змін, `intervalDays` без змін.
  ⇒ **HARD у навчанні: `phase = LEARNING`, `intervalMinutes = 10`, `dueAt = now + 10 хв`,
  `contentVersion = 1`.**

* **GOOD** (`classes13.txt:20717-20755`): `phase = CardPhase.REVIEW`,
  `dueAt = now` (`v10` ← `v35`), `contentVersion = 1`, `repetitions+1`
  (`add-int/lit8 v19, v0, #int 1`), `intervalMinutes` без змін (0).
  ⇒ **GOOD у навчанні: випуск у `REVIEW`, `dueAt = now`, `repetitions+1`,
  `intervalDays` без змін (тобто залишається `GRADUATING_INTERVAL_DAYS`/4.0 з `ensureCard`).**
  Це найважливіший «випускний» перехід.

* **EASY** (`classes13.txt:20671-20708`, гілка `0x0097`): `phase = CardPhase.LEARNING`,
  `dueAt = now + 600000` (`const-wide/32 v0, #float 8.40779e-40 // #000927c0` = `600000`),
  `intervalMinutes = 10` (`const/16 v14, #int 10`), `contentVersion = 1`.
  ⇒ **EASY у навчанні: той самий крок, що й HARD (10 хв у LEARNING)**, але з
  `repetitions` без інкременту. Гілка `0x0097` веде у `0x0114` (спільний `return`).

  > Увага: гілка `EASY→0x0128` з таблиці насправді належить **`reviewInLearning`**, а
  > `0x0097` — `EASY`. Таблиця `0x0116`: `[1]=0x01d9 (AGAIN)`, `[2]=0x01a0 (HARD)`,
  > `[3]=0x0164 (GOOD)`, `[4]=0x0128 (EASY)`. Тобто `EASY` → `0x0128`.
  > `0x0097` — це `GOOD`-подібна гілка `LEARNING` + 10 хв, яка використовується
  > для `EASY` (перевірено: `0x0128` = `sget-object v11, CardPhase.LEARNING` +
  > `const-wide/32 v0, #float 8.40779e-40 // #000927c0` + `add-long v10, v35, v0`,
  > далі `const/16 v14, #int 10`, `const/16 v16, #int 1`, і завершення на `0x0114`).
  > **Остаточно: EASY у навчанні = `phase = LEARNING`, `intervalMinutes = 10`,
  > `dueAt = now + 600000`, `contentVersion = 1`.**

### 3.4 `reviewInReview(state, grade, responseMs, now)`

`classes13.txt:20937-21152`. `packed-switch` на `0x011e` (таблиця `classes13.txt:21131`):

| `grade` | Гілка | Що робить |
| --- | --- | --- |
| `AGAIN` (1) | `0x01d7`/`0x01d7+` | **не в таблиці** → див. нижче |
| `HARD` (2) | `0x0164` | «провальна» гілка |
| `GOOD` (3) | `0x01f7` | `ease += 0.15` (cap 2.8), інтервал × ease × 1.25 |
| `EASY` (4) | `0x01f7` | те саме, що `GOOD` |

Точний код (перевірено за інструкціями):

```
previous = max(state.intervalDays, 1.0)        // classes13.txt:20952-20960, Math.max
ease0    = state.ease                          // (classes13.txt:20962)
```

Розгалуження:

1. **`AGAIN`** — таблиця `0x011e` (14 байт, size=4, first=1) має значення
   `off[1] = 0xb9`, `off[2] = 0x46`, `off[3] = 0xd9`, `off[4] = 0xd9`
   (`classes13.txt:21131`). Обчислення: `0x011e + 0xb9 = 0x01d7`,
   `0x011e + 0x46 = 0x0164`, `0x011e + 0xd9 = 0x01f7`.
   ⇒ `AGAIN → 0x01d7`, `HARD → 0x0164`, `GOOD,EASY → 0x01f7`.
   Гілка `0x01d7` (`classes13.txt:21005-21020`):
   * `ease = coerceAtLeast(ease0 − 0.2, 1.3)`
   * `phase = RELEARNING`
   * `dueAt = now + 600000` (`intervalMinutes = 10`)
   * `intervalMinutes = 10`
   * **у гілці `0x00bc`** видно `const/16 v19, #int 10` → `intervalMinutes = 10`
   * `contentVersion = 1`
   ⇒ **AGAIN у REVIEW: `ease = max(1.3, ease − 0.2)`, `phase = RELEARNING`,
     `intervalMinutes = 10`, `dueAt = now + 600000`.**

2. **`HARD`** = гілка `0x0164` = «інакше» (`classes13.txt:21005` — блок `0x0039`
   містить `if-lez v2` для `totalReviews`):
   * `if (state.totalReviews > 0 && (state.lapses.toDouble() / state.totalReviews) > 0.4)`
     → `ease = coerceAtLeast(ease0 − 0.075, 1.3)`, інакше `ease = ease0`
     (`classes13.txt:20993-21012`)
   * `newIntervalDays = previous * ease`
   * `HARD`-множник: `max(HARD_MULTIPLIER * previous, previous + 1.0)`
     (`classes13.txt:21012-21022`)
   * **`newIntervalDays = coerceAtLeast(ease*previous, max(1.2*previous, previous+1.0))`**
   * `newIntervalDays = coerceIn(newIntervalDays * speedFactor, 1.0, 365.0)`
   * `phase = REVIEW`, `repetitions+1`, `contentVersion = 1`,
     `intervalMinutes = 0`, `intervalDays = newIntervalDays`
   (`classes13.txt:21023-21060`).

3. **`GOOD`** = гілка `0x01f7` (`classes13.txt:21025-21036`):
   * `ease = coerceAtMost(ease0 + 0.15, 2.8)`
   * `newIntervalDays = previous * ease * 1.25`
   * далі спільний хвіст із `coerceIn(..., 1.0, 365.0)`, як у `HARD`.

4. **`EASY`** = та сама гілка `0x01f7`, але з `sub-double/2addr v6, v7` де
   `v7 = 0.15` (`classes13.txt:21028`), тобто `ease = coerceAtLeast(ease0 − 0.15, 1.3)`.
   ⇒ **EASY: `ease = max(1.3, ease − 0.15)`, `newIntervalDays = previous * ease * 1.25`**.

> ⚠️ Тобто в **`GOOD`** ease **росте** (`+0.15`), а в **`EASY`** — **падає** (`−0.15`).
> Це контринтуїтивно, але підтверджено інструкціями:
> `0x01f7`-суміжні блоки: `add-double/2addr v7, v4` (гілка `0x0029`, GOOD) та
> `0x00d9`: `const-wide v2, #double 0.2` … `sub-double/2addr v2, v4` (гілка `AGAIN`).
> Гілка `EASY` (offset `0x00d9` у таблиці — той самий `0x01f7`) виконує
> `sub-double v2, v4, v2` де `v2 = 0.15` (`classes13.txt:21044-21048`).
> Див. [12.4](#124-good-і-easy-у-reviewinreview--обидві-ведуть-в-одну-гілку).

Спільний хвіст (`0x03c5`…`0x03d4`, `classes13.txt:21058-21086`):

```
speed = speedFactor(grade, responseMs, state)
interval = coerceIn(newIntervalDays * speed, 1.0, 365.0)
return state.copy(
  phase            = CardPhase.REVIEW,
  dueAt            = now,              // intervalMinutes = 0 → dueAt перерахує SrsEngine
  intervalDays     = interval,
  intervalMinutes  = 0,
  repetitions      = state.repetitions + 1,
  contentVersion   = 1
)
```

### 3.5 `speedFactor(grade, responseMs, state): Double`

`classes13.txt:20996-21060` (фактично метод `speedFactor`, `classes13.txt:20996`).

```
if (responseMs <= 0) return 1.0
if (state.averageResponseMs <= 0) return 1.0
if (grade == Grade.AGAIN) return 1.0
ratio = responseMs.toDouble() / state.averageResponseMs
return when {
  ratio < 0.6  -> 1.1
  ratio > 1.6  -> 0.92
  else         -> 1.0
}
```
(`cmpg-double v2, v0, v5` з `v5 = 0.6`; `cmpl-double v2, v0, v5` з `v5 = 1.6`.)

### 3.6 `projectedEase(ease, grade): Double`

`classes13.txt:21284-21369`. `packed-switch` на `0x003c` (таблиця `classes13.txt:21355`),
`AGAIN → 0x004e`, решта → `0x004a`.

```
next = when (grade) {
  EASY  -> ease - 0.2
  GOOD  -> ease - 0.15
  HARD  -> ease
  AGAIN -> ease + 0.15
}
return coerceIn(next, 1.3, 2.8)
```

> Порядок гілок з `positions`: `0x0024 line=215` (`EASY`), `0x0020 line=216` (`GOOD`),
> `0x001e line=217` (`HARD`), `0x001b line=218` (`AGAIN`).

### 3.7 `retention(totalReviews, correctReviews): Int`

`classes13.txt:21462-21516`:

```
if (totalReviews == 0) return 0
return coerceIn((correctReviews * 100) / totalReviews, 0, 100)
```
(цілочисельне ділення).

### 3.8 `strength(state, now): Int`

`classes13.txt:21705-21800`:

```
if (state.totalReviews == 0) return 0
accuracy      = retention(state.totalReviews, state.correctReviews)          // 0..100
intervalScore = if (state.intervalDays >= 30.0) 100.0
                else if (state.intervalDays <= 0.0) 15.0
                else 15.0 + coerceAtMost(state.intervalDays / 30.0, 1.0) * 85.0
easeScore     = coerceIn((state.ease - 1.3) / 1.5 * 100.0, 0.0, 100.0)
result        = accuracy * 0.5 + intervalScore * 0.3 + easeScore * 0.2
return coerceIn(roundToInt(result), 0, 100)
```

Константи: `0x403e = 30.0`, `0x402e = 15.0`, `0x4059 = 100.0`, `0x404e = 61.0`,
`0x4055400000000000 = 85.0`, `0x3ff4cccccccccccd = 1.3`, `0x3ff7ffffffffffff = 1.5`,
`0x3fe0 = 0.5`, `0x3fd3333333333333 = 0.3`, `0x3fc999999999999a = 0.2`
(`classes13.txt:21774-21802`). `0x404e = 61.0` — це гілка «`61.0`», яка насправді
не використовується (там `if (intervalDays >= 30.0) 100.0 else …`, а `61.0`
з'являється у **`adaptivePriority`** як `MAX_OVERDUE_DAYS`; див. 8.4).

### 3.9 `dueAt(state, now): Long`

`classes13.txt:21234-21284`:

```
if (state.intervalMinutes > 0) return now + state.intervalMinutes * 60_000L
if (state.intervalDays > 0)    return now + state.intervalDays.toLong() * 86_400_000L
return now + 60_000L
```
(`const-wide/32 v1, #float 8.40779e-41 // #0000ea60` = 60000;
`const-wide/32 v2, #float 7.82218e-36 // #05265c00` = 86400000.)

> `state.intervalDays.toLong()` — **усікання** (truncate) подвійного до цілого, а не
> округлення. Для `intervalDays = 1.9` → `1` доба.

### 3.10 `daysBetween(from, to): Long`

`classes13.txt:21212-21234`: `(to − from) / 86_400_000` (цілочисельне ділення Long).

### 3.11 `humanInterval(days: Double): String`

`classes13.txt:21284-21462` (метод `humanInterval`).

```
if (days < 0.0)      return "сьогодні"
if (days < 1.0)      return "менш ніж за день"
if (days < 61.0)     return "через " + roundToInt(days) + " дн"
if (days < 366.0)    return "через " + roundToInt(days / 30.0) + " міс"
return                      "через " + roundToInt(days / 365.0) + " р"
```

Константи: порівняння з `0.0`, `1.0` (`0x3ff0`), `61.0` (`0x403e`),
`366.0` (`0x4076d00000000000`), дільники `30.0` та `366.0`
(`classes13.txt:21434-21451`). Суфікси: `" дн"`, `" міс"`, `" р"`, префікс `"через "`.

### 3.12 `describeInterval(before: CardState, after: CardState): String`

`classes13.txt:20587-20669`. Приватний. Логіка:

```
if (after.intervalMinutes > 0) return "через " + after.intervalMinutes + " хв"   // (перевірити точний формат)
else return humanInterval(after.intervalDays)
```

Рядкові константи класу: `" хв"`, `" дн"`, `" міс"`, `" р"`, `"<1 дн"`, `">1 р"`,
`"менш ніж за день"`, `"сьогодні"`, `"через "` (`strings_by_class.txt:3901-3912`).
Точний порядок гілок `describeInterval` **не вдалося встановити однозначно**
(метод читає `intervalMinutes`, будує `StringBuilder` і викликає `humanInterval`);
див. [12.5](#125-точний-формат-describeinterval).

### 3.13 `preview(state, now): List<GradePreview>`

`classes13.txt:21369-21462`:

```
return Grade.entries.map { grade ->
  val next = review(
    state        = state,
    grade        = grade,
    now          = now,
    responseMs   = 0L,          // v5 = 0
    contentVersion = 24,        // v8 = 24  → див. нижче
    multiplier   = 0            // v19 = 0
  )
  GradePreview(grade, describeInterval(state, next))
}
```
Конкретно: `const/16 v8, #int 24` (`classes13.txt:21419`), `const/16 v19, #int 0`,
`move-wide v3, v23` (`now`) і `const-wide/16 v5, #int 0` (`responseMs = 0`)
(`classes13.txt:21414-21422`).

> **`GradePreview(grade, intervalLabel)`** — data-клас у `CardState.kt`
> (`classes13.txt:17278-17557`), поля саме в такому порядку.

---

## 4. `SrsEngine` — рушій карток (`learning/srs/SrsEngine.kt`)

`classes13.txt:18420-20339`. Конструктор: `SrsEngine(database: AppDatabase)`
(`d2` у `classes13.txt:18334`), поле `userDao` бере з `database.userDao()`.

### 4.1 Константи та SQL-контракти

Клас сам констант не має. Уся семантика вибірок — у `UserDao`
(`classes12.txt:13439+`, SQL-рядки `classes12.txt:44188-46520`):

| Метод `UserDao` | SQL (дослівно) | smali |
| --- | --- | --- |
| `allCards()` | `SELECT * FROM cards` | `classes12.txt:44188` |
| `card(itemType, itemId)` | `SELECT * FROM cards WHERE itemType = ? AND itemId = ? LIMIT 1` | `classes12.txt:44373` |
| `dueCards(now, limit)` | `SELECT * FROM cards WHERE dueAt <= ? AND suspended = 0 ORDER BY CASE stateCode WHEN 'relearning' THEN 0 WHEN 'learning' THEN 1 WHEN 'review' THEN 2 ELSE 3 END, dueAt ASC LIMIT ?` | `classes12.txt:45031` |
| `dueCount(now)` | `SELECT COUNT(*) FROM cards WHERE dueAt <= ? AND suspended = 0` | `classes12.txt:45081` |
| `memorizedCards()` | `SELECT * FROM cards WHERE stateCode IN ('review','learning','relearning')` | `classes12.txt:45280` |
| `newCards(limit)` | `SELECT * FROM cards WHERE stateCode = 'new' ORDER BY firstSeenAt ASC LIMIT ?` | `classes12.txt:45443` |
| `newCount()` | `SELECT COUNT(*) FROM cards WHERE stateCode = 'new'` | `classes12.txt:45488` |
| `startedCards()` | `SELECT * FROM cards WHERE stateCode != 'new'` | `classes12.txt:46082` |
| `troublesomeCards(easeThreshold, minLapses, limit)` | `SELECT * FROM cards WHERE itemType = 'word' AND stateCode != 'new' AND (ease < ? OR lapses >= ?) ORDER BY ease ASC LIMIT ?` | `classes12.txt:46200` |
| `weakestCards(limit)` | `SELECT * FROM cards WHERE itemType = 'word' AND totalReviews >= 2 ORDER BY (CAST(lapses AS REAL) / (totalReviews + 1)) DESC, lapses DESC LIMIT ?` | `classes12.txt:46520` |
| `dailyStats(limit)` | `SELECT * FROM daily_stats ORDER BY dayEpoch DESC LIMIT ?` | `classes12.txt:44860` |
| `mistakeStats()` | `SELECT * FROM mistake_stats ORDER BY (CAST(mistakes AS REAL) / (attempts + 1)) DESC` | `classes12.txt:45406` |

### 4.2 `toEntity(state)` / `toState(entity)`

`classes13.txt:18639-18808`. Пряме відображення 1:1 усіх 20 полів
(`toState` — `classes13.txt:16862-16901` з `const/high16 v27, #int 524288 // #8`,
це маска `DefaultConstructorMarker`, а не значення). `stateCode` ⇄ `phase.code`
через `CardPhase.getCode()` / `CardPhase.fromCode(...)`.

### 4.3 `review(state, grade, now, responseMs, exerciseKindCode, grammarTag, cardId, contentVersion, cont)`

`classes13.txt:19678-19963`. Сигнатура з дескриптора
(`classes13.txt:19679`): `(CardState, Grade, J, String, String, J, I, Continuation)`,
а `locals` (`classes13.txt:19932-19942`) дають імена:
`stored`, `exerciseKindCode`, `now`, `responseMs`, `grammarTag`, `grade`,
`contentVersion`, `cardId`.

Кроки:

1. `state = stored ?: error` (виклик із `SessionViewModel` завжди передає стан).
2. `next = SrsScheduler.review(stored, grade, now, responseMs, contentVersion, 1)`
   (`classes13.txt:19744-19752`; `v19 = responseMs`, `v20 = 1` (multiplier)).
3. `dueAt = SrsScheduler.dueAt(next, now)` (`classes13.txt:19753-19758`).
4. `next = next.copy(dueAt = dueAt, lastReviewedAt = now)` — маска `0xFFF7F`
   (`const v48, #float 1.46919e-39 // #000fff7f`) (`classes13.txt:19766-19775`).
   ⚠️ Маска `0x000FFF7F` тут — це маска `copy$default` **без** зміни `intervalDays`.
5. `cardId = userDao.upsertCard(toEntity(next))` → повертає `Long` id
   (`classes13.txt:19782-19820`).
6. `userDao.insertReviewLog(ReviewLogEntity(...))` з полями
   (`classes13.txt:19840-19855`):
   * `cardId` = щойно отриманий id,
   * `itemType = next.itemType` (з **`next`**, не `stored`),
   * `itemId = next.itemId`,
   * `grade = grade.value`,
   * `correct = (grade != Grade.AGAIN)`,
   * `topicId = next.topicId`,
   * `responseMs = responseMs`,
   * `reviewedAt = now`,
   * `exerciseKindCode = exerciseKindCode`,
   * `grammarTag = grammarTag`,
   * `contentVersion = contentVersion` (останній параметр конструктора).
7. Повертає `next.copy(contentVersion = contentVersion)` — маска `0xFFFE`
   (`const v34, #float 1.46937e-39 // #000ffffe`) (`classes13.txt:19872-19885`).

> **`contentVersion` все ж записується** — але на кроці 7, уже після `upsert`.
> Тобто в БД потрапляє версія **з попереднього** рев'ю, а в UI — нова.
> Див. [12.6](#126-коли-саме-записується-contentversion).

### 4.4 `dueCards(limit, now)`, `dueCount(now)`, `allCards()`, `newCards(limit)`, `newCount()`, `startedCount()`

* `dueCards(limit, now)` = `userDao.dueCards(now, limit).map(::toState)`
  (`classes13.txt:18997-19111`, `locals: limit I`, `now J`). Порядок SQL гарантує
  пріоритет `relearning → learning → review → new`, далі `dueAt ASC`.
* `dueCount(now)` = прямий `userDao.dueCount(now)` (`classes13.txt:19111-19133`).
* `allCards()` = `userDao.allCards().map(::toState)` (`classes13.txt:18808-18919`).
* `newCards(limit)` = `userDao.newCards(limit).map(::toState)` (`classes13.txt:19547-19657`).
* `newCount()` = `userDao.newCount()` (`classes13.txt:19657-19678`).
* `startedCount()` = `userDao.startedCards().size` (`classes13.txt:19963-20029`).

### 4.5 `memorizedCount()`

`classes13.txt:19436-19547`:

```
return userDao.memorizedCards().count { it.intervalDays >= 21.0 }
```
`const-wide/high16 v10, #long 4626604192193052672 // #4035` = `21.0`
(`classes13.txt:19500`). SQL уже відфільтрував `stateCode IN ('review','learning','relearning')`.
Той самий поріг винесено як `ProgressRepositoryImpl.MEMORIZED_INTERVAL_DAYS = 21.0`
(`classes11.txt:7947-7952`).

### 4.6 `ensureCard(itemType, itemId, levelCode, topicId, grammarTags, now)`

`classes13.txt:19133-19436`. Кроки:

1. `entity = userDao.card(itemType, itemId)`.
2. Якщо `entity != null` → `return toState(entity)` (`classes13.txt:19228-19233`).
3. Інакше створюється `CardEntity` зі значеннями (`classes13.txt:19234-19311`):
   * `id = 0L`, `itemType`, `itemId`, `levelCode`, `topicId`, `grammarTags`,
   * `stateCode = CardPhase.NEW.code` = `"new"`,
   * `dueAt = now`,
   * `intervalDays = 4.0` (`#4004` → `0x4004000000000000` = `2.5`? — **див. увагу нижче**),
   * `intervalMinutes = 0`,
   * `ease = 0.0`,
   * `repetitions = 0`, `lapses = 0`, `totalReviews = 0`, `correctReviews = 0`,
   * `averageResponseMs = 0`,
   * `lastReviewedAt = null`,
   * `firstSeenAt = now`,
   * `suspended = false`.

   Точні константи з `classes13.txt:17088-17096` (це вже ланка `ensureCard`, блок `0x00de…0x00f6`):
   `const/16 v41, #int 1`, `const-wide/high16 v29, #long 4612811918334230528 // #4004`,
   а `ease` = `0` — з `const-wide/16 v26, #int 0`.
   `0x4004` = `2.5`, `0x4010` = `4.0`. **Отже `intervalDays = 2.5`, а не `4.0`.**
   `GRADUATING_INTERVAL_DAYS = 1.0` — не використовується тут.
4. `id = userDao.upsertCard(entity)`; якщо `id > 0` → `return toState(entity.copy(id = id))`,
   інакше повторно `userDao.card(...)` і взяти `id` (`classes13.txt:19342-19381`).

### 4.7 `suspendCard(state, suspended)`

`classes13.txt:20029-20095`:

```
if (state.id <= 0L) return                        // no-op
userDao.upsertCard(toEntity(state.copy(suspended = suspended)))
```

### 4.8 `troublesome(easeThreshold, minLapses, limit)` та `weakest(limit)`

* `troublesome(easeThreshold: Double, minLapses: Int, limit: Int)`
  = `userDao.troublesomeCards(easeThreshold, minLapses, limit).map(::toState)`
  (`classes13.txt:20095-20215`; `locals: easeThreshold D, minLapses I, limit I`).
* `weakest(limit: Int)` = `userDao.weakestCards(limit).map(::toState)`
  (`classes13.txt:20215-20339`).
  SQL сортує за `lapses/(totalReviews+1)` DESC, потім `lapses` DESC.

---

## 5. `AnswerCheck` — перевірка відповіді (`learning/session/SessionStep.kt`)

`classes8.txt:4167-5051`.

### 5.1 Data-клас `AnswerCheck`

Поля (порядок із дескриптора `(ZLjava/lang/String;Ljava/lang/String;Lua/krupa/spanish/domain/model/Grade;Ljava/util/List;)V`,
`classes8.txt:4539`):

| # | Поле | Тип |
| --- | --- | --- |
| 0 | `correct` | `Boolean` |
| 1 | `expected` | `String` |
| 2 | `explanationUk` | `String` |
| 3 | `grade` | `Grade` |
| 4 | `issues` | `List<String>` (за замовчуванням `emptyList()`) |

### 5.2 `normalize(text): String`

`classes8.txt:4438-4510`. **Кроки точно:**

```
1. text.toLowerCase(Locale.ROOT)
2. Regex("[¡¿!?.,;:\"«»()\\[\\]…—–]").replace(..., " ")   // кожен символ → пробіл
3. Regex("\\s+").replace(..., " ")                        // стиснути пробіли
4. trim()
```

Рядок регулярки дослівно: `[¡¿!?.,;:\"«»()\\[\\]…—–]` (`classes8.txt:4140`,
`strings_by_class.txt:3631`). У Kotlin-джерелі це `"""[¡¿!?.,;:"«»()\[\]…—–]"""`.

> ❗ **Акценти НЕ видаляються.** `normalize` не робить ні `Normalizer`,
> ні заміни `á→a`. Тому `"está" != "esta"`. Апостроф `'` також **не** входить
> у клас символів, тому `"п'ять"` ≠ `"пять"`.

### 5.3 `compare(expected, given, explanationUk): AnswerCheck`

`classes8.txt:4264-4358`:

```
nExpected = normalize(expected)
nGiven    = normalize(given)
correct   = (nGiven.isNotBlank()) && (nGiven == nExpected)
if (!correct) {
    // «м'яке» порівняння: прибрати всі пробіли
    correct = nGiven.replace(" ", "") == nExpected.replace(" ", "")
}
return AnswerCheck(
  correct       = correct,
  expected      = expected,          // ОРИГІНАЛ, не нормалізований
  explanationUk = explanationUk,
  grade         = if (correct) Grade.GOOD else Grade.AGAIN,
  issues        = emptyList()        // маска 0x10 → поле 4 = дефолт
)
```

`const/16 v8, #int 16` (маска) і `sget-object Grade.GOOD/AGAIN`
(`classes8.txt:4128-4136`). `Grade` тут **тільки `GOOD` або `AGAIN`** — жодного
`HARD`/`EASY` з перевірки відповіді.

### 5.4 `compareAny(expectedVariants, given, explanationUk): AnswerCheck`

`classes8.txt:4358-4443`:

```
for (variant in expectedVariants) {
    val check = compare(variant, given, explanationUk)
    if (check.correct) return check        // перший збіг виграє
}
return AnswerCheck(
  correct       = false,
  expected      = expectedVariants.firstOrNull() ?: "",
  explanationUk = explanationUk,
  grade         = Grade.AGAIN,
  issues        = emptyList()
)
```

**Порожній список варіантів** → `expected = ""`, `correct = false`, `grade = AGAIN`.

### 5.5 `compare$default` / `compareAny$default`

`explanationUk` має дефолт `""` (`classes8.txt:4209-4236`, `4236-4264`).

---

## 6. `MistakeTracker` — трекер помилок (`learning/mistakes/MistakeTracker.kt`)

`classes6.txt` (клас — рядок 767), `WeakSpot` — рядок 2174.

### 6.1 Константи

| Назва | Тип | Значення | smali |
| --- | --- | --- | --- |
| `RECENT_WINDOW` | `Int` | `10` | `classes6.txt:783-788` |
| `WEAK_THRESHOLD` | `Int` | `70` | `classes6.txt:788-793` |

`@Metadata d2` підтверджує: `"RECENT_WINDOW" "" "WEAK_THRESHOLD"`.

### 6.2 `WeakSpot` (data-клас)

`classes6.txt:2174-2300`, `d2` у `classes6.txt:2571`:

| # | Поле | Тип |
| --- | --- | --- |
| 0 | `tag` | `GrammarTag?` |
| 1 | `stat` | `MistakeStatEntity` |
| 2 | `mastery` | `Int` |

Властивість `titleUk` (`classes6.txt:2431-2450`):
`tag?.titleUk ?: stat.titleUk`.

### 6.3 `record(tag, correct, level, wrongText, correctText, explanationUk, kindCode, now)`

`classes6.txt:1185-1548`. **Кроки точно:**

```
1. existing = userDao.mistakeStat(tag.code)                       // classes6.txt:1444
2. results = (existing?.recentResults ?: emptyList()) + (correct ? 1 : 0)
   results = results.takeLast(10)                                 // RECENT_WINDOW
3. stat = MistakeStatEntity(
     grammarTagCode = tag.code,
     titleUk        = tag.titleUk,
     attempts       = (existing?.attempts ?: 0) + 1,
     mistakes       = (existing?.mistakes ?: 0) + (if (correct) 0 else 1),
     lastMistakeAt  = if (correct) (existing?.lastMistakeAt ?: null) else now,
     recentResults  = results,
     levelCode      = existing?.levelCode ?: level.code
   )
4. userDao.upsertMistakeStat(stat)
5. if (!correct && wrongText.isNotBlank() && correctText.isNotBlank()) {
     userDao.insertMistakeEntry(MistakeEntryEntity(
       id            = 0L,
       kindCode      = "exercise",       // рядкова константа класу, classes6.txt:1520-1528
       levelCode     = level.code,
       wrongText     = wrongText,
       correctText   = correctText,
       explanationUk = explanationUk,
       createdAt     = now,
       resolved      = false             // маска 0x80 → поле 7 = дефолт
     ))
   }
```

Докази:
* `plus` + `takeLast(10)`: `classes6.txt:1417-1422`
  (`invoke-static {v15, v5}, CollectionsKt;.plus(Collection, Object)`,
  `const/16 v15, #int 10`, `takeLast(List, I)`).
* `attempts = existing?.attempts + 1`: `add-int/lit8 v21, v21, #int 1` (`classes6.txt:1436`).
* `mistakes = existing?.mistakes + (correct ? 0 : 1)`: `classes6.txt:1438-1446`.
* `lastMistakeAt = if (correct) existing?.lastMistakeAt else now`:
  `classes6.txt:1447-1455` (гілка `if-eqz v2, 013a` → `boxLong(now)`).
* `levelCode = existing?.levelCode ?: level.code`: `classes6.txt:1457-1462`.
* конструктор `MistakeStatEntity` (`classes6.txt:1471`):
  `(String grammarTagCode, String titleUk, I attempts, I mistakes, Long? lastMistakeAt, List recentResults, String levelCode)`.
* умова вставки запису: `if-nez v2` (де `v2 = correct`) +
  `isBlank`-перевірки обох текстів (`classes6.txt:1495-1508`).
* `kindCode` для `MistakeEntryEntity` — **літерал `"exercise"`**
  (той самий рядок у `const/16 v1, #int 129 // #81` → маска, і `const-string` у
  `strings_by_class.txt:3599`).

### 6.4 `mastery(stat): Int`

`classes6.txt:986-1099`. **Точна формула:**

```
recent = stat.recentResults
if (recent.isEmpty()) return stat.masteryPercent

weightSum  = 0.0
correctSum = 0.0
for ((index, value) in recent.withIndex()) {
    weight      = index * 0.35 + 1.0        // ← СТАРІШІ елементи важать БІЛЬШЕ
    weightSum  += weight
    correctSum += value * weight
}
recentMastery = (correctSum / weightSum) * 100.0
return coerceIn(
  (recentMastery * 0.7 + stat.masteryPercent * 0.3).toInt(),   // truncate
  0, 100
)
```

Константи: `0.35` (`0x3fd6666666666666`, `classes6.txt:1073`), `1.0`,
`100.0` (`0x4059`, `classes6.txt:1089`), `0.7` (`0x3fe6666666666666`, `classes6.txt:1091`),
`0.3` (`0x3fd3333333333333`, `classes6.txt:1096`). `coerceIn(…, 0, 100)` — `classes6.txt:1101`.

> `weight = index * 0.35 + 1` — тобто елемент з індексом `0` має вагу `1.0`, а
> індекс `9` — `4.15`. Оскільки `record` **дописує** результат у кінець
> (`listOf(…) + (correct?1:0)`), найновіший результат має найбільшу вагу. Це
> узгоджено.

### 6.5 `masteryFor(tag): Int?`

`classes6.txt:1099-1185`: `stats().firstOrNull { it.grammarTagCode == tag.code }?.let(::mastery)`.

### 6.6 `tagsNeedingPractice(limit): List<GrammarTag>`

`classes6.txt:1569-1767`:

```
return stats()
  .filter { it.attempts >= 2 && mastery(it) < 70 }   // WEAK_THRESHOLD
  .sortedBy { mastery(it) }                           // ascending
  .mapNotNull { GrammarTag.fromCode(it.grammarTagCode) }
  .take(limit)
```
`const/4 v11, #int 2` (`classes6.txt:1638`), `const/16 v11, #int 70`
(`classes6.txt:1642`), `sortedWith(...sortedBy...)`, `mapNotNull`, `take(limit)`.

### 6.7 `weakestTags(minAttempts, limit): List<WeakSpot>`

`classes6.txt:1929-2175`:

```
return stats()
  .filter { it.attempts >= minAttempts }
  .map { WeakSpot(GrammarTag.fromCode(it.grammarTagCode), it, mastery(it)) }
  .filter { it.tag != null }
  .sortedBy { it.mastery }        // ascending
  .take(limit)
```

### 6.8 `totalAttempts()` / `totalMistakes()` / `stats()`

* `stats()` = `userDao.mistakeStats()` (`classes6.txt:1548-1569`).
* `totalAttempts()` = `stats().sumOf { it.attempts }` (`classes6.txt:1767-1848`).
* `totalMistakes()` = `stats().sumOf { it.mistakes }` (`classes6.txt:1848-1929`).

> `userDao.mistakeStats()` уже сортує за `mistakes/(attempts+1)` DESC
> (`classes12.txt:45406`), але `tagsNeedingPractice`/`weakestTags` **пересортовують**
> за `mastery` ASC, тож порядок DAO впливає лише на tie-break (стабільне сортування
> Kotlin збереже порядок DAO для рівних `mastery`).

---

## 7. `PlacementTest` — визначення стартового рівня (`learning/assessment/PlacementTest.kt`)

`classes15.txt:1140-4216`.

### 7.1 Банк питань

`questions` — **статичний список із 12 питань** (`classes15.txt:3118-3119`,
`classes15.txt:3199`: `const/16 v0, #int 12`, `new-array`).

`Question` поля (дескриптор у `classes15.txt:1171+`, порядок з `d2` і з
`invoke-direct ... Question;.<init>`):

| # | Поле | Тип | Примітка |
| --- | --- | --- | --- |
| 0 | `id` | `String` | `"pt_01"` … `"pt_12"` |
| 1 | `kind` | `ExerciseKind` | `MULTIPLE_CHOICE`, `SENTENCE_BUILD`, `FILL_GAP`, `LISTENING`, `TRANSLATION_UK_ES` |
| 2 | `level` | `Level` | `A0` (1 шт.), `A1` (7 шт.), `A2` (4 шт.) |
| 3 | `promptUk` | `String` | текст завдання |
| 4 | `options` | `List<String>?` | для `MULTIPLE_CHOICE`/`FILL_GAP`/`LISTENING` |
| 5 | `answerIndex`/`correctOptionIndex` | `Int` | індекс правильної опції |
| 6 | `expectedText` | `String?` | для `SENTENCE_BUILD`/`TRANSLATION_UK_ES` |
| 7 | `heardsEs` | `List<String>?` | для `LISTENING` |
| 8 | `tag` | `GrammarTag` | `POLITE`, `SER_ESTAR`, `GUSTAR`, `PERIPHRASIS`, `PREPOSITIONS`, `IR_A_INFINITIVE`, `PRETERITE`, `PERFECT`, `TIME_EXPRESSIONS` |
| 9 | `weight` | `Int` | див. нижче |
| 10 | `explanationUk` | `String` | |

**Точні ваги (`weight`)** видно як аргумент `const/16 vXX, #int N` у кожному виклику:

| id | level | weight (десятковий) | weight (hex у smali) | smali |
| --- | --- | --- | --- | --- |
| `pt_01` | A0 | `1` | `const/4 v12, #int 1` | `classes15.txt:3264` |
| `pt_02` | A1 | `2` | `#1190` = `0x1190` = `4496` → див. маску | `classes15.txt:3300` |
| `pt_03` | A1 | — | — | — |
| `pt_04` | A1 | — | — | — |
| `pt_05` | A1 | `3` | `const/16 v49, #int 3` | `classes15.txt:3385` |
| `pt_06` | A1 | `3` | `const/16 v33, #int 3` | `classes15.txt:3418` |
| `pt_07` | A1 | `0` | `masks only` | `classes15.txt:3451` |
| `pt_08` | A1 | `0` | | `classes15.txt:3493` |
| `pt_09` | A1 | `4` | `const/16 v33, #int 4` | `classes15.txt:3535` |
| `pt_10` | A2 | `5` | `const/16 v33, #int 5` | `classes15.txt:3569` |
| `pt_11` | A2 | `0` | | `classes15.txt:3591` |
| `pt_12` | A2 | `0` | | `classes15.txt:3625` |

> У рядках `const/16 vXX, #int 4496 // #1190` значення `0x1190` — це **маска
> `DefaultConstructorMarker`** (`0x1000 | 0x190`), а не `weight`. Реальний `weight`
> у цих викликах передається як `const/16 vXX, #int N` у позиції 9-го аргументу.
> Через це точні `weight` для `pt_02`–`pt_04`, `pt_07`, `pt_08`, `pt_11`, `pt_12`
> **не вдалося прочитати безпечно** — див. [12.7](#127-точні-weight-питань-placementtest).
>
> Практичний висновок для порту: **`percent` залежить лише від сум ваг, а `level`
> визначається за `byLevel`-відсотком, тому достатньо відтворити ваги точності
> до `1`.** Рекомендація: взяти `weight = level.ordinal + 1` (A0→1, A1→2, A2→3)
> **не** підтверджено; надійніше — витягнути `weight` із 9-ї позиції кожного
> `invoke-direct ... Question;.<init>` у `classes15.txt:3199-3626`.

### 7.2 `evaluate(answers: Map<String, Boolean>): TestResult`

`classes15.txt:3784-4076`. **Псевдокод (точний):**

```
score = 0                 // v1
maxScore = 0              // v2
byLevelPoints = LinkedHashMap<Level, Pair<Int,Int>>()   // (correct, total)

for (q in questions) {
    correct   = (answers[q.id] == true)
    maxScore += q.weight
    if (correct) score += q.weight

    val (c, t) = byLevelPoints[q.level] ?: (0 to 0)
    byLevelPoints[q.level] = (c + (if (correct) q.weight else 0)) to (t + q.weight)
}

percent = if (maxScore == 0) 0 else (score * 100) / maxScore     // цілочисельне

// ---- вибір рівня: найвищий MVP-рівень, де >= 60% ----
level = null
for (lvl in Level.mvpLevels.reversed()) {          // A2, A1, A0
    val (c, t) = byLevelPoints[lvl] ?: (0 to 0)
    if (t > 0 && (c * 100) / t >= 60) { level = lvl; break }
}
if (level == null) level = Level.A0

// ---- відсотки за рівнями (тільки MVP-рівні, бо ключі — з questions) ----
byLevel: Map<Level, Int> = byLevelPoints.mapValues { (_, v) ->
    if (v.second == 0) 0 else (v.first * 100) / v.second
}

// ---- слабкі теми ----
wrongTags = questions.filter { answers[it.id] != true }.map { it.tag }.distinct()

return TestResult(score, maxScore, percent, level, byLevel, wrongTags)
```

Докази:
* цикл по `questions`, `answers[q.id] == true`, `+= weight`: `classes15.txt:3793-3871`.
* `percent`: `classes15.txt:3873-3878` (`if-nez v2` → `0`, інакше `v1*100/v2`).
* `Level.mvpLevels` + `listIterator(size)` + `hasPrevious`/`previous`
  (**зворотний** порядок): `classes15.txt:3879-3928`.
* поріг `60`: `const/16 v9, #int 60 // #3c`, `if-lt v15, v9` (`classes15.txt:3918-3920`).
* умова `t > 0` (`if-lez v13, 00ec`): `classes15.txt:3915`.
* fallback `A0`: `classes15.txt:3929-3933` (`if-nez v7` → `sget-object Level.A0`).
* `byLevel`: `classes15.txt:3940-4000` (мапа `(1..2)`, ділення `c*100/t`, `0` якщо `t==0`).
* `wrongTags`: `classes15.txt:4004-4070` — `filter { answers[it.id] != true }.map { it.tag }.distinct()`.
* конструктор: `classes15.txt:4071-4075` `TestResult(score, maxScore, percent, level, byLevel, wrongTags)`.

### 7.3 `TestResult` (data-клас)

Поля (дескриптор `(IIILua/krupa/spanish/domain/model/Level;Ljava/util/Map;Ljava/util/List;)V`,
`classes15.txt:2481`, і `locals` там же):

| # | Поле | Тип |
| --- | --- | --- |
| 0 | `score` | `Int` |
| 1 | `maxScore` | `Int` |
| 2 | `percent` | `Int` |
| 3 | `level` | `Level` |
| 4 | `byLevel` | `Map<Level, Int>` |
| 5 | `wrongTags` | `List<GrammarTag>` |

Обчислювані властивості:

**`weakAreasUk: String`** (`classes15.txt:2921-2960`):

```
wrongTags
  .takeIf { it.isNotEmpty() }
  ?.joinToString(separator = ", ") { it.titleUk.lowercase(Locale.ROOT) }
  ?: ""
```
(`joinToString$default` з `const/16 v9, #int 30` — це **не** `limit`, а пакування
`default`-бітів; реальні значення: separator `", "`, решта — дефолти.)

**`recommendationUk: String`** (`classes15.txt:2822-2899`):

```
if (percent >= 85) "Чудовий старт. Починаємо з рівня " + level.code +
                   " — матеріал буде посильним, але не нудним."
else if (percent >= 60) "Хороший результат. Стартуємо з рівня " + level.code +
                        " і швидко закриємо прогалини."
else if (percent >= 35) "Основа є. Почнемо з рівня " + level.code +
                        " і приділимо більше уваги слабким темам."
else "Почнемо з самого початку — це нормально: так фундамент буде міцним."
```
Пороги: `85` (`const/16 v1, #int 85 // #55`), `60` (`#3c`), `35` (`#23`)
(`classes15.txt:2833`, `2852`, `2871`).

---

## 8. `LessonBuilder` — побудова сесії (`learning/session/LessonBuilder.kt`)

`classes8.txt:7180-11305`. Залежності: `courses: CourseRepository`,
`database: AppDatabase`, `srs: SrsEngine`, `mistakes: MistakeTracker`.

### 8.1 Константи та `LessonBuilderKt`

| Назва | Значення | Примітка | smali |
| --- | --- | --- | --- |
| `LessonBuilder.SLOW_RESPONSE_MS` | `12000L` | поріг «повільної» відповіді | `classes8.txt:7196-7202` |
| `getNewWordsPerSession()` | `8` | нових слів на сесію | `classes8.txt:7477-7495` |
| `REVIEW_EXERCISE_KINDS` | `[TRANSLATION_ES_UK, TRANSLATION_UK_ES, LISTENING, SPEAKING]` | для повторювальних вправ | `classes8.txt:11311-11325` |
| `hasHints(item: ListeningItem)` | `item.keyWords.isNotEmpty()` | | `classes8.txt:11379-11400` |

### 8.2 `ActivityAllocation.forMinutes(minutes: Int)`

`classes8.txt:5051-5216` + сам data-клас `classes8.txt:5216-5942`.
Поля (порядок із `ActivityAllocation;.<init>:(IIIIIIIIII)V`, `classes8.txt:5672`):

| # | Поле | Тип |
| --- | --- | --- |
| 0 | `reviewMinutes` | `Int` |
| 1 | `newWordsMinutes` | `Int` |
| 2 | `grammarMinutes` | `Int` |
| 3 | `exerciseMinutes` | `Int` |
| 4 | `listeningMinutes` | `Int` |
| 5 | `speakingMinutes` | `Int` |
| 6 | `exerciseItems` | `Int` |
| 7 | `listeningItems` | `Int` |
| 8 | `speakingItems` | `Int` |
| 9 | `grammarItems` | `Int` |

> Порядок полів **уточнити** за `@Metadata d2` класу `ActivityAllocation`
> (`classes8.txt:5216`). Назви видно в `strings_by_class.txt:3667-3677`:
> `reviewMinutes, exerciseItems, exerciseMinutes, grammarMinutes, listeningItems,
> listeningMinutes, newWordsMinutes, speakingItems, speakingMinutes` —
> це **алфавітний** список рядків, а не порядок полів.

**Алгоритм `forMinutes(minutes)`** (`classes8.txt:5044-5120`, точні константи):

```
review    = max(3, (minutes * 0.25).toInt())        // 0x3fd0 = 0.25
newWords  = max(2, (minutes * 0.25).toInt())
grammar   = max(2, (minutes * 0.20).toInt())        // 0x3fc999999999999a = 0.2
listening = max(1, (minutes * 0.15).toInt())        // 0x3fc3333333333333 = 0.15
speaking  = max(1, (minutes * 0.10).toInt())        // 0x3fb999999999999a = 0.1
exercise  = max(2, minutes - review - newWords - grammar - listening - speaking)

speakingItems  = max(1, speaking / 2)
listeningItems = max(1, (speaking * 1.2).toInt())   // 0x3ff3333333333333 = 1.2
exerciseItems  = max(3, (exercise * 1.5).toInt())   // 0x3ff8 = 1.5
grammarItems   = ???  → див. нижче
```

`locals` у `forMinutes` (`classes8.txt:5113-5120`):
`reg=14 speaking I`, `reg=1 review I`, `reg=3 newWords I`, `reg=4 exercise I`,
`reg=15 grammar I`, `reg=16 listening I`.

Конструктор викликається з регістрами `v6=review, v7=newWords, v8=grammar, v9=exercise,
v10=listening, v11=speaking, v12=speakingItems?, v13=listeningItems?, v14=exerciseItems?`
(`classes8.txt:5101-5109`). `v12 = max(1, speaking/2)`, `v13 = max(1, (speaking*1.2).toInt())`,
`v2 = max(3, (exercise*1.5).toInt())`. Тобто **останні 4 поля — це
`exerciseItems`, `listeningItems`, `speakingItems`, `grammarItems`, але їх
точне зіставлення з `v12/v13/v2` потребує перевірки**; див.
[12.8](#128-порядок-полів-activityallocation).

### 8.3 `unlockedLevels(current: Level): List<Level>`

`classes8.txt:8192-8272`:

```
return Level.mvpLevels.filter { it.ordinal <= current.ordinal }.ifEmpty { listOf(Level.A0) }
```
(`if-gt v9, v10` → пропустити, якщо `it.ordinal > current.ordinal`;
`ifEmpty` → `listOf(Level.A0)`, `classes8.txt:8255-8261`.)

### 8.4 `adaptivePriority(card: CardState, now: Long): Double`

`classes8.txt:8272-8396`. **Точна формула:**

```
overdueDays   = if (card.dueAt < now) (now - card.dueAt).toDouble() / 86_400_000.0 else 0.0
overdueScore  = min(overdueDays, 61.0) / 61.0 * 25.0           // 0x403e = 61.0, 0x4039 = 25.0
lapseRate     = if (card.totalReviews == 0) 0.0
                else card.lapses.toDouble() / card.totalReviews
lapseScore    = 30.0 * lapseRate                                // 0x403e = 30.0
accuracyPenalty = (100 - card.accuracyPercent) * 0.25           // 0x3fd0 = 0.25
stateBonus    = when (card.phase) {
                  RELEARNING -> 5.0     // 0x4014
                  LEARNING   -> 10.0    // 0x4028
                  REVIEW     -> 20.0    // 0x4034
                  NEW        -> 0.0
                }
speedPenalty  = if (card.averageResponseMs > 12000L) 8.0 else 0.0   // 0x4020 = 8.0
return overdueScore + lapseScore + accuracyPenalty + stateBonus + speedPenalty
```

* `0x403e = 30.0`, `0x4039 = 25.0`, `0x4014 = 5.0`, `0x4028 = 12.0`,
  `0x4034 = 20.0`, `0x4020 = 8.0`, `0x3fd0 = 0.25`.
* `12000` — дослівно `const-wide/16 v18, #int 12000 // #2ee0` (`classes8.txt:8325`).
* `StateBonus` розкодовано з `$EnumSwitchMapping$0`
  (`classes8.txt:5993-6075`): `RELEARNING→1, LEARNING→2, REVIEW→3, NEW→4`
  (порядок ключів у таблиці `0x0053`: `key1→0x64` = `0.0`? — **див. нижче**).

  `packed-switch` у `adaptivePriority` (`classes8.txt:8314`, таблиця
  `classes8.txt:8377`): `size=4, first=1`, offsets: key1→`0x64`, key2→`0x61`,
  key3→`0x5e`, key4→`0x5c`. Гілки:
  * `0x005c`: `move-wide v14, v2` (`v2 = 0.0`) — `NEW → 0.0`
  * `0x005e`: `const-wide/high16 v14, #long … // #4014` — `5.0`
  * `0x0061`: `#4028` — `10.0`
  * `0x0064`: `#4034` — `20.0`

  З урахуванням мапінгу `WhenMappings` (`RELEARNING→1, LEARNING→2, REVIEW→3, NEW→4`):
  **NEW = 0.0, RELEARNING = 5.0, LEARNING = 10.0, REVIEW = 20.0.**

* `accuracyPercent` — властивість `CardState` (`getAccuracyPercent:()I`,
  `classes8.txt:8360`), дорівнює `retention(totalReviews, correctReviews)`.

### 8.5 `prioritize(cards, now, limit): List<CardState>`

`classes8.txt:11258-11305`:

```
return cards.sortedByDescending { adaptivePriority(it, now) }.take(limit)
```

### 8.6 `buildReason(dueCount: Int, newCount: Int, weakTags: List<GrammarTag>, level: Level): String`

`classes8.txt:7357-7477`. **Точний рядковий конкатенатор:**

```
"Рівень " + level.code + ". " +
  (if (dueCount > 0) "На повторення чекає $dueCount карток. "
   else             "Прострочених повторень немає. ") +
  (if (newCount > 0) "Додано $newCount нових слів. " else "") +
  (if (weakTags.isNotEmpty())
     "Посилена увага до тем: " + weakTags.joinToString(", ") { it.titleUk.lowercase(Locale.ROOT) } + "."
   else
     "Слабких тем поки не виявлено — йдемо за програмою.")
```

Рядкові константи — `strings_by_class.txt:3655-3666`. `joinToString` — той самий
патерн, що в `weakAreasUk`.

### 8.7 `pickNewWords(levels, knownWordIds, topics, limit): List<Word>`

`classes8.txt:7847-8192`.

```
topicOrder = topics.sortedBy { it.id }            // стабільний порядок за id
                   .mapIndexed { index, topic -> topic.id to index }
                   .toMap()

return levels
  .flatMap { level -> courses.wordsByLevel(level) }
  .filterNot { knownWordIds.contains(it.id) }
  .sortedWith(compareBy(
      { topicOrder[it.topicId] ?: Int.MAX_VALUE },   // невідома тема — в кінець
      { it.frequencyRank }                            // менший rank — раніше
  ))
  .take(limit)
```
Докази: `sortedBy { it.id }` + `mapIndexed` (`classes8.txt:7980-8060`),
`toMap` (`classes8.txt:8076`), `flatMap { wordsByLevel(it) }` (`classes8.txt:7955`),
`filterNot { knownWordIds.contains(it.id) }` (`classes8.txt:7990-8000`),
`compareBy([pickNewWords$4, pickNewWords$5])` (`classes8.txt:7920-7930`),
`pickNewWords$4` = `topicOrder[it.topicId] ?: Int.MAX_VALUE` (`classes8.txt:6866-6963`),
`take(limit)` (`classes8.txt:8020`).

> **`pickNewWords$5`** — друга лямбда компаратора. За `strings_by_class.txt:3692`
> вона містить лише `"it"`. За змістом і назвою поля `Word` це `it.frequencyRank`.
> Якщо в моделі `Word` такого поля немає — див. [12.9](#129-другий-ключ-сортування-в-picknewwords).

### 8.8 `pickGrammar(tags, levels, limit)`

`classes8.txt:7495-7847`:

```
val result = mutableListOf<GrammarNote>()
for (tag in tags) {
    courses.grammarByTag(tag)?.let { result += it }
}
if (result.isEmpty()) {
    val fallback = mutableListOf<GrammarNote>()
    for (level in levels) fallback += courses.grammarByLevel(level)
    result += fallback.sortedBy { ??? }.take(limit)
}
return result
```
`createListBuilder` (`classes8.txt:7568`), `grammarByTag` (`classes8.txt:7590`),
`isEmpty` (`classes8.txt:7632`), `grammarByLevel` (`classes8.txt:7676`),
`sortedWith(pickGrammar$lambda$40$$inlined$sortedBy$1)` (`classes8.txt:7720`),
`take(v5)` (`classes8.txt:7730`) де `v5` — це параметр `limit`.
Сортувальний ключ — `pickGrammar$lambda$40$$inlined$sortedBy$1`
(`classes8.txt:6595-6678`); **точний ключ не встановлено**, див.
[12.10](#1210-ключ-сортування-в-pickgrammar).

### 8.9 `buildReviewItems(dueCards, newWords): List<StudyItem>`

`classes8.txt:10406-11258`. **Точні кроки:**

```
1. all = (dueCards + newWords).distinctBy { it.itemType to it.itemId }.take(60)
   // const/16 v8, #int 60  (classes8.txt:8501)
2. wordCards = all.filter { it.itemType == "word" }.map { it.itemId }
   wordById   = courses.words(wordCards).associateBy { it.id }
3. sentenceCards = all.filter { it.itemType == "sentence" }.map { it.itemId }
   sentenceById   = courses.sentences(sentenceCards).associateBy { it.id }
4. listeningCards = all.filter { it.itemType == "listening" } → courses.listening(...)
   listeningById  = ...
5. result = mutableListOf<StudyItem>()
   for (card in all) {
       when (card.itemType) {
         "exercise" -> courses.exercise(card.itemId)?.let { result += ExerciseItem(it) }
         "sentence" -> sentenceById[card.itemId]?.let { result += SentenceItem(it) }
         "word"     -> wordById[card.itemId]?.let { result += WordItem(it, isNew = false) }
         "listening"-> ... ListeningItemRef(...)
         else       -> null   // пропускається
       }
   }
6. return result
```

Докази:
* `plus(dueCards, newWords)` (`classes8.txt:8544`), `distinctBy { itemType to itemId }`
  (`classes8.txt:8558-8576`), `take(60)` (`classes8.txt:8501`, `const/16 v8, #int 60 // #3c`).
* розбиття за `itemType` на три списки (`"word"`, `"sentence"`, `"listening"`)
  (`classes8.txt:8578-8640`, `const-string v5/v6/v7` = `classes8.txt:10301-10305`).
* `courses.words(ids)` → `associateBy { it.id }` (`classes8.txt:8680-8700`),
  `courses.sentences(ids)` → `associateBy { it.id }` (`classes8.txt:8725-8745`).
* `sparse-switch` на `itemType.hashCode()` (`classes8.txt:8733-8736`):
  `"exercise"` → `ExerciseItem` (`classes8.txt:8765-8770`),
  `"sentence"` → `SentenceItem` (`classes8.txt:8786-8790`),
  `"word"` → `WordItem(word, **false**)` (`classes8.txt:8747-8750`,
  `const/4 v10, #int 0` → `isNew = false`), `else` → `null` (пропуск).
* `StudyItem`-підтипи: `ExerciseItem(Exercise)`, `GrammarItem(GrammarNote)`,
  `ListeningItemRef(ListeningItem)`, `SentenceItem(Sentence)`,
  `WordItem(Word, Boolean isNew)` (`classes8.txt:41038-42200`).

### 8.10 `buildPlan(profile, minutes, now): SessionPlan`

`classes8.txt:8396-10407` (state machine корутини; реальний код — `0x0250`…`0x095e`).
**Відновлений алгоритм:**

```
1.  levels = unlockedLevels(profile.level)                       // 0x027b
2.  levelCodes = levels.map { it.code }                          // 0x029f
3.  dueCards  = srs.dueCards(limit = 120, now)                   // 0x02c0, const/16 v10, #int 120 // #78
4.  weakCards = srs.weakest(limit = 20)                          // 0x02de, const/16 v9, #int 20 // #14
5.  weakOnly  = weakCards.filter { w -> dueCards.none { it.itemId == w.itemId } }
                                                                  // 0x02f9-0x0355
6.  weakTags  = mistakes.tagsNeedingPractice(limit = 4)           // 0x0379, const/4 v9, #int 4
7.  allCards  = srs.allCards()                                    // 0x039b
8.  knownWordIds = allCards.filter { it.itemType == "word" }
                            .map { it.itemId }.toSet()            // 0x03ad-0x0411
9.  topics    = courses.topics()                                  // 0x0431
10. newWords  = pickNewWords(levels, knownWordIds, topics, limit = getNewWordsPerSession() /* 8 */)
                                                                  // 0x0442-0x046c
11. newItems  = newWords.map { StudyItem.WordItem(it, isNew = true) }   // 0x066b-0x0692
12. grammarNotes = pickGrammar(newWords.flatMap { it.grammarTags }, levels, limit = ??)
                                                                  // 0x06b6
13. grammarItems = grammarNotes.map { StudyItem.GrammarItem(it) } // 0x06ee-0x0710
14. levelExercises = courses.exercisesByLevel(profile.level)      // 0x0742
15. exercisePool   = levelExercises + weakTagExercises
      де weakTagExercises = weakTags.flatMap { tag ->
             exerciseByTag[tag] = courses.exercisesByTag(tag) }   // 0x04dc
      (exerciseByTag — LinkedHashMap, ключ = weakTags-елемент, значення = List<Exercise>;
       потім `values.flatten()` + dedup за exercise.id)           // 0x0517-0x0551
16. exercisePool  += exercisesByLevel(level)                      // 0x0756
17. dedup: розгортання `exercisePool` з HashSet за `Exercise.id`  // 0x076f-0x07ab
18. exerciseItems = dedup
      .sortedByDescending { weakTags.contains(it.grammarTag) }    // 0x07ba-0x07c4
      .take(allocation.exerciseItems)                             // 0x07c7-0x07cb
19. listeningPool  = courses.listeningByLevel(level) для level in levels.reversed()
                                                                  // 0x0555-0x05ca
20. listeningItems = listeningPool.take(allocation.listeningItems)
      .map { StudyItem.ListeningItemRef(it) }                     // 0x0814-0x0848
21. speakingPool   = courses.exercisesByKind(Speaking, levels)    // 0x0607
22. speakingItems  = speakingPool.take(allocation.speakingItems)
      .map { StudyItem.ExerciseItem(it) }                         // 0x085c-0x088d
23. reviewItems    = buildReviewItems(dueCards, newItems)         // 0x063c
24. allocation     = ActivityAllocation.forMinutes(minutes)       // 0x061e
25. blocks (у ЦЬОМУ порядку):
      REVIEW     { allocation.reviewMinutes    } items = reviewItems
      NEW_WORDS  { allocation.newWordsMinutes  } items = newItems
      GRAMMAR    { allocation.grammarMinutes   } items = grammarItems
      EXERCISES  { allocation.exerciseMinutes  } items = exerciseItems
      LISTENING  { allocation.listeningMinutes } items = listeningItems
      SPEAKING   { allocation.speakingMinutes  } items = speakingItems
                                                                  // 0x089d-0x0906
26. blocks = blocks.filter { it.items.isNotEmpty() }              // 0x0915-0x093b
27. totalMinutes   = dueCards.size + newItems.size                // 0x0947-0x0952 (v12.size + v6.size)
28. reasonUk       = buildReason(dueCards.size, newItems.size, weakTags, profile.level)   // 0x0955
29. return SessionPlan(totalMinutes, blocks, reasonUk)            // 0x095b
```

Докази:
* `dueCards(120, now)` — `const/16 v10, #int 120 // #78` (`classes8.txt:8788`).
* `weakest(20)` — `const/16 v9, #int 20 // #14` (`classes8.txt:8806`).
* `tagsNeedingPractice(4)` — `const/4 v9, #int 4` (`classes8.txt:8892`).
* `unlockedLevels` → `map { it.code }` (`classes8.txt:8766-8774`).
* `allCards` → `filter { itemType == "word" }` → `map { itemId }` → `toSet()`
  (`classes8.txt:8914-8980`; `const-string v12, "word"` — `classes8.txt:8938`).
* `topics()` (`classes8.txt:9042`), `getNewWordsPerSession()` (`classes8.txt:8835`),
  `pickNewWords(levels, knownWordIds, topics, 8)` (`classes8.txt:8855`).
* `courses.exercisesByLevel(profile.level)` (`classes8.txt:8841-8852`).
* `courses.exercisesByTag(tag)` у циклі по `weakTags` (`classes8.txt:8800-8820`).
* `values.flatten()` (`classes8.txt:8858`), `reversed()` для `levels`
  (`classes8.txt:8880`), `listeningByLevel` (`classes8.txt:8899`),
  `exercisesByKind(Speaking, ...)` (`classes8.txt:8977`).
* `sortedByDescending { weakTags.contains(it.grammarTag) }`
  (`classes8.txt:9520-9524` + лямбда `classes8.txt:6074-6130`).
* `take(allocation.getExerciseItems())` (`classes8.txt:9525-9530`).
* блоки — `classes8.txt:9640-9720`, `filter { items.isNotEmpty() }` — `classes8.txt:9700-9720`.
* `totalMinutes = reviewItems.size + newItems.size` — `classes8.txt:9700-9706`
  (`invoke-interface {v12}, List.size()`, `invoke-interface {v6}, List.size()`,
  потім `SessionPlan(v3, v0, v2)`).
* `SessionPlan` поля: `totalMinutes: Int`, `blocks: List<SessionBlock>`, `reasonUk: String`
  (`classes8.txt:12215-12704`; `strings_by_class.txt:3728-3735`).
* `SessionBlock` поля: `kind: SessionBlockKind`, `minutes: Int`, `titleUk: String`,
  `items: List<StudyItem>` (`classes8.txt:11421-11824`;
  `strings_by_class.txt:3698-3706`).

> **`weekTagExercises` / кеш `exerciseByTag`** реалізовано як
> `LinkedHashMap<GrammarTag, List<Exercise>>` зі `mapCapacity(...).coerceAtLeast(16)`
> (`classes8.txt:8858-8900`). На результат не впливає (порядок ключів = порядок
> `weakTags`).

---

## 9. `ProgressRepositoryImpl` — метрики прогресу (`data/repository/ProgressRepositoryImpl.kt`)

`classes11.txt:7930-10133`.

### 9.1 Константи

| Назва | Тип | Значення | smali |
| --- | --- | --- | --- |
| `MEMORIZED_INTERVAL_DAYS` | `Double` | `21.0` | `classes11.txt:7947-7952` |

### 9.2 `ProgressSnapshot` — усі метрики

Поля (дескриптор конструктора, `classes11.txt:8804-8831`:
`(Level;IIIIIIIIIIIIIIIJIIILjava/util/List;Ljava/util/List;Ljava/util/List;Ljava/util/List;)V`
плюс `@Metadata d2` у `classes8.txt:1713`):

| # | Поле | Тип | Формула / джерело |
| --- | --- | --- | --- |
| 0 | `level` | `Level` | параметр |
| 1 | `levelPercent` | `Int` | `coerceIn( (reviewCoverage*0.75 + mistakePractice*0.25).toInt(), 0, 100 )` |
| 2 | `wordsTotal` | `Int` | параметр |
| 3 | `wordsStarted` | `Int` | `allCards.count { it.totalReviews > 0 }` |
| 4 | `wordsMemorized` | `Int` | `wordCards.count { it.intervalDays >= 21.0 }` |
| 5 | `newWordsAvailable` | `Int` | `coerceAtLeast(grammarNotesTotal - wordsStarted, 0)` |
| 6 | `grammarNotesTotal` | `Int` | параметр |
| 7 | `grammarLearned` | `Int` | `cards.count { it.levelCode == level.code && it.phase != NEW }` |
| 8 | `totalMinutes` | `Int` | `dailyStats.sumOf { it.minutes }` |
| 9 | `todayMinutes` | `Int` | `today?.minutes ?: 0` |
| 10 | `todayReviews` | `Int` | `today?.reviews ?: 0` |
| 11 | `todayNewWords` | `Int` | `today?.newWords ?: 0` |
| 12 | `dueNow` | `Int` | `cards.count { !it.suspended && it.dueAt <= now }` |
| 13 | `reviewCount` | `Int` | `cards.sumOf { it.totalReviews }` |
| 14 | `streakDays` | `Int` | `calculateStreak(dailyStats)` |
| 15 | `retentionPercent` | `Int` | `SrsScheduler.retention(reviewCount, correctReviews)` |
| 16 | `averageResponseMs` | `Long` | `cards.filter { it.averageResponseMs > 0 }.map { it.averageResponseMs }.average().takeIf { !it.isNaN() }?.toLong() ?: 0L` |
| 17 | `speakingAttempts` | `Int` | `dailyStats.sumOf { it.speakingAttempts }` |
| 18 | `listeningMinutes` | `Int` | `dailyStats.sumOf { it.listeningMinutes }` |
| 19 | `exercisesDone` | `Int` | `dailyStats.sumOf { it.exercisesDone }` |
| 20 | `weakSpots` | `List<WeakSpot>` | див. 9.3 крок 11 |
| 21 | `topicProgress` | `List<TopicProgressEntity>` | параметр |
| 22 | `dailyStats` | `List<DailyStatEntity>` | параметр |
| 23 | `mistakeStats` | `List<MistakeStatEntity>` | параметр |

Обчислювані властивості (`@Metadata d2`, `classes8.txt:1713`):

* `canRecallWords: Int` — **увага**: за `d2` це `getCanRecallWords:()I`, тобто `Int`.
* `formattedAverageResponse: String` — форматує `averageResponseMs`.
* `weakestSpotTitle: String?` — `weakSpots.firstOrNull()?.titleUk`.

**Доказова база формул** (`buildSnapshot`, `classes11.txt:8074-9163`):

* `wordsStarted`: `filter { totalReviews > 0 }` → `.count` (`classes11.txt:8207-8222`).
* `wordsMemorized`: `filter { intervalDays >= 21.0 }` → `.count` (`classes11.txt:8171-8181`).
* `grammarLearned`: `filter { levelCode == level.code && phase != NEW }` → `.count`
  (`classes11.txt:8368-8429`).
* `reviewCount` / `correctReviews`: `sumOf { totalReviews }` (`classes11.txt:8225-8242`),
  `sumOf { correctReviews }` (`classes11.txt:8243-8260`).
* `averageResponseMs`: `filter { averageResponseMs > 0 }` → `map { averageResponseMs }`
  → `averageOfLong` → `isNaN` guard → `double-to-long` (`classes11.txt:8262-8346`).
* `levelPercent`: `reviewCoverage = if (totalWeight == 0) 0 else (learnedWeight*100)/totalWeight`
  (`classes11.txt:8397-8435`); `mistakePractice = if (weakTagsTotal == 0) 0 else
  coerceIn(weakTagCount*100/weakTagsTotal, 0, 100)` (`classes11.txt:8436-8489`);
  `(reviewCoverage * 0.75 + mistakePractice * 0.25).toInt()` з
  `0x3fe8 = 0.75` і `0x3fd0 = 0.25` (`classes11.txt:8492-8503`).
* `weakSpots`: `mistakeStats.filter { attempts >= 3 }.map { WeakSpot(tag, it, mastery(it)) }`
  → `.sortedBy { it.mastery }`.take(5) (`classes11.txt:8504-8602`;
  `const/4 v4, #int 3` — `classes11.txt:8476`; `const/4 v2, #int 5` — `classes11.txt:8600`).
* `newWordsAvailable = coerceAtLeast(grammarNotesTotal - wordsStarted /* v29 */, 0)`
  (`classes11.txt:8610-8613`).
* `totalMinutes`: `dailyStats.sumOf { it.minutes }` (`classes11.txt:8670-8683`).
* `todayMinutes/todayReviews/todayNewWords`: `today ?: 0` (`classes11.txt:8685-8702`).
* `dueNow`: `filter { !suspended && dueAt <= now }` → `.count` (`classes11.txt:8703-8741`).
* `streakDays = calculateStreak(dailyStats)` (`classes11.txt:8743`).
* `retentionPercent = SrsScheduler.retention(reviewCount, correctReviews)`
  (`classes11.txt:8745-8747`).
* `speakingAttempts` / `listeningMinutes` / `exercisesDone` — три `sumOf`
  (`classes11.txt:8749-8799`).
* `"today"` — `dailyStats.firstOrNull { it.dayEpoch == UserRepository.todayEpoch(now) }`
  (`classes11.txt:8096-8115`); `now = System.currentTimeMillis()` (`classes11.txt:8085`).

### 9.3 `calculateStreak(stats: List<DailyStatEntity>): Int`

`classes11.txt:9163-9385`. **Псевдокод:**

```
if (stats.isEmpty()) return 0

activeDays = stats
  .filter { it.reviews > 0 || it.exercisesDone > 0 || it.minutes > 0 || it.newWords > 0 }
  .map { it.dayEpoch }
  .toSortedSet().toList().sortedDescending()      // унікальні дні, від найновішого

if (activeDays.isEmpty()) return 0

today     = UserRepository.todayEpoch(now)         // локальна північ
yesterday = today - 86_400_000L

if (activeDays.first() != today && activeDays.first() != yesterday) return 0

streak = 1
cursor = activeDays.first()
for (day in activeDays.drop(1)) {
    val diff = cursor - day                         // > 0, бо список спадний
    if (diff == 86_400_000L) { streak++; cursor = day }
    else if (diff > 86_400_000L) break
    // diff < дня (дублікат/однакова дата) — продовжуємо без інкременту
}
return streak
```

Докази: `filter` (`classes11.txt:9184-9211`), `toSortedSet` + `toList` +
`sortedDescending` (`classes11.txt:9245-9254`), перевірка `first() == today || first() == yesterday`
(`classes11.txt:9261-9286`), цикл `drop(1)` і порівняння з `86400000L`
(`classes11.txt:9287-9322`).

> `todayEpoch(now)`: `Calendar.getInstance()` → `setTimeInMillis(now)` →
> `set(HOUR_OF_DAY, 0)`, `set(MINUTE, 0)`, `set(SECOND, 0)`, `set(MILLISECOND, 0)`
> → `getTimeInMillis()` (`classes8.txt:3657-3690`). Це **локальна** північ.

### 9.4 `snapshot()` / `reviewForecast()` / `observeSnapshot()`

* `snapshot()` — `classes11.txt:9749-10133`: збирає `allCards`, `dailyStats(limit?)`,
  `mistakeStats`, `topicProgress`, `profile.level`, кількість слів/граматики з
  `ContentDao`, і викликає `buildSnapshot(level, cards, dailyStats, mistakeStats, topicProgress, grammarTotal, wordsTotal)`.
  Параметри `buildSnapshot` (`classes11.txt:8074-8082`):
  `(Level, List, List, List, List, I, I)` — два останні `Int` це
  `grammarNotesTotal` і `wordsTotal` (використані як `v7` і `v51`).
* `reviewForecast()` — `classes11.txt:9561-9749`: групує картки за днем
  `dueAt` (`groupingBy`), повертає `Map<Long, Int>` (кількість на день).
* `observeSnapshot()` — `classes11.txt:9473-9561`: `combine` потоків
  (`observeCards`, `observeDailyStats`, `observeMistakeStats`, `observeTopicProgress`,
  `observeProfile`) → `buildSnapshot`.

---

## 10. Спільні утиліти

### 10.1 `UserRepository.todayEpoch(now)` — локальна північ

`classes8.txt:3657-3690`. Описано в 9.3.

### 10.2 `Level.mvpLevels` — «MVP» рівні

`[A0, A1, A2]`. Використовується в `unlockedLevels` та `PlacementTest.evaluate`.

### 10.3 `SrsScheduler.dueAt` та інваріант «`intervalMinutes` має приоритет»

Якщо `intervalMinutes > 0`, `intervalDays` **ігнорується**. Це ключова поведінка:
картки у `LEARNING`/`RELEARNING` мають `intervalMinutes = 10`, а `intervalDays`
може залишатися старим (наприклад `2.5` з `ensureCard`). Саме тому `dueAt`
дає «+10 хв», а не «+2.5 дні».

### 10.4 Усі рядкові ключі/теги, які використовуються як «магічні»

| Рядок | Де | Призначення |
| --- | --- | --- |
| `"new"`, `"learning"`, `"review"`, `"relearning"` | `CardEntity.stateCode`, SQL | стан картки |
| `"word"`, `"sentence"`, `"exercise"`, `"listening"` | `CardState.itemType`, `Lifecycle` | тип елемента |
| `"exercise"` | `MistakeEntryEntity.kindCode` (хардкод у `record`) | тип запису помилки |
| `"A0"`, `"A1"`, `"A2"`, `"B1"`, `"B2"` | `Level.code` | код рівня |
| `"pt_01"` … `"pt_12"` | `PlacementTest.Question.id` | id питання |
| `"review"`, `"new_words"`, `"grammar"`, `"exercises"`, `"listening"`, `"speaking"` | `SessionBlockKind.code` | тип блоку |
| `"Рівень "`, `". "`, `"На повторення чекає "`, `" карток. "`, `"Прострочених повторень немає. "`, `"Додано "`, `" нових слів. "`, `"Посилена увага до тем: "`, `", "`, `"Слабких тем поки не виявлено — йдемо за програмою."` | `buildReason` | текст причини |
| `"сьогодні"`, `"менш ніж за день"`, `"через "`, `" дн"`, `" міс"`, `" р"` | `humanInterval` | текст інтервалу |
| `"Не знаю"`, `"Пам'ятаю з труднощами"`, `"Знаю"`, `"Дуже добре"`, `"✕"`, `"~"`, `"✓"`, `"★"` | `Grade` | UI-підписи оцінок |

---

## 11. Чекліст переносу на Swift (порядок залежностей)

1. Enums `Grade`, `CardPhase`, `Level`, `SessionBlockKind` з **точними** `code`/`titleUk`/`value`.
2. `CardState` (struct, 20 полів) + `CardPhase.fromCode` з fallback на `.new`.
3. `SrsScheduler`: константи (3.1), `schedule` = `reviewInLearning`/`reviewInReview`
   з `speedFactor`, `dueAt`, `humanInterval`, `retention`, `strength`,
   `projectedEase`, `preview`. Обов'язково зберегти **цілочисельні** ділення
   (`(average*3 + r)/4`, `c*100/t`, `coerceIn` порядку).
4. `SrsEngine`: `review` (кроки 4.3), `ensureCard` (4.6), `memorizedCount` (4.5),
   SQL-контракти вибірок (4.1) — у Core Data / SQLite повторити `ORDER BY` дослівно.
5. `AnswerCheck.normalize`/`compare`/`compareAny` (5.2–5.4) — з `Locale(identifier: "en_US_POSIX")`
   замість `Locale.ROOT` і **без** accent-folding.
6. `MistakeTracker`: `record` (6.3), `mastery` (6.4), `tagsNeedingPractice` (6.6),
   `weakestTags` (6.7).
7. `PlacementTest`: 12 питань з вагами, `evaluate` (7.2), `TestResult` (7.3).
8. `LessonBuilder`: `unlockedLevels`, `adaptivePriority`, `prioritize`, `pickNewWords`,
   `pickGrammar`, `ActivityAllocation.forMinutes`, `buildReviewItems`, `buildPlan`,
   `buildReason`.
9. `ProgressRepositoryImpl`: `buildSnapshot` (9.2), `calculateStreak` (9.3),
   `todayEpoch` (10.1).

---

## 12. Неоднозначності та два варіанти трактування

### 12.1 `intervalDays = 4.0` для нової картки

У `ensureCard` (`classes13.txt:17088-17096`) новий `CardEntity` отримує
`intervalDays` з `const-wide/high16 v29, #long 4612811918334230528 // #4004`.
`0x4004` = **2.5**, `0x4010` = **4.0** — я перевірив обидва значення.
У тілі є **дві** такі константи (`#4004` і `#4010`), і я не зміг з абсолютною
впевненістю визначити, яка саме йде в `intervalDays`, а яка — в `ease`.

* **Варіант A (імовірніший):** `intervalDays = 2.5`, `ease = 0.0`.
  Тоді `SrsScheduler.dueAt` для нової картки дасть `now + 2 доби`
  (`intervalMinutes == 0`, `intervalDays > 0`), а `ease` «доросте» до `2.5`
  лише після перших рев'ю. Але `ease = 0.0` суперечить `INITIAL_EASE = 2.5`.
* **Варіант B:** `intervalDays = 0.0`, `ease = 2.5` (тобто `#4004` — це `ease`).
  Тоді `dueAt` для `NEW` = `now + 60_000` (1 хв), а `ease` стартує правильно.

**Рекомендація для порту:** реалізувати **Варіант B** (`intervalDays = 0.0`,
`ease = 2.5`, `intervalMinutes = 0`). Це узгоджується з `INITIAL_EASE = 2.5`,
з відсутністю будь-якого використання `intervalDays` до першого рев'ю, і з
тим, що `reviewInReview` робить `previous = max(intervalDays, 1.0)` — тобто
`0.0` і `2.5` дають **однаковий** результат `1.0` на першому повторенні.
Різниця виявляється лише в `dueAt` для щойно створеної картки (`0` → +1 хв,
`2.5` → +2 доби), а також у `memorizedCount` (поріг `21.0` — обидва варіанти
не проходять).

### 12.2 Параметр `contentVersion` vs `multi`

`SrsScheduler.review` має **два** `Int`-параметри після `responseMs`, які в
`locals` названі `contentVersion` (регістр `v19`/`v20` у `SrsEngine.review`,
`classes13.txt:19801-19820`) і `multi` (`v20` у `preview`, значення `24`).

* **Варіант A:** `review(state, grade, now, responseMs, contentVersion, multi)`.
  Тоді `SrsEngine.review` викликає `SrsScheduler.review(stored, grade, now,
  responseMs, contentVersion, 1)` — `contentVersion` записується у
  `CardState.contentVersion`, `multi = 1` (нейтральний множник), а `preview`
  передає `multi = 24`, щоб «попередні» картки відрізнялися (див. нижче).
* **Варіант B:** порядок зворотний: `review(state, grade, now, responseMs, multi,
  contentVersion)`. Тоді `contentVersion = 1` (завжди), а `multi = contentVersion`.

**Що видно точно:** у `SrsEngine.review` (крок 7, `classes13.txt:19872-19885`)
фінальний `copy` ставить `contentVersion = <параметр з сигнатури>`, і цей параметр
у дескрипторі `SrsEngine.review` стоїть **після** `cardId` (`J`) і **перед**
`Continuation`. У `locals` (`classes13.txt:19932-19942`) він названий `contentVersion`.
Тому: `multi` — **окремий, п'ятий за рахунком** параметр `SrsScheduler.review`,
значення якого `preview` ставить `24`, а `SrsEngine` — `1`.

**Рекомендація:** реалізувати **Варіант A**. Для `preview` значення `multi = 24`
на практиці не впливає на результат `review` (усі гілки використовують лише
`now`, `responseMs` і сам `state`), тому його можна сміливо ігнорувати або
прокидати як є.

### 12.3 Гілка `AGAIN` у `reviewInLearning`

Гілка `0x01d9` (`classes13.txt:20677-20706`) містить `const-wide/32 v0, #float 8.40779e-41 // #000927c0`
(= `600000`, тобто **10 хв**) у гілці `EASY`/`0x0097`, і `#0000ea60` (= `60000`,
**1 хв**) у гілці `HARD`/`0x00d0`… але `locals` і порядок регістрів допускають
два прочитання того, у який саме слот `copy` потрапляє сума.

* **Варіант A:** `AGAIN` у навчанні = `dueAt = now + 60_000` (1 хв),
  `phase = LEARNING`, `intervalMinutes = 0`, `ease = max(1.3, ease − 0.15)`.
  Це відповідає назві константи `AGAIN_STEP_MINUTES = 1` (3.1) — хоч вона й
  «не використовується в `schedule`», число `1` тут фігурує.
* **Варіант B:** `intervalMinutes = 1`, `dueAt = now` (тобто крок передається
  через `intervalMinutes`, а `dueAt` перерахує `SrsEngine.dueAt` → `now + 1 хв`).
  Результат **еквівалентний** варіанту A після `SrsEngine.review`, але
  відрізняється в `preview` (де `dueAt` не перераховується).

**Рекомендація:** реалізувати `AGAIN` у навчанні як
`phase = .learning, intervalMinutes = 1, dueAt = now + 60_000` — це безпечно
за обох трактувань (обидва дають однаковий `dueAt`).

### 12.4 `GOOD` і `EASY` у `reviewInReview` — обидві ведуть в одну гілку

Таблиця `0x011e` дає `GOOD → 0x01f7` і `EASY → 0x01f7` — одна й та сама гілка.
Але всередині гілки є **дві** різні операції над ease:

* `add-double/2addr v7, v4` де `v7 = 0.15` (`classes13.txt:21029`) → `+0.15`
* `sub-double v2, v4, v2` де `v2 = 0.15` (`classes13.txt:21046`) → `−0.15`

* **Варіант A:** `GOOD → +0.15` (cap `2.8`), `EASY → −0.15` (floor `1.3`),
  обидві з `intervalDays = previous * ease * 1.25`. Це те, що видно з порядку
  інструкцій і збігається з `projectedEase` (3.6), де `EASY → ease − 0.2`,
  `GOOD → ease − 0.15`. **АЛЕ** в `projectedEase` знаки **протилежні** до
  `reviewInReview` — тобто `projectedEase` використовується лише для UI-прогнозу
  і **не** збігається з фактичним ease після рев'ю.
* **Варіант B:** `GOOD → +0.15`, `EASY → −0.15`, але `EASY` додатково
  помножує інтервал на `EASY_BONUS = 1.25`, а `GOOD` — ні.

**Рекомендація:** реалізувати **Варіант A**, але **НЕ** використовувати
`projectedEase` для показу «майбутнього ease» в UI — він розходиться з
фактичною поведінкою `review`. Для UI-прогнозу інтервалів використовувати
`SrsScheduler.preview` (3.13), який викликає справжній `review`.

### 12.5 Точний формат `describeInterval`

Метод читає `after.intervalMinutes` і або формує рядок самостійно, або делегує в
`humanInterval(after.intervalDays)`. Рядкові константи класу містять `"<1 дн"`,
`">1 р"`, `" хв"`, `" дн"`, `" міс"`, `" р"`, `"менш ніж за день"`, `"сьогодні"`.

* **Варіант A:** `describeInterval` повертає `humanInterval(...)`, а рядки
  `"<1 дн"` / `">1 р"` належать іншому методу цього ж файлу (наприклад,
  форматуванню граничних випадків `intervalDays == 0.0` та `>= 365.0`).
* **Варіант B:** `describeInterval` сам повертає `"<1 дн"` для
  `intervalMinutes in 1..1439` і `">1 р"` для `intervalDays >= 365`, а
  `humanInterval` викликається лише для «середніх» значень.

**Рекомендація:** реалізувати **Варіант A** (лише делегування в `humanInterval`),
і додатково продублювати рядки `"<1 дн"`/`">1 р"` як «мертві» константи —
вони не вплинуть на UI. Якщо в дизайні є окремі підписи «<1 дн» — додати гілки
за варіантом B.

### 12.6 Коли саме записується `contentVersion`

`SrsEngine.review` (крок 7) ставить `contentVersion` **після** `upsertCard`.
Тому в БД зберігається `contentVersion` = `0` (або попередній), а в UI —
новий.

* **Варіант A (як у smali):** `contentVersion` у БД і в UI розходяться на 1 рев'ю.
  Це може бути навмисним: `contentVersion` зчитується з БД для виявлення
  застарілого контенту, і затримка на 1 рев'ю нешкідлива.
* **Варіант B:** насправді `upsert` викликається з `toEntity(next)` **після**
  `copy(contentVersion = ...)`, і порядок у smali — лише ефект корутинного
  state machine.

**Рекомендація:** реалізувати **Варіант A** дослівно (upsert зі старим
`contentVersion`, повернути новий). Задокументувати в коді як відому розбіжність.

### 12.7 Точні `weight` питань `PlacementTest`

У `classes15.txt:3199-3626` кожне питання конструюється через 16-аргументний
`Question.<init>` з `DefaultConstructorMarker`. Позиція `weight` — 9-та (індекс 9),
але частина аргументів передається через маску, і `const/16 vXX, #int 4496 // #1190`
є **маскою**, а не `weight`.

* **Варіант A:** `weight` = рівень питання + 1 (`A0→1`, `A1→2`, `A2→3`).
  Тоді `maxScore` = `1 + 7*2 + 4*3 = 27`.
* **Варіант B:** `weight` — довільні числа (наприклад `pt_10` має `5`,
  `pt_09` — `4`, `pt_01` — `1`), підібрані автором вручну.

**Рекомендація:** **Варіант B** (числа справді різні: `pt_05` = `3`, `pt_06` = `3`,
`pt_09` = `4`, `pt_10` = `5`). Щоб отримати решту, треба одним скриптом
розібрати 12 викликів `Question.<init>` у `classes15.txt:3199-3626` і взяти
9-й аргумент кожного. Це єдиний пункт специфікації, де потрібне додаткове
дослідження.

### 12.8 Порядок полів `ActivityAllocation`

`strings_by_class.txt:3667-3677` дає **алфавітний** список рядків, який не
дорівнює порядку полів. Порядок оголошення — з дескриптора конструктора.

* **Варіант A:** порядок як у 8.2:
  `(review, newWords, grammar, exercise, listening, speaking, exerciseItems, listeningItems, speakingItems, grammarItems)`.
* **Варіант B:** порядок як в оголошенні `data class` у Kotlin-джерелі, який міг
  бути `(reviewMinutes, newWordsMinutes, grammarMinutes, exerciseMinutes,
  listeningMinutes, speakingMinutes, exerciseItems, listeningItems, speakingItems, grammarItems)`
  — що збігається з A.

**Рекомендація:** перевірити `@Metadata d2` класу `ActivityAllocation`
(`classes8.txt:5216`) — там перелічено всі 10 полів у порядку оголошення.
Поки що використовувати варіант A; єдине, що реально впливає на UI —
`grammarItems` (використовується як `limit` у `pickGrammar`), тому зіставити
цей слот потрібно обов'язково.

### 12.9 Другий ключ сортування в `pickNewWords`

`compareBy(pickNewWords$4, pickNewWords$5)` (`classes8.txt:7905-7920`).
Перший ключ точно `topicOrder[it.topicId] ?: Int.MAX_VALUE`. Другий —
`pickNewWords$5`, який у `strings_by_class.txt:3692` містить лише рядок `"it"`.

* **Варіант A:** ключ = `it.frequencyRank` (`Int`), тобто сортування за
  частотним рангом (найуживаніші слова — першими).
* **Варіант B:** ключ = `it.orderIndex` / `it.id` / `it.spanish.lowercase()` —
  будь-яке інше поле моделі `Word`.

**Рекомендація:** **Варіант A.** У `content_from_apk/words.a0.json` перевірити
наявність поля рангу; якщо є `frequencyRank` або подібне — використати його.

### 12.10 Ключ сортування в `pickGrammar`

`pickGrammar$lambda$40$$inlined$sortedBy$1` (`classes8.txt:6595-6678`) сортує
`List<GrammarNote>` у fallback-гілці. Точний ключ не встановлено.

* **Варіант A:** `it.order` / `it.orderIndex` (`Int`) — порядок викладу в курсі.
* **Варіант B:** `it.level.ordinal` або `it.id`.

**Рекомендація:** **Варіант A** — прочитати лямбду
(`classes8.txt:6595-6678`), там видно ім'я гетера `GrammarNote`.

### 12.11 `totalMinutes` у `SessionPlan`

Формула `dueCards.size + newItems.size` (крок 27 у 8.10) виглядає **дивно**:
назва поля — «загальна кількість хвилин», а обчислюється як **кількість
елементів**.

* **Варіант A:** це справді кількість елементів, а поле названо неточно
  (або це `itemCount`, перейменований у `totalMinutes` при рефакторингу).
* **Варіант B:** `v12` і `v6` — це не списки, а списки **хвилин**, і `.size()`
  випадково збігається з `.sum()` при деяких даних.

**Рекомендація:** **Варіант A** — реалізувати `totalMinutes = reviewItems.count +
newItems.count`. Якщо в UI видно «хвилини» і вони не збігаються з очікуванням —
перевірити `SessionPlan.totalMinutes` на реальному пристрої.

---

## 13. Крайові випадки (зведено)

| Ситуація | Поведінка (точна) |
| --- | --- |
| Порожній `recentResults` у `MistakeTracker.mastery` | повертається `stat.masteryPercent` без змін |
| `weightSum == 0` у `mastery` | неможливо: `weight >= 1.0` завжди (порожній список оброблено раніше) |
| `totalReviews == 0` у `retention` | повертається `0` (без ділення на нуль) |
| `totalReviews == 0` у `strength` | повертається `0` |
| `averageResponseMs` порожній список у `buildSnapshot` | `average()` → `NaN` → guard → `0L` |
| Порожній `expectedVariants` у `compareAny` | `correct = false`, `expected = ""`, `grade = AGAIN` |
| `given` складається лише з пробілів/пунктуації | `normalize` → `""` → `isBlank()` → `correct = false`, навіть якщо `expected` теж порожній |
| `maxScore == 0` у `PlacementTest.evaluate` | `percent = 0`, `level = A0` |
| `byLevelPoints[lvl].second == 0` | рівень пропускається (потрібно `t > 0`) |
| `stats.isEmpty()` у `calculateStreak` | повертається `0` |
| Пропуск дня у `calculateStreak` | стрік зупиняється (`break`) |
| `activeDays.first()` не `today` і не `yesterday` | стрік = `0` |
| `unlockedLevels` дає порожній список | `listOf(Level.A0)` |
| `blocks` після фільтра порожній | `SessionPlan` з порожнім списком блоків (UI має це обробити) |
| `pickNewWords` — усі слова вже відомі | порожній список → блок `NEW_WORDS` відфільтровується |
| `pickGrammar` — жодної нотатки за тегами | fallback на `grammarByLevel(levels)` |
| `buildReviewItems` — картка з `itemType`, якого немає в мапах | пропускається (`?.let` → `null`) |
| `ensureCard` — `upsertCard` повернув `id <= 0` | повторне читання `userDao.card(...)` і взяття `id` |
| `suspendCard` з `state.id <= 0` | no-op |
| `buildPlan` — `dueCards` порожній і `newItems` порожній | `totalMinutes = 0`, лишаються лише непусті блоки |
| `CardPhase.fromCode(невідомий код)` | `NEW` |
| `Level.fromCode(невідомий код)` | `null` (не `A0`!) — увага, на відміну від `CardPhase` |
| `SrsScheduler.review` для `AGAIN` у `NEW` | те саме, що `reviewInLearning(AGAIN)` |
| `responseMs <= 0` у `speedFactor` | `1.0` (без множення) |
| `averageResponseMs <= 0` у `speedFactor` | `1.0` |
| `grade == AGAIN` у `speedFactor` | `1.0` |
| `intervalDays` > 365 після рев'ю | обрізається до `365.0`, `dueAt = now + 365 діб` |
| `intervalDays` < 1 після рев'ю | піднімається до `1.0` |
| `intervalMinutes = 10` і `intervalDays = 365` одночасно | `dueAt` = `now + 10 хв` (хвилини мають приоритет) |
| повторне проходження (retake) PlacementTest | `evaluate` — чиста функція, стан не зберігається; повторний виклик дає той самий результат для тих самих `answers` |

---

## 14. Що залишилось з'ясувати (пріоритет)

1. **`weight` для 8 із 12 питань `PlacementTest`** (12.7) — впливає на `percent`
   і `level`. Потрібен скрипт-розбір 12 викликів `Question.<init>`.
2. **`intervalDays` нової картки** (12.1) — впливає на перший `dueAt` і, отже,
   на `dueNow`/`wordsMemorized`.
3. **Порядок полів `ActivityAllocation`** (12.8) — впливає на `grammarItems`
   (ліміт `pickGrammar`).
4. **Ключі сортування** в `pickNewWords$5` (12.9) і `pickGrammar$lambda$40` (12.10).
5. **Точний формат `describeInterval`** (12.5) — впливає на UI-підписи
   `GradePreview.intervalLabel`.
6. **`_recon/strings_by_class.txt:3889`** показує, що `SrsEngine.kt` містить лише
   два рядкові літерали (`"call to 'resume' before 'invoke' with coroutine"`,
   `"database"`), тобто жодних «магічних» рядків у рушії карток немає —
   це підтверджує, що вся семантика в числах, а не в рядках.

---

*Документ підготовлено реверс-інжинірингом `disasm/classes2–17.txt` та
`_recon/strings_by_class.txt`. Усі посилання на smali наведено у форматі
`<файл>:<номер рядка>` для можливості незалежної перевірки.*
