import Foundation

/// Складає план заняття з контенту курсу та поточного прогресу користувача.
///
/// Порядок блоків: повторення → нові слова → граматика → вправи → аудіювання → говоріння.
/// Порожні блоки не додаються. Розмір заняття обмежується `AppSettings.sessionSize`
/// та щоденними лімітами `newCardsPerDay` / `reviewsPerDay`.
struct LessonBuilder {

    /// Скільки нових слів давати за одне заняття.
    static let newWordsPerSession = 8
    /// Скільки карток повторення брати за одне заняття.
    static let reviewItemsPerSession = 60

    var content: CourseContent
    var progress: ProgressStore
    var settings: AppSettings
    var profile: UserProfile

    // MARK: - Побудова плану

    func buildPlan(
        level: Level? = nil,
        topicId: String? = nil,
        now: Date = Date()
    ) -> SessionPlan {
        let targetLevel = level ?? profile.level
        let topic = topicId.flatMap { content.topic($0) }

        var blocks: [SessionBlock] = []

        // Порядок блоків як в оригіналі: повторення → нові слова → граматика → вправи → аудіювання → говоріння.
        let reviewItems = buildReview(level: targetLevel, now: now)
        if !reviewItems.isEmpty {
            blocks.append(SessionBlock(kind: .review, items: reviewItems))
        }

        let newWordItems = buildNewWords(level: targetLevel, topicId: topicId, now: now)
        if !newWordItems.isEmpty {
            blocks.append(SessionBlock(kind: .newWords, items: newWordItems))
        }

        let grammarItems = buildGrammar(level: targetLevel, topic: topic)
        if !grammarItems.isEmpty {
            blocks.append(SessionBlock(kind: .grammar, items: grammarItems))
        }

        let exerciseItems = buildExercises(level: targetLevel, topicId: topicId)
        if !exerciseItems.isEmpty {
            blocks.append(SessionBlock(kind: .exercises, items: exerciseItems))
        }

        let listeningItems = buildListening(level: targetLevel, topicId: topicId)
        if !listeningItems.isEmpty {
            blocks.append(SessionBlock(kind: .listening, items: listeningItems))
        }

        let speakingItems = buildSpeaking(level: targetLevel, topicId: topicId)
        if !speakingItems.isEmpty {
            blocks.append(SessionBlock(kind: .speaking, items: speakingItems))
        }

        return SessionPlan(
            id: UUID().uuidString,
            level: targetLevel,
            createdAt: now,
            blocks: blocks,
            focusTopicId: topicId,
            focusTopicTitleUk: topic?.titleUk
        )
    }

    // MARK: - Нові слова

    private func buildNewWords(level: Level, topicId: String?, now: Date) -> [SessionItem] {
        // За одне заняття — не більше 8 нових слів (як в оригіналі), і не більше
        // за денний ліміт користувача.
        let dailyLimit = max(1, settings.newCardsPerDay)
        let today = progress.dailyStat(for: now)
        let remainingToday = max(0, dailyLimit - today.newCards)
        let limit = min(LessonBuilder.newWordsPerSession, remainingToday)
        guard limit > 0 else { return [] }

        let candidates = content.words(level: level, topicId: topicId)
            .filter { progress.card(for: $0.id) == nil }

        return candidates
            .prefix(limit)
            .map { word in
                SessionItem.word(word, promptKind(for: word, isNew: true))
            }
    }

    /// Нове слово показуємо на вибір перекладу, знайоме — на введення.
    private func promptKind(for word: Word, isNew: Bool) -> StudyPromptKind {
        if isNew { return .recognize }
        let card = progress.card(for: word.id)
        guard let card else { return .recognize }
        if card.lapses >= 2 { return .recognize }
        if card.intervalDays >= 7 { return .listen }
        return .recall
    }

    // MARK: - Повторення

