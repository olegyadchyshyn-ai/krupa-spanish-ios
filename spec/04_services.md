# 04. Сервіси та дані застосунку `ua.krupa.spanish` (специфікація для порту на Swift / iOS 17)

Джерела (усі твердження нижче — з них):
- `_recon/strings_by_class.txt` — рядкові константи за класами;
- байткод: `C:\Users\olegy\AppData\Local\Temp\dsh-ctDS1R\krupa_ios\disasm\classesN.txt` (baksmali-дамп, N=2..17; `classes18/19` не дизасембльовані);
- `content_from_apk/*.json`, `_apk_extract/AndroidManifest.xml`.

Позначки: **[точно]** — видно безпосередньо в байткоді/рядках; **[частково]** — відновлено не все; **[невідомо]** — даних немає.

Витяги класів, на які спирається цей документ, лежать у `spec/_work/classes/` (див. `spec/_work/extract.ps1`, `spec/_work/class_index.csv`).

---

## A. TTS — `speech/tts/SpanishTtsEngine.kt`, `TtsState`

### A.1 Клас `SpanishTtsEngine` **[точно]**

Поля/константи (з `<clinit>` і списку полів):

| Елемент | Тип | Значення |
|---|---|---|
| `SPANISH_TAG` | String, `public static final` | `"es-ES"` |
| `INIT_TIMEOUT_MS` | Long, `public static final` | `8000` |
| `FEMALE_MARKERS` | `List<String>`, private static final | `["female", "-f-", "f00", "sfg", "esf", "woman", "mujer"]` |
| `MALE_MARKERS` | `List<String>`, private static final | `["male", "-m-", "m00", "sfg", "esm", "man", "hombre"]` |
| `tts` | `android.speech.tts.TextToSpeech?` | створюється в `initialize()` |
| `initDeferred` | `CompletableDeferred<Boolean>?` | створюється в `initialize()` |
| `completionDeferred` | `Map<String, CompletableDeferred<Unit>>` (`LinkedHashMap`) | ключ — utteranceId |
| `_state` / `state` | `MutableStateFlow<TtsState>` / `StateFlow<TtsState>` | початковий `TtsState(...)` = усі поля за замовчуванням (маска `0x1FF`) |

Реєстр маркерів **нечутливий до регістру**: `voice.name.toLowerCase(Locale.ROOT).contains(marker)` (виклик `StringsKt.contains(..., ignoreCase=false)`, але обидві сторони вже в нижньому регістрі).

### A.2 `TtsState` (data class) **[точно]**

Порядок оголошення (= порядок `toString`, `component1..9`):

```kotlin
data class TtsState(
    val ready: Boolean,
    val spanishAvailable: Boolean,
    val hasFemaleVoice: Boolean,
    val hasMaleVoice: Boolean,
    val selectedGender: VoiceGender,
    val rate: Float,
    val error: String? = null,        // єдиний параметр із default (маска 0x40)
    val maleVoiceName: String? = null,
    val femaleVoiceName: String? = null,
)
```
`toString`: `TtsState(ready=…, spanishAvailable=…, hasFemaleVoice=…, hasMaleVoice=…, selectedGender=…, rate=…, error=…, maleVoiceName=…, femaleVoiceName=…)`

### A.3 `VoiceGender` (enum) **[точно]**

```kotlin
enum class VoiceGender(val code: String, val titleUk: String) {
    FEMALE("female", "Жіночий голос"),   // ordinal 0
    MALE("male", "Чоловічий голос"),     // ordinal 1
}
```
`Companion`: `fromCode(code)` — пошук за `code`; також експонуються `FEMALE_MARKERS`/`MALE_MARKERS`.

### A.4 `initialize()` **[точно]**

```kotlin
suspend fun initialize(): Boolean {
    if (tts != null || state.value.ready) return true        // рядок 38
    initDeferred = CompletableDeferred()                      // 39
    _state.update { it.copy(error = null) }                   // 40 (маска 0x1BE → задається лише error)
    tts = TextToSpeech(context, OnInitListener { status ->    // 43
        if (status == TextToSpeech.SUCCESS) { configureEngine(); initDeferred?.complete(true) }
        else { _state.update { it.copy(error = "Системний синтез мовлення недоступний.") }; initDeferred?.complete(false) }
    })
    return withTimeoutOrNull(INIT_TIMEOUT_MS) { deferred.await() } ?: false   // 52, 8000 мс
}
```

### A.5 `configureEngine()` **[точно]**

```kotlin
private fun configureEngine() {
    val engine = tts ?: return
    engine.setOnUtteranceProgressListener(listener)                       // рядок 57
    val availability = engine.isLanguageAvailable(Locale.forLanguageTag("es-ES"))   // 79
    val langAvailable = availability == LANG_AVAILABLE(0) || availability == LANG_COUNTRY_AVAILABLE(1)
                        || availability == LANG_COUNTRY_VAR_AVAILABLE(2)  // 80–82
    val voices = runCatching { engine.voices?.toList() ?: emptyList() }.getOrDefault(emptyList())  // 84–85
    val spanishVoices = voices.filter { it.locale.language == "spa" }     // 86  (мова саме "spa", не "es")
    val offlineVoices = spanishVoices.filterNot { it.isNetworkConnectionRequired }   // 87
    val sorted = offlineVoices.sortedBy { /* компаратор Comparisons.kt: sortedBy */ }  // 89
    val female = sorted.firstOrNull { v -> FEMALE_MARKERS.any { m -> v.name.lowercase(ROOT).contains(m) } }  // 89
    val male   = sorted.firstOrNull { v -> MALE_MARKERS.any  { m -> v.name.lowercase(ROOT).contains(m) } }  // 90
    engine.setLanguage(Locale.forLanguageTag("es-ES"))                    // 92
    _state.value = TtsState(                                              // 93
        ready = true,                                                     // 94
        spanishAvailable = langAvailable || voices.isNotEmpty(),          // 95
        hasFemaleVoice = female != null || voices.isEmpty(),              // 96  ← див. примітку
        hasMaleVoice = male != null,                                      // 97
        selectedGender = current.selectedGender,                          // 98
        rate = current.rate,                                              // 99
        maleVoiceName = male?.name,                                       // 100
        femaleVoiceName = female?.name,                                   // 101
        // error не передається (default null)                            // —
    )
    applyVoice()                                                          // 103
}
```
**Примітка (важливо, не вигадка):** у байткоді гілка `hasFemaleVoice` — це `female != null || voices.isEmpty()` (перевірка `if-nez v4 → true`, далі `voices.isEmpty()`), тоді як `hasMaleVoice` — просто `male != null`. Асиметрія виглядає як особливість оригіналу; для iOS логічно реалізувати симетрично `!= null`, але це відхилення від Android-поведінки.

`sortedBy`-компаратор: `SpanishTtsEngine$configureEngine$$inlined$sortedBy$1` (файл `Comparisons.kt`) — ключ сортування у байткоді явно не видно; **[частково]** ймовірно `it.name`, не підтверджено.

### A.6 `applyVoice()` **[точно]** (рядки 120–135)

```kotlin
private fun applyVoice() {
    val engine = tts ?: return
    val current = _state.value
    val desiredName = when (current.selectedGender) {
        VoiceGender.MALE -> current.maleVoiceName
        VoiceGender.FEMALE -> current.femaleVoiceName
    }
    val voice = runCatching { engine.voices?.firstOrNull { it.name == desiredName } }.getOrNull()
    if (voice != null) runCatching { engine.setVoice(voice) }
    else runCatching { engine.setLanguage(Locale.forLanguageTag("es-ES")) }
    engine.setSpeechRate(current.rate)
}
```

### A.7 `setRate`, `setVoiceGender` **[точно]**

```kotlin
fun setRate(rate: Float) {                       // рядок 114
    val clamped = rate.coerceIn(0.5f, 1.5f)      // 0x3F00 = 0.5f, 0x3FC0 = 1.5f   (115)
    tts?.setSpeechRate(clamped)                  // 115
    _state.update { it.copy(rate = clamped) }    // 116
}
fun setVoiceGender(gender: VoiceGender) {        // 108
    _state.update { it.copy(selectedGender = gender) }   // 108
    applyVoice()                                 // 109
}
```
**rate: діапазон 0.5…1.5, значення за замовчуванням — `TtsState.rate` = `0.0f`** (конструктор за замовчуванням передає `F` = 0). `pitch` і `volume` у класі **відсутні** — TTS-движок викликає лише `setSpeechRate` (див. `applyVoice`).

### A.8 `speak(text, force = true)` **[точно]** (рядки 138–155)

