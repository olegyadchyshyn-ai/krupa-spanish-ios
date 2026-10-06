# iOS-порт KRUPA Spanish — контракт реалізації

Документ описує архітектуру, точні сигнатури API та правила коду.
Будь-який код екранів має писатися **строго за цим контрактом**.

- Цільова платформа: **iOS 17.0** (працює на iOS 17.7)
- Мова інтерфейсу: **українська**, контент — **іспанська**
- Залежності: **жодних сторонніх бібліотек**, лише SwiftUI / Foundation / AVFoundation / Speech
- Мова коду: Swift 5 (режим мови 5.0, `SWIFT_STRICT_CONCURRENCY = minimal`)

---

## 1. Структура файлів

```
KrupaSpanish/
├── project.yml                    # XcodeGen: генерує KrupaSpanish.xcodeproj
├── Supporting/Info.plist
├── Resources/
│   ├── Assets.xcassets            # AppIcon (1024), AccentColor, LaunchBackground
│   └── Content/*.json             # 17 файлів контенту курсу
└── Sources/
    ├── App/        KrupaSpanishApp, RootView, AppRoute, AppState
    ├── Models/     ContentModels, UserModels
    ├── Content/    ContentStore
    ├── Data/       ProgressStore, BackupService
    ├── Learning/   SrsEngine, AnswerCheck, SessionModels, LessonBuilder
    ├── Speech/     SpeechService, PronunciationScorer
    ├── AI/         AIService
    └── UI/
        ├── Theme/KrupaTheme.swift
        ├── Components/KrupaComponents.swift
        └── Screens/*.swift      # по одному файлу на екран
```

Один файл екрана містить і `View`, і (за потреби) його `ViewModel` —
це зменшує кількість перехресних залежностей.

---

## 2. Правила коду (щоб збірка гарантовано проходила)

1. **Не використовувати** макроси (`@Observable`, `#Predicate`), `SwiftData`,
   `TipKit`, `Charts`, стрічки-форматування тощо — тільки стабільний SwiftUI.
2. **Не використовувати** API, новіші за iOS 17 (`onChange` без параметрів — ні,
   тільки `onChange(of:) { oldValue, newValue in }`).
3. Кожен екран — окремий `struct ... : View`, доступ до стану —
   через `@EnvironmentObject private var app: AppState`.
4. Усі тексти інтерфейсу — рядкові літерали українською, без `LocalizedStringKey`.
5. `@State` — лише для локального стану екрана; бізнес-логіка — в `AppState`/сервісах.
6. Ніяких `fatalError`, `try!`, `as!`. Помилки — у `@State var errorMessage: String?`
   і показ через `ErrorBanner`.
7. Список у `ForEach` — завжди з `id:` (моделі мають `Identifiable`).
8. Не додавати нові файли в `project.yml` — XcodeGen підхоплює всю теку `Sources` автоматично.
9. Коментарі — українською, короткі, по суті.

---

## 3. Доступ до даних

### 3.1 AppState (єдине джерело сервісів)

```swift
@EnvironmentObject private var app: AppState

app.content          // CourseContent — увесь контент курсу
app.contentIssues    // [String] — зауваження до контенту
app.progress         // ProgressStore — прогрес користувача
app.speech           // SpeechService — синтез мовлення
app.recognition      // SpeechRecognitionService — розпізнавання
app.ai               // AIService — діалоги
app.backup           // BackupService — резервні копії

app.profile          // скорочення до app.progress.profile
app.settings         // скорочення до app.progress.settings

app.speak(_ text: String, force: Bool = false)   // озвучити іспанською
app.speak(word: Word)
app.makePlan(topicId: String? = nil) -> SessionPlan
app.makeReviewPlan() -> SessionPlan
app.topicsWithProgress(level: Level? = nil) -> [(topic: Topic, fraction: Double, wordsCount: Int)]
app.wordsWithProgress(level: Level, topicId: String? = nil) -> [(word: Word, card: CardState?)]
app.recordAnswer(item:grade:userAnswer:usedHint:responseMs:)
app.markListeningCompleted()
app.markSpeakingAttempt()
app.preferredColorScheme   // ColorScheme? для .preferredColorScheme
```

