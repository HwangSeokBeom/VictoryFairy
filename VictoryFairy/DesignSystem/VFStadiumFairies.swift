import SwiftUI

// Stadium Fairy — 9개 구장 + 제네릭 + 미지정.
//
// 개정 Pencil(SHA-256 8e055d8a…3d6db2) `02_StadiumFairy_System` 보드를 옮긴 것이다.
// 좌표·경로·선 두께는 원본 노드에서 그대로 읽었다.
//
// 보드가 정한 규칙: "Stadium Fairy — 9개 구장 · 잉크 라인 디테일 + 구장별 특징
// (항상 구장명과 병기)".
//
// 팀 페어리와 달리 구장 페어리는 **기본 글리프를 그대로 쓴다.** Pencil의
// `StadiumFairy_*`는 `FairyGlyph_Stadium`과 몸통·안테나·눈·입이 완전히 같고,
// 그 위에 구장 특징 한두 개만 얹는다. 그래서 몸통을 다시 그리지 않고
// `VFFairyGlyph(.stadium)`을 합성한다.
//
// 구장 목록과 이름은 `KBOStadiumSeed`가 소유한다. 여기에 두 번째 구장 등록부도,
// 한국어 구장 이름도 두지 않는다.
//
// 그리는 것은 "야구의 기억이 일어난 장소"라는 정체성이지 건축물의 초상이 아니다.
// 실제 어느 구장인지는 **언제나 곁의 글자**가 말한다.

// MARK: - 구장 정체성

/// 무엇을 그릴지 정하는 세 가지 상태.
///
/// "구장 없음"은 여기에 없다. 값이 아예 없으면 구장 페어리를 그리지 않는 것이
/// 기본이므로, 그 경우는 `identity(forRecordedStadiumNamed:)`가 `nil`을 돌려준다.
enum VFStadiumFairyIdentity: Equatable, Hashable {
    /// 등록부가 아는 구장. 연관값은 canonical 구장 ID다.
    case canonical(String)
    /// 구장 맥락은 있지만 특정 구장을 지목할 필요가 없다.
    /// 어느 구장의 대역도 아니며 기본 구장을 뜻하지도 않는다.
    case generic
    /// 값은 있는데 등록부가 풀지 못한다. 이름은 부르는 쪽이 적힌 그대로 보여 준다.
    case unknown

    /// 기록에 적힌 구장 값으로 무엇을 그릴지 정한다.
    ///
    /// - 값이 없거나 공백뿐이면 `nil` — **구장 없음**이라 페어리를 그리지 않는다.
    /// - 등록부가 이름을 알면 그 구장.
    /// - 이름은 있는데 등록부가 모르면 `unknown`. 다른 구장으로 바꾸지 않는다.
    ///
    /// 이름 대조 규칙은 `RecordDetailService`가 이미 쓰는 것과 같다. 응원 팀의 홈
    /// 구장이나 사용자의 주 관람 구장으로 **되돌아가지 않는다** — 이 함수는 기록에
    /// 적힌 값 말고 아무것도 보지 않는다.
    static func identity(forRecordedStadiumNamed name: String?) -> VFStadiumFairyIdentity? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        guard let known = KBOStadiumSeed.all.first(where: { $0.name == trimmed }) else {
            return .unknown
        }
        return .canonical(known.id)
    }

    /// canonical ID로 직접 만든다. 등록부가 모르는 ID는 `unknown`이 된다.
    static func identity(forStadiumID id: String?) -> VFStadiumFairyIdentity? {
        guard let id, !id.isEmpty else { return nil }
        return KBOStadiumSeed.isValid(id: id) ? .canonical(id) : .unknown
    }
}

// MARK: - 구장 특징

