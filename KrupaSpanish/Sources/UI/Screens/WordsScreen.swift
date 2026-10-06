import Foundation
import SwiftUI

// MARK: - Вкладка «Слова»

/// Словник курсу: перемикач рівня, пошук, фільтри та список слів із прогресом.
struct WordsScreen: View {
    @EnvironmentObject private var app: AppState

    @State private var level: Level = .a0
    @State private var query: String = ""
    @State private var partOfSpeech: PartOfSpeech? = nil
    @State private var learnedFilter: WordsLearnedFilter = .all
    @State private var didLoadProfileLevel = false

    var body: some View {
        VStack(spacing: KrupaSpacing.sm) {
            WordsLevelPicker(selection: $level)
                .padding(.horizontal, KrupaSpacing.screenPadding)
                .padding(.top, KrupaSpacing.xs)

            WordsSearchField(text: $query)
                .padding(.horizontal, KrupaSpacing.screenPadding)

            WordsResultsList(
                level: level,
                query: $query,
                partOfSpeech: $partOfSpeech,
                learnedFilter: $learnedFilter
            )
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Слова")
        .onAppear(perform: loadProfileLevelIfNeeded)
    }

    /// Один раз підставляємо рівень із профілю — далі користувач керує ним сам.
    private func loadProfileLevelIfNeeded() {
        guard !didLoadProfileLevel else { return }
        didLoadProfileLevel = true
        level = app.progress.profile.level
    }
}

// MARK: - Окремий маршрут списку слів

/// Той самий список, але без перемикача рівня й із заголовком рівня.
struct WordsListScreen: View {
    let level: Level

    @State private var query: String = ""
    @State private var partOfSpeech: PartOfSpeech? = nil
    @State private var learnedFilter: WordsLearnedFilter = .all

    var body: some View {
        VStack(spacing: KrupaSpacing.sm) {
            WordsSearchField(text: $query)
                .padding(.horizontal, KrupaSpacing.screenPadding)
                .padding(.top, KrupaSpacing.xs)

            WordsResultsList(
                level: level,
                query: $query,
                partOfSpeech: $partOfSpeech,
                learnedFilter: $learnedFilter
            )
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(level.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Фільтр вивченості

/// Три стани фільтра за вивченістю (відповідник android `WordFilter`).
/// «Засвоєні» = `SrsEngine.isLearned(card)`, решта карток — «Ще не вчилися».
private enum WordsLearnedFilter: String, CaseIterable, Identifiable {
    case all
    case learned
    case unlearned

    var id: String { rawValue }

    /// Формулювання взяті з android-версії (`WordFilter.ALL/MASTERED/NOT_STARTED`).
    var titleUk: String {
        switch self {
        case .all: return "Усі"
        case .learned: return "Засвоєні"
        case .unlearned: return "Ще не вчилися"
        }
    }
}

// MARK: - Фільтрація та зведення

/// Логіка відбору слів для списку.
private enum WordsFiltering {

    /// Нормалізація для пошуку: без регістру, діакритики та пунктуації.
    static func normalize(_ text: String) -> String {
        AnswerCheck.normalizeLoose(AnswerCheck.stripAccents(text))
    }

    static func isLearned(_ card: CardState?) -> Bool {
        guard let card else { return false }
        return SrsEngine.isLearned(card)
    }

    static func matchesQuery(_ word: Word, query: String) -> Bool {
        let needle = normalize(query)
        guard !needle.isEmpty else { return true }
        return normalize(word.spanish).contains(needle)
            || normalize(word.translationUk).contains(needle)
    }

    static func matchesPartOfSpeech(_ word: Word, part: PartOfSpeech?) -> Bool {
        guard let part else { return true }
        return word.partOfSpeech == part
    }

    static func matchesLearned(_ card: CardState?, filter: WordsLearnedFilter) -> Bool {
        switch filter {
        case .all: return true
        case .learned: return isLearned(card)
        case .unlearned: return !isLearned(card)
        }
    }

    /// Видимі слова рівня після застосування всіх фільтрів.
    static func visible(
        words: [Word],
        query: String,
        part: PartOfSpeech?,
        filter: WordsLearnedFilter,
        card: (String) -> CardState?
    ) -> [Word] {
        words.filter { word in
            matchesQuery(word, query: query)
                && matchesPartOfSpeech(word, part: part)
                && matchesLearned(card(word.id), filter: filter)
        }
    }
}

/// Українське відмінювання слова «слово» для зведення.
private enum WordsText {
    static func words(_ count: Int) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        if mod100 >= 11 && mod100 <= 14 { return "\(count) слів" }
        if mod10 == 1 { return "\(count) слово" }
        if mod10 >= 2 && mod10 <= 4 { return "\(count) слова" }
        return "\(count) слів"
    }
}

// MARK: - Спільний список

/// Зведення, фільтри та рядки слів. Використовується і вкладкою, і маршрутом.
private struct WordsResultsList: View {
    let level: Level

    @Binding var query: String
    @Binding var partOfSpeech: PartOfSpeech?
    @Binding var learnedFilter: WordsLearnedFilter

    @EnvironmentObject private var app: AppState

    private var levelWords: [Word] {
        app.content.words(level: level)
    }

    private var visibleWords: [Word] {
        WordsFiltering.visible(
            words: levelWords,
            query: query,
            part: partOfSpeech,
            filter: learnedFilter,
            card: app.progress.card(for:)
        )
    }

    private var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
            || partOfSpeech != nil
            || learnedFilter != .all
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                WordsSummaryCard(level: level, words: levelWords)
                WordsFilterSection(partOfSpeech: $partOfSpeech, learnedFilter: $learnedFilter)

                if visibleWords.isEmpty {
                    WordsEmptyResults(hasActiveFilters: hasActiveFilters, reset: resetFilters)
                } else {
                    ForEach(visibleWords, id: \.id) { word in
                        WordsResultRow(
                            word: word,
                            isLearned: WordsFiltering.isLearned(app.progress.card(for: word.id))
                        )
                    }
                }
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.vertical, KrupaSpacing.sm)
        }
    }

