import SwiftUI

// MARK: - Тренування вимови

/// Екран тренування вимови: показує фразу-еталон, записує голос і оцінює
/// вимову (відповідник android `SpeakingScreen`).
struct SpeakingScreen: View {
    @EnvironmentObject private var app: AppState

    /// Джерело фраз для тренування.
    private enum Mode: String, CaseIterable, Identifiable {
        case words
        case sentences
        case free

        var id: String { rawValue }

        var titleUk: String {
            switch self {
            case .words: return "Слова"
            case .sentences: return "Речення"
            case .free: return "Вільна фраза"
            }
        }

        var systemImageName: String {
            switch self {
            case .words: return "character.book.closed"
            case .sentences: return "text.alignleft"
            case .free: return "square.and.pencil"
            }
        }
    }

    @State private var mode: Mode = .words
    @State private var currentIndex = 0
    @State private var freeText = ""
    @State private var showsTranslation = false

    /// Результат останньої спроби.
    @State private var result: PronunciationResult?
    @State private var errorMessage: String?

    /// Лічильники сеансу: скільки фраз опрацьовано та сума оцінок.
    @State private var attemptCount = 0
    @State private var scoreSum = 0

    // MARK: - Дані

    /// Черга фраз для обраного режиму (відповідник android `SpeakingPrompt`).
    private var phrases: [SpeakingPhrase] {
        switch mode {
        case .words:
            return app.content.words(level: app.profile.level).map { word in
                SpeakingPhrase(
                    id: "sp_word_\(word.id)",
                    spanish: word.spanish,
                    translationUk: word.translationUk,
                    hintUk: wordHint(word)
                )
            }
        case .sentences:
            return app.content.sentences(level: app.profile.level).map { sentence in
                SpeakingPhrase(
                    id: "sp_sent_\(sentence.id)",
                    spanish: sentence.spanish,
                    translationUk: sentence.translationUk,
                    hintUk: sentence.kind.titleUk
                )
            }
        case .free:
            let trimmed = freeText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }
            return [SpeakingPhrase(id: "sp_free", spanish: trimmed, translationUk: "", hintUk: "")]
        }
    }

    private var currentPhrase: SpeakingPhrase? {
        let list = phrases
        guard !list.isEmpty else { return nil }
        let index = min(max(0, currentIndex), list.count - 1)
        return list[index]
    }

    private var averageScore: Int {
        guard attemptCount > 0 else { return 0 }
        return Int((Double(scoreSum) / Double(attemptCount)).rounded())
    }

    private var recordingSubtitle: String {
        app.recognition.isRecording ? "Слухаю… говоріть" : "Натисніть і говоріть"
    }

    private func wordHint(_ word: Word) -> String {
        var parts: [String] = []
        if !word.pronunciation.isEmpty {
            parts.append("Вимова: \(word.pronunciation)")
        }
        if word.withArticle {
            parts.append("З артиклем: \(word.spanishWithArticle)")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Вигляд

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                modeSelector

                if mode == .free {
                    freeTextCard
                }

                if let phrase = currentPhrase {
                    promptCard(phrase: phrase)
                    recordCard(phrase: phrase)
                    if let result {
                        resultCard(result: result)
                    }
                } else if mode != .free {
                    emptyState
                }

                sessionStats

                if let errorMessage {
                    ErrorBanner(message: errorMessage, retryTitle: nil, onRetry: nil)
                }
            }
            .padding(KrupaSpacing.screenPadding)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Вимова")
        .onChange(of: mode) { oldValue, newValue in
            _ = oldValue
            _ = newValue
            resetSession()
        }
        .onChange(of: app.profile.level) { oldValue, newValue in
            _ = oldValue
            _ = newValue
            resetSession()
        }
        .onDisappear { stopEverything() }
    }

    // MARK: Перемикач режимів

    private var modeSelector: some View {
        HStack(spacing: KrupaSpacing.xs) {
            ForEach(Mode.allCases, id: \.rawValue) { item in
                Button {
                    mode = item
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.systemImageName)
                            .font(.system(size: 11, weight: .semibold))
                        Text(item.titleUk)
                            .font(.krupaSmall)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(mode == item ? Color.white : Color.krupaTextSecondary)
                    .background(mode == item ? Color.krupaBrand : Color.krupaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.titleUk)
            }
        }
    }

    // MARK: Вільна фраза

    private var freeTextCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Вільна фраза",
                    subtitle: "Введіть іспанський текст, який хочете потренувати.",
                    systemImage: "square.and.pencil"
                )
                KrupaTextField(
                    placeholder: "Напишіть фразу іспанською",
                    text: $freeText,
                    isFocused: false,
                    onSubmit: { }
                )
            }
        }
    }

    // MARK: Фраза-еталон

    private func promptCard(phrase: SpeakingPhrase) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Скажіть уголос:",
                    subtitle: "Послухайте зразок, а потім повторіть уголос.",
                    systemImage: "quote.bubble"
                )

                HStack(alignment: .center, spacing: KrupaSpacing.sm) {
                    Text(phrase.spanish)
                        .font(.krupaSpanishWord)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    SpeakerButton(
                        isSpeaking: app.speech.isSpeakingText(phrase.spanish),
                        size: 22,
                        action: { speakSample(phrase: phrase) }
                    )
                }

                if !phrase.hintUk.isEmpty {
                    Text(phrase.hintUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsTranslation, !phrase.translationUk.isEmpty {
                    Text(phrase.translationUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: KrupaSpacing.sm) {
                    SecondaryActionButton(
                        title: "Зразок",
                        systemImage: "speaker.wave.2.fill",
                        tint: .krupaBrand,
                        action: { speakSample(phrase: phrase) }
                    )
                    SecondaryActionButton(
                        title: "Повільно",
                        systemImage: "tortoise",
                        tint: .krupaBrandDark,
                        action: { speakSlow(phrase: phrase) }
                    )
                }

                HStack(spacing: KrupaSpacing.sm) {
                    if !phrase.translationUk.isEmpty {
                        SecondaryActionButton(
                            title: showsTranslation ? "Сховати переклад" : "Показати переклад",
                            systemImage: "character.book.closed",
                            tint: .krupaTextSecondary,
                            action: { showsTranslation.toggle() }
                        )
                    }
                    SecondaryActionButton(
                        title: "Пропустити",
                        systemImage: "forward.fill",
                        tint: .krupaTextSecondary,
                        action: { nextPhrase() }
                    )
                }
            }
        }
    }

    // MARK: Запис голосу

    @ViewBuilder
    private func recordCard(phrase: SpeakingPhrase) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: "Запис", subtitle: recordingSubtitle, systemImage: "mic.fill")

                if !app.recognition.isAvailable {
                    ErrorBanner(
                        message: "У системі немає розпізнавання мовлення, тому оцінка вимови недоступна. Слухайте зразок і оцініть себе самі.",
                        retryTitle: nil,
                        onRetry: nil
                    )
                    Text("Перевірте дозволи: Налаштування → KRUPA Spanish → «Мікрофон» і «Розпізнавання мовлення».")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if case .failed(let message) = app.recognition.state {
                    ErrorBanner(message: message, retryTitle: nil, onRetry: nil)
                }

                if app.recognition.isRecording {
                    KrupaProgressBar(value: app.recognition.audioLevel, tint: .krupaError, height: 10, showsLabel: false)
                    Text("Слухаю… говоріть")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    PrimaryActionButton(
                        title: "Зупинити",
                        systemImage: "stop.fill",
                        isEnabled: true,
                        action: { stopRecording(phrase: phrase) }
                    )
                } else {
                    Text("Натисніть і говоріть")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    PrimaryActionButton(
                        title: "Записати",
                        systemImage: "mic.fill",
                        isEnabled: app.recognition.isAvailable,
                        action: { startRecording() }
                    )
                }
            }
        }
    }

    // MARK: Результат

    private func resultCard(result: PronunciationResult) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .center, spacing: KrupaSpacing.md) {
                    ScoreRing(score: result.score)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.summaryUk)
                            .font(.krupaHeadline)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Звучання: \(result.heardText.isEmpty ? "—" : result.heardText)")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Слова: \(result.expectedText)")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if result.issues.isEmpty {
                    ExplanationBox(
                        title: "Рекомендації",
                        text: "Усі слова розпізнано правильно — тримайте такий темп.",
                        tint: .krupaSuccess,
                        systemImage: "checkmark.seal"
                    )
                } else {
                    KrupaSectionHeader(title: "Що виправити", subtitle: "Рекомендації", systemImage: "wrench.and.screwdriver")
                    ForEach(Array(result.issues.enumerated()), id: \.offset) { entry in
                        IssueRow(issue: entry.element)
                    }
                }

                HStack(spacing: KrupaSpacing.sm) {
                    SecondaryActionButton(
                        title: "Ще раз",
                        systemImage: "arrow.counterclockwise",
                        tint: .krupaBrand,
                        action: { retryRecording() }
                    )
                    PrimaryActionButton(
                        title: "Наступна фраза",
                        systemImage: "arrow.right",
                        isEnabled: true,
                        action: { nextPhrase() }
                    )
                }
            }
        }
    }

    // MARK: Порожній стан і статистика

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "mic.slash",
            title: "Немає завдань для говоріння",
            message: "Спершу пройдіть кілька занять — ми підберемо слова й речення, які ви вже вчите.",
            actionTitle: nil,
            action: nil
        )
    }

    private var sessionStats: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            HStack(spacing: KrupaSpacing.sm) {
                StatTile(
                    title: "Опрацьовано фраз",
                    value: "\(attemptCount)",
                    systemImage: "text.bubble.fill",
                    tint: .krupaSuccess
                )
                StatTile(
                    title: "Середня оцінка",
                    value: "\(averageScore)",
                    systemImage: "chart.bar.fill",
                    tint: .krupaBrand
                )
            }
            ChipView(text: "Спроб: \(attemptCount)", systemImage: "mic.fill", tint: .krupaTextSecondary)
        }
    }

    // MARK: - Дії

    private func speakSample(phrase: SpeakingPhrase) {
        app.speech.speak(phrase.spanish)
    }

    private func speakSlow(phrase: SpeakingPhrase) {
        app.speech.stop()
        app.speech.speak(phrase.spanish, rateOverride: 0.35)
    }

    private func startRecording() {
        errorMessage = nil
        result = nil
        Task {
            let granted = await app.recognition.requestAuthorization()
            guard granted else {
                errorMessage = "Без дозволу на мікрофон оцінка вимови недоступна."
                return
            }
            app.speech.stop()
            do {
                try app.recognition.start()
            } catch {
                errorMessage = "Не вдалося почати запис: \(error.localizedDescription)"
                app.recognition.reset()
            }
        }
    }

    private func stopRecording(phrase: SpeakingPhrase) {
        let heard = app.recognition.finishRecording()
        let scored = PronunciationScorer.score(expected: phrase.spanish, heard: heard)
        result = scored
        attemptCount += 1
        scoreSum += scored.score
        app.markSpeakingAttempt()
    }

    private func retryRecording() {
        result = nil
        errorMessage = nil
        startRecording()
    }

    private func nextPhrase() {
        result = nil
        errorMessage = nil
        showsTranslation = false
        app.recognition.reset()
        let count = phrases.count
        if count > 0 {
            currentIndex = (currentIndex + 1) % count
        }
    }

    private func resetSession() {
        currentIndex = 0
        result = nil
        errorMessage = nil
        showsTranslation = false
        app.recognition.reset()
    }

    private func stopEverything() {
        app.speech.stop()
        if app.recognition.isRecording {
            app.recognition.stop()
        }
    }
}

