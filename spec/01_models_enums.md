# 01. Моделі даних та enum-и застосунку `ua.krupa.spanish`

Документ відновлено з дизасембльованого APK (dex `classes2..classes17`), карти класів (`_recon/class_to_source.txt`, `_recon/strings_by_class.txt`) та фактичного контенту (`content_from_apk/*.json`).

Позначки джерела:
* **[D]** — блок класу в дизасемблі (поля, `<clinit>`, `<init>`, serializers).
* **[J]** — фактичний JSON контенту.
* **[SQL]** — `CREATE TABLE` з `AppDatabase_Impl` (Room-схема).

Загальні принципи:
* усі enum-и в контенті/БД зберігаються **рядковими кодами** (`code`), а не ordinal; виняток — `Grade` (зберігається як `Int value` у `ReviewLogEntity.gradeValue`).
* регістр кодів: `Level` — **ВЕЛИКІ** літери (`"A0"`), решта — **нижній регістр** (`"noun"`, `"dialogue"`, `"articles"`, `"travel"`, `"system"`).
* порядок значень у таблицях = порядок оголошення = порядок у `<clinit>` (ordinal).

---

## 1. Перелік усіх enum-ів (22)

Знайдено повним скануванням дизасемблю на `PUBLIC FINAL ENUM`:

| # | Enum | Файл (Kotlin) | Пакет | Додаткові поля |
|---|------|---------------|-------|----------------|
| 1 | `Level` | Enums.kt | domain/model | code, titleUk, descriptionUk |
| 2 | `ExerciseKind` | Enums.kt | domain/model | code, titleUk |
| 3 | `Grade` | Enums.kt | domain/model | value(Int), titleUk, symbol |
| 4 | `GrammarTag` | Enums.kt | domain/model | code, titleUk |
| 5 | `Gender` | Enums.kt | domain/model | code, titleUk, article? |
| 6 | `PartOfSpeech` | Enums.kt | domain/model | code, titleUk |
| 7 | `LearningGoal` | UserProfile.kt | domain/model | code, titleUk, descriptionUk |
| 8 | `ThemeMode` | UserProfile.kt | domain/model | code, titleUk |
| 9 | `ListeningKind` | CourseModels.kt | domain/model | code, titleUk |
| 10 | `SentenceKind` | CourseModels.kt | domain/model | code, titleUk |
| 11 | `CardPhase` | CardState.kt | learning/srs | code, titleUk |
| 12 | `SessionBlockKind` | SessionPlan.kt | learning/session | code, titleUk |
| 13 | `IssueType` | PronunciationScorer.kt | speech/pronunciation | titleUk (без code) |
| 14 | `PronunciationScorer.Operation` | PronunciationScorer.kt | speech/pronunciation | — (вкладений) |
| 15 | `AIConversationMode` | AIProvider.kt | ai | code, titleUk, descriptionUk |
| 16 | `AIScenario` | AIProvider.kt | ai | code, titleUk, openingSpanish, openingHintUk |
| 17 | `AiPhase` | AiDialogViewModel.kt | ui/screens/ai | — |
| 18 | `Step` | OnboardingViewModel.kt | ui/screens/onboarding | — |
| 19 | `BottomDestination` | NavigationComponents.kt | ui/navigation | route, titleUk, icon(ImageVector) |
| 20 | `SecondaryDestination` | NavigationComponents.kt | ui/navigation | route, titleUk, descriptionUk, icon |
| 21 | `WordFilter` | WordsViewModel.kt | ui/screens/words | titleUk (без code) |
| 22 | `SpanishTtsEngine.VoiceGender` | SpanishTtsEngine.kt | speech/tts | code, titleUk |

Конструктори (порядок параметрів після `name`/`ordinal`) **[D]**:

```
Level(code: String, titleUk: String, descriptionUk: String)          // <init>(String,ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;)V
ExerciseKind(code: String, titleUk: String)
Grade(value: Int, titleUk: String, symbol: String)
GrammarTag(code: String, titleUk: String)
Gender(code: String, titleUk: String, article: String?)
PartOfSpeech(code: String, titleUk: String)
LearningGoal(code: String, titleUk: String, descriptionUk: String)
ThemeMode(code: String, titleUk: String)
ListeningKind(code: String, titleUk: String)
SentenceKind(code: String, titleUk: String)
CardPhase(code: String, titleUk: String)
SessionBlockKind(code: String, titleUk: String)
IssueType(titleUk: String)
AIConversationMode(code: String, titleUk: String, descriptionUk: String)
AIScenario(code: String, titleUk: String, openingSpanish: String, openingHintUk: String)
BottomDestination(route: String, titleUk: String, icon: ImageVector)
SecondaryDestination(route: String, titleUk: String, descriptionUk: String, icon: ImageVector)
SpanishTtsEngine.VoiceGender(code: String, titleUk: String)
```

---

## 2. Enum-и доменного шару (Enums.kt)

### 2.1 `Level` [D]

| # | name | code | titleUk | descriptionUk |
|---|------|------|---------|---------------|
| 0 | A0 | `"A0"` | Повний нуль | Перші слова, звуки, прості фрази |
| 1 | A1 | `"A1"` | Базове спілкування | Знайомство, числа, час, прості питання |
| 2 | A2 | `"A2"` | Повсякденні ситуації | Магазин, транспорт, здоров'я, побут |
| 3 | B1 | `"B1"` | Вільніше спілкування | Розповідь про себе, думки, плани |
| 4 | B2 | `"B2"` | Складніша мова | Аргументація, абстрактні теми, нюанси |

Методи/статики [D]:
* `fun getIndex(): Int = ordinal`
* `fun isAtMost(other: Level): Boolean = ordinal <= other.ordinal` (param `other`, non-null)
* `Companion.fromCode(code: String): Level` — **без урахування регістру** (`StringsKt.equals(a, b, ignoreCase = true)`), якщо не знайдено → **`A0`** (не nullable).
* `Companion.all: List<Level> = entries.toList()`
* `Companion.mvpLevels: List<Level> = listOf(A0, A1, A2)`

Приклад у контенті [J]: `"level": "A0" | "A1" | "A2"` (рівні B1/B2 у контенті відсутні).

### 2.2 `ExerciseKind` [D]

| # | name | code | titleUk | Знайдено в контенті [J] |
|---|------|------|---------|--------------------------|
| 0 | TRANSLATION_ES_UK | `"translation_es_uk"` | Переклад іспанською → українською | ✅ |
| 1 | TRANSLATION_UK_ES | `"translation_uk_es"` | Переклад українською → іспанською | ✅ |
| 2 | MULTIPLE_CHOICE | `"multiple_choice"` | Вибір відповіді | ✅ |
| 3 | SENTENCE_BUILD | `"sentence_build"` | Складання речення | ✅ |
| 4 | FILL_GAP | `"fill_gap"` | Пропущене слово | ✅ |
| 5 | LISTENING | `"listening"` | Аудіювання | ✅ |
| 6 | DICTATION | `"dictation"` | Диктант | ✅ |
| 7 | SPEAKING | `"speaking"` | Говоріння | ✅ |
| 8 | MATCH_PAIRS | `"match_pairs"` | Зіставлення пар | ✅ |

`Companion.fromCode(code: String): ExerciseKind` — **точна** рівність (`Intrinsics.areEqual`), fallback → **`MULTIPLE_CHOICE`**.

### 2.3 `Grade` [D]

| # | name | value | titleUk | symbol |
|---|------|-------|---------|--------|
| 0 | AGAIN | 0 | Не знаю | `"✕"` |
| 1 | HARD | 1 | Пам'ятаю з труднощами | `"~"` |
| 2 | GOOD | 2 | Знаю | `"✓"` |
| 3 | EASY | 3 | Дуже добре | `"★"` |

`Companion.fromValue(value: Int): Grade` — пошук за `value`, fallback → **`GOOD`**. Використовується в SRS (`ease`/`interval`) та в БД як `review_logs.gradeValue` (INTEGER).

### 2.4 `Gender` [D]

