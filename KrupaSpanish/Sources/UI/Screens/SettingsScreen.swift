import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Налаштування

/// Вкладка «Налаштування»: навчання, звук і мовлення, вигляд, AI-співрозмовник,
/// дані (резервна копія, діагностика, про застосунок) і небезпечна зона.
///
/// `ProgressStore.profile` і `ProgressStore.settings` — computed-властивості без
/// сеттера, тому кожен контрол пише зміни через `updateProfile` / `updateSettings`
/// (див. `profileBinding` і `settingsBinding` нижче).
struct SettingsScreen: View {
    @EnvironmentObject private var app: AppState

    /// Чи показано підтвердження очищення прогресу.
    @State private var showsResetDialog = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        Form {
            messagesSection
            learningSection
            audioSection
            appearanceSection
            aiSection
            dataSection
            dangerSection
        }
        .navigationTitle("Налаштування")
        .scrollContentBackground(.hidden)
        .background(Color.krupaBackground.ignoresSafeArea())
        .tint(.krupaBrand)
        .confirmationDialog(
            "Очистити прогрес?",
            isPresented: $showsResetDialog,
            titleVisibility: .visible
        ) {
            Button("Очистити", role: .destructive) {
                resetProgress()
            }
            Button("Скасувати", role: .cancel) { }
        } message: {
            Text("Будуть видалені всі картки, статистика, помилки й діалоги. Контент курсу залишиться. Дію не можна скасувати.")
        }
    }

    // MARK: - Звʼязки зі станом

    /// Профіль і налаштування доступні лише для читання, тому контроли
    /// отримують `Binding`, який записує зміну через відповідний метод стора.
    private func profileBinding<T>(_ keyPath: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(
            get: { app.progress.profile[keyPath: keyPath] },
            set: { value in
                app.progress.updateProfile { $0[keyPath: keyPath] = value }
            }
        )
    }

    private func settingsBinding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(
            get: { app.progress.settings[keyPath: keyPath] },
            set: { value in
                app.progress.updateSettings { $0[keyPath: keyPath] = value }
            }
        )
    }

    /// Увімкнення зовнішнього AI одночасно перемикає й провайдера,
    /// інакше `AIService` продовжив би відповідати офлайн-скриптом.
    private var allowExternalAiBinding: Binding<Bool> {
        Binding(
            get: { app.progress.profile.allowExternalAi },
            set: { value in
                app.progress.updateProfile { profile in
                    profile.allowExternalAi = value
                    profile.aiProviderId = value ? "remote" : "local"
                }
            }
        )
    }

    /// Швидкість мовлення у вигляді «0.45».
    private var rateText: String {
        String(format: "%.2f", app.progress.profile.ttsRate)
    }

    // MARK: - Повідомлення

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage {
            Section {
                ErrorBanner(message: errorMessage)
            }
        }
        if let statusMessage {
            Section {
                ExplanationBox(
                    title: "Готово",
                    text: statusMessage,
                    tint: .krupaSuccess,
                    systemImage: "checkmark.circle.fill"
                )
            }
        }
    }

    // MARK: - Секція «Навчання»

    private var learningSection: some View {
        Section {
            Picker("Рівень", selection: profileBinding(\.level)) {
                ForEach(Level.allCases, id: \.self) { level in
                    Text("\(level.title) — \(level.subtitleUk)").tag(level)
                }
            }
            .pickerStyle(.menu)

            SettingsHintText(text: "Обраний рівень: \(app.profile.level.title) — \(app.profile.level.subtitleUk)")

            Picker("Ціль навчання", selection: profileBinding(\.goal)) {
                ForEach(LearningGoal.allCases, id: \.self) { goal in
                    Text(goal.titleUk).tag(goal)
                }
            }
            .pickerStyle(.menu)

            SettingsHintText(text: app.profile.goal.descriptionUk)

            Stepper(value: profileBinding(\.dailyMinutes), in: 5...60, step: 5) {
                SettingsValueRow(title: "Час на день", value: "\(app.profile.dailyMinutes) хв")
            }

            Stepper(value: profileBinding(\.dailyCardGoal), in: 10...200, step: 5) {
                SettingsValueRow(title: "Щоденна ціль карток", value: "\(app.profile.dailyCardGoal)")
            }

            Stepper(value: settingsBinding(\.sessionSize), in: 5...50, step: 5) {
                SettingsValueRow(title: "Розмір заняття", value: "\(app.settings.sessionSize)")
            }

            Stepper(value: settingsBinding(\.newCardsPerDay), in: 10...50, step: 5) {
                SettingsValueRow(title: "Нових карток на день", value: "\(app.settings.newCardsPerDay)")
            }

            Stepper(value: settingsBinding(\.reviewsPerDay), in: 20...300, step: 5) {
                SettingsValueRow(title: "Повторень на день", value: "\(app.settings.reviewsPerDay)")
            }
        } header: {
            Text("Навчання")
        } footer: {
            Text("Ці значення визначають, скільки матеріалу застосунок пропонує щодня: час на день, ціль карток, розмір заняття та ліміти нових карток і повторень.")
        }
    }

    // MARK: - Секція «Звук і мовлення»

    private var audioSection: some View {
        Section {
            Toggle("Автоматичне озвучення", isOn: settingsBinding(\.autoPlayAudio))

            VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                HStack(spacing: KrupaSpacing.xs) {
                    Text("Швидкість")
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Spacer(minLength: KrupaSpacing.xs)
                    Text(rateText)
                        .font(.krupaCallout)
                        .foregroundStyle(Color.krupaBrand)
                }

                Slider(
                    value: profileBinding(\.ttsRate),
                    in: 0.2...0.8,
                    step: 0.05,
                    onEditingChanged: { isEditing in
                        // Коли користувач відпустив повзунок — показуємо новий темп.
                        if !isEditing {
                            app.speak("Hola, ¿qué tal?", force: true)
                        }
                    }
                )
            }

            Picker("Голос", selection: profileBinding(\.ttsVoiceGender)) {
                ForEach(TtsVoiceGender.allCases, id: \.self) { gender in
                    Text(gender.titleUk).tag(gender)
                }
            }
            .pickerStyle(.menu)

            SettingsInfoRow(
                title: "Доступні іспанські голоси",
                value: "\(app.speech.availableVoices.count)",
                tint: app.speech.availableVoices.isEmpty ? .krupaWarning : .krupaSuccess
            )

            if app.speech.availableVoices.isEmpty {
                ErrorBanner(message: "У системі немає іспанського голосу для синтезу мовлення. Завантажте його: Налаштування iOS → Доступність → Промовляння → Голоси → Іспанська.")
            }

            if let speechError = app.speech.lastError {
                ErrorBanner(message: speechError)
            }
        } header: {
            Text("Звук і мовлення")
        } footer: {
            Text("Мовлення озвучує система пристрою — мова іспанська (es-ES). Якщо голосів немає, додайте іспанський голос у налаштуваннях iOS.")
        }
    }

    // MARK: - Секція «Вигляд»

    private var appearanceSection: some View {
        Section {
            Picker("Тема оформлення", selection: profileBinding(\.themeMode)) {
                ForEach(ThemeMode.allCases, id: \.self) { mode in
                    Text(mode.titleUk).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Показувати підказки вимови", isOn: settingsBinding(\.showPronunciationHints))
            if app.settings.showPronunciationHints {
                SettingsHintText(text: "Корисно на початку, заважає згодом")
            }

            Toggle("Показувати IPA", isOn: settingsBinding(\.showIpa))
            Toggle("Переклад одразу", isOn: settingsBinding(\.showTranslationFirst))
            Toggle("Показувати переклад під час слухання", isOn: settingsBinding(\.listeningHintsEnabled))
            Toggle("Вібровідгук", isOn: settingsBinding(\.hapticsEnabled))
        } header: {
            Text("Вигляд")
        } footer: {
            Text("Підказки вимови й IPA допомагають на старті, а переклад одразу варто вимкнути, коли слова вже знайомі.")
        }
    }

    // MARK: - Секція «AI-співрозмовник»

    private var aiSection: some View {
        Section {
            SettingsInfoRow(title: "Провайдер", value: app.ai.title(for: app.profile))

            Toggle("Дозволити зовнішній AI", isOn: allowExternalAiBinding)

            VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                SettingsHintText(text: "Адреса API (endpoint)")
                TextField("https://api.example.com/v1/chat/completions", text: profileBinding(\.aiEndpoint))
                    .font(.krupaCaption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .keyboardType(.URL)
            }

            VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                SettingsHintText(text: "Модель")
                TextField("gpt-4o-mini", text: profileBinding(\.aiModel))
                    .font(.krupaCaption)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            SecureField("Ваш API-ключ", text: profileBinding(\.aiApiKey))
                .font(.krupaCaption)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)

            ExplanationBox(
                title: "Офлайн-режим",
                text: "У цій версії працює локальний викладач: діалоги, рольові ситуації й розбір помилок — усе на пристрої, без інтернету.\nМережеві провайдери з'являться в наступних версіях. Зараз ці поля зберігаються локально, щоб ви могли підготувати налаштування заздалегідь.\nЯкщо увімкнено, ваші тексти й записи можуть надсилатися на вибраний сервіс. Ключі не зашиті в застосунок — їх вводите ви.",
                systemImage: "lock.shield"
            )
        } header: {
            Text("AI-співрозмовник")
        } footer: {
            Text("Без ключів і мережі діалоги працюють офлайн — зовнішній AI потрібен лише для складніших відповідей.")
        }
    }

    // MARK: - Секція «Дані»

    private var dataSection: some View {
        Section {
            NavigationLink(value: AppRoute.backup) {
                SettingsLinkRow(
                    title: "Резервна копія та перенесення",
                    subtitle: "Експорт та імпорт прогресу у файл JSON",
                    systemImage: "externaldrive.fill"
                )
            }

            NavigationLink(value: AppRoute.diagnostics) {
                SettingsLinkRow(
                    title: "Діагностика",
                    subtitle: "Стан контенту, збереження й мовлення",
                    systemImage: "stethoscope"
                )
            }

            NavigationLink(value: AppRoute.about) {
                SettingsLinkRow(
                    title: "Про застосунок",
                    subtitle: "Версія, профіль і статистика контенту",
                    systemImage: "info.circle.fill"
                )
            }
        } header: {
            Text("Дані")
        }
    }

    // MARK: - Небезпечна зона

    private var dangerSection: some View {
        Section {
            Button(role: .destructive) {
                showsResetDialog = true
            } label: {
                Label("Скинути весь прогрес", systemImage: "trash.fill")
                    .font(.krupaBody)
            }
        } header: {
            Text("Небезпечна зона")
        } footer: {
            Text("Контент курсу залишиться на місці — видаляється лише ваш прогрес. Дію не можна скасувати.")
        }
    }

    // MARK: - Дії

    private func resetProgress() {
        app.speech.stop()
        app.progress.resetAll()
        errorMessage = nil
        statusMessage = "Прогрес очищено. Контент курсу залишився."
    }
}