    private func buildReview(level: Level, now: Date) -> [SessionItem] {
        // Не більше 60 карток за заняття (як в оригіналі) і не більше за денний ліміт.
        let limit = min(LessonBuilder.reviewItemsPerSession, max(1, settings.reviewsPerDay))
        let due = progress.dueCards(at: now)
            .filter { $0.levelCode == level.rawValue || $0.levelCode.isEmpty }
            .prefix(limit)

        var items: [SessionItem] = []
        for card in due {
            switch card.itemType {
            case .word:
                if let word = content.word(card.itemId) {
                    items.append(.word(word, promptKind(for: word, isNew: false)))
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
        return items
    }

    // MARK: - Граматика

    private func buildGrammar(level: Level, topic: Topic?) -> [SessionItem] {
        let tags: [String]
        if let topic, !topic.grammarTags.isEmpty {
            tags = topic.grammarTags
        } else {
            tags = profile.goal.priorityGrammarTags
        }

        let notes = content.grammarNotes(tags: tags)
            .filter { $0.level.order <= level.order }
            .prefix(2)

        return notes.map { SessionItem.grammar($0) }
    }

    // MARK: - Вправи

    private func buildExercises(level: Level, topicId: String?) -> [SessionItem] {
        let weakTags = Set(weakGrammarTags())
        var pool = content.exercises(level: level, topicId: topicId)
        if pool.isEmpty {
            pool = content.exercises(level: level)
        }

        // Спершу вправи на слабкі теми, далі — решта.
        let weak = pool.filter { weakTags.contains($0.grammarTag) }
        let rest = pool.filter { !weakTags.contains($0.grammarTag) }

        let limit = 8
        var selected: [Exercise] = []
        var kindCounts: [ExerciseKind: Int] = [:]

        // Розмаїття типів: не більше двох вправ одного типу підряд.
        for exercise in weak + rest.shuffled() {
            guard selected.count < limit else { break }
            let count = kindCounts[exercise.kind, default: 0]
            if count >= 2 { continue }
            kindCounts[exercise.kind] = count + 1
            selected.append(exercise)
        }

        return selected.map { SessionItem.exercise($0) }
    }

    // MARK: - Аудіювання

    private func buildListening(level: Level, topicId: String?) -> [SessionItem] {
        let items = content.listening(level: level, topicId: topicId)
        let fallback = items.isEmpty ? content.listening(level: level) : items
        return fallback.prefix(1).map { SessionItem.listening($0) }
    }

    // MARK: - Говоріння

    private func buildSpeaking(level: Level, topicId: String?) -> [SessionItem] {
        // Вправи типу «вимова» плюс короткі речення для читання вголос.
        let speakingExercises = content
            .exercises(level: level, topicId: topicId, kind: .speaking)
            .prefix(3)
            .map { SessionItem.exercise($0) }

        if !speakingExercises.isEmpty { return Array(speakingExercises) }

        return content.sentences(level: level, topicId: topicId)
            .filter { $0.spanish.count <= 60 }
            .prefix(3)
            .map { SessionItem.sentence($0, .recall) }
    }

    // MARK: - Слабкі місця

    private func weakGrammarTags() -> [String] {
        progress.document.mistakes.values
            .filter { $0.kind == "grammar" && $0.errorRate >= 0.3 }
            .sorted { $0.errorRate > $1.errorRate }
            .prefix(5)
            .map(\.key)
    }
}

// MARK: - Перевірка кроку заняття

/// Перевіряє відповідь користувача на конкретному кроці заняття.
enum SessionChecker {

    static func check(item: SessionItem, userAnswer: String) -> SessionAnswerFeedback {
        switch item {
        case .word(let word, let prompt):
            return checkWord(word, prompt: prompt, userAnswer: userAnswer)
        case .sentence(let sentence, _):
            let result = AnswerCheck.check(userAnswer, expected: sentence.spanish)
            if result.isCorrect {
                return SessionAnswerFeedback(
                    isCorrect: true,
                    messageUk: result.messageUk,
                    correctAnswer: sentence.spanish,
                    explanationUk: sentence.audioHint
                )
            }
            return .wrong(correctAnswer: sentence.spanish, explanation: sentence.translationUk)
        case .exercise(let exercise):
            return checkExercise(exercise, userAnswer: userAnswer)
        case .grammar:
            // Граматичні картки не оцінюються — це довідковий матеріал.
            return .correct("Прочитано")
        case .listening(let listening):
            let result = AnswerCheck.check(userAnswer, expected: listening.lines.first?.spanish ?? "")
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: listening.lines.first?.spanish ?? "")
        }
    }

    private static func checkWord(_ word: Word, prompt: StudyPromptKind, userAnswer: String) -> SessionAnswerFeedback {
        let expected: String
        switch prompt {
        case .recognize:
            expected = word.translationUk
        case .recall, .listen, .buildSentence:
            expected = word.spanish
        }

        let result = AnswerCheck.check(userAnswer, expected: expected)
        if result.isCorrect {
            return SessionAnswerFeedback(
                isCorrect: true,
                messageUk: result.messageUk,
                correctAnswer: expected,
                explanationUk: word.notesUk
            )
        }
        return .wrong(correctAnswer: expected, explanation: word.exampleEs)
    }

    private static func checkExercise(_ exercise: Exercise, userAnswer: String) -> SessionAnswerFeedback {
        switch exercise.kind {
        case .multipleChoice, .translationEsUk:
            let result = AnswerCheck.check(userAnswer, anyOf: [exercise.answerUk, exercise.answerEs])
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: exercise.answerUk.isEmpty ? exercise.answerEs : exercise.answerUk,
                          explanation: exercise.explanationUk)

        case .translationUkEs, .dictation, .speaking:
            let result = AnswerCheck.check(userAnswer, expected: exercise.answerEs)
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: exercise.answerEs, explanation: exercise.explanationUk)

        case .fillGap:
            let expected = exercise.gapAnswer.isEmpty ? exercise.answerEs : exercise.gapAnswer
            let result = AnswerCheck.check(userAnswer, expected: expected)
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: expected, explanation: exercise.explanationUk)

        case .sentenceBuild, .matchPairs:
            let result = AnswerCheck.check(userAnswer, expected: exercise.answerEs, allowTypo: false)
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: exercise.answerEs, explanation: exercise.explanationUk)

