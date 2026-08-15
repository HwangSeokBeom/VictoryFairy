import SwiftUI

// Victory Fairy 기본 글리프.
//
// 개정 Pencil 원본(SHA-256 8e055d8a…3d6db2)의 `02_VictoryFairy_Glyph_System`과
// `10_Fairy_Validation` 보드를 옮긴 것이다. 좌표·경로·선 두께는 원본 노드에서 그대로
// 읽어 왔고, 눈대중으로 다시 그린 값은 하나도 없다.
//
// 이 파일은 **공유 기반**만 담는다. 팀 페어리·구장 페어리·앱 아이콘·화면 배치는
// 각각 다음 패스의 몫이며, 여기서는 팀이나 구장 이름을 알지 못한다.

// MARK: - 종류

/// Pencil `FairyGlyph_*` 12종.
///
/// 이름은 Pencil 컴포넌트 이름을 그대로 따른다. 이 값은 **식별자일 뿐이며
/// VoiceOver로 읽히지 않는다.** 읽어 줄 문장은 언제나 사용하는 쪽이 정한다.
enum VFFairyKind: String, CaseIterable {
    /// Pencil `FairyGlyph_Base`. 다른 표정의 기준이 되는 기본형.
    case base
    /// Pencil `FairyGlyph_Victory`. 승리.
    case victory
    /// Pencil `FairyGlyph_Success`. 저장 완료.
    case success
    /// Pencil `FairyGlyph_Team`. 팀 정체성 기반형.
    case team
    /// Pencil `FairyGlyph_Stadium`. 구장 정체성 기반형.
    case stadium
    /// Pencil `FairyGlyph_Memory`. 추억.
    case memory
    /// Pencil `FairyGlyph_Loss`. 패배.
    case loss
    /// Pencil `FairyGlyph_Draw`. 무승부.
    case draw
    /// Pencil `FairyGlyph_Cancelled`. 경기 취소.
    case cancelled
    /// Pencil `FairyGlyph_Live`. 경기 중.
    case live
    /// Pencil `FairyGlyph_Empty`. 기록 없음.
    case empty
    /// Pencil `FairyGlyph_Error`. 오류.
    case error

    /// Pencil이 실제로 48px 축소본(`Fairy48_*`)까지 그려 둔 8종.
    ///
    /// 나머지 네 종(base·team·stadium·live)은 96px만 있다. team·stadium의 축소본은
    /// `TeamFairy48`·`StadiumFairy48_*`라는 **다른 컴포넌트**이며 이후 패스에서 다룬다.
    static let pencilCompactKinds: Set<VFFairyKind> = [
        .victory, .loss, .draw, .cancelled, .success, .empty, .error, .memory
    ]

    var hasPencilCompactVariant: Bool { Self.pencilCompactKinds.contains(self) }
}

// MARK: - 의미 결합 규칙

/// 페어리가 혼자서는 뜻을 전하지 못한다는 것을 타입으로 남긴다.
///
/// Pencil `10_Fairy_Validation`은 결과·상태 글리프에 "라벨 병기 필수",
/// 구장 페어리에 "항상 구장명과 병기"를 명시한다. 색과 표정만으로 뜻을 전하면
/// 색약·그레이스케일·VoiceOver에서 의미가 사라지므로, 규칙을 문서가 아니라
/// 코드에 둔다.
enum VFFairyPairing: Equatable {
    /// 장식. 읽어 줄 것이 없다.
    case decorative
    /// 결과·상태. 화면에 읽을 수 있는 문구가 함께 있어야 한다.
    case requiresResultText
    /// 팀 정체성. 팀 이름과 함께 써야 한다.
    case requiresTeamName
    /// 구장 정체성. 구장 이름과 함께 써야 한다.
    case requiresStadiumName
}

extension VFFairyKind {
    /// 이 글리프를 쓸 때 곁에 무엇이 있어야 하는가.
    var pairing: VFFairyPairing {
        switch self {
        case .base: .decorative
        case .team: .requiresTeamName
        case .stadium: .requiresStadiumName
        case .victory, .success, .memory, .loss, .draw, .cancelled, .live, .empty, .error:
            .requiresResultText
        }
    }

    /// 뜻을 지닌 글리프인가. 장식이 아니면 읽어 줄 문장이 필요하다.
    var isMeaningful: Bool { pairing != .decorative }
}

