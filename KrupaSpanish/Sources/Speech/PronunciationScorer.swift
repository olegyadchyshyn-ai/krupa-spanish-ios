import Foundation

/// Типи проблем вимови (відповідник android `IssueType`).
enum PronunciationIssueType: String, Codable, CaseIterable, Hashable {
    case wrongWord = "WRONG_WORD"
    case missingWord = "MISSING_WORD"
    case extraWord = "EXTRA_WORD"
    case phoneticNear = "PHONETIC_NEAR"
    case swallowedSyllable = "SWALLOWED_SYLLABLE"
    case nothingHeard = "NOTHING_HEARD"
    case bAndV = "B_AND_V"
    case cAndZ = "C_AND_Z"
    case jSound = "J_SOUND"
    case rSound = "R_SOUND"
    case articleAgreement = "ARTICLE_AGREEMENT"

    var titleUk: String {
        switch self {
        case .wrongWord: return "Неправильне слово"
        case .missingWord: return "Пропущене слово"
        case .extraWord: return "Зайве слово"
        case .phoneticNear: return "Неточна вимова"
        case .swallowedSyllable: return "Проковтнутий склад"
        case .nothingHeard: return "Нічого не почуто"
        case .bAndV: return "Звуки b / v"
        case .cAndZ: return "Звуки c / z"
        case .jSound: return "Звук j"
        case .rSound: return "Звук r"
        case .articleAgreement: return "Артикль не узгоджений"
        }
    }

    var adviceUk: String {
        switch self {
        case .wrongWord: return "Спробуйте ще раз — слово розпізнано неправильно."
        case .missingWord: return "Ви пропустили слово. Промовте речення повністю."
        case .extraWord: return "Прозвучало зайве слово."
        case .phoneticNear: return "Майже правильно, але звучання неточне."
        case .swallowedSyllable: return "Промовте повільніше й чіткіше — частину складу не чути."
        case .nothingHeard: return "Нічого не почуто. Перевірте мікрофон і спробуйте знову."
        case .bAndV: return "В іспанській b і v звучать однаково — як [б] на початку слова."
        case .cAndZ: return "c перед e/i та z в Іспанії вимовляються міжзубно — як [θ] (англ. th)."
        case .jSound: return "j вимовляється як хрипкий [х]."
        case .rSound: return "r — одноударний, rr — розкотистий, кілька ударів."
        case .articleAgreement: return "Перевірте артикль: el — чоловічий рід, la — жіночий."
        }
    }
}

/// Одна знайдена проблема вимови.
struct PronunciationIssue: Identifiable, Hashable {
    var id: String { "\(type.rawValue):\(expected)" }
    var type: PronunciationIssueType
    /// Очікуване слово або склад.
    var expected: String
    /// Що почули.
    var heard: String
}

/// Результат оцінки вимови.
struct PronunciationResult: Hashable {
    /// Загальна оцінка 0…100.
    var score: Int
    /// Точність слів 0…100.
    var wordAccuracy: Int
    /// Фонетична близькість 0…100.
    var phoneticScore: Int
    /// Плавність мовлення 0…100.
    var fluency: Int
    /// Що розпізнано.
    var heardText: String
    /// Еталонний текст.
    var expectedText: String
    var issues: [PronunciationIssue]
    /// До трьох порад українською.
    var suggestionsUk: [String]

    var isGood: Bool { score >= 75 }
    var isAcceptable: Bool { score >= 55 }

    /// Короткий відгук для користувача.
    var summaryUk: String {
        switch score {
        case 90...100: return "Відмінна вимова!"
        case 75..<90: return "Добре — дрібні неточності."
        case 55..<75: return "Зрозуміло, але варто потренуватися."
        case 1..<55: return "Спробуйте ще раз, повільніше."
        default: return "Нічого не почуто."
        }
    }

    static func nothingHeard(expected: String) -> PronunciationResult {
        PronunciationResult(
            score: 0,
            wordAccuracy: 0,
            phoneticScore: 0,
            fluency: 0,
            heardText: "",
            expectedText: expected,
            issues: [PronunciationIssue(type: .nothingHeard, expected: expected, heard: "")],
            suggestionsUk: [PronunciationIssueType.nothingHeard.adviceUk]
        )
    }
}

// MARK: - Іспанська фонетика

/// Перетворює іспанський текст на спрощений фонетичний запис українськими
/// літерами — щоб порівнювати звучання, а не написання.
enum SpanishPhonetics {

    /// Правила для диграфів (застосовуються раніше за окремі літери).
    private static let digraphs: [(String, String)] = [
        ("ch", "ч"),
        ("ll", "й"),
        ("qu", "к"),
        ("rr", "р"),
        ("gu", "ґ"),
        ("ce", "θе"),
        ("ci", "θі")
    ]