        case .listening:
            let result = AnswerCheck.check(userAnswer, expected: exercise.answerEs)
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: exercise.answerEs, explanation: exercise.explanationUk)

        case .unknown:
            let result = AnswerCheck.check(userAnswer, anyOf: [exercise.answerEs, exercise.answerUk])
            if result.isCorrect { return .correct(result.messageUk) }
            return .wrong(correctAnswer: exercise.answerEs, explanation: exercise.explanationUk)
        }
    }

    /// Оцінка для SRS на основі результату перевірки.
    static func grade(for item: SessionItem, userAnswer: String, usedHint: Bool) -> Grade {
        switch item {
        case .grammar:
            return .good
        case .exercise(let exercise):
            let result = exerciseResult(exercise, userAnswer: userAnswer)
            if !result.isCorrect { return .again }
            return usedHint ? .hard : (result == .exact ? .good : .good)
        default:
            let feedback = check(item: item, userAnswer: userAnswer)
            if !feedback.isCorrect { return .again }
            return usedHint ? .hard : .good
        }
    }

    private static func exerciseResult(_ exercise: Exercise, userAnswer: String) -> AnswerCheck.Result {
        switch exercise.kind {
        case .multipleChoice, .translationEsUk:
            return AnswerCheck.check(userAnswer, anyOf: [exercise.answerUk, exercise.answerEs])
        case .fillGap:
            return AnswerCheck.check(userAnswer, expected: exercise.gapAnswer.isEmpty ? exercise.answerEs : exercise.gapAnswer)
        default:
            return AnswerCheck.check(userAnswer, expected: exercise.answerEs)
        }
    }
}
