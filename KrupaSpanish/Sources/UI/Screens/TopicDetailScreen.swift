import SwiftUI

/// Деталі теми: опис, вхід у заняття, слова, граматика та аудіювання.
struct TopicDetailScreen: View {
    let topicId: String

    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// Чи показувати всі слова теми (інакше — перші кілька).
    @State private var showsAllWords = false
    /// Орієнтовна тривалість заняття з теми (рахуємо один раз).
    @State private var suggestedMinutes: Int = 0

    /// Скільки слів показуємо без розгортання.
    private let wordsLimit = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                if let topic = topic {
                    topicHeader(topic)
                    startButton(topic)
                    wordsSection
                    grammarSection
                    listeningSection
                } else {
                    EmptyStateView(
                        systemImage: "questionmark.folder",
                        title: "Тему не знайдено",
                        message: "Можливо, тему прибрали з контенту курсу. Поверніться до списку тем і виберіть іншу.",
                        actionTitle: "Назад",
                        action: { dismiss() }
                    )
                }
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.vertical, KrupaSpacing.md)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(topic?.titleUk ?? "Тема")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: prepareMinutesIfNeeded)
    }

    // MARK: - Дані теми

    private var topic: Topic? { app.content.topic(topicId) }

    private var words: [Word] { app.content.words(topicId: topicId) }

    private var visibleWords: [Word] {
        showsAllWords ? words : Array(words.prefix(wordsLimit))
    }

    private var sentences: [Sentence] {
        app.content.sentences(level: topic?.level ?? app.progress.profile.level, topicId: topicId)
    }

    private var exerciseCount: Int {
        guard let topic = topic else { return 0 }
        return app.content.exercises(level: topic.level, topicId: topic.id).count
    }

    private var grammarNotes: [GrammarNote] {
        guard let topic = topic else { return [] }
        return app.content.grammarNotes(tags: topic.grammarTags)
    }

    private var listeningItems: [ListeningItem] {
        guard let topic = topic else { return [] }
        return app.content.listening(level: topic.level, topicId: topic.id)
    }

    private var startTitle: String {
        suggestedMinutes > 0 ? "Почати заняття з теми (\(suggestedMinutes) хв)" : "Почати заняття з теми"
    }

    private func prepareMinutesIfNeeded() {
        guard suggestedMinutes == 0, app.content.topic(topicId) != nil else { return }
        suggestedMinutes = app.makePlan(topicId: topicId).estimatedMinutes
    }

    private func isLearned(_ word: Word) -> Bool {
        guard let card = app.progress.card(for: word.id) else { return false }
        return SrsEngine.isLearned(card)
    }

    // MARK: - Заголовок теми

    private func topicHeader(_ topic: Topic) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .top, spacing: KrupaSpacing.sm) {
                    Image(systemName: topic.systemImageName)
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.krupaBrand)
                        .frame(width: 46, height: 46)
                        .background(Color.krupaBrand.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: KrupaSpacing.xs) {
                            Text(topic.titleUk)
                                .font(.krupaTitle)
                                .foregroundStyle(Color.krupaTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            LevelBadge(level: topic.level)
                        }
                        Text(topic.titleEs)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }

                    Spacer(minLength: 0)
                }

                Text(topic.descriptionUk)
                    .font(.krupaBody)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(Color.krupaDivider)

                Text("У цій темі")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                Text("\(words.count) слів · \(sentences.count) речень · \(exerciseCount) вправ")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)

                if !topic.grammarTags.isEmpty {
                    Text("Граматика: \(grammarTitles)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var grammarTitles: String {
        let titles = grammarNotes.map(\.titleUk)
        return titles.isEmpty ? "—" : titles.joined(separator: ", ")
    }

    // MARK: - Заняття з теми

    private func startButton(_ topic: Topic) -> some View {
        NavigationLink(value: AppRoute.session(topicId: topic.id)) {
            TopicActionLabel(
                title: startTitle,
                subtitle: "Повторення, нові слова, граматика, аудіювання й говоріння",
                systemImage: "play.fill"
            )
        }
        .buttonStyle(.plain)
        .krupaButtonShadow()
    }

    // MARK: - Слова теми

    private var wordsSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Слова теми (\(words.count))",
                subtitle: "Натисніть слово, щоб побачити приклад, вимову та нотатки",
                systemImage: "character.book.closed.fill"
            )

            if words.isEmpty {
                TopicEmptyNote(text: "Слів у цій темі поки немає.")
            } else {
                KrupaCard(padding: KrupaSpacing.xs) {
                    VStack(spacing: 0) {
                        ForEach(visibleWords) { word in
                            NavigationLink(value: AppRoute.wordDetail(word.id)) {
                                WordRowView(
                                    word: word,
                                    showsTranslation: true,
                                    isLearned: isLearned(word)
                                )
                            }
                            .buttonStyle(.plain)

                            if word.id != visibleWords.last?.id {
                                Divider()
                                    .background(Color.krupaDivider)
                            }
                        }
                    }
                }

                if words.count > wordsLimit {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsAllWords.toggle()
                        }
                    } label: {
                        Text(showsAllWords ? "Згорнути" : "Показати всі (\(words.count))")
                            .font(.krupaCallout)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color.krupaBrand)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Граматика теми

    private var grammarSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Граматика теми",
                subtitle: "Пояснення українською з прикладами",
                systemImage: "text.book.closed.fill"
            )

            if grammarNotes.isEmpty {
                TopicEmptyNote(text: "Для цієї теми поки немає граматичних пояснень.")
            } else {
                ForEach(grammarNotes) { note in
                    NavigationLink(value: AppRoute.grammarDetail(note.id)) {
                        TopicGrammarRow(note: note)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Аудіювання

    private var listeningSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Аудіювання",
                subtitle: "Розуміння на слух за рівнями",
                systemImage: "headphones"
            )

            if listeningItems.isEmpty {
                TopicEmptyNote(text: "Для цієї теми поки немає окремого аудіоматеріалу — слухання буде з речень теми.")
            } else {
                ForEach(listeningItems) { item in
                    NavigationLink(value: AppRoute.listeningDetail(item.id)) {
                        TopicListeningRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Допоміжні типи

/// Підпис головної кнопки теми.
private struct TopicActionLabel: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: KrupaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.krupaCallout)
                Text(subtitle)
                    .font(.krupaSmall)
                    .opacity(0.9)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.8)
        }
        .padding(.horizontal, KrupaSpacing.md)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.white)
        .background(Color.krupaBrand)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
    }
}