/// 구장을 구분하는 잉크 라인 한두 개. 건축물을 그린 것이 아니다.
///
/// 이 값은 **식별자일 뿐 VoiceOver로 읽히지 않는다.** 어느 구장인지는 곁의 글자가
/// 말한다.
enum VFStadiumFairyTrait: String, CaseIterable {
    /// 잠실 — 조명탑 둘.
    case floodlights
    /// 고척 — 돔 아크.
    case domeArc
    /// 인천 SSG — 전광판.
    case scoreboard
    /// 수원 KT — 페넌트.
    case pennant
    /// 대전 한화 — 외야 담장 커브.
    case outfieldWall
    /// 대구 라이온즈파크 — 직선 지붕.
    case straightRoof
    /// 광주 KIA — 관중석 단.
    case seatingTier
    /// 부산 사직 — 파도 라인.
    case waveLine
    /// 창원 NC — 스카이라인 노치.
    case skylineNotch
    /// 제네릭 — 홈플레이트 베이스. 구장 공통 모티프이지 특정 구장이 아니다.
    case homePlate
    /// 미지정 — 특징 없음.
    case none

    /// canonical 구장 ID → 특징. 구장 목록은 `KBOStadiumSeed`가 소유하므로 잇기만 한다.
    private static let byStadiumID: [String: VFStadiumFairyTrait] = [
        "jamsil": .floodlights,
        "gocheok": .domeArc,
        "incheon-ssg": .scoreboard,
        "suwon-kt": .pennant,
        "daejeon-hanwha": .outfieldWall,
        "daegu-lions": .straightRoof,
        "gwangju-kia": .seatingTier,
        "sajik": .waveLine,
        "changwon-nc": .skylineNotch
    ]

    static func trait(for identity: VFStadiumFairyIdentity) -> VFStadiumFairyTrait {
        switch identity {
        case let .canonical(id): byStadiumID[id] ?? .none
        case .generic: .homePlate
        case .unknown: .none
        }
    }

    /// 표가 담고 있는 구장 ID 전체. 테스트가 canonical 목록과 대조한다.
    static var coveredStadiumIDs: Set<String> { Set(byStadiumID.keys) }

    /// 특징이 몸통 위(머리 쪽)에 오는가, 아래(발치)에 오는가.
    /// Pencil이 그렇게 나눠 그렸다.
    var sitsBelowBody: Bool {
        switch self {
        case .outfieldWall, .waveLine, .seatingTier, .homePlate: true
        default: false
        }
    }
}

// MARK: - 크기

/// Pencil이 그린 두 크기.
///
/// 48px은 `StadiumFairy48_Generic`과 `StadiumFairy48_Mono` 둘뿐이다. **구장별 48px
/// 원본은 없다.** 그래서 작은 크기에서는 구장 특징이 사라지고 홈플레이트만 남는다.
/// 구장을 구분하는 것은 언제나 곁의 글자다.
enum VFStadiumFairySize: CaseIterable {
    /// Pencil `StadiumFairy_*`. 96×96.
    case regular
    /// Pencil `StadiumFairy48_*`. 48×48.
    case compact

    var canvas: CGFloat {
        switch self {
        case .regular: 96
        case .compact: 48
        }
    }

    var scale: CGFloat { canvas / 96 }

    /// 기본 글리프의 대응 크기. 몸통·얼굴은 기본 글리프가 그린다.
    var glyphSize: VFFairySize {
        switch self {
        case .regular: .regular
        case .compact: .compact
        }
    }

    /// 96px에서만 구장별 특징을 그린다.
    var showsVenueTrait: Bool {
        switch self {
        case .regular: true
        case .compact: false
        }
    }
}

// MARK: - 외형

/// 표면과 색 조건.
///
/// 라이트와 다크는 같은 아트워크다 — Pencil이 같은 인스턴스를 `paper` 위와 `night`
/// 위에 아무 재정의 없이 놓는다. 모노크롬만 따로 그려 두었다.
enum VFStadiumFairyAppearance: CaseIterable {
    case onLightSurface
    case onDarkSurface
    /// Pencil `StadiumFairy48_Mono`. 잉크 몸에 종이색 얼굴로 뒤집는다.
    case monochrome
}

// MARK: - 선택

/// 선택을 알리는 신호. 어느 것도 색이 아니다.
enum VFStadiumFairyAffordance: String, CaseIterable {
    /// 골드 2pt 테두리. Pencil `StadiumFairy_Badge_Selected`의 stroke.
    case goldBorder
    /// 네이티브 체크 아이콘. **페어리로 바꾸지 않는다.**
    case checkmark
}

