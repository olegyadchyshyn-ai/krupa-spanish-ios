import SwiftUI

// MARK: - Перелік аудіювань

/// Список матеріалів для аудіювання з перемикачем рівня
/// (відповідник android `ListeningScreen`).
struct ListeningListScreen: View {
    @EnvironmentObject private var app: AppState

    /// Обраний рівень — за замовчуванням беремо рівень профілю.
    @State private var level: Level = .a0
    @State private var didApplyInitialLevel = false

    // MARK: - Дані

    private var items: [ListeningItem] {
        app.content.listening(level: level)
    }

    /// Скільки матеріалів рівня вже пройдено (є картка SRS із повтореннями).
    private var completedCount: Int {
        var count = 0
        for item in items where isCompleted(item) {
            count += 1
        }
        return count
    }

    private func isCompleted(_ item: ListeningItem) -> Bool {
        let reviews = app.progress.card(for: item.id)?.totalReviews ?? 0
        return reviews > 0
    }

    /// Підказка для обраного рівня (тексти з android-версії).
    private var levelHint: String {
        switch level {
        case .a0: return "A0 — дуже прості речення з візуальною опорою. Слухайте й повторюйте вголос."
        case .a1: return "A1 — короткі діалоги про щоденні справи. Намагайтеся вловити, хто що робить."
        case .a2: return "A2 — побутові історії з минулими часами. Звертайте увагу на послідовність подій."
        }
    }

