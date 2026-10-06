import Foundation

// MARK: - Блоки заняття

/// Складові частини заняття (порядок у плані — як у android-версії).
enum SessionBlockKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case newWords = "NEW_WORDS"
    case review = "REVIEW"
    case grammar = "GRAMMAR"
    case exercises = "EXERCISES"
    case listening = "LISTENING"
    case speaking = "SPEAKING"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .newWords: return "Нові слова"
        case .review: return "Повторення"
        case .grammar: return "Граматика"
        case .exercises: return "Вправи"
        case .listening: return "Аудіювання"
        case .speaking: return "Говоріння"
        }
    }

    var systemImageName: String {
        switch self {
        case .newWords: return "sparkles"
        case .review: return "arrow.triangle.2.circlepath"
        case .grammar: return "text.book.closed"
        case .exercises: return "pencil.and.list.clipboard"
        case .listening: return "headphones"
        case .speaking: return "mic"
        }
    }

    /// Орієнтовний час на один елемент блоку (хвилини).
    var minutesPerItem: Double {
        switch self {
        case .newWords: return 0.7
        case .review: return 0.3
        case .grammar: return 2.0
        case .exercises: return 0.8
        case .listening: return 3.0
        case .speaking: return 1.2
        }
    }
}

// MARK: - Тип завдання для слова

/// Як саме показувати слово під час навчання.
enum StudyPromptKind: String, Codable, CaseIterable, Hashable {
    /// Іспанське слово → вибір українського перекладу.
    case recognize
    /// Український переклад → ввести іспанське слово.
    case recall
    /// Почути іспанське слово → ввести його.
    case listen
    /// Скласти речення зі слів.
    case buildSentence

    var titleUk: String {
        switch self {
        case .recognize: return "Оберіть переклад"
        case .recall: return "Напишіть іспанською"
        case .listen: return "Напишіть, що почули"
        case .buildSentence: return "Складіть речення"
        }
    }
}

// MARK: - Елемент заняття

/// Один крок заняття. Обгортка над контентом, яку показує екран сесії.
enum SessionItem: Identifiable, Hashable {
    case word(Word, StudyPromptKind)
    case sentence(Sentence, StudyPromptKind)
    case exercise(Exercise)
    case grammar(GrammarNote)
    case listening(ListeningItem)

    var id: String {
        switch self {
        case .word(let word, let prompt): return "word:\(word.id):\(prompt.rawValue)"
        case .sentence(let sentence, let prompt): return "sentence:\(sentence.id):\(prompt.rawValue)"
        case .exercise(let exercise): return "exercise:\(exercise.id)"
        case .grammar(let note): return "grammar:\(note.id)"
        case .listening(let item): return "listening:\(item.id)"
        }
    }

    /// Ідентифікатор контенту без типу завдання — ключ для картки SRS.
    var contentId: String {
        switch self {
        case .word(let word, _): return word.id
        case .sentence(let sentence, _): return sentence.id
        case .exercise(let exercise): return exercise.id
        case .grammar(let note): return note.id
        case .listening(let item): return item.id
        }
    }

    var itemType: ContentItemType {
        switch self {
        case .word: return .word
        case .sentence: return .sentence
        case .exercise: return .exercise
        case .grammar: return .sentence
        case .listening: return .listening
        }
    }

    var level: Level {
        switch self {
        case .word(let word, _): return word.level
        case .sentence(let sentence, _): return sentence.level
        case .exercise(let exercise): return exercise.level
        case .grammar(let note): return note.level
        case .listening(let item): return item.level
        }
    }

    var topicId: String {
        switch self {
        case .word(let word, _): return word.topicId
        case .sentence(let sentence, _): return sentence.topicId
        case .exercise(let exercise): return exercise.topicId
        case .grammar: return ""
        case .listening(let item): return item.topicId
        }
    }

    var grammarTags: [String] {
        switch self {
        case .word(let word, _): return word.grammarTags
        case .sentence(let sentence, _): return sentence.grammarTags
        case .exercise(let exercise): return exercise.grammarTag.isEmpty ? [] : [exercise.grammarTag]
        case .grammar(let note): return [note.tag]
        case .listening: return []
        }
    }

