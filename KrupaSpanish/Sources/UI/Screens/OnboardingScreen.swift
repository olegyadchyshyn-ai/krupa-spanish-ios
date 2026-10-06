import SwiftUI

/// Онбординг нового користувача: вітання → рівень → мета → час → мінітест → результат.
///
/// Усі вибори зберігаються одним записом у профіль під час завершення
/// (або одразу, якщо користувач натиснув «Пропустити»).
struct OnboardingScreen: View {
    @EnvironmentObject private var app: AppState

    /// Поточний крок: 0 — вітання, 1 — рівень, 2 — мета, 3 — час, 4 — тест і результат.
    @State private var step: Int = 0

    // Вибір користувача
    @State private var level: Level = .a0
    @State private var goal: LearningGoal = .communication
    @State private var dailyMinutes: Int = 15
    @State private var name: String = ""

    // Мінітест
    @State private var questions: [OnboardingTestQuestion] = []
    @State private var questionIndex: Int = 0
    @State private var correctCount: Int = 0
    @State private var selectedOption: String?
    @State private var isAnswered: Bool = false

    /// Варіанти щоденної цілі в хвилинах.
    private let minuteOptions: [Int] = [5, 10, 15, 20, 30]
    /// Скільки питань у мінітесті (5…8).
    private let testSize: Int = 8
    /// Скільки кроків показує індикатор.
    private let totalSteps: Int = 5