### 3.2 CourseContent (контент)

```swift
content.words                                  // [Word]
content.word(_ id: String) -> Word?
content.words(level: Level, topicId: String? = nil) -> [Word]      // за частотою
content.words(topicId: String) -> [Word]
content.words(grammarTag: String) -> [Word]

content.sentences(level: Level, topicId: String? = nil) -> [Sentence]
content.sentence(_ id: String) -> Sentence?

content.exercises(level: Level, topicId: String? = nil, kind: ExerciseKind? = nil) -> [Exercise]
content.exercise(_ id: String) -> Exercise?

content.topics(level: Level) -> [Topic]        // за orderIndex
content.topic(_ id: String) -> Topic?

content.grammarNotes(level: Level) -> [GrammarNote]
content.grammarNotes(tags: [String]) -> [GrammarNote]
content.grammarNote(id:) / grammarNote(tag:)

content.listening(level: Level, topicId: String? = nil) -> [ListeningItem]
content.listeningItem(_ id: String) -> ListeningItem?
```

### 3.3 ProgressStore (прогрес)

```swift
progress.profile / progress.settings
progress.updateProfile { $0.level = .a1 }
progress.updateSettings { $0.autoPlayAudio = false }

progress.card(for: String) -> CardState?
progress.cardOrCreate(itemId:itemType:level:topicId:grammarTags:) -> CardState
progress.upsert(_ card: CardState)
progress.setSuspended(_ suspended: Bool, itemId: String)
progress.dueCards(at: Date = Date()) -> [CardState]
progress.newCards() -> [CardState]
progress.dueCount(on: Date) -> Int

progress.dailyStat(for: Date) -> DailyStat
progress.todayStat -> DailyStat
progress.streakDays / progress.longestStreak
progress.snapshot() -> ProgressSnapshot
progress.weakSpots(limit: Int = 10) -> [WeakSpot]
progress.topicProgress(_ topicId: String) -> TopicProgress?
progress.updateTopicProgress(_ topicId: String) { $0.wordsLearned += 1 }

progress.conversations -> [ConversationSession]
progress.saveConversation(_ session: ConversationSession)
progress.deleteConversation(id: String)
progress.resetAll()
progress.exportData() throws -> Data
progress.lastSaveError -> String?
```

### 3.4 SRS та заняття

```swift
SrsEngine.previews(for: card) -> [GradePreview]      // для GradeButtonsRow
SrsEngine.preview(grade:for:) -> String              // «10 хв», «4 дн»
SrsEngine.intervalLabel(for: card) -> String
SrsEngine.isLearned(card) -> Bool

let plan: SessionPlan = app.makePlan()
plan.blocks            // [SessionBlock] — порожні блоки відсутні
plan.allItems          // [SessionItem]
plan.estimatedMinutes  // Int
plan.isEmpty           // Bool
plan.focusTopicTitleUk // String?

SessionItem.word(Word, StudyPromptKind)
SessionItem.sentence(Sentence, StudyPromptKind)
SessionItem.exercise(Exercise)
SessionItem.grammar(GrammarNote)
SessionItem.listening(ListeningItem)
  .id, .contentId, .itemType, .level, .topicId, .grammarTags
  .spanishForSpeech: String?    // що озвучувати
  .ukrainianText: String?       // підказка українською
  .titleText: String            // головний текст кроку
  .isSrsGraded: Bool

SessionChecker.check(item:userAnswer:) -> SessionAnswerFeedback
  // feedback.isCorrect, .messageUk, .correctAnswer, .explanationUk
SessionChecker.grade(for:userAnswer:usedHint:) -> Grade

AnswerCheck.check(_ user: String, expected: String, allowTypo: Bool = true) -> AnswerCheck.Result
  // .isCorrect, .messageUk, .suggestedGrade: Grade?
AnswerCheck.check(_ user: String, anyOf: [String]) -> Result
AnswerCheck.checkTokens(_ tokens: [String], expected: String) -> Result
AnswerCheck.similarity(_ a: String, _ b: String) -> Double   // 0…100
```

