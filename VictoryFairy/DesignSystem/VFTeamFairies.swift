import SwiftUI

// Team Fairy — 10개 구단 + 중립.
//
// 개정 Pencil(SHA-256 8e055d8a…3d6db2) `02_TeamFairy_System` 보드의 `TeamFairy_*` 11종과
// `TeamFairy48`을 옮긴 것이다. 좌표·경로·선 두께는 원본 노드에서 그대로 읽었다.
//
// 이것은 기본 글리프 위에 얹는 **의미 래퍼**다. 몸통과 안테나 경로는
// `VFFairyGeometry`의 것을 그대로 쓰고, 구단 정체성 층만 더한다.
//
// 팀 색은 `VFTeamAccent`가 소유한다. 여기에 팀 색 리터럴을 다시 적지 않는다.
// 팀 목록은 `KBOSeed`가 소유한다. 여기에 두 번째 팀 등록부를 만들지 않는다.
//
// 보드가 정한 규칙: "크림 바디 + 팀컬러 캡 + 구단명 유래 무로고 특징".
// 구단 로고도, 공식 마스코트도 옮기지 않는다. 이름에서 온 일반 개념만 쓴다.

// MARK: - 구단 특징

/// 구단 이름에서 온 특징. 로고나 마스코트가 아니라 낱말의 뜻을 그린다.
///
/// 이 값은 **식별자일 뿐 VoiceOver로 읽히지 않는다.** 읽어 줄 팀 이름은 언제나
/// 부르는 쪽이 준다.
enum VFTeamFairyTrait: String, CaseIterable {
    /// 삼성 라이온즈 — 사자 갈기.
    case lionMane
    /// LG 트윈스 — 안테나 둘, 투톤 캡.
    case twinAntenna
    /// 두산 베어스 — 곰 귀와 주둥이.
    case bearFeatures
    /// KIA 타이거즈 — 호랑이 귀·이마 줄무늬·볼 줄.
    case tigerStripes
    /// KT 위즈 — 마법사 모자.
    case wizardHat
    /// SSG 랜더스 — 로켓 핀과 창문.
    case rocketFin
    /// NC 다이노스 — 공룡 스파이크와 등 가시.
    case dinoSpikes
    /// 롯데 자이언츠 — 큰 몸과 하이크라운 캡.
    case giantFrame
    /// 키움 히어로즈 — 히어로 마스크와 망토.
    case heroMask
    /// 한화 이글스 — 독수리 날개와 눈썹.
    case eagleWings
    /// 중립 — 아직 팀을 고르지 않은 상태. 특정 구단을 암시하지 않는다.
    case neutral

    /// canonical 팀 ID → 특징. 팀 목록은 `KBOSeed`가 소유하므로 여기서는 잇기만 한다.
    private static let byTeamID: [String: VFTeamFairyTrait] = [
        "samsung-lions": .lionMane,
        "lg-twins": .twinAntenna,
        "doosan-bears": .bearFeatures,
        "kia-tigers": .tigerStripes,
        "kt-wiz": .wizardHat,
        "ssg-landers": .rocketFin,
        "nc-dinos": .dinoSpikes,
        "lotte-giants": .giantFrame,
        "kiwoom-heroes": .heroMask,
        "hanwha-eagles": .eagleWings
    ]

    /// 팀 ID에 해당하는 특징. 모르는 팀이면 중립으로 돌아간다.
    /// 예전 짧은 ID도 `KBOSeed`가 정규화해 받아들인다.
    static func trait(forTeamID teamID: String?) -> VFTeamFairyTrait {
        guard let normalized = KBOSeed.normalizedTeamID(teamID),
              let trait = byTeamID[normalized] else {
            return .neutral
        }
        return trait
    }

    /// 표가 담고 있는 팀 ID 전체. 테스트가 canonical 목록과 대조한다.
    static var coveredTeamIDs: Set<String> { Set(byTeamID.keys) }

    /// 중립을 뺀 구단 특징.
    static var clubTraits: [VFTeamFairyTrait] { allCases.filter { $0 != .neutral } }
}

// MARK: - 크기

/// Pencil이 그린 두 크기.
///
/// 48px은 배치가 정확히 절반이지만 **선 두께와 눈 지름은 아니다.** 기본 글리프와
/// 같은 광학 보정을 받는다. 게다가 48px에서는 재봉선·버튼·구단 특징이 모두 빠지고
/// **캡 색만 남는다.** 그래서 작은 크기에서는 팀 이름을 곁에 두는 것이 필수다.
enum VFTeamFairySize: CaseIterable {
    /// Pencil `TeamFairy_*`. 96×96.
    case regular
    /// Pencil `TeamFairy48`. 48×48.
    case compact

    var canvas: CGFloat {
        switch self {
        case .regular: 96
        case .compact: 48
        }
    }

    var scale: CGFloat { canvas / 96 }

    /// 몸통과 캡 돔 외곽선.
    var heavyStroke: CGFloat {
        switch self {
        case .regular: 2
        case .compact: 1.4
        }
    }

