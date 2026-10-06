import Foundation

/// Рушій інтервального повторення — відтворює логіку android-версії
/// (`SrsScheduler` / `SrsEngine`); константи відновлено з оригінального APK.
enum SrsEngine {

    // MARK: - Константи (як в оригіналі)

    static let minuteMs: Double = 60_000
    static let dayMs: Double = 86_400_000

    /// Початковий коефіцієнт легкості.
    static let initialEase: Double = 2.5
    static let minEase: Double = 1.3
    static let maxEase: Double = 2.8
    /// Крок навчання після «трудно» (хвилини).
    static let learningStepMinutes: Int = 10
    /// Крок навчання після «не знаю» (хвилини).
    static let againStepMinutes: Int = 1
    /// Крок переучування після зриву (хвилини).
    static let relearningStepMinutes: Int = 10

    static let easeBonus: Double = 0.15
    static let easePenalty: Double = 0.15
    static let lapseEasePenalty: Double = 0.20
    /// Знижений штраф легкості для «трудно», якщо картка часто зривалася.
    static let hardEasePenalty: Double = 0.075
    /// Поріг частки зривів, після якого «трудно» знижує легкість.
    static let lapseRatioThreshold: Double = 0.4

    static let hardMultiplier: Double = 1.2
    static let easyBonus: Double = 1.25

    static let graduatingIntervalDays: Double = 1.0
    static let easyIntervalDays: Double = 4.0
    static let lapseIntervalDays: Double = 1.0
    static let maxIntervalDays: Double = 365.0

    /// Інтервал, з якого картка вважається вивченим словом.
    static let learnedIntervalDays: Double = 21.0

    /// Множники швидкості відповіді (`speedFactor` в оригіналі).
    static let speedFastRatio: Double = 0.6
    static let speedSlowRatio: Double = 1.6
    static let speedFastFactor: Double = 1.1
    static let speedSlowFactor: Double = 0.92

    // MARK: - Застосування оцінки

    /// Повертає оновлений стан картки після відповіді.
    static func apply(grade: Grade, to card: CardState, responseMs: Int = 0, now: Date = Date()) -> CardState {
        var updated = card

        updated.totalReviews += 1
        updated.lastReviewedAt = now
        if grade.isCorrect {
            updated.correctReviews += 1
        }
        // Середній час відповіді: (старе * 3 + нове) / 4 — як в оригіналі.
        updated.averageResponseMs = updated.averageResponseMs == 0
            ? Double(responseMs)
            : (updated.averageResponseMs * 3 + Double(responseMs)) / 4

        if grade == .again {
            updated.lapses += 1
        }

        switch card.phase {
        case .new, .learning:
            updated = applyLearning(grade: grade, to: updated, now: now)
        case .review:
            updated = applyReview(grade: grade, to: updated, responseMs: responseMs, now: now)
        case .relearning:
            updated = applyRelearning(grade: grade, to: updated, now: now)
        }

        return updated
    }

    // MARK: - Фаза навчання

    private static func applyLearning(grade: Grade, to card: CardState, now: Date) -> CardState {
        var updated = card
        switch grade {
        case .again:
            updated.phase = .learning
            updated.ease = max(minEase, card.ease - easePenalty)
            updated.intervalMinutes = againStepMinutes
            updated.intervalDays = 0
            updated.dueAt = now.addingTimeInterval(Double(againStepMinutes) * 60)

        case .hard:
            updated.phase = .learning
            updated.ease = max(minEase, card.ease - easePenalty)
            updated.intervalMinutes = learningStepMinutes
            updated.intervalDays = 0
            updated.dueAt = now.addingTimeInterval(Double(learningStepMinutes) * 60)

        case .good:
            // «Знаю» на навчанні — картка випускається у повторення.
            updated.phase = .review
            updated.intervalMinutes = 0
            updated.intervalDays = graduatingIntervalDays
            updated.repetitions += 1
            updated.dueAt = now.addingTimeInterval(graduatingIntervalDays * 86_400)

        case .easy:
            updated.phase = .review
            updated.intervalMinutes = 0
            updated.intervalDays = easyIntervalDays
            updated.repetitions += 1
            updated.ease = min(maxEase, card.ease + easeBonus)
            updated.dueAt = now.addingTimeInterval(easyIntervalDays * 86_400)
        }
        return updated
    }

    // MARK: - Фаза повторення

