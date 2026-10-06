import SwiftUI

/// Кореневий екран: онбординг для нового користувача, далі — вкладки.
struct RootView: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedTab: BottomDestination = .home

    var body: some View {
        Group {
            if app.progress.profile.onboardingDone {
                mainTabs
            } else {
                OnboardingScreen()
            }
        }
        .tint(.krupaBrand)
        .background(Color.krupaBackground.ignoresSafeArea())
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeScreen()
                    .krupaNavigationDestinations()
            }
            .tabItem {
                Label(BottomDestination.home.titleUk, systemImage: BottomDestination.home.systemImageName)
            }
            .tag(BottomDestination.home)

            NavigationStack {
                LearnScreen()
                    .krupaNavigationDestinations()
            }
            .tabItem {
                Label(BottomDestination.learn.titleUk, systemImage: BottomDestination.learn.systemImageName)
            }
            .tag(BottomDestination.learn)

            NavigationStack {
                WordsScreen()
                    .krupaNavigationDestinations()
            }
            .tabItem {
                Label(BottomDestination.words.titleUk, systemImage: BottomDestination.words.systemImageName)
            }
            .tag(BottomDestination.words)

            NavigationStack {
                ProgressScreen()
                    .krupaNavigationDestinations()
            }
            .tabItem {
                Label(BottomDestination.progress.titleUk, systemImage: BottomDestination.progress.systemImageName)
            }
            .tag(BottomDestination.progress)

            NavigationStack {
                SettingsScreen()
                    .krupaNavigationDestinations()
            }
            .tabItem {
                Label(BottomDestination.settings.titleUk, systemImage: BottomDestination.settings.systemImageName)
            }
            .tag(BottomDestination.settings)
        }
    }
}

// MARK: - Маршрутизація

/// Перетворює `AppRoute` на конкретний екран.
struct RouteView: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .session(let topicId):
            SessionScreen(topicId: topicId)
        case .review:
            ReviewScreen()
        case .topicDetail(let topicId):
            TopicDetailScreen(topicId: topicId)
        case .wordDetail(let wordId):
            WordDetailScreen(wordId: wordId)
        case .wordsList(let level):
            WordsListScreen(level: level)
        case .listeningList:
            ListeningListScreen()
        case .listeningDetail(let itemId):
            ListeningDetailScreen(itemId: itemId)
        case .speaking:
            SpeakingScreen()
        case .aiDialog(let scenarioId):
            AIDialogScreen(scenarioId: scenarioId)
        case .grammarList:
            GrammarListScreen()
        case .grammarDetail(let noteId):
            GrammarDetailScreen(noteId: noteId)
        case .progressDetails:
            ProgressDetailsScreen()
        case .diagnostics:
            DiagnosticsScreen()
        case .backup:
            BackupScreen()
        case .about:
            AboutScreen()
        }
    }
}

extension View {
    /// Додає обробку всіх маршрутів застосунку до стеку навігації.
    func krupaNavigationDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            RouteView(route: route)
        }
    }
}
