import Foundation

// MARK: - Режими діалогу

enum AIConversationMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case freeChat = "FREE_CHAT"
    case rolePlay = "ROLE_PLAY"
    case guided = "GUIDED"

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .freeChat: return "Вільна розмова"
        case .rolePlay: return "Рольова гра"
        case .guided: return "З підказками"
        }
    }

    var descriptionUk: String {
        switch self {
        case .freeChat: return "Співрозмовник відповідає і ставить зустрічні питання."
        case .rolePlay: return "Ви граєте роль у побутовій ситуації."
        case .guided: return "До кожної репліки додаються підказки українською."
        }
    }

    init(from decoder: Decoder) throws {
        let raw = (try? decoder.singleValueContainer().decode(String.self)) ?? ""
        self = AIConversationMode(rawValue: raw.uppercased()) ?? .freeChat
    }
}

// MARK: - Сценарій діалогу

struct AIScenario: Identifiable, Hashable {
    var id: String
    var titleUk: String
    var titleEs: String
    var descriptionUk: String
    var level: Level
    var openingLineEs: String
    var suggestedReplies: [String]
    var systemPrompt: String
    var topicId: String

    var systemImageName: String {
        switch id {
        case "cafe": return "cup.and.saucer"
        case "airport": return "airplane.departure"
        case "hotel": return "bed.double"
        case "doctor": return "cross.case"
        case "shop": return "cart"
        case "street": return "map"
        case "work": return "briefcase"
        case "friends": return "person.2"
        case "landlord": return "house"
        case "bank": return "banknote"
        default: return "bubble.left.and.bubble.right"
        }
    }