// MARK: - 크기

/// Pencil이 그린 두 가지 크기.
///
/// 48px은 96px의 정확한 절반 배치이지만, **선 두께와 눈 지름은 절반이 아니다.**
/// 그대로 줄이면 선이 사라지고 눈이 점으로 뭉개져서 Pencil이 광학 보정을 해 두었다.
/// 그래서 이 타입은 배치는 비율로, 두께는 원본 값으로 따로 들고 있다.
enum VFFairySize: CaseIterable {
    /// Pencil `FairyGlyph_*`. 96×96.
    case regular
    /// Pencil `Fairy48_*`. 48×48.
    case compact

    /// 그려질 정사각형 한 변.
    var canvas: CGFloat {
        switch self {
        case .regular: 96
        case .compact: 48
        }
    }

    /// 96 기준 좌표를 이 크기로 옮기는 배율.
    var scale: CGFloat { canvas / 96 }

    /// 몸통 외곽선.
    var bodyStroke: CGFloat {
        switch self {
        case .regular: 2.016
        case .compact: 1.2
        }
    }

    /// 안테나 줄기·입·감은 눈처럼 선으로만 그리는 요소.
    var lineStroke: CGFloat {
        switch self {
        case .regular: 2.6
        case .compact: 1.8
        }
    }

    /// 안테나 다이아몬드 외곽선. 두 크기에서 같다.
    var diamondStroke: CGFloat { 1.1 }

    /// 뜬 눈의 지름. 96에서 7, 48에서 4 — 절반(3.5)보다 크다.
    var openEyeDiameter: CGFloat {
        switch self {
        case .regular: 7
        case .compact: 4
        }
    }

    /// 스파크·일시정지 바·펄스 같은 곁들임. Pencil은 48px에서 모두 뺐다.
    var showsAccessory: Bool {
        switch self {
        case .regular: true
        case .compact: false
        }
    }
}

// MARK: - 외형

/// 표면과 색 조건.
///
/// Pencil `10_Fairy_Validation`의 `표면 대비 · 라이트/다크`는 **똑같은 인스턴스를
/// `paper` 위와 `night` 위에 아무 재정의 없이** 나란히 놓는다. 즉 인앱 글리프는
/// 표면에 따라 다시 칠하지 않는다. 두 경우를 굳이 나눠 두는 것은 부르는 쪽의 의도를
/// 드러내기 위해서이고, 실제 팔레트가 같다는 사실은 테스트가 지킨다.
enum VFFairyAppearance: CaseIterable {
    /// 밝은 표면(`paper`) 위.
    case onLightSurface
    /// 어두운 표면(`night`) 위. 라이트와 같은 아트워크를 쓴다.
    case onDarkSurface
    /// 색 없이 실루엣과 표정만 남긴다.
    case monochrome
}

// MARK: - 표정 조각

/// 눈. Pencil은 뜬 눈(원)과 감은 눈(곡선) 두 가지만 쓴다.
enum VFFairyEyes: Equatable {
    case open
    case closed
}

/// 입. Pencil이 실제로 그린 일곱 가지.
enum VFFairyMouth: Equatable {
    /// 기본 미소. `M42 57q6 5 12 0`
    case smile
    /// 활짝 웃는 채운 입. 승리 전용. `M41 55c2 9 12 9 14 0z`
    case filledSmile
    /// 평평한 선. `M42 58l12 0`
    case flat
    /// 옅은 미소. `M43 58q5 3 10 0`
    case gentle
    /// 아쉬운 표정. `M42 60q6-3 12 0`
    case frown
    /// 흔들리는 선. 오류 전용. `M42 58q3-2 6 0 3 2 6 0`
    case wavy
    /// 벌어진 입. 경기 중 전용. 타원.
    case openMouth
}

/// 곁들임. 96px에서만 나타난다.
enum VFFairyAccessory: Equatable {
    case none
    /// 승리 스파크 14×14.
    case victorySpark
    /// 저장 스파크 10×10.
    case successSpark
    /// 일시정지 바 두 개.
    case pauseBars
    /// 라이브 펄스 호.
    case pulse
}

// MARK: - 구성 규격