/// 선택 상태.
///
/// 팀 페어리와 달리 구장 페어리에는 Pencil이 **선택 변형을 그려 두었다** —
/// `StadiumFairy_Badge_Selected`. 다만 바뀌는 것은 페어리 그림이 아니라 **뱃지**다:
/// 골드 테두리가 생기고 네이티브 체크가 붙는다. 페어리 자체는 그대로다.
enum VFStadiumFairySelectionState: CaseIterable {
    case unselected
    case selected

    /// 이 상태를 알리려면 반드시 있어야 하는 비-색상 신호.
    var requiredAffordances: Set<VFStadiumFairyAffordance> {
        switch self {
        case .unselected: []
        case .selected: [.goldBorder, .checkmark]
        }
    }

    /// 선택을 색 하나로만 알리고 있지 않은가.
    /// 체크는 형태이므로 색을 지워도 남는다.
    var isCommunicatedWithoutColour: Bool {
        self == .unselected || requiredAffordances.contains(.checkmark)
    }
}

// MARK: - 원본 좌표

/// Pencil 96×96 좌표계에서 읽은 구장 특징 값.
///
/// 몸통·안테나·얼굴은 `VFFairyGeometry`가 소유하므로 여기에 없다.
enum VFStadiumFairyGeometry {
    static func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    /// 잠실 — 조명탑 둘. 오른쪽 탑은 캔버스 위로 살짝 넘어간다(원본 y = -2).
    static let floodlightLeftRect = box(22, 2, 9, 17)
    static let floodlightLeftViewBox = box(0, 0, 9, 17)
    static let floodlightLeftPath = "M4.5 17l0-9m-4-4a4 4 0 1 1 8 0 4 4 0 1 1-8 0"
    static let floodlightRightRect = box(37, -2, 9, 19)
    static let floodlightRightViewBox = box(0, 0, 9, 19)
    static let floodlightRightPath = "M4.5 19l0-11m-4-4a4 4 0 1 1 8 0 4 4 0 1 1-8 0"
    static let floodlightStroke: CGFloat = 2.4

    /// 고척 — 돔 아크.
    static let domeArcRect = box(16, 2, 42, 12)
    static let domeArcViewBox = box(0, 0, 42, 12)
    static let domeArcPath = "M0 12c7-11 35-11 42 0"
    static let domeArcStroke: CGFloat = 2.8

    /// 인천 SSG — 전광판 기둥과 보드.
    static let scoreboardPostRect = box(26, 4, 16, 14)
    static let scoreboardPostViewBox = box(0, 0, 16, 15)
    static let scoreboardPostPath = "M8 15l0-5"
    static let scoreboardPostStroke: CGFloat = 2.2
    static let scoreboardPanelRect = box(26, 4, 16, 9)
    static let scoreboardPanelStroke: CGFloat = 1.8

    /// 수원 KT — 페넌트 깃대와 깃발.
    static let pennantPoleRect = box(26, 1, 3, 16)
    static let pennantPoleViewBox = box(0, 0, 3, 16)
    static let pennantPolePath = "M1.5 16l0-15.5"
    static let pennantPoleStroke: CGFloat = 2.2
    static let pennantFlagRect = box(28, 2, 12, 8)
    static let pennantFlagViewBox = box(0, 0, 12, 8)
    static let pennantFlagPath = "M0 0l12 3.5-12 3.5z"
    static let pennantFlagStroke: CGFloat = 1.5

    /// 대전 한화 — 외야 담장 커브.
    static let outfieldWallRect = box(26, 84, 44, 8)
    static let outfieldWallViewBox = box(0, 0, 44, 8)
    static let outfieldWallPath = "M0 2c12 6 32 6 44 0"
    static let outfieldWallStroke: CGFloat = 2.6

    /// 대구 라이온즈파크 — 직선 지붕.
    static let straightRoofRect = box(16, 4, 38, 12)
    static let straightRoofViewBox = box(0, 0, 38, 12)
    static let straightRoofPath = "M0 12l10-10 18 0 10 10"
    static let straightRoofStroke: CGFloat = 2.6