### 3.5 Мовлення

```swift
app.speech.speak(_ text: String, language: String = "es-ES", rateOverride: Double? = nil)
app.speech.speakDialogue(_ lines: [String])
app.speech.stop()
app.speech.isSpeaking -> Bool
app.speech.isSpeakingText(_ text: String) -> Bool
app.speech.availableVoices -> [AVSpeechSynthesisVoice]

app.recognition.requestAuthorization() async -> Bool
try app.recognition.start(locale: String = "es-ES")
app.recognition.finishRecording() -> String     // зупиняє й повертає текст
app.recognition.reset()
app.recognition.transcript -> String
app.recognition.isRecording -> Bool
app.recognition.audioLevel -> Double            // 0…1 для індикатора
app.recognition.state -> SpeechRecognitionService.State   // .idle/.listening/.finished(String)/.failed(String)

PronunciationScorer.score(expected: String, heard: String) -> PronunciationResult
  // .score (0…100), .heardText, .expectedText, .issues: [PronunciationIssue], .summaryUk, .isGood
PronunciationIssue.type -> PronunciationIssueType   // .titleUk, .adviceUk
```

### 3.6 AI

```swift
AIScenario.all -> [AIScenario]        // 8 сценаріїв
  .id, .titleUk, .titleEs, .descriptionUk, .level, .openingLineEs,
  .suggestedReplies, .systemPrompt, .topicId, .systemImageName
AIConversationMode.allCases           // .freeChat/.rolePlay/.guided, .titleUk, .descriptionUk

await app.ai.respond(scenario:mode:history:profile:) -> AIResponse?
  // .textEs, .translationUk, .corrections: [AICorrection], .suggestedReplies
app.ai.corrections(for: String) -> [AICorrection]
app.ai.isThinking -> Bool
app.ai.lastError -> String?
app.ai.title(for: profile) -> String

AIMessage(id:role:text:translationUk:corrections:createdAt:)   // role: .user/.assistant/.system
ConversationSession(id:scenarioId:scenarioTitleUk:mode:startedAt:messages:)
```

### 3.7 Резервні копії

```swift
app.backup.export(progress: app.progress) -> URL?          // файл у tmp
try app.backup.inspect(url: URL) -> BackupService.Summary  // .descriptionUk
try app.backup.importBackup(from: url, into: app.progress, mode: .replace/.merge) -> Summary
app.backup.lastError -> String?
```

---

## 4. Дизайн-система

### Кольори (`Color`)