/// 한 종류의 페어리가 무엇으로 이루어지는지.
struct VFFairySpec: Equatable {
    /// 몸 색.
    let body: Color
    /// 눈·입·안테나 줄기 색.
    let face: Color
    let eyes: VFFairyEyes
    let mouth: VFFairyMouth
    let accessory: VFFairyAccessory
}

extension VFFairyKind {
    /// Pencil 원본에서 읽은 구성. 외형에 따라 색만 갈린다.
    func spec(for appearance: VFFairyAppearance) -> VFFairySpec {
        let base = pencilSpec
        guard appearance == .monochrome else { return base }
        // 모노크롬은 Pencil 앱 아이콘 Monochrome 셀의 규칙(몸과 다이아몬드를 한 톤으로
        // 눕히고 배경이 네거티브 스페이스로 비치게 한다)을 글리프에 옮긴 것이다.
        // 다만 표정은 남긴다. 글리프에서 표정은 장식이 아니라 색을 대신하는
        // 유일한 의미 신호이므로, 지우면 모노크롬을 만든 이유가 사라진다.
        // 몸 톤은 Pencil이 이미 무채색 페어리로 쓰고 있는 `cream`을 그대로 쓴다.
        return VFFairySpec(
            body: VFColor.subtleSurface,
            face: VFColor.bodyTertiary,
            eyes: base.eyes,
            mouth: base.mouth,
            accessory: base.accessory
        )
    }

    /// Pencil 노드에서 그대로 읽은 기본 구성.
    private var pencilSpec: VFFairySpec {
        switch self {
        case .base:
            VFFairySpec(body: VFFairyColor.victory, face: VFFairyColor.faceOnLight,
                        eyes: .open, mouth: .smile, accessory: .none)
        case .victory:
            VFFairySpec(body: VFFairyColor.victory, face: VFFairyColor.faceOnLight,
                        eyes: .open, mouth: .filledSmile, accessory: .victorySpark)
        case .success:
            VFFairySpec(body: VFFairyColor.victory, face: VFFairyColor.faceOnLight,
                        eyes: .open, mouth: .smile, accessory: .successSpark)
        case .team:
            VFFairySpec(body: VFFairyColor.team, face: VFFairyColor.faceOnDark,
                        eyes: .open, mouth: .flat, accessory: .none)
        case .stadium:
            VFFairySpec(body: VFFairyColor.stadium, face: VFFairyColor.faceOnDark,
                        eyes: .open, mouth: .gentle, accessory: .none)
        case .memory:
            VFFairySpec(body: VFFairyColor.memory, face: VFFairyColor.faceOnLight,
                        eyes: .closed, mouth: .gentle, accessory: .none)
        case .loss:
            VFFairySpec(body: VFColor.bodySecondary, face: VFFairyColor.faceOnDark,
                        eyes: .open, mouth: .frown, accessory: .none)
        case .draw:
            VFFairySpec(body: VFFairyColor.neutral, face: VFFairyColor.faceOnLight,
                        eyes: .open, mouth: .flat, accessory: .none)
        case .cancelled:
            VFFairySpec(body: VFFairyColor.neutral, face: VFFairyColor.faceOnLight,
                        eyes: .closed, mouth: .flat, accessory: .pauseBars)
        case .live:
            VFFairySpec(body: VFFairyColor.live, face: VFFairyColor.faceOnDark,
                        eyes: .open, mouth: .openMouth, accessory: .pulse)
        case .empty:
            VFFairySpec(body: VFColor.subtleSurface, face: VFColor.bodyTertiary,
                        eyes: .open, mouth: .flat, accessory: .none)
        case .error:
            VFFairySpec(body: VFFairyColor.concern, face: VFFairyColor.faceOnDark,
                        eyes: .open, mouth: .wavy, accessory: .none)
        }
    }
}

// MARK: - 원본 좌표

/// Pencil 96×96 좌표계에서 읽은 값. 모든 크기가 이 값을 배율로 옮겨 쓴다.
///
/// 사각형은 `(x, y, width, height)`, 경로는 `d` 문자열과 `viewBox`를 원본 그대로 둔다.
/// 다시 그리지 않고 옮겨 적기만 했으므로 테스트가 Pencil 노드 값과 직접 비교할 수 있다.
enum VFFairyGeometry {
    typealias Rect = (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)
    typealias ViewBox = (CGFloat, CGFloat, CGFloat, CGFloat)

    /// 96×96 원본 캔버스.
    static let canvas: CGFloat = 96