    // MARK: - Вигляд

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                introCard
                ListeningLevelPicker(selection: $level)
                summaryRow
                listContent
            }
            .padding(KrupaSpacing.screenPadding)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Слухання")
        .onAppear {
            guard !didApplyInitialLevel else { return }
            didApplyInitialLevel = true
            level = app.profile.level
        }
    }

    // MARK: Секції

    private var introCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Слухання",
                    subtitle: "Мета — розуміти загальний зміст, а не кожне слово. Слухайте кілька разів, переклад відкривайте лише за потреби.",
                    systemImage: "headphones"
                )
                Text(levelHint).font(.krupaCaption).foregroundStyle(Color.krupaTextSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var summaryRow: some View {
        HStack(spacing: KrupaSpacing.sm) {
            StatTile(title: "Усього матеріалів", value: "\(items.count)", systemImage: "list.bullet", tint: .krupaBrand)
            StatTile(title: "Пройдено", value: "\(completedCount)", systemImage: "checkmark.seal.fill", tint: .krupaSuccess)
        }
    }

    @ViewBuilder
    private var listContent: some View {
        if items.isEmpty {
            EmptyStateView(
                systemImage: "headphones",
                title: "Для цього рівня матеріалів немає",
                message: "Оберіть інший рівень — матеріали додаються поступово.",
                actionTitle: nil,
                action: nil
            )
        } else {
            VStack(spacing: KrupaSpacing.sm) {
                ForEach(items, id: \.id) { item in
                    NavigationLink(value: AppRoute.listeningDetail(item.id)) {
                        ListeningRow(item: item, isCompleted: isCompleted(item))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Деталі аудіювання

/// Екран одного матеріалу: прослуховування, текст, ключові слова й питання
/// (відповідник android `ListeningDetailScreen`).
struct ListeningDetailScreen: View {
    let itemId: String

    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    /// Перемикачі підказок — спочатку приховані, якщо підказки увімкнено в налаштуваннях.
    @State private var showsText = false
    @State private var showsTranslation = false
    @State private var didApplyHintDefaults = false

    /// Швидкість відтворення та фонове завдання повільної черги реплік.
    @State private var isSlow = false
    @State private var playbackTask: Task<Void, Never>?

    /// Стан блоку питань на розуміння.
    @State private var questionIndex = 0
    @State private var selectedOption: Int?
    @State private var correctCount = 0
    @State private var isQuizFinished = false
    @State private var didMarkCompleted = false

    /// Чи додано матеріал у повторення.
    @State private var isAddedToReview = false

    private var item: ListeningItem? {
        app.content.listeningItem(itemId)
    }

    /// Текст показуємо за перемикачем; якщо підказки вимкнено — показуємо все одразу.
    private var textVisible: Bool {
        showsText || !app.settings.listeningHintsEnabled
    }

    private var translationVisible: Bool {
        showsTranslation || !app.settings.listeningHintsEnabled
    }

    // MARK: - Вигляд

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                if let item {
                    headerCard(item: item)
                    listenCard(item: item)
                    linesCard(item: item)
                    keyWordsCard(item: item)
                    questionsCard(item: item)
                    reviewCard(item: item)
                } else {
                    notFound
                }
            }
            .padding(KrupaSpacing.screenPadding)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(item?.titleUk ?? "Слухання")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { applyHintDefaults() }
        .onDisappear { stopPlayback() }
    }

    private var notFound: some View {
        EmptyStateView(
            systemImage: "questionmark.circle",
            title: "Матеріал не знайдено",
            message: "Схоже, цей матеріал більше недоступний. Поверніться до списку аудіювань.",
            actionTitle: "До списку",
            action: { dismiss() }
        )
    }

    // MARK: Заголовок

    private func headerCard(item: ListeningItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
                    Text(item.titleUk).font(.krupaTitle).foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    LevelBadge(level: item.level)
                }

                Text(item.titleEs).font(.krupaSpanishExample).foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: KrupaSpacing.xs) {
                    ChipView(text: item.kind.titleUk, systemImage: item.kind.listIconName, tint: .krupaBrand)
                    ChipView(text: "реплік: \(item.lines.count)", systemImage: "text.bubble", tint: .krupaTextSecondary)
                    ChipView(text: "питань: \(item.comprehensionQuestions.count)", systemImage: "questionmark.circle", tint: .krupaTextSecondary)
                }

                if isCompleted(item) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 12, weight: .semibold))
                        Text("Пройдено").font(.krupaSmall)
                    }
                    .foregroundStyle(Color.krupaSuccess)
                }
            }
        }
    }

    // MARK: Слухання

    private func listenCard(item: ListeningItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: "Слухати", subtitle: nil, systemImage: "waveform")

                PrimaryActionButton(title: "Прослухати", systemImage: "play.fill", isEnabled: !item.lines.isEmpty, action: { playAll(item: item) })
                .accessibilityLabel("Слухати повністю")

                HStack(spacing: KrupaSpacing.sm) {
                    SecondaryActionButton(title: "Зупинити", systemImage: "stop.fill", tint: .krupaError, action: { stopPlayback() })
                    SecondaryActionButton(
                        title: "Повторити",
                        systemImage: "arrow.counterclockwise",
                        tint: .krupaBrand,
                        action: { playAll(item: item) }
                    )
                }

                SpeedToggle(isSlow: $isSlow, onChange: { slow in restart(item: item, slow: slow) })

                if app.speech.isSpeaking {
                    HStack(spacing: KrupaSpacing.xs) {
                        ProgressView().tint(Color.krupaBrand)
                        Text("Відтворюється…").font(.krupaCaption).foregroundStyle(Color.krupaTextSecondary)
                    }
                } else {
                    Text("Натисніть «Прослухати» — діалог читає синтезатор мовлення.").font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }
    }

    // MARK: Репліки

    private func linesCard(item: ListeningItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: "Текст", subtitle: nil, systemImage: "text.alignleft")
                hintToggles

                ForEach(Array(item.lines.enumerated()), id: \.offset) { entry in
                    ListeningLineRow(
                        line: entry.element,
                        tint: speakerTint(for: entry.element.speaker, in: item),
                        showsText: textVisible,
                        showsTranslation: translationVisible,
                        isSpeaking: app.speech.isSpeakingText(entry.element.spanish),
                        onSpeak: { speak(line: entry.element) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var hintToggles: some View {
        if app.settings.listeningHintsEnabled {
            HStack(spacing: KrupaSpacing.xs) {
                HintToggleButton(title: "Показати текст", systemImage: "eye", isOn: showsText, action: { showsText.toggle() })
                HintToggleButton(
                    title: "Показати переклад",
                    systemImage: "character.book.closed",
                    isOn: showsTranslation,
                    action: { showsTranslation.toggle() }
                )
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Ключові слова

    @ViewBuilder
    private func keyWordsCard(item: ListeningItem) -> some View {
        if !item.keyWords.isEmpty {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(title: "Ключові слова", subtitle: "Натисніть на слово, щоб почути його.", systemImage: "textformat.abc")
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 140), spacing: KrupaSpacing.xs)],
                        alignment: .leading,
                        spacing: KrupaSpacing.xs
                    ) {
                        ForEach(Array(item.keyWords.enumerated()), id: \.offset) { entry in
                            KeyWordChip(keyWord: entry.element, action: { speakKeyWord(entry.element) })
                        }
                    }
                }
            }
        }
    }

    // MARK: Питання на розуміння

    @ViewBuilder
    private func questionsCard(item: ListeningItem) -> some View {
        if !item.comprehensionQuestions.isEmpty {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(title: "Перевірте розуміння", subtitle: quizSubtitle(item: item), systemImage: "questionmark.circle")
                    if isQuizFinished {
                        quizResult(item: item)
                    } else if let question = currentQuestion(item: item) {
                        questionBlock(question: question, item: item)
                    }
                }
            }
        }
    }

    private func quizSubtitle(item: ListeningItem) -> String {
        let total = item.comprehensionQuestions.count
        if isQuizFinished {
            return "Правильно \(correctCount) з \(total)"
        }
        return "Питання \(questionIndex + 1) з \(total)"
    }

    private func currentQuestion(item: ListeningItem) -> ComprehensionQuestion? {
        let questions = item.comprehensionQuestions
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    private func questionBlock(question: ComprehensionQuestion, item: ListeningItem) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            Text(question.questionUk).font(.krupaBody).foregroundStyle(Color.krupaTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(question.options.enumerated()), id: \.offset) { entry in
                AnswerOptionRow(
                    text: entry.element,
                    state: optionState(index: entry.offset, question: question),
                    subtitle: nil,
                    action: { select(option: entry.offset, question: question) }
                )
            }

            if let selected = selectedOption {
                feedbackBlock(question: question, selected: selected)

                PrimaryActionButton(
                    title: isLastQuestion(item: item) ? "Завершити" : "Далі",
                    systemImage: "arrow.right",
                    isEnabled: true,
                    action: { advance(item: item) }
                )
            }
        }
    }

    private func feedbackBlock(question: ComprehensionQuestion, selected: Int) -> some View {
        let isCorrect = selected == question.correctIndex
        let correctText = question.correctOption ?? ""
        return VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isCorrect ? Color.krupaSuccess : Color.krupaError)
                Text(isCorrect ? "✓ Правильно." : "✕ Правильна відповідь: \(correctText)").font(.krupaCallout)
                    .foregroundStyle(isCorrect ? Color.krupaSuccess : Color.krupaError)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            ExplanationBox(
                title: "Пояснення",
                text: question.explanationUk,
                tint: isCorrect ? Color.krupaSuccess : Color.krupaWarning,
                systemImage: isCorrect ? "checkmark.circle" : "info.circle"
            )
        }
    }

    private func quizResult(item: ListeningItem) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            HStack(spacing: KrupaSpacing.sm) {
                Image(systemName: correctCount == item.comprehensionQuestions.count ? "star.circle.fill" : "checkmark.circle")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(quizTint(item: item))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Правильно \(correctCount) з \(item.comprehensionQuestions.count)").font(.krupaHeadline)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Text("Відповідей: \(item.comprehensionQuestions.count)").font(.krupaCaption).foregroundStyle(Color.krupaTextSecondary)
                }
                Spacer(minLength: 0)
            }

            KrupaProgressBar(value: quizFraction(item: item), tint: quizTint(item: item), height: 8, showsLabel: true)

            SecondaryActionButton(title: "Пройти ще раз", systemImage: "arrow.counterclockwise", tint: .krupaBrand, action: { restartQuiz() })
        }
    }

    private func quizTint(item: ListeningItem) -> Color {
        let total = item.comprehensionQuestions.count
        guard total > 0 else { return .krupaBrand }
        let fraction = Double(correctCount) / Double(total)
        if fraction >= 0.8 { return .krupaSuccess }
        if fraction >= 0.5 { return .krupaWarning }
        return .krupaError
    }

    private func quizFraction(item: ListeningItem) -> Double {
        let total = item.comprehensionQuestions.count
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }

    // MARK: Повторення

    private func reviewCard(item: ListeningItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Повторення",
                    subtitle: "Додайте матеріал у розклад, щоб повернутися до нього пізніше.",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                if isAddedToReview {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.krupaSuccess)
                        Text("Додано в повторення").font(.krupaCaption).foregroundStyle(Color.krupaTextPrimary)
                    }
                } else {
                    SecondaryActionButton(
                        title: "Додати в повторення",
                        systemImage: "plus.circle",
                        tint: .krupaBrand,
                        action: { addToReview(item: item) }
                    )
                }
            }
        }
    }

    // MARK: - Дії

    private func isCompleted(_ item: ListeningItem) -> Bool {
        let reviews = app.progress.card(for: item.id)?.totalReviews ?? 0
        return reviews > 0
    }

    private func applyHintDefaults() {
        guard !didApplyHintDefaults else { return }
        didApplyHintDefaults = true
        // Спершу текст і переклад приховані — спочатку просто слухаємо.
        if app.settings.listeningHintsEnabled {
            showsText = false
            showsTranslation = false
        }
    }

    private func playAll(item: ListeningItem) {
        guard !item.lines.isEmpty else { return }
        if isSlow {
            playSlow(item: item)
        } else {
            playbackTask?.cancel()
            playbackTask = nil
            app.speech.speakDialogue(item.lines.map(\.spanish))
        }
    }

    /// Повільний режим: озвучуємо репліки по одній із паузою між ними.
    private func playSlow(item: ListeningItem) {
        playbackTask?.cancel()
        app.speech.stop()
        let lines = item.lines
        playbackTask = Task {
            for line in lines {
                if Task.isCancelled { return }
                app.speech.speak(line.spanish, rateOverride: 0.35)
                // Невелика пауза між репліками.
                try? await Task.sleep(for: .milliseconds(600))
                // Чекаємо, доки репліка дозвучить, інакше наступна її обірве.
                var waited = 0
                while app.speech.isSpeaking && !Task.isCancelled && waited < 240 {
                    try? await Task.sleep(for: .milliseconds(250))
                    waited += 1
                }
            }
        }
    }

    private func restart(item: ListeningItem, slow: Bool) {
        stopPlayback()
        isSlow = slow
        playAll(item: item)
    }

    private func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        app.speech.stop()
    }

    private func speak(line: ListeningLine) {
        app.speech.speak(line.spanish, rateOverride: isSlow ? 0.35 : nil)
    }

    private func speakKeyWord(_ keyWord: ListeningKeyWord) {
        app.speech.speak(keyWord.spanish, rateOverride: isSlow ? 0.35 : nil)
    }

    private func speakerTint(for speaker: String, in item: ListeningItem) -> Color {
        let palette: [Color] = [.krupaBrand, .krupaGold, .krupaSuccess, .krupaWarning, .krupaBrandDark]
        guard let index = item.speakers.firstIndex(of: speaker) else { return .krupaBrand }
        return palette[index % palette.count]
    }

    private func optionState(index: Int, question: ComprehensionQuestion) -> AnswerOptionState {
        guard let selected = selectedOption else { return .idle }
        if index == question.correctIndex { return .correct }
        if index == selected { return .wrong }
        return .idle
    }

    private func select(option index: Int, question: ComprehensionQuestion) {
        guard selectedOption == nil else { return }
        selectedOption = index
        if index == question.correctIndex {
            correctCount += 1
        }
    }

    private func isLastQuestion(item: ListeningItem) -> Bool {
        questionIndex + 1 >= item.comprehensionQuestions.count
    }

    private func advance(item: ListeningItem) {
        selectedOption = nil
        if questionIndex + 1 < item.comprehensionQuestions.count {
            questionIndex += 1
        } else {
            isQuizFinished = true
            if !didMarkCompleted {
                didMarkCompleted = true
                app.markListeningCompleted()
            }
        }
    }

    private func restartQuiz() {
        questionIndex = 0
        selectedOption = nil
        correctCount = 0
        isQuizFinished = false
    }

    private func addToReview(item: ListeningItem) {
        _ = app.progress.cardOrCreate(
            itemId: item.id,
            itemType: .listening,
            level: item.level,
            topicId: item.topicId,
            grammarTags: []
        )
        withAnimation {
            isAddedToReview = true
        }
    }
}

