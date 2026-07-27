import SwiftUI

// MARK: - 팀 포인트 컬러

/// 팀별 화면 강조색. Pencil `팀 포인트 컬러 시스템` 프레임에서 그대로 옮겨온 값으로,
/// 종이 팔레트 위에서 서로 구분되도록 채도를 낮춘 표현용 색이다.
///
/// 구단 공식 색은 `KBOTeam.primaryColorHex`에 그대로 남아 있다. 이 표는 그 데이터를
/// 대체하지 않고, 화면에 칠할 색만 담당한다.
enum VFTeamAccent {
    private static let byTeamID: [String: Color] = [
        "lg-twins": Color(hex: "#C6564E"),
        "doosan-bears": Color(hex: "#2F3D5C"),
        "kiwoom-heroes": Color(hex: "#7E4B52"),
        "ssg-landers": Color(hex: "#D07A6A"),
        "kt-wiz": Color(hex: "#4A4753"),
        "hanwha-eagles": Color(hex: "#C8743C"),
        "samsung-lions": Color(hex: "#4A6C9B"),
        "kia-tigers": Color(hex: "#B23A34"),
        "lotte-giants": Color(hex: "#8390AE"),
        "nc-dinos": Color(hex: "#5E7C93")
    ]

    /// 팀 ID에 해당하는 강조색. 알 수 없는 팀이면 중립 잉크색으로 되돌린다.
    /// 예전 짧은 ID("lg")도 canonical ID로 정규화해 받아들인다.
    static func color(forTeamID teamID: String?) -> Color {
        guard let normalized = KBOSeed.normalizedTeamID(teamID),
              let color = byTeamID[normalized] else {
            return VFColor.bodySecondary
        }
        return color
    }

    /// 표가 담고 있는 팀 ID 전체. 테스트에서 canonical 팀 목록과 대조한다.
    static var coveredTeamIDs: Set<String> { Set(byTeamID.keys) }
}

// MARK: - 팀 뱃지 표기

extension KBOTeam {
    /// 팀 뱃지에 찍는 짧은 표기.
    ///
    /// Pencil 뱃지는 한글 팀이면 한 글자(삼·두·롯·키·한), 로마자 팀이면 약칭
    /// 그대로(LG·KIA·KT·SSG·NC)를 쓴다. 두 경우를 문자 종류로 구분한다.
    var badgeInitial: String {
        let isLatinOnly = shortName.unicodeScalars.allSatisfy { $0.isASCII }
        if isLatinOnly { return shortName }
        return String(shortName.prefix(1))
    }

    /// 화면 강조색. 데이터가 아니라 표현용 값이다.
    var accentColor: Color { VFTeamAccent.color(forTeamID: id) }
}

// MARK: - 테마

struct TeamTheme: Identifiable, Equatable {
    let id: String
    let teamID: String?
    /// 화면 강조색(Pencil 종이 팔레트 기준).
    let primary: Color
    /// 보조 강조색.
    let secondary: Color
    let accent: Color
    /// `primary`를 배경으로 썼을 때 읽히는 글자색.
    let textOnPrimary: Color
    /// 구단 공식 색. 데이터 계약 그대로이며 표현에는 기본으로 쓰지 않는다.
    let officialPrimary: Color

    static let neutral = TeamTheme(
        id: "neutral",
        teamID: nil,
        primary: VFColor.primaryAction,
        secondary: VFColor.deepAccent,
        accent: VFColor.primaryAction,
        textOnPrimary: VFColor.bodyOnDark,
        officialPrimary: VFColor.primaryAction
    )

    init(team: KBOTeam) {
        let accentColor = VFTeamAccent.color(forTeamID: team.id)
        id = "team-\(team.id)"
        teamID = team.id
        primary = accentColor
        secondary = VFColor.deepAccent
        accent = accentColor
        textOnPrimary = accentColor.vfReadableForegroundColor
        officialPrimary = Color(hex: team.primaryColorHex)
    }

    private init(
        id: String,
        teamID: String?,
        primary: Color,
        secondary: Color,
        accent: Color,
        textOnPrimary: Color,
        officialPrimary: Color
    ) {
        self.id = id
        self.teamID = teamID
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.textOnPrimary = textOnPrimary
        self.officialPrimary = officialPrimary
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
