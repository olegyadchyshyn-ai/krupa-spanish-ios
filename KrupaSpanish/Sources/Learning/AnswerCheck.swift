import Foundation

/// Перевірка відповідей користувача.
///
/// Іспанська має наголоси, діакритику й перевернуті знаки питання, тому
/// порівняння робиться у два етапи: спочатку «точно» (з урахуванням наголосів),
/// потім «мʼяко» (без наголосів, регістру та пунктуації).
enum AnswerCheck {

    enum Result: Equatable {
        /// Повний збіг з урахуванням наголосів.
        case exact
        /// Збіг без урахування наголосів, регістру чи пунктуації.
        case almostExact(missingAccents: Bool)
        /// Відповідь близька до правильної (одруківка).
        case closeEnough(distance: Int)
        /// Неправильна відповідь.
        case wrong

        var isCorrect: Bool {
            switch self {
            case .exact, .closeEnough: return true
            case .almostExact(let missingAccents): return !missingAccents
            case .wrong: return false
            }
        }

        /// Оцінка для SRS: як в оригіналі — або «знаю», або «не знаю».
        var suggestedGrade: Grade? {
            switch self {
            case .exact: return .good
            case .almostExact(let missingAccents): return missingAccents ? nil : .good
            case .closeEnough: return .good
            case .wrong: return nil
            }
        }

        var messageUk: String {
            switch self {
            case .exact: return "Правильно!"
            case .almostExact(true): return "Правильно, але зверніть увагу на наголос."
            case .almostExact(false): return "Правильно."
            case .closeEnough: return "Майже — невеличка одруківка."
            case .wrong: return "Не зовсім."
            }
        }
    }

    /// Порівнює відповідь користувача з еталоном.
    ///
    /// Як в оригіналі: наголоси та діакритика ВАЖЛИВІ (іспанська без них змінює
    /// значення слова), а регістр, пунктуація та зайві пробіли — ні.
    /// - Parameters:
    ///   - user: те, що ввів або склав користувач.
    ///   - expected: правильна відповідь з контенту.
    ///   - allowTypo: дозволити одну одруківку в довгих відповідях
    ///     (розширення порту, увімкнене для диктантів і довгих речень).
    static func check(_ user: String, expected: String, allowTypo: Bool = false) -> Result {
        let userTrimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedTrimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !userTrimmed.isEmpty else { return .wrong }
        guard !expectedTrimmed.isEmpty else { return .wrong }

        if normalizeStrict(userTrimmed) == normalizeStrict(expectedTrimmed) {
            return .exact
        }

        let userLoose = normalizeLoose(userTrimmed)
        let expectedLoose = normalizeLoose(expectedTrimmed)

        if userLoose == expectedLoose {
            return .almostExact(missingAccents: false)
        }

        // Оригінал додатково порівнює рядки без жодного пробілу.
        if userLoose.replacingOccurrences(of: " ", with: "")
            == expectedLoose.replacingOccurrences(of: " ", with: "") {
            return .almostExact(missingAccents: false)
        }

        // Відмінність лише в наголосах — це помилка, але з окремою підказкою.
        if stripAccents(userLoose) == stripAccents(expectedLoose) {
            return .almostExact(missingAccents: true)
        }

        guard allowTypo else { return .wrong }

        let expectedWords = words(expectedLoose)
        guard expectedWords.count >= 3 else { return .wrong }

        let distance = levenshtein(words(userLoose).joined(separator: " "), expectedWords.joined(separator: " "))
        let allowed = expectedWords.joined(separator: " ").count <= 12 ? 1 : 2
        if distance <= allowed {
            return .closeEnough(distance: distance)
        }
        return .wrong
    }

    /// Порівняння для вправ зі складанням речення з токенів — порядок важливий,
    /// але пунктуація ні.
    static func checkTokens(_ userTokens: [String], expected: String) -> Result {
        let joined = userTokens.joined(separator: " ")
        return check(joined, expected: expected, allowTypo: false)
    }

    /// Чи відповідь серед прийнятних варіантів.
    static func check(_ user: String, anyOf expected: [String]) -> Result {
        var best: Result = .wrong
        for variant in expected {
            let result = check(user, expected: variant)
            if result == .exact { return .exact }
            if result.isCorrect, best == .wrong { best = result }
        }
        return best
    }

    // MARK: - Нормалізація

    /// Суворе порівняння: прибираємо зайві пробіли й регістр, наголоси лишаємо.
    static func normalizeStrict(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }

    /// Мʼяке порівняння: без регістру, пунктуації та перевернутих знаків.
    static func normalizeLoose(_ text: String) -> String {
        let punctuation = CharacterSet.punctuationCharacters
            .union(.symbols)
            .subtracting(CharacterSet(charactersIn: "'’"))
        var result = ""
        for scalar in text.lowercased().unicodeScalars {
            if punctuation.contains(scalar) { continue }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                result.append(" ")
                continue
            }
            result.unicodeScalars.append(scalar)
        }
        return result
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Прибирає діакритичні знаки (á → a, ñ → n).
    static func stripAccents(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
    }

    private static func words(_ text: String) -> [String] {
        text.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }

    // MARK: - Відстань Левенштейна

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Схожість двох рядків у відсотках (0…100) — для оцінки вимови.
    static func similarity(_ lhs: String, _ rhs: String) -> Double {
        let a = normalizeLoose(stripAccents(lhs))
        let b = normalizeLoose(stripAccents(rhs))
        guard !a.isEmpty || !b.isEmpty else { return 0 }
        let distance = levenshtein(a, b)
        let longest = max(a.count, b.count)
        guard longest > 0 else { return 0 }
        return max(0, (1 - Double(distance) / Double(longest)) * 100)
    }
}