    // 몸통
    static let bodyRect: Rect = (17, 16, 63, 64)
    static let bodyViewBox: ViewBox = (17, 16, 63, 64)
    static let bodyPath = "M48 16c19 0 32 12 31 32-1 19-14 32-32 32-17 0-30-14-30-33 0-19 13-31 31-31z"

    // 안테나
    static let antennaStemRect: Rect = (56, 7, 6, 9)
    static let antennaStemViewBox: ViewBox = (56, 7, 6, 9)
    static let antennaStemPath = "M57 16q2-5 4-8.5"

    static let antennaDiamondRect: Rect = (56.5, 0.5, 9, 9)
    static let antennaDiamondViewBox: ViewBox = (56.5, 0.5, 9, 9)
    static let antennaDiamondPath = "M61 0.5l4.5 4.5-4.5 4.5-4.5-4.5z"

    // 눈 — 뜬 눈은 원본 지름 7이지만 크기별 광학 보정을 받는다.
    static let openEyeLeftOrigin = CGPoint(x: 32.5, y: 41)
    static let openEyeRightOrigin = CGPoint(x: 56.5, y: 41)

    static let closedEyeLeftRect: Rect = (31, 42, 10, 5)
    static let closedEyeLeftViewBox: ViewBox = (31, 42, 10, 5)
    static let closedEyeLeftPath = "M31 43q5 4 10 0"

    static let closedEyeRightRect: Rect = (55, 42, 10, 5)
    static let closedEyeRightViewBox: ViewBox = (55, 42, 10, 5)
    static let closedEyeRightPath = "M55 43q5 4 10 0"

    // 입
    static let mouthRect: Rect = (41, 55, 14, 7)
    static let mouthViewBox: ViewBox = (41, 55, 14, 7)
    static let filledMouthRect: Rect = (41, 55, 14, 8)
    static let filledMouthViewBox: ViewBox = (41, 55, 14, 8)
    static let openMouthRect: Rect = (44.5, 53, 7, 8)

    static let smilePath = "M42 57q6 5 12 0"
    static let filledSmilePath = "M41 55c2 9 12 9 14 0z"
    static let flatPath = "M42 58l12 0"
    static let gentlePath = "M43 58q5 3 10 0"
    static let frownPath = "M42 60q6-3 12 0"
    static let wavyPath = "M42 58q3-2 6 0 3 2 6 0"

    // 곁들임
    static let sparkViewBox: ViewBox = (0, 0, 14, 14)
    static let sparkPath = "M7 0l1.6 5.4 5.4 1.6-5.4 1.6-1.6 5.4-1.6-5.4-5.4-1.6 5.4-1.6z"
    static let victorySparkRect: Rect = (8, 12, 14, 14)
    static let successSparkRect: Rect = (12, 16, 10, 10)

    static let pulseViewBox: ViewBox = (0, 0, 14, 14)
    static let pulsePath = "M2 14a12 12 0 0 0 12-12m-7 12a7 7 0 0 0 7-7"
    static let pulseRect: Rect = (76, 14, 12, 12)
    static let pulseStroke: CGFloat = 2.4

    static let pauseBarLeftRect: Rect = (74, 14, 3.5, 12)
    static let pauseBarRightRect: Rect = (81, 14, 3.5, 12)

    /// 몸통이 캔버스 가장자리에서 떨어진 거리. 안테나만 이 여백 위로 올라간다.
    ///
    /// 왼쪽만 17이고 위·오른쪽·아래는 16이다. 대칭이 아닌 것은 실수가 아니라
    /// Pencil의 광학 중심 보정이다 — 안테나가 오른쪽 위로 뻗어 나가므로 몸통을
    /// 0.5pt 오른쪽으로 밀어야 글리프 전체가 가운데 있어 보인다. 핸드오프의
    /// "광학 중심 유지"가 이것을 가리킨다. 대칭으로 고치면 원본과 어긋난다.
    static let bodyInsetLeading: CGFloat = 17
    static let bodyInsetTop: CGFloat = 16
    static let bodyInsetTrailing: CGFloat = 16
    static let bodyInsetBottom: CGFloat = 16
}

// MARK: - 색 이음새