// MARK: - Допоміжні view

/// Перемикач рівня у списку аудіювань.
private struct ListeningLevelPicker: View {
    @Binding var selection: Level

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            ForEach(Level.allCases, id: \.rawValue) { level in
                Button {
                    selection = level
                } label: {
                    VStack(spacing: 2) {
                        Text(level.rawValue).font(.krupaCallout)
                        Text(level.subtitleUk).font(.krupaSmall)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selection == level ? Color.white : Color.krupaTextSecondary)
                    .background(selection == level ? Color.forLevel(level) : Color.krupaSurface)
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Рівень \(level.rawValue)")
            }
        }
    }
}

/// Картка одного матеріалу в списку.
private struct ListeningRow: View {
    var item: ListeningItem
    var isCompleted: Bool

    private var metaText: String {
        var parts: [String] = [item.kind.titleUk]
        parts.append(" · реплік: \(item.lines.count)")
        parts.append(" · питань: \(item.comprehensionQuestions.count)")
        return parts.joined()
    }

    var body: some View {
        HStack(spacing: KrupaSpacing.sm) {
            Image(systemName: item.kind.listIconName).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.krupaBrand)
                .frame(width: 42, height: 42)
                .background(Color.krupaBrand.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.titleUk).font(.krupaCallout).foregroundStyle(Color.krupaTextPrimary).lineLimit(1)
                    LevelBadge(level: item.level)
                    if isCompleted {
                        completedBadge
                    }
                }
                Text(item.titleEs).font(.krupaCaption).foregroundStyle(Color.krupaTextSecondary).lineLimit(1)
                Text(metaText).font(.krupaSmall).foregroundStyle(Color.krupaTextSecondary).lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.krupaTextSecondary)
        }
        .padding(KrupaSpacing.sm)
        .background(Color.krupaSurface)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }

    private var completedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 10, weight: .bold))
            Text("Пройдено").font(.krupaSmall)
        }
        .foregroundStyle(Color.krupaSuccess)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.krupaSuccess.opacity(0.12))
        .clipShape(Capsule())
    }
}

