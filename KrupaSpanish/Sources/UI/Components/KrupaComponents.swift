import SwiftUI

// MARK: - Картка

/// Базова поверхня: біла (або темна) картка з заокругленням і тінню.
struct KrupaCard<Content: View>: View {
    var padding: CGFloat = KrupaSpacing.md
    var background: Color = .krupaSurface
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
            .krupaCardShadow()
    }
}

// MARK: - Заголовок секції

struct KrupaSectionHeader: View {
    var title: String
    var subtitle: String?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KrupaSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.krupaBrand)
                    .font(.krupaHeadline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.krupaHeadline)
                    .foregroundStyle(Color.krupaTextPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Кнопки

struct PrimaryActionButton: View {
    var title: String
    var systemImage: String?
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KrupaSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.krupaCallout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Color.white)
            .background(isEnabled ? Color.krupaBrand : Color.krupaTextSecondary.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .krupaButtonShadow()
    }
}

struct SecondaryActionButton: View {
    var title: String
    var systemImage: String?
    var tint: Color = .krupaBrand
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KrupaSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(.krupaCallout)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(tint)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Варіант відповіді

enum AnswerOptionState {
    case idle
    case selected
    case correct
    case wrong

    var borderColor: Color {
        switch self {
        case .idle: return .krupaDivider
        case .selected: return .krupaBrand
        case .correct: return .krupaSuccess
        case .wrong: return .krupaError
        }
    }

    var background: Color {
        switch self {
        case .idle: return .krupaSurface
        case .selected: return .krupaBrand.opacity(0.10)
        case .correct: return .krupaSuccess.opacity(0.14)
        case .wrong: return .krupaError.opacity(0.14)
        }
    }

    var trailingIcon: String? {
        switch self {
        case .idle, .selected: return nil
        case .correct: return "checkmark.circle.fill"
        case .wrong: return "xmark.circle.fill"
        }
    }
}

struct AnswerOptionRow: View {
    var text: String
    var state: AnswerOptionState = .idle
    var subtitle: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KrupaSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.krupaBody)
                        .foregroundStyle(Color.krupaTextPrimary)
                        .multilineTextAlignment(.leading)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.krupaCaption)
                            .foregroundStyle(Color.krupaTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                if let icon = state.trailingIcon {
                    Image(systemName: icon)
                        .foregroundStyle(state.borderColor)
                }
            }
            .padding(KrupaSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(state.background)
            .overlay(
                RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous)
                    .stroke(state.borderColor, lineWidth: state == .idle ? 1 : 1.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Індикатори

struct KrupaProgressBar: View {
    var value: Double
    var tint: Color = .krupaBrand
    var height: CGFloat = 8
    var showsLabel: Bool = false

    private var clamped: Double { min(1, max(0, value)) }

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.krupaSurfaceAlt)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(0, geometry.size.width * clamped))
                }
            }
            .frame(height: height)

            if showsLabel {
                Text("\(Int((clamped * 100).rounded())) %")
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
            }
        }
    }
}

struct LevelBadge: View {
    var level: Level

    var body: some View {
        Text(level.rawValue)
            .font(.krupaSmall)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.forLevel(level))
            .clipShape(Capsule())
    }
}

struct ChipView: View {
    var text: String
    var systemImage: String?
    var tint: Color = .krupaBrand

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(.krupaSmall)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var systemImage: String
    var tint: Color = .krupaBrand

    var body: some View {
        VStack(alignment: .leading, spacing: KrupaSpacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.krupaTitle)
                .foregroundStyle(Color.krupaTextPrimary)
            Text(title)
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
                .lineLimit(2)
        }
        .padding(KrupaSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.krupaSurface)
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
        .krupaCardShadow()
    }
}

struct StreakBadge: View {
    var days: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(days > 0 ? Color.krupaGold : Color.krupaTextSecondary)
            Text("\(days)")
                .font(.krupaCallout)
                .foregroundStyle(Color.krupaTextPrimary)
            Text(days == 1 ? "день" : "днів")
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
        }
        .padding(.horizontal, KrupaSpacing.sm)
        .padding(.vertical, 6)
        .background(Color.krupaSurface)
        .clipShape(Capsule())
        .krupaCardShadow()
    }
}

// MARK: - Поля введення

struct KrupaTextField: View {
    var placeholder: String
    @Binding var text: String
    var isFocused: Bool = false
    var onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.krupaBody)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .onSubmit(onSubmit)
            .padding(KrupaSpacing.sm)
            .background(Color.krupaSurface)
            .overlay(
                RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous)
                    .stroke(Color.krupaDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.buttonRadius, style: .continuous))
    }
}

