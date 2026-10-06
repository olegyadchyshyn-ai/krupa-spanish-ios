import SwiftUI

/// Діалог з AI-співрозмовником (відповідник android `AiDialogScreen`).
struct AIDialogScreen: View {
    let scenarioId: String

    @EnvironmentObject private var app: AppState

    @State private var mode: AIConversationMode = .freeChat
    @State private var messages: [AIMessage] = []
    @State private var inputText: String = ""
    @State private var showsSaved: Bool = false
    @State private var showsHint: Bool = false

    private var scenario: AIScenario {
        AIScenario.all.first { $0.id == scenarioId } ?? AIScenario.all[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.krupaDivider)
            conversation
            Divider().overlay(Color.krupaDivider)
            composer
        }
        .background(Color.krupaBackground.ignoresSafeArea())
        .navigationTitle(scenario.titleUk)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSaved = true
                } label: {
                    Image(systemName: "tray.full")
                }
                .accessibilityLabel("Збережені розмови")
            }
        }
        .sheet(isPresented: $showsSaved) { savedConversationsSheet }
        .sheet(isPresented: $showsHint) { hintSheet }
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            HStack(spacing: KrupaSpacing.xs) {
                Image(systemName: scenario.systemImageName)
                    .foregroundStyle(Color.krupaBrand)
                VStack(alignment: .leading, spacing: 2) {
                    Text(scenario.titleEs)
                        .font(.krupaHeadline)
                        .foregroundStyle(Color.krupaTextPrimary)
                    Text(scenario.descriptionUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
                Spacer(minLength: 0)
                LevelBadge(level: scenario.level)
            }

            HStack(spacing: KrupaSpacing.xs) {
                Picker("Режим", selection: $mode) {
                    ForEach(AIConversationMode.allCases) { item in
                        Text(item.titleUk).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    showsHint = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.krupaBrand)
                }
                .accessibilityLabel("Підказка")
            }

            HStack(spacing: KrupaSpacing.xs) {
                ChipView(text: app.ai.title(for: app.profile),
                         systemImage: app.profile.allowExternalAi ? "antenna.radiowaves.left.and.right" : "wifi.slash",
                         tint: app.profile.allowExternalAi ? .krupaBrand : .krupaSuccess)
                if !app.profile.allowExternalAi {
                    Text("Працює без інтернету")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
                Spacer(minLength: 0)
            }

            if let error = app.ai.lastError {
                ErrorBanner(message: error)
            }
        }
        .padding(.horizontal, KrupaSpacing.screenPadding)
        .padding(.vertical, KrupaSpacing.sm)
        .background(Color.krupaSurface)
    }

    // MARK: - Стрічка повідомлень

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: KrupaSpacing.sm) {
                    ForEach(messages) { message in
                        MessageBubble(message: message, onSpeak: {
                            app.speak(message.text, force: true)
                        })
                        .id(message.id)
                    }

                    if app.ai.isThinking {
                        HStack(spacing: KrupaSpacing.xs) {
                            ProgressView().tint(.krupaBrand)
                            Text("Співрозмовник друкує…")
                                .font(.krupaCaption)
                                .foregroundStyle(Color.krupaTextSecondary)
                        }
                        .padding(.leading, KrupaSpacing.xs)
                        .id("thinking")
                    }
                }
                .padding(KrupaSpacing.screenPadding)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Поле введення

    private var composer: some View {
        VStack(spacing: KrupaSpacing.xs) {
            if let suggestions = messages.last(where: { $0.role == .assistant })?.corrections.isEmpty == false ? nil : lastSuggestions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KrupaSpacing.xs) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                            Button {
                                inputText = suggestion
                            } label: {
                                ChipView(text: suggestion, systemImage: "text.bubble")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, KrupaSpacing.screenPadding)
                }
            }

            HStack(spacing: KrupaSpacing.xs) {
                KrupaTextField(
                    placeholder: "Напишіть іспанською…",
                    text: $inputText,
                    onSubmit: send
                )

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(10)
                        .background(canSend ? Color.krupaBrand : Color.krupaTextSecondary.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Надіслати")
            }
            .padding(.horizontal, KrupaSpacing.screenPadding)
            .padding(.bottom, KrupaSpacing.xs)
        }
        .padding(.top, KrupaSpacing.xs)
        .background(Color.krupaSurface)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !app.ai.isThinking
    }

    private var lastSuggestions: [String]? {
        let history = messages.filter { $0.role == .user }
        guard !history.isEmpty else { return scenario.suggestedReplies }
        let index = min(history.count, scenario.suggestedReplies.count - 1)
        guard index >= 0, index < scenario.suggestedReplies.count else { return nil }
        return [scenario.suggestedReplies[index]]
    }

    // MARK: - Дії

    private func startIfNeeded() {
        guard messages.isEmpty else { return }
        messages = [
            AIMessage(
                id: UUID().uuidString,
                role: .assistant,
                text: scenario.openingLineEs,
                translationUk: "",
                corrections: [],
                createdAt: Date()
            )
        ]
        app.speak(scenario.openingLineEs, force: true)
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let corrections = app.ai.corrections(for: text)
        let userMessage = AIMessage(
            id: UUID().uuidString,
            role: .user,
            text: text,
            translationUk: "",
            corrections: corrections,
            createdAt: Date()
        )
        messages.append(userMessage)
        inputText = ""

        let history = messages
        let currentScenario = scenario
        let currentMode = mode
        let profile = app.profile

        Task {
            let response = await app.ai.respond(
                scenario: currentScenario,
                mode: currentMode,
                history: history,
                profile: profile
            )
            guard let response else { return }
            let reply = AIMessage(
                id: UUID().uuidString,
                role: .assistant,
                text: response.textEs,
                translationUk: response.translationUk,
                corrections: [],
                createdAt: Date()
            )
            messages.append(reply)
            app.speak(response.textEs, force: true)
        }
    }

    private func saveConversation() {
        let session = ConversationSession(
            id: UUID().uuidString,
            scenarioId: scenario.id,
            scenarioTitleUk: scenario.titleUk,
            mode: mode.rawValue,
            startedAt: messages.first?.createdAt ?? Date(),
            messages: messages
        )
        app.progress.saveConversation(session)
    }

    // MARK: - Аркуші

    private var savedConversationsSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button("Зберегти поточну розмову", action: saveConversation)
                        .disabled(messages.filter { $0.role == .user }.isEmpty)
                }

                if app.progress.conversations.isEmpty {
                    Text("Збережених розмов ще немає.")
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                } else {
                    ForEach(app.progress.conversations) { conversation in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(conversation.scenarioTitleUk)
                                .font(.krupaCallout)
                            Text("Реплік: \(conversation.userMessageCount) • \(conversation.startedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.krupaSmall)
                                .foregroundStyle(Color.krupaTextSecondary)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let conversation = app.progress.conversations[index]
                            app.progress.deleteConversation(id: conversation.id)
                        }
                    }
                }
            }
            .navigationTitle("Збережені розмови")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { showsSaved = false }
                }
            }
        }
    }

    private var hintSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KrupaSpacing.md) {
                    KrupaSectionHeader(title: "Як вести діалог", subtitle: mode.descriptionUk, systemImage: "lightbulb")

                    KrupaCard {
                        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                            Text("Готові фрази")
                                .font(.krupaCallout)
                            ForEach(scenario.suggestedReplies, id: \.self) { reply in
                                HStack(spacing: KrupaSpacing.xs) {
                                    Text("•")
                                    Text(reply)
                                        .font(.krupaBody)
                                    Spacer(minLength: 0)
                                    Button {
                                        app.speak(reply, force: true)
                                    } label: {
                                        Image(systemName: "speaker.wave.2")
                                            .foregroundStyle(Color.krupaBrand)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    ExplanationBox(
                        title: "Порада",
                        text: "Пишіть простими реченнями. Якщо помиляєтесь — застосунок підкаже правильний варіант під вашим повідомленням.",
                        tint: .krupaSuccess
                    )
                }
                .padding(KrupaSpacing.screenPadding)
            }
            .background(Color.krupaBackground.ignoresSafeArea())
            .navigationTitle("Підказка")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { showsHint = false }
                }
            }
        }
    }
}

