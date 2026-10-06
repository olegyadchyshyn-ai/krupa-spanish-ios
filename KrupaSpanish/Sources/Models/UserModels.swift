import Foundation

// MARK: - Оцінка відповіді (SRS)

/// Оцінки, які користувач ставить картці. Сирі значення збігаються з android-версією.
enum Grade: String, Codable, CaseIterable, Identifiable, Hashable {
    case again = "AGAIN"
    case hard = "HARD"
    case good = "GOOD"
    case easy = "EASY"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .again: return "Не знаю"
        case .hard: return "Пам'ятаю з труднощами"
        case .good: return "Знаю"
        case .easy: return "Дуже добре"
        }
    }

    /// Короткий підпис для кнопки.
    var shortTitleUk: String {
        switch self {
        case .again: return "Не знаю"
        case .hard: return "Трудно"
        case .good: return "Знаю"
        case .easy: return "Легко"
        }
    }

    var symbol: String {
        switch self {
        case .again: return "✕"
        case .hard: return "~"
        case .good: return "✓"
        case .easy: return "★"
        }
    }

    /// Чи зараховується відповідь як правильна.
    var isCorrect: Bool { self != .again }

    /// Числовий множник якості (0…1) для статистики точності.
    var quality: Double {
        switch self {
        case .again: return 0
        case .hard: return 0.5
        case .good: return 0.8
        case .easy: return 1.0
        }
    }

    /// Вага для нарахування досвіду (XP).
    var xpWeight: Int {
        switch self {
        case .again: return 1
        case .hard: return 2
        case .good: return 3
        case .easy: return 4
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Grade(rawValue: raw.uppercased()) ?? .again
    }
}

// MARK: - Фаза картки

enum CardPhase: String, Codable, CaseIterable, Hashable {
    case new = "NEW"
    case learning = "LEARNING"
    case review = "REVIEW"
    case relearning = "RELEARNING"

    var titleUk: String {
        switch self {
        case .new: return "Нова"
        case .learning: return "Вивчається"
        case .review: return "На повторенні"
        case .relearning: return "Переучується"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = CardPhase(rawValue: raw.uppercased()) ?? .new
    }
}

// MARK: - Мета навчання

enum LearningGoal: String, Codable, CaseIterable, Identifiable, Hashable {
    case communication = "COMMUNICATION"
    case relocation = "RELOCATION"
    case study = "STUDY"
    case travel = "TRAVEL"
    case work = "WORK"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .communication: return "Спілкування"
        case .relocation: return "Переїзд"
        case .study: return "Навчання"
        case .travel: return "Подорожі"
        case .work: return "Робота"
        }
    }

    var descriptionUk: String {
        switch self {
        case .communication: return "Друзі, серіали, музика, інтернет"
        case .relocation: return "Побут, документи, оренда житла, лікарі"
        case .study: return "Іспити, університет, сертифікати DELE"
        case .travel: return "Розмови в аеропорту, готелі, кафе, на вулиці"
        case .work: return "Ділове листування, зустрічі, професійна лексика"
        }
    }

    var systemImageName: String {
        switch self {
        case .communication: return "bubble.left.and.bubble.right"
        case .relocation: return "shippingbox"
        case .study: return "graduationcap"
        case .travel: return "airplane"
        case .work: return "briefcase"
        }
    }

    /// Граматичні теги, які варто підсилити для цієї мети.
    var priorityGrammarTags: [String] {
        switch self {
        case .communication: return ["present_irregular", "gustar", "question_words"]
        case .relocation: return ["ser_estar", "articles", "numbers", "polite_forms"]
        case .study: return ["past_tenses", "subjunctive_intro", "connectors"]
        case .travel: return ["polite_forms", "directions", "numbers", "time_expressions"]
        case .work: return ["formal_address", "past_tenses", "connectors"]
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = LearningGoal(rawValue: raw.uppercased()) ?? .communication
    }
}

// MARK: - Тема оформлення

enum ThemeMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .system: return "Як у системі"
        case .light: return "Світла"
        case .dark: return "Темна"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ThemeMode(rawValue: raw.uppercased()) ?? .system
    }
}

// MARK: - Голос синтезатора

enum TtsVoiceGender: String, Codable, CaseIterable, Identifiable, Hashable {
    case female = "FEMALE"
    case male = "MALE"
    case any = "ANY"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .female: return "Жіночий"
        case .male: return "Чоловічий"
        case .any: return "Будь-який"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = TtsVoiceGender(rawValue: raw.uppercased()) ?? .any
    }
}

// MARK: - Тип елемента навчання

enum ContentItemType: String, Codable, CaseIterable, Hashable {
    case word = "WORD"
    case sentence = "SENTENCE"
    case exercise = "EXERCISE"
    case listening = "LISTENING"