// MARK: - Пояснення

struct ExplanationBox: View {
    var title: String
    var text: String
    var tint: Color = .krupaBrand
    var systemImage: String = "lightbulb"

    var body: some View {
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: KrupaSpacing.xxs) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                    Text(title)
                        .font(.krupaSmall)
                }
                .foregroundStyle(tint)

                Text(text)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KrupaSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
        }
    }
}

struct EmptyStateView: View {
    var systemImage: String
    var title: String
    var message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: KrupaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.krupaBrand.opacity(0.7))
            Text(title)
                .font(.krupaHeadline)
                .foregroundStyle(Color.krupaTextPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                PrimaryActionButton(title: actionTitle, action: action)
                    .frame(maxWidth: 260)
                    .padding(.top, KrupaSpacing.xs)
            }
        }
        .padding(KrupaSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct LoadingView: View {
    var message: String = "Завантаження…"

    var body: some View {
        VStack(spacing: KrupaSpacing.sm) {
            ProgressView()
                .tint(Color.krupaBrand)
            Text(message)
                .font(.krupaCaption)
                .foregroundStyle(Color.krupaTextSecondary)
        }
        .padding(KrupaSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

struct ErrorBanner: View {
    var message: String
    var retryTitle: String?
    var onRetry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: KrupaSpacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.krupaError)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.krupaCaption)
                    .foregroundStyle(Color.krupaTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let retryTitle, let onRetry {
                    Button(retryTitle, action: onRetry)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaBrand)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(KrupaSpacing.sm)
        .background(Color.krupaError.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
    }
}

// MARK: - Озвучення

/// Кнопка «прослухати» — викликає передану дію (озвучення тексту).
struct SpeakerButton: View {
    var isSpeaking: Bool = false
    var size: CGFloat = 20
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(Color.krupaBrand)
                .padding(8)
                .background(Color.krupaBrand.opacity(0.10))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Прослухати")
    }
}

// MARK: - Кнопки оцінки SRS

struct GradeButtonsRow: View {
    var previews: [GradePreview]
    var onGrade: (Grade) -> Void

    var body: some View {
        HStack(spacing: KrupaSpacing.xs) {
            ForEach(previews) { preview in
                Button {
                    onGrade(preview.grade)
                } label: {
                    VStack(spacing: 2) {
                        Text(preview.grade.symbol)
                            .font(.system(size: 15, weight: .bold))
                        Text(preview.grade.shortTitleUk)
                            .font(.krupaSmall)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(preview.intervalText)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .opacity(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(Color.white)
                    .background(Color.forGrade(preview.grade))
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Рядки списків

struct WordRowView: View {
    var word: Word
    var showsTranslation: Bool = true
    var isLearned: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: KrupaSpacing.sm) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(word.spanishWithArticle)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.krupaTextPrimary)
                    if isLearned {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.krupaSuccess)
                    }
                }
                if showsTranslation {
                    Text(word.translationUk)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                Text(word.partOfSpeech.shortTitleUk)
                    .font(.krupaSmall)
                    .foregroundStyle(Color.krupaTextSecondary)
                if !word.gender.marker.isEmpty {
                    Text(word.gender.marker)
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaBrand)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct TopicCardView: View {
    var topic: Topic
    var fraction: Double
    var wordsCount: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KrupaSpacing.sm) {
                Image(systemName: topic.systemImageName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.krupaBrand)
                    .frame(width: 42, height: 42)
                    .background(Color.krupaBrand.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.chipRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(topic.titleUk)
                            .font(.krupaCallout)
                            .foregroundStyle(Color.krupaTextPrimary)
                            .lineLimit(1)
                        LevelBadge(level: topic.level)
                    }
                    Text(topic.titleEs)
                        .font(.krupaCaption)
                        .foregroundStyle(Color.krupaTextSecondary)
                        .lineLimit(1)
                    if wordsCount > 0 {
                        KrupaProgressBar(value: fraction, height: 5)
                    }
                }

                Spacer(minLength: 0)

                if wordsCount > 0 {
                    Text("\(Int((min(1, max(0, fraction)) * 100).rounded()))%")
                        .font(.krupaSmall)
                        .foregroundStyle(Color.krupaTextSecondary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.krupaTextSecondary)
                }
            }
            .padding(KrupaSpacing.sm)
            .background(Color.krupaSurface)
            .clipShape(RoundedRectangle(cornerRadius: KrupaSpacing.cardRadius, style: .continuous))
            .krupaCardShadow()
        }
        .buttonStyle(.plain)
    }
}