| # | name | code | titleUk | article |
|---|------|------|---------|---------|
| 0 | MASCULINE | `"m"` | чоловічий | `"el"` |
| 1 | FEMININE | `"f"` | жіночий | `"la"` |
| 2 | AMBIGUOUS | `"mf"` | спільний (el/la) | **null** |
| 3 | NONE | `"none"` | не має роду | **null** |

`article: String?` (nullable — для AMBIGUOUS і NONE дорівнює `null`) [D].
`Companion.fromCode(code: String?): Gender` — **без урахування регістру**, параметр **nullable** (у методі немає `checkNotNullParameter` для `code`); fallback → **`NONE`**.
[J] `"gender": "m" | "f" | "mf" | "none"` (усі 4 значення присутні).

### 2.5 `GrammarTag` [D] — 32 значення

| # | name | code | titleUk |
|---|------|------|---------|
| 0 | ARTICLES | `articles` | Артиклі |
| 1 | GENDER_NUMBER | `gender_number` | Рід і число |
| 2 | PRESENT_REGULAR | `present_regular` | Теперішній час (правильні) |
| 3 | PRESENT_IRREGULAR | `present_irregular` | Теперішній час (неправильні) |
| 4 | SER_ESTAR | `ser_estar` | Ser / estar |
| 5 | HAY | `hay` | Hay / є |
| 6 | GUSTAR | `gustar` | Gustar і подібні |
| 7 | REFLEXIVE | `reflexive` | Зворотні дієслова |
| 8 | IR_A_INFINITIVE | `ir_a` | Ir a + інфінітив (майбутнє) |
| 9 | PERIPHRASIS | `periphrasis` | Дієслово + інфінітив |
| 10 | QUESTION_WORDS | `question_words` | Питальні слова |
| 11 | NEGATION | `negation` | Заперечення |
| 12 | PRONOUNS_OBJECT | `pronouns_object` | Займенники-додатки |
| 13 | POSSESSIVES | `possessives` | Присвійні |
| 14 | DEMONSTRATIVES | `demonstratives` | Вказівні |
| 15 | COMPARATIVES | `comparatives` | Порівняння |
| 16 | PRETERITE | `preterite` | Минулий час (pretérito indefinido) |
| 17 | IMPERFECT | `imperfect` | Минулий час (imperfecto) |
| 18 | PERFECT | `perfect` | Складений минулий (he hecho) |
| 19 | FUTURE | `future` | Майбутній час |
| 20 | CONDITIONAL | `conditional` | Умовний спосіб |
| 21 | SUBJUNCTIVE | `subjunctive` | Subjuntivo |
| 22 | IMPERATIVE | `imperative` | Наказовий спосіб |
| 23 | POR_PARA | `por_para` | Por / para |
| 24 | PREPOSITIONS | `prepositions` | Прийменники |
| 25 | TIME_EXPRESSIONS | `time_expressions` | Час і дати |
| 26 | NUMBERS | `numbers` | Числа |
| 27 | SPELLING | `spelling` | Правопис і наголос |
| 28 | COGNATES | `cognates` | Схожі слова (когнати) |
| 29 | FALSE_FRIENDS | `false_friends` | Фальшиві друзі перекладача |
| 30 | WORD_ORDER | `word_order` | Порядок слів |
| 31 | POLITE | `polite` | Ввічливість |

`Companion.fromCode(code: String): GrammarTag?` — **точна** рівність, **fallback → `null`** (єдиний enum із nullable-результатом). Саме тому мапери використовують `mapNotNull` над списками тегів.

Теги, що реально зустрічаються [J]:
* `grammar.tag` — 31 значення (усі, крім `polite`… фактично: articles, cognates, comparatives, conditional, demonstratives, false_friends, future, gender_number, gustar, hay, imperative, imperfect, ir_a, negation, numbers, perfect, periphrasis, polite, por_para, possessives, prepositions, present_irregular, present_regular, preterite, pronouns_object, question_words, reflexive, ser_estar, spelling, time_expressions, word_order);
* `exercises.grammarTag` — 29 значень (усі з `grammar.tag`, крім `false_friends` і `word_order`);
* `words.grammarTags[]`, `sentences.grammarTags[]`, `topics.grammarTags[]` — масиви кодів (див. §6).

### 2.6 `PartOfSpeech` [D]

| # | name | code | titleUk | [J] |
|---|------|------|---------|-----|
| 0 | NOUN | `noun` | іменник | ✅ |
| 1 | VERB | `verb` | дієслово | ✅ |
| 2 | ADJECTIVE | `adjective` | прикметник | ✅ |
| 3 | ADVERB | `adverb` | прислівник | ✅ |
| 4 | PRONOUN | `pronoun` | займенник | ✅ |
| 5 | ARTICLE | `article` | артикль | (у контенті не зустрічається) |
| 6 | PREPOSITION | `preposition` | прийменник | ✅ |
| 7 | CONJUNCTION | `conjunction` | сполучник | (не зустрічається) |
| 8 | NUMERAL | `numeral` | числівник | ✅ |
| 9 | INTERJECTION | `interjection` | вигук | ✅ |
| 10 | PHRASE | `phrase` | фраза | ✅ |

`Companion.fromCode(code: String): PartOfSpeech` — **без урахування регістру**, fallback → **`PHRASE`**.

---

## 3. Enum-и профілю користувача (UserProfile.kt)

### 3.1 `LearningGoal` [D]

| # | name | code | titleUk | descriptionUk |
|---|------|------|---------|---------------|
| 0 | TRAVEL | `travel` | Подорожі | Розмови в аеропорту, готелі, кафе, на вулиці |
| 1 | WORK | `work` | Робота | Ділове листування, зустрічі, професійна лексика |
| 2 | STUDY | `study` | Навчання | Іспити, університет, сертифікати DELE |
| 3 | RELOCATION | `relocation` | Переїзд | Побут, документи, оренда житла, лікарі |
| 4 | COMMUNICATION | `communication` | Спілкування | Друзі, серіали, музика, інтернет |

`fromCode` — точна рівність, fallback → **`TRAVEL`**.

### 3.2 `ThemeMode` [D]

| # | name | code | titleUk |
|---|------|------|---------|
| 0 | SYSTEM | `system` | Як у системі |
| 1 | LIGHT | `light` | Світла |
| 2 | DARK | `dark` | Темна |

`fromCode` — точна рівність, fallback → **`SYSTEM`**. У БД зберігається в `user_profile.themeMode` (TEXT, напр. `"system"`).

---

## 4. Enum-и контенту (CourseModels.kt) та SRS/сесій

### 4.1 `ListeningKind` [D]

| # | name | code | titleUk | [J] |
|---|------|------|---------|-----|
| 0 | DIALOGUE | `dialogue` | Діалог | ✅ |
| 1 | STORY | `story` | Історія | ✅ |
| 2 | PODCAST | `podcast` | Подкаст | ✅ |
| 3 | MONOLOGUE | `monologue` | Розповідь | ✅ |

`fromCode` — точна, fallback → **`DIALOGUE`**.

### 4.2 `SentenceKind` [D]

| # | name | code | titleUk | [J] |
|---|------|------|---------|-----|
| 0 | WORD | `word` | Приклад до слова | (у `sentences.*` не зустрічається) |
| 1 | PHRASE | `phrase` | Фраза | ✅ |
| 2 | DIALOGUE | `dialogue` | Діалог | ✅ |
| 3 | STORY | `story` | Історія | ✅ |

`fromCode` — точна, fallback → **`PHRASE`**.

### 4.3 `CardPhase` (learning/srs/CardState.kt) [D]

| # | name | code | titleUk |
|---|------|------|---------|
| 0 | NEW | `new` | Нова |
| 1 | LEARNING | `learning` | Вивчається |
| 2 | REVIEW | `review` | На повторенні |
| 3 | RELEARNING | `relearning` | Переучується |

`fromCode` — точна, fallback → **`NEW`**. У БД: `cards.stateCode` (TEXT).