/// 기본 글리프의 색만 부르는 쪽이 바꿀 수 있게 하는 최소 이음새.
///
/// 기하는 그대로 두고 칠만 다르게 하는 파생 컴포넌트가 Pencil에 실제로 있다 —
/// `StadiumFairy_Unknown`은 `FairyGlyph_Stadium`과 같은 몸통·얼굴에 몸 색만
/// 중립으로 바꾼 것이고, `StadiumFairy48_Mono`는 같은 기하를 잉크·종이색으로
/// 뒤집은 것이다. 그런 파생을 위해 몸통을 다시 그리지 않아도 되도록 열어 둔다.
///
/// 지정하지 않은 값은 종류와 외형이 정한 색을 그대로 쓴다. 기본 글리프 스스로는
/// 이 값을 만들지 않으므로, `kind.spec(for:)`의 의미는 바뀌지 않는다.
struct VFFairyPaletteOverride: Equatable {
    var body: Color?
    var face: Color?
    var diamond: Color?

    init(body: Color? = nil, face: Color? = nil, diamond: Color? = nil) {
        self.body = body
        self.face = face
        self.diamond = diamond
    }

    func applied(to spec: VFFairySpec) -> VFFairySpec {
        VFFairySpec(
            body: body ?? spec.body,
            face: face ?? spec.face,
            eyes: spec.eyes,
            mouth: spec.mouth,
            accessory: spec.accessory
        )
    }
}

// MARK: - 뷰

/// Victory Fairy 기본 글리프 하나를 그린다.
///
/// 읽어 줄 문장은 **부르는 쪽이 준다.** 라벨을 주지 않으면 장식으로 보고 VoiceOver에서
/// 숨긴다. 컴포넌트 이름이나 `VFFairyKind`의 원시값이 대신 읽히는 일은 없다.
///
///     VFFairyGlyph(.victory, size: .compact, accessibilityLabel: "승리")
///     VFFairyGlyph(.memory)                       // 장식 — 숨겨진다
struct VFFairyGlyph: View {
    let kind: VFFairyKind
    var size: VFFairySize
    var appearance: VFFairyAppearance
    /// VoiceOver가 읽을 문장. 비우면 장식으로 보고 숨긴다.
    var accessibilityLabel: String?
    /// 기하는 그대로 두고 칠만 바꾸는 파생 컴포넌트를 위한 이음새.
    var paletteOverride: VFFairyPaletteOverride?

    init(
        _ kind: VFFairyKind,
        size: VFFairySize = .regular,
        appearance: VFFairyAppearance = .onLightSurface,
        accessibilityLabel: String? = nil,
        paletteOverride: VFFairyPaletteOverride? = nil
    ) {
        self.kind = kind
        self.size = size
        self.appearance = appearance
        self.accessibilityLabel = accessibilityLabel
        self.paletteOverride = paletteOverride
    }

    var spec: VFFairySpec {
        let base = kind.spec(for: appearance)
        guard let paletteOverride else { return base }
        return paletteOverride.applied(to: base)
    }

    private var scale: CGFloat { size.scale }

    /// 모노크롬에서는 다이아몬드도 한 톤으로 눕는다(Pencil 아이콘 Monochrome 규칙).
    private var diamondFill: Color {
        if let diamond = paletteOverride?.diamond { return diamond }
        return appearance == .monochrome ? VFColor.subtleSurface : VFColor.attentionAccent
    }

    /// 곁들임은 언제나 몸과 같은 색이다.
    private var accessoryColor: Color { spec.body }

    var body: some View {
        ZStack(alignment: .topLeading) {
            bodyShape
            antenna
            eyes
            mouth
            accessory
        }
        .frame(width: size.canvas, height: size.canvas, alignment: .topLeading)
        .modifier(VFFairyAccessibility(label: accessibilityLabel))
    }

    // MARK: 조각

    private var bodyShape: some View {
        let g = VFFairyGeometry.self
        return filled(g.bodyPath, g.bodyViewBox, fill: spec.body,
                      stroke: VFColor.inkOutline, width: size.bodyStroke, join: .round)
            .place(g.bodyRect, scale)
    }

    private var antenna: some View {
        let g = VFFairyGeometry.self
        return ZStack(alignment: .topLeading) {
            stroked(g.antennaStemPath, g.antennaStemViewBox, color: spec.face, width: size.lineStroke)
                .place(g.antennaStemRect, scale)
            filled(g.antennaDiamondPath, g.antennaDiamondViewBox, fill: diamondFill,
                   stroke: VFColor.inkOutline, width: size.diamondStroke, join: .round)
                .place(g.antennaDiamondRect, scale)
        }
    }