// MARK: - Резервна копія

/// Експорт та імпорт прогресу: файл JSON у Файлах чи месенджері,
/// або вміст копії, вставлений текстом (аварійний спосіб).
struct BackupScreen: View {
    @EnvironmentObject private var app: AppState

    @State private var exportedFileURL: URL?
    @State private var showsFileImporter = false
    @State private var pendingImportURL: URL?
    @State private var pendingSummary: BackupService.Summary?
    @State private var showsImportDialog = false
    @State private var jsonText = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                messagesSection
                exportCard
                importCard
                textRestoreCard
                stateCard
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.top, KrupaSpacing.md)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Резервна копія")
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.json],
            onCompletion: handlePickedFile
        )
        .confirmationDialog(
            "Імпорт прогресу",
            isPresented: $showsImportDialog,
            titleVisibility: .visible,
            presenting: pendingSummary
        ) { _ in
            Button("Замінити прогрес") {
                performImport(mode: .replace)
            }
            Button("Обʼєднати") {
                performImport(mode: .merge)
            }
            Button("Скасувати", role: .cancel) {
                clearPendingImport()
            }
        } message: { summary in
            Text(summary.descriptionUk + "\n\nЗамінити наявний прогрес даними з файлу чи додати їх до поточного?")
        }
    }

    // MARK: - Повідомлення

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage {
            ErrorBanner(message: errorMessage)
        }
        if let statusMessage {
            ExplanationBox(
                title: "Готово",
                text: statusMessage,
                tint: .krupaSuccess,
                systemImage: "checkmark.circle.fill"
            )
        }
    }

    // MARK: - Експорт

    private var exportCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Експорт",
                    subtitle: "Прогрес зберігається лише на цьому пристрої. Щоб перенести навчання на інший телефон, збережіть файл JSON і відкрийте його там.",
                    systemImage: "square.and.arrow.up"
                )

                PrimaryActionButton(title: "Створити резервну копію", systemImage: "externaldrive.fill") {
                    exportBackup()
                }

                if let url = exportedFileURL {
                    VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                        SettingsInfoRow(title: "Файл", value: url.lastPathComponent)

                        ShareLink(item: url) {
                            Label("Надіслати файл", systemImage: "paperplane.fill")
                                .font(.krupaCallout)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .foregroundStyle(Color.krupaBrand)
                                .background(Color.krupaBrand.opacity(0.12))
                                .clipShape(
                                    RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous)
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Імпорт із файлу

    private var importCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Імпорт",
                    subtitle: "Резервна копія — це один JSON-файл із профілем, картками, журналом відповідей і статистикою.",
                    systemImage: "square.and.arrow.down"
                )

                SecondaryActionButton(title: "Імпортувати прогрес з файлу", systemImage: "folder") {
                    showsFileImporter = true
                }

                SettingsHintText(text: "Перед імпортом застосунок покаже, що саме містить файл: дату створення, рівень, кількість карток і відповідей.")
            }
        }
    }

    // MARK: - Імпорт із тексту

    private var textRestoreCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Відновлення з тексту",
                    subtitle: "Якщо файл не відкривається — вставте вміст резервної копії (JSON) у поле нижче.",
                    systemImage: "doc.text"
                )

                TextEditor(text: $jsonText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 150)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .scrollContentBackground(.hidden)
                    .padding(KrupaSpacing.xs)
                    .background(Color.krupaSurfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

                SecondaryActionButton(
                    title: "Відновити з тексту",
                    systemImage: "arrow.counterclockwise",
                    tint: .krupaWarning
                ) {
                    restoreFromText()
                }
            }
        }
    }

    // MARK: - Стан збереження

    private var stateCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Стан збереження", systemImage: "clock.arrow.circlepath")

                SettingsInfoRow(
                    title: "Останнє збереження",
                    value: SettingsFormatting.savedAtText(app.progress.lastSavedAt)
                )

                if let saveError = app.progress.lastSaveError {
                    ErrorBanner(message: saveError)
                }

                if let backupError = app.backup.lastError {
                    ErrorBanner(message: backupError)
                }

                SettingsHintText(text: "Файл копії лежить у тимчасовій теці: його варто одразу надіслати собі або зберегти у Файлах.")
            }
        }
    }

    // MARK: - Дії

    private func exportBackup() {
        errorMessage = nil
        statusMessage = nil
        app.backup.export(progress: app.progress)
        if let url = app.backup.lastExportURL {
            exportedFileURL = url
            statusMessage = "Резервну копію створено: \(url.lastPathComponent)"
        } else {
            errorMessage = app.backup.lastError ?? "Не вдалося створити резервну копію."
        }
    }

    private func handlePickedFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            inspectPickedFile(url)
        case .failure(let error):
            errorMessage = "Не вдалося відкрити файл: \(error.localizedDescription)"
        }
    }

    /// Читає заголовок копії, щоб показати користувачу, що саме він імпортує.
    private func inspectPickedFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let summary = try app.backup.inspect(url: url)
            pendingImportURL = url
            pendingSummary = summary
            showsImportDialog = true
            errorMessage = nil
        } catch {
            errorMessage = "Не вдалося прочитати резервну копію: \(error.localizedDescription)"
        }
    }

    private func performImport(mode: BackupService.ImportMode) {
        guard let url = pendingImportURL else {
            clearPendingImport()
            return
        }

        do {
            let summary = try app.backup.importBackup(from: url, into: app.progress, mode: mode)
            let message: String
            switch mode {
            case .replace:
                message = "Прогрес замінено даними з копії."
            case .merge:
                message = "Дані з копії додано до поточного прогресу."
            }
            statusMessage = message + "\n" + summary.descriptionUk
            errorMessage = nil
        } catch {
            errorMessage = "Не вдалося відновити прогрес: \(error.localizedDescription)"
        }

        clearPendingImport()
    }

    private func clearPendingImport() {
        pendingImportURL = nil
        pendingSummary = nil
        showsImportDialog = false
    }

    private func restoreFromText() {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Спочатку вставте JSON-текст резервної копії."
            return
        }

        do {
            let summary = try app.backup.importBackup(jsonText: trimmed, into: app.progress)
            jsonText = ""
            statusMessage = "Прогрес відновлено з тексту.\n" + summary.descriptionUk
            errorMessage = nil
        } catch {
            errorMessage = "Не вдалося відновити прогрес: \(error.localizedDescription)"
        }
    }
}