    static let all: [AIScenario] = [
        AIScenario(
            id: "cafe",
            titleUk: "У кафе",
            titleEs: "En el café",
            descriptionUk: "Замовте напої та їжу, спитайте ціну й попросіть рахунок.",
            level: .a0,
            openingLineEs: "¡Hola! Buenos días, ¿qué le pongo?",
            suggestedReplies: ["Un café con leche, por favor.", "¿Tienen tostadas?", "La cuenta, por favor."],
            systemPrompt: "Ти офіціант у кафе в Іспанії. Відповідай іспанською простою мовою рівня A1, 1–2 речення, і став коротке зустрічне питання.",
            topicId: "t_a0_food"
        ),
        AIScenario(
            id: "shop",
            titleUk: "У магазині",
            titleEs: "En la tienda",
            descriptionUk: "Спитайте, скільки коштує, попросіть інший розмір чи колір.",
            level: .a0,
            openingLineEs: "Buenas, ¿le ayudo en algo?",
            suggestedReplies: ["¿Cuánto cuesta esto?", "¿Tiene otra talla?", "Solo estoy mirando, gracias."],
            systemPrompt: "Ти продавець у невеликій крамниці. Відповідай коротко іспанською (рівень A1), допомагай з вибором.",
            topicId: "t_a1_shopping"
        ),
        AIScenario(
            id: "street",
            titleUk: "На вулиці",
            titleEs: "En la calle",
            descriptionUk: "Запитайте дорогу, уточніть, де метро чи зупинка.",
            level: .a1,
            openingLineEs: "Sí, dime, ¿qué buscas?",
            suggestedReplies: ["¿Dónde está el metro?", "¿Está lejos de aquí?", "¿Cómo llego a la estación?"],
            systemPrompt: "Ти перехожий у Мадриді. Пояснюй дорогу простою іспанською (A1–A2) з орієнтирами.",
            topicId: "t_a1_city"
        ),
        AIScenario(
            id: "hotel",
            titleUk: "У готелі",
            titleEs: "En el hotel",
            descriptionUk: "Заселіться, спитайте про сніданок і Wi-Fi.",
            level: .a1,
            openingLineEs: "Buenas tardes, ¿tiene una reserva?",
            suggestedReplies: ["Sí, a nombre de…", "¿A qué hora es el desayuno?", "¿Hay wifi en la habitación?"],
            systemPrompt: "Ти адміністратор готелю. Відповідай ввічливо іспанською, рівень A2.",
            topicId: "t_a1_travel"
        ),
        AIScenario(
            id: "doctor",
            titleUk: "У лікаря",
            titleEs: "En el médico",
            descriptionUk: "Опишіть симптоми, зрозумійте поради лікаря.",
            level: .a1,
            openingLineEs: "Buenos días, cuénteme, ¿qué le pasa?",
            suggestedReplies: ["Me duele la cabeza.", "Tengo fiebre desde ayer.", "¿Necesito una receta?"],
            systemPrompt: "Ти лікар. Став прості питання про симптоми іспанською та давай короткі поради (рівень A2).",
            topicId: "t_a1_health"
        ),
        AIScenario(
            id: "landlord",
            titleUk: "Оренда житла",
            titleEs: "Alquilar un piso",
            descriptionUk: "Обговоріть умови оренди, комунальні платежі, завдаток.",
            level: .a2,
            openingLineEs: "Hola, ¿llamas por el piso del centro?",
            suggestedReplies: ["Sí, ¿sigue disponible?", "¿Están incluidos los gastos?", "¿Cuándo puedo verlo?"],
            systemPrompt: "Ти власник квартири в Іспанії. Обговорюй умови оренди іспанською (рівень A2–B1), став уточнювальні питання.",
            topicId: "t_a2_home"
        ),
        AIScenario(
            id: "friends",
            titleUk: "З друзями",
            titleEs: "Con amigos",
            descriptionUk: "Поговоріть про плани на вихідні, хобі та вподобання.",
            level: .a1,
            openingLineEs: "¡Qué bien verte! ¿Qué tal la semana?",
            suggestedReplies: ["Todo bien, ¿y tú?", "El sábado voy al cine.", "Me gusta mucho la música."],
            systemPrompt: "Ти друг. Спілкуйся невимушено іспанською (A2), ділися планами й питай про життя.",
            topicId: "t_a1_hobby"
        ),
        AIScenario(
            id: "work",
            titleUk: "На роботі",
            titleEs: "En el trabajo",
            descriptionUk: "Домовтеся про зустріч, напишіть короткий лист.",
            level: .a2,
            openingLineEs: "Buenos días, ¿podemos hablar un momento?",
            suggestedReplies: ["Sí, claro. ¿De qué se trata?", "Propongo reunirnos el martes.", "Te envío el correo ahora."],
            systemPrompt: "Ти колега. Спілкуйся діловою іспанською (A2–B1), домовляйся про зустрічі.",
            topicId: "t_a2_work"
        )
    ]
}

// MARK: - Запит і відповідь

struct AIRequest: Hashable {
    var scenario: AIScenario
    var mode: AIConversationMode
    var history: [AIMessage]
    var level: Level
}

struct AIResponse: Hashable {
    var textEs: String
    var translationUk: String
    var corrections: [AICorrection]
    var suggestedReplies: [String]
}

// MARK: - Протокол провайдера

protocol AIProviderProtocol {
    var id: String { get }
    var titleUk: String { get }
    var requiresNetwork: Bool { get }
    func respond(to request: AIRequest, profile: UserProfile) async throws -> AIResponse
}

enum AIProviderError: LocalizedError {
    case notConfigured(String)
    case transport(String)
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let message): return message
        case .transport(let message): return "Помилка мережі: \(message)"
        case .badResponse(let message): return "Несподівана відповідь сервера: \(message)"
        }
    }
}

// MARK: - Локальний провайдер (без інтернету)

/// Працює офлайн: відповідає заготовками сценарію, перевіряє типові помилки
/// та підказує варіанти відповіді. Не потребує ключів і мережі.
struct LocalAIProvider: AIProviderProtocol {
    let id = "local"
    let titleUk = "Офлайн-співрозмовник"
    let requiresNetwork = false