    /// Іспанський текст для озвучення (nil — озвучувати нічого).
    var spanishForSpeech: String? {
        switch self {
        case .word(let word, let prompt):
            return prompt == .recognize ? word.spanishWithArticle : word.spanish
        case .sentence(let sentence, _): return sentence.spanish
        case .exercise(let exercise):
            if exercise.kind == .listening || exercise.kind == .dictation { return exercise.answerEs }
            return exercise.promptEs.isEmpty ? nil : exercise.promptEs
        case .grammar(let note): return note.examples.first?.spanish
        case .listening(let item): return item.fullText
        }
    }

    /// Український текст-підказка.
    var ukrainianText: String? {
        switch self {
        case .word(let word, _): return word.translationUk
        case .sentence(let sentence, _): return sentence.translationUk
        case .exercise(let exercise): return exercise.promptUk.isEmpty ? nil : exercise.promptUk
        case .grammar(let note): return note.titleUk
        case .listening(let item): return item.titleUk
        }
    }

    var titleText: String {
        switch self {
        case .word(let word, _): return word.spanishWithArticle
        case .sentence(let sentence, _): return sentence.spanish
        case .exercise(let exercise): return exercise.promptEs.isEmpty ? exercise.promptUk : exercise.promptEs
        case .grammar(let note): return note.titleEs.isEmpty ? note.titleUk : note.titleEs
        case .listening(let item): return item.titleEs.isEmpty ? item.titleUk : item.titleEs
        }
    }

    /// Чи потрібна для цього кроку картка SRS.
    var isSrsGraded: Bool {
        switch self {
        case .word, .sentence: return true
        case .exercise, .listening: return true
        case .grammar: return false
        }
    }
}

// MARK: - Блок і план заняття

struct SessionBlock: Identifiable, Hashable {
    var id: String { kind.rawValue }
    var kind: SessionBlockKind
    var items: [SessionItem]

    var estimatedMinutes: Double {
        Double(items.count) * kind.minutesPerItem
    }
}

struct SessionPlan: Identifiable, Hashable {
    var id: String
    var level: Level
    var createdAt: Date
    var blocks: [SessionBlock]
    var focusTopicId: String?
    var focusTopicTitleUk: String?

    var allItems: [SessionItem] {
        blocks.flatMap(\.items)
    }

    var itemCount: Int { allItems.count }

    var estimatedMinutes: Int {
        max(1, Int(blocks.reduce(0) { $0 + $1.estimatedMinutes }.rounded()))
    }

    var isEmpty: Bool { allItems.isEmpty }

    /// Позиція елемента в межах усього заняття.
    func position(of item: SessionItem) -> Int? {
        allItems.firstIndex(of: item)
    }

    func block(for item: SessionItem) -> SessionBlock? {
        blocks.first { $0.items.contains(item) }
    }
}

// MARK: - Стан заняття

/// Поточний прогрес проходження заняття.
struct SessionProgress: Hashable {
    var currentIndex: Int
    var totalItems: Int
    var correct: Int
    var wrong: Int
    var startedAt: Date

    var fraction: Double {
        guard totalItems > 0 else { return 0 }
        return min(1, Double(currentIndex) / Double(totalItems))
    }

    var accuracy: Double {
        let attempts = correct + wrong
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts) * 100
    }

    var isFinished: Bool { currentIndex >= totalItems }

    static func start(totalItems: Int) -> SessionProgress {
        SessionProgress(
            currentIndex: 0,
            totalItems: totalItems,
            correct: 0,
            wrong: 0,
            startedAt: Date()
        )
    }
}

// MARK: - Відповідь на крок

/// Результат одного кроку заняття — те, що показує екран після перевірки.
struct SessionAnswerFeedback: Hashable {
    var isCorrect: Bool
    var messageUk: String
    var correctAnswer: String
    var explanationUk: String

    static func correct(_ message: String = "Правильно!") -> SessionAnswerFeedback {
        SessionAnswerFeedback(isCorrect: true, messageUk: message, correctAnswer: "", explanationUk: "")
    }

    static func wrong(correctAnswer: String, explanation: String = "") -> SessionAnswerFeedback {
        SessionAnswerFeedback(
            isCorrect: false,
            messageUk: "Правильна відповідь:",
            correctAnswer: correctAnswer,
            explanationUk: explanation
        )
    }
}
