import SwiftUI

/// Усі маршрути навігації застосунку (відповідник android `Routes`).
enum AppRoute: Hashable {
    case session(topicId: String?)
    case review
    case topicDetail(String)
    case wordDetail(String)
    case wordsList(Level)
    case listeningList
    case listeningDetail(String)
    case speaking
    case aiDialog(String)
    case grammarList
    case grammarDetail(String)
    case progressDetails
    case diagnostics
    case backup
    case about
}

/// Вкладки нижньої навігації (відповідник android `BottomDestination`).
enum BottomDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case learn
    case words
    case progress
    case settings

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .home: return "Головна"
        case .learn: return "Навчання"
        case .words: return "Слова"
        case .progress: return "Прогрес"
        case .settings: return "Налаштування"
        }
    }

    var systemImageName: String {
        switch self {
        case .home: return "house.fill"
        case .learn: return "book.fill"
        case .words: return "character.book.closed.fill"
        case .progress: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Швидкі дії на головному екрані (відповідник android `SecondaryDestination`).
enum QuickAction: String, CaseIterable, Identifiable, Hashable {
    case listening
    case speaking
    case aiDialog
    case grammar

    var id: String { rawValue }

    var titleUk: String {
        switch self {
        case .listening: return "Аудіювання"
        case .speaking: return "Вимова"
        case .aiDialog: return "Діалог з AI"
        case .grammar: return "Граматика"
        }
    }

    var subtitleUk: String {
        switch self {
        case .listening: return "Слухайте діалоги й відповідайте"
        case .speaking: return "Тренуйте вимову з мікрофоном"
        case .aiDialog: return "Поговоріть іспанською"
        case .grammar: return "Правила з прикладами"
        }
    }

    var systemImageName: String {
        switch self {
        case .listening: return "headphones"
        case .speaking: return "mic.fill"
        case .aiDialog: return "bubble.left.and.bubble.right.fill"
        case .grammar: return "text.book.closed.fill"
        }
    }

    var tint: Color {
        switch self {
        case .listening: return .krupaBrand
        case .speaking: return .krupaSuccess
        case .aiDialog: return .krupaGold
        case .grammar: return .krupaBrandDark
        }
    }

    var route: AppRoute {
        switch self {
        case .listening: return .listeningList
        case .speaking: return .speaking
        case .aiDialog: return .aiDialog(AIScenario.all.first?.id ?? "cafe")
        case .grammar: return .grammarList
        }
    }
}