    func respond(to request: AIRequest, profile: UserProfile) async throws -> AIResponse {
        let scenario = request.scenario
        let userMessages = request.history.filter { $0.role == .user }
        let lastUser = userMessages.last?.text ?? ""
        let turn = userMessages.count

        let corrections = LocalAIProvider.corrections(for: lastUser)

        // Репліки сценарію по колу — так діалог не «зависає».
        let lines = Self.script(for: scenario)
        let replyIndex = min(turn, lines.count - 1)
        let reply = lines.isEmpty ? "Muy bien, ¿y tú qué opinas?" : lines[replyIndex]

        let suggestions = turn + 1 < scenario.suggestedReplies.count
            ? [scenario.suggestedReplies[turn + 1]]
            : scenario.suggestedReplies

        return AIResponse(
            textEs: reply,
            translationUk: Self.translationHint(for: reply),
            corrections: corrections,
            suggestedReplies: Array(suggestions.prefix(3))
        )
    }

    /// Набір реплік для кожного сценарію — простий «скрипт» розмови.
    private static func script(for scenario: AIScenario) -> [String] {
        switch scenario.id {
        case "cafe":
            return [
                "¡Hola! Buenos días, ¿qué le pongo?",
                "Muy bien. ¿Lo quiere con leche o solo?",
                "Perfecto. ¿Algo para comer? Las tostadas están muy buenas.",
                "Son cuatro euros con cincuenta. ¿Paga en efectivo o con tarjeta?",
                "Gracias a usted. ¡Que tenga un buen día!"
            ]
        case "shop":
            return [
                "Buenas, ¿le ayudo en algo?",
                "Claro. ¿Qué talla busca?",
                "Ese modelo cuesta veinticinco euros y hay azul y negro.",
                "¿Quiere probárselo? El probador está al fondo.",
                "Muy bien. ¿Se lo envuelvo para regalo?"
            ]
        case "street":
            return [
                "Sí, dime, ¿qué buscas?",
                "El metro está a dos calles, todo recto y luego a la derecha.",
                "No, no está lejos: unos cinco minutos andando.",
                "Puedes coger también el autobús número doce.",
                "De nada, ¡buena suerte!"
            ]
        case "hotel":
            return [
                "Buenas tardes, ¿tiene una reserva?",
                "Perfecto, una habitación doble para dos noches.",
                "El desayuno es de siete a diez y media, en la planta baja.",
                "Sí, hay wifi gratis. La contraseña está en la tarjeta de la habitación.",
                "Aquí tiene su llave. ¡Que disfrute de la estancia!"
            ]
        case "doctor":
            return [
                "Buenos días, cuénteme, ¿qué le pasa?",
                "¿Desde cuándo tiene esos síntomas?",
                "¿Ha tomado algún medicamento?",
                "Le voy a recetar un jarabe. Tómelo cada ocho horas.",
                "Si no mejora en tres días, vuelva, por favor."
            ]
        case "landlord":
            return [
                "Hola, ¿llamas por el piso del centro?",
                "Sí, sigue disponible. Son setecientos euros al mes.",
                "Los gastos de comunidad están incluidos, pero la luz y el agua no.",
                "Necesito un mes de fianza y el contrato es por un año.",
                "Podemos verlo mañana por la tarde, si te viene bien."
            ]
        case "friends":
            return [
                "¡Qué bien verte! ¿Qué tal la semana?",
                "Yo también estoy cansado, pero el fin de semana me apetece salir.",
                "¿Te gusta el cine? Estrenan una película muy buena.",
                "Podemos quedar el sábado a las siete en el centro.",
                "¡Genial! Te escribo mañana para confirmar."
            ]
        case "work":
            return [
                "Buenos días, ¿podemos hablar un momento?",
                "Es sobre el informe del cliente. ¿Lo tienes listo?",
                "Perfecto. ¿Podrías enviarlo antes del jueves?",
                "Podemos reunirnos el martes a las diez para revisarlo.",
                "Gracias, buen trabajo."
            ]
        default:
            return [
                "¡Hola! ¿Cómo estás?",
                "Muy bien, gracias. ¿Y tú?",
                "Cuéntame más, me interesa.",
                "¿Qué te gusta hacer en tu tiempo libre?",
                "¡Qué interesante! Nos vemos pronto."
            ]
        }
    }

