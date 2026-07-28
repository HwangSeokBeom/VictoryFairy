import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// VictoryFairy 디자인 시스템.
//
// 모든 값은 Pencil 디자인 원본(VictoryFairy.pen)의 문서 변수에서 그대로 옮겨왔다.
// 원본은 종이 스크랩북 정서를 기준으로 하며, 밝은 종이 배경 위에 잉크색 글자와
// 산호색 강조를 올리는 단일 외형(light appearance)만 정의한다.

// MARK: - 색

/// 화면 배경과 표면, 글자, 강조에 쓰는 의미 기반 색 토큰.
enum VFColor {
    // 배경 레이어
    /// 앱 전체 바탕. Pencil `paper`.
    static let appBackground = Color(hex: "#F4F4F2")
    /// 카드·시트처럼 배경에서 한 단계 떠오른 표면. Pencil `surface`.
    static let elevatedSurface = Color(hex: "#FFFFFF")
    /// 표면 위에 다시 얹는 은은한 톤 블록. Pencil `cream`.
    static let subtleSurface = Color(hex: "#EAEAE6")
    /// 강조 스트립·선택 행에 쓰는 따뜻한 톤. Pencil `butter-pale`.
    static let highlightSurface = Color(hex: "#F6EEDC")
    /// 반투명 표면(탭바 등).
    static let translucentSurface = Color(hex: "#FFFFFF").opacity(0.94)

    // 야간 표면 — 온보딩 웰컴·완료, 시즌 커버, 스플래시가 쓰는 어두운 무대.
    /// Pencil `night`.
    static let nightSurface = Color(hex: "#0E1526")
    /// Pencil `night-2`. 야간 표면 위의 카드.
    static let nightElevated = Color(hex: "#1A2338")
    /// Pencil `night-line`. 야간 표면 위의 경계선.
    static let nightHairline = Color(hex: "#2B3652")

    // 글자
    /// 본문 1차 글자색. Pencil `ink`.
    static let bodyPrimary = Color(hex: "#14171F")
    /// 본문 2차 글자색. Pencil `ink-soft`.
    static let bodySecondary = Color(hex: "#4C5160")
    /// 보조 정보·플레이스홀더. Pencil `ink-faint`.
    static let bodyTertiary = Color(hex: "#8B909E")
    /// 어두운 표면 위에 올리는 글자색.
    static let bodyOnDark = Color(hex: "#F6F5F0")

    // 강조
    /// 주요 액션. Pencil `coral`/`gold`/`butter`가 모두 같은 금색을 가리킨다.
    static let primaryAction = Color(hex: "#F2B63C")
    /// 주요 액션의 진한 변형(글자·강조 텍스트). Pencil `coral-deep`.
    static let primaryActionDeep = Color(hex: "#D99A26")
    /// 주요 액션의 옅은 배경. Pencil `coral-pale`.
    static let primaryActionPale = Color(hex: "#F7E7C2")
    /// 차분한 보조 강조. Pencil `navy`.
    static let deepAccent = Color(hex: "#0E1526")
    /// 자연 톤 보조 강조. Pencil `sage`.
    static let supportAccent = Color(hex: "#2F7A56")
    /// 정보 톤 보조 강조. Pencil `sky`.
    static let infoAccent = Color(hex: "#5E7FA6")

    // 옅은 톤 배경
    static let supportAccentPale = Color(hex: "#E3EFE8")
    static let infoAccentPale = Color(hex: "#E8EDF4")
    /// 강조 금색. Pencil `butter`.
    static let attentionAccent = Color(hex: "#F2B63C")

    // 선
    /// 카드·구분선에 쓰는 부드러운 경계. Pencil `line`.
    static let hairline = Color(hex: "#E2E3E1")
    /// 버튼·뱃지처럼 또렷한 윤곽. Pencil `line-ink`.
    static let inkOutline = Color(hex: "#232A3C")

    // 경기 결과 (Pencil 스탬프 체계)
    /// 승. Pencil `win`.
    static let gameWin = Color(hex: "#2E9E6B")
    /// 패. Pencil 스탬프/패의 채움색.
    static let gameLoss = Color(hex: "#3A4157")
    /// 무. Pencil `ink-faint`.
    static let gameDraw = Color(hex: "#8B909E")
    /// 취소·우천 등 진행되지 않은 경기.
    static let gameCanceled = Color(hex: "#8B909E")
    /// 진행 중인 경기. Pencil `live`.
    static let gameLive = Color(hex: "#E5484D")
    /// 예정된 경기.
    static let gameScheduled = Color(hex: "#8B909E")

    // 상태
    static let statusSuccess = Color(hex: "#2F7A56")
    static let statusWarning = Color(hex: "#F2B63C")
    static let statusError = Color(hex: "#E5484D")
    static let disabled = Color(hex: "#8B909E")
}

// MARK: - 간격

