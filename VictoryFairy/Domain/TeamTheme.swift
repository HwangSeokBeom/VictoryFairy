import SwiftUI

struct TeamTheme: Identifiable, Equatable {
    let id: String
    let teamID: String?
    let primary: Color
    let secondary: Color
    let accent: Color
    let textOnPrimary: Color
    let gradientStart: Color
    let gradientEnd: Color

    static let neutral = TeamTheme(
        id: "neutral",
        teamID: nil,
        primary: VFColor.grassGreen,
        secondary: VFColor.scoreboardNavy,
        accent: VFColor.grassGreen,
        textOnPrimary: .white,
        gradientStart: VFColor.scoreboardNavy,
        gradientEnd: VFColor.grassGreen
    )

    init(team: KBOTeam) {
        id = "team-\(team.id)"
        teamID = team.id
        primary = Color(hex: team.primaryColorHex)
        secondary = Color(hex: team.secondaryColorHex)
        accent = Color(hex: team.accentColorHex)
        textOnPrimary = Color(hex: team.textOnPrimaryHex)
        gradientStart = Color(hex: team.secondaryColorHex)
        gradientEnd = Color(hex: team.primaryColorHex)
    }

    private init(
        id: String,
        teamID: String?,
        primary: Color,
        secondary: Color,
        accent: Color,
        textOnPrimary: Color,
        gradientStart: Color,
        gradientEnd: Color
    ) {
        self.id = id
        self.teamID = teamID
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.textOnPrimary = textOnPrimary
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
    }
}

private struct TeamThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = TeamTheme.neutral
}

extension EnvironmentValues {
    var appTheme: TeamTheme {
        get { self[TeamThemeEnvironmentKey.self] }
        set { self[TeamThemeEnvironmentKey.self] = newValue }
    }
}