    /// 부산 사직 — 파도 라인.
    static let waveLineRect = box(26, 84, 44, 8)
    static let waveLineViewBox = box(0, 0, 44, 8)
    static let waveLinePath = "M0 5q5.5-5 11 0 5.5 5 11 0 5.5-5 11 0 5.5 5 11 0"
    static let waveLineStroke: CGFloat = 2.6

    /// 창원 NC — 스카이라인 노치.
    static let skylineNotchRect = box(16, 3, 36, 13)
    static let skylineNotchViewBox = box(0, 0, 36, 13)
    static let skylineNotchPath = "M0 13l0-6 11 0 0-5 12 0 0 7 13 0"
    static let skylineNotchStroke: CGFloat = 2.4

    /// 광주 KIA — 관중석 단.
    static let seatingTierRect = box(28, 83, 20, 11)
    static let seatingTierViewBox = box(0, 0, 20, 12)
    static let seatingTierPath = "M0 10l14 0m-11-7l14 0"
    static let seatingTierStroke: CGFloat = 2.6

    /// 제네릭 — 홈플레이트 베이스.
    static let homePlateRect = box(41, 84, 14, 12)
    static let homePlateViewBox = box(0, 0, 14, 13)
    static let homePlatePath = "M0 0l14 0 0 6-7 7-7-7z"
    static let homePlateStroke: CGFloat = 1.8
    /// 48px에서는 홈플레이트가 몸 색으로 칠해지고 외곽선이 사라진다.
    static let compactHomePlateRect = box(41, 84, 14, 12)

    // 뱃지와 행 — Pencil이 그린 합성 변형.
    static let badgePadding = EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 12)
    static let badgeSpacing: CGFloat = 8
    static let badgeCornerRadius: CGFloat = 12
    static let badgeSelectedBorderWidth: CGFloat = 2
    static let badgeCheckSize: CGFloat = 16
    static let badgeNameFontSize: CGFloat = 13

    static let rowWidth: CGFloat = 300
    static let rowPadding = EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 14)
    static let rowSpacing: CGFloat = 10
    static let rowTextSpacing: CGFloat = 1
    static let rowCornerRadius: CGFloat = 12
    static let rowBorderWidth: CGFloat = 1
    static let rowChevronSize: CGFloat = 16
}

// MARK: - 팔레트

/// 역할별 실제 색. 구장 색은 `VFFairyColor.stadium`이 소유한다.
/// 아홉 구장에 아홉 색을 만들지 않는다 — Pencil도 그러지 않는다.
struct VFStadiumFairyPalette {
    let body: Color
    let face: Color
    let trait: Color
    let accentFill: Color
    let diamond: Color
    let plate: Color

    static func resolve(
        identity: VFStadiumFairyIdentity,
        appearance: VFStadiumFairyAppearance
    ) -> VFStadiumFairyPalette {
        switch appearance {
        case .onLightSurface, .onDarkSurface:
            return VFStadiumFairyPalette(
                // 미지정만 중립색이다. 나머지는 모두 같은 구장색을 쓴다.
                body: identity == .unknown ? VFFairyColor.neutral : VFFairyColor.stadium,
                face: VFFairyColor.faceOnDark,
                trait: VFColor.bodyPrimary,
                accentFill: VFColor.attentionAccent,
                diamond: VFColor.attentionAccent,
                plate: VFColor.highlightSurface
            )
        case .monochrome:
            // Pencil `StadiumFairy48_Mono` 그대로. 회색으로 눕히는 것이 아니라
            // 잉크 몸에 종이색 얼굴로 **뒤집는다.** 다이아몬드만 금색으로 남는다.
            return VFStadiumFairyPalette(
                body: VFColor.bodyPrimary,
                face: VFColor.appBackground,
                trait: VFColor.appBackground,
                accentFill: VFColor.appBackground,
                diamond: VFColor.attentionAccent,
                plate: VFColor.bodyPrimary
            )
        }
    }

    /// 기본 글리프에 넘길 칠 이음새.
    var glyphOverride: VFFairyPaletteOverride {
        VFFairyPaletteOverride(body: body, face: face, diamond: diamond)
    }
}