```kotlin
suspend fun speak(text: String, force: Boolean = true): Boolean {
    if (text.isBlank()) return false                                  // 139
    if (tts == null || !state.value.ready) { if (!initialize()) return false }   // 140–141
    val engine = tts ?: return false                                  // 143
    val id = UUID.randomUUID().toString()                             // 144
    val deferred = CompletableDeferred<Unit>()                        // 145
    completionDeferred[id] = deferred                                 // 146
    val mode = if (force) TextToSpeech.QUEUE_FLUSH else TextToSpeech.QUEUE_ADD   // 147 (0 / 1)
    val result = engine.speak(text, mode, null, id)                   // 148
    if (result != TextToSpeech.SUCCESS) { completionDeferred.remove(id); return false }  // 149–151
    withTimeoutOrNull(speechTimeout(text)) { deferred.await() }       // 153
    completionDeferred.remove(id)                                     // 154
    return true                                                       // 155
}
```
`speak()` повертає `true`, якщо озвучення поставлено в чергу (навіть якщо спрацював таймаут; `?: false` у байткоді **відсутній**).

```kotlin
private fun speechTimeout(text: String): Long =                 // рядок 179
    (text.length.toLong() * 90L + 1500L).coerceAtMost(20000L)   // 90 мс/символ + 1500, максимум 20 000 мс
```

`speakAsync(text)` (рядки 160–163): якщо `text.isBlank()` → return; `tts ?: return`; `engine.speak(text, QUEUE_FLUSH, null, UUID.randomUUID().toString())` — без очікування.

`stop()` (166–169): `runCatching { tts?.stop() }`; `completionDeferred.values.forEach { it.complete(Unit) }`; `completionDeferred.clear()`.

`shutdown()` (172–176): `stop()`; `runCatching { tts?.shutdown() }`; `tts = null`; `_state.update { it.copy(ready = false) }`.

### A.9 Слухач прогресу `UtteranceProgressListener` **[точно]** (рядки 57–74)

`onDone(id)`, `onError(id)`, `onError(id, errorCode)`, `onStop(id, interrupted)` → `completionDeferred.remove(id)?.complete(Unit)`.
`onStart(id)` — порожній (no-op).

### A.10 Ключі налаштувань TTS

Зберігаються в `user_profile` (див. E): `ttsVoiceGender TEXT NOT NULL`, `ttsRate REAL NOT NULL`. Значення `ttsVoiceGender` = `VoiceGender.code` (`"female"`/`"male"`). Значення за замовчуванням **[частково]**: `ProfileBackup` показує `ttsVoiceGender` = `female` як один зі значень; дефолт `ttsRate` — не підтверджено (див. «Невідоме»).

---

## B. Розпізнавання мовлення — `speech/recognition/SpanishSpeechRecognizer.kt`

### B.1 Публічний API **[точно]**

```kotlin
class SpanishSpeechRecognizer(private val context: Context) {
    val hasPermission: Boolean                       // рядок 45
    fun isAvailable(): Boolean                        // 42
    fun spanishModelAvailable(): Boolean              // 49
    fun listen(locale: Locale = Locale.forLanguageTag("es-ES"),
               partialResults: Boolean = true,
               silenceMs: Long = 1500L): Flow<Event>  // 57–60, callbackFlow
}
```
- `hasPermission` = `ContextCompat.checkSelfPermission(context, "android.permission.RECORD_AUDIO") == PackageManager.PERMISSION_GRANTED`.
- `isAvailable()` = `SpeechRecognizer.isRecognitionAvailable(context)`.
- `spanishModelAvailable()` = `runCatching { SpeechRecognizer.isRecognitionAvailable(context) }.getOrDefault(false)`.
- `listen(...)` = `callbackFlow { ... }`.

### B.2 Intent розпізнавання **[точно]** (рядки 73–84)

| Extra | Значення |
|---|---|
| `RecognizerIntent.ACTION_RECOGNIZE_SPEECH` | action intent |
| `android.speech.extra.LANGUAGE_MODEL` | `"free_form"` |
| `android.speech.extra.LANGUAGE` | `locale.toLanguageTag()` (`"es-ES"`) |
| `android.speech.extra.LANGUAGE_PREFERENCE` | `locale.toLanguageTag()` |
| `android.speech.extra.ONLY_RETURN_LANGUAGE_PREFERENCE` | `false` |
| `android.speech.extra.PARTIAL_RESULTS` | `partialResults` (default `true`) |
| `android.speech.extra.MAX_RESULTS` | `3` |
| `calling_package` | `context.packageName` |
| `android.speech.extras.SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS` | `silenceMs` (default `1500`) |
| `android.speech.extras.SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS` | `silenceMs` |

Порядок у потоці (рядки 62–86): 1) `isAvailable()` → якщо ні: `Event.Failed("У системі немає сервісу розпізнавання мовлення.", errorCode = 0)` і `close()`;
2) `hasPermission` → якщо ні: `Event.Failed("Немає дозволу на мікрофон.", 0)` і `close()`;
3) `SpeechRecognizer.createSpeechRecognizer(context)`, `setRecognitionListener(listener)`, `startListening(intent)`;
4) `awaitClose { runCatching { recognizer.stopListening() }; runCatching { recognizer.cancel() }; runCatching { recognizer.destroy() } }` (рядки 138–141).

### B.3 Події та `RecognitionListener` **[точно]**

```kotlin
sealed interface Event {
    data object Ready : Event                         // onReadyForSpeech
    data object ListeningStarted : Event              // onBeginningOfSpeech
    data class Amplitude(val rms: Float) : Event      // onRmsChanged(rmsdB)
    data class Partial(val text: String) : Event      // onPartialResults
    data class Final(val result: Result) : Event      // onResults
    data class Failed(val reasonUk: String, val errorCode: Int) : Event   // onError
}
data class Result(val text: String, val alternatives: List<String>, val confidence: Float)
```
- `onBufferReceived`, `onEndOfSpeech`, `onEvent` — no-op.
- `onRmsChanged(rmsdB)` → `Event.Amplitude(rms = rmsdB)` (без фільтрації/нормалізації).
- `onPartialResults(bundle)`: `bundle.getStringArrayList("results_recognition")?.firstOrNull()?.takeIf { it.isNotBlank() }?.let { Event.Partial(it) }` (рядки 129–131).
- `onResults(bundle)` (рядки 109–126):
  ```kotlin
  val list = bundle?.getStringArrayList("results_recognition") ?: emptyList()
  val confidences = bundle?.getFloatArray("confidence_scores")
  val best = list.firstOrNull() ?: ""
  if (best.isBlank()) trySend(Event.Failed("Не вдалося розпізнати мовлення. Спробуйте ще раз.", 0, …))
  else trySend(Event.Final(Result(text = best, alternatives = list,
                                  confidence = confidences?.firstOrNull() ?: -1.0f)))   // 0xBF80 = -1.0f
  close()
  ```
- `onError(error)`: `trySend(Event.Failed(describeError(error), error)); close()`.

### B.4 `describeError(error: Int)` **[точно]** (рядки 145–156)

`when (error)` за кодовами `SpeechRecognizer` (ключі packed-switch 1..9; порядок рядків у джерелі 146→154):

| Код | Константа | Текст (дослівно) |
|---|---|---|
| 3 | `ERROR_AUDIO` | `Помилка запису звуку. Перевірте мікрофон.` |
| 5 | `ERROR_CLIENT` | `Помилку на боці застосунку. Спробуйте ще раз.` |
| 9 | `ERROR_INSUFFICIENT_PERMISSIONS` | `Немає дозволу на мікрофон.` |
| 2 | `ERROR_NETWORK` | `Потрібен інтернет для розпізнавання.` |
| 1 | `ERROR_NETWORK_TIMEOUT` | `Час очікування мережі минув.` |
| 7 | `ERROR_NO_MATCH` | `Не розчув. Спробуйте сказати чіткіше.` |
| 8 | `ERROR_RECOGNIZER_BUSY` | `Розпізнавач зайнятий. Зачекайте секунду.` |
| 4 | `ERROR_SERVER` | `Сервіс розпізнавання повернув помилку.` |
| 6 | `ERROR_SPEECH_TIMEOUT` | `Не почув жодного слова. Натисніть і говоріть.` |
| інші | — | `"Не вдалося розпізнати мовлення (код " + error + ")."` |

Таймаутів/повторів на рівні класу немає (лише `silenceMs` в intent). Дозволи запитуються на рівні екранів (`AiDialogScreenKt$…$permissionLauncher`, `SpeakingScreen`), не в цьому класі.

---

## C. Оцінка вимови — `speech/pronunciation/*`

### C.1 Константи `PronunciationScorer` **[точно]**

```kotlin
private const val MISSING_PENALTY = 1.0        // (у дампі: value 1)
private const val EXTRA_PENALTY = 0.6
private const val SUBSTITUTION_PENALTY = 1.0
private const val PHONETIC_NEAR_PENALTY = 0.45
private val ACCENT_MARKS = Regex("\\p{Mn}+")
object PronunciationScorer { … }               // INSTANCE (singleton)
```
Поріг «схожості» — `0.72` (inline у `substitutionCost` і в `score`).

### C.2 Типи **[точно]**

