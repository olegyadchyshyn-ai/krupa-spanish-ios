import Foundation
import Combine
import SwiftUI

/// Центральний стан застосунку: контент курсу та всі сервіси.
///
/// Створюється один раз у точці входу й передається екранам через
/// `@EnvironmentObject`. Зміни у вкладених сервісах транслюються назовні,
/// тому екранам достатньо спостерігати лише за `AppState`.
@MainActor
final class AppState: ObservableObject {

    /// Контент курсу, завантажений із бандла.
    let content: CourseContent
    /// Зауваження до контенту (порожній список = усе гаразд).
    let contentIssues: [String]

    let progress: ProgressStore
    let speech: SpeechService
    let recognition: SpeechRecognitionService
    let ai: AIService
    let backup: BackupService

    private var cancellables = Set<AnyCancellable>()

    init() {
        let store = ContentStore.shared
        let loaded = store.loadIfNeeded()

        self.content = loaded
        self.contentIssues = store.loadIssues
        self.progress = ProgressStore(contentVersion: loaded.contentVersion)
        self.speech = SpeechService()
        self.recognition = SpeechRecognitionService()
        self.ai = AIService()
        self.backup = BackupService()

        applySpeechSettings()
        forwardChanges()
    }

    // MARK: - Трансляція змін

    /// Скорочення до профілю користувача (лише читання).
    var profile: UserProfile { progress.profile }

    /// Скорочення до налаштувань (лише читання).
    var settings: AppSettings { progress.settings }

    private func forwardChanges() {
        let publishers: [ObservableObjectPublisher] = [
            progress.objectWillChange,
            speech.objectWillChange,
            recognition.objectWillChange,
            ai.objectWillChange,
            backup.objectWillChange
        ]
        for publisher in publishers {
            publisher
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Мовлення

    /// Застосовує налаштування голосу з профілю.
    func applySpeechSettings() {
        speech.configure(rate: progress.profile.ttsRate, gender: progress.profile.ttsVoiceGender)
    }

    /// Озвучує іспанський текст, якщо користувач не вимкнув автозвук.
    func speak(_ text: String, force: Bool = false) {
        guard force || progress.settings.autoPlayAudio else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        applySpeechSettings()
        speech.speak(text)
    }

    /// Озвучує слово так, як його показують на картці.
    func speak(word: Word) {
        speak(word.spanish)
    }

    // MARK: - Навчання

    /// Створює конструктор занять із поточними налаштуваннями.
    func makeLessonBuilder() -> LessonBuilder {
        LessonBuilder(
            content: content,
            progress: progress,
            settings: progress.settings,
            profile: progress.profile
        )
    }

    /// Готує заняття (з урахуванням теми, якщо вона вказана).
    func makePlan(topicId: String? = nil) -> SessionPlan {
        makeLessonBuilder().buildPlan(topicId: topicId)
    }

    /// Готує сесію повторення лише з карток, які вже час повторити.
    func makeReviewPlan() -> SessionPlan {
        let due = progress.dueCards()
        var items: [SessionItem] = []
        for card in due {
            switch card.itemType {
            case .word:
                if let word = content.word(card.itemId) {
                    items.append(.word(word, card.phase == .review ? .recall : .recognize))
                }
            case .sentence:
                if let sentence = content.sentence(card.itemId) {
                    items.append(.sentence(sentence, .recall))
                }
            case .exercise:
                if let exercise = content.exercise(card.itemId) {
                    items.append(.exercise(exercise))
                }
            case .listening:
                if let listening = content.listeningItem(card.itemId) {
                    items.append(.listening(listening))
                }
            }
        }
        return SessionPlan(
            id: UUID().uuidString,
            level: progress.profile.level,
            createdAt: Date(),
            blocks: items.isEmpty ? [] : [SessionBlock(kind: .review, items: items)],
            focusTopicId: nil,
            focusTopicTitleUk: nil
        )
    }

    /// Теми поточного рівня з часткою вивчених слів.
    func topicsWithProgress(level: Level? = nil) -> [(topic: Topic, fraction: Double, wordsCount: Int)] {
        let targetLevel = level ?? progress.profile.level
        return content.topics(level: targetLevel).map { topic in
            let words = content.words(topicId: topic.id)
            let learned = words.filter { word in
                guard let card = progress.card(for: word.id) else { return false }
                return SrsEngine.isLearned(card)
            }.count
            let fraction = words.isEmpty ? 0 : Double(learned) / Double(words.count)
            return (topic, fraction, words.count)
        }
    }

    /// Слово з прогресом — для списків.
    func wordsWithProgress(level: Level, topicId: String? = nil) -> [(word: Word, card: CardState?)] {
        content.words(level: level, topicId: topicId).map { word in
            (word, progress.card(for: word.id))
        }
    }

    // MARK: - Запис відповіді

    /// Записує відповідь на картку: оновлює SRS, статистику та «слабкі місця».
    func recordAnswer(
        item: SessionItem,
        grade: Grade,
        userAnswer: String,
        usedHint: Bool,
        responseMs: Int
    ) {
        guard item.isSrsGraded else { return }

        let existing = progress.cardOrCreate(
            itemId: item.contentId,
            itemType: item.itemType,
            level: item.level,
            topicId: item.topicId,
            grammarTags: item.grammarTags
        )
        let updated = SrsEngine.apply(grade: grade, to: existing, responseMs: responseMs)

        var mistakeKeys: [String] = []
        if !grade.isCorrect || usedHint {
            for tag in item.grammarTags {
                mistakeKeys.append(tag)
                progress.recordMistake(key: tag, kind: "grammar", correct: grade.isCorrect)
            }
            if case .word(let word, _) = item {
                mistakeKeys.append(word.id)
            }
        } else {
            for tag in item.grammarTags {
                progress.recordMistake(key: tag, kind: "grammar", correct: true)
            }
        }

        let minutes = max(0.05, Double(responseMs) / 60_000)
        progress.recordAnswer(
            card: updated,
            grade: grade,
            responseMs: responseMs,
            minutesSpent: minutes,
            mistakeKeys: mistakeKeys
        )
    }

    /// Позначає проходження аудіювання.
    func markListeningCompleted() {
        progress.bumpDailyStat { $0.listeningCompleted += 1 }
    }

    /// Позначає спробу вимови.
    func markSpeakingAttempt() {
        progress.bumpDailyStat { $0.speakingAttempts += 1 }
    }

    // MARK: - Налаштування теми

    var preferredColorScheme: ColorScheme? {
        switch progress.profile.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