// MARK: - 뷰

/// 구장 정체성을 지닌 Victory Fairy 하나를 그린다.
///
/// 몸통과 얼굴은 `VFFairyGlyph(.stadium)`이 그린다. 이 타입이 더하는 것은 Pencil이
/// 그린 구장 특징 한두 개뿐이다.
///
/// 읽어 줄 문장은 **부르는 쪽이 준다.** 구장 이름을 컴포넌트가 지어내지 않는다.
///
///     VFStadiumFairy(identity: .canonical("jamsil"), accessibilityLabel: "잠실야구장")
///     VFStadiumFairy(identity: .unknown, accessibilityLabel: "등록되지 않은 구장, 군산월명야구장")
struct VFStadiumFairy: View {
    let identity: VFStadiumFairyIdentity
    var size: VFStadiumFairySize
    var appearance: VFStadiumFairyAppearance
    /// VoiceOver가 읽을 문장. 비우면 장식으로 보고 숨긴다.
    var accessibilityLabel: String?

    init(
        identity: VFStadiumFairyIdentity,
        size: VFStadiumFairySize = .regular,
        appearance: VFStadiumFairyAppearance = .onLightSurface,
        accessibilityLabel: String? = nil
    ) {
        self.identity = identity
        self.size = size
        self.appearance = appearance
        self.accessibilityLabel = accessibilityLabel
    }

    /// 이 페어리는 구장 이름과 함께 쓰여야 한다.
    static let pairing: VFFairyPairing = .requiresStadiumName

    var palette: VFStadiumFairyPalette {
        VFStadiumFairyPalette.resolve(identity: identity, appearance: appearance)
    }

    /// 이 크기에서 실제로 그려지는 특징.
    /// 48px에서는 구장별 특징이 사라지고, 미지정을 뺀 나머지는 홈플레이트만 남는다.
    var renderedTrait: VFStadiumFairyTrait {
        let authored = VFStadiumFairyTrait.trait(for: identity)
        guard size.showsVenueTrait else {
            return identity == .unknown ? .none : .homePlate
        }
        return authored
    }

    var body: some View {
        let palette = self.palette
        ZStack(alignment: .topLeading) {
            VFFairyGlyph(
                .stadium,
                size: size.glyphSize,
                paletteOverride: palette.glyphOverride
            )
            trait(palette: palette)
        }
        .frame(width: size.canvas, height: size.canvas, alignment: .topLeading)
        .modifier(VFStadiumFairyAccessibility(label: accessibilityLabel))
    }

    // MARK: 구장 특징

    @ViewBuilder
    private func trait(palette: VFStadiumFairyPalette) -> some View {
        let g = VFStadiumFairyGeometry.self
        let s = size.scale
        switch renderedTrait {
        case .none:
            EmptyView()
        case .floodlights:
            stroked(g.floodlightLeftPath, g.floodlightLeftViewBox, palette.trait, g.floodlightStroke)
                .place(g.floodlightLeftRect, s)
            stroked(g.floodlightRightPath, g.floodlightRightViewBox, palette.trait, g.floodlightStroke)
                .place(g.floodlightRightRect, s)
        case .domeArc:
            stroked(g.domeArcPath, g.domeArcViewBox, palette.trait, g.domeArcStroke)
                .place(g.domeArcRect, s)
        case .scoreboard:
            stroked(g.scoreboardPostPath, g.scoreboardPostViewBox, palette.trait, g.scoreboardPostStroke)
                .place(g.scoreboardPostRect, s)
            Rectangle()
                .fill(palette.accentFill)
                .overlay(Rectangle().stroke(palette.trait, lineWidth: g.scoreboardPanelStroke))
                .place(g.scoreboardPanelRect, s)
        case .pennant:
            stroked(g.pennantPolePath, g.pennantPoleViewBox, palette.trait, g.pennantPoleStroke)
                .place(g.pennantPoleRect, s)
            filled(g.pennantFlagPath, g.pennantFlagViewBox, palette.accentFill, palette.trait, g.pennantFlagStroke)
                .place(g.pennantFlagRect, s)
        case .outfieldWall:
            stroked(g.outfieldWallPath, g.outfieldWallViewBox, palette.trait, g.outfieldWallStroke)
                .place(g.outfieldWallRect, s)
        case .straightRoof:
            stroked(g.straightRoofPath, g.straightRoofViewBox, palette.trait, g.straightRoofStroke)
                .place(g.straightRoofRect, s)
        case .waveLine:
            stroked(g.waveLinePath, g.waveLineViewBox, palette.trait, g.waveLineStroke)
                .place(g.waveLineRect, s)
        case .skylineNotch:
            stroked(g.skylineNotchPath, g.skylineNotchViewBox, palette.trait, g.skylineNotchStroke)
                .place(g.skylineNotchRect, s)
        case .seatingTier:
            stroked(g.seatingTierPath, g.seatingTierViewBox, palette.trait, g.seatingTierStroke)
                .place(g.seatingTierRect, s)
        case .homePlate:
            // 96px은 옅은 면에 잉크 외곽선, 48px은 몸 색으로 채우고 외곽선을 뺀다.
            if size.showsVenueTrait {
                filled(g.homePlatePath, g.homePlateViewBox, palette.plate, palette.trait, g.homePlateStroke)
                    .place(g.homePlateRect, s)
            } else {
                VFVectorPath(g.homePlatePath, viewBox: g.homePlateViewBox)
                    .fill(palette.body)
                    .place(g.compactHomePlateRect, s)
            }
        }
    }