```kotlin
enum class IssueType(val titleUk: String) {                    // порядок оголошення
    WRONG_WORD("Неправильне слово"),                           // 0
    MISSING_WORD("Пропущене слово"),                           // 1
    EXTRA_WORD("Зайве слово"),                                 // 2
    PHONETIC_NEAR("Неточна вимова"),                           // 3
    NOTHING_HEARD("Нічого не почуто"),                         // 4
    ARTICLE_AGREEMENT("Артикль не узгоджений"),                // 5
    R_SOUND("Звук r"),                                         // 6
    C_AND_Z("Звуки c / z"),                                    // 7
    J_SOUND("Звук j"),                                         // 8
    B_AND_V("Звуки b / v"),                                    // 9
    SWALLOWED_SYLLABLE("Проковтнутий склад"),                  // 10
}
data class PronunciationIssue(val type: IssueType, val expectedWord: String,
                              val heardWord: String, val explanationUk: String)
data class PronunciationResult(
    val score: Int, val wordAccuracy: Int, val phoneticScore: Int, val fluencyScore: Int,
    val issues: List<PronunciationIssue>, val suggestions: List<String>,
    val heardText: String, val expectedText: String)           // саме такий порядок (toString)
data class Step(val expected: String, val heard: String, val operation: Operation)
enum class Operation { MATCH, SUBSTITUTE, DELETE, INSERT }     // ordinals 0..3
```

### C.3 Головна формула `score()` **[точно]** (рядки 35–54 API, тіло 41–133)

```kotlin
fun score(expected: String, recognized: String,
          elapsedMs: Long = 0L, knownGenders: Map<String, String> = emptyMap()): PronunciationResult
```
1. `expectedTokens = tokenize(expected)`, `heardTokens = tokenize(recognized)`.
2. Якщо `expectedTokens.isEmpty()` → `PronunciationResult(0,0,0,0, emptyList(), listOf("Немає еталонного речення для порівняння."), expectedText = expected, heardText = recognized)`.
3. Якщо `heardTokens.isEmpty()` → `PronunciationResult(0,0,0,0, listOf(PronunciationIssue(NOTHING_HEARD, "", "", "Нічого не розпізнано. Спробуйте говорити ближче до мікрофона й трохи повільніше.")), listOf("Перевірте дозвіл на мікрофон і повторіть спробу."), expected, recognized)`.
4. `steps = align(expectedTokens, heardTokens)`; `penalty = 0.0`; ітерація по `steps`:
   - `INSERT` → `penalty += 0.6`; issue `EXTRA_WORD`, `expectedWord=""`, `heardWord=step.heard`, текст `"Зайве слово «${step.heard}»."`
   - `DELETE` → `penalty += 1.0`; issue `MISSING_WORD`, `expectedWord=step.expected`, `heardWord=""`, текст `"Слово «${step.expected}» не прозвучало."`
   - `SUBSTITUTE`:
     ```kotlin
     val sim = phoneticSimilarity(step.expected, step.heard)
     if (sim >= 0.72) { penalty += 0.45
         issues += PronunciationIssue(PHONETIC_NEAR, expected, heard,
                    "Схоже на «${expected}», але звучання відрізняється. ${phoneticHint(expected)}") }
     else { penalty += 1.0
         issues += PronunciationIssue(classifySubstitution(expected, heard), expected, heard,
                    "Сказано «${heard}» замість «${expected}». ${phoneticHint(expected)}")
         suggestions += phoneticHint(expected) }
     ```
   - `MATCH` → нічого.
5. `issues += articleIssues(expectedTokens, heardTokens, knownGenders)`.
6. **wordAccuracy** (`0..100`):
   ```kotlin
   val total = expectedTokens.size.toDouble()
   val wordAccuracy = (((total - penalty) / total) * 100.0).coerceIn(0.0, 100.0).roundToInt()
   ```
7. **phoneticScore** (`0..100`):
   ```kotlin
   val ep = SpanishPhonetics.phonemize(expectedTokens.joinToString(" "))
   val hp = SpanishPhonetics.phonemize(heardTokens.joinToString(" "))
   val phoneticScore = (100.0 * phoneticSimilarity(ep, hp)).roundToInt().coerceIn(0, 100)
   ```
8. **fluencyScore** = `fluency(heardTokens, elapsedMs, steps)` (див. C.6).
9. **score**:
   ```kotlin
   val score = ((wordAccuracy * 0.55) + (phoneticScore * 0.30) + (fluencyScore * 0.15))
                 .roundToInt().coerceIn(0, 100)
   ```
   Ваги: **0.55 / 0.30 / 0.15** (у байткоді `0x3FE199999999999A`=0.55, `0x3FD3333333333333`=0.30, `0x3FC3333333333333`=0.15).
10. `issues` дедуплікуються: унікальність за парою `(type, expectedWord)` (HashSet + ArrayList, порядок збережено).
11. `suggestions = suggestions.distinct().take(3)`.
12. Повертається `PronunciationResult(score, wordAccuracy, phoneticScore, fluencyScore, uniqueIssues, suggestions, expectedText = expected, heardText = recognized)`.

### C.4 `align(expected, heard)` — зважена відстань Левенштейна **[точно]** (рядки 184–241)

```kotlin
cost[i][0] = i * 1.0                      // MISSING_PENALTY
cost[0][j] = j * 0.6                      // EXTRA_PENALTY
cost[i][j] = minOf(cost[i-1][j] + 1.0,    // DELETE
                   cost[i][j-1] + 0.6,    // INSERT
                   cost[i-1][j-1] + sub)  // sub = 0.0 якщо рядки рівні, інакше substitutionCost(...)
```
Backtracking (ArrayDeque + `addFirst`, тобто список у прямому порядку) з epsilon `1e-9`:
- `|cost[i][j] - (cost[i-1][j-1] + sub)| < 1e-9` → `Step(expected[i-1], heard[j-1], if (same) MATCH else SUBSTITUTE)`, `i--, j--`;
- інакше `|cost[i][j] - (cost[i-1][j] + 1.0)| < 1e-9` → `Step(expected[i-1], "", DELETE)`, `i--`;
- інакше → `Step("", heard[j-1], INSERT)`, `j--`.
Залишок: `DELETE` з `heard=""` для решти `expected`, `INSERT` з `expected=""` для решти `heard`.

```kotlin
private fun substitutionCost(expected: String, heard: String): Double =
    if (phoneticSimilarity(expected, heard) >= 0.72) 0.45 /* PHONETIC_NEAR_PENALTY */ else 1.0
```
`stepPenalty(step)` (рядки 249–254): `MATCH → 0.0`; `DELETE → 1.0`; `INSERT → 0.6`; `SUBSTITUTE → substitutionCost(...)`. *(Гілки `DELETE`/`INSERT` у payload обрізані дампом; віднесення 1.0 до DELETE, 0.6 до INSERT підтверджується такими самими гілками всередині `score()` — там `INSERT` додає 0.6, `DELETE` — 1.0.)*

### C.5 `phoneticSimilarity(a, b)`, `levenshtein`, `tokenize` **[точно]**

```kotlin
fun phoneticSimilarity(a: String, b: String): Double {          // рядки 262–268
    val pa = SpanishPhonetics.phonemize(a); val pb = SpanishPhonetics.phonemize(b)
    if (pa.isEmpty() && pb.isEmpty()) return 1.0
    if (pa.isEmpty() || pb.isEmpty()) return 0.0
    val distance = levenshtein(pa, pb)
    val longest = maxOf(pa.length, pb.length).toDouble()
    return (1.0 - distance / longest).coerceIn(0.0, 1.0)
}
private fun levenshtein(a: String, b: String): Int {            // 272–283, класичний DP, вартості 1/1/1
    if (a == b) return 0
    var prev = IntArray(b.length + 1) { it }; var curr = IntArray(b.length + 1)
    for (i in 1..a.length) { curr[0] = i
        for (j in 1..b.length) { val cost = if (a[i-1] == b[j-1]) 0 else 1
            curr[j] = minOf(curr[j-1] + 1, prev[j] + 1, prev[j-1] + cost) }
        System.arraycopy(curr, 0, prev, 0, curr.size) }
    return prev[b.length]
}
private fun tokenize(text: String): List<String> =              // 394–399
    stripAccents(text)
        .replace(Regex("[¡¿!?.,;:\"«»()\\[\\]…—–-]"), " ")
        .replace(Regex("\\s+"), " ")
        .trim()
        .split(" ")
        .filter { it.isNotBlank() }
private fun stripAccents(text: String) =                        // 391
    Normalizer.normalize(text.lowercase(Locale.ROOT), Normalizer.Form.NFD).replace(ACCENT_MARKS, "")
```
Regex пунктуації для токенізації — **з дефісом у класі**: `[¡¿!?.,;:"«»()\[\]…—–-]`.

### C.6 `fluency(heard, durationMs, alignment)` **[точно]** (рядки 362–378)

```kotlin
val paceScore: Double = if (durationMs <= 0L) 75.0 else {
    val minutes = durationMs / 60000.0
    if (minutes <= 0.0) 75.0 else {
        val wpm = heard.size / minutes
        when {
            wpm < 45.0  -> 55.0
            wpm < 80.0  -> 75.0
            wpm <= 190.0 -> 100.0
            wpm <= 260.0 -> 80.0
            else        -> 60.0
        }
    }
}
val repeats = alignment.count { it.operation == Operation.INSERT }
val repeatPenalty = minOf(25.0, repeats * 6.0)      // 0x4018=6.0, 0x4039=25.0
return (paceScore - repeatPenalty).coerceIn(0.0, 100.0).roundToInt()
```

