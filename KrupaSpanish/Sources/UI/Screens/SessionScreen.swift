import SwiftUI

// MARK: - Екран заняття

/// Головний екран навчання (відповідник android `SessionScreen`).
///
/// Показує кроки заняття один за одним: слова, речення, граматичні довідки,
/// вправи всіх девʼяти типів і аудіювання. Перевірка відповідей та оцінка SRS
/// виконуються рушіями `SessionChecker`, `AnswerCheck` і `SrsEngine` — екран
/// лише показує стан і передає відповіді користувача.
struct SessionScreen: View {

    /// Тема, для якої складається заняття (`nil` — заняття дня).
    let topicId: String?

    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: Стан заняття

    @State private var plan: SessionPlan?
    @State private var index: Int = 0
    @State private var answer: String = ""
    @State private var feedback: SessionAnswerFeedback?
    @State private var usedHint: Bool = false
    @State private var startedAt: Date = Date()
    @State private var showSummary: Bool = false
    @State private var progress: SessionProgress = .start(totalItems: 0)

    // MARK: Стан поточного кроку

    @State private var choices: [String] = []
    @State private var buildTokens: [String] = []
    @State private var selectedTokens: [Int] = []
    @State private var matchPairs: [SessionMatchPair] = []
    @State private var matchOptions: [String] = []
    @State private var matchedPairIds: Set<Int> = []
    @State private var selectedPairId: Int?
    @State private var pairMistakes: Int = 0
    @State private var card: CardState?
    @State private var appliedGrade: Grade?
    @State private var isAutoGradedStep: Bool = false
    @State private var showPronunciation: Bool = false
    @State private var showExitDialog: Bool = false

    // MARK: Стан аудіювання

    @State private var showListeningText: Bool = false
    @State private var showListeningTranslation: Bool = false
    @State private var questionIndex: Int = 0
    @State private var questionResults: [Bool] = []

    // MARK: - Каркас екрана

    var body: some View {
        ZStack {
            Color.krupaBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                if let plan, !plan.isEmpty, !showSummary {
                    header(plan)
                }
                content
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadPlanIfNeeded() }
        .onDisappear {
            app.speech.stop()
            if app.recognition.isRecording {
                app.recognition.stop()
            }
        }
        .confirmationDialog(
            "Вийти із заняття?",
            isPresented: $showExitDialog,
            titleVisibility: .visible
        ) {
            Button("Вийти", role: .destructive) { dismiss() }
            Button("Продовжити", role: .cancel) { }
        } message: {
            Text("Поточний крок не збережеться. Ви можете повернутися до заняття пізніше.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let plan {
            if plan.isEmpty {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    EmptyStateView(
                        systemImage: "checkmark.circle",
                        title: "На сьогодні все зроблено",
                        message: "На сьогодні занять немає. Додайте нові теми в розділі «Навчання» або змініть рівень у налаштуваннях.",
                        actionTitle: "Повернутися",
                        action: { dismiss() }
                    )
                    Spacer(minLength: 0)
                }
            } else if showSummary {
                SessionSummaryView(
                    title: "Заняття завершено",
                    subtitle: plan.focusTopicTitleUk,
                    progress: progress,
                    minutes: minutesSpent,
                    onAgain: { restart() },
                    onFinish: { dismiss() }
                )
            } else {
                stepScroll
            }
        } else {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LoadingView(message: "Складаємо заняття…")
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Верхня панель

    private func header(_ plan: SessionPlan) -> some View {
        VStack(spacing: KrupaSpacing.xs) {
            HStack(spacing: KrupaSpacing.sm) {
                Button {
                    requestExit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.krupaTextSecondary)
                        .padding(9)
                        .background(Color.krupaSurfaceAlt)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Вийти")

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.focusTopicTitleUk ?? "Заняття")
                        .font(.krupaHeadline)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .lineLimit(1)

                    if let block = currentBlock {
                        HStack(spacing: 4) {
                            Image(systemName: block.kind.systemImageName)
                            Text(block.kind.titleUk)
                        }
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    }
                }

                Spacer(minLength: 0)

                Text("Крок \(min(index + 1, max(1, total))) з \(max(1, total))")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .lineLimit(1)
            }

            KrupaProgressBar(value: Double(index) / Double(max(1, total)))
        }
        .padding(.horizontal, KrupaSpacing.screenPadding)
        .padding(.top, KrupaSpacing.xs)
        .padding(.bottom, KrupaSpacing.sm)
        .background(Color.krupaSurface)
    }

    // MARK: - Тіло кроку