// MARK: - Допоміжні типи

/// Фраза для тренування (відповідник android `SpeakingPrompt`).
private struct SpeakingPhrase: Identifiable {
    let id: String
    let spanish: String
    let translationUk: String
    let hintUk: String
}

/// Кільце з оцінкою вимови.
private struct ScoreRing: View {
    var score: Int

    private var fraction: Double {
        min(1, max(0, Double(score) / 100))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.krupaSurfaceAlt, lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(scoreTint(score), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.krupaTitle)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text("з 100")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
        }
        .frame(width: 96, height: 96)
        .accessibilityLabel("Оцінка \(score) з 100")
    }
}

/// Одна знайдена проблема вимови з порадою.
private struct IssueRow: View {
    var issue: PronunciationIssue

    private var comparison: String {
        let heard = issue.heard.isEmpty ? "—" : issue.heard
        let expected = issue.expected.isEmpty ? "—" : issue.expected
        return "\(expected) → \(heard)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.krupaWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.type.titleUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text(issue.type.adviceUk)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(comparison)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(KrupaSpacing.xs)
        .background(Color.krupaWarning.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }
}

/// Колір оцінки: зелений — добре, жовтий — прийнятно, червоний — варто повторити.
private func scoreTint(_ score: Int) -> Color {
    if score >= 75 { return .krupaSuccess }
    if score >= 55 { return .krupaWarning }
    return .krupaError
}
