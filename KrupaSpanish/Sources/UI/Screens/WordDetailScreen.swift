import Foundation
import SwiftUI

// MARK: - Екран слова

/// Картка слова: переклад, вимова, приклад, нотатки, граматичні теги
/// та стан пам'яті з керуванням повтореннями.
struct WordDetailScreen: View {
    let wordId: String

    @EnvironmentObject private var app: AppState

    private var word: Word? { app.content.word(wordId) }

    var body: some View {
        Group {
            if let word {
                content(for: word)
            } else {
                EmptyStateView(
                    systemImage: "questionmark.circle",
                    title: "Слово не знайдено",
                    message: "Це слово ще не зустрічалося в заняттях — воно з'явиться у наступних уроках."
                )
            }
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(word?.spanish ?? "Слово")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for word: Word) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                WordDetailHeadCard(word: word)
                WordDetailPronunciationCard(word: word)
                WordDetailInfoCard(word: word, topicTitle: app.content.topic(word.topicId)?.titleUk)

                if !word.exampleEs.isEmpty || !word.exampleUk.isEmpty {
                    WordDetailExampleCard(word: word)
                }
                if word.hasNotes {
                    WordDetailNotesCard(word: word)
                }
                if !word.grammarTags.isEmpty {
                    WordDetailGrammarTagsCard(tags: word.grammarTags)
                }

                WordDetailProgressCard(word: word, card: app.progress.card(for: word.id))
            }
            .padding(KrupaSpacing.screenPadding)
        }
    }
}

// MARK: - Основна картка

/// Велике іспанське слово, озвучення, артикль/рід, частина мови, переклад і множина.
private struct WordDetailHeadCard: View {
    let word: Word

    @EnvironmentObject private var app: AppState

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .center, spacing: KrupaSpacing.xs) {
                    Text(word.spanish)
                        .font(.krupaSpanishWord)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)

                    SpeakerButton(
                        isSpeaking: app.speech.isSpeakingText(word.spanish),
                        size: 22
                    ) {
                        app.speak(word.spanish, force: true)
                    }

                    Spacer(minLength: 0)
                    LevelBadge(level: word.level)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KrupaSpacing.xs) {
                        if word.withArticle {
                            ChipView(text: word.spanishWithArticle, systemImage: "textformat")
                        } else if !word.gender.marker.isEmpty {
                            ChipView(text: word.gender.marker, systemImage: "textformat")
                        }
                        ChipView(text: word.partOfSpeech.titleUk, tint: .krupaBrandDark)
                    }
                    .padding(.vertical, 2)
                }

                Text(word.translationUk)
                    .font(.krupaHeadline)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xxs) {
                    Text("Множина")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    Text(word.plural.isEmpty ? "не вживається" : word.plural)
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextPrimary)
                }
            }
        }
    }
}

// MARK: - Вимова

/// Підказки вимови (українськими літерами та IPA) і перехід до тренування.
private struct WordDetailPronunciationCard: View {
    let word: Word

    @EnvironmentObject private var app: AppState

    /// Підказки вимови з налаштувань (`settings` живе в `ProgressStore`).
    private var showsPronunciation: Bool {
        app.progress.settings.showPronunciationHints && !word.pronunciation.isEmpty
    }