    /// 캡 챙.
    var brimStroke: CGFloat {
        switch self {
        case .regular: 1.8
        case .compact: 1.2
        }
    }

    /// 안테나 줄기와 입.
    var lineStroke: CGFloat {
        switch self {
        case .regular: 2.4
        case .compact: 1.6
        }
    }

    /// 안테나 다이아몬드.
    var diamondStroke: CGFloat {
        switch self {
        case .regular: 1.3
        case .compact: 1.1
        }
    }

    /// 캡 재봉선.
    var seamStroke: CGFloat { 1.3 }

    /// 캡 버튼.
    var buttonStroke: CGFloat { 1.4 }

    /// 눈 지름. 96에서 7, 48에서 4 — 절반(3.5)보다 크다.
    var eyeDiameter: CGFloat {
        switch self {
        case .regular: 7
        case .compact: 4
        }
    }

    /// 48px에서는 재봉선·버튼·구단 특징이 빠진다. Pencil `TeamFairy48`이 그렇다.
    var showsFineDetail: Bool {
        switch self {
        case .regular: true
        case .compact: false
        }
    }
}

// MARK: - 외형

/// 표면과 색 조건. 기본 글리프와 같은 규칙을 따른다.
///
/// Pencil은 같은 인스턴스를 `paper` 위와 `night` 위에 아무 재정의 없이 놓는다.
/// 팀 페어리도 표면에 따라 다시 칠하지 않는다.
enum VFTeamFairyAppearance: CaseIterable {
    case onLightSurface
    case onDarkSurface
    case monochrome
}

// MARK: - 선택

/// 선택을 알리는 신호. 어느 것도 색이 아니다.
enum VFTeamFairyAffordance: String, CaseIterable {
    /// 네이티브 체크 표시. Pencil `OnboardingTeamCard`의 `체크`,
    /// `08_TeamSelector`의 `circle-check`. **페어리로 바꾸지 않는다.**
    case checkmark
    /// "선택됨" 같은 읽을 수 있는 글자.
    case selectedLabel
    /// 팀 컬러 레일. `08_TeamSelector 선택 팀 프리뷰`의 4pt 세로 막대.
    case accentRail
}

/// 선택 상태.
///
/// **Pencil에는 `TeamFairy_*_Selected` 컴포넌트가 없다.** 구장 페어리에는
/// `StadiumFairy_Badge_Selected`가 따로 있지만 팀 페어리에는 없다. 선택은 페어리
/// 그림이 아니라 **감싸는 카드**가 알린다 — 체크 표시, "선택됨" 글자, 팀 컬러 레일.
///
/// 그래서 이 타입은 그림을 바꾸지 않는다. 대신 감싸는 쪽이 무엇을 반드시 그려야
/// 하는지를 계약으로 남긴다. 색만으로 선택을 알리는 일을 막기 위해서다.
enum VFTeamFairySelection: CaseIterable {
    case unselected
    case selected

    /// 이 상태를 알리려면 반드시 있어야 하는 비-색상 신호.
    var requiredAffordances: Set<VFTeamFairyAffordance> {
        switch self {
        case .unselected: []
        case .selected: [.checkmark]
        }
    }

    /// Pencil이 자리에 따라 덧붙이는 신호. 카드는 라벨을, 프리뷰 패널은 레일을 쓴다.
    var supplementaryAffordances: Set<VFTeamFairyAffordance> {
        switch self {
        case .unselected: []
        case .selected: [.selectedLabel, .accentRail]
        }
    }

    /// 선택을 색 하나로만 알리고 있지 않은가.
    var isCommunicatedWithoutColour: Bool {
        self == .unselected || !requiredAffordances.isEmpty
    }
}

// MARK: - 색 역할

/// 요소가 어떤 의미의 색을 쓰는지. 실제 색은 외형이 정한다.
enum VFTeamFairyPaint: Equatable {
    /// 팀 강조색. 중립이면 `fairyTeam`.
    case accent
    /// 크림 몸통.
    case body
    /// 잉크 외곽선.
    case outline
    /// 눈·입.
    case face
    /// 안테나 다이아몬드.
    case diamond
    /// 흰 표면(두산 주둥이).
    case surface
    /// 팀 강조색 위에 얹는 밝은 면(키움 눈, 두산 귀 안쪽, SSG 창문).
    case onAccent
    /// 칠하지 않음.
    case none
}

// MARK: - 요소

/// 페어리 한 조각. 그리기 전에 목록으로 검사할 수 있도록 값으로 남긴다.
struct VFTeamFairyElement: Equatable {
    enum Shape: Equatable {
        /// SVG 경로와 원본 viewBox.
        case path(String, CGRect)
        case ellipse
        case rectangle
    }

    let name: String
    let shape: Shape
    /// 그려질 사각형. 요소 목록을 만든 크기의 좌표계다.
    let rect: CGRect
    let fill: VFTeamFairyPaint
    let stroke: VFTeamFairyPaint
    let strokeWidth: CGFloat
}

