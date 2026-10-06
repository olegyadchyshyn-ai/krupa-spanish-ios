import Foundation

// MARK: - Рівень володіння мовою

/// Три рівні контенту застосунку. Сирі значення збігаються з тими, що вживаються
/// в JSON-контенті (`"A0"`, `"A1"`, `"A2"`).
enum Level: String, Codable, CaseIterable, Identifiable, Hashable {
    case a0 = "A0"
    case a1 = "A1"
    case a2 = "A2"

    var id: String { rawValue }

    /// Порядок вивчення: A0 → A1 → A2.
    var order: Int {
        switch self {
        case .a0: return 0
        case .a1: return 1
        case .a2: return 2
        }
    }

    var title: String {
        switch self {
        case .a0: return "A0"
        case .a1: return "A1"
        case .a2: return "A2"
        }
    }

    var subtitleUk: String {
        switch self {
        case .a0: return "З нуля"
        case .a1: return "Базовий"
        case .a2: return "Побутовий"
        }
    }

    /// Наступний рівень (для переходу після завершення курсу).
    var next: Level? {
        switch self {
        case .a0: return .a1
        case .a1: return .a2
        case .a2: return nil
        }
    }

    /// Невідоме значення не валить застосунок — повертаємо A0.
    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Level(rawValue: raw.uppercased()) ?? .a0
    }
}

// MARK: - Частина мови

enum PartOfSpeech: String, Codable, CaseIterable, Hashable {
    case noun
    case verb
    case phrase
    case adjective
    case numeral
    case adverb
    case pronoun
    case interjection
    case preposition
    case unknown

    var titleUk: String {
        switch self {
        case .noun: return "іменник"
        case .verb: return "дієслово"
        case .phrase: return "фраза"
        case .adjective: return "прикметник"
        case .numeral: return "числівник"
        case .adverb: return "прислівник"
        case .pronoun: return "займенник"
        case .interjection: return "вигук"
        case .preposition: return "прийменник"
        case .unknown: return "інше"
        }
    }

    var shortTitleUk: String {
        switch self {
        case .noun: return "імен."
        case .verb: return "дієсл."
        case .phrase: return "фраза"
        case .adjective: return "прикм."
        case .numeral: return "числ."
        case .adverb: return "присл."
        case .pronoun: return "займ."
        case .interjection: return "вигук"
        case .preposition: return "прийм."
        case .unknown: return "інше"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = PartOfSpeech(rawValue: raw) ?? .unknown
    }
}

// MARK: - Рід іменника

enum Gender: String, Codable, CaseIterable, Hashable {
    case masculine = "m"
    case feminine = "f"
    case both = "mf"
    case noGender = "none"

    /// Порожній рядок для слів, у яких роду немає (дієслова, прислівники тощо).
    var marker: String {
        switch self {
        case .masculine: return "m"
        case .feminine: return "f"
        case .both: return "m/f"
        case .noGender: return ""
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = Gender(rawValue: raw) ?? .noGender
    }
}

// MARK: - Типи вправ

/// Дев'ять типів вправ, які трапляються в контенті.
enum ExerciseKind: String, Codable, CaseIterable, Hashable {
    case multipleChoice = "multiple_choice"
    case translationUkEs = "translation_uk_es"
    case translationEsUk = "translation_es_uk"
    case fillGap = "fill_gap"
    case sentenceBuild = "sentence_build"
    case listening
    case speaking
    case dictation
    case matchPairs = "match_pairs"
    case unknown

    var titleUk: String {
        switch self {
        case .multipleChoice: return "Вибір відповіді"
        case .translationUkEs: return "Переклад українською → іспанською"
        case .translationEsUk: return "Переклад іспанською → українською"
        case .fillGap: return "Заповни пропуск"
        case .sentenceBuild: return "Склади речення"
        case .listening: return "Аудіювання"
        case .speaking: return "Вимова"
        case .dictation: return "Диктант"
        case .matchPairs: return "Зістав пари"
        case .unknown: return "Вправа"
        }
    }