### C.7 `articleIssues` **[точно]** (рядки 329–354) — правило узгодження артиклів

```kotlin
val articles = setOf("el", "la", "los", "las", "un", "una", "unos", "unas")
for (index in expected.indices) {
    if (index >= heard.size) break
    val exp = expected[index]; val hrd = heard[index]
    if (exp == hrd) continue
    if (!articles.contains(exp) || !articles.contains(hrd)) continue
    val noun = expected.getOrNull(index + 1) ?: ""
    val gender = knownGenders[noun]
        ?: knownGenders.entries.firstOrNull { stripAccents(it.key) == noun }?.value
    val explanation = when (gender) {
        "m" -> "«$noun» — чоловічого роду, тому «$exp», а не «$hrd»."
        "f" -> "«$noun» — жіночого роду, тому «$exp», а не «$hrd»."
        else -> "Артикль має узгоджуватися з родом і числом іменника: «$exp $noun»."
    }
    issues += PronunciationIssue(IssueType.ARTICLE_AGREEMENT, exp, hrd, explanation)
}
```

### C.8 `classifySubstitution(expected, heard)` **[точно]** (рядки 290–300)

```kotlin
val e = SpanishPhonetics.phonemize(expected)
val h = SpanishPhonetics.phonemize(heard)
return when {
    e.isEmpty() || h.isEmpty() -> IssueType.WRONG_WORD
    e[0] != h[0] && (e.contains("р") || h.contains("р")) -> IssueType.R_SOUND
    e.contains("θ") || h.contains("θ") -> IssueType.C_AND_Z
    e.contains("х") || h.contains("х") -> IssueType.J_SOUND
    (e.contains("б") && h.contains("в")) || (e.contains("в") && h.contains("б")) -> IssueType.B_AND_V
    expected.length > heard.length + 2 -> IssueType.SWALLOWED_SYLLABLE
    else -> IssueType.WRONG_WORD
}
```
(це українські літери `р`, `х`, `б`, `в` і грецька `θ` у фонетичному рядку).

### C.9 `phoneticHint(word)` **[точно]** (рядки 306–320) — підказки, дослівно

```kotlin
val lower = word.lowercase(Locale.ROOT)
when {                                                                    // рядок
    lower.contains("ll") -> "«ll» звучить як українське [й]: llave → [йа-ве]."          // 308
    lower.contains("ñ")  -> "«ñ» — це [нь]: año → [а-ньо]."                              // 309
    lower.contains("rr") -> "«rr» — розкотистий, кілька ударів язика: perro."           // 310
    lower.startsWith("r") -> "«r» на початку слова розкотистий: rojo."                   // 311
    lower.contains("j") || (lower.contains("g") && (lower.contains("e") || lower.contains("i"))) ->
        "«j» і «g» перед e/i — це глухий [х]: jugo, gente."                              // 313
    lower.contains("z") || (lower.contains("c") && (lower.contains("e") || lower.contains("i"))) ->
        "В Іспанії «z» і «c» перед e/i — міжзубний [θ], як англійське th у think."       // 315
    lower.contains("v") -> "«v» в іспанській вимовляється майже як «b»: vivo → [бі-бо]." // 317
    lower.contains("h") -> "«h» ніколи не читається: hora → [о-ра]."                     // 318
    lower.contains("que") || lower.contains("qui") -> "«qu» — це просто [к], «u» не читається: quiero → [кʼє-ро]."  // 318
    lower.contains("gue") || lower.contains("gui") -> "«gu» перед e/i — це [ґ], «u» не читається: guerra."          // 319
    else -> "Зверніть увагу на наголос: він змінює значення слова."                       // 320
}
```

### C.10 `SpanishPhonetics` (object) **[точно]**

```kotlin
private val ACCENT_MARKS = Regex("\\p{Mn}+")
private val WHITESPACE = Regex("\\s+")
private val NON_PHONETIC = Regex("[^а-яіїєґйθ]")

fun phonemize(text: String): String {                       // рядки 30–48
    if (text.isBlank()) return ""
    return stripPunctuation(text.lowercase(Locale.ROOT))    // replace("[¡¿!?.,;:\"«»()\\[\\]…—–]", " ")
        .let { Normalizer.normalize(it, Normalizer.Form.NFD) }
        .replace(ACCENT_MARKS, "")
        .let { transliterate(it) }
        .replace(WHITESPACE, "")                            // пробіли ВИДАЛЯЮТЬСЯ
        .replace(NON_PHONETIC, "")                          // лишаються тільки кириличні фонеми + θ
}
fun syllabify(text: String): List<String> =                 // 55–58
    text.lowercase(ROOT).split(Regex("[\\s.,;:!?¡¿]+")).filter { it.isNotBlank() }.map { phonemize(it) }
fun toUkrHint(word: String): String =                       // 19–24
    transliterate(Normalizer.normalize(word.lowercase(ROOT), NFD).replace(ACCENT_MARKS, ""))
```

**Таблиця `mapping(char: Char): Char`** (рядки 92–124; невідомі символи повертаються без змін):

| Вхід | Вихід |  | Вхід | Вихід |
|---|---|---|---|---|
| `a`, `á` | `а` | | `n`, `ñ` | `н` |
| `e`, `é` | `е` | | `p` | `п` |
| `i`, `í` | `і` | | `r` | `р` |
| `y` | `й` | | `s` | `с` |
| `o`, `ó` | `о` | | `t` | `т` |
| `u`, `ú`, `ü` | `у` | | `w` | `в` |
| `b`, `v` | `б` | | `ç` | `θ` |
| `c` | `к` | | `k` | **[частково]** див. примітку |
| `d` | `д` | | `f` | `ф` |
| `g` | `ґ` | | `j` | `х` |
| `l` | `л` | | `m` | `м` |

Примітка: у гілці для `'k'` (код 107) байткод робить `goto` на `return` без присвоєння значення (регістр перевикористано з попередньої гілки) — коректне значення не підтверджене; найімовірніше задумано `'к'`.

**`transliterate(word)`** (рядки 38–89) — прохід по символах `i` з `next = word.getOrNull(i+1)`, `third = word.getOrNull(i+2)`; правила **в порядку перевірки**:

| № | Умова | Дія | Рядки |
|---|---|---|---|
| 1 | `c` + `h` | `+='ч'`, `i += 2` | 45–46 |
| 2 | `l` + `l` | `+='й'`, `i += 2` | 49–50 |
| 3 | `q` + `u` | `+='к'`, `i += 2` | 53–54 |
| 4 | `g` + `u` + (`e`\|`i`) | `+='ґ'`, `i += 2` | 57–58 |
| 5 | `g` + (`e`\|`i`) | `+='х'`, `i += 2` | 61–62 |
| 6 | `c` + (`e`\|`i`) | `+='θ'`, `i += 2` | 65–66 |
| 7 | `z` | `+='θ'`, `i += 1` | 68–69 |
| 8 | `r` + `r` | `+='р'`, `i += 2` | 72–73 |
| 9 | `c` + `'\u00B8'` (184, `¸`) | `+='θ'`, `i += 2` | 76–77 *(виглядає як одруківка в оригіналі; очікувалося, ймовірно, `ç` — не підтверджено)* |
| 10 | `ç` (231) | `+='θ'`, `i += 1` | 79–80 |
| 11 | `h` | нічого не додається, `i += 1` | 82 |
| 12 | інакше | `+= mapping(char)`, `i += 1` | 84 |

### C.11 Підсумкові тексти-підказки результатів (для UI) **[точно]**

```
Відмінна вимова.
Добре. Є дрібні неточності.
Зрозуміло, але варто попрацювати над окремими звуками.
Поки що не схоже на еталон. Послухайте зразок і повторіть за ним.
Спробуйте ще раз, промовляючи повільніше й чіткіше.
```
---

## D. AI-діалоги — `ai/*`, `ui/screens/ai/*`

### D.1 Провайдер: **мережевого HTTP-провайдера НЕМАЄ** **[точно]**

- Єдина реалізація `AIProvider` — `ai/providers/LocalAIProvider` (перевірено пошуком по `Interfaces` у всіх дампах: `classes14.txt` — єдиний клас, що реалізує `Lua/krupa/spanish/ai/AIProvider;`).
- Рядок `"https://api.example.com/v1/chat/completions"` **існує**, але це **статичний текст у UI** екрана налаштувань: `SettingsScreen.kt:306`, клас `ComposableSingletons$SettingsScreenKt$lambda-6$1`, виклик `androidx.compose.material3.TextKt.Text--4IGK_g(...)` (`classes9.txt`, адреса `0x013d92`). Жодних `okhttp`, `HttpURLConnection`, `Bearer`, `Authorization`, `api.openai` у дампах немає.
- `LocalAIProvider`: `id = "local"`, `titleUk = "Локальний викладач (без інтернету)"`, `requiresNetwork = false` (поле не ініціалізується → `false`), `suspend fun isAvailable() = true`.
- **Шаблонів промптів (LLM) у застосунку немає** — офлайн-провайдер працює на скриптах і регулярних виразах, а не на промптах.

