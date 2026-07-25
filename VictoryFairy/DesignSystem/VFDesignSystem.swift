import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum VFColor {
    static let background = Color(hex: "#F7F8FA")
    static let backgroundWarm = Color(hex: "#F7F3EA")
    static let card = Color(hex: "#FFFFFF")
    static let cardTranslucent = Color.white.opacity(0.86)
    static let primaryText = Color(hex: "#111827")
    static let secondaryText = Color(hex: "#6B7280")
    static let tertiaryText = Color(hex: "#9CA3AF")
    static let scoreboardNavy = Color(hex: "#101A2E")
    static let victoryOrange = Color(hex: "#FF6B1A")
    static let grassGreen = Color(hex: "#2E9B63")
    static let winGreen = Color(hex: "#1F9D55")
    static let lossRed = Color(hex: "#E5484D")
    static let drawGray = Color(hex: "#8B95A1")
    static let canceledGray = Color(hex: "#A3AAB5")
    static let mutedLine = Color(hex: "#E5E7EB")
    static let offWhite = Color(hex: "#F7F3EA")
}

enum VFSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum VFTabBarMetrics {
    static let customTabBarHeight: CGFloat = 66
    /// 캡슐 하단과 화면 하단 사이 여백. iOS 26 네이티브 리퀴드 글라스 탭바가
    /// 홈 인디케이터 유무와 무관하게 쓰는 값과 같게 맞춘다.
    static let customTabBarBottomInset: CGFloat = 21
    static let extraBreathingRoom: CGFloat = 20
    /// 캡슐이 화면 하단에서 customTabBarBottomInset만큼 떠 있으므로, 스크롤 콘텐츠는
    /// 캡슐 높이 + 그 여백까지 비켜야 한다. 홈 인디케이터가 없는 기기에서 기존과 같은
    /// extraBreathingRoom이 남고, 있는 기기에서는 그만큼 더 여유가 생긴다.
    static let tabContentBottomPadding = customTabBarHeight + customTabBarBottomInset + extraBreathingRoom
}

enum VFRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 18
    static let lg: CGFloat = 22
    static let xl: CGFloat = 26
    static let pill: CGFloat = 999
}

enum VFTypography {
    static let title = Font.system(size: 27, weight: .bold, design: .rounded)
    static let section = Font.system(size: 20, weight: .bold, design: .rounded)
    static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default).weight(.medium)
    static let number = Font.system(size: 34, weight: .heavy, design: .rounded)
}

struct VFShadow {
    static let cardColor = Color.black.opacity(0.055)
    static let cardRadius: CGFloat = 16
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")))
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    var vfReadableForegroundColor: Color {
        vfIsLight ? VFColor.primaryText : .white
    }

    var vfIsLight: Bool {
        guard let components = vfRGBAComponents else { return false }
        let red = Self.linearized(components.red)
        let green = Self.linearized(components.green)
        let blue = Self.linearized(components.blue)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.52
    }

    private var vfRGBAComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return (red, green, blue, alpha)
        #else
        return nil
        #endif
    }

    private static func linearized(_ value: CGFloat) -> CGFloat {
        value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
}

struct VFCard<Content: View>: View {
    let padding: CGFloat
    var background: Color
    @ViewBuilder var content: Content

    init(
        padding: CGFloat = VFSpacing.md,
        background: Color = VFColor.card,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background.opacity(0.96))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 0.7)
            )
            .shadow(color: VFShadow.cardColor, radius: VFShadow.cardRadius, y: 8)
    }
}

struct VFPrimaryButton: View {
    @Environment(\.appTheme) private var theme
    let title: String
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "plus")
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.textOnPrimary)
        .background(
            LinearGradient(
                colors: [VFColor.victoryOrange, theme.primary.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .shadow(color: VFColor.victoryOrange.opacity(0.18), radius: 10, y: 5)
        .accessibilityLabel(title)
    }
}

struct VFSecondaryButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "arrow.right")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(VFColor.primaryText)
        .background(VFColor.backgroundWarm)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.mutedLine.opacity(0.9), lineWidth: 1)
        )
        .accessibilityLabel(title)
    }
}

struct VFChip: View {
    @Environment(\.appTheme) private var theme
    let title: String
    var isSelected = false
    var tint: Color?

    var body: some View {
        let selectedTint = tint ?? theme.primary
        let selectedTextColor = selectedTint.vfIsLight ? VFColor.primaryText : selectedTint
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(isSelected ? selectedTextColor : VFColor.primaryText)
            .padding(.horizontal, VFSpacing.md)
            .frame(minHeight: 36)
            .background(isSelected ? selectedTint.opacity(0.14) : VFColor.card.opacity(0.94))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? selectedTint.opacity(0.5) : VFColor.mutedLine.opacity(0.95), lineWidth: 1))
    }
}

struct VFScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: [VFColor.backgroundWarm.opacity(0.9), VFColor.background, Color.white.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
    }
}

extension View {
    func vfScreenBackground() -> some View {
        modifier(VFScreenBackground())
    }

    func vfTabContentPadding() -> some View {
        padding(.bottom, VFTabBarMetrics.tabContentBottomPadding)
    }
}