/// Рядок граматичного правила теми.
private struct TopicGrammarRow: View {
    var note: GrammarNote

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.sm) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.krupaBrand)
                .frame(width: 36, height: 36)
                .background(Color.krupaBrand.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(note.titleUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note.titleEs)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                if !note.patternUk.isEmpty {
                    Text("Закономірність: \(note.patternUk)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.krupaTextSecondary)
        }
        .padding(KrupaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaSurface)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }
}

/// Рядок аудіоматеріалу теми.
private struct TopicListeningRow: View {
    var item: ListeningItem

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.sm) {
            Image(systemName: "headphones")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.krupaSuccess)
                .frame(width: 36, height: 36)
                .background(Color.krupaSuccess.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.titleUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.titleEs)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                HStack(spacing: KrupaSpacing.xxs) {
                    ChipView(text: item.kind.titleUk, systemImage: nil, tint: .krupaSuccess)
                    ChipView(text: "\(item.lines.count) реплік", systemImage: nil, tint: .krupaTextSecondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.krupaTextSecondary)
        }
        .padding(KrupaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaSurface)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }
}

/// Коротке пояснення для порожньої секції.
private struct TopicEmptyNote: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.krupaCaption)
            .foregroundStyle(Color.krupaTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(KrupaSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.krupaSurfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }
}