`krupaBrand` (#C1272D), `krupaBrandDark`, `krupaGold`, `krupaBackground`, `krupaSurface`,
`krupaSurfaceAlt`, `krupaTextPrimary`, `krupaTextSecondary`, `krupaDivider`,
`krupaSuccess`, `krupaWarning`, `krupaError`, `krupaHeaderGradient`,
`Color.forLevel(_ level: Level)`, `Color.forGrade(_ grade: Grade)`

### Шрифти (`Font`)

`krupaLargeTitle`, `krupaTitle`, `krupaHeadline`, `krupaBody`, `krupaCallout`,
`krupaCaption`, `krupaSmall`, `krupaSpanishWord`, `krupaSpanishExample`

### Відступи

`KrupaSpacing.xxs/xs/sm/md/lg/xl/xxl`, `.cardRadius`, `.buttonRadius`, `.chipRadius`, `.screenPadding`

### Компоненти

| Компонент | Призначення |
|---|---|
| `KrupaCard { }` | картка-поверхня |
| `KrupaSectionHeader(title:subtitle:systemImage:)` | заголовок секції |
| `PrimaryActionButton(title:systemImage:isEnabled:action:)` | головна кнопка |
| `SecondaryActionButton(title:systemImage:tint:action:)` | другорядна кнопка |
| `AnswerOptionRow(text:state:subtitle:action:)` | варіант відповіді (`AnswerOptionState`: `.idle/.selected/.correct/.wrong`) |
| `KrupaProgressBar(value:tint:height:showsLabel:)` | смуга прогресу (0…1) |
| `LevelBadge(level:)` | бейдж рівня |
| `ChipView(text:systemImage:tint:)` | чип-тег |
| `StatTile(title:value:systemImage:tint:)` | плитка статистики |
| `StreakBadge(days:)` | серія днів |
| `KrupaTextField(placeholder:text:isFocused:onSubmit:)` | поле введення |
| `ExplanationBox(title:text:tint:systemImage:)` | пояснення/підказка |
| `EmptyStateView(systemImage:title:message:actionTitle:action:)` | порожній стан |
| `LoadingView(message:)` | завантаження |
| `ErrorBanner(message:retryTitle:onRetry:)` | помилка |
| `SpeakerButton(isSpeaking:size:action:)` | кнопка «прослухати» |
| `GradeButtonsRow(previews:onGrade:)` | кнопки оцінок SRS |
| `WordRowView(word:showsTranslation:isLearned:)` | рядок слова |
| `TopicCardView(topic:fraction:wordsCount:action:)` | картка теми |

---

## 5. Навігація

Маршрути вже оголошені в `AppRoute`. Перехід — стандартним `NavigationLink`:

```swift
NavigationLink(value: AppRoute.wordDetail(word.id)) { WordRowView(word: word) }
NavigationLink(value: AppRoute.session(topicId: topic.id)) { Text("Почати заняття") }
```

Вкладки: `HomeScreen`, `LearnScreen`, `WordsScreen`, `ProgressScreen`, `SettingsScreen`.
Інші екрани відкриваються як маршрути (див. `RouteView`).

`@Environment(\.dismiss) private var dismiss` — повернення назад.

---

## 6. Перелік екранів, які треба реалізувати

| Файл | Тип | Ініціалізація |
|---|---|---|
| `Screens/OnboardingScreen.swift` | `OnboardingScreen` | без параметрів |
| `Screens/HomeScreen.swift` | `HomeScreen` | без параметрів |
| `Screens/LearnScreen.swift` | `LearnScreen` | без параметрів |
| `Screens/TopicDetailScreen.swift` | `TopicDetailScreen` | `topicId: String` |
| `Screens/SessionScreen.swift` | `SessionScreen` | `topicId: String?` |
| `Screens/ReviewScreen.swift` | `ReviewScreen` | без параметрів |
| `Screens/WordsScreen.swift` | `WordsScreen`, `WordsListScreen(level: Level)` | — |
| `Screens/WordDetailScreen.swift` | `WordDetailScreen` | `wordId: String` |
| `Screens/GrammarScreen.swift` | `GrammarListScreen`, `GrammarDetailScreen(noteId: String)` | — |
| `Screens/ListeningScreen.swift` | `ListeningListScreen`, `ListeningDetailScreen(itemId: String)` | — |
| `Screens/SpeakingScreen.swift` | `SpeakingScreen` | без параметрів |
| `Screens/AIDialogScreen.swift` | `AIDialogScreen` | `scenarioId: String` |
| `Screens/ProgressScreen.swift` | `ProgressScreen`, `ProgressDetailsScreen` | — |
| `Screens/SettingsScreen.swift` | `SettingsScreen`, `BackupScreen`, `DiagnosticsScreen`, `AboutScreen` | — |

Кожен екран має самостійно обробляти стани: завантаження, порожній список, помилку.