// MARK: - Діагностика

/// Стан контенту, збереження, мовлення та даних; звіт можна скопіювати.
struct DiagnosticsScreen: View {
    @EnvironmentObject private var app: AppState

    @State private var errorMessage: String?
    @State private var statusMessage: String?

    private let statColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                messagesSection
                contentCard
                savingCard
                speechCard
                dataCard
                actionsCard
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.top, KrupaSpacing.md)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Діагностика")
    }

    // MARK: - Повідомлення

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage {
            ErrorBanner(message: errorMessage)
        }
        if let statusMessage {
            ExplanationBox(
                title: "Готово",
                text: statusMessage,
                tint: .krupaSuccess,
                systemImage: "checkmark.circle.fill"
            )
        }
    }

    // MARK: - Контент

    private var contentCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Контент",
                    subtitle: "Усі матеріали курсу вбудовано в застосунок — мережа для навчання не потрібна.",
                    systemImage: "books.vertical.fill"
                )

                LazyVGrid(columns: statColumns, spacing: KrupaSpacing.xs) {
                    StatTile(
                        title: "Слів у курсі",
                        value: "\(app.content.words.count)",
                        systemImage: "textformat.abc",
                        tint: .krupaBrand
                    )
                    StatTile(
                        title: "Речень",
                        value: "\(app.content.sentences.count)",
                        systemImage: "text.alignleft",
                        tint: .krupaBrandDark
                    )
                    StatTile(
                        title: "Вправ",
                        value: "\(app.content.exercises.count)",
                        systemImage: "checklist",
                        tint: .krupaSuccess
                    )
                    StatTile(
                        title: "Граматичних тем",
                        value: "\(app.content.grammar.count)",
                        systemImage: "text.book.closed.fill",
                        tint: .krupaGold
                    )
                    StatTile(
                        title: "Аудіювань",
                        value: "\(app.content.listening.count)",
                        systemImage: "headphones",
                        tint: .krupaWarning
                    )
                    StatTile(
                        title: "Тем курсу",
                        value: "\(app.content.topics.count)",
                        systemImage: "square.grid.2x2.fill",
                        tint: .krupaBrand
                    )
                }

                if app.contentIssues.isEmpty {
                    SettingsInfoRow(title: "Проблеми контенту", value: "Зауважень немає", tint: .krupaSuccess)
                } else {
                    SettingsInfoRow(
                        title: "Проблеми контенту",
                        value: "\(app.contentIssues.count)",
                        tint: .krupaWarning
                    )
                    ForEach(app.contentIssues, id: \.self) { issue in
                        Text("• \(issue)")
                            .font(.krupaSmall)
                            .foregroundStyle(Color.krupaTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    // MARK: - Збереження

    private var savingCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Збереження", systemImage: "clock.arrow.circlepath")

                SettingsInfoRow(
                    title: "Останнє збереження",
                    value: SettingsFormatting.savedAtText(app.progress.lastSavedAt)
                )

                if let saveError = app.progress.lastSaveError {
                    ErrorBanner(message: saveError)
                } else {
                    SettingsInfoRow(title: "Помилок запису", value: "немає", tint: .krupaSuccess)
                }

                SettingsHintText(text: "Прогрес записується на диск із невеликою затримкою після кожної відповіді.")
            }
        }
    }

    // MARK: - Мовлення

    private var speechCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(
                    title: "Синтез мовлення",
                    subtitle: "Мова: іспанська (es-ES)",
                    systemImage: "speaker.wave.2.fill"
                )

                SettingsInfoRow(
                    title: "Доступні голоси",
                    value: "\(app.speech.availableVoices.count)",
                    tint: app.speech.availableVoices.isEmpty ? .krupaWarning : .krupaSuccess
                )

                SettingsInfoRow(
                    title: "Стан",
                    value: app.speech.availableVoices.isEmpty ? "не готовий" : "готовий",
                    tint: app.speech.availableVoices.isEmpty ? .krupaWarning : .krupaSuccess
                )

                if let speechError = app.speech.lastError {
                    ErrorBanner(message: speechError)
                }

                KrupaSectionHeader(title: "Розпізнавання мовлення", systemImage: "waveform")

                SettingsInfoRow(
                    title: "Доступне",
                    value: app.recognition.isAvailable ? "є" : "немає",
                    tint: app.recognition.isAvailable ? .krupaSuccess : .krupaWarning
                )
            }
        }
    }

    // MARK: - Дані

    private var dataCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Дані", systemImage: "internaldrive.fill")

                SettingsInfoRow(title: "Карток у пам'яті", value: "\(app.progress.document.cards.count)")

                ForEach(CardPhase.allCases, id: \.self) { phase in
                    SettingsInfoRow(title: phase.titleUk, value: "\(cardCount(phase))")
                }

                SettingsInfoRow(
                    title: "Записів у журналі відповідей",
                    value: "\(app.progress.document.reviewLog.count)"
                )
                SettingsInfoRow(
                    title: "Тем із прогресом",
                    value: "\(app.progress.document.topicProgress.count)"
                )
                SettingsInfoRow(
                    title: "Збережених діалогів",
                    value: "\(app.progress.document.conversations.count)"
                )
            }
        }
    }

    // MARK: - Дії

    private var actionsCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(title: "Дії", systemImage: "wrench.and.screwdriver.fill")

                SecondaryActionButton(title: "Оновити список голосів", systemImage: "arrow.clockwise") {
                    refreshVoices()
                }

                SecondaryActionButton(title: "Перевірити звук", systemImage: "speaker.wave.3.fill") {
                    errorMessage = nil
                    app.speak("Hola, esto es una prueba.", force: true)
                }

                SecondaryActionButton(title: "Скопіювати звіт", systemImage: "doc.on.doc") {
                    copyReport()
                }
            }
        }
    }

    // MARK: - Дії

    private func cardCount(_ phase: CardPhase) -> Int {
        app.progress.document.cards.values.filter { $0.phase == phase }.count
    }

    private func refreshVoices() {
        app.speech.refreshVoices()
        errorMessage = nil
        statusMessage = "Список голосів оновлено: доступно \(app.speech.availableVoices.count)."
    }

    private func copyReport() {
        let report = makeReport()
        UIPasteboard.general.string = report
        errorMessage = nil
        statusMessage = "Звіт скопійовано в буфер обміну (\(report.count) символів)."
    }

    /// Текстовий звіт про стан застосунку — його зручно надіслати розробнику.
    private func makeReport() -> String {
        var lines: [String] = []
        lines.append("KRUPA Spanish — звіт про стан")
        lines.append("Версія: \(SettingsFormatting.versionText())")
        lines.append("Дата звіту: \(SettingsFormatting.dayTime.string(from: Date()))")
        lines.append("")
        lines.append("Контент:")
        lines.append("  слів: \(app.content.words.count)")
        lines.append("  речень: \(app.content.sentences.count)")
        lines.append("  вправ: \(app.content.exercises.count)")
        lines.append("  граматичних тем: \(app.content.grammar.count)")
        lines.append("  аудіювань: \(app.content.listening.count)")
        lines.append("  тем: \(app.content.topics.count)")
        lines.append("  зауважень до контенту: \(app.contentIssues.count)")
        for issue in app.contentIssues {
            lines.append("    • \(issue)")
        }
        lines.append("")
        lines.append("Збереження:")
        lines.append("  останнє збереження: \(SettingsFormatting.savedAtText(app.progress.lastSavedAt))")
        lines.append("  помилка запису: \(app.progress.lastSaveError ?? "немає")")
        lines.append("")
        lines.append("Мовлення:")
        lines.append("  іспанських голосів: \(app.speech.availableVoices.count)")
        lines.append("  помилка синтезу: \(app.speech.lastError ?? "немає")")
        lines.append("  розпізнавання доступне: \(app.recognition.isAvailable ? "так" : "ні")")
        lines.append("")
        lines.append("Дані:")
        lines.append("  карток у пам'яті: \(app.progress.document.cards.count)")
        for phase in CardPhase.allCases {
            lines.append("  \(phase.titleUk): \(cardCount(phase))")
        }
        lines.append("  записів у журналі: \(app.progress.document.reviewLog.count)")
        lines.append("  тем із прогресом: \(app.progress.document.topicProgress.count)")
        lines.append("  збережених діалогів: \(app.progress.document.conversations.count)")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Про застосунок

/// Коротка довідка: версія, профіль користувача, опис курсу та статистика контенту.
struct AboutScreen: View {
    @EnvironmentObject private var app: AppState

    private let statColumns = [
        GridItem(.flexible(), spacing: KrupaSpacing.xs),
        GridItem(.flexible(), spacing: KrupaSpacing.xs)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                headerCard
                profileCard
                descriptionCard
                contentCard
                offlineCard
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.top, KrupaSpacing.md)
            .padding(.bottom, KrupaSpacing.xl)
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle("Про застосунок")
    }

    // MARK: - Заголовок

    private var headerCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                HStack(spacing: KrupaSpacing.sm) {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 56, height: 56)
                        .background(Color.krupaHeaderGradient)
                        .clipShape(
                            RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("KRUPA Spanish")
                            .font(.krupaTitle)
                            .foregroundStyle(Color.krupaTextPrimary)
                        Text("Іспанська для україномовних")
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }

                    Spacer(minLength: 0)
                }

                SettingsInfoRow(title: "Версія", value: SettingsFormatting.versionText())
                SettingsInfoRow(title: "Платформа", value: "iOS 17 або новіша")
                SettingsInfoRow(title: "Мова інтерфейсу", value: "українська")
                SettingsInfoRow(title: "Контент", value: "іспанська (Іспанія)")
            }
        }
    }

    // MARK: - Профіль

    private var profileCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Ваш профіль", systemImage: "person.crop.circle")

                HStack(spacing: KrupaSpacing.xs) {
                    LevelBadge(level: app.profile.level)
                    Text(app.profile.level.subtitleUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                    Spacer(minLength: 0)
                    StreakBadge(days: app.progress.streakDays)
                }

                SettingsInfoRow(title: "Ціль навчання", value: app.profile.goal.titleUk)
                SettingsHintText(text: app.profile.goal.descriptionUk)
                SettingsInfoRow(
                    title: "Початок навчання",
                    value: SettingsFormatting.day.string(from: app.profile.startedAt)
                )
                SettingsInfoRow(title: "Хвилин на день", value: "\(app.profile.dailyMinutes) хв")
            }
        }
    }

    // MARK: - Опис

    private var descriptionCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Що це за застосунок", systemImage: "info.circle")

                AboutParagraph(text: "KRUPA Spanish — застосунок для вивчення іспанської мови україномовними: переклад, рід іменників, IPA, підказки вимови та приклади подано українською.")
                AboutParagraph(text: "Слова й речення повторюються за інтервальним алгоритмом (SM-2), мовлення озвучує синтезатор пристрою, вимову оцінює розпізнавання мовлення, а AI-співрозмовник веде діалоги за сценаріями — від кафе до оренди житла.")
                AboutParagraph(text: "Це iOS-версія застосунку (порт з Android): та сама логіка навчання й той самий контент курсу, написані заново на SwiftUI.")
            }
        }
    }

    // MARK: - Статистика контенту

    private var contentCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                KrupaSectionHeader(
                    title: "Контент курсу",
                    subtitle: "Усе це вже всередині застосунку — завантажувати нічого не треба.",
                    systemImage: "books.vertical.fill"
                )

                LazyVGrid(columns: statColumns, spacing: KrupaSpacing.xs) {
                    StatTile(
                        title: "Слів",
                        value: "\(app.content.words.count)",
                        systemImage: "textformat.abc",
                        tint: .krupaBrand
                    )
                    StatTile(
                        title: "Речень",
                        value: "\(app.content.sentences.count)",
                        systemImage: "text.alignleft",
                        tint: .krupaBrandDark
                    )
                    StatTile(
                        title: "Вправ",
                        value: "\(app.content.exercises.count)",
                        systemImage: "checklist",
                        tint: .krupaSuccess
                    )
                    StatTile(
                        title: "Граматичних тем",
                        value: "\(app.content.grammar.count)",
                        systemImage: "text.book.closed.fill",
                        tint: .krupaGold
                    )
                    StatTile(
                        title: "Аудіювань",
                        value: "\(app.content.listening.count)",
                        systemImage: "headphones",
                        tint: .krupaWarning
                    )
                    StatTile(
                        title: "Тем",
                        value: "\(app.content.topics.count)",
                        systemImage: "square.grid.2x2.fill",
                        tint: .krupaBrand
                    )
                }
            }
        }
    }

    // MARK: - Офлайн

    private var offlineCard: some View {
        KrupaCard {
            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                KrupaSectionHeader(title: "Інтернет не потрібен", systemImage: "wifi.slash")

                AboutParagraph(text: "Усі слова, речення, вправи, граматика й аудіювання зберігаються на пристрої, тому навчатися можна без мережі. Прогрес лежить лише у вашій пісочниці — перенести його на інший телефон можна резервною копією.")
                AboutParagraph(text: "Мережа потрібна лише для зовнішнього AI-співрозмовника, якщо ви увімкнете його в налаштуваннях і введете свій ключ.")
            }
        }
    }
}