    @ViewBuilder
    private var eyes: some View {
        let g = VFFairyGeometry.self
        switch spec.eyes {
        case .open:
            let d = size.openEyeDiameter
            ZStack(alignment: .topLeading) {
                Ellipse().fill(spec.face)
                    .frame(width: d, height: d)
                    .offset(x: g.openEyeLeftOrigin.x * scale, y: g.openEyeLeftOrigin.y * scale)
                Ellipse().fill(spec.face)
                    .frame(width: d, height: d)
                    .offset(x: g.openEyeRightOrigin.x * scale, y: g.openEyeRightOrigin.y * scale)
            }
        case .closed:
            ZStack(alignment: .topLeading) {
                stroked(g.closedEyeLeftPath, g.closedEyeLeftViewBox, color: spec.face, width: size.lineStroke)
                    .place(g.closedEyeLeftRect, scale)
                stroked(g.closedEyeRightPath, g.closedEyeRightViewBox, color: spec.face, width: size.lineStroke)
                    .place(g.closedEyeRightRect, scale)
            }
        }
    }

    @ViewBuilder
    private var mouth: some View {
        let g = VFFairyGeometry.self
        switch spec.mouth {
        case .filledSmile:
            VFVectorPath(g.filledSmilePath, viewBox: g.filledMouthViewBox)
                .fill(spec.face)
                .place(g.filledMouthRect, scale)
        case .openMouth:
            Ellipse()
                .stroke(spec.face, lineWidth: size.lineStroke)
                .place(g.openMouthRect, scale)
        case .smile, .flat, .gentle, .frown, .wavy:
            stroked(strokedMouthPath, g.mouthViewBox, color: spec.face, width: size.lineStroke)
                .place(g.mouthRect, scale)
        }
    }

    private var strokedMouthPath: String {
        let g = VFFairyGeometry.self
        switch spec.mouth {
        case .smile: return g.smilePath
        case .flat: return g.flatPath
        case .gentle: return g.gentlePath
        case .frown: return g.frownPath
        case .wavy: return g.wavyPath
        case .filledSmile, .openMouth: return g.smilePath   // 위에서 따로 그린다
        }
    }

    @ViewBuilder
    private var accessory: some View {
        let g = VFFairyGeometry.self
        if size.showsAccessory {
            switch spec.accessory {
            case .none:
                EmptyView()
            case .victorySpark:
                VFVectorPath(g.sparkPath, viewBox: g.sparkViewBox)
                    .fill(accessoryColor)
                    .place(g.victorySparkRect, scale)
            case .successSpark:
                VFVectorPath(g.sparkPath, viewBox: g.sparkViewBox)
                    .fill(accessoryColor)
                    .place(g.successSparkRect, scale)
            case .pauseBars:
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(accessoryColor).place(g.pauseBarLeftRect, scale)
                    Rectangle().fill(accessoryColor).place(g.pauseBarRightRect, scale)
                }
            case .pulse:
                VFVectorPath(g.pulsePath, viewBox: g.pulseViewBox)
                    .stroke(accessoryColor,
                            style: StrokeStyle(lineWidth: g.pulseStroke * scale, lineCap: .round))
                    .place(g.pulseRect, scale)
            }
        }
    }

    // MARK: 그리기 도우미

    private func stroked(
        _ path: String,
        _ viewBox: VFFairyGeometry.ViewBox,
        color: Color,
        width: CGFloat
    ) -> some View {
        VFVectorPath(path, viewBox: viewBox)
            .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func filled(
        _ path: String,
        _ viewBox: VFFairyGeometry.ViewBox,
        fill: Color,
        stroke: Color,
        width: CGFloat,
        join: CGLineJoin
    ) -> some View {
        VFVectorPath(path, viewBox: viewBox)
            .fill(fill)
            .overlay(
                VFVectorPath(path, viewBox: viewBox)
                    .stroke(stroke, style: StrokeStyle(lineWidth: width, lineJoin: join))
            )
    }
}

// MARK: - 배치