// MARK: - 원본 좌표

/// Pencil 96×96 좌표계에서 읽은 팀 페어리 전용 값.
///
/// 몸통·안테나 줄기·안테나 다이아몬드는 `VFFairyGeometry`의 것을 그대로 쓴다.
/// 여기에는 캡과 구단 특징만 둔다.
enum VFTeamFairyGeometry {
    static func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    // 얼굴 — 기본 글리프보다 2pt 아래에 있다. 캡이 위쪽을 차지하기 때문이다.
    static let eyeLeftOrigin = CGPoint(x: 32.5, y: 43)
    static let eyeRightOrigin = CGPoint(x: 56.5, y: 43)
    static let mouthRect = box(41, 57, 14, 6)
    static let mouthViewBox = box(41, 57, 14, 6)
    /// 48px에서 Pencil이 입 viewBox를 경로에 딱 맞게 좁힌다.
    static let compactMouthViewBox = box(43, 59, 10, 3)
    static let mouthPath = "M43 59q5 3 10 0"

    // 표준 캡
    static let capDomeRect = box(25, 10, 46, 26)
    static let capDomeViewBox = box(25, 10, 46, 26)
    static let capDomePath = "M25 36c2-19 12-26 23-26 11 0 21 7 23 26-12-5-34-5-46 0z"
    static let capSeamRect = box(47, 12, 2, 19)
    static let capSeamViewBox = box(47, 12, 2, 19)
    static let capSeamPath = "M48 12l0 19"
    static let capBrimRect = box(12, 31, 24, 6)
    static let capBrimViewBox = box(0, 0, 24, 6)
    static let capBrimPath = "M3 0l18 0a3 3 0 0 1 0 6l-18 0a3 3 0 0 1 0-6z"
    static let capButtonRect = box(45, 7.5, 6, 6)

    // 삼성 — 사자 갈기
    static let lionManeRect = box(6, 4, 84, 84)
    static let lionManeViewBox = box(2, 0, 92, 92)
    static let lionManePath = "M84 46q12.3 12.9-4.8 18 4.2 17.4-13.2 13.2-5.1 17.1-18 4.8-12.9 12.3-18-4.8-17.4 4.2-13.2-13.2-17.1-5.1-4.8-18-12.3-12.9 4.8-18-4.2-17.4 13.2-13.2 5.1-17.1 18-4.8 12.9-12.3 18 4.8 17.4-4.2 13.2 13.2 17.1 5.1 4.8 18z"

    // LG — 투톤 캡과 둘째 안테나
    static let capTwoToneRect = box(48, 10, 23, 26)
    static let capTwoToneViewBox = box(48, 10, 23, 26)
    static let capTwoTonePath = "M48 10c11 0 21 7 23 26-8-3.3-15.5-4.6-23-4.6z"
    static let secondStemRect = box(34, 7, 6, 9)
    static let secondStemViewBox = box(34, 7, 6, 9)
    static let secondStemPath = "M39 16q-2-5-4-8.5"
    static let secondDiamondRect = box(30.5, 0.5, 9, 9)
    static let secondDiamondViewBox = box(30.5, 0.5, 9, 9)
    static let secondDiamondPath = "M35 0.5l4.5 4.5-4.5 4.5-4.5-4.5z"

    // 두산 — 곰
    static let bearEarLeftRect = box(22, 6, 16, 16)
    static let bearEarRightRect = box(58, 6, 16, 16)
    static let bearInnerEarLeftRect = box(26.5, 10.5, 7, 7)
    static let bearInnerEarRightRect = box(62.5, 10.5, 7, 7)
    static let bearMuzzleRect = box(39, 52, 18, 14)

    // KIA — 호랑이
    static let tigerEarLeftRect = box(30, 7, 11, 9)
    static let tigerEarLeftViewBox = box(30, 7, 11, 9)
    static let tigerEarLeftPath = "M30 16l6-9 5 6z"
    static let tigerEarRightRect = box(55, 7, 11, 9)
    static let tigerEarRightViewBox = box(55, 7, 11, 9)
    static let tigerEarRightPath = "M55 13l5-6 6 9z"
    static let tigerForeheadRect = box(42, 12, 12, 12)
    static let tigerForeheadViewBox = box(42, 12, 12, 12)
    static let tigerForeheadPath = "M43 14l0 8m5-10l0 11m5-9l0 8"
    static let tigerCheekLeftRect = box(23, 43, 10, 12)
    static let tigerCheekLeftViewBox = box(23, 43, 10, 12)
    static let tigerCheekLeftPath = "M24 44l8 1m-9 4l8 1m-7 4l8 0.5"
    static let tigerCheekRightRect = box(63, 43, 10, 12)
    static let tigerCheekRightViewBox = box(63, 43, 10, 12)
    static let tigerCheekRightPath = "M72 44l-8 1m9 4l-8 1m7 4l-8 0.5"

