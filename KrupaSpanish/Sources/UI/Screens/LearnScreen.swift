import SwiftUI

/// Екран курсу: вибір рівня, заняття на сьогодні, теми рівня та граматика.
struct LearnScreen: View {
    @EnvironmentObject private var app: AppState

    /// Обраний вручну рівень (nil — використовуємо рівень із профілю).
    @State private var selectedLevel: Level?

    private var level: Level { selectedLevel ?? app.progress.profile.level }

    private var topicItems: [LearnTopicItem] {
        app.topicsWithProgress(level: level).map { item in
            LearnTopicItem(
                id: item.topic.id,
                topic: item.topic,
                fraction: item.fraction,
                wordsCount: item.wordsCount
            )
        }
    }

    private var grammarCount: Int {
        app.content.grammarNotes(level: level).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                header
                levelSelector
                sessionLink
                topicsSection
                grammarSection
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
    }

    // MARK: - Заголовок

    private var header: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Навчання",
                    subtitle: "Ваш рівень: \(app.progress.profile.level.title) · \(app.progress.profile.level.subtitleUk)",
                    systemImage: "book.fill"
                )
                Text("Курс побудований за рівнями CEFR. Кожна тема — це набір слів, граматика й вправи, які разом ведуть до наступного рівня.")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Вибір рівня

    private var levelSelector: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Рівень",
                subtitle: "Рівень можна змінити вручну в будь-який момент у Налаштуваннях.",
                systemImage: "chart.bar"
            )
            LearnLevelSelector(selected: level) { newLevel in
                selectedLevel = newLevel
            }
        }
    }

    // MARK: - Заняття на сьогодні

    private var sessionLink: some View {
        NavigationLink(value: AppRoute.session(topicId: nil)) {
            LearnActionLabel(
                title: "Заняття на сьогодні",
                subtitle: "Повторення, нові слова, граматика, аудіювання й говоріння",
                systemImage: "play.fill",
                isPrimary: true
            )
        }
        .buttonStyle(.plain)
        .krupaButtonShadow()
    }

    // MARK: - Теми рівня

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Теми рівня \(level.title)",
                subtitle: topicsSubtitle,
                systemImage: "list.bullet.rectangle"
            )

            if topicItems.isEmpty {
                EmptyStateView(
                    systemImage: "books.vertical",
                    title: "Тем немає",
                    message: emptyMessage,
                    actionTitle: nextLevelActionTitle,
                    action: nextLevelAction
                )
            } else {
                ForEach(topicItems) { item in
                    LearnTopicLink(
                        topic: item.topic,
                        fraction: item.fraction,
                        wordsCount: item.wordsCount
                    )
                }
            }
        }
    }

    private var topicsSubtitle: String {
        let count = topicItems.count
        if count == 0 { return "Тем поки немає" }
        return "\(count) тем."
    }

    private var emptyMessage: String {
        if let next = level.next {
            return "Теми цього рівня відкриються, коли ви перейдете на \(next.title). Рівень можна змінити вручну в Налаштуваннях."
        }
        return "Тем цього рівня поки немає. Спробуйте інший рівень — перемикач вище."
    }

    private var nextLevelActionTitle: String? {
        guard let next = level.next else { return nil }
        return "Показати рівень \(next.title)"
    }

    private var nextLevelAction: (() -> Void)? {
        guard let next = level.next else { return nil }
        return { selectedLevel = next }
    }

    // MARK: - Граматика

    private var grammarSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Граматика українською",
                subtitle: "Пояснення не «вивчи правило», а «чому іспанці кажуть саме так». Доступно \(grammarCount) тем.",
                systemImage: "text.book.closed.fill"
            )
            NavigationLink(value: AppRoute.grammarList) {
                LearnActionLabel(
                    title: "Відкрити граматику",
                    subtitle: "Правила з прикладами та частими помилками",
                    systemImage: "text.book.closed.fill",
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Допоміжні типи

/// Тема з прогресом для списку курсу.
private struct LearnTopicItem: Identifiable {
    let id: String
    let topic: Topic
    let fraction: Double
    let wordsCount: Int
}

/// Картка теми з переходом на її екран.
///
/// `TopicCardView` уже містить власну кнопку, тому посилання навігації
/// накладаємо зверху — так дотик завжди потрапляє в `NavigationLink`.
private struct LearnTopicLink: View {
    var topic: Topic
    var fraction: Double
    var wordsCount: Int

    var body: some View {
        TopicCardView(topic: topic, fraction: fraction, wordsCount: wordsCount) { }
            .overlay(
                NavigationLink(value: AppRoute.topicDetail(topic.id)) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            )
    }
}

/// Ряд кнопок вибору рівня (A0 / A1 / A2).
private struct LearnLevelSelector: View {
    var selected: Level
    var onSelect: (Level) -> Void

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            ForEach(Level.allCases) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 2) {
                        Text(item.title)
                            .font(.krupaCallout)
                        Text(item.subtitleUk)
                            .font(.krupaSmall)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KrupaSpacing.xs)
                    .foregroundStyle(selected == item ? Color.white : Color.krupaTextPrimary)
                    .background(selected == item ? Color.forLevel(item) : Color.krupaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Підпис кнопки-посилання на екрані курсу.
private struct LearnActionLabel: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var isPrimary: Bool

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
        .foregroundStyle(isPrimary ? Color.white : Color.krupaBrand)
        .background(isPrimary ? Color.krupaBrand : Color.krupaBrand.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
    }
}