// MARK: - Допоміжні рядки

/// Рядок «назва — значення» для `Stepper` та інших контролів у формі.
private struct SettingsValueRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            Text(title)
                .font(.krupaBody)
                .foregroundStyle(Color.krupaTextPrimary)
            Spacer(minLength: KrupaSpacing.xs)
            Text(value)
                .font(.krupaCallout)
                .foregroundStyle(Color.krupaBrand)
        }
    }
}

/// Рядок-посилання на підекіран у секції «Дані».
private struct SettingsLinkRow: View {
    var title: String
    var subtitle: String
    var systemImage: String

    var body: some View {
        HStack(spacing: KrupaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.krupaBrand)
                .frame(width: 30, height: 30)
                .background(Color.krupaBrand.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.krupaBody)
                    .foregroundStyle(Color.krupaTextPrimary)
                Text(subtitle)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

/// Рядок «підпис — значення» для карток діагностики та довідки.
private struct SettingsInfoRow: View {
    var title: String
    var value: String
    var tint: Color = .krupaTextPrimary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
            Text(title)
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
            Spacer(minLength: KrupaSpacing.xs)
            Text(value)
                .font(.krupaCallout)
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Дрібний пояснювальний підпис під контролом.
private struct SettingsHintText: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.krupaSmall)
            .foregroundStyle(Color.krupaTextSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Абзац опису в картках «Про застосунок».
private struct AboutParagraph: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.krupaCaption)
            .foregroundStyle(Color.krupaTextPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Форматування

/// Дати українською та версія застосунку з `Bundle`.
private enum SettingsFormatting {

    /// «1 січня 2025, 19:40»
    static let dayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter
    }()

    /// «1 січня 2025»
    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "uk_UA")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    /// Час останнього збереження у зрозумілому вигляді.
    static func savedAtText(_ date: Date?) -> String {
        guard let date else { return "ще не зберігалося" }
        return dayTime.string(from: date)
    }

    /// Версія й номер збірки з Info.plist: «1.0.0 (1)».
    static func versionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }
}