    // KT — 마법사 모자
    static let wizardHatRect = box(27, 3, 42, 33)
    static let wizardHatViewBox = box(27, 3, 42, 33)
    static let wizardHatPath = "M27 36c2-16 9-28 20-33-1 9 3 12 11 11-3 8 4 16 11 22-14-6-28-6-42 0z"
    static let hatDiamondViewBox = box(0, 0, 6, 6)
    static let hatDiamondPath = "M3 0l3 3-3 3-3-3z"
    static let hatDiamondLargeRect = box(38, 14, 6, 6)
    static let hatDiamondSmallRect = box(50, 21, 5, 5)

    // SSG — 로켓
    static let rocketFinRect = box(44, 1, 11, 11)
    static let rocketFinViewBox = box(44, 1, 11, 11)
    static let rocketFinPath = "M44 12l6-11 5 11z"
    static let rocketWindowRect = box(41, 17, 13, 13)

    // NC — 공룡
    static let dinoSpikesRect = box(33, 3, 25, 12)
    static let dinoSpikesViewBox = box(33, 3, 25, 12)
    static let dinoSpikesPath = "M33 15l5-10 5 8 4-9 4 9 4-6 3 8z"
    static let dinoBackSpineOneRect = box(76, 35, 11, 13)
    static let dinoBackSpineOneViewBox = box(76, 35, 11, 13)
    static let dinoBackSpineOnePath = "M77.5 40l9-4-6.5 12z"
    static let dinoBackSpineTwoRect = box(77, 49, 11, 12)
    static let dinoBackSpineTwoViewBox = box(77, 49, 11, 12)
    static let dinoBackSpineTwoPath = "M78.5 52l9.5-1.5-7 10z"

    // 롯데 — 큰 몸과 하이크라운
    static let giantBodyRect = box(14.5, 13, 68, 68)
    static let giantCapDomeRect = box(27, 3, 42, 33)
    static let giantCapDomeViewBox = box(27, 6, 42, 30)
    static let giantCapDomePath = "M27 36c0-24 11-30 21-30 10 0 21 6 21 30-12-5-30-5-42 0z"
    static let giantCapSeamRect = box(47, 5, 2, 24)
    static let giantCapSeamViewBox = box(47, 8, 2, 21)
    static let giantCapSeamPath = "M48 8l0 21"
    static let giantCapBrimRect = box(11, 31, 26, 6.5)

    // 키움 — 히어로
    static let heroCapeRect = box(60, 34, 28, 44)
    static let heroCapeViewBox = box(60, 34, 28, 44)
    static let heroCapePath = "M64 38c16 4 24 20 18 40-6-11-13-20-21-26z"
    static let heroMaskRect = box(26, 39, 44, 16)
    static let heroMaskViewBox = box(0, 0, 44, 16)
    static let heroMaskPath = "M8 0l28 0a8 8 0 0 1 0 16l-28 0a8 8 0 0 1 0-16z"

    // 한화 — 독수리
    static let eagleWingLeftRect = box(2, 22, 24, 38)
    static let eagleWingLeftViewBox = box(2, 22, 24, 38)
    static let eagleWingLeftPath = "M26 38c-9-8-17-11-24-15 5 9 4 13 0 18 7 1 9 5 7 12 6-2 9 0 11 7 3-6 6-13 6-22z"
    static let eagleWingRightRect = box(70, 22, 24, 38)
    static let eagleWingRightViewBox = box(70, 22, 24, 38)
    static let eagleWingRightPath = "M70 38c9-8 17-11 24-15-5 9-4 13 0 18-7 1-9 5-7 12-6-2-9 0-11 7-3-6-6-13-6-22z"
    static let eagleBrowRect = box(31, 37, 34, 5)
    static let eagleBrowViewBox = box(31, 37, 34, 5)
    static let eagleBrowPath = "M32 38l9 3m23-3l-9 3"
}

// MARK: - 요소 조립

extension VFTeamFairyTrait {

