import Foundation

/// Експорт та імпорт прогресу у файл (відповідник android `ProgressBackup`).
///
/// Формат — один JSON-документ із заголовком: його можна зберегти у Файлах,
/// надіслати собі в месенджері чи перенести на інший пристрій.
@MainActor
final class BackupService: ObservableObject {

    /// Опис вмісту резервної копії — показується перед імпортом.
    struct Summary: Hashable {
        var exportedAt: Date
        var contentVersion: Int
        var schemaVersion: Int
        var cardsCount: Int
        var reviewsCount: Int
        var level: Level
        var applicationName: String

        var descriptionUk: String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "uk_UA")
            return """
            Копію створено: \(formatter.string(from: exportedAt))
            Рівень: \(level.rawValue)
            Карток: \(cardsCount), відповідей у журналі: \(reviewsCount)
            """
        }
    }

    /// Заголовок файлу резервної копії.
    private struct BackupEnvelope: Codable {
        var application: String
        var formatVersion: Int
        var exportedAt: Date
        var contentVersion: Int
        var cardsCount: Int
        var reviewsCount: Int
        var level: Level
        var data: AppDataDocument
    }

    private static let formatVersion = 1
    private static let applicationName = "KRUPA Spanish"

    @Published private(set) var lastError: String?
    @Published private(set) var lastExportURL: URL?

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Експорт

    /// Створює файл резервної копії в тимчасовій теці й повертає посилання на нього.
    @discardableResult
    func export(progress: ProgressStore) -> URL? {
        lastError = nil
        let document = progress.document
        let envelope = BackupEnvelope(
            application: Self.applicationName,
            formatVersion: Self.formatVersion,
            exportedAt: Date(),
            contentVersion: document.contentVersion,
            cardsCount: document.cards.count,
            reviewsCount: document.reviewLog.count,
            level: document.profile.level,
            data: document
        )

        do {
            let data = try Self.makeEncoder().encode(envelope)
            // Назва файлу як в оригіналі: krupa_spanish_progress_2025-01-31_1845.json
            let name = "krupa_spanish_progress_\(Self.fileStamp()).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            lastExportURL = url
            return url
        } catch {
            lastError = "Не вдалося створити резервну копію: \(error.localizedDescription)"
            return nil
        }
    }

    /// Мітка часу для назви файлу: `yyyy-MM-dd_HHmm`.
    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }

    // MARK: - Читання заголовка

    /// Читає лише заголовок файлу — щоб показати користувачу, що саме він імпортує.
    func inspect(url: URL) throws -> Summary {
        let data = try Data(contentsOf: url)
        let envelope = try Self.makeDecoder().decode(BackupEnvelope.self, from: data)
        return Summary(
            exportedAt: envelope.exportedAt,
            contentVersion: envelope.contentVersion,
            schemaVersion: envelope.data.schemaVersion,
            cardsCount: envelope.cardsCount,
            reviewsCount: envelope.reviewsCount,
            level: envelope.level,
            applicationName: envelope.application
        )
    }

    // MARK: - Імпорт

    enum ImportMode {
        /// Замінити весь прогрес даними з копії.
        case replace
        /// Додати картки та статистику до наявних (конфлікти — на користь копії).
        case merge
    }

    /// Завантажує резервну копію в застосунок.
    @discardableResult
    func importBackup(from url: URL, into progress: ProgressStore, mode: ImportMode = .replace) throws -> Summary {
        lastError = nil

        // Файл може прийти з-поза пісочниці — відкриваємо з доступом.
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let envelope = try Self.makeDecoder().decode(BackupEnvelope.self, from: data)
        let summary = Summary(
            exportedAt: envelope.exportedAt,
            contentVersion: envelope.contentVersion,
            schemaVersion: envelope.data.schemaVersion,
            cardsCount: envelope.cardsCount,
            reviewsCount: envelope.reviewsCount,
            level: envelope.level,
            applicationName: envelope.application
        )

        switch mode {
        case .replace:
            progress.importData(try Self.makeEncoder().encode(envelope.data))
        case .merge:
            progress.merge(document: envelope.data)
        }

        return summary
    }

    /// Зчитує JSON, який користувач вставив текстом (аварійний спосіб відновлення).
    func importBackup(jsonText: String, into progress: ProgressStore) throws -> Summary {
        guard let data = jsonText.data(using: .utf8) else {
            throw NSError(domain: "BackupService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Текст не схожий на резервну копію."
            ])
        }
        let envelope = try Self.makeDecoder().decode(BackupEnvelope.self, from: data)
        // importData теж кидає виняток — тому обидва виклики з `try`.
        try progress.importData(Self.makeEncoder().encode(envelope.data))
        return Summary(
            exportedAt: envelope.exportedAt,
            contentVersion: envelope.contentVersion,
            schemaVersion: envelope.data.schemaVersion,
            cardsCount: envelope.cardsCount,
            reviewsCount: envelope.reviewsCount,
            level: envelope.level,
            applicationName: envelope.application
        )
    }
}

extension ProgressStore {
    /// Додає дані з резервної копії до наявного прогресу.
    func merge(document incoming: AppDataDocument) {
        var current = self.document

        for (key, card) in incoming.cards {
            if let existing = current.cards[key] {
                // Беремо картку з більшою кількістю повторень.
                current.cards[key] = existing.totalReviews >= card.totalReviews ? existing : card
            } else {
                current.cards[key] = card
            }
        }

        let knownLogIds = Set(current.reviewLog.map(\.id))
        current.reviewLog.append(contentsOf: incoming.reviewLog.filter { !knownLogIds.contains($0.id) })

        for (day, stat) in incoming.dailyStats {
            if let existing = current.dailyStats[day] {
                current.dailyStats[day] = DailyStat(
                    day: day,
                    reviews: max(existing.reviews, stat.reviews),
                    correct: max(existing.correct, stat.correct),
                    newCards: max(existing.newCards, stat.newCards),
                    minutes: max(existing.minutes, stat.minutes),
                    xp: max(existing.xp, stat.xp),
                    speakingAttempts: max(existing.speakingAttempts, stat.speakingAttempts),
                    listeningCompleted: max(existing.listeningCompleted, stat.listeningCompleted)
                )
            } else {
                current.dailyStats[day] = stat
            }
        }

        for (key, mistake) in incoming.mistakes {
            if let existing = current.mistakes[key] {
                current.mistakes[key] = MistakeStat(
                    key: key,
                    kind: existing.kind,
                    attempts: existing.attempts + mistake.attempts,
                    wrong: existing.wrong + mistake.wrong,
                    lastWrongAt: max(existing.lastWrongAt ?? .distantPast, mistake.lastWrongAt ?? .distantPast)
                )
            } else {
                current.mistakes[key] = mistake
            }
        }

        for (topicId, topicProgress) in incoming.topicProgress where current.topicProgress[topicId] == nil {
            current.topicProgress[topicId] = topicProgress
        }

        let knownConversations = Set(current.conversations.map(\.id))
        current.conversations.append(contentsOf: incoming.conversations.filter { !knownConversations.contains($0.id) })

        self.replaceDocument(with: current)
    }
}
