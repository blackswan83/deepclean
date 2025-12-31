import SwiftUI

// MARK: - Color Palette
extension Color {
    // Light Mode
    static let paperBackground = Color(hex: "#FAFAFA")
    static let surface = Color(hex: "#FFFFFF")
    static let inkBlack = Color(hex: "#1A1A1A")
    static let stoneGrey = Color(hex: "#6B6B6B")
    static let mist = Color(hex: "#E0E0E0")
    static let ashGrey = Color(hex: "#E5E5E5")

    // Dark Mode
    static let charcoal = Color(hex: "#1C1C1E")
    static let sumiGrey = Color(hex: "#2C2C2E")

    // Accent Colors
    static let terminalGreen = Color(hex: "#00D47E")
    static let phosphorGreen = Color(hex: "#00B86B")
    static let sumiBlack = Color(hex: "#0D0D0D")

    // Status Colors
    static let warningOrange = Color(hex: "#FF9500")
    static let errorRed = Color(hex: "#FF3B30")
    static let successGreen = Color(hex: "#34C759")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Adaptive Colors
struct SumiColors {
    @Environment(\.colorScheme) static var colorScheme

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .charcoal : .paperBackground
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .sumiGrey : .surface
    }

    static func primary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : .inkBlack
    }

    static func secondary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.6) : .stoneGrey
    }

    static func accent(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .phosphorGreen : .terminalGreen
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.1) : .mist
    }
}

// MARK: - Typography
struct SumiTypography {
    // UI Labels (SF Pro Text)
    static let label = Font.system(size: 13, weight: .regular, design: .default)
    static let labelMedium = Font.system(size: 13, weight: .medium, design: .default)
    static let caption = Font.system(size: 11, weight: .regular, design: .default)
    static let title = Font.system(size: 22, weight: .semibold, design: .default)

    // Code/Data (SF Mono)
    static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    static let monoSmall = Font.system(size: 11, weight: .regular, design: .monospaced)
    static let monoLarge = Font.system(size: 15, weight: .regular, design: .monospaced)
    static let monoTitle = Font.system(size: 18, weight: .medium, design: .monospaced)
    static let command = Font.system(size: 24, weight: .light, design: .monospaced)
    static let commandLarge = Font.system(size: 32, weight: .light, design: .monospaced)

    // Status Display
    static let metric = Font.system(size: 28, weight: .medium, design: .monospaced)
    static let metricLabel = Font.system(size: 10, weight: .medium, design: .monospaced)
}

// MARK: - Card Style
struct SumiCardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(SumiColors.surface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(
                color: colorScheme == .dark ? .clear : .black.opacity(0.05),
                radius: 2,
                x: 0,
                y: 1
            )
    }
}

extension View {
    func sumiCard() -> some View {
        modifier(SumiCardStyle())
    }
}

// MARK: - Button Styles
struct SumiPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isEnabled) var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SumiTypography.mono)
            .foregroundStyle(isEnabled ? .white : .gray)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEnabled ? SumiColors.accent(colorScheme) : Color.gray.opacity(0.3))
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SumiSecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SumiTypography.mono)
            .foregroundStyle(SumiColors.accent(colorScheme))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(SumiColors.accent(colorScheme), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct SumiTextButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isAccent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SumiTypography.mono)
            .foregroundStyle(isAccent ? SumiColors.accent(colorScheme) : SumiColors.secondary(colorScheme))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// MARK: - Progress Bar
struct CLIProgressBar: View {
    let progress: Double
    let label: String
    var showPercentage: Bool = true

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
                Spacer()
                if showPercentage {
                    Text("\(Int(progress * 100))%")
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.primary(colorScheme))
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(SumiColors.border(colorScheme))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(SumiColors.accent(colorScheme))
                        .frame(width: geometry.size.width * min(max(progress, 0), 1), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Size Bar
struct SizeBar: View {
    let percentage: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                Rectangle()
                    .fill(color)
                    .frame(width: geometry.size.width * min(max(percentage, 0), 1))
            }
        }
        .frame(height: 8)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Cursor Blink View
struct CursorBlinkView: View {
    @State private var isVisible = true
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Rectangle()
            .fill(SumiColors.accent(colorScheme))
            .frame(width: 8, height: 16)
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    isVisible.toggle()
                }
            }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    enum Status {
        case success, warning, error, info

        var color: Color {
            switch self {
            case .success: return .successGreen
            case .warning: return .warningOrange
            case .error: return .errorRed
            case .info: return .terminalGreen
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }

    let status: Status
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10))
            Text(text)
                .font(SumiTypography.monoSmall)
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(status.color.opacity(0.1))
        )
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(SumiTypography.monoTitle)
                .foregroundStyle(SumiColors.primary(colorScheme))

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            Spacer()
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Metric Card
struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    var trend: Double? = nil

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(SumiColors.accent(colorScheme))

                Text(title)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))

                Spacer()

                if let trend = trend {
                    HStack(spacing: 2) {
                        Image(systemName: trend >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text("\(abs(Int(trend)))%")
                            .font(SumiTypography.monoSmall)
                    }
                    .foregroundStyle(trend >= 0 ? .errorRed : .successGreen)
                }
            }

            Text(value)
                .font(SumiTypography.metric)
                .foregroundStyle(SumiColors.primary(colorScheme))

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }
        }
        .padding(16)
        .sumiCard()
    }
}

// MARK: - List Row Style
struct SumiListRow: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil
    var icon: String? = nil
    var isSelected: Bool = false
    var showArrow: Bool = true

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(SumiColors.accent(colorScheme))
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(SumiTypography.monoSmall)
                        .foregroundStyle(SumiColors.secondary(colorScheme))
                }
            }

            Spacer()

            if let trailing = trailing {
                Text(trailing)
                    .font(SumiTypography.monoSmall)
                    .foregroundStyle(SumiColors.secondary(colorScheme))
            }

            if showArrow {
                Text(isSelected ? ">" : "")
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.accent(colorScheme))
                    .frame(width: 12)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? SumiColors.accent(colorScheme).opacity(0.1) : .clear)
        )
    }
}

// MARK: - Checkbox Style
struct SumiCheckbox: View {
    @Binding var isChecked: Bool
    let label: String

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: { isChecked.toggle() }) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isChecked ? SumiColors.accent(colorScheme) : SumiColors.border(colorScheme), lineWidth: 1.5)
                        .frame(width: 18, height: 18)

                    if isChecked {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(SumiColors.accent(colorScheme))
                            .frame(width: 18, height: 18)

                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(label)
                    .font(SumiTypography.mono)
                    .foregroundStyle(SumiColors.primary(colorScheme))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spinner
struct SumiSpinner: View {
    @State private var rotation: Double = 0
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
            .font(.system(size: 16))
            .foregroundStyle(SumiColors.accent(colorScheme))
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String = "Retry"

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(SumiColors.secondary(colorScheme))

            Text(title)
                .font(SumiTypography.monoTitle)
                .foregroundStyle(SumiColors.primary(colorScheme))

            Text(message)
                .font(SumiTypography.mono)
                .foregroundStyle(SumiColors.secondary(colorScheme))
                .multilineTextAlignment(.center)

            if let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(SumiPrimaryButtonStyle())
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}