    /// 이 특징의 페어리를 이루는 조각들. Pencil의 그리기 순서를 그대로 따른다.
    ///
    /// 반환된 좌표는 `size`의 좌표계다. 96 기준 값에 배율을 곱하되, 눈 지름과 선
    /// 두께는 Pencil의 광학 보정 값을 그대로 쓴다.
    func elements(size: VFTeamFairySize) -> [VFTeamFairyElement] {
        let g = VFTeamFairyGeometry.self
        let s = size.scale
        var out: [VFTeamFairyElement] = []

        func scaled(_ r: CGRect) -> CGRect {
            CGRect(x: r.minX * s, y: r.minY * s, width: r.width * s, height: r.height * s)
        }
        func add(
            _ name: String, _ shape: VFTeamFairyElement.Shape, _ rect: CGRect,
            fill: VFTeamFairyPaint, stroke: VFTeamFairyPaint = .none, width: CGFloat = 0
        ) {
            out.append(VFTeamFairyElement(name: name, shape: shape, rect: scaled(rect),
                                          fill: fill, stroke: stroke, strokeWidth: width))
        }
        func path(_ d: String, _ vb: CGRect) -> VFTeamFairyElement.Shape { .path(d, vb) }

        let fine = size.showsFineDetail

        // 1. 몸통 뒤에 오는 것
        if fine, self == .lionMane {
            add("사자 갈기", path(g.lionManePath, g.lionManeViewBox), g.lionManeRect,
                fill: .accent, stroke: .outline, width: size.heavyStroke)
        }
        if fine, self == .heroMask {
            add("히어로 망토", path(g.heroCapePath, g.heroCapeViewBox), g.heroCapeRect,
                fill: .accent, stroke: .outline, width: 1.8)
        }

        // 2. 몸통 — 모든 팀이 같은 실루엣을 쓴다. 롯데만 크기를 키운다.
        let bodyRect = (self == .giantFrame && fine)
            ? g.giantBodyRect
            : CGRect(x: VFFairyGeometry.bodyRect.x, y: VFFairyGeometry.bodyRect.y,
                     width: VFFairyGeometry.bodyRect.width, height: VFFairyGeometry.bodyRect.height)
        add("바디", path(VFFairyGeometry.bodyPath, viewBox(VFFairyGeometry.bodyViewBox)), bodyRect,
            fill: .body, stroke: .outline, width: size.heavyStroke)

        // 3. 캡보다 뒤에 오는 구단 특징
        if fine, self == .bearFeatures {
            add("곰 귀 왼쪽", .ellipse, g.bearEarLeftRect, fill: .accent, stroke: .outline, width: 1.8)
            add("곰 귀 안 왼쪽", .ellipse, g.bearInnerEarLeftRect, fill: .onAccent)
            add("곰 귀 오른쪽", .ellipse, g.bearEarRightRect, fill: .accent, stroke: .outline, width: 1.8)
            add("곰 귀 안 오른쪽", .ellipse, g.bearInnerEarRightRect, fill: .onAccent)
        }

        // 4. 캡 — KT만 마법사 모자로 갈아입는다.
        if self == .wizardHat {
            if fine {
                add("마법사 모자", path(g.wizardHatPath, g.wizardHatViewBox), g.wizardHatRect,
                    fill: .accent, stroke: .outline, width: size.heavyStroke)
                add("모자 다이아 1", path(g.hatDiamondPath, g.hatDiamondViewBox), g.hatDiamondLargeRect,
                    fill: .diamond, stroke: .outline, width: 1.1)
                add("모자 다이아 2", path(g.hatDiamondPath, g.hatDiamondViewBox), g.hatDiamondSmallRect,
                    fill: .diamond, stroke: .outline, width: 1.1)
            } else {
                addStandardCap(&out, size: size, scaled: scaled, trait: self)
            }
        } else {
            addStandardCap(&out, size: size, scaled: scaled, trait: self)
        }

        // 5. 캡 위에 오는 구단 특징
        if fine {
            switch self {
            case .tigerStripes:
                add("호랑이 귀 왼쪽", path(g.tigerEarLeftPath, g.tigerEarLeftViewBox), g.tigerEarLeftRect,
                    fill: .accent, stroke: .outline, width: 1.6)
                add("호랑이 귀 오른쪽", path(g.tigerEarRightPath, g.tigerEarRightViewBox), g.tigerEarRightRect,
                    fill: .accent, stroke: .outline, width: 1.6)
                add("이마 줄무늬", path(g.tigerForeheadPath, g.tigerForeheadViewBox), g.tigerForeheadRect,
                    fill: .none, stroke: .outline, width: 2)
                add("볼 줄 왼쪽", path(g.tigerCheekLeftPath, g.tigerCheekLeftViewBox), g.tigerCheekLeftRect,
                    fill: .none, stroke: .outline, width: 1.9)
                add("볼 줄 오른쪽", path(g.tigerCheekRightPath, g.tigerCheekRightViewBox), g.tigerCheekRightRect,
                    fill: .none, stroke: .outline, width: 1.9)
            case .rocketFin:
                add("랜더스 핀", path(g.rocketFinPath, g.rocketFinViewBox), g.rocketFinRect,
                    fill: .accent, stroke: .outline, width: 1.6)
                add("로켓 창문", .ellipse, g.rocketWindowRect, fill: .onAccent, stroke: .outline, width: 1.8)
            case .dinoSpikes:
                add("공룡 스파이크", path(g.dinoSpikesPath, g.dinoSpikesViewBox), g.dinoSpikesRect,
                    fill: .accent, stroke: .outline, width: 1.6)
                add("등 가시 1", path(g.dinoBackSpineOnePath, g.dinoBackSpineOneViewBox), g.dinoBackSpineOneRect,
                    fill: .accent, stroke: .outline, width: 1.5)
                add("등 가시 2", path(g.dinoBackSpineTwoPath, g.dinoBackSpineTwoViewBox), g.dinoBackSpineTwoRect,
                    fill: .accent, stroke: .outline, width: 1.5)
            case .heroMask:
                add("히어로 마스크", path(g.heroMaskPath, g.heroMaskViewBox), g.heroMaskRect,
                    fill: .accent, stroke: .outline, width: 1.8)
            case .eagleWings:
                add("독수리 날개 왼쪽", path(g.eagleWingLeftPath, g.eagleWingLeftViewBox), g.eagleWingLeftRect,
                    fill: .accent, stroke: .outline, width: 1.8)
                add("독수리 날개 오른쪽", path(g.eagleWingRightPath, g.eagleWingRightViewBox), g.eagleWingRightRect,
                    fill: .accent, stroke: .outline, width: 1.8)
                add("독수리 눈썹", path(g.eagleBrowPath, g.eagleBrowViewBox), g.eagleBrowRect,
                    fill: .none, stroke: .face, width: size.lineStroke)
            default:
                break
            }
        }

        // 6. 안테나 — 모든 팀이 같다. LG만 둘이다.
        add("안테나 줄기", path(VFFairyGeometry.antennaStemPath, viewBox(VFFairyGeometry.antennaStemViewBox)),
            rect(VFFairyGeometry.antennaStemRect), fill: .none, stroke: .face, width: size.lineStroke)
        add("안테나 다이아몬드", path(VFFairyGeometry.antennaDiamondPath, viewBox(VFFairyGeometry.antennaDiamondViewBox)),
            rect(VFFairyGeometry.antennaDiamondRect), fill: .diamond, stroke: .outline, width: size.diamondStroke)
        if fine, self == .twinAntenna {
            add("안테나 줄기 2", path(g.secondStemPath, g.secondStemViewBox), g.secondStemRect,
                fill: .none, stroke: .face, width: size.lineStroke)
            add("안테나 다이아몬드 2", path(g.secondDiamondPath, g.secondDiamondViewBox), g.secondDiamondRect,
                fill: .diamond, stroke: .outline, width: size.diamondStroke)
        }

        // 7. 얼굴 위에 오는 것
        if fine, self == .bearFeatures {
            add("곰 주둥이", .ellipse, g.bearMuzzleRect, fill: .surface, stroke: .outline, width: 1.6)
        }

        // 8. 얼굴 — 모든 팀이 같은 자리, 같은 크기.
        //    키움만 마스크 위에 눈이 올라가므로 밝은 색을 쓴다.
        let eyeFill: VFTeamFairyPaint = (self == .heroMask && fine) ? .onAccent : .face
        let d = size.eyeDiameter
        add("눈 왼쪽", .ellipse,
            CGRect(x: g.eyeLeftOrigin.x, y: g.eyeLeftOrigin.y, width: d / s, height: d / s),
            fill: eyeFill)
        add("눈 오른쪽", .ellipse,
            CGRect(x: g.eyeRightOrigin.x, y: g.eyeRightOrigin.y, width: d / s, height: d / s),
            fill: eyeFill)
        add("입", path(g.mouthPath, fine ? g.mouthViewBox : g.compactMouthViewBox), g.mouthRect,
            fill: .none, stroke: .face, width: size.lineStroke)

        return out
    }

