import Foundation
import SwiftUI

// MARK: - Перелік правил

/// Граматика курсу: перемикач рівня, пошук і картки правил.
struct GrammarListScreen: View {
    @EnvironmentObject private var app: AppState

    /// `nil` — показати правила всіх рівнів (пункт «Усі»).
    @State private var level: Level? = nil
    @State private var query: String = ""

    private var notes: [GrammarNote] {
        GrammarFiltering.visible(
            notes: GrammarFiltering.notes(in: app.content, level: level),
            query: query
        )
    }

    var body: some View {
        VStack(spacing: KrupaSpacing.sm) {
            GrammarLevelPicker(selection: $level)
                .padding(.horizontal, KrupaSpacing.screenPadding)
                .padding(.top, KrupaSpacing.xs)

            GrammarSearchField(text: $query)
                .padding(.horizontal, KrupaSpacing.screenPadding)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    header

                    if notes.isEmpty {
                        EmptyStateView(
                            systemImage: "text.book.closed",
                            title: "Нічого не знайдено",
                            message: "Спробуйте змінити рівень або запит пошуку."
                        )
                    } else {
                        ForEach(notes, id: \.id) { note in
                            GrammarNoteRow(note: note)
                        }
                    }
                }
                .padding(.horizontal, KrupaSpacing.screenPadding)
                .padding(.vertical, KrupaSpacing.sm)
            }
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Граматика")
    }

    /// Пояснювальна шапка списку.
    private var header: some View {
        KrupaCard(background: .krupaSurfaceAlt) {
            VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                Text("Граматика")
                    .font(.krupaHeadline)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text(
                    "Пояснення українською: не «вивчи правило», "
                        + "а «чому іспанці будують речення саме так». "
                        + "Усього тем: \(notes.count)"
                )
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Фільтрація правил

/// Відбір правил за рівнем і пошуковим запитом.
private enum GrammarFiltering {

    /// Нормалізація для пошуку: без регістру, діакритики та пунктуації.
    static func normalize(_ text: String) -> String {
        AnswerCheck.normalizeLoose(AnswerCheck.stripAccents(text))
    }

    /// Правила рівня; для `nil` — усі рівні за порядком A0 → A1 → A2.
    static func notes(in content: CourseContent, level: Level?) -> [GrammarNote] {
        guard let level else {
            return Level.allCases.flatMap { content.grammarNotes(level: $0) }
        }
        return content.grammarNotes(level: level)
    }

    /// Пошук за українською назвою, іспанською назвою та тегом.
    static func visible(notes: [GrammarNote], query: String) -> [GrammarNote] {
        let needle = normalize(query)
        guard !needle.isEmpty else { return notes }
        return notes.filter { note in
            normalize(note.titleUk).contains(needle)
                || normalize(note.titleEs).contains(needle)
                || normalize(note.tag).contains(needle)
        }
    }
}

// MARK: - Елементи списку

/// Сегментований перемикач рівня з пунктом «Усі».
private struct GrammarLevelPicker: View {
    @Binding var selection: Level?

    var body: some View {
        Picker("Рівень", selection: $selection) {
            Text("Усі").tag(Level?.none)
            ForEach(Level.allCases, id: \.id) { level in
                Text(level.title).tag(Level?.some(level))
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Поле пошуку з іконкою лупи.
private struct GrammarSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.krupaTextSecondary)

            TextField("Пошук за назвою або тегом", text: $text)
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

/// Картка правила в списку.
private struct GrammarNoteRow: View {
    let note: GrammarNote

    var body: some View {
        NavigationLink(value: AppRoute.grammarDetail(note.id)) {
            KrupaCard(padding: KrupaSpacing.sm) {
                VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                    HStack(spacing: KrupaSpacing.xs) {
                        Text(note.titleUk)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .lineLimit(1)
                        LevelBadge(level: note.level)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.krupaTextSecondary)
                    }

                    Text(note.titleEs)
                        .font(.krupaSpanishExample)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .lineLimit(1)

                    if !note.patternUk.isEmpty {
                        Text(note.patternUk)
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Одне правило

/// Правило: закономірність, пояснення, приклади, типові помилки та слова з тегом.
struct GrammarDetailScreen: View {
    let noteId: String

    @EnvironmentObject private var app: AppState

    private var note: GrammarNote? { app.content.grammarNote(noteId) }

    var body: some View {
        Group {
            if let note {
                content(for: note)
            } else {
                EmptyStateView(
                    systemImage: "text.book.closed",
                    title: "Правило не знайдено",
                    message: "Цього правила немає в поточному контенті курсу."
                )
            }
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(note?.titleUk ?? "Граматика")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for note: GrammarNote) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                GrammarDetailHeadCard(note: note)
                GrammarDetailPatternBlock(patternUk: note.patternUk)
                GrammarDetailExplanationCard(text: note.explanationUk)

                if !note.examples.isEmpty {
                    GrammarDetailExamplesCard(examples: note.examples)
                }

                if !note.commonMistakeUk.isEmpty {
                    ExplanationBox(
                        title: "Типова помилка",
                        text: note.commonMistakeUk,
                        tint: .krupaError,
                        systemImage: "exclamationmark.triangle"
                    )
                }

                if !note.tipForUkSpeakersUk.isEmpty {
                    ExplanationBox(
                        title: "Порада для україномовних",
                        text: note.tipForUkSpeakersUk,
                        tint: .krupaSuccess,
                        systemImage: "lightbulb"
                    )
                }

                GrammarDetailTagWordsCard(tag: note.tag)
            }
            .padding(KrupaSpacing.screenPadding)
        }
    }
}

// MARK: - Секції правила

/// Заголовок правила: іспанська назва, українська назва, рівень і тег.
private struct GrammarDetailHeadCard: View {
    let note: GrammarNote

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
                    Text(note.titleEs)
                        .font(.krupaTitle)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    LevelBadge(level: note.level)
                }

                Text(note.titleUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ChipView(text: note.tag, systemImage: "tag", tint: .krupaBrandDark)
            }
        }
    }
}

/// Закономірність правила — виділений блок.
private struct GrammarDetailPatternBlock: View {
    let patternUk: String

    var body: some View {
        if !patternUk.isEmpty {
            KrupaCard(background: .krupaSurfaceAlt) {
                VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                    Text("Закономірність")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaBrand)
                    Text(patternUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Основне пояснення правила.
private struct GrammarDetailExplanationCard: View {
    let text: String

    var body: some View {
        if !text.isEmpty {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    KrupaSectionHeader(title: "Пояснення", systemImage: "text.alignleft")
                    Text(text)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Приклади з озвученням, перекладом і підказкою.
private struct GrammarDetailExamplesCard: View {
    let examples: [GrammarExample]

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: "Приклади", systemImage: "text.quote")

                ForEach(examples.indices, id: \.self) { index in
                    GrammarDetailExampleRow(example: examples[index])
                    if index < examples.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

/// Один приклад: іспанською з озвученням, переклад і нотатка.
private struct GrammarDetailExampleRow: View {
    let example: GrammarExample

    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
            HStack(alignment: .center, spacing: KrupaSpacing.xs) {
                Text(example.spanish)
                    .font(.krupaSpanishExample)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                SpeakerButton(
                    isSpeaking: app.speech.isSpeakingText(example.spanish),
                    size: 18
                ) {
                    app.speak(example.spanish, force: true)
                }
            }

            if !example.translationUk.isEmpty {
                Text(example.translationUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !example.noteUk.isEmpty {
                ExplanationBox(
                    title: "Підказка",
                    text: example.noteUk,
                    tint: .krupaBrand,
                    systemImage: "lightbulb"
                )
            }
        }
    }
}

/// Слова, які належать до тега правила (горизонтальний список).
private struct GrammarDetailTagWordsCard: View {
    let tag: String

    @EnvironmentObject private var app: AppState

    private var words: [Word] {
        app.content.words(grammarTag: tag)
    }

    var body: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Слова з цим тегом",
                    subtitle: words.isEmpty
                        ? "Поки що немає слів із цим тегом."
                        : "Натисніть слово, щоб відкрити його картку.",
                    systemImage: "character.book.closed.fill"
                )

                if !words.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: KrupaSpacing.xs) {
                            ForEach(words, id: \.id) { word in
                                NavigationLink(value: AppRoute.wordDetail(word.id)) {
                                    GrammarDetailWordCard(word: word)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

/// Мінікартка слова для горизонтального списку.
private struct GrammarDetailWordCard: View {
    let word: Word

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.spanishWithArticle)
                .font(.system(size: 15, weight: .semibold, design: .serif))
                .foregroundStyle(Color.krupaTextPrimary)
                .lineLimit(1)
            Text(word.translationUk)
                .font(.krupaSmall)
                .foregroundStyle(Color.krupaTextSecondary)
                .lineLimit(1)
        }
        .padding(KrupaSpacing.xs)
        .frame(width: 150, alignment: .leading)
        .background(Color.krupaSurfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }
}