    /// Простий переклад-підказка: показуємо українською лише типові фрази.
    private static func translationHint(for line: String) -> String {
        let dictionary: [String: String] = [
            "¡Hola! Buenos días, ¿qué le pongo?": "Доброго дня! Що вам принести?",
            "¿Qué le pongo?": "Що вам принести?",
            "¿Algo para comer?": "Щось поїсти?",
            "¿Paga en efectivo o con tarjeta?": "Платите готівкою чи карткою?",
            "¿Le ayudo en algo?": "Допомогти вам чимось?",
            "¿Qué talla busca?": "Який розмір шукаєте?",
            "¿Quiere probárselo?": "Хочете приміряти?",
            "¿Qué buscas?": "Що шукаєш?",
            "No está lejos.": "Це недалеко.",
            "¿Tiene una reserva?": "У вас є бронювання?",
            "¿Qué le pasa?": "Що вас турбує?",
            "¿Desde cuándo tiene esos síntomas?": "Відколи ці симптоми?",
            "Sigue disponible.": "Ще доступно.",
            "¿Qué tal la semana?": "Як тиждень минув?",
            "¿Podemos hablar un momento?": "Можемо поговорити хвилинку?"
        ]
        return dictionary[line] ?? ""
    }

    /// Перевірка типових помилок україномовних учнів.
    static func corrections(for text: String) -> [AICorrection] {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        var result: [AICorrection] = []
        let lower = text.lowercased()

        // «yo soy 25 años» замість «tengo 25 años»
        if lower.contains("soy") && lower.range(of: "\\bsoy\\s+\\d+", options: .regularExpression) != nil {
            result.append(AICorrection(
                original: text,
                corrected: text.replacingOccurrences(of: "soy", with: "tengo"),
                explanationUk: "Про вік кажемо «tengo … años», а не «soy … años»."
            ))
        }

        // «estoy bien, gracias» — ок; але «soy bien» — ні.
        if lower.contains("soy bien") {
            result.append(AICorrection(
                original: "soy bien",
                corrected: "estoy bien",
                explanationUk: "Стан описуємо через estar: «estoy bien»."
            ))
        }

        // Пропущений перевернутий знак питання.
        if text.contains("?") && !text.contains("¿") {
            result.append(AICorrection(
                original: text,
                corrected: "¿" + text,
                explanationUk: "В іспанській питання відкривається знаком ¿."
            ))
        }

        // «me gusta» + множина.
        if lower.contains("me gusta los") || lower.contains("me gusta las") {
            result.append(AICorrection(
                original: "me gusta los/las",
                corrected: "me gustan los/las",
                explanationUk: "З множиною вживаємо «me gustan»."
            ))
        }

        // «voy a la casa de» — часто плутають із «voy a casa».
        if lower.contains("tengo que ir a la casa") {
            result.append(AICorrection(
                original: "ir a la casa",
                corrected: "ir a casa",
                explanationUk: "«Додому» — «a casa», без артикля."
            ))
        }

        // Артикль перед іменем.
        if lower.range(of: "\\b(el|la)\\s+(señor|señora)\\b", options: .regularExpression) != nil {
            result.append(AICorrection(
                original: "el señor / la señora",
                corrected: "señor / señora",
                explanationUk: "Звертаючись до людини, артикль не вживаємо."
            ))
        }

        return result
    }
}

// MARK: - Віддалений провайдер (OpenAI-сумісний)

/// Надсилає запит на сумісний із OpenAI сервер `/v1/chat/completions`.
/// Працює лише якщо користувач сам увімкнув зовнішній AI і задав endpoint та ключ.
struct RemoteAIProvider: AIProviderProtocol {
    let id = "remote"
    let titleUk = "Зовнішній AI"
    let requiresNetwork = true