    /// Коротка назва для чипів у списках.
    var shortTitleUk: String {
        switch self {
        case .multipleChoice: return "вибір"
        case .translationUkEs: return "UK→ES"
        case .translationEsUk: return "ES→UK"
        case .fillGap: return "пропуск"
        case .sentenceBuild: return "речення"
        case .listening: return "аудіо"
        case .speaking: return "вимова"
        case .dictation: return "диктант"
        case .matchPairs: return "пари"
        case .unknown: return "вправа"
        }
    }

    /// Чи потрібен мікрофон для цієї вправи.
    var needsMicrophone: Bool { self == .speaking }

    /// Чи потрібне відтворення аудіо синтезатором мовлення.
    var needsSpeech: Bool {
        switch self {
        case .listening, .dictation, .speaking: return true
        default: return false
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ExerciseKind(rawValue: raw) ?? .unknown
    }
}

// MARK: - Типи речень і аудіювання

enum SentenceKind: String, Codable, CaseIterable, Hashable {
    case phrase
    case dialogue
    case story
    case unknown

    var titleUk: String {
        switch self {
        case .phrase: return "Фраза"
        case .dialogue: return "Діалог"
        case .story: return "Розповідь"
        case .unknown: return "Речення"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = SentenceKind(rawValue: raw) ?? .unknown
    }
}

enum ListeningKind: String, Codable, CaseIterable, Hashable {
    case dialogue
    case story
    case monologue
    case podcast
    case unknown

    var titleUk: String {
        switch self {
        case .dialogue: return "Діалог"
        case .story: return "Історія"
        case .monologue: return "Монолог"
        case .podcast: return "Подкаст"
        case .unknown: return "Аудіювання"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = ListeningKind(rawValue: raw) ?? .unknown
    }
}

// MARK: - Слово

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let spanish: String
    let translationUk: String
    let partOfSpeech: PartOfSpeech
    let gender: Gender
    let plural: String
    /// Складова підказка вимови українськими літерами, напр. «ПО-йо».
    let pronunciation: String
    /// IPA-транскрипція, напр. «[ˈpo.ʝo]».
    let ipaHint: String
    let exampleEs: String
    let exampleUk: String
    let level: Level
    let topicId: String
    let withArticle: Bool
    let grammarTags: [String]
    let notesUk: String
    let cognateNoteUk: String
    let frequencyRank: Int

    /// Іспанське слово разом з артиклем, якщо він потрібен (el/la).
    var spanishWithArticle: String {
        guard withArticle else { return spanish }
        switch gender {
        case .masculine: return "el \(spanish)"
        case .feminine: return "la \(spanish)"
        case .both, .noGender: return spanish
        }
    }

    var hasNotes: Bool { !notesUk.isEmpty || !cognateNoteUk.isEmpty }
}

// MARK: - Речення

struct Sentence: Codable, Identifiable, Hashable {
    let id: String
    let spanish: String
    let translationUk: String
    let level: Level
    let topicId: String
    let kind: SentenceKind
    let grammarTags: [String]
    let wordIds: [String]
    let audioHint: String
}

// MARK: - Вправа

struct Exercise: Codable, Identifiable, Hashable {
    let id: String
    let kind: ExerciseKind
    let level: Level
    let topicId: String
    let grammarTag: String
    let promptUk: String
    let promptEs: String
    let answerEs: String
    let answerUk: String
    let distractors: [String]
    let tokens: [String]
    let gapText: String
    let gapAnswer: String
    let relatedWordIds: [String]
    let relatedSentenceId: String
    let explanationUk: String
    let difficulty: Int