enum VFSpacing {
    /// Pencil `sp-xs`.
    static let xxs: CGFloat = 4
    /// Pencil `sp-sm`.
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    /// Pencil `sp-md`. 화면 좌우 기본 여백과 같다.
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    /// Pencil `sp-lg`.
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    /// 화면 좌우 콘텐츠 여백. Pencil 홈/피드 콘텐츠 padding과 같다.
    static let screenHorizontalMargin: CGFloat = 16
    /// 세로로 쌓인 주요 섹션 사이 간격. Pencil 홈 콘텐츠 gap.
    static let sectionGap: CGFloat = 22
}

// MARK: - 모서리

enum VFRadius {
    /// 폴라로이드·사진처럼 거의 각진 모서리.
    static let photo: CGFloat = 6
    /// Pencil `r-sm`.
    static let sm: CGFloat = 10
    static let field: CGFloat = 12
    /// Pencil `r-md`.
    static let md: CGFloat = 14
    /// 카드·버튼 기본 모서리.
    static let card: CGFloat = 16
    /// 패널·빈 상태 박스.
    static let panel: CGFloat = 18
    /// Pencil `r-lg`.
    static let lg: CGFloat = 20
    /// 시트·다이얼로그.
    static let sheet: CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - 선 두께

enum VFStroke {
    /// 카드 테두리. Pencil 카드 strokeWidth.
    static let hairline: CGFloat = 1.2
    /// 입력 박스.
    static let field: CGFloat = 1.5
    /// 버튼·다이얼로그처럼 또렷한 손그림 윤곽.
    static let ink: CGFloat = 1.5
    /// 팀 뱃지 윤곽.
    static let badge: CGFloat = 1.8
}

// MARK: - 타이포그래피

/// Pencil은 Black Han Sans(display) / Noto Sans KR(ui·hand) / Barlow Condensed(mono)를
/// 쓴다. 세 글꼴 모두 저장소에 라이선스 파일이 없고 이 작업에서도 폰트 파일을 추가하지
/// 않으므로, 시스템 서체의 굵기와 디자인 변형으로 각 역할을 대신한다.
///
/// - display -> `.default` 아주 굵게 (Black Han Sans의 묵직한 인상)
/// - ui/hand -> `.default` (두 역할이 같은 Noto Sans KR로 통합됐다)
/// - mono    -> `monospacedDigit()` (Barlow Condensed의 자리수 고정 성격)
///
/// 이전 문서의 손글씨 목소리(Gaegu)는 최신 Pencil에서 사라졌다. `handwritten` 역할은
/// 호출부 호환을 위해 이름을 유지하되 평범한 산세리프로 바뀌었다.
///
/// 모든 역할은 `Font.TextStyle` 기반이라 Dynamic Type을 그대로 따른다.
enum VFTypography {
    /// 화면 제목·인사말 같은 가장 큰 표현 텍스트. Pencil display.
    static let display = Font.system(.title2, design: .default).weight(.heavy)
    /// 화면 제목. Pencil 내비 제목 17/600.
    static let screenTitle = Font.system(.headline, design: .default).weight(.semibold)
    /// 섹션 제목. Pencil 17/700.
    static let sectionTitle = Font.system(.headline, design: .default).weight(.bold)
    /// 카드 제목·매치업. Pencil 15/700.
    static let cardTitle = Font.system(.subheadline, design: .default).weight(.bold)
    /// 본문. Pencil 14.
    static let body = Font.system(.subheadline, design: .default)
    /// 보조 본문·설명. Pencil 13.
    static let supporting = Font.system(.footnote, design: .default)
    /// 메타 정보. Pencil 12.
    static let metadata = Font.system(.caption, design: .default)
    /// 뱃지·탭 라벨. Pencil 10~11.
    static let badge = Font.system(.caption2, design: .default).weight(.medium)
    /// 버튼 라벨. Pencil 16/700.
    static let button = Font.system(.callout, design: .default).weight(.bold)
    /// 숫자 강조(날짜·스코어). Pencil font-mono 26/700.
    static let numericEmphasis = Font.system(.title, design: .default).weight(.bold).monospacedDigit()
    /// 스코어처럼 자리수가 흔들리면 안 되는 작은 숫자. Pencil 13/600.
    static let numericSupporting = Font.system(.footnote, design: .default).weight(.semibold).monospacedDigit()
    /// 부제·캡션. 최신 Pencil에서 손글씨 글꼴이 사라져 본문과 같은 산세리프를 쓴다.
    static let handwritten = Font.system(.subheadline, design: .default)
    /// 큰 부제·워드마크.
    static let handwrittenLarge = Font.system(.title3, design: .default).weight(.semibold)
    /// 차트 축·범례 라벨.
    static let chartLabel = Font.system(.caption2, design: .default)
}

// MARK: - 그림자

enum VFShadow {
    /// 카드 그림자. Pencil 기록 카드 `#33302A14`, blur 8, y 2.
    static let cardColor = Color(hex: "#33302A").opacity(0.08)
    static let cardRadius: CGFloat = 8
    static let cardOffsetY: CGFloat = 2