// MARK: - Бульбашка повідомлення

private struct MessageBubble: View {
    let message: AIMessage
    let onSpeak: () -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: KrupaSpacing.xl) }

            VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
                Text(message.text)
                    .font(isUser ? .krupaBody : .krupaSpanishExample)
                    .foregroundStyle(isUser ? Color.white : Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !message.translationUk.isEmpty {
                    Text(message.translationUk)
                        .font(.krupaCaption)
                        .foregroundStyle(isUser ? Color.white.opacity(0.85) : Color.krupaTextSecondary)
                }

                if !isUser {
                    HStack(spacing: KrupaSpacing.xs) {
                        Button(action: onSpeak) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.krupaBrand)
                    }
                }

                ForEach(message.corrections, id: \.original) { correction in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(correction.original) → \(correction.corrected)")
                            .font(.krupaSmall)
                            .foregroundStyle(Color.krupaWarning)
                        Text(correction.explanationUk)
                            .font(.krupaSmall)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                    .padding(6)
                    .background(Color.krupaWarning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                }
            }
            .padding(KrupaSpacing.sm)
            .background(isUser ? Color.krupaBrand : Color.krupaSurface)
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
            .krupaCardShadow()

            if !isUser { Spacer(minLength: KrupaSpacing.xl) }
        }
    }
}