    private static let letterMap: [Character: String] = [
        "a": "а", "á": "а",
        "e": "е", "é": "е",
        "i": "і", "í": "і", "y": "й",
        "o": "о", "ó": "о",
        "u": "у", "ú": "у", "ü": "у",
        "b": "б", "v": "б",
        "c": "к", "d": "д", "f": "ф", "g": "ґ", "j": "х",
        "k": "к", "l": "л", "m": "м", "n": "н", "ñ": "н",
        "p": "п", "r": "р", "s": "с", "t": "т", "w": "в",
        "z": "θ", "ç": "θ", "h": ""
    ]

    /// Транслітерація: `playa` → `плайа`, `gente` → `хенте`, `cero` → `θеро`.
    static func transliterate(_ text: String) -> String {
        var working = text.lowercased()
        // Прибираємо все, крім літер іспанського алфавіту та пробілів.
        working = working.replacingOccurrences(
            of: "[^a-záéíóúüñç ]",
            with: "",
            options: .regularExpression
        )

        // Специфічні сполучення: g перед e/i — [х], c перед e/i — [θ].
        working = working.replacingOccurrences(of: "gue", with: "ґе")
        working = working.replacingOccurrences(of: "gui", with: "ґі")
        working = working.replacingOccurrences(of: "ge", with: "хе")
        working = working.replacingOccurrences(of: "gi", with: "хі")
        working = working.replacingOccurrences(of: "ce", with: "θе")
        working = working.replacingOccurrences(of: "ci", with: "θі")

        for (from, to) in digraphs {
            working = working.replacingOccurrences(of: from, with: to)
        }

        var result = ""
        for character in working {
            if let mapped = letterMap[character] {
                result.append(mapped)
            } else if character == " " {
                result.append(" ")
            }
            // θ та ґ уже додані правилами вище, решта символів ігнорується.
        }

        // Прибираємо подвійні пробіли.
        return result
            .replacingOccurrences(of: " +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Приблизна кількість складів (за голосними).
    static func syllables(in word: String) -> Int {
        let vowels = Set("aeiouáéíóúü")
        var count = 0
        var previousWasVowel = false
        for character in word.lowercased() {
            let isVowel = vowels.contains(character)
            if isVowel && !previousWasVowel { count += 1 }
            previousWasVowel = isVowel
        }
        return max(1, count)
    }

    /// Схожість двох фонетичних записів (0…1).
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = lhs.replacingOccurrences(of: " ", with: "")
        let b = rhs.replacingOccurrences(of: " ", with: "")
        if a.isEmpty && b.isEmpty { return 1 }
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 0 }
        let distance = AnswerCheck.levenshtein(a, b)
        return max(0, 1 - Double(distance) / Double(longest))
    }
}

// MARK: - Оцінювач

/// Оцінює вимову за формулою оригінального застосунку:
///
/// `score = 0.55 × точність слів + 0.30 × фонетична близькість + 0.15 × плавність`
///
/// Штрафи за слова: пропущене — 1.0, зайве — 0.6, неточне (схожість ≥ 0.72) — 0.45.
enum PronunciationScorer {

    // MARK: Ваги та пороги (як в оригіналі)

    static let penaltyDelete = 1.0
    static let penaltyInsert = 0.6
    static let penaltyPhoneticNear = 0.45
    static let similarityThreshold = 0.72

    static let weightWordAccuracy = 0.55
    static let weightPhonetic = 0.30
    static let weightFluency = 0.15

    /// Пороги темпу мовлення (слів за хвилину → оцінка).
    private static let tempoBands: [(upperBound: Double, score: Double)] = [
        (45, 55),
        (80, 75),
        (190, 100),
        (260, 80)
    ]
    private static let slowestTempoScore: Double = 60
    private static let defaultFluency: Double = 75
    private static let maxRepeatPenalty: Double = 25
    private static let repeatPenaltyStep: Double = 6

    // MARK: - Основна оцінка