    private func addStandardCap(
        _ out: inout [VFTeamFairyElement],
        size: VFTeamFairySize,
        scaled: (CGRect) -> CGRect,
        trait: VFTeamFairyTrait
    ) {
        let g = VFTeamFairyGeometry.self
        let fine = size.showsFineDetail
        let isGiant = trait == .giantFrame && fine

        func add(
            _ name: String, _ shape: VFTeamFairyElement.Shape, _ rect: CGRect,
            fill: VFTeamFairyPaint, stroke: VFTeamFairyPaint = .none, width: CGFloat = 0
        ) {
            out.append(VFTeamFairyElement(name: name, shape: shape, rect: scaled(rect),
                                          fill: fill, stroke: stroke, strokeWidth: width))
        }

        add("캡 돔",
            .path(isGiant ? g.giantCapDomePath : g.capDomePath,
                  isGiant ? g.giantCapDomeViewBox : g.capDomeViewBox),
            isGiant ? g.giantCapDomeRect : g.capDomeRect,
            fill: .accent, stroke: .outline, width: size.heavyStroke)

        if fine, trait == .twinAntenna {
            add("캡 투톤 우측", .path(g.capTwoTonePath, g.capTwoToneViewBox), g.capTwoToneRect, fill: .outline)
        }

        if fine {
            add("캡 재봉선",
                .path(isGiant ? g.giantCapSeamPath : g.capSeamPath,
                      isGiant ? g.giantCapSeamViewBox : g.capSeamViewBox),
                isGiant ? g.giantCapSeamRect : g.capSeamRect,
                fill: .none, stroke: .outline, width: size.seamStroke)
        }

        add("캡 챙", .path(g.capBrimPath, g.capBrimViewBox),
            isGiant ? g.giantCapBrimRect : g.capBrimRect,
            fill: .accent, stroke: .outline, width: size.brimStroke)

        // 롯데는 하이크라운이라 버튼이 없다. 48px에서는 모든 팀이 버튼을 뺀다.
        if fine, !isGiant {
            add("캡 버튼", .ellipse, g.capButtonRect, fill: .accent, stroke: .outline, width: size.buttonStroke)
        }
    }
}