    var titleUk: String {
        switch self {
        case .word: return "Слово"
        case .sentence: return "Речення"
        case .exercise: return "Вправа"
        case .listening: return "Аудіювання"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ContentItemType(rawValue: raw.uppercased()) ?? .word
    }
}

// MARK: - Стан картки (spaced repetition)

struct CardState: Codable, Identifiable, Hashable {
    var itemId: String
    var itemType: ContentItemType
    var levelCode: String
    var topicId: String
    var grammarTags: [String]
    var phase: CardPhase
    /// Коли картку треба повторити.
    var dueAt: Date
    /// Інтервал для фаз learning/relearning — у хвилинах.
    var intervalMinutes: Int
    /// Інтервал для фази review — у днях.
    var intervalDays: Double
    /// Коефіцієнт легкості (стартує з 2.5, як у SM-2).
    var ease: Double
    var repetitions: Int
    var lapses: Int
    var totalReviews: Int
    var correctReviews: Int
    var averageResponseMs: Double
    var firstSeenAt: Date
    var lastReviewedAt: Date?
    var suspended: Bool
    var contentVersion: Int

    var id: String { itemId }

    /// Чи картка доступна для повторення зараз.
    func isDue(at date: Date = Date()) -> Bool {
        !suspended && dueAt <= date
    }

    /// Точність відповідей у відсотках.
    var accuracy: Double {
        guard totalReviews > 0 else { return 0 }
        return Double(correctReviews) / Double(totalReviews) * 100
    }

    /// Нова картка для елемента контенту.
    static func makeNew(
        itemId: String,
        itemType: ContentItemType,
        level: Level,
        topicId: String,
        grammarTags: [String],
        contentVersion: Int,
        now: Date = Date()
    ) -> CardState {
        CardState(
            itemId: itemId,
            itemType: itemType,
            levelCode: level.rawValue,
            topicId: topicId,
            grammarTags: grammarTags,
            phase: .new,
            dueAt: now,
            intervalMinutes: 0,
            intervalDays: 0,
            ease: SrsEngine.initialEase,
            repetitions: 0,
            lapses: 0,
            totalReviews: 0,
            correctReviews: 0,
            averageResponseMs: 0,
            firstSeenAt: now,
            lastReviewedAt: nil,
            suspended: false,
            contentVersion: contentVersion
        )
    }
}

// MARK: - Профіль користувача

struct UserProfile: Codable, Hashable {
    var level: Level
    var goal: LearningGoal
    var dailyMinutes: Int
    var themeMode: ThemeMode
    var ttsRate: Double
    var ttsVoiceGender: TtsVoiceGender
    var aiProviderId: String
    var aiModel: String
    var aiEndpoint: String
    var aiApiKey: String
    var allowExternalAi: Bool
    var assessmentDone: Bool
    var assessmentScore: Int
    var showListeningHints: Bool
    var startedAt: Date
    /// Чи завершено онбординг (у android-версії це виводиться з assessmentDone).
    var onboardingDone: Bool
    /// Імʼя, яке користувач ввів під час онбордингу (необовʼязково).
    var displayName: String
    /// Щоденна ціль за кількістю карток.
    var dailyCardGoal: Int
    /// Нагадування про заняття.
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    static let `default` = UserProfile(
        level: .a0,
        goal: .communication,
        dailyMinutes: 15,
        themeMode: .system,
        ttsRate: 0.45,
        ttsVoiceGender: .any,
        aiProviderId: "local",
        aiModel: "",
        aiEndpoint: "",
        aiApiKey: "",
        allowExternalAi: false,
        assessmentDone: false,
        assessmentScore: 0,
        showListeningHints: true,
        startedAt: Date(),
        onboardingDone: false,
        displayName: "",
        dailyCardGoal: 30,
        remindersEnabled: false,
        reminderHour: 19,
        reminderMinute: 0
    )
}

// MARK: - Статистика

/// Запис про один перегляд картки.
struct ReviewLogEntry: Codable, Identifiable, Hashable {
    var id: String
    var itemId: String
    var itemType: ContentItemType
    var grade: Grade
    var reviewedAt: Date
    var responseMs: Int
    var topicId: String
    var grammarTags: [String]
}

/// Щоденна статистика (ключ — дата у форматі `yyyy-MM-dd`).
struct DailyStat: Codable, Hashable {
    var day: String
    var reviews: Int
    var correct: Int
    var newCards: Int
    var minutes: Double
    var xp: Int
    var speakingAttempts: Int
    var listeningCompleted: Int

    static func empty(day: String) -> DailyStat {
        DailyStat(
            day: day,
            reviews: 0,
            correct: 0,
            newCards: 0,
            minutes: 0,
            xp: 0,
            speakingAttempts: 0,
            listeningCompleted: 0
        )
    }