    static func score(expected: String, heard: String, durationMs: Int = 0) -> PronunciationResult {
        let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        let heardTrimmed = heard.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !heardTrimmed.isEmpty else {
            return .nothingHeard(expected: expectedTrimmed)
        }

        let expectedWords = words(expectedTrimmed)
        let heardWords = words(heardTrimmed)
        let totalExpected = max(1, expectedWords.count)

        var issues: [PronunciationIssue] = []
        var penalty = 0.0

        // 1. Порівняння слів із вирівнюванням.
        let alignment = align(expected: expectedWords, heard: heardWords)
        for pair in alignment {
            switch pair.kind {
            case .match:
                continue

            case .wrong:
                let similarity = phoneticSimilarity(pair.expected, pair.heard)
                if similarity >= similarityThreshold {
                    issues.append(PronunciationIssue(type: .phoneticNear, expected: pair.expected, heard: pair.heard))
                    penalty += penaltyPhoneticNear
                } else {
                    issues.append(PronunciationIssue(type: .wrongWord, expected: pair.expected, heard: pair.heard))
                    penalty += penaltyDelete
                }

            case .missing:
                issues.append(PronunciationIssue(type: .missingWord, expected: pair.expected, heard: ""))
                penalty += penaltyDelete

            case .extra:
                issues.append(PronunciationIssue(type: .extraWord, expected: "", heard: pair.heard))
                penalty += penaltyInsert
            }
        }

        let wordAccuracy = clampScore(((Double(totalExpected) - penalty) / Double(totalExpected)) * 100)

        // 2. Фонетична близькість усього речення.
        let expectedPhonetic = SpanishPhonetics.transliterate(expectedTrimmed)
        let heardPhonetic = SpanishPhonetics.transliterate(heardTrimmed)
        let phoneticScore = clampScore(SpanishPhonetics.similarity(expectedPhonetic, heardPhonetic) * 100)

        // 3. Плавність: темп і повтори.
        let fluency = fluencyScore(heardWords: heardWords, durationMs: durationMs)

        // 4. Додаткові підказки щодо специфічних звуків.
        appendSoundIssues(expected: expectedTrimmed, heard: heardTrimmed, issues: &issues)
        appendSwallowedSyllableIssue(expectedWords: expectedWords, heardWords: heardWords, issues: &issues)
        if let articleIssue = articleAgreementIssue(expected: expectedWords, heard: heardWords) {
            issues.append(articleIssue)
        }

        let rawScore = weightWordAccuracy * Double(wordAccuracy)
            + weightPhonetic * Double(phoneticScore)
            + weightFluency * fluency

        var finalScore = Int(rawScore.rounded())
        // Ідеальний збіг без зауважень — це 100 незалежно від округлень.
        if alignment.allSatisfy({ $0.kind == .match }) && issues.isEmpty {
            finalScore = 100
        }

        let deduplicated = deduplicate(issues)

        return PronunciationResult(
            score: min(100, max(0, finalScore)),
            wordAccuracy: wordAccuracy,
            phoneticScore: phoneticScore,
            fluency: Int(fluency.rounded()),
            heardText: heardTrimmed,
            expectedText: expectedTrimmed,
            issues: deduplicated,
            suggestionsUk: Array(Set(deduplicated.map { $0.type.adviceUk }).sorted().prefix(3))
        )
    }

    // MARK: - Плавність

    private static func fluencyScore(heardWords: [String], durationMs: Int) -> Double {
        guard durationMs > 0, !heardWords.isEmpty else { return defaultFluency }

        let minutes = Double(durationMs) / 60_000
        guard minutes > 0 else { return defaultFluency }
        let wordsPerMinute = Double(heardWords.count) / minutes

        var tempoScore = slowestTempoScore
        for band in tempoBands where wordsPerMinute < band.upperBound {
            tempoScore = band.score
            break
        }
        if wordsPerMinute >= 260 { tempoScore = slowestTempoScore }

        let repeats = repeatedWordCount(heardWords)
        let repeatPenalty = min(maxRepeatPenalty, Double(repeats) * repeatPenaltyStep)

        return min(100, max(0, tempoScore - repeatPenalty))
    }

    /// Кількість повторів одного слова підряд.
    private static func repeatedWordCount(_ words: [String]) -> Int {
        guard words.count > 1 else { return 0 }
        var repeats = 0
        for index in 1..<words.count where words[index] == words[index - 1] {
            repeats += 1
        }
        return repeats
    }

    // MARK: - Додаткові підказки

    private static func appendSoundIssues(expected: String, heard: String, issues: inout [PronunciationIssue]) {
        let expectedLower = expected.lowercased()
        let heardLower = heard.lowercased()

        if expectedLower.contains("b") || expectedLower.contains("v") {
            let voicedVersion = expectedLower
                .replacingOccurrences(of: "v", with: "b")
            if heardLower == voicedVersion, expectedLower != heardLower {
                issues.append(PronunciationIssue(type: .bAndV, expected: expected, heard: heard))
            }
        }

        if expectedLower.contains("z") || expectedLower.contains("ce") || expectedLower.contains("ci") {
            let seseo = expectedLower
                .replacingOccurrences(of: "z", with: "s")
                .replacingOccurrences(of: "ce", with: "se")
                .replacingOccurrences(of: "ci", with: "si")
            if heardLower == seseo {
                issues.append(PronunciationIssue(type: .cAndZ, expected: expected, heard: heard))
            }
        }

        if expectedLower.contains("j") || expectedLower.contains("ge") || expectedLower.contains("gi") {
            let softened = expectedLower
                .replacingOccurrences(of: "j", with: "h")
                .replacingOccurrences(of: "ge", with: "he")
                .replacingOccurrences(of: "gi", with: "hi")
            if heardLower == softened {
                issues.append(PronunciationIssue(type: .jSound, expected: expected, heard: heard))
            }
        }

        if expectedLower.contains("rr") {
            let simplified = expectedLower.replacingOccurrences(of: "rr", with: "r")
            if heardLower == simplified {
                issues.append(PronunciationIssue(type: .rSound, expected: expected, heard: heard))
            }
        }
    }