### 4.4 `SessionBlockKind` (learning/session/SessionPlan.kt) [D]

| # | name | code | titleUk |
|---|------|------|---------|
| 0 | REVIEW | `review` | Повторення |
| 1 | NEW_WORDS | `new_words` | Нові слова |
| 2 | GRAMMAR | `grammar` | Граматика |
| 3 | EXERCISES | `exercises` | Вправи |
| 4 | LISTENING | `listening` | Аудіювання |
| 5 | SPEAKING | `speaking` | Говоріння |

`fromCode` — точна, fallback → **`REVIEW`**.

### 4.5 `IssueType` (speech/pronunciation) [D] — без `code`

| # | name | titleUk |
|---|------|---------|
| 0 | WRONG_WORD | Неправильне слово |
| 1 | MISSING_WORD | Пропущене слово |
| 2 | EXTRA_WORD | Зайве слово |
| 3 | PHONETIC_NEAR | Неточна вимова |
| 4 | NOTHING_HEARD | Нічого не почуто |
| 5 | ARTICLE_AGREEMENT | Артикль не узгоджений |
| 6 | R_SOUND | Звук r |
| 7 | C_AND_Z | Звуки c / z |
| 8 | J_SOUND | Звук j |
| 9 | B_AND_V | Звуки b / v |
| 10 | SWALLOWED_SYLLABLE | Проковтнутий склад |

`PronunciationScorer.Operation` (внутрішній enum алгоритму Левенштейна/вирівнювання) [D]: `MATCH`, `SUBSTITUTE`, `DELETE`, `INSERT` — без полів.

### 4.6 Enum-и AI-шару (ai/AIProvider.kt) [D]

`AIConversationMode(code, titleUk, descriptionUk)`:

| # | name | code | titleUk | descriptionUk |
|---|------|------|---------|---------------|
| 0 | TEACHER | `teacher` | Вчитель | Пояснює помилки українською, розбирає граматику |
| 1 | PARTNER | `partner` | Співрозмовник | Говорить лише іспанською, як носій |
| 2 | HINTS | `hints` | Іспанська + підказки | Іспанською, але з перекладом і допомогою |
| 3 | ROLEPLAY | `roleplay` | Рольова гра | Реалістична ситуація: ресторан, готель, лікар… |

`fromCode` — точна, fallback → **`HINTS`**.

`AIScenario(code, titleUk, openingSpanish, openingHintUk)`:

| # | name | code | titleUk | openingSpanish | openingHintUk |
|---|------|------|---------|----------------|----------------|
| 0 | INTRODUCTIONS | `introductions` | Знайомство | ¡Hola! Me llamo Ana. ¿Y tú? ¿Cómo te llamas? | Привіт! Мене звати Ана. А ти? |
| 1 | RESTAURANT | `restaurant` | Ресторан | Buenas tardes, bienvenido. ¿Mesa para cuántas personas? | Доброго дня, вітаю. Столик на скільки осіб? |
| 2 | SHOP | `shop` | Магазин | Hola, ¿le puedo ayudar en algo? | Вітаю, можу чимось допомогти? |
| 3 | HOTEL | `hotel` | Готель | Buenas noches. ¿Tiene una reserva a su nombre? | Доброго вечора. У вас є бронювання? |
| 4 | AIRPORT | `airport` | Аеропорт | Buenos días. ¿Me enseña su pasaporte, por favor? | Доброго ранку. Покажіть, будь ласка, паспорт. |
| 5 | DOCTOR | `doctor` | Лікар | Buenos días. Cuénteme, ¿qué le pasa? | Доброго ранку. Розкажіть, що вас турбує? |
| 6 | WORK | `work` | Робота | Hola, soy Marta de recursos humanos. Cuéntame un poco sobre ti. | Вітаю, я Марта з відділу кадрів. Розкажи трохи про себе. |
| 7 | RENTING | `renting` | Оренда житла | Hola, ¿llama por el piso del centro? Todavía está disponible. | Вітаю, ви телефонуєте щодо квартири в центрі? Вона ще вільна. |
| 8 | FREE_TALK | `free_talk` | Вільна розмова | ¡Hola! ¿Qué tal? ¿Cómo llevas el español? | Привіт! Як справи? Як тобі дається іспанська? |

`fromCode` — точна, fallback → **`FREE_TALK`**.

### 4.7 Enum-и UI (не є моделями даних, але впливають на навігацію)

| Enum | Значення (name → route/title) |
|------|-------------------------------|
| `AiPhase` [D] | `SETUP`, `CHAT`, `REVIEW` (без полів) |
| `Step` (onboarding) [D] | `WELCOME`, `GOAL`, `TIME`, `TEST_INTRO`, `TEST`, `RESULT` (без полів) |
| `BottomDestination` [D] | `HOME`(`home`,`Головна`), `LEARN`(`learn`,`Навчання`), `REVIEW`(`review`,`Повторення`), `LISTENING`(`listening`,`Слухання`), `PROGRESS`(`progress`,`Прогрес`) + `icon` |
| `SecondaryDestination` [D] | `WORDS`(`words`,`Слова`,`Словник і стан запам'ятовування`), `SPEAKING`(`speaking`,`Говоріння`,`Вимова й оцінка мовлення`), `AI_DIALOG`(`ai_dialog`,`AI-діалог`,`Розмова з викладачем`), `GRAMMAR`(`grammar`,`Граматика`,`Пояснення українською`), `SETTINGS`(`settings`,`Налаштування`,`Профіль, аудіо, дані`) |
| `WordFilter` [D] | `ALL`(`Усі`), `LEARNING`(`У навчанні`), `DIFFICULT`(`Важкі`), `MASTERED`(`Засвоєні`), `NOT_STARTED`(`Ще не вчилися`) — лише `titleUk` |
| `SpanishTtsEngine.VoiceGender` [D] | `FEMALE`(`female`,`Жіночий голос`), `MALE`(`male`,`Чоловічий голос`); `fromCode` fallback → `FEMALE` |

---

## 5. Доменні моделі `CourseModels.kt` (domain/model)

Усі — `data class` (не `@Serializable`), усі поля **non-null**, якщо не вказано інше (перевірено `checkNotNullParameter` у головному конструкторі **[D]**). Порядок полів = порядок у `toString()` = порядок параметрів конструктора.

