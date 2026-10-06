import SwiftUI

// MARK: - Вкладка «Прогрес»

/// Екран «Прогрес»: ключові показники, статистика за сьогодні, активність
/// за останні 7 днів (власна стовпчикова діаграма без `Charts`), рівень і мета,
/// слабкі місця та теми з часткою вивчених слів.
struct ProgressScreen: View {
    @EnvironmentObject private var app: AppState

    /// Дві колонки для плиток статистики.
    private let tileColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    /// Три колонки для дрібних показників у картці «Сьогодні».
    private let miniColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.sm),
        GridItem(.flexible(), spacing: KrupaSpacing.sm),
        GridItem(.flexible(), spacing: KrupaSpacing.sm)
    ]

    /// Скільки днів показуємо на діаграмі активності.
    private let weekLength = 7

    /// Скорочені назви днів: індекс = `Calendar.component(.weekday) - 1` (1 — неділя).
    private static let weekdayShortNames = ["нд", "пн", "вт", "ср", "чт", "пт", "сб"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                summaryGrid
                todayCard
                weekCard
                levelCard
                weakSpotsSection
                topicsSection
                detailsLink
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.vertical, KrupaSpacing.md)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Прогрес")
    }

    // MARK: - Дані екрана

    private var profile: UserProfile { app.progress.profile }

    private var snapshot: ProgressSnapshot { app.progress.snapshot() }

    private var todayStat: DailyStat { app.progress.todayStat }

    /// Хвилини за сьогодні, округлені до цілого.
    private var minutesToday: Int { max(0, Int(todayStat.minutes.rounded())) }

    /// Дні для діаграми: від найстарішого до сьогодні.
    private var weekBars: [ProgressDayBar] {
        let calendar = Calendar.current
        let now = Date()
        let offsets = Array((0..<weekLength).reversed())
        return offsets.compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let stat = app.progress.dailyStat(for: date)
            return ProgressDayBar(
                id: DayKey.key(for: date),
                reviews: stat.reviews,
                label: weekdayLabel(for: date),
                isToday: calendar.isDateInToday(date)
            )
        }
    }

    /// Чи є хоч один день із повтореннями.
    private var weekHasData: Bool {
        weekBars.contains { $0.reviews > 0 }
    }

    private var weakSpots: [WeakSpot] { app.progress.weakSpots(limit: 8) }

    private var topicItems: [ProgressTopicItem] {
        app.topicsWithProgress().map { item in
            ProgressTopicItem(topic: item.topic, fraction: item.fraction, wordsCount: item.wordsCount)
        }
    }

    /// Підпис дня тижня українською («пн», «вт», …).
    private func weekdayLabel(for date: Date) -> String {
        let index = Calendar.current.component(.weekday, from: date) - 1
        guard index >= 0, index < ProgressScreen.weekdayShortNames.count else { return "" }
        return ProgressScreen.weekdayShortNames[index]
    }

    /// Відсоток без дробової частини: «78%».
    private func percentText(_ value: Double) -> String {
        "\(min(100, max(0, Int(value.rounded()))))%"
    }

    // MARK: - Плитки показників

    private var summaryGrid: some View {
        LazyVGrid(columns: tileColumns, spacing: KrupaSpacing.xs) {
            StatTile(
                title: "Серія днів",
                value: "\(app.progress.streakDays)",
                systemImage: "flame.fill",
                tint: .krupaGold
            )
            StatTile(
                title: "Точність",
                value: percentText(snapshot.accuracy),
                systemImage: "target",
                tint: .krupaSuccess
            )
            StatTile(
                title: "Слів засвоєно",
                value: "\(snapshot.wordsLearned)",
                systemImage: "character.book.closed.fill",
                tint: .krupaBrand
            )
            StatTile(
                title: "Хвилин усього",
                value: "\(Int(snapshot.totalMinutes))",
                systemImage: "clock.fill",
                tint: .krupaBrandDark
            )
        }
    }

    // MARK: - Картка «Сьогодні»

    private var todayCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Сьогодні",
                    subtitle: "Ціль на день: \(max(1, snapshot.dailyGoal)) карток",
                    systemImage: "sun.max.fill"
                )

                LazyVGrid(columns: miniColumns, spacing: KrupaSpacing.sm) {
                    ProgressMiniStat(
                        title: "Повторень",
                        value: "\(todayStat.reviews)",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .krupaBrand
                    )
                    ProgressMiniStat(
                        title: "Правильно",
                        value: "\(todayStat.correct)",
                        systemImage: "checkmark.circle.fill",
                        tint: .krupaSuccess
                    )
                    ProgressMiniStat(
                        title: "Нових слів",
                        value: "\(todayStat.newCards)",
                        systemImage: "sparkles",
                        tint: .krupaGold
                    )
                    ProgressMiniStat(
                        title: "Хвилин",
                        value: "\(minutesToday)",
                        systemImage: "clock",
                        tint: .krupaBrandDark
                    )
                    ProgressMiniStat(
                        title: "XP",
                        value: "\(todayStat.xp)",
                        systemImage: "bolt.fill",
                        tint: .krupaWarning
                    )
                }

                VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                    KrupaProgressBar(value: snapshot.goalCompletion)
                    Text("\(snapshot.reviewsToday) з \(max(1, snapshot.dailyGoal)) карток")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }
    }

    // MARK: - Картка «Останні 7 днів»

    private var weekCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Останні 7 днів",
                    subtitle: "Стовпчик = кількість повторень за день.",
                    systemImage: "chart.bar.fill"
                )

                if weekHasData {
                    ProgressWeekChart(bars: weekBars)
                } else {
                    NavigationLink(value: AppRoute.session(topicId: nil)) {
                        EmptyStateView(
                            systemImage: "chart.bar.xaxis",
                            title: "Даних ще немає",
                            message: "Статистика з'явиться після першого заняття. Найкорисніше — займатися щодня хоча б 10 хвилин.",
                            actionTitle: "Почати заняття",
                            action: { }
                        )
                        .allowsHitTesting(false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Картка «Рівень і мета»

    private var levelCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Рівень і мета",
                    subtitle: "Прогрес рівня рахується зі слів, які ви вже почали вчити, і граматичних тем, у яких маєте понад 60% правильних відповідей.",
                    systemImage: "graduationcap.fill"
                )

                HStack(spacing: KrupaSpacing.xs) {
                    LevelBadge(level: profile.level)
                    Text("Рівень \(profile.level.title) · \(profile.level.subtitleUk)")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Spacer(minLength: 0)
                }

                ProgressInfoRow(
                    systemImage: profile.goal.systemImageName,
                    title: "Мета: \(profile.goal.titleUk)",
                    subtitle: profile.goal.descriptionUk,
                    tint: .krupaBrand
                )

                ProgressInfoRow(
                    systemImage: "clock.fill",
                    title: "\(profile.dailyMinutes) хв на день",
                    subtitle: "Слів засвоєно: \(snapshot.wordsLearned) · у роботі: \(snapshot.wordsInProgress)",
                    tint: .krupaBrandDark
                )
            }
        }
    }

    // MARK: - Слабкі місця

    private var weakSpotsSection: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Слабкі місця",
                    subtitle: "Застосунок автоматично додає більше вправ на ці теми у наступних заняттях.",
                    systemImage: "exclamationmark.triangle.fill"
                )

                if weakSpots.isEmpty {
                    Text("Даних замало: дайте більше відповідей, і тут з'являться теми та слова, які варто підсилити.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(weakSpots, id: \.id) { spot in
                        weakSpotRow(spot)
                    }
                }
            }
        }
    }

    /// Рядок слабкого місця: веде в граматику, у слово або лишається текстом.
    @ViewBuilder
    private func weakSpotRow(_ spot: WeakSpot) -> some View {
        if let note = app.content.grammarNote(tag: spot.key) {
            NavigationLink(value: AppRoute.grammarDetail(note.id)) {
                ProgressWeakSpotRow(
                    title: note.titleUk,
                    subtitle: "Граматика",
                    spot: spot,
                    showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
        } else if let word = app.content.word(spot.key) {
            NavigationLink(value: AppRoute.wordDetail(word.id)) {
                ProgressWeakSpotRow(
                    title: word.spanishWithArticle,
                    subtitle: word.translationUk,
                    spot: spot,
                    showsDisclosure: true
                )
            }
            .buttonStyle(.plain)
        } else {
            ProgressWeakSpotRow(
                title: "Слабке місце: \(spot.titleUk)",
                subtitle: nil,
                spot: spot,
                showsDisclosure: false
            )
        }
    }

    // MARK: - Теми

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            KrupaSectionHeader(
                title: "Теми",
                subtitle: "Рівень \(profile.level.title) · \(profile.level.subtitleUk)",
                systemImage: "book.fill"
            )

            if topicItems.isEmpty {
                KrupaCard {
                    Text("Тем цього рівня поки немає — почніть заняття, і теми з'являться автоматично.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ForEach(topicItems, id: \.id) { item in
                    NavigationLink(value: AppRoute.topicDetail(item.topic.id)) {
                        TopicCardView(
                            topic: item.topic,
                            fraction: item.fraction,
                            wordsCount: item.wordsCount
                        ) { }
                        .allowsHitTesting(false)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Перехід до деталей

    private var detailsLink: some View {
        NavigationLink(value: AppRoute.progressDetails) {
            SecondaryActionButton(
                title: "Детальніше",
                systemImage: "chart.bar.doc.horizontal"
            ) { }
            .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Допоміжні типи екрана «Прогрес»

/// День тижня для діаграми активності.
private struct ProgressDayBar: Identifiable {
    var id: String
    var reviews: Int
    var label: String
    var isToday: Bool
}

/// Тема з прогресом для списку тем.
private struct ProgressTopicItem: Identifiable {
    var id: String { topic.id }
    var topic: Topic
    var fraction: Double
    var wordsCount: Int
}

/// Дрібний показник усередині картки «Сьогодні».
private struct ProgressMiniStat: View {
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

/// Рядок «іконка + заголовок + пояснення» у картці рівня.
private struct ProgressInfoRow: View {
    var systemImage: String
    var title: String
    var subtitle: String
    var tint: Color = .krupaBrand

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Власна стовпчикова діаграма активності — навмисно без `Charts`.
private struct ProgressWeekChart: View {
    var bars: [ProgressDayBar]

    /// Верхня межа шкали (нуль замінюємо на одиницю, щоб не ділити на нуль).
    private var maxReviews: Int { max(1, bars.map(\.reviews).max() ?? 0) }

    var body: some View {
        HStack(alignment: .bottom, spacing: KrupaSpacing.xxs) {
            ForEach(0..<7, id: \.self) { index in
                if index < bars.count {
                    ProgressWeekBarView(bar: bars[index], maxReviews: maxReviews)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                }
            }
        }
    }
}

/// Один стовпчик діаграми: висота, кількість повторень і підпис дня.
private struct ProgressWeekBarView: View {
    var bar: ProgressDayBar
    var maxReviews: Int

    /// Максимальна висота стовпчика в точках.
    private let maxBarHeight: CGFloat = 96

    private var barHeight: CGFloat {
        guard bar.reviews > 0 else { return 4 }
        let ratio = Double(bar.reviews) / Double(max(1, maxReviews))
        return max(8, maxBarHeight * ratio)
    }

    private var barTint: Color {
        bar.isToday ? .krupaBrand : Color.krupaBrand.opacity(0.45)
    }

    var body: some View {
        VStack(spacing: KrupaSpacing.xxs) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(barTint)
                .frame(height: barHeight)
            Text("\(bar.reviews)")
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextPrimary)
            Text(bar.label)
                .font(.krupaSmall)
                .foregroundStyle(bar.isToday ? Color.krupaBrand : Color.krupaTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
    }
}

/// Рядок слабкого місця з кількістю помилок і часткою.
private struct ProgressWeakSpotRow: View {
    var title: String
    var subtitle: String?
    var spot: WeakSpot
    var showsDisclosure: Bool

    private var percent: Int {
        min(100, max(0, Int((spot.errorRate * 100).rounded())))
    }

    var body: some View {
        HStack(alignment: .center, spacing: KrupaSpacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .lineLimit(2)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .lineLimit(1)
                }
                Text("помилок: \(spot.wrong) з \(spot.attempts)")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }

            Spacer(minLength: 0)

            Text("\(percent)% помилок")
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaError)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.krupaTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Детальна статистика

/// Екран детальної статистики: зведення за весь час, розподіл карток за
/// фазами й рівнями, «сила знань», останні відповіді та звіт для надсилання.
struct ProgressDetailsScreen: View {
    @EnvironmentObject private var app: AppState

    /// Дві колонки для показників зведення.
    private let metricColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                if cards.isEmpty {
                    KrupaCard {
                        emptyState
                    }
                } else {
                    summaryCard
                    phasesCard
                    levelsCard
                    knowledgeCard
                    reviewLogCard
                    shareSection
                }
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.vertical, KrupaSpacing.md)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Детальна статистика")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Дані екрана

    private var snapshot: ProgressSnapshot { app.progress.snapshot() }

    private var cards: [CardState] { Array(app.progress.cards.values) }

    private var totalCards: Int { cards.count }

    /// Картки, які вже хоч раз повторювали.
    private var reviewedCards: [CardState] { cards.filter { $0.totalReviews > 0 } }

    /// Останні 20 відповідей — від найновіших.
    private var recentAnswers: [ReviewLogEntry] {
        Array(app.progress.document.reviewLog.suffix(20).reversed())
    }

    /// Середня «міцність» карток (0…1).
    ///
    /// У контракті згадані `SrsEngine.strength(_:)` і `SrsEngine.retention(_:)`,
    /// але в наявному `SrsEngine` таких методів немає, а цей файл не редагує
    /// інші файли проєкту — тому показники рахуються локально з полів картки.
    private var averageStrength: Double {
        guard !cards.isEmpty else { return 0 }
        let total = cards.reduce(0.0) { $0 + strength(of: $1) }
        return min(1, max(0, total / Double(cards.count)))
    }

    /// Середня точність відповідей за картками, які вже повторювали (у відсотках).
    private var averageRetention: Double {
        guard !reviewedCards.isEmpty else { return 0 }
        let total = reviewedCards.reduce(0.0) { $0 + $1.accuracy }
        return min(100, max(0, total / Double(reviewedCards.count)))
    }

    /// Міцність однієї картки: інтервал повторення, легкість і штраф за зриви.
    private func strength(of card: CardState) -> Double {
        let intervalPart = min(1, max(0, card.intervalDays / SrsEngine.learnedIntervalDays))
        let easeRange = max(0.01, 3.2 - SrsEngine.minEase)
        let easePart = min(1, max(0, (card.ease - SrsEngine.minEase) / easeRange))
        let lapsePart = card.totalReviews > 0
            ? min(0.3, Double(card.lapses) / Double(card.totalReviews) * 0.3)
            : 0
        return min(1, max(0, intervalPart * 0.7 + easePart * 0.3 - lapsePart))
    }

    /// Відсоток без дробової частини.
    private func percentText(_ value: Double) -> String {
        "\(min(100, max(0, Int(value.rounded()))))%"
    }

    /// Час відповіді: сьогодні — «HH:mm», інакше — дата й час.
    private func timeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let time = ProgressDetailsScreen.timeFormatter.string(from: date)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInYesterday(date) { return "вчора, \(time)" }
        return "\(ProgressDetailsScreen.dayFormatter.string(from: date)), \(time)"
    }

    // MARK: - Зведення

    private var summaryCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Зведення",
                    subtitle: "За весь час навчання",
                    systemImage: "chart.bar.fill"
                )

                LazyVGrid(columns: metricColumns, spacing: KrupaSpacing.xs) {
                    ProgressMetricTile(
                        title: "Усього повторень",
                        value: "\(snapshot.totalReviews)",
                        systemImage: "arrow.triangle.2.circlepath",
                        tint: .krupaBrand
                    )
                    ProgressMetricTile(
                        title: "Найдовша серія",
                        value: "\(snapshot.longestStreak) дн",
                        systemImage: "flame.fill",
                        tint: .krupaGold
                    )
                    ProgressMetricTile(
                        title: "Точність",
                        value: percentText(snapshot.accuracy),
                        systemImage: "target",
                        tint: .krupaSuccess
                    )
                    ProgressMetricTile(
                        title: "Заплановано на завтра",
                        value: "\(snapshot.dueTomorrow) карток",
                        systemImage: "calendar",
                        tint: .krupaWarning
                    )
                    ProgressMetricTile(
                        title: "Хвилин усього",
                        value: "\(Int(snapshot.totalMinutes))",
                        systemImage: "clock.fill",
                        tint: .krupaBrandDark
                    )
                    ProgressMetricTile(
                        title: "XP",
                        value: "\(snapshot.totalXP)",
                        systemImage: "bolt.fill",
                        tint: .krupaBrand
                    )
                }

                Text("Карток у курсі: \(totalCards) · слів засвоєно: \(snapshot.wordsLearned) · у роботі: \(snapshot.wordsInProgress)")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Розподіл за фазами

    private var phasesCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Фази карток",
                    subtitle: "Скільки карток у кожній фазі повторення.",
                    systemImage: "square.stack.3d.up.fill"
                )

                ForEach(CardPhase.allCases, id: \.self) { phase in
                    ProgressPhaseRow(
                        phase: phase,
                        count: app.progress.cardsInPhase(phase).count,
                        total: totalCards
                    )
                }
            }
        }
    }

    // MARK: - Розподіл за рівнями

    private var levelsCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Розподіл за рівнями",
                    subtitle: "Картки рівнів A0, A1 і A2 у вашому профілі.",
                    systemImage: "chart.pie.fill"
                )

                ForEach(Level.allCases, id: \.rawValue) { level in
                    ProgressLevelRow(
                        level: level,
                        count: cards.filter { $0.levelCode == level.rawValue }.count,
                        total: totalCards
                    )
                }
            }
        }
    }

    // MARK: - Сила знань

    private var knowledgeCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Знання мови",
                    subtitle: "Міцність рахується з інтервалу повторення, легкості картки та кількості зривів.",
                    systemImage: "brain.head.profile"
                )

                if reviewedCards.isEmpty {
                    Text("Даних ще немає — дайте перші відповіді, і показники з'являться.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ProgressMeterRow(
                        title: "Середня міцність",
                        valueText: percentText(averageStrength * 100),
                        fraction: averageStrength,
                        tint: .krupaBrand
                    )
                    ProgressMeterRow(
                        title: "Середня точність",
                        valueText: percentText(averageRetention),
                        fraction: min(1, averageRetention / 100),
                        tint: .krupaSuccess
                    )
                    Text("Карток у повторенні: \(reviewedCards.count) з \(totalCards)")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }
    }

    // MARK: - Останні відповіді

    private var reviewLogCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Останні відповіді",
                    subtitle: "До 20 останніх карток із журналу повторень.",
                    systemImage: "list.bullet.rectangle"
                )

                if recentAnswers.isEmpty {
                    Text("Журнал порожній — відповіді з'являться після першого заняття.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    ForEach(recentAnswers, id: \.id) { entry in
                        ProgressReviewRow(entry: entry, timeText: timeLabel(for: entry.reviewedAt))
                        if entry.id != recentAnswers.last?.id {
                            Divider()
                                .background(Color.krupaDivider)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Звіт

    private var shareSection: some View {
        ShareLink(item: reportText) {
            HStack(spacing: KrupaSpacing.xs) {
                Image(systemName: "square.and.arrow.up")
                Text("Поділитися звітом")
                    .font(.krupaCallout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color.krupaBrand)
            .background(Color.krupaBrand.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    /// Текстовий звіт про прогрес для надсилання.
    private var reportText: String {
        let profile = app.progress.profile
        return """
        KRUPA Spanish — прогрес
        Рівень: \(profile.level.title) (\(profile.level.subtitleUk)) · мета: \(profile.goal.titleUk)
        Серія днів: \(app.progress.streakDays) · найдовша серія: \(snapshot.longestStreak) дн
        Усього повторень: \(snapshot.totalReviews)
        Точність: \(percentText(snapshot.accuracy))
        Слів засвоєно: \(snapshot.wordsLearned) · у роботі: \(snapshot.wordsInProgress)
        Карток у курсі: \(totalCards)
        Хвилин усього: \(Int(snapshot.totalMinutes))
        XP: \(snapshot.totalXP)
        Заплановано на завтра: \(snapshot.dueTomorrow) карток
        """
    }

    // MARK: - Порожній стан

    private var emptyState: some View {
        NavigationLink(value: AppRoute.session(topicId: nil)) {
            EmptyStateView(
                systemImage: "chart.bar.doc.horizontal",
                title: "Даних ще немає",
                message: "Статистика з'явиться після першого заняття. Найкорисніше — займатися щодня хоча б 10 хвилин.",
                actionTitle: "Пройти перше заняття",
                action: { }
            )
            .allowsHitTesting(false)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Допоміжні типи детальної статистики

/// Компактний показник зведення всередині картки.
private struct ProgressMetricTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = .krupaBrand

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.krupaHeadline)
                .foregroundStyle(Color.krupaTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KrupaSpacing.xs)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(Color.krupaSurfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }
}

/// Рядок розподілу карток за фазою.
private struct ProgressPhaseRow: View {
    var phase: CardPhase
    var count: Int
    var total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(count) / Double(total)))
    }

    private var tint: Color {
        switch phase {
        case .new: return .krupaTextSecondary
        case .learning: return .krupaWarning
        case .review: return .krupaSuccess
        case .relearning: return .krupaError
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
            HStack(spacing: KrupaSpacing.xs) {
                Text(phase.titleUk)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text("\(Int((fraction * 100).rounded()))%")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
            KrupaProgressBar(value: fraction, tint: tint, height: 6)
        }
    }
}

/// Рядок розподілу карток за рівнем.
private struct ProgressLevelRow: View {
    var level: Level
    var count: Int
    var total: Int

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(count) / Double(total)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
            HStack(spacing: KrupaSpacing.xs) {
                LevelBadge(level: level)
                Text(level.subtitleUk)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                Spacer(minLength: 0)
                Text("\(count) карток")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
            KrupaProgressBar(value: fraction, tint: Color.forLevel(level), height: 6)
        }
    }
}

/// Рядок «підпис + значення + смуга» для показників сили знань.
private struct ProgressMeterRow: View {
    var title: String
    var valueText: String
    var fraction: Double
    var tint: Color = .krupaBrand

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
            HStack(spacing: KrupaSpacing.xs) {
                Text(title)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                Spacer(minLength: 0)
                Text(valueText)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
            KrupaProgressBar(value: fraction, tint: tint, height: 6)
        }
    }
}

/// Рядок журналу: час, тип елемента, оцінка та час відповіді.
private struct ProgressReviewRow: View {
    var entry: ReviewLogEntry
    var timeText: String

    var body: some View {
        HStack(alignment: .center, spacing: KrupaSpacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeText)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text(entry.itemType.titleUk)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                ChipView(
                    text: entry.grade.titleUk,
                    systemImage: nil,
                    tint: Color.forGrade(entry.grade)
                )
                Text("\(entry.responseMs) мс")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