    private static func appendSwallowedSyllableIssue(
        expectedWords: [String],
        heardWords: [String],
        issues: inout [PronunciationIssue]
    ) {
        let expectedSyllables = expectedWords.reduce(0) { $0 + SpanishPhonetics.syllables(in: $1) }
        let heardSyllables = heardWords.reduce(0) { $0 + SpanishPhonetics.syllables(in: $1) }
        guard expectedSyllables >= 3 else { return }
        guard Double(heardSyllables) < Double(expectedSyllables) * 0.75 else { return }
        let word = expectedWords.first { SpanishPhonetics.syllables(in: $0) >= 2 } ?? expectedWords.first ?? ""
        issues.append(PronunciationIssue(type: .swallowedSyllable, expected: word, heard: heardWords.joined(separator: " ")))
    }

    private static func articleAgreementIssue(expected: [String], heard: [String]) -> PronunciationIssue? {
        let articles = ["el", "la", "los", "las", "un", "una", "unos", "unas"]
        for (index, word) in expected.enumerated() {
            let lower = word.lowercased()
            guard articles.contains(lower), index < heard.count else { continue }
            let heardArticle = heard[index].lowercased()
            guard articles.contains(heardArticle), heardArticle != lower else { continue }
            if genderOf(lower) != genderOf(heardArticle) {
                return PronunciationIssue(type: .articleAgreement, expected: word, heard: heard[index])
            }
        }
        return nil
    }

    private static func genderOf(_ article: String) -> String {
        switch article {
        case "el", "los", "un", "unos": return "m"
        case "la", "las", "una", "unas": return "f"
        default: return "?"
        }
    }

    // MARK: - Схожість і допоміжне

    /// Схожість двох слів за фонетичним записом (0…1).
    static func phoneticSimilarity(_ lhs: String, _ rhs: String) -> Double {
        SpanishPhonetics.similarity(
            SpanishPhonetics.transliterate(lhs),
            SpanishPhonetics.transliterate(rhs)
        )
    }

    private static func clampScore(_ value: Double) -> Int {
        min(100, max(0, Int(value.rounded())))
    }

    private static func deduplicate(_ issues: [PronunciationIssue]) -> [PronunciationIssue] {
        var seen = Set<String>()
        var result: [PronunciationIssue] = []
        for issue in issues {
            let key = "\(issue.type.rawValue)|\(issue.expected.lowercased())"
            if seen.contains(key) { continue }
            seen.insert(key)
            result.append(issue)
        }
        return result
    }

    private static func words(_ text: String) -> [String] {
        AnswerCheck.normalizeLoose(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Вирівнювання слів

    private enum PairKind {
        case match
        case wrong
        case missing
        case extra
    }

    private struct Pair {
        var kind: PairKind
        var expected: String
        var heard: String
    }

    private static func align(expected: [String], heard: [String]) -> [Pair] {
        let n = expected.count
        let m = heard.count
        var table = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)

        for i in 0...n { table[i][0] = i }
        for j in 0...m { table[0][j] = j }

        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let cost = expected[i - 1].lowercased() == heard[j - 1].lowercased() ? 0 : 1
                    table[i][j] = min(
                        table[i - 1][j] + 1,
                        table[i][j - 1] + 1,
                        table[i - 1][j - 1] + cost
                    )
                }
            }
        }

        var pairs: [Pair] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let cost = expected[i - 1].lowercased() == heard[j - 1].lowercased() ? 0 : 1
                if table[i][j] == table[i - 1][j - 1] + cost {
                    pairs.append(Pair(
                        kind: cost == 0 ? .match : .wrong,
                        expected: expected[i - 1],
                        heard: heard[j - 1]
                    ))
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0, table[i][j] == table[i - 1][j] + 1 {
                pairs.append(Pair(kind: .missing, expected: expected[i - 1], heard: ""))
                i -= 1
                continue
            }
            if j > 0 {
                pairs.append(Pair(kind: .extra, expected: "", heard: heard[j - 1]))
                j -= 1
                continue
            }
            break
        }

        return pairs.reversed()
    }
}