private func viewBox(_ v: VFFairyGeometry.ViewBox) -> CGRect {
    CGRect(x: v.0, y: v.1, width: v.2, height: v.3)
}

private func rect(_ r: VFFairyGeometry.Rect) -> CGRect {
    CGRect(x: r.x, y: r.y, width: r.width, height: r.height)
}

// MARK: - 팔레트

/// 역할별 실제 색. 팀 색은 `VFTeamAccent`가 소유한다.
struct VFTeamFairyPalette {
    let accent: Color
    let body: Color
    let outline: Color
    let face: Color
    let diamond: Color
    let surface: Color
    let onAccent: Color

    static func resolve(teamID: String?, appearance: VFTeamFairyAppearance) -> VFTeamFairyPalette {
        switch appearance {
        case .onLightSurface, .onDarkSurface:
            // Pencil은 같은 아트워크를 두 표면에 쓴다. 표면에 따라 다시 칠하지 않는다.
            return VFTeamFairyPalette(
                accent: teamID == nil ? VFFairyColor.team : VFTeamAccent.color(forTeamID: teamID),
                body: VFColor.highlightSurface,
                outline: VFColor.inkOutline,
                face: VFColor.bodyPrimary,
                diamond: VFColor.attentionAccent,
                surface: VFColor.elevatedSurface,
                onAccent: VFColor.highlightSurface
            )
        case .monochrome:
            // 색을 지우되 구조는 남긴다. 몸(가장 밝음) · 캡(중간) · 얼굴(가장 어두움)
            // 세 단계로 눕혀, 캡이 몸에 녹아 사라지지 않게 한다. 기본 글리프의
            // 모노크롬과 같은 원칙이되, 팀 페어리는 층이 하나 더 있어 세 톤을 쓴다.
            return VFTeamFairyPalette(
                accent: VFColor.bodyTertiary,
                body: VFColor.subtleSurface,
                outline: VFColor.inkOutline,
                face: VFColor.bodyPrimary,
                diamond: VFColor.subtleSurface,
                surface: VFColor.elevatedSurface,
                onAccent: VFColor.subtleSurface
            )
        }
    }

    func colour(for paint: VFTeamFairyPaint) -> Color {
        switch paint {
        case .accent: accent
        case .body: body
        case .outline: outline
        case .face: face
        case .diamond: diamond
        case .surface: surface
        case .onAccent: onAccent
        case .none: .clear
        }
    }
}

// MARK: - 뷰

/// 구단 정체성을 지닌 Victory Fairy 하나를 그린다.
///
/// 읽어 줄 문장은 **부르는 쪽이 준다.** 팀 이름을 컴포넌트가 지어내지 않는다.
/// 라벨이 없으면 장식으로 보고 숨긴다 — 곁에 이미 팀 이름이 적혀 있는 자리에서만
/// 그렇게 쓴다.
///
///     VFTeamFairy(teamID: "samsung-lions", accessibilityLabel: "삼성 라이온즈 응원 팀")
///     VFTeamFairy(teamID: nil, accessibilityLabel: "아직 응원 팀을 선택하지 않음")
///
/// 선택 상태는 그림을 바꾸지 않는다. Pencil이 선택을 감싸는 카드로 알리기 때문이다.
/// `selection.requiredAffordances`가 그 카드가 무엇을 그려야 하는지 말해 준다.
struct VFTeamFairy: View {
    /// canonical 팀 ID. `nil`이면 중립(아직 고르지 않음)이다.
    let teamID: String?
    var size: VFTeamFairySize
    var appearance: VFTeamFairyAppearance
    var selection: VFTeamFairySelection
    /// VoiceOver가 읽을 문장. 비우면 장식으로 보고 숨긴다.
    var accessibilityLabel: String?

    init(
        teamID: String?,
        size: VFTeamFairySize = .regular,
        appearance: VFTeamFairyAppearance = .onLightSurface,
        selection: VFTeamFairySelection = .unselected,
        accessibilityLabel: String? = nil
    ) {
        self.teamID = teamID
        self.size = size
        self.appearance = appearance
        self.selection = selection
        self.accessibilityLabel = accessibilityLabel
    }

    /// 이 페어리는 팀 이름과 함께 쓰여야 한다.
    static let pairing: VFFairyPairing = .requiresTeamName

    var trait: VFTeamFairyTrait { VFTeamFairyTrait.trait(forTeamID: teamID) }

    var palette: VFTeamFairyPalette {
        VFTeamFairyPalette.resolve(teamID: teamID, appearance: appearance)
    }

    var elements: [VFTeamFairyElement] { trait.elements(size: size) }

