import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum VFColor {
    static let background = Color(hex: "#F6F8FB")
    static let card = Color(hex: "#FFFFFF")
    static let primaryText = Color(hex: "#0E1A2B")
    static let secondaryText = Color(hex: "#5C667A")
    static let scoreboardNavy = Color(hex: "#13233F")
    static let grassGreen = Color(hex: "#2E9B63")
    static let winGreen = Color(hex: "#1F9D55")
    static let lossRed = Color(hex: "#D64545")
    static let drawGray = Color(hex: "#7A8599")
    static let canceledGray = Color(hex: "#9AA3B2")
    static let mutedLine = Color(hex: "#DCE2EC")
    static let offWhite = Color(hex: "#F5F2EA")
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

enum VFRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 22
    static let pill: CGFloat = 999
}

enum VFTypography {
    static let title = Font.system(.largeTitle, design: .rounded).weight(.bold)
    static let section = Font.system(.title3, design: .rounded).weight(.bold)
    static let cardTitle = Font.system(.headline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .default)
    static let caption = Font.system(.caption, design: .default).weight(.medium)
    static let number = Font.system(.largeTitle, design: .rounded).weight(.heavy)
}

struct VFShadow {
    static let cardColor = Color.black.opacity(0.06)
    static let cardRadius: CGFloat = 18
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
    @ViewBuilder var content: Content

    init(padding: CGFloat = VFSpacing.md, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.card)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                    .stroke(VFColor.mutedLine.opacity(0.75), lineWidth: 1)
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
        .background(theme.primary)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
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
        .background(VFColor.offWhite)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
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
        Text(title)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .foregroundStyle(isSelected ? selectedTint.vfReadableForegroundColor : VFColor.primaryText)
            .padding(.horizontal, VFSpacing.md)
            .frame(minHeight: 36)
            .background(isSelected ? selectedTint : VFColor.card)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isSelected ? selectedTint : VFColor.mutedLine, lineWidth: 1))
    }
}

struct VFScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(VFColor.background.ignoresSafeArea())
    }
}

extension View {
    func vfScreenBackground() -> some View {
        modifier(VFScreenBackground())
    }
}