    func respond(to request: AIRequest, profile: UserProfile) async throws -> AIResponse {
        let endpoint = profile.aiEndpoint.trimmingCharacters(in: .whitespaces)
        guard !endpoint.isEmpty else {
            throw AIProviderError.notConfigured("Не вказано адресу AI-сервера в налаштуваннях.")
        }
        guard let url = URL(string: endpoint) else {
            throw AIProviderError.notConfigured("Адреса AI-сервера має неприпустимий вигляд.")
        }

        let model = profile.aiModel.trimmingCharacters(in: .whitespaces)
        let body = ChatRequest(
            model: model.isEmpty ? "gpt-4o-mini" : model,
            messages: buildMessages(for: request),
            temperature: 0.7
        )

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !profile.aiApiKey.isEmpty {
            urlRequest.setValue("Bearer \(profile.aiApiKey)", forHTTPHeaderField: "Authorization")
        }
        urlRequest.httpBody = try JSONEncoder().encode(body)
        urlRequest.timeoutInterval = 45

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.transport("немає відповіді")
        }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AIProviderError.badResponse("HTTP \(http.statusCode): \(text.prefix(200))")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = decoded.choices.first?.message.content ?? ""
        guard !text.isEmpty else {
            throw AIProviderError.badResponse("порожня відповідь моделі")
        }

        return AIResponse(
            textEs: text,
            translationUk: "",
            corrections: LocalAIProvider.corrections(for: request.history.last(where: { $0.role == .user })?.text ?? ""),
            suggestedReplies: request.scenario.suggestedReplies
        )
    }

    private func buildMessages(for request: AIRequest) -> [ChatRequest.Message] {
        var messages: [ChatRequest.Message] = []

        let system = """
        \(request.scenario.systemPrompt)
        Рівень учня: \(request.level.rawValue). Відповідай ТІЛЬКИ іспанською.
        Пиши 1–2 короткі речення і завжди додавай коротке зустрічне питання.
        Не використовуй складні конструкції, якщо рівень A0–A1.
        """
        messages.append(.init(role: "system", content: system))

        for message in request.history.suffix(12) {
            switch message.role {
            case .user: messages.append(.init(role: "user", content: message.text))
            case .assistant: messages.append(.init(role: "assistant", content: message.text))
            case .system: continue
            }
        }
        return messages
    }

    private struct ChatRequest: Encodable {
        struct Message: Encodable {
            var role: String
            var content: String
        }
        var model: String
        var messages: [Message]
        var temperature: Double
    }

    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                var content: String
            }
            var message: Message
        }
        var choices: [Choice]
    }
}

// MARK: - Сервіс AI-діалогів

/// Обирає провайдера й веде розмову (відповідник android `AIProviderRegistry`).
@MainActor
final class AIService: ObservableObject {

    @Published private(set) var isThinking = false
    @Published private(set) var lastError: String?

    private let local = LocalAIProvider()
    private let remote = RemoteAIProvider()

    /// Провайдер для поточного профілю.
    func provider(for profile: UserProfile) -> AIProviderProtocol {
        if profile.allowExternalAi, profile.aiProviderId == "remote" {
            return remote
        }
        return local
    }

    func title(for profile: UserProfile) -> String {
        provider(for: profile).titleUk
    }

    /// Отримує відповідь співрозмовника.
    func respond(
        scenario: AIScenario,
        mode: AIConversationMode,
        history: [AIMessage],
        profile: UserProfile
    ) async -> AIResponse? {
        isThinking = true
        lastError = nil
        defer { isThinking = false }

        let request = AIRequest(
            scenario: scenario,
            mode: mode,
            history: history,
            level: profile.level
        )

        do {
            return try await provider(for: profile).respond(to: request, profile: profile)
        } catch {
            lastError = error.localizedDescription
            // Якщо зовнішній провайдер не спрацював — не лишаємо користувача без відповіді.
            if provider(for: profile).requiresNetwork {
                return try? await local.respond(to: request, profile: profile)
            }
            return nil
        }
    }

    /// Локальна перевірка репліки користувача (працює завжди, навіть з зовнішнім AI).
    func corrections(for text: String) -> [AICorrection] {
        LocalAIProvider.corrections(for: text)
    }
}