### D.2 `AIProvider` (інтерфейс) **[точно]**

```kotlin
interface AIProvider {
    val id: String
    val titleUk: String
    val requiresNetwork: Boolean
    suspend fun isAvailable(): Boolean
    suspend fun reply(request: AIRequest): AIResponse
}
```

### D.3 `AIProviderRegistry` **[точно]** (AIProvider.kt, рядки ~160–172)

```kotlin
class AIProviderRegistry(private val providers: List<AIProvider>) {
    fun all(): List<AIProvider> = providers
    fun byId(id: String): AIProvider? = providers.firstOrNull { it.id == id }
    fun default(): AIProvider = providers.first()
    suspend fun resolve(preferredId: String? = null): AIProvider {
        if (preferredId != null) {
            providers.firstOrNull { it.id == preferredId }?.let { if (it.isAvailable()) return it }
        }
        providers.firstOrNull { it.isAvailable() }?.let { return it }
        return providers.first()
    }
}
```

### D.4 Модель даних **[точно]**

```kotlin
data class AIRequest(
    val mode: AIConversationMode,
    val scenario: AIScenario,
    val level: Level,
    val history: List<AIMessage> = emptyList(),
    val topicTitleUk: String = "",
    val focusWords: List<String> = emptyList(),
) {
    val lastUserMessage: String get() = history.lastOrNull { it.fromUser }?.spanish ?: ""   // рядок 47
    val turnIndex: Int get() = history.count { it.fromUser }                                 // рядок 48
}
data class AIResponse(val spanish: String, val hintUk: String,
                      val corrections: List<AICorrection>, val error: String? = null)
data class AIMessage(val fromUser: Boolean, val spanish: String, val hintUk: String)
data class AICorrection(val wrongText: String, val correctText: String, val explanationUk: String)
```
(порядок полів відновлено з `toString` і `componentN`).

### D.5 `AIConversationMode` (enum) **[точно]**

```kotlin
enum class AIConversationMode(val code: String, val titleUk: String, val descriptionUk: String) {
    TEACHER("teacher", "Вчитель",     "Пояснює помилки українською, розбирає граматику"),   // 0
    PARTNER("partner", "Співрозмовник", "Говорить лише іспанською, як носій"),              // 1
    HINTS("hints",     "Іспанська + підказки", "Іспанською, але з перекладом і допомогою"), // 2
    ROLEPLAY("roleplay","Рольова гра", "Реалістична ситуація: ресторан, готель, лікар…"),   // 3
}
```

### D.6 `AIScenario` (enum) **[точно]** — усі 9 сценаріїв дослівно

```kotlin
enum class AIScenario(val code: String, val titleUk: String,
                      val openingSpanish: String, val openingUk: String) {
    INTRODUCTIONS("introductions","Знайомство","¡Hola! Me llamo Ana. ¿Y tú? ¿Cómo te llamas?","Привіт! Мене звати Ана. А ти?")
    RESTAURANT("restaurant","Ресторан","Buenas tardes, bienvenido. ¿Mesa para cuántas personas?","Доброго дня, вітаю. Столик на скільки осіб?")
    SHOP("shop","Магазин","Hola, ¿le puedo ayudar en algo?","Вітаю, можу чимось допомогти?")
    HOTEL("hotel","Готель","Buenas noches. ¿Tiene una reserva a su nombre?","Доброго вечора. У вас є бронювання?")
    AIRPORT("airport","Аеропорт","Buenos días. ¿Me enseña su pasaporte, por favor?","Доброго ранку. Покажіть, будь ласка, паспорт.")
    DOCTOR("doctor","Лікар","Buenos días. Cuénteme, ¿qué le pasa?","Доброго ранку. Розкажіть, що вас турбує?")
    WORK("work","Робота","Hola, soy Marta de recursos humanos. Cuéntame un poco sobre ti.","Вітаю, я Марта з відділу кадрів. Розкажи трохи про себе.")
    RENTING("renting","Оренда житла","Hola, ¿llama por el piso del centro? Todavía está disponible.","Вітаю, ви телефонуєте щодо квартири в центрі? Вона ще вільна.")
    FREE_TALK("free_talk","Вільна розмова","¡Hola! ¿Qué tal? ¿Cómo llevas el español?","Привіт! Як справи? Як тобі дається іспанська?")
}
```
(ordinals 0..8 у цьому порядку).

### D.7 `LocalAIProvider.reply()` **[точно]** (рядки 33–51)

```kotlin
override suspend fun reply(request: AIRequest): AIResponse {
    val userText = request.lastUserMessage                                        // 34
    val corrections = detectCorrections(userText)                                 // 35
    val script = SCRIPTS[request.scenario] ?: SCRIPTS.getValue(AIScenario.FREE_TALK)  // 37
    val turn = request.turnIndex                                                  // 38
    val scripted: ScriptLine = script.getOrNull(turn - 1) ?: script.last()        // 41
    val spanish = if (turn == 0) request.scenario.openingSpanish else scripted.spanish   // 43
    val hint = when (request.mode) {                                              // 44
        AIConversationMode.PARTNER -> ""                                          // 45
        AIConversationMode.TEACHER -> buildTeacherHint(scripted.hintUk, corrections, userText)  // 46
        AIConversationMode.HINTS   -> scripted.hintUk                             // 47
        AIConversationMode.ROLEPLAY-> scripted.hintUk                             // 48
    }
    return AIResponse(spanish = spanish, hintUk = hint, corrections = corrections) // 51
}
```
Примітка: віднесення гілок `when` до режимів виведено з порядку цілей `packed-switch` (payload обрізано дампом) і з нумерації рядків джерела 45–48; гілки `HINTS` і `ROLEPLAY` у байткоді ідентичні (`scripted.hintUk`), `PARTNER` → порожній рядок — узгоджується з описами режимів.

`ScriptLine(spanish: String, hintUk: String)`. `SCRIPTS: Map<AIScenario, List<ScriptLine>>` — по 9–10 реплік на сценарій (повний перелік реплік — у `_recon/strings_by_class.txt`, клас `LocalAIProvider`, рядки 115–289; кожна пара «іспанська ↔ українська» наведена там дослівно).

### D.8 `buildTeacherHint(scriptLineHintUk, corrections, userText)` **[точно]** (рядки 62–75)

```kotlin
buildString {
    if (corrections.isEmpty()) append("Молодець, речення побудоване правильно. ")     // 63–64 (з пробілом у кінці)
    else {
        append("Розберімо помилку. ")                                               // 66
        corrections.forEach { c ->
            append("«${c.wrongText}» → «${c.correctText}». ")                        // 68
            append(c.explanationUk)                                                  // 69
            append('\n')                                                             // 70
        }
    }
    if (scriptLineHintUk.isNotBlank()) append("Переклад: $scriptLineHintUk")          // 74
    else append("Спробуйте відповісти повним реченням.")                              // 75
}
```

### D.9 `detectCorrections(text)` — оцінка помилок **[точно]** (рядки 82–134)

```kotlin
fun detectCorrections(text: String): List<AICorrection> {
    if (text.isBlank()) return emptyList()                       // 83–84
    val lower = text.lowercase(Locale.ROOT)                      // 85
    val out = mutableListOf<AICorrection>()                      // 85

    ARTICLE_MISMATCHES.forEach { (wrong, correct, explanation) ->   // 88  (Triple(wrong, correct, explanation))
        if (Regex("\\b$wrong\\b").containsMatchIn(lower))            // 89–90
            out += AICorrection(wrong, correct, explanation)         // 92
    }
    if (Regex("\\bsoy\\s+(bien|mal)\\b").containsMatchIn(lower))
        out += AICorrection("soy bien", "estoy bien",
            "Стан «добре/погано» — це estar: estoy bien. Ser описує постійну рису.")          // 95–99
    if (Regex("\\bestoy\\s+(español|ucraniano|estudiante|profesor)\\b").containsMatchIn(lower))
        out += AICorrection("estoy español", "soy español",
            "Національність і професія — це постійна характеристика, тому ser: soy español.") // 102–106
    if (Regex("\\byo\\s+soy\\s+\\w+").containsMatchIn(lower))
        out += AICorrection("yo soy …", "soy …",
            "Займенник yo зазвичай опускають: закінчення дієслова вже вказує на «я».")        // 111–115
    if (Regex("\\bquiero\\s+que\\s+\\w+(ar|er|ir)\\b").containsMatchIn(lower))
        out += AICorrection("quiero que ir", "quiero ir",
            "Після querer друга дія стоїть в інфінітиві без que: quiero ir.")                 // 120–124
    GENDER_TRAPS.forEach { (word, article, explanation) ->                                        // 129
        val opposite = if (article == "el") "la" else "el"
        if (Regex("\\b${opposite}\\s+$word\\b").containsMatchIn(lower))                            // 132
            out += AICorrection("$opposite $word", "$article $word", explanation)                  // 133–134
    }
    if (Regex("\\bayer\\b").containsMatchIn(lower) &&
        Regex("\\b(como|bebo|voy|hablo)\\b").containsMatchIn(lower))
        out += AICorrection("presente + ayer", "pretérito indefinido",
            "З «ayer» потрібен минулий завершений час: comí, fui, hablé.")
    return out.distinctBy { it.wrongText.lowercase(Locale.ROOT) }    // 258–265
}
```

