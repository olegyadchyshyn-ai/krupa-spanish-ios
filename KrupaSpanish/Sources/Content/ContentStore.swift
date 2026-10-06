import Foundation

/// Завантажує контент курсу з JSON-файлів, вбудованих у бандл застосунку,
/// і складає з них один індексований `CourseContent`.
///
/// Файли контенту (`words.a0.json`, `sentences.a1.json`, `grammar.a0a1.json`, …)
/// лежать у теці `Resources/Content` вихідного проєкту й потрапляють у бандл
/// як ресурси. Якщо хоч один файл не читається — решта все одно завантажиться,
/// а проблема поповнить `loadIssues` (застосунок не падає).
final class ContentStore {

    static let shared = ContentStore()

    private(set) var content: CourseContent = .empty
    private(set) var loadIssues: [String] = []
    private(set) var isLoaded = false

    private init() {}

    /// Завантажує контент один раз. Повторні виклики нічого не роблять.
    @discardableResult
    func loadIfNeeded(bundle: Bundle = .main) -> CourseContent {
        if isLoaded { return content }
        return load(bundle: bundle)
    }

    @discardableResult
    func load(bundle: Bundle = .main) -> CourseContent {
        var issues: [String] = []
        let urls = ContentStore.contentFileURLs(in: bundle)

        if urls.isEmpty {
            issues.append("Не знайдено жодного файлу контенту в бандлі застосунку.")
        }

        var words: [Word] = []
        var sentences: [Sentence] = []
        var exercises: [Exercise] = []
        var grammar: [GrammarNote] = []
        var listening: [ListeningItem] = []
        var topics: [Topic] = []
        var version = 0

        let decoder = JSONDecoder()

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = url.lastPathComponent
            do {
                let data = try Data(contentsOf: url)
                let pack = try decoder.decode(ContentPack.self, from: data)
                version = max(version, pack.contentVersion)
                if let value = pack.words { words.append(contentsOf: value) }
                if let value = pack.sentences { sentences.append(contentsOf: value) }
                if let value = pack.exercises { exercises.append(contentsOf: value) }
                if let value = pack.grammar { grammar.append(contentsOf: value) }
                if let value = pack.listening { listening.append(contentsOf: value) }
                if let value = pack.topics { topics.append(contentsOf: value) }
            } catch {
                issues.append("\(name): не вдалося прочитати (\(error))")
            }
        }

        let merged = CourseContent(
            contentVersion: version == 0 ? 1 : version,
            words: ContentStore.deduplicate(words, id: \.id, issues: &issues, label: "слово"),
            sentences: ContentStore.deduplicate(sentences, id: \.id, issues: &issues, label: "речення"),
            exercises: ContentStore.deduplicate(exercises, id: \.id, issues: &issues, label: "вправа"),
            grammar: ContentStore.deduplicate(grammar, id: \.id, issues: &issues, label: "граматика"),
            listening: ContentStore.deduplicate(listening, id: \.id, issues: &issues, label: "аудіювання"),
            topics: ContentStore.deduplicate(topics, id: \.id, issues: &issues, label: "тема")
        )

        issues.append(contentsOf: ContentValidator.validate(merged))

        self.content = merged
        self.loadIssues = issues
        self.isLoaded = true
        return merged
    }

    var summary: String {
        "слів: \(content.words.count), речень: \(content.sentences.count), "
            + "вправ: \(content.exercises.count), граматики: \(content.grammar.count), "
            + "аудіювання: \(content.listening.count), тем: \(content.topics.count)"
    }

    // MARK: - Пошук файлів

    /// Шукає JSON-файли контенту і в корені бандла, і в підтеці `Content`
    /// (структура залежить від того, як Xcode поклав ресурси).
    private static func contentFileURLs(in bundle: Bundle) -> [URL] {
        var result: [URL] = []

        let rootJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        result.append(contentsOf: rootJSON)

        let contentJSON = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Content") ?? []
        result.append(contentsOf: contentJSON)

        let known = ["words", "sentences", "exercises", "grammar", "listening", "topics"]
        var seen = Set<String>()
        return result.filter { url in
            let name = url.lastPathComponent
            let base = name.split(separator: ".").first.map(String.init) ?? name
            guard known.contains(base) else { return false }
            guard !seen.contains(name) else { return false }
            seen.insert(name)
            return true
        }
    }

    private static func deduplicate<T>(
        _ items: [T],
        id: KeyPath<T, String>,
        issues: inout [String],
        label: String
    ) -> [T] {
        var seen = Set<String>()
        var result: [T] = []
        var duplicates = 0
        for item in items {
            let key = item[keyPath: id]
            if seen.contains(key) {
                duplicates += 1
                continue
            }
            seen.insert(key)
            result.append(item)
        }
        if duplicates > 0 {
            issues.append("Дублікатів (\(label)): \(duplicates) — залишено перший варіант.")
        }
        return result
    }
}

/// Перевіряє цілісність контенту й повертає перелік зауважень (не помилок).
enum ContentValidator {

    static func validate(_ content: CourseContent) -> [String] {
        var issues: [String] = []

        let topicIds = Set(content.topics.map(\.id))

        let orphanWords = content.words.filter { !$0.topicId.isEmpty && !topicIds.contains($0.topicId) }
        if !orphanWords.isEmpty {
            issues.append("Слів із невідомою темою: \(orphanWords.count).")
        }

        let emptyTranslations = content.words.filter { $0.translationUk.trimmingCharacters(in: .whitespaces).isEmpty }
        if !emptyTranslations.isEmpty {
            issues.append("Слів без перекладу: \(emptyTranslations.count).")
        }

        let emptyAnswers = content.exercises.filter { $0.answerEs.trimmingCharacters(in: .whitespaces).isEmpty }
        if !emptyAnswers.isEmpty {
            issues.append("Вправ без правильної відповіді: \(emptyAnswers.count).")
        }

        let badChoice = content.exercises.filter { exercise in
            (exercise.kind == .multipleChoice || exercise.kind == .translationEsUk) && exercise.distractors.isEmpty
        }
        if !badChoice.isEmpty {
            issues.append("Вправ із вибором без варіантів: \(badChoice.count).")
        }

        let badListening = content.listening.filter { item in
            item.comprehensionQuestions.contains { question in
                question.options.isEmpty || !question.options.indices.contains(question.correctIndex)
            }
        }
        if !badListening.isEmpty {
            issues.append("Аудіювань із некоректним індексом відповіді: \(badListening.count).")
        }

        for level in Level.allCases where content.topics(level: level).isEmpty {
            issues.append("Немає тем для рівня \(level.rawValue).")
        }

        return issues
    }
}