    private var stepScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                if let item = currentItem {
                    switch item {
                    case .grammar(let note):
                        grammarSection(note)
                    case .word(let word, let prompt):
                        wordSection(word, prompt: prompt, item: item)
                    case .sentence(let sentence, let prompt):
                        sentenceSection(sentence, prompt: prompt, item: item)
                    case .exercise(let exercise):
                        exerciseSection(exercise, item: item)
                    case .listening(let listening):
                        listeningSection(listening, item: item)
                    }
                }
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.top, KrupaSpacing.md)
            .padding(.bottom, KrupaSpacing.xxl)
        }
    }

    // MARK: - Граматика

    @ViewBuilder
    private func grammarSection(_ note: GrammarNote) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
                    Text(note.titleEs)
                        .font(.krupaTitle)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Spacer(minLength: 0)
                    LevelBadge(level: note.level)
                }

                Text(note.titleUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextSecondary)

                if !note.patternUk.isEmpty {
                    HStack(alignment: .top, spacing: 4) {
                        Text("Закономірність: ")
                            .font(.krupaSmall)
                            .foregroundStyle(Color.krupaBrand)
                        Text(note.patternUk)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !note.explanationUk.isEmpty {
                    Text(note.explanationUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        if !note.examples.isEmpty {
            KrupaSectionHeader(title: "Приклади", subtitle: nil, systemImage: "text.quote")
        }

        ForEach(note.examples.indices, id: \.self) { exampleIndex in
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    HStack(alignment: .top, spacing: KrupaSpacing.xs) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.examples[exampleIndex].spanish)
                                .font(.krupaSpanishExample)
                                .foregroundStyle(Color.krupaTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(note.examples[exampleIndex].translationUk)
                                .font(.krupaCaption)
                                .foregroundStyle(Color.krupaTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        SpeakerButton(
                            isSpeaking: app.speech.isSpeakingText(note.examples[exampleIndex].spanish),
                            size: 20
                        ) {
                            app.speak(note.examples[exampleIndex].spanish, force: true)
                        }
                    }

                    ExplanationBox(
                        title: "Примітка",
                        text: note.examples[exampleIndex].noteUk,
                        tint: .krupaGold,
                        systemImage: "text.quote"
                    )
                }
            }
        }

        ExplanationBox(
            title: "Типова помилка",
            text: note.commonMistakeUk,
            tint: .krupaError,
            systemImage: "exclamationmark.triangle"
        )

        ExplanationBox(
            title: "Підказка",
            text: note.tipForUkSpeakersUk,
            tint: .krupaSuccess,
            systemImage: "lightbulb"
        )

        PrimaryActionButton(title: "Зрозуміло, далі", systemImage: "arrow.right") {
            advance()
        }
    }

    // MARK: - Слово

    @ViewBuilder
    private func wordSection(_ word: Word, prompt: StudyPromptKind, item: SessionItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(spacing: KrupaSpacing.xs) {
                    ChipView(text: prompt.titleUk, systemImage: "sparkles", tint: .krupaBrand)
                    ChipView(text: word.partOfSpeech.shortTitleUk, systemImage: "textformat", tint: .krupaTextSecondary)
                    Spacer(minLength: 0)
                    LevelBadge(level: word.level)
                }

                switch prompt {
                case .recognize:
                    HStack(alignment: .center, spacing: KrupaSpacing.sm) {
                        Text(word.spanishWithArticle)
                            .font(.krupaSpanishWord)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(word.spanish), size: 24) {
                            app.speak(word.spanish, force: true)
                        }
                    }
                    Text("Що це означає?")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .recall:
                    Text(word.translationUk)
                        .font(.krupaTitle)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Text("Згадайте, як це іспанською")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .listen:
                    VStack(spacing: KrupaSpacing.xs) {
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(word.spanish), size: 38) {
                            app.speak(word.spanish, force: true)
                        }
                        Text("Прослухати")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    Text("Напишіть, що почули")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .buildSentence:
                    Text("Складіть речення зі слів")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }

        if feedback == nil {
            answerArea(item: item)
            pronunciationArea(expected: word.spanish)
        } else {
            wordDetails(word)
        }

        stepFooter(item: item)
    }

    @ViewBuilder
    private func wordDetails(_ word: Word) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .center, spacing: KrupaSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(word.spanishWithArticle)
                            .font(.krupaHeadline)
                            .foregroundStyle(Color.krupaTextPrimary)
                        Text(word.translationUk)
                            .font(.krupaBody)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    Spacer(minLength: 0)
                    SpeakerButton(isSpeaking: app.speech.isSpeakingText(word.spanish), size: 22) {
                        app.speak(word.spanish, force: true)
                    }
                }

                if app.settings.showPronunciationHints, !word.pronunciation.isEmpty {
                    Text("Вимова: \(word.pronunciation)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }

                if app.settings.showIpa, !word.ipaHint.isEmpty {
                    Text(word.ipaHint)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }

                if !word.plural.isEmpty {
                    Text("Множина: \(word.plural)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }

                if !word.exampleEs.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Приклад")
                            .font(.krupaSmall)
                            .foregroundStyle(Color.krupaBrand)
                        Text(word.exampleEs)
                            .font(.krupaSpanishExample)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(word.exampleUk)
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                ExplanationBox(title: "Нотатка", text: word.notesUk, tint: .krupaBrand, systemImage: "info.circle")
                ExplanationBox(title: "Схоже слово", text: word.cognateNoteUk, tint: .krupaGold, systemImage: "sparkles")
            }
        }

        pronunciationArea(expected: word.spanish)
    }

    // MARK: - Речення

    @ViewBuilder
    private func sentenceSection(_ sentence: Sentence, prompt: StudyPromptKind, item: SessionItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(spacing: KrupaSpacing.xs) {
                    ChipView(text: sentence.kind.titleUk, systemImage: "text.bubble", tint: .krupaBrand)
                    ChipView(text: prompt.titleUk, systemImage: "sparkles", tint: .krupaTextSecondary)
                    Spacer(minLength: 0)
                    LevelBadge(level: sentence.level)
                }

                switch prompt {
                case .recognize:
                    HStack(alignment: .center, spacing: KrupaSpacing.sm) {
                        Text(sentence.spanish)
                            .font(.krupaTitle)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(3)
                        Spacer(minLength: 0)
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(sentence.spanish), size: 24) {
                            app.speak(sentence.spanish, force: true)
                        }
                    }
                    Text("Що це означає?")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .recall:
                    Text(sentence.translationUk)
                        .font(.krupaTitle)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Text("Згадайте, як це іспанською")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .listen:
                    VStack(spacing: KrupaSpacing.xs) {
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(sentence.spanish), size: 38) {
                            app.speak(sentence.spanish, force: true)
                        }
                        Text("Прослухати")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    Text("Напишіть, що почули")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)

                case .buildSentence:
                    Text("Складіть речення")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
        }

        if feedback == nil {
            answerArea(item: item)
            pronunciationArea(expected: sentence.spanish)
        } else {
            sentenceDetails(sentence)
        }

        stepFooter(item: item)
    }

    @ViewBuilder
    private func sentenceDetails(_ sentence: Sentence) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(alignment: .top, spacing: KrupaSpacing.xs) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sentence.spanish)
                            .font(.krupaSpanishExample)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(sentence.translationUk)
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    SpeakerButton(isSpeaking: app.speech.isSpeakingText(sentence.spanish), size: 22) {
                        app.speak(sentence.spanish, force: true)
                    }
                }
            }
        }

        ExplanationBox(
            title: "Підказка",
            text: sentence.audioHint,
            tint: .krupaWarning,
            systemImage: "ear"
        )

        pronunciationArea(expected: sentence.spanish)
    }

    // MARK: - Тренування вимови

    @ViewBuilder
    private func pronunciationArea(expected: String) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            SecondaryActionButton(title: "Тренувати вимову", systemImage: "mic", tint: .krupaSuccess) {
                showPronunciation.toggle()
            }

            if showPronunciation {
                KrupaCard {
                    SessionPronunciationSection(expected: expected, onFinish: nil)
                }
            }
        }
    }

    // MARK: - Вправи

    @ViewBuilder
    private func exerciseSection(_ exercise: Exercise, item: SessionItem) -> some View {
        exerciseStimulus(exercise)

        if feedback == nil {
            exerciseInput(exercise, item: item)
        }

        stepFooter(item: item)
    }

    @ViewBuilder
    private func exerciseStimulus(_ exercise: Exercise) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(spacing: KrupaSpacing.xs) {
                    ChipView(text: exercise.kind.titleUk, systemImage: "pencil.and.list.clipboard", tint: .krupaBrand)
                    if !exercise.grammarTag.isEmpty {
                        ChipView(text: exercise.grammarTag, systemImage: "tag", tint: .krupaTextSecondary)
                    }
                    Spacer(minLength: 0)
                    LevelBadge(level: exercise.level)
                }

                if !exercise.promptUk.isEmpty {
                    Text(exercise.promptUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                switch exercise.kind {
                case .translationEsUk:
                    if !exercise.promptEs.isEmpty {
                        HStack(alignment: .top, spacing: KrupaSpacing.xs) {
                            Text(exercise.promptEs)
                                .font(.krupaSpanishExample)
                                .foregroundStyle(Color.krupaTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            SpeakerButton(isSpeaking: app.speech.isSpeakingText(exercise.promptEs), size: 20) {
                                app.speak(exercise.promptEs, force: true)
                            }
                        }
                    }

                case .dictation, .listening:
                    VStack(spacing: KrupaSpacing.xs) {
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(exercise.answerEs), size: 38) {
                            app.speak(exercise.answerEs, force: true)
                        }
                        Text("Прослухати")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    .frame(maxWidth: .infinity)

                case .fillGap:
                    Text(gapText(exercise))
                        .font(.krupaSpanishExample)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                case .multipleChoice, .translationUkEs, .sentenceBuild, .matchPairs, .speaking, .unknown:
                    if !exercise.promptEs.isEmpty {
                        Text(exercise.promptEs)
                            .font(.krupaSpanishExample)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func exerciseInput(_ exercise: Exercise, item: SessionItem) -> some View {
        switch exercise.kind {
        case .multipleChoice, .translationEsUk:
            VStack(spacing: KrupaSpacing.xs) {
                ForEach(choices, id: \.self) { choice in
                    AnswerOptionRow(
                        text: choice,
                        state: optionState(for: choice, item: item),
                        subtitle: nil,
                        action: { answer = choice }
                    )
                }

                PrimaryActionButton(
                    title: "Перевірити",
                    systemImage: "checkmark.circle",
                    isEnabled: canCheck(item: item)
                ) {
                    checkAnswer()
                }
                revealButton(for: item)
            }

        case .sentenceBuild:
            tokenArea(item: item)

        case .matchPairs:
            matchPairsArea(exercise, item: item)

        case .speaking:
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                SessionPronunciationSection(expected: exercise.answerEs) { result in
                    applyPronunciation(result)
                }
                revealButton(for: item)
            }

        case .translationUkEs, .dictation, .fillGap, .listening, .unknown:
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaTextField(
                    placeholder: inputPlaceholder(for: item),
                    text: $answer,
                    onSubmit: {
                        if canCheck(item: item) {
                            checkAnswer()
                        }
                    }
                )

                PrimaryActionButton(
                    title: "Перевірити",
                    systemImage: "checkmark.circle",
                    isEnabled: canCheck(item: item)
                ) {
                    checkAnswer()
                }
                revealButton(for: item)
            }
        }
    }

    /// Токени для вправи «склади речення».
    @ViewBuilder
    private func tokenArea(item: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            Text("Натискайте слова у правильному порядку:")
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)

            KrupaCard(background: Color.krupaSurfaceAlt) {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    if selectedTokens.isEmpty {
                        Text("Тут з'явиться ваше речення")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    } else {
                        Text(selectedTokens.map { buildTokens[$0] }.joined(separator: " "))
                            .font(.krupaSpanishExample)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Очистити") {
                            selectedTokens = []
                        }
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaBrand)
                    }
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: KrupaSpacing.xs)],
                alignment: .leading,
                spacing: KrupaSpacing.xs
            ) {
                ForEach(buildTokens.indices, id: \.self) { tokenIndex in
                    Button {
                        toggleToken(tokenIndex)
                    } label: {
                        Text(buildTokens[tokenIndex])
                            .font(.krupaCallout)
                            .foregroundStyle(selectedTokens.contains(tokenIndex) ? Color.white : Color.krupaBrand)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, KrupaSpacing.xs)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity)
                            .background(selectedTokens.contains(tokenIndex) ? Color.krupaBrand : Color.krupaBrand.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            PrimaryActionButton(
                title: "Перевірити",
                systemImage: "checkmark.circle",
                isEnabled: canCheck(item: item)
            ) {
                checkAnswer()
            }
            revealButton(for: item)
        }
    }

    /// Зіставлення пар: ліва колонка — іспанською, права — українською.
    @ViewBuilder
    private func matchPairsArea(_ exercise: Exercise, item: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            HStack(alignment: .top, spacing: KrupaSpacing.sm) {
                VStack(spacing: KrupaSpacing.xs) {
                    ForEach(matchPairs) { pair in
                        AnswerOptionRow(
                            text: pair.spanish,
                            state: pairState(for: pair),
                            subtitle: nil,
                            action: { selectedPairId = pair.id }
                        )
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: KrupaSpacing.xs) {
                    ForEach(matchOptions, id: \.self) { option in
                        AnswerOptionRow(
                            text: option,
                            state: optionPairState(for: option),
                            subtitle: nil,
                            action: { matchRight(option, exercise: exercise, item: item) }
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }

            Text("Оберіть слово ліворуч, потім його переклад праворуч.")
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
        }
    }

    @ViewBuilder
    private func revealButton(for item: SessionItem) -> some View {
        if showsReveal(for: item) {
            SecondaryActionButton(title: "Показати відповідь", systemImage: "eye", tint: .krupaTextSecondary) {
                revealAnswer()
            }
        }
    }

    // MARK: - Аудіювання

    @ViewBuilder
    private func listeningSection(_ listening: ListeningItem, item: SessionItem) -> some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: listening.titleUk, subtitle: listening.titleEs, systemImage: "headphones")

                Text(listening.kind.titleUk)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)

                PrimaryActionButton(title: "Прослухати повністю", systemImage: "play.fill") {
                    app.speech.speakDialogue(listening.lines.map(\.spanish))
                }

                HStack(spacing: KrupaSpacing.xs) {
                    SecondaryActionButton(
                        title: showListeningText ? "Сховати текст" : "Показати текст",
                        systemImage: "text.alignleft"
                    ) {
                        showListeningText.toggle()
                        if showListeningText { usedHint = true }
                    }

                    SecondaryActionButton(
                        title: showListeningTranslation ? "Сховати переклад" : "Показати переклад",
                        systemImage: "character.book.closed"
                    ) {
                        showListeningTranslation.toggle()
                        if showListeningTranslation { usedHint = true }
                    }
                }

                if showListeningText {
                    ForEach(listening.lines.indices, id: \.self) { lineIndex in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(listening.lines[lineIndex].speaker)
                                    .font(.krupaSmall)
                                    .foregroundStyle(Color.krupaBrand)

                                Spacer(minLength: 0)

                                Button("Повторити репліку") {
                                    app.speak(listening.lines[lineIndex].spanish, force: true)
                                }
                                .font(.krupaSmall)
                                .foregroundStyle(Color.krupaBrand)
                            }

                            Text(listening.lines[lineIndex].spanish)
                                .font(.krupaSpanishExample)
                                .foregroundStyle(Color.krupaTextPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            if showListeningTranslation {
                                Text(listening.lines[lineIndex].translationUk)
                                    .font(.krupaCaption)
                                    .foregroundStyle(Color.krupaTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }

        if app.settings.listeningHintsEnabled, !listening.keyWords.isEmpty {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    KrupaSectionHeader(title: "Ключові слова", subtitle: nil, systemImage: "key")

                    ForEach(listening.keyWords.indices, id: \.self) { wordIndex in
                        HStack(alignment: .top, spacing: 6) {
                            Text(listening.keyWords[wordIndex].spanish)
                                .font(.krupaSpanishExample)
                                .foregroundStyle(Color.krupaTextPrimary)
                            Text("— \(listening.keyWords[wordIndex].translationUk)")
                                .font(.krupaCaption)
                                .foregroundStyle(Color.krupaTextSecondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }

        listeningQuestions(listening, item: item)
    }

    @ViewBuilder
    private func listeningQuestions(_ listening: ListeningItem, item: SessionItem) -> some View {
        if listening.comprehensionQuestions.isEmpty {
            if feedback == nil {
                PrimaryActionButton(title: "Завершити слухання", systemImage: "checkmark.circle") {
                    finishListening(listening, item: item)
                }
            }
            stepFooter(item: item)
        } else if let question = currentQuestion(in: listening) {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(
                        title: "Питання \(questionIndex + 1) з \(listening.comprehensionQuestions.count)",
                        subtitle: nil,
                        systemImage: "questionmark.circle"
                    )

                    Text(question.questionUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(question.options.indices, id: \.self) { optionIndex in
                        AnswerOptionRow(
                            text: question.options[optionIndex],
                            state: listeningOptionState(question.options[optionIndex], question: question),
                            subtitle: nil,
                            action: {
                                selectListeningOption(question.options[optionIndex], question: question)
                            }
                        )
                    }

                    if answeredCurrentQuestion {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(
                                currentQuestionWasCorrect
                                    ? "✓ Правильно."
                                    : "✕ Правильна відповідь: \(question.correctOption ?? "")"
                            )
                            .font(.krupaCallout)
                            .foregroundStyle(currentQuestionWasCorrect ? Color.krupaSuccess : Color.krupaError)

                            if !question.explanationUk.isEmpty {
                                Text(question.explanationUk)
                                    .font(.krupaCaption)
                                    .foregroundStyle(Color.krupaTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(KrupaSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((currentQuestionWasCorrect ? Color.krupaSuccess : Color.krupaError).opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

                        PrimaryActionButton(title: "Далі", systemImage: "arrow.right") {
                            nextQuestion(listening, item: item)
                        }
                    }
                }
            }
        } else {
            stepFooter(item: item)
        }
    }

    // MARK: - Спільний підсумок кроку

    @ViewBuilder
    private func stepFooter(item: SessionItem) -> some View {
        if let feedback {
            SessionFeedbackCard(
                feedback: feedback,
                userAnswer: answer,
                showsUserAnswer: showsUserAnswer(for: item)
            )

            if item.isSrsGraded, !previews.isEmpty {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    KrupaSectionHeader(
                        title: isAutoGradedStep ? "Оцінку виставлено автоматично" : "Наскільки добре ви згадали?",
                        subtitle: isAutoGradedStep ? "За потреби уточніть оцінку" : nil,
                        systemImage: "star"
                    )

                    GradeButtonsRow(previews: previews) { grade in
                        if isAutoGradedStep {
                            refine(grade: grade, item: item)
                        } else {
                            finish(grade: grade, item: item)
                        }
                    }

                    if isAutoGradedStep {
                        PrimaryActionButton(title: "Далі", systemImage: "arrow.right") {
                            advance()
                        }
                    }
                }
                .padding(.top, KrupaSpacing.xs)
            } else {
                PrimaryActionButton(title: "Далі", systemImage: "arrow.right") {
                    advance()
                }
            }
        }
    }

    // MARK: - Спільна зона відповіді

    @ViewBuilder
    private func answerArea(item: SessionItem) -> some View {
        switch item {
        case .word(_, let prompt):
            if prompt == .recognize {
                choiceArea(item: item)
            } else if prompt == .buildSentence {
                tokenArea(item: item)
            } else {
                textArea(item: item)
            }

        case .sentence(_, let prompt):
            if prompt == .recognize {
                choiceArea(item: item)
            } else if prompt == .buildSentence {
                tokenArea(item: item)
            } else {
                textArea(item: item)
            }

        case .exercise(let exercise):
            exerciseInput(exercise, item: item)

        case .grammar, .listening:
            EmptyView()
        }
    }

    @ViewBuilder
    private func choiceArea(item: SessionItem) -> some View {
        VStack(spacing: KrupaSpacing.xs) {
            ForEach(choices, id: \.self) { choice in
                AnswerOptionRow(
                    text: choice,
                    state: optionState(for: choice, item: item),
                    subtitle: nil,
                    action: { answer = choice }
                )
            }

            PrimaryActionButton(
                title: "Перевірити",
                systemImage: "checkmark.circle",
                isEnabled: canCheck(item: item)
            ) {
                checkAnswer()
            }

            revealButton(for: item)
        }
    }

    @ViewBuilder
    private func textArea(item: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            KrupaTextField(
                placeholder: inputPlaceholder(for: item),
                text: $answer,
                onSubmit: {
                    if canCheck(item: item) {
                        checkAnswer()
                    }
                }
            )

            PrimaryActionButton(
                title: "Перевірити",
                systemImage: "checkmark.circle",
                isEnabled: canCheck(item: item)
            ) {
                checkAnswer()
            }

            revealButton(for: item)
        }
    }

    // MARK: - Похідні дані кроку

    private var items: [SessionItem] { plan?.allItems ?? [] }

    private var total: Int { items.count }

    private var currentItem: SessionItem? {
        items.indices.contains(index) ? items[index] : nil
    }

    private var currentBlock: SessionBlock? {
        guard let plan, let item = currentItem else { return nil }
        return plan.block(for: item)
    }

    private var previews: [GradePreview] {
        guard let card else { return [] }
        return SrsEngine.previews(for: card)
    }

    private var minutesSpent: Int {
        let seconds = Date().timeIntervalSince(progress.startedAt)
        return max(1, Int((seconds / 60).rounded()))
    }

    private var trimmedAnswer: String {
        answer.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var answeredCurrentQuestion: Bool {
        questionResults.count > questionIndex
    }

    private var currentQuestionWasCorrect: Bool {
        questionResults.indices.contains(questionIndex) ? questionResults[questionIndex] : false
    }

    private func currentQuestion(in listening: ListeningItem) -> ComprehensionQuestion? {
        guard listening.comprehensionQuestions.indices.contains(questionIndex) else { return nil }
        return listening.comprehensionQuestions[questionIndex]
    }

    // MARK: - Дії кроку

    private func loadPlanIfNeeded() {
        guard plan == nil else { return }
        let newPlan = app.makePlan(topicId: topicId)
        plan = newPlan
        progress = .start(totalItems: newPlan.itemCount)
        startedAt = Date()
        prepareStep()
    }

    private func restart() {
        app.speech.stop()
        let newPlan = app.makePlan(topicId: topicId)
        index = 0
        showSummary = false
        plan = newPlan
        progress = .start(totalItems: newPlan.itemCount)
        startedAt = Date()
        prepareStep()
    }

    /// Скидає стан кроку й готує його дані (варіанти, токени, пари, озвучення).
    private func prepareStep() {
        resetStep()

        guard let item = currentItem else { return }

        if item.isSrsGraded {
            card = app.progress.cardOrCreate(
                itemId: item.contentId,
                itemType: item.itemType,
                level: item.level,
                topicId: item.topicId,
                grammarTags: item.grammarTags
            )
        }

        switch item {
        case .word(let word, let prompt):
            switch prompt {
            case .recognize:
                choices = makeWordChoices(for: word)
            case .listen:
                app.speak(word.spanish, force: true)
            case .buildSentence:
                buildTokens = tokenize(word.spanish)
            case .recall:
                break
            }

        case .sentence(let sentence, let prompt):
            switch prompt {
            case .recognize:
                choices = makeSentenceChoices(for: sentence)
            case .listen:
                app.speak(sentence.spanish, force: true)
            case .buildSentence:
                buildTokens = tokenize(sentence.spanish)
            case .recall:
                break
            }

        case .exercise(let exercise):
            prepareExercise(exercise)

        case .grammar, .listening:
            break
        }
    }

    private func resetStep() {
        answer = ""
        feedback = nil
        usedHint = false
        appliedGrade = nil
        isAutoGradedStep = false
        choices = []
        buildTokens = []
        selectedTokens = []
        matchPairs = []
        matchOptions = []
        matchedPairIds = []
        selectedPairId = nil
        pairMistakes = 0
        card = nil
        showPronunciation = false
        showListeningText = false
        showListeningTranslation = false
        questionIndex = 0
        questionResults = []
        startedAt = Date()
    }

    private func prepareExercise(_ exercise: Exercise) {
        switch exercise.kind {
        case .multipleChoice, .translationEsUk:
            choices = exercise.choices(shuffled: true)

        case .sentenceBuild:
            buildTokens = exercise.buildTokens

        case .matchPairs:
            let pairs = makeMatchPairs(exercise)
            matchPairs = pairs
            matchOptions = (pairs.map(\.ukrainian) + exercise.distractors).shuffled()

        case .dictation, .listening:
            app.speak(exercise.answerEs, force: true)

        case .translationUkEs, .fillGap, .speaking, .unknown:
            break
        }
    }

    private func checkAnswer() {
        guard feedback == nil, let item = currentItem else { return }

        app.speech.stop()

        if case .exercise(let exercise) = item, exercise.kind == .sentenceBuild {
            answer = selectedTokens.map { buildTokens[$0] }.joined(separator: " ")
        }

        feedback = SessionChecker.check(item: item, userAnswer: answer)

        guard item.isSrsGraded, isAutoGraded(item) else { return }
        let auto = autoGrade(for: item) ?? .again
        record(item: item, grade: auto, countsForProgress: true)
        appliedGrade = auto
        isAutoGradedStep = true
    }

    private func revealAnswer() {
        guard feedback == nil, let item = currentItem else { return }
        usedHint = true
        feedback = SessionAnswerFeedback(
            isCorrect: false,
            messageUk: "Правильна відповідь:",
            correctAnswer: correctAnswerText(for: item),
            explanationUk: explanationText(for: item)
        )
    }

    private func finish(grade: Grade, item: SessionItem) {
        guard feedback != nil else { return }
        record(item: item, grade: grade, countsForProgress: true)
        advance()
    }

    private func refine(grade: Grade, item: SessionItem) {
        guard isAutoGradedStep, appliedGrade != grade else { return }
        record(item: item, grade: grade, countsForProgress: false)
        appliedGrade = grade
    }

    private func record(item: SessionItem, grade: Grade, countsForProgress: Bool) {
        let responseMs = Int(Date().timeIntervalSince(startedAt) * 1000)
        app.recordAnswer(
            item: item,
            grade: grade,
            userAnswer: answer,
            usedHint: usedHint,
            responseMs: responseMs
        )

        guard countsForProgress else { return }
        if grade.isCorrect {
            progress.correct += 1
        } else {
            progress.wrong += 1
        }
    }

    private func advance() {
        app.speech.stop()
        let next = index + 1
        progress.currentIndex = min(next, total)

        if next >= total {
            resetStep()
            index = next
            showSummary = true
        } else {
            index = next
            prepareStep()
        }
    }

    private func requestExit() {
        if index > 0 && !showSummary {
            showExitDialog = true
        } else {
            dismiss()
        }
    }

    private func toggleToken(_ tokenIndex: Int) {
        if let position = selectedTokens.firstIndex(of: tokenIndex) {
            selectedTokens.remove(at: position)
        } else {
            selectedTokens.append(tokenIndex)
        }
    }

    private func applyPronunciation(_ result: PronunciationResult) {
        guard feedback == nil else { return }
        app.markSpeakingAttempt()
        answer = result.heardText
        feedback = SessionAnswerFeedback(
            isCorrect: result.isAcceptable,
            messageUk: result.summaryUk,
            correctAnswer: result.expectedText,
            explanationUk: pronunciationAdvice(result)
        )
    }

    private func pronunciationAdvice(_ result: PronunciationResult) -> String {
        result.issues
            .map { "\($0.type.titleUk): \($0.type.adviceUk)" }
            .joined(separator: "\n")
    }

    // MARK: - Аудіювання: дії

    private func selectListeningOption(_ option: String, question: ComprehensionQuestion) {
        guard !answeredCurrentQuestion else { return }
        answer = option
        let result = AnswerCheck.check(option, expected: question.correctOption ?? "")
        questionResults.append(result.isCorrect)
    }

    private func nextQuestion(_ listening: ListeningItem, item: SessionItem) {
        let next = questionIndex + 1
        questionIndex = next
        if next >= listening.comprehensionQuestions.count {
            finishListening(listening, item: item)
        } else {
            answer = ""
        }
    }

    private func finishListening(_ listening: ListeningItem, item: SessionItem) {
        guard feedback == nil else { return }
        app.speech.stop()
        app.markListeningCompleted()

        let allCorrect = questionResults.allSatisfy { $0 }
        feedback = SessionAnswerFeedback(
            isCorrect: allCorrect,
            messageUk: allCorrect ? "Правильно!" : "Не зовсім",
            correctAnswer: listening.lines.first?.spanish ?? "",
            explanationUk: listening.lines.first?.translationUk ?? ""
        )
    }

    private func listeningOptionState(_ option: String, question: ComprehensionQuestion) -> AnswerOptionState {
        guard answeredCurrentQuestion else {
            return answer == option ? .selected : .idle
        }
        if option == question.correctOption {
            return .correct
        }
        if option == answer {
            return .wrong
        }
        return .idle
    }

    // MARK: - Пари

    private func pairState(for pair: SessionMatchPair) -> AnswerOptionState {
        if matchedPairIds.contains(pair.id) { return .correct }
        return selectedPairId == pair.id ? .selected : .idle
    }

    private func optionPairState(for option: String) -> AnswerOptionState {
        matchedPairIds.contains(matchedPairId(for: option) ?? -1) ? .correct : .idle
    }

    private func matchedPairId(for option: String) -> Int? {
        matchPairs.first { $0.ukrainian == option && matchedPairIds.contains($0.id) }?.id
    }

    private func matchRight(_ option: String, exercise: Exercise, item: SessionItem) {
        guard let leftId = selectedPairId, let pair = matchPairs.first(where: { $0.id == leftId }) else { return }

        if pair.ukrainian == option {
            matchedPairIds.insert(leftId)
            selectedPairId = nil
            if matchedPairIds.count == matchPairs.count {
                usedHint = pairMistakes > 0
                answer = exercise.answerEs
                feedback = SessionChecker.check(item: item, userAnswer: exercise.answerEs)
            }
        } else {
            pairMistakes += 1
            selectedPairId = nil
        }
    }

    private func makeMatchPairs(_ exercise: Exercise) -> [SessionMatchPair] {
        var pairs: [SessionMatchPair] = []

        if exercise.answerEs.contains("—") || exercise.answerEs.contains(";") {
            let chunks = exercise.answerEs.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            for chunk in chunks {
                let parts = chunk.components(separatedBy: "—")
                guard parts.count >= 2 else { continue }
                let spanish = parts[0].trimmingCharacters(in: .whitespaces)
                let ukrainian = parts[1...].joined(separator: "—").trimmingCharacters(in: .whitespaces)
                guard !spanish.isEmpty, !ukrainian.isEmpty else { continue }
                pairs.append(SessionMatchPair(id: pairs.count, spanish: spanish, ukrainian: ukrainian))
            }
        }

        if pairs.count < 2 {
            let ukrainianItems = exercise.answerUk
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if exercise.tokens.count >= 2, exercise.tokens.count == ukrainianItems.count {
                pairs = zip(exercise.tokens, ukrainianItems).enumerated().map { item in
                    SessionMatchPair(id: item.offset, spanish: item.element.0, ukrainian: item.element.1)
                }
            }
        }

        if pairs.count < 2, !exercise.relatedWordIds.isEmpty {
            let words = exercise.relatedWordIds.compactMap { app.content.word($0) }
            if words.count >= 2 {
                pairs = words.enumerated().map { item in
                    SessionMatchPair(id: item.offset, spanish: item.element.spanishWithArticle, ukrainian: item.element.translationUk)
                }
            }
        }

        if pairs.isEmpty {
            pairs = [SessionMatchPair(id: 0, spanish: exercise.answerEs, ukrainian: exercise.answerUk)]
        }

        return pairs
    }

    // MARK: - Варіанти та тексти

    private func makeWordChoices(for word: Word) -> [String] {
        let pool = app.content.words(level: word.level)
            .filter { $0.id != word.id && $0.translationUk != word.translationUk }
            .map(\.translationUk)
        let distractors = Array(Array(Set(pool)).shuffled().prefix(3))
        return ([word.translationUk] + distractors).shuffled()
    }

    private func makeSentenceChoices(for sentence: Sentence) -> [String] {
        let pool = app.content.sentences(level: sentence.level)
            .filter { $0.id != sentence.id && $0.translationUk != sentence.translationUk }
            .map(\.translationUk)
        let distractors = Array(Array(Set(pool)).shuffled().prefix(3))
        return ([sentence.translationUk] + distractors).shuffled()
    }

    private func tokenize(_ spanish: String) -> [String] {
        spanish
            .replacingOccurrences(of: "¿", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "¡", with: "")
            .replacingOccurrences(of: "!", with: "")
            .split(separator: " ")
            .map(String.init)
    }

    private func gapText(_ exercise: Exercise) -> String {
        let target = exercise.gapAnswer.isEmpty ? exercise.answerEs : exercise.gapAnswer
        guard !exercise.gapText.isEmpty else {
            return exercise.promptEs.isEmpty ? exercise.promptUk : exercise.promptEs
        }
        guard !target.isEmpty, exercise.gapText.contains(target) else { return exercise.gapText }
        return exercise.gapText.replacingOccurrences(of: target, with: "____")
    }

    private func inputPlaceholder(for item: SessionItem) -> String {
        switch item {
        case .word:
            return "Іспанське слово"
        case .sentence:
            return "Речення іспанською"
        case .grammar:
            return "Ваша відповідь"
        case .listening:
            return "Ваша відповідь"
        case .exercise(let exercise):
            switch exercise.kind {
            case .fillGap:
                return "Пропущене слово"
            case .dictation, .listening:
                return "Запишіть те, що почули"
            case .translationUkEs:
                return "Переклад іспанською"
            case .translationEsUk:
                return "Переклад українською"
            default:
                return "Ваша відповідь"
            }
        }
    }

    private func correctAnswerText(for item: SessionItem) -> String {
        switch item {
        case .word(let word, let prompt):
            return prompt == .recognize ? word.translationUk : word.spanish
        case .sentence(let sentence, _):
            return sentence.spanish
        case .exercise(let exercise):
            switch exercise.kind {
            case .multipleChoice, .translationEsUk:
                return exercise.answerUk.isEmpty ? exercise.answerEs : exercise.answerUk
            case .fillGap:
                return exercise.gapAnswer.isEmpty ? exercise.answerEs : exercise.gapAnswer
            default:
                return exercise.answerEs
            }
        case .grammar(let note):
            return note.titleUk
        case .listening(let listening):
            return listening.lines.first?.spanish ?? ""
        }
    }

    private func explanationText(for item: SessionItem) -> String {
        switch item {
        case .word(let word, _):
            return word.notesUk.isEmpty ? word.exampleEs : word.notesUk
        case .sentence(let sentence, _):
            return sentence.audioHint
        case .exercise(let exercise):
            return exercise.explanationUk
        case .grammar(let note):
            return note.explanationUk
        case .listening(let listening):
            return listening.lines.first?.translationUk ?? ""
        }
    }

    private func optionState(for choice: String, item: SessionItem) -> AnswerOptionState {
        guard let feedback else {
            return answer == choice ? .selected : .idle
        }
        if feedback.isCorrect {
            return choice == answer ? .correct : .idle
        }
        if choice == correctAnswerText(for: item) {
            return .correct
        }
        if choice == answer {
            return .wrong
        }
        return .idle
    }

    private func showsUserAnswer(for item: SessionItem) -> Bool {
        switch item {
        case .word(_, let prompt):
            return prompt != .recognize
        case .sentence(_, let prompt):
            return prompt != .recognize
        case .exercise(let exercise):
            switch exercise.kind {
            case .multipleChoice, .translationEsUk, .matchPairs, .speaking:
                return false
            default:
                return true
            }
        case .grammar, .listening:
            return false
        }
    }

    private func showsReveal(for item: SessionItem) -> Bool {
        switch item {
        case .grammar, .listening:
            return false
        case .exercise(let exercise):
            return exercise.kind != .matchPairs
        default:
            return true
        }
    }

    private func isAutoGraded(_ item: SessionItem) -> Bool {
        guard case .exercise(let exercise) = item else { return false }
        return exercise.kind == .multipleChoice || exercise.kind == .translationEsUk
    }

    private func autoGrade(for item: SessionItem) -> Grade? {
        guard case .exercise(let exercise) = item else { return nil }
        switch exercise.kind {
        case .multipleChoice, .translationEsUk:
            return AnswerCheck.check(answer, anyOf: [exercise.answerUk, exercise.answerEs]).suggestedGrade
        default:
            return nil
        }
    }

    private func canCheck(item: SessionItem) -> Bool {
        switch item {
        case .word(_, let prompt):
            return prompt == .recognize ? !answer.isEmpty : !trimmedAnswer.isEmpty
        case .sentence(_, let prompt):
            switch prompt {
            case .recognize:
                return !answer.isEmpty
            case .buildSentence:
                return !selectedTokens.isEmpty
            default:
                return !trimmedAnswer.isEmpty
            }
        case .exercise(let exercise):
            switch exercise.kind {
            case .multipleChoice, .translationEsUk:
                return !answer.isEmpty
            case .sentenceBuild:
                return !selectedTokens.isEmpty
            case .matchPairs, .speaking:
                return false
            default:
                return !trimmedAnswer.isEmpty
            }
        case .grammar, .listening:
            return false
        }
    }
}

// MARK: - Пара для зіставлення

/// Пара «іспанське слово — український переклад» для вправи `matchPairs`.
private struct SessionMatchPair: Identifiable, Hashable {
    let id: Int
    let spanish: String
    let ukrainian: String
}

// MARK: - Картка відгуку

/// Зелена або червона картка з результатом перевірки кроку.
private struct SessionFeedbackCard: View {
    let feedback: SessionAnswerFeedback
    let userAnswer: String
    let showsUserAnswer: Bool

    private var tint: Color {
        feedback.isCorrect ? .krupaSuccess : .krupaError
    }

    var body: some View {
        KrupaCard(background: tint.opacity(0.10)) {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                HStack(spacing: 6) {
                    Image(systemName: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(feedback.isCorrect ? "Правильно" : "Не зовсім")
                        .font(.krupaHeadline)
                }
                .foregroundStyle(tint)

                if !feedback.messageUk.isEmpty {
                    Text(feedback.messageUk)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsUserAnswer, !userAnswer.isEmpty {
                    Text("Ви відповіли: \(userAnswer)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !feedback.isCorrect, !feedback.correctAnswer.isEmpty {
                    Text("Правильно: \(feedback.correctAnswer)")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ExplanationBox(
                    title: "Пояснення",
                    text: feedback.explanationUk,
                    tint: .krupaBrand,
                    systemImage: "info.circle"
                )
            }
        }
    }
}

// MARK: - Тренування вимови

/// Мікрофон, розпізнавання та оцінка вимови (відповідник android `AudioRow`).
private struct SessionPronunciationSection: View {
    let expected: String
    let onFinish: ((PronunciationResult) -> Void)?

    @EnvironmentObject private var app: AppState
    @State private var result: PronunciationResult?
    @State private var errorMessage: String?
    @State private var isRequesting: Bool = false

    init(expected: String, onFinish: ((PronunciationResult) -> Void)? = nil) {
        self.expected = expected
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
            HStack(alignment: .top, spacing: KrupaSpacing.sm) {
                Text(expected)
                    .font(.krupaSpanishExample)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                SpeakerButton(isSpeaking: app.speech.isSpeakingText(expected), size: 22) {
                    app.speak(expected, force: true)
                }
            }

            if app.recognition.isRecording {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    Text("Слухаю…")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)

                    KrupaProgressBar(value: app.recognition.audioLevel, tint: .krupaSuccess, height: 6)

                    PrimaryActionButton(title: "Стоп", systemImage: "stop.fill") {
                        finishRecording()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    PrimaryActionButton(
                        title: "Говорити",
                        systemImage: "mic.fill",
                        isEnabled: !isRequesting
                    ) {
                        startRecording()
                    }

                    Text("Скажіть це вголос — застосунок перевірить вимову.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }

            if let result {
                resultView(result)
            }

            if let message = errorMessage ?? recognitionFailureMessage {
                ErrorBanner(message: message, retryTitle: nil, onRetry: nil)
            }
        }
    }

    @ViewBuilder
    private func resultView(_ result: PronunciationResult) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
                Text("\(result.score)")
                    .font(.krupaTitle)
                    .foregroundStyle(result.isGood ? Color.krupaSuccess : (result.isAcceptable ? Color.krupaWarning : Color.krupaError))
                Text(result.summaryUk)
                    .font(.krupaCallout)
                    .foregroundStyle(Color.krupaTextPrimary)
            }

            if !result.heardText.isEmpty {
                Text("Почуто: \(result.heardText)")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(result.issues.indices, id: \.self) { issueIndex in
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.issues[issueIndex].type.titleUk)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaBrand)
                    Text(result.issues[issueIndex].type.adviceUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(KrupaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaSurfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }

    private var recognitionFailureMessage: String? {
        if case .failed(let message) = app.recognition.state {
            return message
        }
        return nil
    }

    private func startRecording() {
        guard !isRequesting else { return }
        isRequesting = true
        errorMessage = nil

        Task { @MainActor in
            let granted = await app.recognition.requestAuthorization()
            isRequesting = false
            guard granted else { return }

            do {
                try app.recognition.start()
            } catch {
                errorMessage = "Не вдалося почати запис. Перевірте доступ до мікрофона."
            }
        }
    }

    private func finishRecording() {
        let heard = app.recognition.finishRecording()
        let scored = PronunciationScorer.score(expected: expected, heard: heard)
        result = scored
        onFinish?(scored)
    }
}

// MARK: - Підсумок заняття

/// Екран підсумку після останнього кроку.
private struct SessionSummaryView: View {
    let title: String
    let subtitle: String?
    let progress: SessionProgress
    let minutes: Int
    let onAgain: () -> Void
    let onFinish: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: KrupaSpacing.sm),
        GridItem(.flexible(), spacing: KrupaSpacing.sm)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                KrupaCard {
                    VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                        KrupaSectionHeader(title: title, subtitle: subtitle, systemImage: "checkmark.seal.fill")

                        Text("Наступні повторення вже заплановано. Найкращий результат — заходити щодня хоча б на кілька хвилин.")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                LazyVGrid(columns: columns, spacing: KrupaSpacing.sm) {
                    StatTile(
                        title: "Правильно",
                        value: "\(progress.correct)",
                        systemImage: "checkmark.circle",
                        tint: .krupaSuccess
                    )
                    StatTile(
                        title: "Помилки",
                        value: "\(progress.wrong)",
                        systemImage: "xmark.circle",
                        tint: .krupaError
                    )
                    StatTile(
                        title: "Точність",
                        value: "\(Int(progress.accuracy.rounded())) %",
                        systemImage: "target",
                        tint: .krupaBrand
                    )
                    StatTile(
                        title: "Хвилин",
                        value: "\(minutes)",
                        systemImage: "clock",
                        tint: .krupaGold
                    )
                }

                PrimaryActionButton(title: "Ще заняття", systemImage: "arrow.clockwise", action: onAgain)
                SecondaryActionButton(title: "Завершити", systemImage: "checkmark", tint: .krupaTextSecondary, action: onFinish)
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.vertical, KrupaSpacing.md)
        }
    }
}