**`ARTICLE_MISMATCHES`** — `List<Triple<wrong, correct, explanation>>` (6 елементів, дослівно):
```
("una café",     "un café",     "«café» — чоловічого роду, тому un café.")
("un casa",      "una casa",    "«casa» — жіночого роду, тому una casa.")
("una problema", "un problema", "«problema» — чоловічого роду, хоч і закінчується на -a.")
("un mano",      "una mano",    "«mano» — жіночого роду, хоч і закінчується на -o.")
("una agua",     "el agua",     "«agua» — жіночого роду, але вживається з el, щоб не зливались два «а».")
("una día",      "un día",      "«día» — чоловічого роду.")
```
**`GENDER_TRAPS`** — `List<Triple<word, article, explanation>>` (4 елементи, дослівно):
```
("problema", "el", "Слова грецького походження на -ma чоловічого роду: el problema, el tema, el idioma.")
("mano",     "la", "«mano» — виняток: жіночого роду, la mano.")
("mapa",     "el", "«mapa» — чоловічого роду: el mapa.")
("flor",     "la", "«flor» — жіночого роду: la flor.")
```
`pronunciationHint(word)` = `SpanishPhonetics.toUkrHint(word)`;
`looksSpanish(text)` = `!text.isBlank() && !Regex("[іїєґи]").containsMatchIn(text.lowercase(Locale.ROOT))`.

### D.10 Екран/VM `AiDialogViewModel` **[частково]**

```kotlin
enum class AiPhase { SETUP, CHAT, REVIEW }        // порядок оголошення
data class ChatMessage(val fromUser: Boolean, val spanish: String,
                       val hintUk: String, val timestamp: Long)
data class AiDialogUiState(
    val phase: AiPhase, val mode: AIConversationMode, val scenario: AIScenario,
    val messages: List<ChatMessage>, val input: String, val thinking: Boolean,
    val corrections: List<AICorrection>, val providerTitle: String,
    val requiresNetwork: Boolean, val allowExternalAi: Boolean,
    val speechAvailable: Boolean, val isListening: Boolean)
```
Поля VM: `container: AppContainer`, `_state: MutableStateFlow<AiDialogUiState>`, `state`, `allCorrections: List<AICorrection>`, `conversationStartedAt: Long`.
Методи: `start()`, `send()`, `retry()`, `finish()`, `backToSetup()`, `focusWords()` (suspend), `recordMistakes(state)` (suspend), `saveConversation(state)` (suspend), `tagForScenario(AIScenario): GrammarTag`, `previewCorrections(text): List<AICorrection>`, `setMode`, `setScenario`, `setListening`, `updateInput`, `speak(text)`.
Рядок `" · "` використовується як роздільник (у `recordMistakes`/`focusWords`); `const/16 0x80` (128) і `#int 3` фігурують у `saveConversation`/`recordMistakes` — точна семантика **[частково]** (див. «Невідоме»).
Провайдер вибирається як `container.aiProviders.resolve(profile.aiProviderId)`; `allowExternalAi`/`aiEndpoint`/`aiApiKey`/`aiModel` — поля профілю (див. E), але фактичного HTTP-виклику в коді немає.

---

## E. Дані — `data/database/*`

### E.1 База **[точно]**

- Файл БД: **`krupa_spanish.db`** (`AppDatabase$Companion`, `context.getApplicationContext(...)`).
- Таблиці (16): `words`, `sentences`, `exercises`, `grammar`, `listening_items`, `topics`, `cards`, `review_logs`, `mistake_entries`, `mistake_stats`, `topic_progress`, `daily_stats`, `conversations`, `settings`, `user_profile`, + службова `room_master_table`.
- `room_master_table`: `CREATE TABLE IF NOT EXISTS room_master_table (id INTEGER PRIMARY KEY,identity_hash TEXT)`.
- Identity-hash-рядки в `AppDatabase_Impl`: `2b0878dcd09fae2141ed3cf0069f7a12`, `8e522a11e664096aaf21f20864f4e903`.
- Службові запити: `PRAGMA wal_checkpoint(FULL)`, `VACUUM`, `DELETE FROM <table>` (для всіх 15 таблиць — «очистити все»).
- Версія БД, `exportSchema`, `Migration`-об'єкти, `fallbackToDestructiveMigration` — **[невідомо]** (у дампі не знайдено).

### E.2 Схема (дослівні `CREATE TABLE`) **[точно]**