    private static func applyReview(grade: Grade, to card: CardState, responseMs: Int, now: Date) -> CardState {
        var updated = card
        let previous = max(card.intervalDays, lapseIntervalDays)

        switch grade {
        case .again:
            updated.ease = max(minEase, card.ease - lapseEasePenalty)
            updated.phase = .relearning
            updated.intervalMinutes = relearningStepMinutes
            updated.intervalDays = 0
            updated.dueAt = now.addingTimeInterval(Double(relearningStepMinutes) * 60)

        case .hard:
            let lapseRatio = card.totalReviews > 0 ? Double(card.lapses) / Double(card.totalReviews) : 0
            if lapseRatio > lapseRatioThreshold {
                updated.ease = max(minEase, card.ease - hardEasePenalty)
            }
            let hardBase = max(hardMultiplier * previous, previous + 1)
            let base = Swift.max(card.ease * previous, hardBase)
            updated.intervalDays = clampInterval(base * speedFactor(grade: grade, responseMs: responseMs, card: card))
            updated.intervalMinutes = 0
            updated.repetitions += 1
            updated.dueAt = now.addingTimeInterval(updated.intervalDays * 86_400)

        case .good:
            let base = previous * card.ease
            updated.intervalDays = clampInterval(base * speedFactor(grade: grade, responseMs: responseMs, card: card))
            updated.intervalMinutes = 0
            updated.repetitions += 1
            updated.dueAt = now.addingTimeInterval(updated.intervalDays * 86_400)

        case .easy:
            let base = previous * card.ease * easyBonus
            updated.intervalDays = clampInterval(base * speedFactor(grade: grade, responseMs: responseMs, card: card))
            updated.intervalMinutes = 0
            updated.repetitions += 1
            updated.ease = min(maxEase, card.ease + easeBonus)
            updated.dueAt = now.addingTimeInterval(updated.intervalDays * 86_400)
        }
        return updated
    }

    // MARK: - Фаза переучування

    private static func applyRelearning(grade: Grade, to card: CardState, now: Date) -> CardState {
        var updated = card
        switch grade {
        case .again:
            updated.intervalMinutes = againStepMinutes
            updated.dueAt = now.addingTimeInterval(Double(againStepMinutes) * 60)

        case .hard:
            updated.intervalMinutes = relearningStepMinutes
            updated.dueAt = now.addingTimeInterval(Double(relearningStepMinutes) * 60)

        case .good, .easy:
            // Повернення у повторення з коротким інтервалом.
            let base = grade == .easy ? lapseIntervalDays * easyBonus : lapseIntervalDays
            updated.phase = .review
            updated.intervalMinutes = 0
            updated.intervalDays = clampInterval(base)
            updated.repetitions += 1
            updated.dueAt = now.addingTimeInterval(updated.intervalDays * 86_400)
        }
        return updated
    }

    // MARK: - Допоміжні розрахунки

    /// Множник швидкості відповіді: швидка відповідь трохи подовжує інтервал,
    /// повільна — скорочує.
    static func speedFactor(grade: Grade, responseMs: Int, card: CardState) -> Double {
        guard grade != .again else { return 1.0 }
        guard responseMs > 0, card.averageResponseMs > 0 else { return 1.0 }
        let ratio = Double(responseMs) / card.averageResponseMs
        if ratio < speedFastRatio { return speedFastFactor }
        if ratio > speedSlowRatio { return speedSlowFactor }
        return 1.0
    }

    private static func clampInterval(_ days: Double) -> Double {
        min(maxIntervalDays, max(1, days.rounded(.towardZero)))
    }

    // MARK: - Передпрогляд і підписи

    static func preview(grade: Grade, for card: CardState, now: Date = Date()) -> String {
        let updated = apply(grade: grade, to: card, now: now)
        return intervalLabel(for: updated)
    }

    static func previews(for card: CardState, now: Date = Date()) -> [GradePreview] {
        Grade.allCases.map { grade in
            GradePreview(grade: grade, intervalText: preview(grade: grade, for: card, now: now))
        }
    }

    /// Людський опис інтервалу. Хвилини мають приоритет над днями — як в оригіналі.
    static func intervalLabel(for card: CardState) -> String {
        if card.intervalMinutes > 0 {
            let minutes = card.intervalMinutes
            if minutes < 60 { return "\(minutes) хв" }
            let hours = Int((Double(minutes) / 60).rounded())
            return "\(hours) год"
        }
        let days = Int(max(0, card.intervalDays))
        if days < 1 { return "зараз" }
        if days < 31 { return "\(days) дн" }
        if days < 365 {
            let months = Int((Double(days) / 30).rounded())
            return "\(months) міс"
        }
        return "1 рік"
    }

    /// Чи картка вважається вивченою (інтервал 21 день і більше).
    static func isLearned(_ card: CardState) -> Bool {
        card.phase == .review && card.intervalDays >= learnedIntervalDays
    }

    /// Точність картки у відсотках (як `retention` в оригіналі).
    static func retention(_ card: CardState) -> Int {
        guard card.totalReviews > 0 else { return 0 }
        return card.correctReviews * 100 / card.totalReviews
    }

    /// Узагальнена «міцність» знання (0…100).
    static func strength(_ card: CardState) -> Double {
        let accuracy = Double(retention(card))
        let intervalScore = min(100.0, card.intervalDays / maxIntervalDays * 100)
        let easeScore = (card.ease - minEase) / (maxEase - minEase) * 100
        return (accuracy * 0.5 + intervalScore * 0.3 + easeScore * 0.2).rounded()
    }
}

/// Передпрогляд інтервалу для кнопки оцінки.
struct GradePreview: Identifiable, Hashable {
    var id: String { grade.rawValue }
    var grade: Grade
    var intervalText: String
}