private extension View {
    /// Pencil 96 좌표계의 사각형을 배율에 맞춰 놓는다.
    func place(_ rect: VFFairyGeometry.Rect, _ scale: CGFloat) -> some View {
        frame(width: rect.width * scale, height: rect.height * scale)
            .offset(x: rect.x * scale, y: rect.y * scale)
    }
}

// MARK: - 접근성

/// 라벨이 있으면 하나의 요소로 읽고, 없으면 통째로 숨긴다.
///
/// 기본값이 "숨김"인 것이 중요하다. 라벨을 깜빡한 페어리가 컴포넌트 이름이나
/// 원시값으로 읽히는 일이 생기지 않는다.
private struct VFFairyAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
            content.accessibilityElement().accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

// MARK: - 아이콘 정책

/// 어떤 자리에 페어리를 쓰고 어떤 자리에 쓰지 않는지.
///
/// Pencil `10_Fairy_Validation`의 평가 항목 그대로다 —
/// "유틸리티 아이콘(뒤로/검색/재시도 등)은 네이티브 유지, 화면당 페어리 1~3개 제한".
enum VFFairyIconPolicy {

    /// 페어리로 바꾸면 안 되는 네이티브 동작.
    ///
    /// 이 동작들은 사용자가 시스템 전체에서 익힌 모양이 있고, 캐릭터로 바꾸면
    /// 무엇을 누르는 자리인지 알기 어려워진다. 되돌리기 어려운 동작일수록 더 그렇다.
    static let nativeUtilityActions: Set<String> = [
        "back", "close", "edit", "delete", "settings", "chevron", "overflow",
        "retry", "camera", "photoPicker", "calendarPrevious", "calendarNext",
        "disclosure", "destructiveAction"
    ]

    /// 페어리를 써도 되는 자리.
    static let fairyEligibleRoles: Set<String> = [
        "brandIdentity", "teamIdentity", "stadiumIdentity", "resultIdentity",
        "emotionalMemory", "emptyState", "errorState"
    ]

    /// 이 동작에 페어리를 쓸 수 있는가.
    static func allowsFairy(for action: String) -> Bool {
        !nativeUtilityActions.contains(action)
    }

    /// 한 화면에 두어도 되는 페어리 수의 상한. Pencil 지침 "1~3개".
    static let maximumFairiesPerScreen = 3
    /// 한 화면에서 감정을 전하는 큰 페어리는 하나로 둔다.
    static let maximumEmotionalMomentsPerScreen = 1
}

// MARK: - 프리뷰

#Preview("페어리 글리프 96") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(VFFairyKind.allCases, id: \.self) { kind in
                VStack(spacing: VFSpacing.xs) {
                    VFFairyGlyph(kind)
                    Text(kind.rawValue)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("페어리 글리프 48 — Pencil 축소본 8종") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(VFFairyKind.allCases.filter(\.hasPencilCompactVariant), id: \.self) { kind in
                VStack(spacing: VFSpacing.xs) {
                    VFFairyGlyph(kind, size: .compact)
                    Text(kind.rawValue)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("어두운 표면 — 같은 아트워크") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(VFFairyKind.allCases, id: \.self) { kind in
                VStack(spacing: VFSpacing.xs) {
                    VFFairyGlyph(kind, appearance: .onDarkSurface)
                    Text(kind.rawValue)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyOnDark)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.nightSurface)
}

#Preview("모노크롬 — 색 없이 표정만") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(VFFairyKind.allCases, id: \.self) { kind in
                VStack(spacing: VFSpacing.xs) {
                    VFFairyGlyph(kind, appearance: .monochrome)
                    Text(kind.rawValue)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("소형 사이즈 재검증") {
    VStack(alignment: .leading, spacing: VFSpacing.lg) {
        ForEach([VFFairyKind.victory, .loss, .empty, .error], id: \.self) { kind in
            HStack(alignment: .bottom, spacing: VFSpacing.md) {
                ForEach([CGFloat(60), 40, 29, 20, 16], id: \.self) { side in
                    VStack(spacing: VFSpacing.xxs) {
                        VFFairyGlyph(kind, size: .compact)
                            .scaleEffect(side / 48, anchor: .bottom)
                            .frame(width: side, height: side)
                        Text("\(Int(side))")
                            .font(VFTypography.chartLabel)
                            .foregroundStyle(VFColor.bodyTertiary)
                    }
                }
            }
        }
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}