    /// 떠 있는 표면(폴라로이드·공유 카드). Pencil blur 14~20, y 5~8.
    static let liftedColor = Color(hex: "#33302A").opacity(0.13)
    static let liftedRadius: CGFloat = 14
    static let liftedOffsetY: CGFloat = 5

    /// 탭바·시트처럼 화면 위에 겹치는 표면. Pencil blur 22~28.
    static let overlayColor = Color(hex: "#33302A").opacity(0.14)
    static let overlayRadius: CGFloat = 22
    static let overlayOffsetY: CGFloat = 8

    /// 버튼의 얕은 눌림 그림자. Pencil `#4A453C33`, y 3.
    static let buttonColor = Color(hex: "#4A453C").opacity(0.20)
    static let buttonRadius: CGFloat = 0
    static let buttonOffsetY: CGFloat = 3
}

// MARK: - 아이콘·컨트롤 치수

enum VFIconSize {
    /// 메타 행 아이콘. Pencil 14.
    static let small: CGFloat = 14
    /// 본문 인라인 아이콘. Pencil 17~18.
    static let medium: CGFloat = 18
    /// 탭·내비 아이콘. Pencil 21~22.
    static let large: CGFloat = 22
}

enum VFControl {
    /// 기본 버튼 높이. Pencil 54.
    static let buttonHeight: CGFloat = 54
    /// 입력 박스 높이. Pencil 50.
    static let fieldHeight: CGFloat = 50
    /// 최소 터치 영역.
    static let minimumTouchTarget: CGFloat = 44
    /// 팀 뱃지 지름. Pencil 34.
    static let teamBadgeSize: CGFloat = 34
    /// 결과 스탬프 지름. Pencil 46.
    static let stampSize: CGFloat = 46
}

enum VFTabBarMetrics {
    /// Pencil 탭바 높이 62 + 상하 여유.
    static let customTabBarHeight: CGFloat = 62
    /// 캡슐 하단과 화면 하단 사이 여백. Pencil 탭 영역 bottom padding 12에
    /// 홈 인디케이터를 고려한 여유를 더한 값이다.
    static let customTabBarBottomInset: CGFloat = 12
    static let extraBreathingRoom: CGFloat = 20
    /// 스크롤 콘텐츠가 탭바에 가리지 않도록 확보하는 하단 여백.
    static let tabContentBottomPadding = customTabBarHeight + customTabBarBottomInset + extraBreathingRoom
}

// MARK: - 모션

/// Pencil 프로토타입이 요구하는 절제된 움직임만 정의한다.
/// 모든 사용처는 Reduce Motion을 존중해야 한다.
enum VFMotion {
    static let tabTransition = Animation.snappy(duration: 0.22)
    static let selection = Animation.snappy(duration: 0.18)
    static let contentAppear = Animation.easeOut(duration: 0.24)
    /// 로딩 점이 순환하는 주기.
    static let loadingCycle: Double = 0.9

    /// Reduce Motion이 켜져 있으면 애니메이션을 제거한다.
    static func respectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}

// MARK: - 손으로 붙인 듯한 회전

/// Pencil은 폴라로이드·테이프·스탬프에 아주 작은 회전을 준다.
/// 값을 한곳에 모아 화면마다 임의로 흩어지지 않게 한다.
enum VFTilt {
    static let photo: Double = -3
    static let card: Double = 0.6
    static let tape: Double = -4
    static let shareCard: Double = -1
    static let winStamp: Double = 8
    static let lossStamp: Double = -6
    static let drawStamp: Double = 4
}

// MARK: - Color 유틸리티

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

    /// 이 색을 배경으로 썼을 때 읽히는 글자색.
    var vfReadableForegroundColor: Color {
        vfIsLight ? VFColor.bodyPrimary : VFColor.bodyOnDark
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

// MARK: - 화면 배경

struct VFScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(VFColor.appBackground.ignoresSafeArea())
    }
}

extension View {
    /// Pencil의 종이 배경을 화면 전체에 깐다.
    func vfScreenBackground() -> some View {
        modifier(VFScreenBackground())
    }

    /// 탭바에 가리지 않도록 스크롤 콘텐츠 하단 여백을 준다.
    func vfTabContentPadding() -> some View {
        padding(.bottom, VFTabBarMetrics.tabContentBottomPadding)
    }

    /// Reduce Motion이 켜져 있으면 회전을 적용하지 않는다.
    /// 손으로 붙인 듯한 기울기는 장식이므로 정보 접근을 막지 않아야 한다.
    func vfTilt(_ degrees: Double, reduceMotion: Bool = false) -> some View {
        rotationEffect(.degrees(reduceMotion ? 0 : degrees))
    }
}