### 5.1 `Word` (17 полів) [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — (обов'язкове) |
| 2 | spanish | String | — |
| 3 | translationUk | String | — |
| 4 | partOfSpeech | PartOfSpeech | — |
| 5 | gender | Gender | `Gender.NONE` |
| 6 | plural | String | `""` |
| 7 | pronunciation | String | `""` |
| 8 | ipaHint | String | `""` |
| 9 | exampleEs | String | `""` |
| 10 | exampleUk | String | `""` |
| 11 | level | Level | — (обов'язкове) |
| 12 | topicId | String | — |
| 13 | withArticle | Boolean | `false` |
| 14 | grammarTags | List\<GrammarTag\> | `emptyList()` |
| 15 | notesUk | String | `""` |
| 16 | cognateNoteUk | String | `""` |
| 17 | frequencyRank | Int | `5000` |

### 5.2 `WordGloss` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | spanish | String | — |
| 2 | translationUk | String | — |

(Синтетичного конструктора з `DefaultConstructorMarker` немає → **дефолтів немає**.)

### 5.3 `Topic` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — |
| 2 | level | Level | — |
| 3 | titleEs | String | — |
| 4 | titleUk | String | — |
| 5 | descriptionUk | String | — |
| 6 | orderIndex | Int | — |
| 7 | iconKey | String | — |
| 8 | grammarTags | List\<GrammarTag\> | `emptyList()` |

### 5.4 `Sentence` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — |
| 2 | spanish | String | — |
| 3 | translationUk | String | — |
| 4 | level | Level | — |
| 5 | topicId | String | — |
| 6 | kind | SentenceKind | `SentenceKind.PHRASE` |
| 7 | grammarTags | List\<GrammarTag\> | `emptyList()` |
| 8 | wordIds | List\<String\> | `emptyList()` |
| 9 | audioHint | String | `""` |

### 5.5 `ListeningItem` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — |
| 2 | level | Level | — |
| 3 | topicId | String | — |
| 4 | titleEs | String | — |
| 5 | titleUk | String | — |
| 6 | kind | ListeningKind | — (обов'язкове) |
| 7 | lines | List\<ListeningLine\> | — (обов'язкове; біт 6 маски дефолтів не виставлений) |
| 8 | keyWords | List\<WordGloss\> | `emptyList()` |
| 9 | comprehensionQuestions | List\<ComprehensionQuestion\> | `emptyList()` |
| 10 | orderIndex | Int | `0` |

### 5.6 `ListeningLine` [D] — без дефолтів

`speaker: String`, `spanish: String`, `translationUk: String`.

### 5.7 `ComprehensionQuestion` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | questionUk | String | — |
| 2 | options | List\<String\> | — |
| 3 | correctIndex | Int | — |
| 4 | explanationUk | String | `""` |

### 5.8 `Exercise` (17 полів) [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — |
| 2 | kind | ExerciseKind | — |
| 3 | level | Level | — |
| 4 | topicId | String | — |
| 5 | grammarTag | GrammarTag | — |
| 6 | promptUk | String | `""` |
| 7 | promptEs | String | `""` |
| 8 | answerEs | String | `""` |
| 9 | answerUk | String | `""` |
| 10 | distractors | List\<String\> | `emptyList()` |
| 11 | tokens | List\<String\> | `emptyList()` |
| 12 | gapText | String | `""` |
| 13 | gapAnswer | String | `""` |
| 14 | relatedWordIds | List\<String\> | `emptyList()` |
| 15 | relatedSentenceId | String | `""` |
| 16 | explanationUk | String | `""` |
| 17 | difficulty | Int | `1` |

> `grammarTag` у доменній моделі має тип `GrammarTag` (JVM-сигнатура `Lua/krupa/spanish/domain/model/GrammarTag;`) — тобто не nullable, але значення походить із `GrammarTag.fromCode()`, який може повернути `null`; у контенті всі `grammarTag` валідні.

### 5.9 `GrammarNote` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | id | String | — |
| 2 | tag | GrammarTag | — |
| 3 | level | Level | — |
| 4 | titleEs | String | — |
| 5 | titleUk | String | — |
| 6 | explanationUk | String | — |
| 7 | patternUk | String | `""` |
| 8 | examples | List\<GrammarExample\> | `emptyList()` |
| 9 | commonMistakeUk | String | `""` |
| 10 | tipForUkSpeakersUk | String | `""` |
| 11 | orderIndex | Int | `0` |

### 5.10 `GrammarExample` [D]

`spanish: String`, `translationUk: String`, `noteUk: String = ""`.

### 5.11 `ContentPack` [D]

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | contentVersion | Int | — (обов'язкове) |
| 2 | topics | List\<Topic\> | `emptyList()` |
| 3 | words | List\<Word\> | `emptyList()` |
| 4 | sentences | List\<Sentence\> | `emptyList()` |
| 5 | grammar | List\<GrammarNote\> | `emptyList()` |
| 6 | exercises | List\<Exercise\> | `emptyList()` |
| 7 | listening | List\<ListeningItem\> | `emptyList()` |

---

## 6. `UserProfile` (domain/model/UserProfile.kt) [D]

`data class UserProfile` — 16 полів, порядок оголошення підтверджено конструктором і `toString()`:

| # | поле | тип | default |
|---|------|-----|---------|
| 1 | name | String | `""` |
| 2 | level | Level | `Level.A0` |
| 3 | assessmentDone | Boolean | `false` |
| 4 | assessmentScore | Int | `0` |
| 5 | goal | LearningGoal | `LearningGoal.TRAVEL` |
| 6 | dailyMinutes | Int | `20` |
| 7 | startedAt | Long | `System.currentTimeMillis()` |
| 8 | themeMode | ThemeMode | `ThemeMode.SYSTEM` |
| 9 | ttsVoiceGender | String | `"female"` |
| 10 | ttsRate | Float | `1.0f` |
| 11 | showListeningHints | Boolean | `false` ← (так у байткоді!) |
| 12 | allowExternalAi | Boolean | `false` |
| 13 | aiProviderId | String | `"local"` |
| 14 | aiEndpoint | String | `""` |
| 15 | aiApiKey | String | `""` |
| 16 | aiModel | String | `""` |

Додатково (`UserProfileKt`) [D]:
* `fun defaultProfile(): UserProfile` — викликає конструктор з маскою `0x0000FFFF` (усі 16 дефолтів), тобто `UserProfile()`.
* `fun UserProfile.toEntity(): UserProfileEntity` — мапиться: `level.code → levelCode`, `goal.code → goalCode`, `themeMode.code → themeMode`, `id = 0` (`SINGLE_PROFILE_ID`), `dailyGoalStreak` не передається (береться дефолт).
* `fun UserProfileEntity.toDomain(): UserProfile` — зворотно через `Level.fromCode`, `LearningGoal.fromCode`, `ThemeMode.fromCode`.

---

## 7. DTO контенту `ContentPackDto.kt` (data/content)

Усі DTO — `@Serializable data class`; **усі поля non-null** (перевірено `checkNotNullParameter` для всіх reference-параметрів) **[D]**. JSON-ім'я = ім'я поля (жодного `@SerialName` не виявлено: `PluginGeneratedSerialDescriptor` будується з іменами, ідентичними назвам полів; ім'я дескриптора = FQCN, напр. `ua.krupa.spanish.data.content.WordDto`).

Позначка «opt» = `addElement(name, isOptional = true)`, тобто поле має дефолт у конструкторі **[D]**.

### 7.1 `ContentPackDto`

| # | поле (JSON-ключ) | тип | default | opt |
|---|---|---|---|---|
| 1 | `contentVersion` | Int | `1` | ✅ |
| 2 | `topics` | List\<TopicDto\> | `emptyList()` | ✅ |
| 3 | `words` | List\<WordDto\> | `emptyList()` | ✅ |
| 4 | `sentences` | List\<SentenceDto\> | `emptyList()` | ✅ |
| 5 | `grammar` | List\<GrammarNoteDto\> | `emptyList()` | ✅ |
| 6 | `exercises` | List\<ExerciseDto\> | `emptyList()` | ✅ |
| 7 | `listening` | List\<ListeningItemDto\> | `emptyList()` | ✅ |

Фактичні файли ассетів [J]/[D]: `topics.a0.json`, `words.a0.json`, `sentences.a0.json`, `exercises.a0.json`, `listening.a0.json` (те саме для `a1`, `a2`) + `grammar.a0a1.json`, `grammar.a2.json` — усього 17 файлів; кожен містить `{"contentVersion": 1, "<секція>": [...]}`, тобто фактично «частковий» `ContentPackDto`.

Парсер контенту [D]: `Json { ignoreUnknownKeys = true; explicitNulls = false }`.

### 7.2 `WordDto` (17 полів, порядок у дескрипторі)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `spanish` | String | — | ❌ |
| 3 | `translationUk` | String | — | ❌ |
| 4 | `partOfSpeech` | String | `"phrase"` | ✅ |
| 5 | `gender` | String | `"none"` | ✅ |
| 6 | `plural` | String | `""` | ✅ |
| 7 | `pronunciation` | String | `""` | ✅ |
| 8 | `ipaHint` | String | `""` | ✅ |
| 9 | `exampleEs` | String | `""` | ✅ |
| 10 | `exampleUk` | String | `""` | ✅ |
| 11 | `level` | String | `"A0"` | ✅ |
| 12 | `topicId` | String | `""` | ✅ |
| 13 | `withArticle` | Boolean | `false` | ✅ |
| 14 | `grammarTags` | List\<String\> | `emptyList()` | ✅ |
| 15 | `notesUk` | String | `""` | ✅ |
| 16 | `cognateNoteUk` | String | `""` | ✅ |
| 17 | `frequencyRank` | Int | `5000` | ✅ |

`$childSerializers[13] = ArrayListSerializer(StringSerializer)` → елементи `grammarTags` — рядки **[D]**.

### 7.3 `WordGlossDto`

`spanish: String` (обов'язкове), `translationUk: String = ""`.

### 7.4 `TopicDto` (8 полів)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `level` | String | — | ❌ |
| 3 | `titleEs` | String | `""` | ✅ |
| 4 | `titleUk` | String | `""` | ✅ |
| 5 | `descriptionUk` | String | `""` | ✅ |
| 6 | `orderIndex` | Int | `0` | ✅ |
| 7 | `iconKey` | String | `"topic"` | ✅ |
| 8 | `grammarTags` | List\<String\> | `emptyList()` | ✅ |

### 7.5 `SentenceDto` (9 полів)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `spanish` | String | — | ❌ |
| 3 | `translationUk` | String | — | ❌ |
| 4 | `level` | String | `"A0"` | ✅ |
| 5 | `topicId` | String | `""` | ✅ |
| 6 | `kind` | String | `"phrase"` | ✅ |
| 7 | `grammarTags` | List\<String\> | `emptyList()` | ✅ |
| 8 | `wordIds` | List\<String\> | `emptyList()` | ✅ |
| 9 | `audioHint` | String | `""` | ✅ |

### 7.6 `ListeningItemDto` (10 полів)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `level` | String | `"A0"` | ✅ |
| 3 | `topicId` | String | `""` | ✅ |
| 4 | `titleEs` | String | `""` | ✅ |
| 5 | `titleUk` | String | `""` | ✅ |
| 6 | `kind` | String | `"dialogue"` | ✅ |
| 7 | `lines` | List\<ListeningLineDto\> | `emptyList()` | ✅ |
| 8 | `keyWords` | **List\<WordGlossDto\>** | `emptyList()` | ✅ |
| 9 | `comprehensionQuestions` | List\<ComprehensionQuestionDto\> | `emptyList()` | ✅ |
| 10 | `orderIndex` | Int | `0` | ✅ |

> **Важливо:** `keyWords` — це масив **об'єктів** `{spanish, translationUk}`, а не рядків (підтверджено і `$childSerializers` = `WordGlossDto$$serializer`, і фактичним JSON [J]).

### 7.7 `ListeningLineDto`

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `speaker` | String | `"A"` | ✅ |
| 2 | `spanish` | String | — | ❌ |
| 3 | `translationUk` | String | `""` | ✅ |

[J] фактичні значення `speaker`: `"A"`, `"B"`.

### 7.8 `ComprehensionQuestionDto`

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `questionUk` | String | — | ❌ |
| 2 | `options` | List\<String\> | `emptyList()` | ✅ |
| 3 | `correctIndex` | Int | `0` | ✅ |
| 4 | `explanationUk` | String | `""` | ✅ |

### 7.9 `ExerciseDto` (17 полів)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `kind` | String | — | ❌ |
| 3 | `level` | String | `"A0"` | ✅ |
| 4 | `topicId` | String | `""` | ✅ |
| 5 | `grammarTag` | String | `""` | ✅ |
| 6 | `promptUk` | String | `""` | ✅ |
| 7 | `promptEs` | String | `""` | ✅ |
| 8 | `answerEs` | String | `""` | ✅ |
| 9 | `answerUk` | String | `""` | ✅ |
| 10 | `distractors` | List\<String\> | `emptyList()` | ✅ |
| 11 | `tokens` | List\<String\> | `emptyList()` | ✅ |
| 12 | `gapText` | String | `""` | ✅ |
| 13 | `gapAnswer` | String | `""` | ✅ |
| 14 | `relatedWordIds` | List\<String\> | `emptyList()` | ✅ |
| 15 | `relatedSentenceId` | String | `""` | ✅ |
| 16 | `explanationUk` | String | `""` | ✅ |
| 17 | `difficulty` | Int | `1` | ✅ |

Обов'язкові лише `id` і `kind` (маска `0b11`) [D]. Спільні `grammarTag`/`gapText`/`gapAnswer`/`relatedSentenceId`/`explanationUk` = `""`.
[J] `difficulty` ∈ {1,2,3,4}.

### 7.10 `GrammarNoteDto` (11 полів)

| # | поле | тип | default | opt |
|---|------|-----|---------|-----|
| 1 | `id` | String | — | ❌ |
| 2 | `tag` | String | — | ❌ |
| 3 | `level` | String | `"A0"` | ✅ |
| 4 | `titleEs` | String | `""` | ✅ |
| 5 | `titleUk` | String | `""` | ✅ |
| 6 | `explanationUk` | String | `""` | ✅ |
| 7 | `patternUk` | String | `""` | ✅ |
| 8 | `examples` | List\<GrammarExampleDto\> | `emptyList()` | ✅ |
| 9 | `commonMistakeUk` | String | `""` | ✅ |
| 10 | `tipForUkSpeakersUk` | String | `""` | ✅ |
| 11 | `orderIndex` | Int | `0` | ✅ |

`GrammarExampleDto`: `spanish` (обов'язкове), `translationUk` (обов'язкове), `noteUk = ""`.
[J] `examples[]` містить саме ключі `spanish`, `translationUk`, `noteUk`.

---

## 8. Мапінг DTO → домен (`ContentMappers`) [D]

`ContentMappers` має `toDomain(...)` для кожного DTO та кожної entity + `toEntity(domain, contentVersion)` + `merge(List<ContentPackDto>, Int): ContentPack`.

Для `WordDto → Word` (повністю відновлено з байткоду):

```
Word(
  id            = dto.id,
  spanish       = dto.spanish,
  translationUk = dto.translationUk,
  partOfSpeech  = PartOfSpeech.fromCode(dto.partOfSpeech),
  gender        = Gender.fromCode(dto.gender),
  plural        = dto.plural,
  pronunciation = dto.pronunciation,
  ipaHint       = dto.ipaHint,
  exampleEs     = dto.exampleEs,
  exampleUk     = dto.exampleUk,
  level         = Level.fromCode(dto.level),
  topicId       = dto.topicId,
  withArticle   = dto.withArticle,
  grammarTags   = dto.grammarTags.mapNotNull { GrammarTag.fromCode(it) },
  notesUk       = dto.notesUk,
  cognateNoteUk = dto.cognateNoteUk,
  frequencyRank = dto.frequencyRank,
)
```

Інші мапери аналогічні: `SentenceKind.fromCode`, `ListeningKind.fromCode`, `ExerciseKind.fromCode`,
`GrammarTag.fromCode` (+ `mapNotNull` для списків), `Level.fromCode` для всіх `level`.

---

## 9. Сховище: entities (data/database)

### 9.1 Типи колонок (Room) [SQL]

`TEXT` = String, `INTEGER` = Int/Long/Boolean, `REAL` = Float/Double. Enum-и зберігаються як `*Code` (TEXT), списки — через `AppConverters` у JSON-рядок.

`AppConverters` (TypeConverters) [D]:
`stringListToJson/jsonToStringList` (List\<String\>), `glossesToJson/jsonToGlosses` (List\<WordGlossEmbedded\>),
`grammarExamplesToJson/jsonToGrammarExamples`, `listeningLinesToJson/jsonToListeningLines`,
`questionsToJson/jsonToQuestions`, `conversationMessagesToJson/jsonToConversationMessages`,
`conversationMistakesToJson/jsonToConversationMistakes`, `intListToJson/jsonToIntList` (List\<Int\>).

### 9.2 `ContentEntities.kt`

| Entity | table | Поля (порядок оголошення) з типами | PK / індекси [SQL] |
|--------|-------|-----------------------------------|--------------------|
| `TopicEntity` | `topics` | id:String, levelCode:String, titleEs:String, titleUk:String, descriptionUk:String, orderIndex:Int, iconKey:String, grammarTags:List\<String\> | PK(`id`); index `levelCode`, `orderIndex` |
| `WordEntity` | `words` | id:String, spanish:String, **lemma:String**, translationUk:String, partOfSpeechCode:String, genderCode:String, plural:String, pronunciation:String, ipaHint:String, exampleEs:String, exampleUk:String, levelCode:String, topicId:String, withArticle:Boolean, grammarTags:List\<String\>, notesUk:String, cognateNoteUk:String, frequencyRank:Int, contentVersion:Int | PK(`id`); index `levelCode`, `topicId`, `partOfSpeechCode`; **UNIQUE** index `spanish` |
| `SentenceEntity` | `sentences` | id:String, spanish:String, translationUk:String, levelCode:String, topicId:String, kindCode:String, grammarTags:List\<String\>, wordIds:List\<String\>, audioHint:String, contentVersion:Int | PK(`id`); index `levelCode`, `topicId`, `kindCode` |
| `GrammarNoteEntity` | `grammar` | id:String, tagCode:String, levelCode:String, titleEs:String, titleUk:String, explanationUk:String, patternUk:String, examples:List\<GrammarExampleEmbedded\>, commonMistakeUk:String, tipForUkSpeakersUk:String, orderIndex:Int, contentVersion:Int | PK(`id`); index `levelCode`, `tagCode`, `orderIndex` |
| `GrammarExampleEmbedded` | (вбудований) | spanish:String, translationUk:String, noteUk:String | — |
| `ExerciseEntity` | `exercises` | id:String, kindCode:String, levelCode:String, topicId:String, grammarTagCode:String, promptUk:String, promptEs:String, answerEs:String, answerUk:String, distractors:List\<String\>, tokens:List\<String\>, gapText:String, gapAnswer:String, relatedWordIds:List\<String\>, relatedSentenceId:String, explanationUk:String, difficulty:Int, contentVersion:Int | PK(`id`); index `kindCode`, `levelCode`, `topicId`, `grammarTagCode` |
| `ListeningItemEntity` | `listening_items` | id:String, levelCode:String, topicId:String, titleEs:String, titleUk:String, kindCode:String, lines:List\<ListeningLineEmbedded\>, keyWords:List\<WordGlossEmbedded\>, comprehensionQuestions:List\<ComprehensionQuestionEmbedded\>, orderIndex:Int, contentVersion:Int | PK(`id`); index `levelCode`, `topicId`, `orderIndex` |
| `ListeningLineEmbedded` | (вбудований) | speaker:String, spanish:String, translationUk:String | — |
| `ComprehensionQuestionEmbedded` | (вбудований) | questionUk:String, options:List\<String\>, correctIndex:Int, explanationUk:String | — |
| `WordGlossEmbedded` | (вбудований) | spanish:String, translationUk:String | — |

> `WordGlossEmbedded` використовується лише всередині `ListeningItemEntity.keyWords`; окремої таблиці для глос немає. `WordEntity.lemma` у контенті-джерелі відсутнє (DTO не має такого поля) — див. §12.

### 9.3 `UserEntities.kt`

| Entity | table | Поля (порядок) | PK / індекси [SQL] |
|--------|-------|----------------|--------------------|
| `CardEntity` | `cards` | id:Long, itemType:String, itemId:String, levelCode:String, topicId:String, grammarTags:List\<String\>, stateCode:String, dueAt:Long, intervalDays:Double, intervalMinutes:Int, ease:Double, repetitions:Int, lapses:Int, totalReviews:Int, correctReviews:Int, averageResponseMs:Long, lastReviewedAt:**Long?**, firstSeenAt:Long, suspended:Boolean | PK autoincrement(`id`); index `dueAt`, `itemType`, `itemId`, `stateCode` |
| `ReviewLogEntity` | `review_logs` | id:Long, cardId:Long, itemType:String, itemId:String, gradeValue:Int, correct:Boolean, responseMs:Long, reviewedAt:Long, exerciseKindCode:String, grammarTag:String, topicId:String | PK autoincrement; index `cardId`, `reviewedAt`, `grammarTag` |
| `MistakeStatEntity` | `mistake_stats` | grammarTagCode:String, titleUk:String, attempts:Int, mistakes:Int, lastMistakeAt:**Long?**, recentResults:List\<Int\>, levelCode:String | PK(`grammarTagCode`); index `grammarTagCode` |
| `MistakeEntryEntity` | `mistake_entries` | id:Long, kindCode:String, wrongText:String, correctText:String, explanationUk:String, grammarTagCode:String, createdAt:Long, resolved:Boolean | PK autoincrement; index `kindCode`, `createdAt` |
| `TopicProgressEntity` | `topic_progress` | topicId:String, levelCode:String, lessonsCompleted:Int, totalLessons:Int, wordsIntroduced:Int, lastStudiedAt:**Long?**, completedAt:**Long?** | PK(`topicId`); index `topicId` |
| `DailyStatEntity` | `daily_stats` | dayEpoch:Long, minutes:Int, reviews:Int, newWords:Int, speakingAttempts:Int, listeningMinutes:Int, exercisesDone:Int, correctAnswers:Int, totalAnswers:Int | PK(`dayEpoch`); index `dayEpoch` |
| `ConversationEntity` | `conversations` | id:Long, scenarioCode:String, modeCode:String, titleUk:String, startedAt:Long, finishedAt:**Long?**, messages:List\<ConversationMessageEmbedded\>, mistakes:List\<ConversationMistakeEmbedded\> | PK autoincrement; index `startedAt` |
| `ConversationMessageEmbedded` | (вбудований) | fromUser:Boolean, spanish:String, hintUk:String, timestamp:Long | — |
| `ConversationMistakeEmbedded` | (вбудований) | wrongText:String, correctText:String, explanationUk:String | — |
| `SettingEntity` | `settings` | key:String, value:String | PK(`key`) |
| `UserProfileEntity` | `user_profile` | id:Int, name:String, levelCode:String, assessmentDone:Boolean, assessmentScore:Int, goalCode:String, dailyMinutes:Int, startedAt:Long, themeMode:String, ttsVoiceGender:String, ttsRate:Float, showListeningHints:Boolean, allowExternalAi:Boolean, aiProviderId:String, aiEndpoint:String, aiApiKey:String, aiModel:String, **dailyGoalStreak:Int** | PK(`id`); `SINGLE_PROFILE_ID = 0` (єдиний рядок; у `toEntity` передається 0) |

`UserProfileEntity` — єдина entity з дефолтами [D]:
`id=0, name="", levelCode="A0", assessmentDone=false, assessmentScore=0, goalCode="travel", dailyMinutes=20, startedAt=System.currentTimeMillis(), themeMode="system", ttsVoiceGender="female", ttsRate=1.0f, showListeningHints=false, allowExternalAi=false, aiProviderId="local", aiEndpoint="", aiApiKey="", aiModel="", dailyGoalStreak=0`.

`ConversationEntity` має дефолт лише для `id = 0L` [D]. `ConversationMessageEmbedded`, `ConversationMistakeEmbedded`, `ListeningLineEmbedded`, `WordGlossEmbedded` — без дефолтів.

`CardEntity` ↔ `CardState` (домен): `stateCode` = `CardPhase.code`, `itemType` ∈ {`word`, `sentence`, `exercise`} (константи `CardState.ITEM_WORD/ITEM_SENTENCE/ITEM_EXERCISE`) [D].

---

## 10. Суміжні моделі (не входили у запит, але потрібні для порту)

| Клас | Поля (порядок) | Примітки |
|------|----------------|----------|
| `CardState` (learning/srs, **data class, не enum**) | id:Long=0, itemType:String="word", itemId:String="", levelCode:String="A0", topicId:String="", grammarTags:List\<String\>=emptyList(), phase:CardPhase=NEW, dueAt:Long=0, intervalDays:Double=0.0, intervalMinutes:Int=0, ease:Double=2.5, repetitions:Int=0, lapses:Int=0, totalReviews:Int=0, correctReviews:Int=0, averageResponseMs:Long=0, lastReviewedAt:Long?=null, firstSeenAt:Long=0, suspended:Boolean=false, contentVersion:Int=1 | + `isNew`, `isDue`, `accuracyPercent`, статики `ITEM_WORD/ITEM_SENTENCE/ITEM_EXERCISE` |
| `GradePreview` | grade:Grade, intervalLabel:String | без дефолтів |
| `AnswerCheck` | correct:Boolean, expected:String, explanationUk:String, grade:Grade, issues:List\<PronunciationIssue\> | learning/session |
| `SessionBlock` | kind:SessionBlockKind, minutes:Int, titleUk:String, items:List\<StudyItem\> | |
| `SessionPlan` | totalMinutes:Int, blocks:List\<SessionBlock\>, reasonUk:String | |
| `StudyItem` (sealed) | `WordItem(word: Word, isNew: Boolean)`, `SentenceItem(sentence: Sentence)`, `GrammarItem(note: GrammarNote)`, `ListeningItemRef(item: ListeningItem)`, `ExerciseItem(exercise: Exercise)` | без дефолтів |
| `SessionStep` (sealed) | `WordIntro(id, blockKind, word)`, `Flashcard(id, blockKind, card: CardState, frontEs, frontUk, backEs, backUk, exampleEs, exampleUk, genderNoteUk, cognateNoteUk, pronunciation, askSpanish:Boolean)`, `GrammarStep(id, blockKind, note)`, `ListeningStep(id, blockKind, item)`, `ExerciseStep(id, blockKind, exercise)`, `Summary(id, answered:Int, correct:Int, minutes:Int, newWords:Int, weakTags:List\<GrammarTag\>)` | усі мають `id` |
| `LessonBuilder.ActivityAllocation` | reviewMinutes, newWordsMinutes, grammarMinutes, exerciseMinutes, listeningMinutes, speakingMinutes, listeningItems, speakingItems, exerciseItems (усі Int) | |
| `MistakeTracker.WeakSpot` | tag:GrammarTag, stat:MistakeStatEntity, mastery:Int | константи `RECENT_WINDOW = 10`, `WEAK_THRESHOLD = 70` |
| `AIMessage` | fromUser:Boolean, spanish:String, hintUk:String | ai |
| `AICorrection` | wrongText:String, correctText:String, explanationUk:String | ai |
| `AIRequest` | mode:AIConversationMode, scenario:AIScenario, level:Level, history:List\<AIMessage\>, topicTitleUk:String, focusWords:List\<String\> | ai |
| `AIResponse` | spanish:String, hintUk:String, corrections:List\<AICorrection\>, error:String | ai |
| `PronunciationIssue` | type:IssueType, expectedWord:String, heardWord:String, explanationUk:String | |
| `PronunciationResult` | score:Int, wordAccuracy:Int, phoneticScore:Int, fluencyScore:Int, issues:List\<PronunciationIssue\>, suggestions:List\<String\>, heardText:String, expectedText:String | |
| `ContentValidator.Result` | pack:ContentPack, errors:List\<String\>, warnings:List\<String\> | |
| `PlacementTest.Question` | id:String, kind:ExerciseKind, level:Level, promptUk:String, stimulusEs:String, options:List\<String\>, correctOption:Int, correctAnswer:String, tokens:List\<String\>, tag:GrammarTag, weight:Int, explanationUk:String, isAudio:Boolean | |
| `PlacementTest.TestResult` | score:Int, maxScore:Int, percent:Int, level:Level, byLevel:Map\<Level,Int\>, wrongTags:List\<GrammarTag\> | + обчислюване `weakAreasUk` |

### 10.1 Бекапи прогресу (`ProgressBackup.kt`, `@Serializable`) [D]

`ProgressBackup`: `formatVersion:Int`, `exportedAt:Long`, `appVersion:String`, `contentVersion:Int`, `profile:ProfileBackup`, `cards:List<CardBackup>`, `dailyStats:List<DailyStatBackup>`, `mistakeStats:List<MistakeStatBackup>`, `mistakes:List<MistakeBackup>`, `conversations:List<ConversationBackup>`; константа `FORMAT_VERSION = 1`. JSON-ключі = імена полів (дескриптори без `@SerialName`). Серіалізація: `Json { prettyPrint = true; ignoreUnknownKeys = true; encodeDefaults = true }`.

`ProfileBackup`: name, levelCode, assessmentDone, assessmentScore, goalCode, dailyMinutes, startedAt, themeMode, ttsVoiceGender, ttsRate, showListeningHints (без AI-полів і без `dailyGoalStreak`).
`CardBackup`: itemType, itemId, levelCode, topicId, grammarTags, stateCode, dueAt, intervalDays, intervalMinutes, ease, repetitions, lapses, totalReviews, correctReviews, averageResponseMs, lastReviewedAt, firstSeenAt, suspended.
`MistakeStatBackup`: grammarTagCode, titleUk, attempts, mistakes, lastMistakeAt, recentResults, levelCode.
`MistakeBackup`: kindCode, wrongText, correctText, explanationUk, grammarTagCode, createdAt.
`DailyStatBackup`: dayEpoch, minutes, reviews, newWords, speakingAttempts, listeningMinutes, exercisesDone, correctAnswers, totalAnswers.
`ConversationBackup`: scenarioCode, modeCode, titleUk, startedAt, finishedAt, messageCount (агрегат, без реплік).
`ExportReport`: success, messageUk, fileName, bytes. `ImportReport`: success, messageUk, cardsImported, daysImported, mistakesImported, profileImported, warnings.

---

## 11. Фактичний контент: формати, значення, статистика [J]

Обсяг: topics 24, words 1492, sentences 432, exercises 466, grammar 34, listening 22.

### 11.1 Формати ідентифікаторів

| Сутність | Формат | Приклади |
|----------|--------|----------|
| Topic | `t_<level>_<slug>` | `t_a0_greetings`, `t_a0_numbers_0_20`, `t_a1_weather_seasons`, `t_a2_city_directions` |
| Word | `w_<level>_<slug>` | `w_a0_hola`, `w_a0_buenos_dias` |
| Sentence | `s_<level>_NNN` | `s_a0_001` … |
| Exercise | `e_<level>_NNN` | `e_a0_001` … |
| Grammar | `g_<level>_<tag-code>` | `g_a0_articles`, `g_a0_gender_number`, `g_a0_numbers`, `g_a0_spelling` |
| Listening | `l_<level>_NNN` | `l_a0_001` … `l_a2_008` |

Зв'язки: `word.topicId` / `sentence.topicId` / `exercise.topicId` / `listening.topicId` → `topics.id`; `sentence.wordIds[]` → `words.id`; `exercise.relatedWordIds[]` → `words.id`; `exercise.relatedSentenceId` → `sentences.id`; `exercise.grammarTag` / `grammar.tag` → `GrammarTag.code`.

`contentVersion = 1` у всіх 17 файлах.

### 11.2 `iconKey` — повний перелік значень у контенті (23 унікальні, 24 теми)

`greetings`, `person`, `polite`, `numbers` (2 теми), `verbs`, `survival`, `clock`, `family`, `food`, `home`, `shopping`, `weather`, `hobby`, `restaurant`, `transport`, `travel`, `health`, `work`, `errands`, `past`, `city`, `opinion`, `tech`.

Мапінг тема → `iconKey`:

| topicId | iconKey | | topicId | iconKey |
|---|---|---|---|---|
| t_a0_greetings | greetings | | t_a1_hobbies | hobby |
| t_a0_introductions | person | | t_a2_restaurant | restaurant |
| t_a0_courtesy | polite | | t_a2_transport | transport |
| t_a0_numbers_0_20 | numbers | | t_a2_travel | travel |
| t_a0_basic_verbs | verbs | | t_a2_health | health |
| t_a0_survival | survival | | t_a2_work | work |
| t_a1_numbers_big | numbers | | t_a2_daily_errands | errands |
| t_a1_time_days | clock | | t_a2_past_experiences | past |
| t_a1_family | family | | t_a2_city_directions | city |
| t_a1_food_drink | food | | t_a2_opinions | opinion |
| t_a1_home | home | | t_a2_technology | tech |
| t_a1_shopping | shopping | | | |
| t_a1_weather_seasons | weather | | | |

`iconKey` у коді — **звичайний `String`** (немає enum, немає `when`-мапінгу в UI: єдине місце, де він читається, — `ContentValidator`, де перевіряється непорожність). Дефолт у DTO: `"topic"`.

### 11.3 Значення полів, які реально зустрічаються

* `words.level` ∈ {A0, A1, A2}; `words.partOfSpeech` ∈ {adjective, adverb, interjection, noun, numeral, phrase, preposition, pronoun, verb}; `words.gender` ∈ {f, m, mf, none}; `withArticle`: true 695 / false 797; `frequencyRank` ∈ [4 … 950].
* Порожні рядки в контенті (тобто дефолти працюють): `plural` — 704 з 1492; `cognateNoteUk` — 1079; `notesUk` — 441; `ipaHint` — 0; `pronunciation` — 0; `exampleEs`/`exampleUk` — 0.
* `sentences.kind` ∈ {dialogue, phrase, story}; `audioHint` непорожній у всіх 432; `wordIds` непорожній у всіх (макс. 1069 id в одному реченні — «word soup» для довгих текстів).
* `exercises.kind` — усі 9 значень; `difficulty` ∈ {1,2,3,4}.
* `listening.kind` ∈ {dialogue, monologue, podcast, story}; `lines[].speaker` ∈ {A, B}; `comprehensionQuestions[]` — 2–3 питання на айтем.
* `topics.orderIndex` — наскрізна нумерація в межах рівня (1..6 / 1..8 / 1..10); `topics.grammarTags` — 3–4 теги на тему.
* `grammar.orderIndex` — довільні числа (напр. 10 для `g_a0_articles`).

### 11.4 Правила валідації контенту (`ContentValidator.validate`) [D]

Текст помилок (українською) показує інваріанти, які варто зберегти в iOS:
`Немає жодної теми (topics порожній).`, `Дубль теми: `, `Дубль слова (id): `, `Дубль іспанського слова: ` (порівняння через `toLowerCase`), `: невідома тема`, `: порожній переклад`, `: порожнє spanish`, `Дубль речення (id): `, `: невідомі слова`, `Дубль граматики (id): `, `: порожній заголовок`, `: немає пояснення`, `: немає прикладів`, `Дубль вправи (id): `, ` ( ) : немає відповіді`, `: потрібно щонайменше 2 варіанти-дистрактори`, `: немає слів-плиток`, `___`, `: у gapText немає позначки ___`, `Дубль слухання (id): `, `: немає реплік`, `: порожні репліки`, `: питання без варіантів`, `: correctIndex поза межами варіантів`, `Після перевірки не залишилося жодного слова.`

Додатково: `ContentValidator.hasEnoughContent(kind, level, topicId, tag): Boolean`, `duplicates(list): List<String>`.

---

## 12. Невідоме / неточне + пропозиції для Swift

| # | Що не встановлено точно | Що відомо | Пропозиція для Swift |
|---|--------------------------|-----------|----------------------|
| 1 | `WordEntity.lemma` — звідки береться | У `words` (SQL) є колонка `lemma TEXT NOT NULL`, у `WordDto`/`Word` такого поля **немає** | Додати `lemma: String = ""` в `WordEntity`/`WordRecord`; заповнювати `""` або `spanish`, якщо колонка потрібна для сумісності з імпортом БД |
| 2 | `contentVersion` у доменних моделях | Є в DTO (`ContentPackDto`), у entity (`WordEntity`, `SentenceEntity`, `GrammarNoteEntity`, `ExerciseEntity`, `ListeningItemEntity`) — але **немає** в `Word`/`Sentence`/... | Зберігати `contentVersion` лише на рівні запису БД/DTO; у доменних структурах не потрібен |
| 3 | `UserProfile.dailyGoalStreak` | Колонка в `user_profile` є, у `UserProfile` (домен) — немає; де оновлюється — не встановлено | Окреме поле `dailyGoalStreak: Int = 0` у `UserProfileRecord`; логіку стріку — окремо (не з'ясовано) |
| 4 | Ключі таблиці `settings` | Таблиця `settings(key, value)`; конкретні ключі (`putSetting`/`setting`) не відновлені | Використовувати словник `[String: String]`; ключі визначити під час реалізації екранів |
| 5 | Точний вміст `Level.mvpLevels`/`all` у UI | `mvpLevels = [A0, A1, A2]`, `all = entries` | Повторити як `static let mvpLevels: [Level] = [.a0, .a1, .a2]` |
| 6 | `ListeningItem.lines` — обов'язкове поле в домені | У DTO `lines` має дефолт `emptyList()`, у доменній моделі дефолту немає (біт 6 маски не виставлений), `keyWords`/`comprehensionQuestions` — мають | У Swift зробити `lines: [ListeningLine] = []` (простіше й безпечніше), зазначивши відмінність від Kotlin |
| 7 | `Gender.fromCode` приймає `String?` | Параметр nullable (без `checkNotNullParameter`), порівняння без урахування регістру, fallback `NONE` | `static func fromCode(_ code: String?) -> Gender` |
| 8 | `iconKey` → іконка | У Kotlin `iconKey` ніде не мапиться на іконку (лише валідується) | У Swift завести `enum TopicIcon: String` з 23 кейсів + `case unknown` → SF Symbol |
| 9 | Порядок полів `StudyItem.WordItem` | Конструктор `(Word, Z)` → `word`, `isNew`; `toString` у дизасемблі не дав рядків | `case word(word: Word, isNew: Bool)` |
| 10 | `ComprehensionQuestion` у домені: `options`/`correctIndex` без дефолтів | У DTO — мають дефолти (`emptyList()`, `0`) | У Swift дефолти за DTO |
| 11 | `MistakeEntryEntity.kindCode` — який enum | Поле є, але відповідного enum не знайдено (можливо `ExerciseKind.code`) | Уточнити; тимчасово `String` |
| 12 | `ConversationEntity.modeCode` / `scenarioCode` | Майже напевно `AIConversationMode.code` / `AIScenario.code` (є `fromCode`) | Використовувати ці enum-и |
| 13 | Локалізація `titleUk`-рядків | Усі підписи зашиті в код (українською), у enum-ах | Перенести як `uk`-рядки безпосередньо (не в `.strings`, якщо потрібна 1:1 відповідність) |
| 14 | Точні `themeMode`/`goalCode` у БД vs домен | Підтверджено мапінг `code ↔ *Code` (`UserProfileKt.toEntity/toDomain`) | Використовувати `rawValue`-коди |
| 15 | `Sentence.wordIds` до 1069 елементів | Обмежень у коді не знайдено | Не обмежувати в Swift |

### 12.1 Рекомендована структура Swift-моделей

* Enum-и з кодом: `enum Level: String, Codable, CaseIterable { case a0 = "A0", a1 = "A1", a2 = "A2", b1 = "B1", b2 = "B2" }` + окремі `titleUk`, `descriptionUk` у `extension` (щоб `rawValue` = код).
* Enum-и без коду (`IssueType`, `WordFilter`, `AiPhase`, `Step`, `PronunciationScorer.Operation`) — звичайні `String`-enum без `rawValue`-семантики.
* `Grade` — `enum Grade: Int, Codable { case again = 0, hard = 1, good = 2, easy = 3 }` + `titleUk`, `symbol`.
* DTO контенту: `struct WordDto: Decodable` з точно такими ж іменами полів і `init(from:)`-дефолтами (Swift не має дефолтів для відсутніх ключів → або `decodeIfPresent ?? default`, або власний `CodingKeys` + extension). Рекомендую `decodeIfPresent` з тими самими дефолтами, що в §7.
* `Gender.article: String?`, `CardState.lastReviewedAt: Int64?`, `MistakeStatEntity.lastMistakeAt: Int64?`, `TopicProgressEntity.lastStudiedAt/completedAt: Int64?`, `ConversationEntity.finishedAt: Int64?` — єдині nullable-поля в усій схемі.
