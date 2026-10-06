import SwiftUI
import UIKit

// MARK: - Кольори

/// Палітра застосунку. Базовий колір бренду взято з іконки android-версії (#C1272D),
/// решта — похідні відтінки з підтримкою світлої та темної тем.
extension Color {

    /// Основний акцент (червоний бренду).
    static let krupaBrand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.878, green: 0.290, blue: 0.333, alpha: 1)
            : UIColor(red: 0.757, green: 0.153, blue: 0.176, alpha: 1)
    })

    /// Темніший відтінок акценту — для градієнтів і натискань.
    static let krupaBrandDark = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.686, green: 0.180, blue: 0.216, alpha: 1)
            : UIColor(red: 0.478, green: 0.086, blue: 0.106, alpha: 1)
    })

    /// Золотий акцент (герб на іконці — жовтий на червоному).
    static let krupaGold = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.976, green: 0.784, blue: 0.286, alpha: 1)
            : UIColor(red: 0.902, green: 0.663, blue: 0.157, alpha: 1)
    })

    /// Тло екрана.
    static let krupaBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.071, green: 0.071, blue: 0.078, alpha: 1)
            : UIColor(red: 0.969, green: 0.965, blue: 0.961, alpha: 1)
    })

    /// Тло карток і панелей.
    static let krupaSurface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.125, green: 0.125, blue: 0.137, alpha: 1)
            : UIColor.white
    })

    /// Другорядне тло (секції всередині карток).
    static let krupaSurfaceAlt = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.180, green: 0.180, blue: 0.196, alpha: 1)
            : UIColor(red: 0.949, green: 0.941, blue: 0.933, alpha: 1)
    })

    static let krupaTextPrimary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.949, blue: 0.957, alpha: 1)
            : UIColor(red: 0.109, green: 0.109, blue: 0.117, alpha: 1)
    })

    static let krupaTextSecondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.639, green: 0.639, blue: 0.666, alpha: 1)
            : UIColor(red: 0.419, green: 0.419, blue: 0.447, alpha: 1)
    })

    static let krupaDivider = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.239, green: 0.239, blue: 0.258, alpha: 1)
            : UIColor(red: 0.898, green: 0.890, blue: 0.878, alpha: 1)
    })

    static let krupaSuccess = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.361, green: 0.729, blue: 0.427, alpha: 1)
            : UIColor(red: 0.180, green: 0.545, blue: 0.243, alpha: 1)
    })

    static let krupaWarning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.949, green: 0.694, blue: 0.235, alpha: 1)
            : UIColor(red: 0.796, green: 0.502, blue: 0.078, alpha: 1)
    })

    static let krupaError = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.925, green: 0.341, blue: 0.341, alpha: 1)
            : UIColor(red: 0.776, green: 0.180, blue: 0.180, alpha: 1)
    })

    /// Градієнт шапки головного екрана та онбордингу.
    static let krupaHeaderGradient = LinearGradient(
        colors: [.krupaBrand, .krupaBrandDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Колір для конкретного рівня — допомагає орієнтуватися у списках.
    static func forLevel(_ level: Level) -> Color {
        switch level {
        case .a0: return .krupaSuccess
        case .a1: return .krupaWarning
        case .a2: return .krupaBrand
        }
    }

    /// Колір для оцінки SRS.
    static func forGrade(_ grade: Grade) -> Color {
        switch grade {
        case .again: return .krupaError
        case .hard: return .krupaWarning
        case .good: return .krupaSuccess
        case .easy: return .krupaBrand
        }
    }
}

// MARK: - Типографіка

extension Font {
    static let krupaLargeTitle = Font.system(size: 32, weight: .bold, design: .rounded)
    static let krupaTitle = Font.system(size: 24, weight: .bold, design: .rounded)
    static let krupaHeadline = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let krupaBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let krupaCallout = Font.system(size: 15, weight: .medium, design: .rounded)
    static let krupaCaption = Font.system(size: 13, weight: .regular, design: .rounded)
    static let krupaSmall = Font.system(size: 11, weight: .medium, design: .rounded)
    /// Великий текст іспанського слова на картці.
    static let krupaSpanishWord = Font.system(size: 34, weight: .bold, design: .serif)
    /// Текст прикладу іспанською.
    static let krupaSpanishExample = Font.system(size: 17, weight: .regular, design: .serif)
}

// MARK: - Відступи та радіуси

enum KrupaSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40

    static let cardRadius: CGFloat = 18
    static let buttonRadius: CGFloat = 14
    static let chipRadius: CGFloat = 10
    static let screenPadding: CGFloat = 16
}

// MARK: - Тіні

extension View {
    /// Мʼяка тінь для карток.
    func krupaCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// Тінь для плаваючих кнопок.
    func krupaButtonShadow() -> some View {
        shadow(color: Color.krupaBrand.opacity(0.28), radius: 12, x: 0, y: 6)
    }
}
