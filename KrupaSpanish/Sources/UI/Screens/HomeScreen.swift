import SwiftUI

/// Головний екран: привітання, ціль на день, вхід у заняття, швидкі дії,
/// продовження теми та слабкі місця.
struct HomeScreen: View {
    @EnvironmentObject private var app: AppState

    /// Чи розгорнуто блок зауважень до контенту.
    @State private var showsContentIssues = false

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private let quickActionColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                header
                todayCard
                sessionButtons
                quickActionsSection
                topicsSection
                weakSpotsSection
                contentIssuesSection
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
    }

    // MARK: - Дані екрана

    private var profile: UserProfile { app.progress.profile }
    private var todayStat: DailyStat { app.progress.todayStat }

    /// Скільки карток чекає на повторення.
    private var dueCount: Int { app.progress.dueCards().count }

    /// Скільки хвилин уже займалися сьогодні.
    private var minutesToday: Int {
        max(0, Int(app.progress.snapshot().minutesToday.rounded()))
    }

    private var goalFraction: Double {
        let goal = max(1, profile.dailyCardGoal)
        return min(1, Double(todayStat.reviews) / Double(goal))
    }

    private var topicItems: [HomeTopicItem] {
        app.topicsWithProgress().prefix(3).map { item in
            HomeTopicItem(
                id: item.topic.id,
                topic: item.topic,
                fraction: item.fraction,
                wordsCount: item.wordsCount
            )
        }
    }

    private var weakSpots: [WeakSpot] { app.progress.weakSpots(limit: 5) }

    private var greeting: String {
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Вітаю!" : "Вітаю, \(name)!"
    }

    private var dateText: String {
        "Сьогодні · \(HomeScreen.dayFormatter.string(from: Date()))"
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            HStack(alignment: .top, spacing: KrupaSpacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.krupaTitle)
                        .foregroundStyle(Color.white)
                    Text("Іспанська Іспанії · рівень \(profile.level.title)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                Spacer(minLength: 0)
                LevelBadge(level: profile.level)
            }

            HStack(spacing: KrupaSpacing.xs) {
                StreakBadge(days: app.progress.streakDays)
                Spacer(minLength: 0)
                Text(dateText)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.white.opacity(0.92))
            }
        }
        .padding(KrupaSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaHeaderGradient)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }

    // MARK: - Картка «Сьогодні»

    private var todayCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Сьогодні",
                    subtitle: "Ціль на день: \(todayStat.reviews) з \(max(1, profile.dailyCardGoal)) карток",
                    systemImage: "sun.max.fill"
                )

                KrupaProgressBar(value: goalFraction, showsLabel: true)

                HStack(alignment: .top, spacing: KrupaSpacing.sm) {
                    HomeMiniStat(
                        title: "Повторень сьогодні",
                        value: "\(todayStat.reviews)",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .krupaBrand
                    )
                    HomeMiniStat(
                        title: "Чекає карток",
                        value: "\(dueCount)",
                        systemImage: "tray.full",
                        tint: .krupaWarning
                    )
                    HomeMiniStat(
                        title: "Хвилин сьогодні",
                        value: "\(minutesToday)",
                        systemImage: "clock",
                        tint: .krupaSuccess
                    )
                }

                Text("Орієнтовний час: \(minutesToday) хв · мета: \(profile.dailyMinutes) хв на день")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Кнопки заняття

    private var sessionButtons: some View {
        VStack(spacing: KrupaSpacing.xs) {
            NavigationLink(value: AppRoute.session(topicId: nil)) {
                HomeActionLabel(
                    title: "Почати заняття",
                    subtitle: "Повторення, нові слова, граматика й аудіювання",
                    systemImage: "play.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
            .krupaButtonShadow()

            if dueCount > 0 {
                NavigationLink(value: AppRoute.review) {
                    HomeActionLabel(
                        title: "Повторити (\(dueCount))",
                        subtitle: "Чекає карток: \(dueCount)",
                        systemImage: "arrow.triangle.2.circlepath",
                        isPrimary: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Швидкі дії

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(title: "Тренування", systemImage: "bolt.fill")
            LazyVGrid(columns: quickActionColumns, spacing: KrupaSpacing.xs) {
                ForEach(QuickAction.allCases) { action in
                    NavigationLink(value: action.route) {
                        HomeQuickActionTile(action: action)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Продовжити тему

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Продовжити тему",
                subtitle: "Рівень \(profile.level.title) · \(profile.level.subtitleUk)",
                systemImage: "book.fill"
            )

            if topicItems.isEmpty {
                KrupaCard {
                    Text("Тем цього рівня поки немає — почніть заняття на сьогодні, і теми зʼявляться автоматично.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(topicItems) { item in
                    HomeTopicLink(
                        topic: item.topic,
                        fraction: item.fraction,
                        wordsCount: item.wordsCount
                    )
                }
            }
        }
    }

    // MARK: - Слабкі місця

    @ViewBuilder
    private var weakSpotsSection: some View {
        if !weakSpots.isEmpty {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    KrupaSectionHeader(
                        title: "Слабкі теми",
                        subtitle: "Застосунок автоматично додає більше вправ на ці теми у наступних заняттях.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    ForEach(weakSpots) { spot in
                        HStack(alignment: .center, spacing: KrupaSpacing.xs) {
                            Text("Слабке місце: \(weakSpotTitle(spot))")
                                .font(.krupaCaption)
                                .foregroundStyle(Color.krupaTextPrimary)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Text("\(errorPercent(spot))% помилок")
                                .font(.krupaSmall)
                                .foregroundStyle(Color.krupaError)
                        }
                    }
                }
            }
        }
    }

    /// Ключ слабкого місця може бути граматичним тегом або id слова.
    private func weakSpotTitle(_ spot: WeakSpot) -> String {
        if let note = app.content.grammarNote(tag: spot.key) {
            return note.titleUk
        }
        if let word = app.content.word(spot.key) {
            return word.spanishWithArticle
        }
        return spot.titleUk
    }

    private func errorPercent(_ spot: WeakSpot) -> Int {
        min(100, max(0, Int((spot.errorRate * 100).rounded())))
    }

    // MARK: - Зауваження до контенту

    @ViewBuilder
    private var contentIssuesSection: some View {
        if !app.contentIssues.isEmpty {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsContentIssues.toggle()
                    }
                } label: {
                    HStack(spacing: KrupaSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.krupaWarning)
                        Text("Зауваження до контенту: \(app.contentIssues.count)")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                        Spacer(minLength: 0)
                        Image(systemName: showsContentIssues ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    .padding(KrupaSpacing.sm)
                    .background(Color.krupaSurfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                if showsContentIssues {
                    ErrorBanner(message: app.contentIssues.joined(separator: "\n"))
                    Text("Навчання працює — частина матеріалів може бути неповною.")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Допоміжні типи

/// Тема з прогресом для списку на головному екрані.
private struct HomeTopicItem: Identifiable {
    let id: String
    let topic: Topic
    let fraction: Double
    let wordsCount: Int
}

/// Картка теми з переходом на її екран.
///
/// `TopicCardView` уже містить власну кнопку, тому посилання навігації
/// накладаємо зверху — так дотик завжди потрапляє в `NavigationLink`.
private struct HomeTopicLink: View {
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

/// Плитка невеликої статистики всередині картки «Сьогодні».
private struct HomeMiniStat: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = .krupaBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.krupaHeadline)
                .foregroundStyle(Color.krupaTextPrimary)
            Text(title)
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Підпис великої кнопки-посилання (заняття та повторення).
private struct HomeActionLabel: View {
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

/// Плитка швидкої дії у сітці 2×2.
private struct HomeQuickActionTile: View {
    var action: QuickAction

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            Image(systemName: action.systemImageName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(action.tint)
                .frame(width: 38, height: 38)
                .background(action.tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
            Text(action.titleUk)
                .font(.krupaCallout)
                .foregroundStyle(Color.krupaTextPrimary)
            Text(action.subtitleUk)
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KrupaSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(Color.krupaSurface)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }
}