```sql
CREATE TABLE IF NOT EXISTS `words` (`id` TEXT NOT NULL, `spanish` TEXT NOT NULL, `lemma` TEXT NOT NULL,
  `translationUk` TEXT NOT NULL, `partOfSpeechCode` TEXT NOT NULL, `genderCode` TEXT NOT NULL,
  `plural` TEXT NOT NULL, `pronunciation` TEXT NOT NULL, `ipaHint` TEXT NOT NULL, `exampleEs` TEXT NOT NULL,
  `exampleUk` TEXT NOT NULL, `levelCode` TEXT NOT NULL, `topicId` TEXT NOT NULL, `withArticle` INTEGER NOT NULL,
  `grammarTags` TEXT NOT NULL, `notesUk` TEXT NOT NULL, `cognateNoteUk` TEXT NOT NULL,
  `frequencyRank` INTEGER NOT NULL, `contentVersion` INTEGER NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `sentences` (`id` TEXT NOT NULL, `spanish` TEXT NOT NULL, `translationUk` TEXT NOT NULL,
  `levelCode` TEXT NOT NULL, `topicId` TEXT NOT NULL, `kindCode` TEXT NOT NULL, `grammarTags` TEXT NOT NULL,
  `wordIds` TEXT NOT NULL, `audioHint` TEXT NOT NULL, `contentVersion` INTEGER NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `exercises` (`id` TEXT NOT NULL, `kindCode` TEXT NOT NULL, `levelCode` TEXT NOT NULL,
  `topicId` TEXT NOT NULL, `grammarTagCode` TEXT NOT NULL, `promptUk` TEXT NOT NULL, `promptEs` TEXT NOT NULL,
  `answerEs` TEXT NOT NULL, `answerUk` TEXT NOT NULL, `distractors` TEXT NOT NULL, `tokens` TEXT NOT NULL,
  `gapText` TEXT NOT NULL, `gapAnswer` TEXT NOT NULL, `relatedWordIds` TEXT NOT NULL,
  `relatedSentenceId` TEXT NOT NULL, `explanationUk` TEXT NOT NULL, `difficulty` INTEGER NOT NULL,
  `contentVersion` INTEGER NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `grammar` (`id` TEXT NOT NULL, `tagCode` TEXT NOT NULL, `levelCode` TEXT NOT NULL,
  `titleEs` TEXT NOT NULL, `titleUk` TEXT NOT NULL, `explanationUk` TEXT NOT NULL, `patternUk` TEXT NOT NULL,
  `examples` TEXT NOT NULL, `commonMistakeUk` TEXT NOT NULL, `tipForUkSpeakersUk` TEXT NOT NULL,
  `orderIndex` INTEGER NOT NULL, `contentVersion` INTEGER NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `listening_items` (`id` TEXT NOT NULL, `levelCode` TEXT NOT NULL, `topicId` TEXT NOT NULL,
  `titleEs` TEXT NOT NULL, `titleUk` TEXT NOT NULL, `kindCode` TEXT NOT NULL, `lines` TEXT NOT NULL,
  `keyWords` TEXT NOT NULL, `comprehensionQuestions` TEXT NOT NULL, `orderIndex` INTEGER NOT NULL,
  `contentVersion` INTEGER NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `topics` (`id` TEXT NOT NULL, `levelCode` TEXT NOT NULL, `titleEs` TEXT NOT NULL,
  `titleUk` TEXT NOT NULL, `descriptionUk` TEXT NOT NULL, `orderIndex` INTEGER NOT NULL, `iconKey` TEXT NOT NULL,
  `grammarTags` TEXT NOT NULL, PRIMARY KEY(`id`))

CREATE TABLE IF NOT EXISTS `cards` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `itemType` TEXT NOT NULL,
  `itemId` TEXT NOT NULL, `levelCode` TEXT NOT NULL, `topicId` TEXT NOT NULL, `grammarTags` TEXT NOT NULL,
  `stateCode` TEXT NOT NULL, `dueAt` INTEGER NOT NULL, `intervalDays` REAL NOT NULL, `intervalMinutes` INTEGER NOT NULL,
  `ease` REAL NOT NULL, `repetitions` INTEGER NOT NULL, `lapses` INTEGER NOT NULL, `totalReviews` INTEGER NOT NULL,
  `correctReviews` INTEGER NOT NULL, `averageResponseMs` INTEGER NOT NULL, `lastReviewedAt` INTEGER,
  `firstSeenAt` INTEGER NOT NULL, `suspended` INTEGER NOT NULL)

CREATE TABLE IF NOT EXISTS `review_logs` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `cardId` INTEGER NOT NULL,
  `itemType` TEXT NOT NULL, `itemId` TEXT NOT NULL, `gradeValue` INTEGER NOT NULL, `correct` INTEGER NOT NULL,
  `responseMs` INTEGER NOT NULL, `reviewedAt` INTEGER NOT NULL, `exerciseKindCode` TEXT NOT NULL,
  `grammarTag` TEXT NOT NULL, `topicId` TEXT NOT NULL)

CREATE TABLE IF NOT EXISTS `mistake_entries` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `kindCode` TEXT NOT NULL,
  `wrongText` TEXT NOT NULL, `correctText` TEXT NOT NULL, `explanationUk` TEXT NOT NULL,
  `grammarTagCode` TEXT NOT NULL, `createdAt` INTEGER NOT NULL, `resolved` INTEGER NOT NULL)

CREATE TABLE IF NOT EXISTS `mistake_stats` (`grammarTagCode` TEXT NOT NULL, `titleUk` TEXT NOT NULL,
  `attempts` INTEGER NOT NULL, `mistakes` INTEGER NOT NULL, `lastMistakeAt` INTEGER,
  `recentResults` TEXT NOT NULL, `levelCode` TEXT NOT NULL, PRIMARY KEY(`grammarTagCode`))

CREATE TABLE IF NOT EXISTS `topic_progress` (`topicId` TEXT NOT NULL, `levelCode` TEXT NOT NULL,
  `lessonsCompleted` INTEGER NOT NULL, `totalLessons` INTEGER NOT NULL, `wordsIntroduced` INTEGER NOT NULL,
  `lastStudiedAt` INTEGER, `completedAt` INTEGER, PRIMARY KEY(`topicId`))

CREATE TABLE IF NOT EXISTS `daily_stats` (`dayEpoch` INTEGER NOT NULL, `minutes` INTEGER NOT NULL,
  `reviews` INTEGER NOT NULL, `newWords` INTEGER NOT NULL, `speakingAttempts` INTEGER NOT NULL,
  `listeningMinutes` INTEGER NOT NULL, `exercisesDone` INTEGER NOT NULL, `correctAnswers` INTEGER NOT NULL,
  `totalAnswers` INTEGER NOT NULL, PRIMARY KEY(`dayEpoch`))

CREATE TABLE IF NOT EXISTS `conversations` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  `scenarioCode` TEXT NOT NULL, `modeCode` TEXT NOT NULL, `titleUk` TEXT NOT NULL, `startedAt` INTEGER NOT NULL,
  `finishedAt` INTEGER, `messages` TEXT NOT NULL, `mistakes` TEXT NOT NULL)

CREATE TABLE IF NOT EXISTS `settings` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY(`key`))

CREATE TABLE IF NOT EXISTS `user_profile` (`id` INTEGER NOT NULL, `name` TEXT NOT NULL, `levelCode` TEXT NOT NULL,
  `assessmentDone` INTEGER NOT NULL, `assessmentScore` INTEGER NOT NULL, `goalCode` TEXT NOT NULL,
  `dailyMinutes` INTEGER NOT NULL, `startedAt` INTEGER NOT NULL, `themeMode` TEXT NOT NULL,
  `ttsVoiceGender` TEXT NOT NULL, `ttsRate` REAL NOT NULL, `showListeningHints` INTEGER NOT NULL,
  `allowExternalAi` INTEGER NOT NULL, `aiProviderId` TEXT NOT NULL, `aiEndpoint` TEXT NOT NULL,
  `aiApiKey` TEXT NOT NULL, `aiModel` TEXT NOT NULL, `dailyGoalStreak` INTEGER NOT NULL, PRIMARY KEY(`id`))
```
Зовнішніх ключів (`FOREIGN KEY`) у схемі **немає**. Дочірні списки (`grammarTags`, `tokens`, `messages`, `mistakes`, `recentResults`, `examples`, `lines`, `comprehensionQuestions`, `distractors`, `relatedWordIds`, `wordIds`) — це `TEXT NOT NULL`, серіалізовані через `AppConverters` (kotlinx.serialization / JSON; `AppConverters$Companion$json$1`), точні формати **[частково]**.

### E.3 Індекси **[точно]**