    var body: some View {
        let palette = self.palette
        ZStack(alignment: .topLeading) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                shape(for: element, palette: palette)
                    .frame(width: element.rect.width, height: element.rect.height)
                    .offset(x: element.rect.minX, y: element.rect.minY)
            }
        }
        .frame(width: size.canvas, height: size.canvas, alignment: .topLeading)
        .modifier(VFTeamFairyAccessibility(label: accessibilityLabel))
    }

    @ViewBuilder
    private func shape(for element: VFTeamFairyElement, palette: VFTeamFairyPalette) -> some View {
        let fill = palette.colour(for: element.fill)
        let stroke = palette.colour(for: element.stroke)
        switch element.shape {
        case let .path(d, viewBox):
            let vector = VFVectorPath(d, viewBox: viewBox)
            if element.fill == .none {
                vector.stroke(stroke, style: StrokeStyle(lineWidth: element.strokeWidth, lineCap: .round))
            } else if element.stroke == .none {
                vector.fill(fill)
            } else {
                vector.fill(fill).overlay(
                    VFVectorPath(d, viewBox: viewBox)
                        .stroke(stroke, style: StrokeStyle(lineWidth: element.strokeWidth, lineJoin: .round))
                )
            }
        case .ellipse:
            if element.stroke == .none {
                Ellipse().fill(fill)
            } else {
                Ellipse().fill(fill).overlay(Ellipse().stroke(stroke, lineWidth: element.strokeWidth))
            }
        case .rectangle:
            Rectangle().fill(fill)
        }
    }
}

// MARK: - 접근성

/// 라벨이 있으면 하나의 요소로 읽고, 없으면 통째로 숨긴다.
///
/// 기본값이 "숨김"이라, 라벨을 깜빡한 페어리가 팀 ID나 컴포넌트 이름으로 읽히는
/// 일이 없다. 팀 카드 안에서 쓸 때는 카드가 이미 팀 이름을 읽어 주므로 숨기는 쪽이
/// 맞다 — 같은 팀을 두 번 읽지 않는다.
private struct VFTeamFairyAccessibility: ViewModifier {
    let label: String?

    func body(content: Content) -> some View {
        if let label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
            content.accessibilityElement().accessibilityLabel(label)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

// MARK: - 프리뷰

private let previewTeamIDs = KBOSeed.teams.filter(\.active).map(\.id)

#Preview("팀 페어리 96 — 10구단") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewTeamIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFTeamFairy(teamID: id)
                    Text(KBOSeed.team(id: id)?.name ?? id)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("중립과 48px") {
    VStack(alignment: .leading, spacing: VFSpacing.xl) {
        HStack(spacing: VFSpacing.md) {
            VFTeamFairy(teamID: nil)
            Text("아직 선택하지 않음")
                .font(VFTypography.body)
                .foregroundStyle(VFColor.bodySecondary)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: VFSpacing.sm)], spacing: VFSpacing.md) {
            ForEach(previewTeamIDs + ["neutral"], id: \.self) { id in
                VStack(spacing: VFSpacing.xxs) {
                    VFTeamFairy(teamID: id == "neutral" ? nil : id, size: .compact)
                    Text(KBOSeed.team(id: id)?.shortName ?? "중립")
                        .font(VFTypography.chartLabel)
                        .foregroundStyle(VFColor.bodyTertiary)
                }
            }
        }
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}

#Preview("어두운 표면 — 같은 아트워크") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewTeamIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFTeamFairy(teamID: id, appearance: .onDarkSurface)
                    Text(KBOSeed.team(id: id)?.shortName ?? id)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyOnDark)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.nightSurface)
}

#Preview("모노크롬 — 팀은 곁의 글자가 말한다") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.md)], spacing: VFSpacing.lg) {
            ForEach(previewTeamIDs, id: \.self) { id in
                VStack(spacing: VFSpacing.xs) {
                    VFTeamFairy(teamID: id, appearance: .monochrome)
                    Text(KBOSeed.team(id: id)?.name ?? id)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
        .padding(VFSpacing.md)
    }
    .background(VFColor.appBackground)
}

#Preview("대비 양 끝 — 가장 밝은 한화, 가장 어두운 두산") {
    VStack(alignment: .leading, spacing: VFSpacing.lg) {
        ForEach(["hanwha-eagles", "doosan-bears"], id: \.self) { id in
            HStack(spacing: VFSpacing.md) {
                VFTeamFairy(teamID: id)
                VFTeamFairy(teamID: id, size: .compact)
                Text(KBOSeed.team(id: id)?.name ?? id)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
            }
        }
        Divider()
        HStack(spacing: VFSpacing.md) {
            VFTeamFairy(teamID: "lotte-giants", size: .compact)
            // 이름은 등록부에서 가져온다. 그리기 소스에 팀 이름을 적지 않는다.
            Text("\(KBOSeed.team(id: "lotte-giants")?.name ?? "") — 긴 팀 이름이 옆에 와도 잘리지 않는다")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodySecondary)
        }
    }
    .padding(VFSpacing.lg)
    .background(VFColor.appBackground)
}