    /// Варіанти для вибору: правильна відповідь + дистрактори, перемішані детерміновано.
    func choices(shuffled: Bool) -> [String] {
        var items = distractors
        switch kind {
        case .translationEsUk, .multipleChoice:
            items.insert(answerUk, at: 0)
        default:
            items.insert(answerEs, at: 0)
        }
        guard shuffled else { return items }
        return items.shuffled()
    }

    /// Токени для складання речення (якщо контент їх не дає — розбиваємо відповідь).
    var buildTokens: [String] {
        if !tokens.isEmpty { return tokens }
        return answerEs
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .split(separator: " ")
            .map(String.init)
    }
}

// MARK: - Граматика

struct GrammarExample: Codable, Hashable {
    let spanish: String
    let translationUk: String
    let noteUk: String
}

struct GrammarNote: Codable, Identifiable, Hashable {
    let id: String
    let tag: String
    let level: Level
    let titleEs: String
    let titleUk: String
    let explanationUk: String
    let patternUk: String
    let examples: [GrammarExample]
    let commonMistakeUk: String
    let tipForUkSpeakersUk: String
    let orderIndex: Int
}

// MARK: - Аудіювання

struct ListeningLine: Codable, Hashable {
    let speaker: String
    let spanish: String
    let translationUk: String
}

struct ListeningKeyWord: Codable, Hashable {
    let spanish: String
    let translationUk: String
}

struct ComprehensionQuestion: Codable, Hashable {
    let questionUk: String
    let options: [String]
    let correctIndex: Int
    let explanationUk: String

    var correctOption: String? {
        guard options.indices.contains(correctIndex) else { return nil }
        return options[correctIndex]
    }
}

struct ListeningItem: Codable, Identifiable, Hashable {
    let id: String
    let level: Level
    let topicId: String
    let titleEs: String
    let titleUk: String
    let kind: ListeningKind
    let orderIndex: Int
    let lines: [ListeningLine]
    let keyWords: [ListeningKeyWord]
    let comprehensionQuestions: [ComprehensionQuestion]

    /// Повний текст запису — його озвучує синтезатор мовлення.
    var fullText: String {
        lines.map(\.spanish).joined(separator: " ")
    }

    /// Перелік голосів (для діалогів — різні голоси на репліку).
    var speakers: [String] {
        var seen: [String] = []
        for line in lines where !seen.contains(line.speaker) {
            seen.append(line.speaker)
        }
        return seen
    }
}

// MARK: - Тема

struct Topic: Codable, Identifiable, Hashable {
    let id: String
    let level: Level
    let titleEs: String
    let titleUk: String
    let descriptionUk: String
    let iconKey: String
    let orderIndex: Int
    let grammarTags: [String]

    /// SF Symbol для теми — відповідник android-іконки `iconKey`.
    var systemImageName: String {
        switch iconKey {
        case "numbers": return "number"
        case "clock": return "clock"
        case "family": return "person.2"
        case "food": return "fork.knife"
        case "restaurant": return "wineglass"
        case "shopping": return "cart"
        case "home": return "house"
        case "city": return "building.2"
        case "travel": return "airplane"
        case "transport": return "tram"
        case "work": return "briefcase"
        case "health": return "cross.case"
        case "weather": return "cloud.sun"
        case "tech": return "laptopcomputer"
        case "hobby": return "gamecontroller"
        case "opinion": return "bubble.left.and.bubble.right"
        case "past": return "clock.arrow.circlepath"
        case "person": return "person.crop.circle"
        case "polite": return "hand.raised"
        case "greetings": return "hand.wave"
        case "verbs": return "text.book.closed"
        case "errands": return "checklist"
        case "survival": return "lifepreserver"
        default: return "book"
        }
    }
}

// MARK: - Пакет контенту

/// Один файл контенту з теки `Resources/Content`.
struct ContentPack: Codable, Hashable {
    let contentVersion: Int
    let words: [Word]?
    let sentences: [Sentence]?
    let exercises: [Exercise]?
    let grammar: [GrammarNote]?
    let listening: [ListeningItem]?
    let topics: [Topic]?
}

/// Повний контент курсу, зібраний з усіх файлів і проіндексований для швидкого доступу.
struct CourseContent {
    let contentVersion: Int
    let words: [Word]
    let sentences: [Sentence]
    let exercises: [Exercise]
    let grammar: [GrammarNote]
    let listening: [ListeningItem]
    let topics: [Topic]