/// Одна репліка діалогу: мовець, іспанський текст і переклад.
private struct ListeningLineRow: View {
    var line: ListeningLine
    var tint: Color
    var showsText: Bool
    var showsTranslation: Bool
    var isSpeaking: Bool
    var onSpeak: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.sm) {
            speakerBadge

            VStack(alignment: .leading, spacing: 4) {
                Button(action: onSpeak) {
                    Text(showsText ? line.spanish : "•••").font(.krupaSpanishExample)
                        .foregroundStyle(showsText ? Color.krupaTextPrimary : Color.krupaTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Прослухати репліку")

                if showsTranslation, !line.translationUk.isEmpty {
                    Text(line.translationUk).font(.krupaCaption).foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            SpeakerButton(isSpeaking: isSpeaking, size: 15, action: onSpeak)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var speakerBadge: some View {
        if line.speaker.isEmpty {
            Image(systemName: "person.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(tint).frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(Circle())
        } else {
            Text(line.speaker).font(.krupaSmall).fontWeight(.bold).foregroundStyle(tint).lineLimit(1).padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(tint.opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

/// Чип ключового слова — натиск озвучує слово.
private struct KeyWordChip: View {
    var keyWord: ListeningKeyWord
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(keyWord.spanish).font(.system(size: 15, weight: .semibold, design: .serif)).foregroundStyle(Color.krupaTextPrimary)
                Text(keyWord.translationUk).font(.krupaSmall).foregroundStyle(Color.krupaTextSecondary).lineLimit(1)
            }
            .padding(.horizontal, KrupaSpacing.xs)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.krupaSurfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Прослухати \(keyWord.spanish)")
    }
}

/// Перемикач швидкості відтворення: «Повільно» / «Звично».
private struct SpeedToggle: View {
    @Binding var isSlow: Bool
    var onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            speedButton(title: "Повільно", systemImage: "tortoise", isActive: isSlow) { select(true) }
            speedButton(title: "Звично", systemImage: "hare", isActive: !isSlow) { select(false) }
            Spacer(minLength: 0)
        }
    }

    private func speedButton(
        title: String,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(.krupaSmall)
            }
            .foregroundStyle(isActive ? Color.white : Color.krupaBrand)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? Color.krupaBrand : Color.krupaBrand.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func select(_ slow: Bool) {
        guard isSlow != slow else { return }
        isSlow = slow
        onChange(slow)
    }
}

/// Перемикач підказки (текст або переклад).
private struct HintToggleButton: View {
    var title: String
    var systemImage: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : systemImage).font(.system(size: 11, weight: .semibold))
                Text(title).font(.krupaSmall)
            }
            .foregroundStyle(isOn ? Color.white : Color.krupaBrand)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isOn ? Color.krupaBrand : Color.krupaBrand.opacity(0.12))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Допоміжне

private extension ListeningKind {
    /// SF Symbol для типу аудіювання.
    var listIconName: String {
        switch self {
        case .dialogue: return "bubble.left.and.bubble.right.fill"
        case .story: return "book.fill"
        case .monologue: return "person.wave.2.fill"
        case .podcast: return "mic.fill"
        case .unknown: return "headphones"
        }
    }
}