    private func resetFilters() {
        query = ""
        partOfSpeech = nil
        learnedFilter = .all
    }
}

// MARK: - Зведення

/// Скільки всього слів, скільки засвоєно та яка це частка.
private struct WordsSummaryCard: View {
    let level: Level
    let words: [Word]

    @EnvironmentObject private var app: AppState

    private var learnedCount: Int {
        words.filter { WordsFiltering.isLearned(app.progress.card(for: $0.id)) }.count
    }

    private var learningCount: Int {
        words.filter { word in
            guard let card = app.progress.card(for: word.id) else { return false }
            let started = card.phase != .new || card.totalReviews > 0
            return started && !SrsEngine.isLearned(card)
        }.count
    }

    private var fraction: Double {
        words.isEmpty ? 0 : Double(learnedCount) / Double(words.count)
    }

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "\(level.title) — \(level.subtitleUk)",
                    subtitle: "Словник курсу: \(WordsText.words(words.count)). "
                        + "Стан показує, наскільки надійно слово закріпилося в пам'яті.",
                    systemImage: "character.book.closed.fill"
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KrupaSpacing.xs) {
                        ChipView(text: "Усього: \(words.count)", systemImage: "textformat.abc")
                        ChipView(
                            text: "Засвоєно: \(learnedCount)",
                            systemImage: "checkmark.seal.fill",
                            tint: .krupaSuccess
                        )
                        ChipView(
                            text: "У навчанні: \(learningCount)",
                            systemImage: "clock",
                            tint: .krupaWarning
                        )
                    }
                    .padding(.vertical, 2)
                }

                KrupaProgressBar(value: fraction, tint: .krupaSuccess)
                Text("Засвоєно \(Int((fraction * 100).rounded())) % слів цього рівня.")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
        }
    }
}

// MARK: - Панель фільтрів

/// Фільтр частини мови (чипи) та вивченості (сегмент).
private struct WordsFilterSection: View {
    @Binding var partOfSpeech: PartOfSpeech?
    @Binding var learnedFilter: WordsLearnedFilter

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            Text("Частина мови")
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextSecondary)

            WordsPartOfSpeechChips(selection: $partOfSpeech)

            Picker("Вивченість", selection: $learnedFilter) {
                ForEach(WordsLearnedFilter.allCases, id: \.id) { filter in
                    Text(filter.titleUk).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

/// Горизонтальний скрол чипів частин мови.
private struct WordsPartOfSpeechChips: View {
    @Binding var selection: PartOfSpeech?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KrupaSpacing.xs) {
                WordsChipButton(text: "Усі", isSelected: selection == nil) {
                    selection = nil
                }
                ForEach(PartOfSpeech.allCases, id: \.rawValue) { part in
                    WordsChipButton(text: part.shortTitleUk, isSelected: selection == part) {
                        selection = part
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// Чип-кнопка фільтра.
private struct WordsChipButton: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ChipView(
                text: text,
                systemImage: isSelected ? "checkmark" : nil,
                tint: isSelected ? Color.krupaBrand : Color.krupaTextSecondary
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.krupaBrand : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Пошук

/// Поле пошуку з іконкою лупи: шукає іспанською та українською.
private struct WordsSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.krupaTextSecondary)

            TextField("Пошук іспанською або українською", text: $text)
                .font(.krupaBody)
                .foregroundStyle(Color.krupaTextPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.krupaTextSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Очистити пошук")
            }
        }
        .padding(KrupaSpacing.sm)
        .background(Color.krupaSurface)
        .overlay(
            RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous)
                .stroke(Color.krupaDivider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
    }
}

// MARK: - Перемикач рівня

/// Сегментований перемикач рівня (`Level.allCases`).
private struct WordsLevelPicker: View {
    @Binding var selection: Level

    var body: some View {
        Picker("Рівень", selection: $selection) {
            ForEach(Level.allCases, id: \.id) { level in
                Text(level.title).tag(level)
            }
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Рядок і порожній стан

/// Рядок списку: картка слова з переходом на деталі.
private struct WordsResultRow: View {
    let word: Word
    let isLearned: Bool

    var body: some View {
        NavigationLink(value: AppRoute.wordDetail(word.id)) {
            KrupaCard(padding: KrupaSpacing.sm) {
                HStack(spacing: KrupaSpacing.xs) {
                    WordRowView(word: word, showsTranslation: true, isLearned: isLearned)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// Порожній результат фільтрації.
private struct WordsEmptyResults: View {
    let hasActiveFilters: Bool
    let reset: () -> Void

    var body: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "Нічого не знайдено",
            message: "Спробуйте змінити фільтр або запит пошуку.",
            actionTitle: hasActiveFilters ? "Скинути фільтри" : nil,
            action: hasActiveFilters ? reset : nil
        )
    }
}