    private let wordsById: [String: Word]
    private let sentencesById: [String: Sentence]
    private let exercisesById: [String: Exercise]
    private let grammarById: [String: GrammarNote]
    private let listeningById: [String: ListeningItem]
    private let topicsById: [String: Topic]

    init(
        contentVersion: Int,
        words: [Word],
        sentences: [Sentence],
        exercises: [Exercise],
        grammar: [GrammarNote],
        listening: [ListeningItem],
        topics: [Topic]
    ) {
        self.contentVersion = contentVersion
        self.words = words
        self.sentences = sentences
        self.exercises = exercises
        self.grammar = grammar
        self.listening = listening
        self.topics = topics

        self.wordsById = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.sentencesById = Dictionary(sentences.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.exercisesById = Dictionary(exercises.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.grammarById = Dictionary(grammar.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.listeningById = Dictionary(listening.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.topicsById = Dictionary(topics.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static let empty = CourseContent(
        contentVersion: 1,
        words: [],
        sentences: [],
        exercises: [],
        grammar: [],
        listening: [],
        topics: []
    )

    // MARK: Доступ за ідентифікатором

    func word(_ id: String) -> Word? { wordsById[id] }
    func sentence(_ id: String) -> Sentence? { sentencesById[id] }
    func exercise(_ id: String) -> Exercise? { exercisesById[id] }
    func grammarNote(_ id: String) -> GrammarNote? { grammarById[id] }
    func listeningItem(_ id: String) -> ListeningItem? { listeningById[id] }
    func topic(_ id: String) -> Topic? { topicsById[id] }

    // MARK: Вибірки

    func words(level: Level, topicId: String? = nil) -> [Word] {
        words.filter { $0.level == level && (topicId == nil || $0.topicId == topicId) }
            .sorted { $0.frequencyRank < $1.frequencyRank }
    }

    func sentences(level: Level, topicId: String? = nil) -> [Sentence] {
        sentences.filter { $0.level == level && (topicId == nil || $0.topicId == topicId) }
    }

    func exercises(level: Level, topicId: String? = nil, kind: ExerciseKind? = nil) -> [Exercise] {
        exercises.filter {
            $0.level == level
                && (topicId == nil || $0.topicId == topicId)
                && (kind == nil || $0.kind == kind)
        }
    }

    func topics(level: Level) -> [Topic] {
        topics.filter { $0.level == level }.sorted { $0.orderIndex < $1.orderIndex }
    }

    func listening(level: Level, topicId: String? = nil) -> [ListeningItem] {
        listening
            .filter { $0.level == level && (topicId == nil || $0.topicId == topicId) }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    func grammarNotes(level: Level) -> [GrammarNote] {
        grammar.filter { $0.level == level }.sorted { $0.orderIndex < $1.orderIndex }
    }

    func grammarNote(tag: String) -> GrammarNote? {
        grammar.first { $0.tag == tag }
    }

    func grammarNotes(tags: [String]) -> [GrammarNote] {
        tags.compactMap { grammarNote(tag: $0) }
    }

    /// Слова теми, відсортовані за частотою.
    func words(topicId: String) -> [Word] {
        words.filter { $0.topicId == topicId }.sorted { $0.frequencyRank < $1.frequencyRank }
    }

    /// Усі слова, що відповідають граматичному тегу.
    func words(grammarTag: String) -> [Word] {
        words.filter { $0.grammarTags.contains(grammarTag) }
    }
}