    private func stroked(
        _ path: String, _ viewBox: CGRect, _ colour: Color, _ width: CGFloat
    ) -> some View {
        VFVectorPath(path, viewBox: viewBox)
            .stroke(colour, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func filled(
        _ path: String, _ viewBox: CGRect, _ fill: Color, _ stroke: Color, _ width: CGFloat
    ) -> some View {
        VFVectorPath(path, viewBox: viewBox)
            .fill(fill)
            .overlay(
                VFVectorPath(path, viewBox: viewBox)
                    .stroke(stroke, style: StrokeStyle(lineWidth: width, lineJoin: .round))
            )
    }
}

private extension View {
    /// Pencil 96 좌표계의 사각형을 배율에 맞춰 놓는다.
    func place(_ rect: CGRect, _ scale: CGFloat) -> some View {
        frame(width: rect.width * scale, height: rect.height * scale)
            .offset(x: rect.minX * scale, y: rect.minY * scale)
    }
}

// MARK: - 접근성

/// 라벨이 있으면 하나의 요소로 읽고, 없으면 통째로 숨긴다.
///
/// 뱃지나 행 안에서는 곁의 글자가 이미 구장을 말하므로 숨기는 쪽이 맞다.
/// 같은 구장을 두 번 읽지 않는다.
private struct VFStadiumFairyAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
            content.accessibilityElement().accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

// MARK: - 뱃지

/// Pencil `StadiumFairy_Badge` / `StadiumFairy_Badge_Selected`.
///
/// 구장 이름은 **부르는 쪽이 준다.** 이 컴포넌트는 구장을 찾지도, 이름을 지어내지도,
/// 탭을 받지도 않는다. 선택 상태는 골드 테두리와 네이티브 체크로 알린다.
struct VFStadiumFairyBadge: View {
    let identity: VFStadiumFairyIdentity
    /// 화면에 보일 구장 이름. 등록되지 않은 구장이면 기록에 적힌 이름 그대로.
    let stadiumName: String
    var selection: VFStadiumFairySelectionState
    var appearance: VFStadiumFairyAppearance

    init(
        identity: VFStadiumFairyIdentity,
        stadiumName: String,
        selection: VFStadiumFairySelectionState = .unselected,
        appearance: VFStadiumFairyAppearance = .onLightSurface
    ) {
        self.identity = identity
        self.stadiumName = stadiumName
        self.selection = selection
        self.appearance = appearance
    }

    var body: some View {
        let g = VFStadiumFairyGeometry.self
        HStack(spacing: g.badgeSpacing) {
            VFStadiumFairy(identity: identity, size: .compact, appearance: appearance)
            Text(stadiumName)
                // Pencil 13pt 자리. 고정 크기 대신 footnote 역할이라 Dynamic Type을 따른다.
                .font(VFTypography.supporting.weight(.semibold))
                .foregroundStyle(VFColor.supportAccent)
                .fixedSize(horizontal: false, vertical: true)
            if selection == .selected {
                // 네이티브 선택 표시. 페어리로 바꾸지 않는다.
                Image(systemName: "checkmark")
                    .font(.system(size: g.badgeCheckSize * 0.75, weight: .bold))
                    .foregroundStyle(VFFairyColor.victory)
                    .frame(width: g.badgeCheckSize, height: g.badgeCheckSize)
                    .accessibilityHidden(true)
            }
        }
        .padding(g.badgePadding)
        .background(
            RoundedRectangle(cornerRadius: g.badgeCornerRadius, style: .continuous)
                .fill(VFColor.supportAccentPale)
        )
        .overlay(
            RoundedRectangle(cornerRadius: g.badgeCornerRadius, style: .continuous)
                .stroke(
                    selection == .selected ? VFFairyColor.victory : .clear,
                    lineWidth: selection == .selected ? g.badgeSelectedBorderWidth : 0
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 컴팩트 행

/// Pencil `StadiumFairy_Row`.
///
/// 구장 이름과 보조 문구는 부르는 쪽이 준다. 탭 영역·선택 특성·이동은 감싸는 버튼이
/// 가진다. 이 컴포넌트는 그리기만 한다.
struct VFStadiumFairyRow: View {
    let identity: VFStadiumFairyIdentity
    let stadiumName: String
    /// 도시처럼 이름 아래 놓이는 보조 문구. 없으면 줄 자체를 뺀다.
    var supportingText: String?
    var selection: VFStadiumFairySelectionState
    var showsDisclosure: Bool
    var appearance: VFStadiumFairyAppearance

    init(
        identity: VFStadiumFairyIdentity,
        stadiumName: String,
        supportingText: String? = nil,
        selection: VFStadiumFairySelectionState = .unselected,
        showsDisclosure: Bool = true,
        appearance: VFStadiumFairyAppearance = .onLightSurface
    ) {
        self.identity = identity
        self.stadiumName = stadiumName
        self.supportingText = supportingText
        self.selection = selection
        self.showsDisclosure = showsDisclosure
        self.appearance = appearance
    }

    var body: some View {
        let g = VFStadiumFairyGeometry.self
        HStack(spacing: g.rowSpacing) {
            VFStadiumFairy(identity: identity, size: .compact, appearance: appearance)
            VStack(alignment: .leading, spacing: g.rowTextSpacing) {
                Text(stadiumName)
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let supportingText, !supportingText.isEmpty {
                    Text(supportingText)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if selection == .selected {
                Image(systemName: "checkmark")
                    .font(.system(size: g.rowChevronSize * 0.75, weight: .bold))
                    .foregroundStyle(VFFairyColor.victory)
                    .frame(width: g.rowChevronSize, height: g.rowChevronSize)
                    .accessibilityHidden(true)
            } else if showsDisclosure {
                // 네이티브 disclosure. 페어리로 바꾸지 않는다.
                Image(systemName: "chevron.right")
                    .font(.system(size: g.rowChevronSize * 0.75, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
                    .frame(width: g.rowChevronSize, height: g.rowChevronSize)
                    .accessibilityHidden(true)
            }
        }
        .padding(g.rowPadding)
        .frame(minHeight: VFControl.minimumTouchTarget)
        .background(
            RoundedRectangle(cornerRadius: g.rowCornerRadius, style: .continuous)
                .fill(VFColor.elevatedSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: g.rowCornerRadius, style: .continuous)
                .stroke(
                    selection == .selected ? VFFairyColor.victory : VFColor.hairline,
                    lineWidth: selection == .selected
                        ? VFStadiumFairyGeometry.badgeSelectedBorderWidth
                        : VFStadiumFairyGeometry.rowBorderWidth
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 프리뷰

private let previewStadiumIDs = KBOStadiumSeed.all.map(\.id)

#Preview("구장 페어리 96 — 9구장") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewStadiumIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFStadiumFairy(identity: .canonical(id))
                    Text(KBOStadiumSeed.stadium(id: id)?.shortName ?? id)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("제네릭 · 미지정 · 구장 없음") {
    VStack(alignment: .leading, spacing: VFSpacing.xl) {
        HStack(spacing: VFSpacing.md) {
            VFStadiumFairy(identity: .generic)
            Text("제네릭 — 구장 맥락은 있지만 특정 구장은 아니다")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
        }
        HStack(spacing: VFSpacing.md) {
            VFStadiumFairy(identity: .unknown)
            Text("미지정 — 이름은 있는데 등록부가 모른다")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
        }
        HStack(spacing: VFSpacing.md) {
            // 구장 없음: 페어리를 그리지 않는다.
            Color.clear.frame(width: 96, height: 96)
            Text("구장 없음 — 페어리를 그리지 않는다")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodyTertiary)
        }
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}

#Preview("48px — 구장 특징이 사라지고 이름이 말한다") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: VFSpacing.sm)], spacing: VFSpacing.md) {
            ForEach(previewStadiumIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xxs) {
                    VFStadiumFairy(identity: .canonical(id), size: .compact)
                    Text(KBOStadiumSeed.stadium(id: id)?.shortName ?? id)
                        .font(VFTypography.chartLabel)
                        .foregroundStyle(VFColor.bodyTertiary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("뱃지 — 선택과 미선택") {
    VStack(alignment: .leading, spacing: VFSpacing.md) {
        ForEach(previewStadiumIDs.prefix(4), id: \.self) { id in
            let stadium = KBOStadiumSeed.stadium(id: id)
            HStack(spacing: VFSpacing.md) {
                VFStadiumFairyBadge(
                    identity: .canonical(id),
                    stadiumName: stadium?.name ?? id
                )
                VFStadiumFairyBadge(
                    identity: .canonical(id),
                    stadiumName: stadium?.name ?? id,
                    selection: .selected
                )
            }
        }
        VFStadiumFairyBadge(identity: .unknown, stadiumName: "군산월명야구장")
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}

#Preview("컴팩트 행") {
    VStack(spacing: VFSpacing.xs) {
        ForEach(previewStadiumIDs.prefix(5), id: \.self) { id in
            let stadium = KBOStadiumSeed.stadium(id: id)
            VFStadiumFairyRow(
                identity: .canonical(id),
                stadiumName: stadium?.name ?? id,
                supportingText: stadium?.city,
                selection: id == previewStadiumIDs.first ? .selected : .unselected
            )
        }
        VFStadiumFairyRow(
            identity: .unknown,
            stadiumName: "아주 긴 이름을 가진 등록되지 않은 어느 지방 야구장",
            supportingText: nil,
            showsDisclosure: false
        )
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}

#Preview("어두운 표면 — 같은 아트워크") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewStadiumIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFStadiumFairy(identity: .canonical(id), appearance: .onDarkSurface)
                    Text(KBOStadiumSeed.stadium(id: id)?.shortName ?? id)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyOnDark)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.nightSurface)
}

#Preview("모노크롬 — 잉크 몸에 종이 얼굴") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewStadiumIDs + ["generic", "unknown"], id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFStadiumFairy(
                        identity: id == "generic" ? .generic : (id == "unknown" ? .unknown : .canonical(id)),
                        appearance: .monochrome
                    )
                    Text(KBOStadiumSeed.stadium(id: id)?.shortName ?? (id == "generic" ? "제네릭" : "미지정"))
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("큰 글자 행") {
    VStack(spacing: VFSpacing.xs) {
        VFStadiumFairyRow(
            identity: .canonical("gwangju-kia"),
            stadiumName: KBOStadiumSeed.stadium(id: "gwangju-kia")?.name ?? "",
            supportingText: KBOStadiumSeed.stadium(id: "gwangju-kia")?.city,
            selection: .selected
        )
        VFStadiumFairyRow(
            identity: .generic,
            stadiumName: "구장을 골라 주세요",
            supportingText: nil
        )
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
    .environment(\.dynamicTypeSize, .accessibility3)
}