    private var showsIpa: Bool {
        app.progress.settings.showIpa && !word.ipaHint.isEmpty
    }

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                if showsPronunciation {
                    HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xxs) {
                        Text("Вимова: ")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                        Text(word.pronunciation)
                            .font(.krupaHeadline)
                            .foregroundStyle(Color.krupaTextPrimary)
                    }
                }

                if showsIpa {
                    HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xxs) {
                        Text("IPA: ")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                        Text(word.ipaHint)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextPrimary)
                    }
                }

                if !showsPronunciation && !showsIpa {
                    Text("Підказки вимови вимкнено в налаштуваннях.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }

                NavigationLink(value: AppRoute.speaking) {
                    WordDetailNavLabel(title: "Тренувати вимову", systemImage: "mic.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Візуальна копія `SecondaryActionButton` без вкладеної кнопки —
/// щоб підпис можна було використати всередині `NavigationLink`.
private struct WordDetailNavLabel: View {
    let title: String
    let systemImage: String
    var tint: Color = .krupaBrand

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            Image(systemName: systemImage)
            Text(title)
                .font(.krupaCallout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .foregroundStyle(tint)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
    }
}

// MARK: - Довідкова інформація

/// Частина мови, рід, тема, рівень і частотність слова.
private struct WordDetailInfoCard: View {
    let word: Word
    let topicTitle: String?

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Про слово", systemImage: "info.circle")

                WordDetailInfoRow(title: "Частина мови", value: word.partOfSpeech.titleUk)
                if !word.gender.marker.isEmpty {
                    WordDetailInfoRow(title: "Рід", value: word.gender.marker)
                }
                if let topicTitle, !topicTitle.isEmpty {
                    WordDetailInfoRow(title: "Тема", value: topicTitle)
                }
                WordDetailInfoRow(title: "Рівень", value: word.level.title)
                WordDetailInfoRow(title: "Частотність", value: "№\(word.frequencyRank) у курсі")
            }
        }
    }
}

/// Рядок «підпис — значення» для довідкових карток.
private struct WordDetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.xs) {
            Text(title)
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.krupaCallout)
                .foregroundStyle(Color.krupaTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Приклад

/// Речення-приклад із озвученням і перекладом.
private struct WordDetailExampleCard: View {
    let word: Word

    @EnvironmentObject private var app: AppState

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Приклад", systemImage: "text.quote")

                if !word.exampleEs.isEmpty {
                    Text(word.exampleEs)
                        .font(.krupaSpanishExample)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !word.exampleUk.isEmpty {
                    Text(word.exampleUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !word.exampleEs.isEmpty {
                    HStack(spacing: KrupaSpacing.xs) {
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(word.exampleEs)) {
                            app.speak(word.exampleEs, force: true)
                        }
                        Button {
                            app.speak(word.exampleEs, force: true)
                        } label: {
                            Text("Прослухати приклад")
                                .font(.krupaCaption)
                                .foregroundStyle(Color.krupaBrand)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Нотатки

/// Нотатки до слова: звичайна та про схожість з українською (когнати).
private struct WordDetailNotesCard: View {
    let word: Word

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                if !word.notesUk.isEmpty {
                    ExplanationBox(
                        title: "Нотатка",
                        text: word.notesUk,
                        tint: .krupaBrand,
                        systemImage: "info.circle"
                    )
                }
                if !word.cognateNoteUk.isEmpty {
                    ExplanationBox(
                        title: "Схожі слова (когнати)",
                        text: word.cognateNoteUk,
                        tint: .krupaGold,
                        systemImage: "sparkles"
                    )
                }
            }
        }
    }
}

// MARK: - Граматичні теги

/// Теги слова; натиск на тег веде до відповідного правила.
private struct WordDetailGrammarTagsCard: View {
    let tags: [String]

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Граматика",
                    subtitle: "Натисніть тег, щоб відкрити правило.",
                    systemImage: "text.book.closed.fill"
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KrupaSpacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            WordDetailGrammarTagChip(tag: tag)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

/// Чип граматичного тегу: з переходом, якщо для тега є нотатка.
private struct WordDetailGrammarTagChip: View {
    let tag: String

    @EnvironmentObject private var app: AppState

    var body: some View {
        if let note = app.content.grammarNote(tag: tag) {
            NavigationLink(value: AppRoute.grammarDetail(note.id)) {
                ChipView(text: note.titleUk, systemImage: "book", tint: .krupaBrand)
            }
            .buttonStyle(.plain)
        } else {
            ChipView(text: tag, systemImage: "book", tint: .krupaTextSecondary)
        }
    }
}

// MARK: - Стан пам'яті

/// Прогрес картки: фаза, інтервал, точність, повторення та дії з карткою.
private struct WordDetailProgressCard: View {
    let word: Word
    let card: CardState?

    @EnvironmentObject private var app: AppState
    @State private var notice: String? = nil

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Стан пам'яті",
                    subtitle: phaseText,
                    systemImage: "brain.head.profile"
                )

                WordDetailInfoRow(title: "Інтервал", value: intervalText)
                WordDetailInfoRow(title: "Наступне повторення", value: nextReviewText)
                WordDetailInfoRow(title: "Точність", value: accuracyText)
                WordDetailInfoRow(title: "Повторень", value: "\(card?.totalReviews ?? 0)")

                KrupaProgressBar(value: accuracyFraction, tint: accuracyTint)

                if let card, card.suspended {
                    ChipView(text: "Призупинено", systemImage: "pause.fill", tint: .krupaWarning)
                }

                if let saveError = app.progress.lastSaveError {
                    ErrorBanner(message: saveError, retryTitle: nil, onRetry: nil)
                }

                if let notice {
                    Text(notice)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaSuccess)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SecondaryActionButton(
                    title: suspensionTitle,
                    systemImage: suspensionIcon,
                    tint: suspensionTint
                ) {
                    toggleSuspension()
                }

                PrimaryActionButton(
                    title: "Додати до повторення зараз",
                    systemImage: "clock.arrow.circlepath"
                ) {
                    addToReviewNow()
                }
            }
        }
    }

    // MARK: Обчислені підписи

    private var phaseText: String {
        card?.phase.titleUk ?? "Ще не вчилися"
    }

    private var intervalText: String {
        guard let card else { return "—" }
        return SrsEngine.intervalLabel(for: card)
    }

    private var accuracyFraction: Double {
        guard let card else { return 0 }
        return min(1, max(0, card.accuracy / 100))
    }

    private var accuracyText: String {
        guard let card, card.totalReviews > 0 else { return "—" }
        return "\(Int(card.accuracy.rounded())) %"
    }

    private var accuracyTint: Color {
        guard let card, card.totalReviews > 0 else { return .krupaTextSecondary }
        return card.accuracy >= 80 ? .krupaSuccess : .krupaWarning
    }

    private var nextReviewText: String {
        guard let card else { return "—" }
        if card.suspended { return "Призупинено" }
        if card.dueAt.timeIntervalSinceNow < 86_400 { return "менш ніж день" }
        return WordDetailFormatting.nextReviewFormatter.string(from: card.dueAt)
    }

    private var suspensionTitle: String {
        (card?.suspended ?? false) ? "Відновити" : "Призупинити"
    }

    private var suspensionIcon: String {
        (card?.suspended ?? false) ? "play.circle" : "pause.circle"
    }

    private var suspensionTint: Color {
        (card?.suspended ?? false) ? .krupaSuccess : .krupaWarning
    }

    // MARK: Дії

    /// Призупиняє або відновлює картку (за потреби створює її).
    private func toggleSuspension() {
        let existing = app.progress.cardOrCreate(
            itemId: word.id,
            itemType: .word,
            level: word.level,
            topicId: word.topicId,
            grammarTags: word.grammarTags
        )
        app.progress.setSuspended(!existing.suspended, itemId: word.id)
        notice = existing.suspended
            ? "Картку відновлено в повтореннях."
            : "Картку призупинено — вона не з'являтиметься в заняттях."
    }

    /// Ставить картку в чергу повторення на цю ж мить.
    private func addToReviewNow() {
        var updated = app.progress.cardOrCreate(
            itemId: word.id,
            itemType: .word,
            level: word.level,
            topicId: word.topicId,
            grammarTags: word.grammarTags
        )
        updated.dueAt = Date()
        updated.suspended = false
        app.progress.upsert(updated)
        notice = "Слово додано до повторення зараз."
    }
}

// MARK: - Форматування

/// Формат дати наступного повторення — як в android-версії (`d MMMM, HH:mm`).
private enum WordDetailFormatting {
    static let nextReviewFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM, HH:mm"
        return formatter
    }()
}
