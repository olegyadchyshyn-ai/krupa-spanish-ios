import Foundation
import SwiftUI

/// Єдине сховище стану користувача: профіль, налаштування, картки повторення,
/// журнал відповідей, щоденна статистика, помилки та AI-розмови.
///
/// Дані зберігаються одним JSON-документом в `Application Support`.
/// Запис — відкладений (debounce), щоб не смикати диск на кожну відповідь.
@MainActor
final class ProgressStore: ObservableObject {

    @Published private(set) var document: AppDataDocument

    /// Коли востаннє стан успішно записано на диск.
    @Published private(set) var lastSavedAt: Date?

    /// Остання помилка збереження (показується на екрані діагностики).
    @Published private(set) var lastSaveError: String?

    private let fileURL: URL
    private var pendingSave: Task<Void, Never>?

    /// Скільки чекати перед записом на диск після зміни.
    private let saveDebounce: Duration = .seconds(1)

    // MARK: - Ініціалізація

    init(contentVersion: Int = 1, directory: URL? = nil) {
        let dir = directory ?? ProgressStore.defaultDirectory()
        self.fileURL = dir.appendingPathComponent("progress.json")
        self.document = AppDataDocument.empty(contentVersion: contentVersion)
        loadFromDisk()
    }

    static func defaultDirectory() -> URL {
        let fm = FileManager.default
        if let url = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let appDir = url.appendingPathComponent("KrupaSpanish", isDirectory: true)
            if (try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)) != nil {
                return appDir
            }
            return url
        }
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs
    }

    // MARK: - Читання й запис

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }

    func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try ProgressStore.makeDecoder().decode(AppDataDocument.self, from: data)
            document = loaded
            lastSavedAt = loaded.savedAt
        } catch {
            lastSaveError = "Не вдалося прочитати збережений прогрес: \(error.localizedDescription)"
            // Пробуємо зберегти пошкоджений файл, щоб не втратити дані остаточно.
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("progress-broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: fileURL, to: backup)
        }
    }

    /// Планує запис на диск (із невеликою затримкою).
    func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.saveDebounce)
            if Task.isCancelled { return }
            self.saveNow()
        }
    }

    func saveNow() {
        document.savedAt = Date()
        do {
            let data = try ProgressStore.makeEncoder().encode(document)
            try data.write(to: fileURL, options: [.atomic])
            lastSavedAt = document.savedAt
            lastSaveError = nil
        } catch {
            lastSaveError = "Не вдалося зберегти прогрес: \(error.localizedDescription)"
        }
    }

    /// Повний JSON стану — для резервної копії.
    func exportData() throws -> Data {
        try ProgressStore.makeEncoder().encode(document)
    }

    /// Замінює стан даними з резервної копії.
    func importData(_ data: Data) throws {
        let loaded = try ProgressStore.makeDecoder().decode(AppDataDocument.self, from: data)
        document = loaded
        saveNow()
    }

    /// Повністю очищає прогрес (профіль і налаштування повертаються до типових).
    func resetAll() {
        let version = document.contentVersion
        document = AppDataDocument.empty(contentVersion: version)
        saveNow()
    }

    /// Замінює документ стану цілком (використовується імпортом резервної копії).
    func replaceDocument(with newDocument: AppDataDocument) {
        document = newDocument
        saveNow()
        objectWillChange.send()
    }

    // MARK: - Профіль і налаштування

    var profile: UserProfile { document.profile }
    var settings: AppSettings { document.settings }

    func updateProfile(_ mutate: (inout UserProfile) -> Void) {
        var copy = document.profile
        mutate(&copy)
        document.profile = copy
        scheduleSave()
        objectWillChange.send()
    }

    func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        var copy = document.settings
        mutate(&copy)
        document.settings = copy
        scheduleSave()
        objectWillChange.send()
    }

    // MARK: - Картки

    var cards: [String: CardState] { document.cards }

    func card(for itemId: String) -> CardState? {
        document.cards[itemId]
    }

    /// Повертає наявну картку або створює нову для елемента контенту.
    func cardOrCreate(
        itemId: String,
        itemType: ContentItemType,
        level: Level,
        topicId: String,
        grammarTags: [String]
    ) -> CardState {
        if let existing = document.cards[itemId] { return existing }
        let new = CardState.makeNew(
            itemId: itemId,
            itemType: itemType,
            level: level,
            topicId: topicId,
            grammarTags: grammarTags,
            contentVersion: document.contentVersion
        )
        document.cards[itemId] = new
        scheduleSave()
        return new
    }

    func upsert(_ card: CardState) {
        document.cards[card.itemId] = card
        scheduleSave()
    }

    func setSuspended(_ suspended: Bool, itemId: String) {
        guard var card = document.cards[itemId] else { return }
        card.suspended = suspended
        document.cards[itemId] = card
        scheduleSave()
    }

    /// Картки, які час повторити.
    func dueCards(at date: Date = Date()) -> [CardState] {
        document.cards.values
            .filter { $0.isDue(at: date) && $0.phase != .new }
            .sorted { $0.dueAt < $1.dueAt }
    }

    /// Нові картки, які ще жодного разу не показували.
    func newCards() -> [CardState] {
        document.cards.values.filter { $0.phase == .new && !$0.suspended }
    }

    func cardsInPhase(_ phase: CardPhase) -> [CardState] {
        document.cards.values.filter { $0.phase == phase }
    }

    /// Скільки карток заплановано на вказаний день.
    func dueCount(on day: Date) -> Int {
        let calendar = Calendar.current
        return document.cards.values.filter { card in
            !card.suspended && card.phase != .new && calendar.isDate(card.dueAt, inSameDayAs: day)
        }.count
    }

    // MARK: - Відповіді та статистика

    /// Записує результат відповіді: оновлює картку, журнал, щоденну статистику й помилки.
    func recordAnswer(
        card updatedCard: CardState,
        grade: Grade,
        responseMs: Int,
        minutesSpent: Double,
        mistakeKeys: [String]
    ) {
        let now = Date()
        let isFirstReview = (document.cards[updatedCard.itemId]?.totalReviews ?? 0) == 0

        document.cards[updatedCard.itemId] = updatedCard

        let entry = ReviewLogEntry(
            id: UUID().uuidString,
            itemId: updatedCard.itemId,
            itemType: updatedCard.itemType,
            grade: grade,
            reviewedAt: now,
            responseMs: responseMs,
            topicId: updatedCard.topicId,
            grammarTags: updatedCard.grammarTags
        )
        document.reviewLog.append(entry)
        // Журнал обмежуємо, щоб файл не ріс безкінечно.
        if document.reviewLog.count > 5000 {
            document.reviewLog.removeFirst(document.reviewLog.count - 5000)
        }

        bumpDailyStat { stat in
            stat.reviews += 1
            if grade.isCorrect { stat.correct += 1 }
            if isFirstReview { stat.newCards += 1 }
            stat.minutes += minutesSpent
            stat.xp += grade.xpWeight
        }

        for key in mistakeKeys {
            recordMistake(key: key, correct: grade.isCorrect, at: now)
        }

        scheduleSave()
    }

    func dailyStat(for day: Date) -> DailyStat {
        let key = DayKey.key(for: day)
        return document.dailyStats[key] ?? DailyStat.empty(day: key)
    }

    var todayStat: DailyStat { dailyStat(for: Date()) }

    func bumpDailyStat(_ mutate: (inout DailyStat) -> Void) {
        let key = DayKey.key(for: Date())
        var stat = document.dailyStats[key] ?? DailyStat.empty(day: key)
        mutate(&stat)
        document.dailyStats[key] = stat
        scheduleSave()
    }

    /// Фіксує спробу за ключем (слово або граматичний тег) — для «слабких місць».
    func recordMistake(key: String, kind: String = "word", correct: Bool, at date: Date = Date()) {
        guard !key.isEmpty else { return }
        var stat = document.mistakes[key] ?? MistakeStat(
            key: key,
            kind: kind,
            attempts: 0,
            wrong: 0,
            lastWrongAt: nil
        )
        stat.attempts += 1
        if !correct {
            stat.wrong += 1
            stat.lastWrongAt = date
        }
        document.mistakes[key] = stat
        scheduleSave()
    }

    // MARK: - Прогрес тем

    func topicProgress(_ topicId: String) -> TopicProgress? {
        document.topicProgress[topicId]
    }

    func updateTopicProgress(_ topicId: String, _ mutate: (inout TopicProgress) -> Void) {
        var progress = document.topicProgress[topicId] ?? TopicProgress(
            topicId: topicId,
            startedAt: Date(),
            completedAt: nil,
            wordsLearned: 0,
            totalWords: 0,
            bestExerciseScore: 0
        )
        mutate(&progress)
        document.topicProgress[topicId] = progress
        scheduleSave()
    }

    // MARK: - AI-розмови

    var conversations: [ConversationSession] { document.conversations }

    func saveConversation(_ session: ConversationSession) {
        if let index = document.conversations.firstIndex(where: { $0.id == session.id }) {
            document.conversations[index] = session
        } else {
            document.conversations.insert(session, at: 0)
        }
        if document.conversations.count > 100 {
            document.conversations.removeLast(document.conversations.count - 100)
        }
        scheduleSave()
    }

    func deleteConversation(id: String) {
        document.conversations.removeAll { $0.id == id }
        scheduleSave()
    }

    // MARK: - Зведення прогресу

    /// Серія днів поспіль із заняттями (враховує сьогодні або вчора як продовження).
    var streakDays: Int {
        let calendar = Calendar.current
        var streak = 0
        var day = Date()
        // Якщо сьогодні ще не займалися — серія може тривати з учора.
        if dailyStat(for: day).reviews == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        while true {
            let stat = dailyStat(for: day)
            if stat.reviews > 0 {
                streak += 1
                guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = previous
            } else {
                break
            }
        }
        return streak
    }

    /// Найдовша серія за всю історію.
    var longestStreak: Int {
        let days = document.dailyStats.values
            .filter { $0.reviews > 0 }
            .compactMap { DayKey.date(from: $0.day) }
            .sorted()
        guard !days.isEmpty else { return 0 }
        let calendar = Calendar.current
        var best = 1
        var current = 1
        for index in 1..<days.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: days[index - 1]),
               calendar.isDate(expected, inSameDayAs: days[index]) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    func snapshot() -> ProgressSnapshot {
        let cards = Array(document.cards.values)
        let reviewed = cards.filter { $0.totalReviews > 0 }
        let totalReviews = cards.reduce(0) { $0 + $1.totalReviews }
        let totalCorrect = cards.reduce(0) { $0 + $1.correctReviews }
        let totalMinutes = document.dailyStats.values.reduce(0) { $0 + $1.minutes }
        let totalXP = document.dailyStats.values.reduce(0) { $0 + $1.xp }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let today = todayStat

        let learned = reviewed.filter { $0.phase == .review && $0.intervalDays >= SrsEngine.learnedIntervalDays }.count
        let inProgress = reviewed.count - learned

        return ProgressSnapshot(
            streakDays: streakDays,
            longestStreak: longestStreak,
            totalReviews: totalReviews,
            totalMinutes: totalMinutes,
            totalXP: totalXP,
            accuracy: totalReviews > 0 ? Double(totalCorrect) / Double(totalReviews) * 100 : 0,
            wordsLearned: learned,
            wordsInProgress: max(0, inProgress),
            dueToday: dueCards().count,
            dueTomorrow: dueCount(on: tomorrow),
            level: document.profile.level,
            goalCompletion: min(1, Double(today.reviews) / Double(max(1, document.profile.dailyCardGoal))),
            dailyGoal: document.profile.dailyCardGoal,
            reviewsToday: today.reviews,
            minutesToday: today.minutes
        )
    }

    /// Найслабші місця за граматичними тегами та словами (для екрана прогресу).
    func weakSpots(limit: Int = 10) -> [WeakSpot] {
        let tagStats = document.mistakes.values
            .filter { $0.kind == "grammar" && $0.attempts >= 3 && $0.errorRate > 0.3 }
        let wordStats = document.mistakes.values
            .filter { $0.kind == "word" && $0.attempts >= 3 && $0.errorRate > 0.3 }

        let combined = (tagStats + wordStats)
            .sorted { lhs, rhs in
                if lhs.errorRate != rhs.errorRate { return lhs.errorRate > rhs.errorRate }
                return lhs.wrong > rhs.wrong
            }
            .prefix(limit)

        return combined.map { stat in
            WeakSpot(
                key: stat.key,
                titleUk: stat.key,
                wrong: stat.wrong,
                attempts: stat.attempts,
                errorRate: stat.errorRate
            )
        }
    }
}