```sql
CREATE INDEX IF NOT EXISTS `index_words_levelCode` ON `words` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_words_partOfSpeechCode` ON `words` (`partOfSpeechCode`)
CREATE INDEX IF NOT EXISTS `index_words_topicId` ON `words` (`topicId`)
CREATE UNIQUE INDEX IF NOT EXISTS `index_words_spanish` ON `words` (`spanish`)
CREATE INDEX IF NOT EXISTS `index_sentences_kindCode` ON `sentences` (`kindCode`)
CREATE INDEX IF NOT EXISTS `index_sentences_levelCode` ON `sentences` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_sentences_topicId` ON `sentences` (`topicId`)
CREATE INDEX IF NOT EXISTS `index_exercises_grammarTagCode` ON `exercises` (`grammarTagCode`)
CREATE INDEX IF NOT EXISTS `index_exercises_kindCode` ON `exercises` (`kindCode`)
CREATE INDEX IF NOT EXISTS `index_exercises_levelCode` ON `exercises` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_exercises_topicId` ON `exercises` (`topicId`)
CREATE INDEX IF NOT EXISTS `index_grammar_levelCode` ON `grammar` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_grammar_orderIndex` ON `grammar` (`orderIndex`)
CREATE INDEX IF NOT EXISTS `index_grammar_tagCode` ON `grammar` (`tagCode`)
CREATE INDEX IF NOT EXISTS `index_listening_items_levelCode` ON `listening_items` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_listening_items_orderIndex` ON `listening_items` (`orderIndex`)
CREATE INDEX IF NOT EXISTS `index_listening_items_topicId` ON `listening_items` (`topicId`)
CREATE INDEX IF NOT EXISTS `index_topics_levelCode` ON `topics` (`levelCode`)
CREATE INDEX IF NOT EXISTS `index_topics_orderIndex` ON `topics` (`orderIndex`)
CREATE INDEX IF NOT EXISTS `index_cards_dueAt` ON `cards` (`dueAt`)
CREATE INDEX IF NOT EXISTS `index_cards_itemId` ON `cards` (`itemId`)
CREATE INDEX IF NOT EXISTS `index_cards_itemType` ON `cards` (`itemType`)
CREATE INDEX IF NOT EXISTS `index_cards_stateCode` ON `cards` (`stateCode`)
CREATE INDEX IF NOT EXISTS `index_review_logs_cardId` ON `review_logs` (`cardId`)
CREATE INDEX IF NOT EXISTS `index_review_logs_grammarTag` ON `review_logs` (`grammarTag`)
CREATE INDEX IF NOT EXISTS `index_review_logs_reviewedAt` ON `review_logs` (`reviewedAt`)
CREATE INDEX IF NOT EXISTS `index_mistake_entries_createdAt` ON `mistake_entries` (`createdAt`)
CREATE INDEX IF NOT EXISTS `index_mistake_entries_kindCode` ON `mistake_entries` (`kindCode`)
CREATE INDEX IF NOT EXISTS `index_mistake_stats_grammarTagCode` ON `mistake_stats` (`grammarTagCode`)
CREATE INDEX IF NOT EXISTS `index_topic_progress_topicId` ON `topic_progress` (`topicId`)
CREATE INDEX IF NOT EXISTS `index_daily_stats_dayEpoch` ON `daily_stats` (`dayEpoch`)
CREATE INDEX IF NOT EXISTS `index_conversations_startedAt` ON `conversations` (`startedAt`)
```

### E.4 Налаштування **[точно / частково]**

- Таблиця `settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)` — сховище «ключ-значення»; клас `SettingEntity`. Окремого `PreferencesStore`/DataStore у дизасембляції **немає** (його немає і в `_recon/source_files.txt`).
- Постійні налаштування користувача зберігаються в `user_profile` (стовпці вище): `name`, `levelCode`, `assessmentDone`, `assessmentScore`, `goalCode`, `dailyMinutes`, `startedAt`, `themeMode`, `ttsVoiceGender`, `ttsRate`, `showListeningHints`, `allowExternalAi`, `aiProviderId`, `aiEndpoint`, `aiApiKey`, `aiModel`, `dailyGoalStreak`.
- Відомі ключі-рядки (з `SettingsViewModel`/`SettingsScreen`/`ProgressTransfer`): `aiProviderId`, `aiEndpoint`, `aiApiKey`, `aiModel`, `allowExternalAi`, `contentVersion` (ключ експорту — `content_version`), `themeMode` (значення: `system`), `goalCode` (значення: `travel`), `ttsVoiceGender` (значення: `female`), `ttsRate`, `showListeningHints`.
- **Значення за замовчуванням** для більшості ключів **[невідомо]** (потребують читання `SettingsViewModel`/`UserRepositoryImpl`).

---

## F. Контент — `data/content/*`

### F.1 Assets **[точно]** (з `content_from_apk/`)

Файли контенту (плоскі, без підкаталогів): `words.a0.json`, `words.a1.json`, `words.a2.json`, `sentences.a0/a1/a2.json`, `exercises.a0/a1/a2.json`, `grammar.a0a1.json`, `grammar.a2.json`, `listening.a0/a1/a2.json`, `topics.a0/a1/a2.json`. Джерело — `AssetsContentSource` (kotlinx.serialization `Json`), DTO — у `ContentPackDto.kt`.
Колонка `contentVersion INTEGER NOT NULL` є в `words`, `sentences`, `exercises`, `grammar`, `listening_items` (у `topics` — немає).

### F.2 Сідинг/валідація **[частково]**

Класи: `ContentSeeder` (`seedIfNeeded`, `$1`, `$2`), `ContentValidator` (+ `ContentValidator$Result`), `ContentMappers`, `AppContainer$contentSeeder$2`/`$contentSource$2`.
Логіка повторного сідингу, чи транзакція, чи блокує сідинг помилка валідації, точний перелік правил валідації та пороги — **[невідомо]** (не відновлено в межах цього проходу; вміст класів лежить у `classes16.txt`).

---

## G. Резервні копії — `data/transfer/*`

**ZIP-архіву НЕМАЄ.** Клас `Zip.kt` у `_recon/class_to_source.txt` належить `kotlinx.coroutines` (`ProgressRepositoryImpl$observeSnapshot$$inlined$combine$1$2/3` → `Zip.kt`), а не архівації файлів.

### G.1 Формат експорту **[точно]**

- **Один JSON-файл** (не zip): MIME `application/json`, ім'я `krupa_spanish_progress_<yyyy-MM-dd_HHmm>.json` (шаблон дати `yyyy-MM-dd_HHmm`, префікс `krupa_spanish_progress_`, суфікс `.json`).
- Запис через `MediaStore` (`MediaStore.Downloads.EXTERNAL_CONTENT_URI`, колонки `_display_name`, `mime_type`, `relative_path = "exports"`), з fallback у власну папку застосунку (`exports`). Повідомлення користувачу (дослівно):
  - `Прогрес збережено у «Завантаження»:` + ім'я файлу
  - `Прогрес збережено у папці застосунку:` + шлях
  - `Не вдалося зберегти прогрес: ` + причина
- `ExportReport(success: Boolean, fileName: String?, messageUk: String?, bytes: Long)`; список експортованих файлів сортується `sortedByDescending`.

### G.2 JSON-схема бекапу **[точно]** (поля з `$$serializer`)

```jsonc
ProgressBackup {
  formatVersion: Int,          // константа версії; конкретне число — [невідомо]
  appVersion: String,
  exportedAt: <long>,          // тип уточнити: ймовірно epoch millis
  contentVersion: Int,         // у коді також рядковий ключ "content_version"
  profile: ProfileBackup?,
  cards: [CardBackup],
  mistakes: [MistakeBackup],
  mistakeStats: [MistakeStatBackup],
  dailyStats: [DailyStatBackup],
  conversations: [ConversationBackup]
}
ProfileBackup { name, levelCode, assessmentDone, assessmentScore, goalCode, dailyMinutes,
                startedAt, themeMode, ttsVoiceGender, ttsRate, showListeningHints }
CardBackup { itemType, itemId, levelCode, topicId, grammarTags, stateCode, dueAt, intervalDays,
             intervalMinutes, ease, repetitions, lapses, totalReviews, correctReviews,
             averageResponseMs, lastReviewedAt, firstSeenAt, suspended }
MistakeBackup { kindCode, wrongText, correctText, explanationUk, grammarTagCode, createdAt }
MistakeStatBackup { grammarTagCode, titleUk, attempts, mistakes, lastMistakeAt, recentResults, levelCode }
DailyStatBackup { dayEpoch, minutes, reviews, newWords, speakingAttempts, listeningMinutes,
                  exercisesDone, correctAnswers, totalAnswers }
ConversationBackup { scenarioCode, modeCode, titleUk, startedAt, finishedAt, messageCount }
```
Порядок полів у `data class` збігається з порядком у `$$serializer` (перевірено для всіх перелічених класів). `formatVersion` — **[частково]** (константа існує, число не витягнуто).

### G.3 Імпорт **[точно / частково]**

- `importFromText(...)` приймає JSON-текст (не zip).
- Повідомлення (дослівно): `Файл пошкоджений або це не файл прогресу KRUPA_Spanish:` …; `Файл створено новішою версією застосунку (формат ` … `).`; `У файлі немає даних про навчання.`; `Прогрес відновлено.`; `Помилка під час імпорту:` …; а також лічильники `Карток:`, `днів статистики:`, `помилок:`.
- `ImportReport(success: Boolean, messageUk: String?, cardsImported: Int, daysImported: Int, mistakesImported: Int, profileImported: Boolean, warnings: List<String>)`.
- Стратегія застосування (заміна/злиття, очищення таблиць), перевірки сумісності версій і передача назовні через SAF/Intent — **[невідомо]** (у рядках класу `ProgressTransfer` немає `ACTION_SEND`/`FileProvider`; використовується `MediaStore` + текстовий JSON).

---

## H. Застосунок — `SpanishApp.kt`, `MainActivity.kt`, `AppContainer.kt`

**[частково]**

- `SpanishApp : Application` має поле `container: AppContainer` (`SpanishApp$onCreate$1` — корутина на старті).
- `MainActivity.onCreate` використовує Compose `viewModel` (помилка `No ViewModelStoreOwner was provided via LocalViewModelStoreOwner`), колбеки `saveProfile(UserProfile)` і `showOnboarding(Boolean)`; `SpanishApp` кастується з `applicationContext` (`null cannot be cast to non-null type ua.krupa.spanish.SpanishApp`).
- `AppContainer(context)`: усі сервіси — **ліниві** (`by lazy`, класи `AppContainer$…$2` для кожного): `database`, `contentSource`, `contentSeeder`, `courseRepository`, `userRepository`, `progressRepository`, `progressTransfer`, `srsEngine`, `lessonBuilder`, `mistakeTracker`, `aiProviders`, `ttsEngine`, `speechRecognizer`. Тобто порядок створення — за першим зверненням, не фіксований.
- Тема/мова: `themeMode` (значення `system`), UI-рядки українською; `ui/theme/Theme.kt`, `Color.kt`, `Type.kt`; навігація — `ui/AppRoot.kt` (`AppNavHost`), маршрути — `Routes.kt`.

---

## Невідоме (потребує додаткового проходу по байткоду)

1. **TTS:** ключ сортування у `configureEngine` (`sortedBy { … }`); значення за замовчуванням `ttsRate` у профілі; чи є `pitch`/`volume` деінде (у `SpanishTtsEngine` їх немає).
2. **ASR:** жодних відкритих питань, окрім поведінки поза `SpanishSpeechRecognizer` (запит дозволу в екранах).
3. **Вимова:** `k` у `mapping()` (байткод не присвоює значення); правило №9 у `transliterate` з символом `'\u00B8'` (схоже на одруківку замість `ç`); обрізаний payload `stepPenalty` (віднесення 1.0/0.6 до DELETE/INSERT виведено з гілок у `score()`).
4. **AI:** точна семантика констант `128` і `3` у `saveConversation`/`recordMistakes`; повний перелік реплік `SCRIPTS` (можна відновити з `strings_by_class.txt`, клас `LocalAIProvider`, рядки 115–289 — пари Es/Uk наведені, але прив'язка до конкретних сценаріїв вимагає ще одного читання `<clinit>`); `focusWords()`/`recordMistakes()` (як саме пишуться помилки в `MistakeTracker`).
5. **БД:** версія БД, міграції, `exportSchema`, точні `@ColumnInfo`-імена (наразі відомі з SQL), типи-конвертери для списків, семантика `stateCode`, формати дат (epoch millis vs ISO) — не підтверджені.
6. **Налаштування:** значення за замовчуванням усіх ключів `settings`/`user_profile`; повний перелік ключів таблиці `settings` (частина може задаватися лише в `SettingsViewModel`).
7. **Контент:** `ContentSeeder.seedIfNeeded` (умова сідингу, ключ версії, транзакція), повний перелік правил `ContentValidator` і порогів, `ContentMappers`.
8. **Бекап:** числове значення `formatVersion`, тип `exportedAt`, стратегія імпорту (merge/replace), спосіб передачі файлу назовні (SAF/шер).
9. **Застосунок:** точний порядок/побічні ефекти ініціалізації в `SpanishApp.onCreate` та `MainActivity`.