    private static let minuteColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                header
                stepIndicator
                content
            }
            .padding(KrupaSpacing.screenPadding)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .onAppear(perform: prepareQuestionsIfNeeded)
    }

    // MARK: - Каркас

    /// Шапка з назвою застосунку та кнопкою «Пропустити».
    private var header: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("KRUPA_Spanish")
                    .font(.krupaTitle)
                    .foregroundStyle(Color.white)
                Spacer(minLength: 0)
                Button(action: skipOnboarding) {
                    Text("Пропустити")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.white.opacity(0.92))
                }
                .buttonStyle(.plain)
            }
            Text("Іспанська мова Іспанії — з нуля до впевненого спілкування.")
                .font(.krupaCaption)
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KrupaSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaHeaderGradient)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }

    /// Індикатор прогресу онбордингу.
    private var stepIndicator: some View {
        HStack(spacing: KrupaSpacing.xxs) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.krupaBrand : Color.krupaDivider)
                    .frame(height: 4)
            }
        }
    }

    /// Вміст поточного кроку.
    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:
            welcomeStep
        case 1:
            levelStep
        case 2:
            goalStep
        case 3:
            timeStep
        default:
            testStep
        }
    }

    // MARK: - Крок 1: вітання

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(
                        title: "Вітаю!",
                        subtitle: "Іспанська для україномовних",
                        systemImage: "hand.wave"
                    )
                    Text("Застосунок сам складе заняття з потрібних частин: повторення, нові слова, граматика, аудіювання, говоріння.")
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Без реєстрації, без пароля й без акаунта. Увесь прогрес зберігається лише на цьому пристрої — і його можна перенести файлом JSON.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                    Text("Як до вас звертатися? (необов'язково)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    KrupaTextField(placeholder: "Ім'я", text: $name) {
                        next()
                    }
                }
            }

            navigationRow(nextTitle: "Далі")
        }
    }

    // MARK: - Крок 2: рівень

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Ваш стартовий рівень",
                    subtitle: "Рівень можна змінити вручну в будь-який момент у Налаштуваннях.",
                    systemImage: "chart.bar"
                )
                ForEach(Level.allCases) { item in
                    OnboardingSelectableCard(
                        title: item.title,
                        subtitle: item.subtitleUk,
                        systemImage: iconName(for: item),
                        isSelected: level == item
                    ) {
                        level = item
                    }
                }
            }
            navigationRow(nextTitle: "Далі")
        }
    }

    // MARK: - Крок 3: мета

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Навіщо вам іспанська?",
                    subtitle: "Ціль впливає на теми, які застосунок пропонуватиме частіше.",
                    systemImage: "target"
                )
                ForEach(LearningGoal.allCases) { item in
                    OnboardingSelectableCard(
                        title: item.titleUk,
                        subtitle: item.descriptionUk,
                        systemImage: item.systemImageName,
                        isSelected: goal == item
                    ) {
                        goal = item
                    }
                }
            }
            navigationRow(nextTitle: "Далі")
        }
    }

    // MARK: - Крок 4: час на день

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(
                        title: "Скільки часу на день?",
                        subtitle: "Мета: \(dailyMinutes) хв на день",
                        systemImage: "clock"
                    )
                    LazyVGrid(columns: OnboardingScreen.minuteColumns, spacing: KrupaSpacing.xs) {
                        ForEach(minuteOptions, id: \.self) { minutes in
                            OnboardingMinuteChip(
                                minutes: minutes,
                                isSelected: dailyMinutes == minutes
                            ) {
                                dailyMinutes = minutes
                            }
                        }
                    }
                    Text("Застосунок сам складе заняття з потрібних частин: повторення, нові слова, граматика, аудіювання, говоріння.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ExplanationBox(
                title: "Рівень можна змінити",
                text: "Рівень можна буде змінити вручну в будь-який момент у Налаштуваннях.",
                systemImage: "gearshape"
            )

            navigationRow(nextTitle: "Почати тест")
        }
    }

    // MARK: - Крок 5: мінітест і результат

    @ViewBuilder
    private var testStep: some View {
        if questions.isEmpty {
            EmptyStateView(
                systemImage: "questionmark.circle",
                title: "Тест недоступний",
                message: "Не вдалося підготувати питання з контенту курсу. Можна пропустити тест і почати з A0.",
                actionTitle: "Пропустити тест і почати з A0",
                action: { finish(with: .a0, score: 0, assessmentDone: false) }
            )
        } else if let question = currentQuestion {
            questionView(question)
        } else {
            resultView
        }
    }

    private var currentQuestion: OnboardingTestQuestion? {
        guard questions.indices.contains(questionIndex) else { return nil }
        return questions[questionIndex]
    }

    private func questionView(_ question: OnboardingTestQuestion) -> some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            KrupaSectionHeader(
                title: "Перевіримо рівень",
                subtitle: "Питання \(questionIndex + 1) з \(questions.count)",
                systemImage: "checkmark.seal"
            )
            KrupaProgressBar(value: Double(questionIndex) / Double(max(1, questions.count)))

            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    HStack(alignment: .center, spacing: KrupaSpacing.xs) {
                        Text(question.word.spanishWithArticle)
                            .font(.krupaSpanishWord)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        SpeakerButton(isSpeaking: app.speech.isSpeakingText(question.word.spanish)) {
                            app.speech.speak(question.word.spanish)
                        }
                    }
                    Text("Оберіть правильний переклад українською")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }

            VStack(spacing: KrupaSpacing.xs) {
                ForEach(question.options, id: \.self) { option in
                    AnswerOptionRow(
                        text: option,
                        state: optionState(option, question: question)
                    ) {
                        choose(option, question: question)
                    }
                }
            }

            if isAnswered {
                ExplanationBox(
                    title: "Правильна відповідь",
                    text: question.correctAnswer,
                    tint: .krupaSuccess,
                    systemImage: "checkmark.circle"
                )
                PrimaryActionButton(
                    title: questionIndex + 1 < questions.count ? "Далі" : "Показати результат",
                    systemImage: "arrow.right"
                ) {
                    nextQuestion()
                }
            } else {
                OnboardingTextButton(title: "Не знаю", systemImage: "questionmark") {
                    choose(nil, question: question)
                }
                OnboardingTextButton(title: "Пропустити питання", systemImage: "forward") {
                    nextQuestion()
                }
            }
        }
    }

    private var resultView: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.md) {
            KrupaCard {
                VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    KrupaSectionHeader(
                        title: "Ваш стартовий рівень",
                        subtitle: "Результат мінітесту",
                        systemImage: "checkmark.seal.fill"
                    )
                    Text("Бал: \(correctCount) з \(questions.count)")
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextPrimary)
                    KrupaProgressBar(
                        value: Double(correctCount) / Double(max(1, questions.count)),
                        showsLabel: true
                    )
                    HStack(spacing: KrupaSpacing.xs) {
                        LevelBadge(level: suggestedLevel)
                        Text(suggestedLevel.subtitleUk)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextPrimary)
                    }
                    Text("Обрано: \(level.title) · \(level.subtitleUk)")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                Text("Обрано вручну:")
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextSecondary)
                ForEach(Level.allCases) { item in
                    AnswerOptionRow(
                        text: item.title,
                        state: level == item ? .selected : .idle,
                        subtitle: item.subtitleUk
                    ) {
                        level = item
                    }
                }
            }

            ExplanationBox(
                title: "Рівень можна змінити",
                text: "Рівень можна буде змінити вручну в будь-який момент у Налаштуваннях.",
                systemImage: "gearshape"
            )

            PrimaryActionButton(title: "Почати навчання", systemImage: "play.fill") {
                finish(with: level, score: assessmentPercent, assessmentDone: true)
            }
            OnboardingTextButton(title: "Пропустити тест і почати з A0", systemImage: "forward") {
                finish(with: .a0, score: 0, assessmentDone: false)
            }
        }
    }

    // MARK: - Логіка кроків

    private func next() {
        guard step < totalSteps - 1 else { return }
        if step == 3 {
            prepareQuestionsIfNeeded()
            // Повторний вхід у тест — починаємо з першого питання.
            if questionIndex >= questions.count {
                questionIndex = 0
                correctCount = 0
                selectedOption = nil
                isAnswered = false
            }
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            step += 1
        }
    }

    private func back() {
        guard step > 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            step -= 1
        }
    }

    /// Кнопки «Назад» і переходу далі.
    private func navigationRow(nextTitle: String) -> some View {
        HStack(spacing: KrupaSpacing.xs) {
            if step > 0 {
                SecondaryActionButton(title: "Назад", systemImage: "chevron.left") {
                    back()
                }
            }
            PrimaryActionButton(title: nextTitle, systemImage: "arrow.right") {
                next()
            }
        }
    }

    // MARK: - Мінітест

    private func prepareQuestionsIfNeeded() {
        guard questions.isEmpty else { return }

        var pool: [Word] = []
        for lvl in Level.allCases {
            pool.append(contentsOf: app.content.words(level: lvl))
        }
        guard pool.count >= 5 else { return }

        // По три слова з A0 та A1 і два з A2 — так тест охоплює весь курс.
        let perLevel = [3, 3, 2]
        var picked: [Word] = []
        for (index, lvl) in Level.allCases.enumerated() {
            let words = app.content.words(level: lvl)
            guard !words.isEmpty else { continue }
            let wanted = index < perLevel.count ? perLevel[index] : 1
            picked.append(contentsOf: testWords(from: words, count: wanted))
        }
        // Якщо з якогось рівня слів не вистачило — додаємо з загального пулу.
        for word in pool where picked.count < testSize && !picked.contains(where: { $0.id == word.id }) {
            picked.append(word)
        }

        questions = picked.prefix(testSize).map { word in
            OnboardingTestQuestion(
                id: word.id,
                word: word,
                options: options(for: word, in: pool),
                correctAnswer: word.translationUk
            )
        }
    }

    /// Беремо слова далі від початку частотного списку, щоб тест не складався
    /// з найтривіальніших слів рівня.
    private func testWords(from words: [Word], count: Int) -> [Word] {
        guard !words.isEmpty, count > 0 else { return [] }
        let start = min(words.count / 4, 30)
        let slice = Array(words.dropFirst(start).prefix(count))
        return slice.count >= count ? slice : Array(words.prefix(count))
    }

    /// Варіанти відповіді: правильний переклад і три дистрактори з інших слів.
    private func options(for word: Word, in pool: [Word]) -> [String] {
        let sameKind = pool.filter { $0.id != word.id && $0.partOfSpeech == word.partOfSpeech }
        let otherKind = pool.filter { $0.id != word.id && $0.partOfSpeech != word.partOfSpeech }
        var result: [String] = [word.translationUk]
        for candidate in sameKind + otherKind {
            guard result.count < 4 else { break }
            guard !result.contains(candidate.translationUk) else { continue }
            result.append(candidate.translationUk)
        }
        return result.shuffled()
    }

    private func choose(_ option: String?, question: OnboardingTestQuestion) {
        guard !isAnswered else { return }
        selectedOption = option
        isAnswered = true
        if option == question.correctAnswer {
            correctCount += 1
        }
    }

    private func optionState(_ option: String, question: OnboardingTestQuestion) -> AnswerOptionState {
        guard isAnswered else { return .idle }
        if option == question.correctAnswer { return .correct }
        if option == selectedOption { return .wrong }
        return .idle
    }

    private func nextQuestion() {
        selectedOption = nil
        isAnswered = false
        questionIndex += 1
        // Коли питання закінчилися — підставляємо рівень, який підказав тест.
        if questionIndex >= questions.count {
            level = suggestedLevel
        }
    }

    /// Простий поріг: понад 75 % правильних — A2, понад 40 % — A1, інакше A0.
    private var suggestedLevel: Level {
        guard !questions.isEmpty else { return .a0 }
        let ratio = Double(correctCount) / Double(questions.count)
        if ratio >= 0.75 { return .a2 }
        if ratio >= 0.4 { return .a1 }
        return .a0
    }

    private var assessmentPercent: Int {
        guard !questions.isEmpty else { return 0 }
        let percent = Double(correctCount) / Double(questions.count) * 100
        return min(100, max(0, Int(percent.rounded())))
    }

    // MARK: - Збереження

    /// Завершує онбординг і зберігає вибір у профіль.
    private func finish(with chosenLevel: Level, score: Int, assessmentDone: Bool) {
        app.progress.updateProfile { profile in
            profile.level = chosenLevel
            profile.goal = goal
            profile.dailyMinutes = dailyMinutes
            profile.displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            profile.assessmentDone = assessmentDone
            profile.assessmentScore = score
            profile.onboardingDone = true
        }
    }

    /// «Пропустити» — стартуємо з A0 без тесту.
    private func skipOnboarding() {
        app.progress.updateProfile { profile in
            profile.level = .a0
            profile.onboardingDone = true
        }
    }

    private func iconName(for level: Level) -> String {
        switch level {
        case .a0: return "sparkles"
        case .a1: return "chart.bar"
        case .a2: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - Допоміжні типи

/// Питання мінітесту: іспанське слово та 4 українські варіанти.
private struct OnboardingTestQuestion: Identifiable, Hashable {
    let id: String
    let word: Word
    let options: [String]
    let correctAnswer: String
}

/// Картка вибору (рівень, мета) з підсвіткою обраного варіанта.
private struct OnboardingSelectableCard: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KrupaSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : Color.krupaBrand)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.krupaBrand : Color.krupaBrand.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Text(subtitle)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Text("✓")
                        .font(.krupaHeadline)
                        .foregroundStyle(Color.krupaBrand)
                }
            }
            .padding(KrupaSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.krupaBrand.opacity(0.10) : Color.krupaSurface)
            .overlay(
                RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous)
                    .stroke(isSelected ? Color.krupaBrand : Color.krupaDivider, lineWidth: isSelected ? 1.6 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Чип вибору щоденної цілі в хвилинах.
private struct OnboardingMinuteChip: View {
    var minutes: Int
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes) хв")
                .font(.krupaCallout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KrupaSpacing.xs)
                .foregroundStyle(isSelected ? Color.white : Color.krupaTextPrimary)
                .background(isSelected ? Color.krupaBrand : Color.krupaSurfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Текстова кнопка другорядних дій («Не знаю», «Пропустити…»).
private struct OnboardingTextButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.krupaCallout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(Color.krupaBrand)
        }
        .buttonStyle(.plain)
    }
}