    var accuracy: Double {
        guard reviews > 0 else { return 0 }
        return Double(correct) / Double(reviews) * 100
    }
}

/// Накопичена статистика помилок за словом або граматичним тегом.
struct MistakeStat: Codable, Hashable {
    var key: String
    var kind: String
    var attempts: Int
    var wrong: Int
    var lastWrongAt: Date?

    var errorRate: Double {
        guard attempts > 0 else { return 0 }
        return Double(wrong) / Double(attempts)
    }
}

/// «Слабке місце» — агрегована проблема за темою або граматикою.
struct WeakSpot: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var titleUk: String
    var wrong: Int
    var attempts: Int
    var errorRate: Double
}

// MARK: - Прогрес курсу

struct TopicProgress: Codable, Hashable {
    var topicId: String
    var startedAt: Date
    var completedAt: Date?
    var wordsLearned: Int
    var totalWords: Int
    var bestExerciseScore: Double

    var fraction: Double {
        guard totalWords > 0 else { return 0 }
        return min(1, Double(wordsLearned) / Double(totalWords))
    }
}

/// Знімок прогресу для екранів статистики.
struct ProgressSnapshot: Hashable {
    var streakDays: Int
    var longestStreak: Int
    var totalReviews: Int
    var totalMinutes: Double
    var totalXP: Int
    var accuracy: Double
    var wordsLearned: Int
    var wordsInProgress: Int
    var dueToday: Int
    var dueTomorrow: Int
    var level: Level
    var goalCompletion: Double
    var dailyGoal: Int
    var reviewsToday: Int
    var minutesToday: Double
}

// MARK: - AI-діалоги

enum AIMessageRole: String, Codable, Hashable {
    case user
    case assistant
    case system

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = AIMessageRole(rawValue: raw) ?? .assistant
    }
}

struct AIMessage: Codable, Identifiable, Hashable {
    var id: String
    var role: AIMessageRole
    var text: String
    var translationUk: String
    var corrections: [AICorrection]
    var createdAt: Date
}

struct AICorrection: Codable, Hashable {
    var original: String
    var corrected: String
    var explanationUk: String
}

/// Збережена розмова з AI-співрозмовником.
struct ConversationSession: Codable, Identifiable, Hashable {
    var id: String
    var scenarioId: String
    var scenarioTitleUk: String
    var mode: String
    var startedAt: Date
    var messages: [AIMessage]

    var userMessageCount: Int {
        messages.filter { $0.role == .user }.count
    }
}

// MARK: - Налаштування (не профільні)

struct AppSettings: Codable, Hashable {
    /// Автоматично озвучувати нові слова та речення.
    var autoPlayAudio: Bool
    /// Показувати переклад одразу (інакше — за кнопкою).
    var showTranslationFirst: Bool
    /// Показувати підказки вимови українськими літерами.
    var showPronunciationHints: Bool
    /// Показувати IPA.
    var showIpa: Bool
    /// Звуковий сигнал після відповіді.
    var answerSoundsEnabled: Bool
    /// Вібровідгук.
    var hapticsEnabled: Bool
    /// Розмір сесії (кількість карток).
    var sessionSize: Int
    /// Максимум нових карток на день.
    var newCardsPerDay: Int
    /// Максимум повторень на день.
    var reviewsPerDay: Int
    /// Чи показувати підказки в аудіюванні.
    var listeningHintsEnabled: Bool
    /// Мова інтерфейсу (поки що лише українська).
    var interfaceLanguage: String

    static let `default` = AppSettings(
        autoPlayAudio: true,
        showTranslationFirst: false,
        showPronunciationHints: true,
        showIpa: false,
        answerSoundsEnabled: true,
        hapticsEnabled: true,
        sessionSize: 20,
        newCardsPerDay: 10,
        reviewsPerDay: 100,
        listeningHintsEnabled: true,
        interfaceLanguage: "uk"
    )
}

// MARK: - Повний збережений стан застосунку

/// Один документ, який зберігається на диск (аналог набору таблиць Room в android-версії).
struct AppDataDocument: Codable {
    var schemaVersion: Int
    var contentVersion: Int
    var profile: UserProfile
    var settings: AppSettings
    var cards: [String: CardState]
    var reviewLog: [ReviewLogEntry]
    var dailyStats: [String: DailyStat]
    var mistakes: [String: MistakeStat]
    var topicProgress: [String: TopicProgress]
    var conversations: [ConversationSession]
    var savedAt: Date

    static func empty(contentVersion: Int) -> AppDataDocument {
        AppDataDocument(
            schemaVersion: AppDataDocument.currentSchemaVersion,
            contentVersion: contentVersion,
            profile: .default,
            settings: .default,
            cards: [:],
            reviewLog: [],
            dailyStats: [:],
            mistakes: [:],
            topicProgress: [:],
            conversations: [],
            savedAt: Date()
        )
    }

    static let currentSchemaVersion = 1
}

// MARK: - Допоміжне: ключі дат

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from key: String) -> Date? {
        formatter.date(from: key)
    }
}
