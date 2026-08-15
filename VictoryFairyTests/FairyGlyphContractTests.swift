import XCTest
import SwiftUI
@testable import VictoryFairy

/// 개정 Pencil(8e055d8a…3d6db2)이 들여온 Victory Fairy 기반 시스템의 계약을 확인한다.
///
/// 값은 모두 Pencil 노드에서 직접 읽은 것이다. 이 파일의 기대값이 바뀌어야 한다면
/// 원본이 바뀐 것이므로, 원본을 다시 읽고 근거를 남긴 뒤에 고쳐야 한다.
final class FairyGlyphContractTests: XCTestCase {

    /// 이번 작업이 근거로 삼은 개정 Pencil 원본.
    /// 이전 원본 `9b5af6ae…5b1a4a`는 완료된 화면들의 근거로 그대로 남는다.
    static let revisedPencilSHA256 = "8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2"

    // MARK: - 소스 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func source(_ relativePath: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 주석을 걷어낸 소스. 설명 문장이 검사에 걸려 거짓 판정이 나지 않게 한다.
    /// 이 파일들의 주석에는 "팀 페어리", "구장", `TeamFairy48` 같은 낱말이 실제로 들어 있다.
    private func executableSource(_ relativePath: String) throws -> String {
        stripComments(try source(relativePath))
    }

    private func stripComments(_ text: String) -> String {
        var output = ""
        var iterator = Array(text)
        var index = 0
        var inLineComment = false
        var inBlockComment = false
        var inString = false
        while index < iterator.count {
            let character = iterator[index]
            let next: Character? = index + 1 < iterator.count ? iterator[index + 1] : nil

            if inLineComment {
                if character == "\n" { inLineComment = false; output.append(character) }
                index += 1
                continue
            }
            if inBlockComment {
                if character == "*", next == "/" { inBlockComment = false; index += 2; continue }
                index += 1
                continue
            }
            if inString {
                if character == "\\" { index += 2; continue }
                if character == "\"" { inString = false }
                output.append(character)
                index += 1
                continue
            }
            if character == "/", next == "/" { inLineComment = true; index += 2; continue }
            if character == "/", next == "*" { inBlockComment = true; index += 2; continue }
            if character == "\"" { inString = true }
            output.append(character)
            index += 1
        }
        return output
    }

    // MARK: - 1. 원본 기록

    func testRevisedPencilHashIsRecordedInDocumentation() throws {
        let docURL = Self.repositoryRoot
            .appendingPathComponent("docs/PencilDesignImplementation.md")
        let doc = try String(contentsOf: docURL, encoding: .utf8)
        XCTAssertTrue(
            doc.contains(Self.revisedPencilSHA256),
            "개정 Pencil 해시가 문서에 남아 있어야 한다"
        )
    }

    // MARK: - 2~4. 페어리 변수 매핑

    /// Pencil `fairy*` 문서 변수 12개와 그 값. `execute`/`GetVariables`로 직접 읽었다.
    private static let pencilFairyVariables: [String: String] = [
        "fairyVictory": "#F2B63C",
        "fairyTeam": "#5E7FA6",
        "fairyStadium": "#2F7A56",
        "fairyLive": "#E5484D",
        "fairyNeutral": "#8B909E",
        "fairyFaceOnLight": "#14171F",
        "fairyIconBg": "#0E1526",
        "fairyMemory": "#9D93C8",
        "fairyMemorySurface": "#EDEAF5",
        "fairyConcern": "#B95F55",
        "fairyFaceOnDark": "#F6F3EA",
        "fairyIconBgDark": "#070C16"
    ]

    private static let swiftFairyColors: [String: Color] = [
        "fairyVictory": VFFairyColor.victory,
        "fairyTeam": VFFairyColor.team,
        "fairyStadium": VFFairyColor.stadium,
        "fairyLive": VFFairyColor.live,
        "fairyNeutral": VFFairyColor.neutral,
        "fairyFaceOnLight": VFFairyColor.faceOnLight,
        "fairyIconBg": VFFairyColor.iconBackground,
        "fairyMemory": VFFairyColor.memory,
        "fairyMemorySurface": VFFairyColor.memorySurface,
        "fairyConcern": VFFairyColor.concern,
        "fairyFaceOnDark": VFFairyColor.faceOnDark,
        "fairyIconBgDark": VFFairyColor.iconBackgroundDark
    ]

    func testEveryPencilFairyVariableHasASwiftToken() {
        XCTAssertEqual(Self.pencilFairyVariables.count, 12, "Pencil 페어리 변수는 12개다")
        for name in Self.pencilFairyVariables.keys {
            XCTAssertNotNil(Self.swiftFairyColors[name], "\(name)에 대응하는 Swift 토큰이 없다")
        }
        XCTAssertEqual(
            Set(Self.swiftFairyColors.keys), Set(Self.pencilFairyVariables.keys),
            "Swift 쪽에 Pencil에 없는 페어리 토큰이 있으면 안 된다"
        )
    }

    func testEveryFairyTokenMatchesItsPencilValue() {
        for (name, hex) in Self.pencilFairyVariables {
            guard let color = Self.swiftFairyColors[name] else {
                return XCTFail("\(name) 토큰 없음")
            }
            XCTAssertEqual(color, Color(hex: hex), "\(name) 값이 Pencil과 다르다")
        }
    }

    /// Pencil에 처음 등장한 다섯 값. 기존 변수 가운데 같은 값을 가진 것이 없다.
    func testTheFiveGenuinelyNewTokensUseExactPencilValues() {
        XCTAssertEqual(VFFairyColor.memory, Color(hex: "#9D93C8"), "fairyMemory")
        XCTAssertEqual(VFFairyColor.memorySurface, Color(hex: "#EDEAF5"), "fairyMemorySurface")
        XCTAssertEqual(VFFairyColor.concern, Color(hex: "#B95F55"), "fairyConcern")
        XCTAssertEqual(VFFairyColor.faceOnDark, Color(hex: "#F6F3EA"), "fairyFaceOnDark")
        XCTAssertEqual(VFFairyColor.iconBackgroundDark, Color(hex: "#070C16"), "fairyIconBgDark")
    }

    /// 새 값 다섯은 기존 어떤 토큰과도 겹치지 않아야 한다. 겹친다면 별칭이었어야 한다.
    func testTheFiveNewTokensAreNotDuplicatesOfExistingTokens() {
        let existing: [Color] = [
            VFColor.appBackground, VFColor.elevatedSurface, VFColor.subtleSurface,
            VFColor.highlightSurface, VFColor.nightSurface, VFColor.nightElevated,
            VFColor.nightHairline, VFColor.bodyPrimary, VFColor.bodySecondary,
            VFColor.bodyTertiary, VFColor.bodyOnDark, VFColor.primaryAction,
            VFColor.primaryActionDeep, VFColor.primaryActionPale, VFColor.deepAccent,
            VFColor.supportAccent, VFColor.infoAccent, VFColor.attentionAccent,
            VFColor.hairline, VFColor.inkOutline, VFColor.gameWin, VFColor.gameLoss,
            VFColor.gameDraw, VFColor.gameLive
        ]
        let newTokens: [(String, Color)] = [
            ("fairyMemory", VFFairyColor.memory),
            ("fairyMemorySurface", VFFairyColor.memorySurface),
            ("fairyConcern", VFFairyColor.concern),
            ("fairyFaceOnDark", VFFairyColor.faceOnDark),
            ("fairyIconBgDark", VFFairyColor.iconBackgroundDark)
        ]
        for (name, color) in newTokens {
            XCTAssertFalse(existing.contains(color), "\(name)이 기존 토큰과 같은 값이다 — 별칭으로 두어야 한다")
        }
    }

    /// `fairyFaceOnDark`(#F6F3EA)와 본문용 `bodyOnDark`(#F6F5F0)는 값이 다르다.
    /// 비슷하다고 합치면 얼굴 대비가 원본과 어긋난다.
    func testFaceOnDarkIsNotTheSameAsBodyTextOnDark() {
        XCTAssertNotEqual(VFFairyColor.faceOnDark, VFColor.bodyOnDark)
    }

    // MARK: - 4. 별칭

    func testAliasedFairyRolesResolveToTheIntendedExistingTokens() {
        XCTAssertEqual(VFFairyColor.victory, VFColor.primaryAction, "fairyVictory = gold/coral/butter")
        XCTAssertEqual(VFFairyColor.team, VFColor.infoAccent, "fairyTeam = sky")
        XCTAssertEqual(VFFairyColor.stadium, VFColor.supportAccent, "fairyStadium = sage")
        XCTAssertEqual(VFFairyColor.live, VFColor.gameLive, "fairyLive = live")
        XCTAssertEqual(VFFairyColor.neutral, VFColor.bodyTertiary, "fairyNeutral = ink-faint")
        XCTAssertEqual(VFFairyColor.faceOnLight, VFColor.bodyPrimary, "fairyFaceOnLight = ink")
        XCTAssertEqual(VFFairyColor.iconBackground, VFColor.nightSurface, "fairyIconBg = night")
    }

    /// 별칭은 값을 베끼지 않고 기존 토큰을 **가리켜야** 한다.
    /// 같은 hex를 다시 적어 두면 나중에 한쪽만 바뀌어 조용히 어긋난다.
    func testAliasedRolesReferenceExistingTokensRatherThanRepeatingHex() throws {
        let text = try executableSource("DesignSystem/VFDesignSystem.swift")
        guard let range = text.range(of: "enum VFFairyColor") else {
            return XCTFail("VFFairyColor를 찾을 수 없다")
        }
        let block = String(text[range.lowerBound...])
        let aliasNames = ["victory", "team", "stadium", "live", "neutral", "faceOnLight", "iconBackground"]
        for name in aliasNames {
            guard let line = block
                .split(separator: "\n")
                .first(where: { $0.contains("static let \(name) ") }) else {
                return XCTFail("\(name) 정의를 찾을 수 없다")
            }
            XCTAssertTrue(line.contains("VFColor."), "\(name)은 기존 토큰을 가리켜야 한다")
            XCTAssertFalse(line.contains("Color(hex:"), "\(name)이 hex를 다시 적고 있다")
        }
    }

    // MARK: - 5. 기존 토큰 불변

    /// 이번 패스는 덧붙이기만 한다. 완성된 화면이 조용히 다시 칠해지면 안 된다.
    func testNoPreExistingTokenValueChanged() {
        XCTAssertEqual(VFColor.appBackground, Color(hex: "#F4F4F2"))
        XCTAssertEqual(VFColor.elevatedSurface, Color(hex: "#FFFFFF"))
        XCTAssertEqual(VFColor.subtleSurface, Color(hex: "#EAEAE6"))
        XCTAssertEqual(VFColor.bodyPrimary, Color(hex: "#14171F"))
        XCTAssertEqual(VFColor.bodySecondary, Color(hex: "#4C5160"))
        XCTAssertEqual(VFColor.bodyTertiary, Color(hex: "#8B909E"))
        XCTAssertEqual(VFColor.primaryAction, Color(hex: "#F2B63C"))
        XCTAssertEqual(VFColor.supportAccent, Color(hex: "#2F7A56"))
        XCTAssertEqual(VFColor.infoAccent, Color(hex: "#5E7FA6"))
        XCTAssertEqual(VFColor.inkOutline, Color(hex: "#232A3C"))
        XCTAssertEqual(VFColor.nightSurface, Color(hex: "#0E1526"))
        XCTAssertEqual(VFColor.gameWin, Color(hex: "#2E9E6B"))
        XCTAssertEqual(VFColor.gameLive, Color(hex: "#E5484D"))
        XCTAssertEqual(VFRadius.sm, 10)
        XCTAssertEqual(VFRadius.md, 14)
        XCTAssertEqual(VFRadius.lg, 20)
        XCTAssertEqual(VFSpacing.xxs, 4)
        XCTAssertEqual(VFSpacing.xs, 8)
        XCTAssertEqual(VFSpacing.md, 16)
        XCTAssertEqual(VFSpacing.xl, 24)
    }

    func testAllTenTeamAccentsRemainUnchanged() {
        let expected = [
            "lg-twins": "#B5195B", "doosan-bears": "#1A2C55", "kiwoom-heroes": "#7A1F33",
            "ssg-landers": "#CE4A2D", "kt-wiz": "#2E2E36", "hanwha-eagles": "#E5691F",
            "samsung-lions": "#1E63C4", "kia-tigers": "#C42B26", "lotte-giants": "#1F3E73",
            "nc-dinos": "#1F5B78"
        ]
        for (id, hex) in expected {
            XCTAssertEqual(VFTeamAccent.color(forTeamID: id), Color(hex: hex), "\(id)")
        }
    }

    // MARK: - 6~7. 컴포넌트 대응

    /// Pencil `FairyGlyph_*` 12종.
    private static let pencilGlyphKinds = [
        "base", "victory", "success", "team", "stadium", "memory",
        "loss", "draw", "cancelled", "live", "empty", "error"
    ]

    /// Pencil `Fairy48_*` 8종.
    private static let pencilCompactKinds = [
        "victory", "loss", "draw", "cancelled", "success", "empty", "error", "memory"
    ]

    func testEveryPencilFairyGlyphComponentHasASwiftKind() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(
            Set(VFFairyKind.allCases.map(\.rawValue)), Set(Self.pencilGlyphKinds),
            "Swift 종류가 Pencil FairyGlyph_* 12종과 일치해야 한다"
        )
    }

    func testEveryPencilFairy48ComponentHasASwiftCompactVariant() {
        XCTAssertEqual(VFFairyKind.pencilCompactKinds.count, 8)
        XCTAssertEqual(
            Set(VFFairyKind.pencilCompactKinds.map(\.rawValue)), Set(Self.pencilCompactKinds),
            "48px 축소본은 Pencil이 그린 8종과 일치해야 한다"
        )
    }

    /// base·team·stadium·live는 Pencil에 48px 축소본이 없다.
    /// team/stadium의 축소본은 이후 패스가 다룰 별개 컴포넌트다.
    func testKindsWithoutAPencilCompactVariantAreRecorded() {
        for kind in [VFFairyKind.base, .team, .stadium, .live] {
            XCTAssertFalse(kind.hasPencilCompactVariant, "\(kind.rawValue)는 48px 원본이 없다")
        }
    }

    // MARK: - 8. 원본 치수

    func testCanvasSizesMatchPencil() {
        XCTAssertEqual(VFFairySize.regular.canvas, 96)
        XCTAssertEqual(VFFairySize.compact.canvas, 48)
        XCTAssertEqual(VFFairySize.compact.scale, 0.5)
    }

    /// 48px은 배치만 정확히 절반이고, 선 두께와 눈 지름은 광학 보정을 받는다.
    func testCompactSizeUsesPencilOpticalCorrectionsRatherThanAPlainHalving() {
        XCTAssertEqual(VFFairySize.regular.bodyStroke, 2.016, accuracy: 0.0001)
        XCTAssertEqual(VFFairySize.compact.bodyStroke, 1.2, accuracy: 0.0001)
        XCTAssertGreaterThan(
            VFFairySize.compact.bodyStroke, VFFairySize.regular.bodyStroke / 2,
            "48px 외곽선은 절반보다 두꺼워야 사라지지 않는다"
        )

        XCTAssertEqual(VFFairySize.regular.lineStroke, 2.6, accuracy: 0.0001)
        XCTAssertEqual(VFFairySize.compact.lineStroke, 1.8, accuracy: 0.0001)
        XCTAssertGreaterThan(VFFairySize.compact.lineStroke, VFFairySize.regular.lineStroke / 2)

        XCTAssertEqual(VFFairySize.regular.openEyeDiameter, 7)
        XCTAssertEqual(VFFairySize.compact.openEyeDiameter, 4)
        XCTAssertGreaterThan(
            VFFairySize.compact.openEyeDiameter, VFFairySize.regular.openEyeDiameter / 2,
            "48px 눈은 절반보다 커야 점으로 뭉개지지 않는다"
        )

        // 다이아몬드 외곽선만 두 크기에서 같다.
        XCTAssertEqual(VFFairySize.regular.diamondStroke, VFFairySize.compact.diamondStroke)
    }

    /// Pencil은 48px에서 스파크·일시정지 바·펄스를 모두 뺐다.
    func testAccessoriesAreDroppedAtCompactSize() {
        XCTAssertTrue(VFFairySize.regular.showsAccessory)
        XCTAssertFalse(VFFairySize.compact.showsAccessory)
    }

    func testGeometryRectsMatchPencilNodeBounds() {
        let g = VFFairyGeometry.self
        XCTAssertEqual(g.canvas, 96)
        assertRect(g.bodyRect, 17, 16, 63, 64, "바디")
        assertRect(g.antennaStemRect, 56, 7, 6, 9, "안테나 줄기")
        assertRect(g.antennaDiamondRect, 56.5, 0.5, 9, 9, "안테나 다이아몬드")
        assertRect(g.closedEyeLeftRect, 31, 42, 10, 5, "감은 눈 왼쪽")
        assertRect(g.closedEyeRightRect, 55, 42, 10, 5, "감은 눈 오른쪽")
        assertRect(g.mouthRect, 41, 55, 14, 7, "입")
        assertRect(g.filledMouthRect, 41, 55, 14, 8, "채운 입")
        assertRect(g.openMouthRect, 44.5, 53, 7, 8, "벌어진 입")
        assertRect(g.victorySparkRect, 8, 12, 14, 14, "승리 스파크")
        assertRect(g.successSparkRect, 12, 16, 10, 10, "저장 스파크")
        assertRect(g.pulseRect, 76, 14, 12, 12, "펄스 마크")
        assertRect(g.pauseBarLeftRect, 74, 14, 3.5, 12, "일시정지 바1")
        assertRect(g.pauseBarRightRect, 81, 14, 3.5, 12, "일시정지 바2")
        XCTAssertEqual(g.openEyeLeftOrigin, CGPoint(x: 32.5, y: 41))
        XCTAssertEqual(g.openEyeRightOrigin, CGPoint(x: 56.5, y: 41))
        XCTAssertEqual(g.pulseStroke, 2.4, accuracy: 0.0001)
    }

    /// 몸통 여백은 대칭이 아니다. 왼쪽 17, 나머지 16 — Pencil의 광학 중심 보정이다.
    /// 안테나가 오른쪽 위로 뻗으므로 몸통을 0.5pt 오른쪽으로 밀어 균형을 잡는다.
    func testBodyKeepsItsAsymmetricPencilInsetForOpticalCentring() {
        let g = VFFairyGeometry.self
        XCTAssertEqual(g.bodyRect.x, g.bodyInsetLeading, accuracy: 0.001)
        XCTAssertEqual(g.bodyRect.y, g.bodyInsetTop, accuracy: 0.001)
        XCTAssertEqual(g.canvas - (g.bodyRect.x + g.bodyRect.width), g.bodyInsetTrailing, accuracy: 0.001)
        XCTAssertEqual(g.canvas - (g.bodyRect.y + g.bodyRect.height), g.bodyInsetBottom, accuracy: 0.001)

        // 보정이 실제로 살아 있는지 — 대칭으로 되돌아가면 이 단언이 잡는다.
        XCTAssertNotEqual(g.bodyInsetLeading, g.bodyInsetTrailing, "광학 보정이 사라졌다")
        let bodyCentre = g.bodyRect.x + g.bodyRect.width / 2
        XCTAssertEqual(bodyCentre - g.canvas / 2, 0.5, accuracy: 0.001, "몸통 중심이 0.5pt 오른쪽이어야 한다")

        XCTAssertLessThan(g.antennaDiamondRect.y, g.bodyInsetTop, "안테나는 몸통 여백 위로 올라간다")
        XCTAssertGreaterThanOrEqual(g.antennaDiamondRect.y, 0, "안테나가 캔버스를 넘어가면 안 된다")
    }

    // MARK: - 9~10. 벡터

    private var allPencilPaths: [(name: String, d: String, viewBox: VFFairyGeometry.ViewBox)] {
        let g = VFFairyGeometry.self
        return [
            ("바디", g.bodyPath, g.bodyViewBox),
            ("안테나 줄기", g.antennaStemPath, g.antennaStemViewBox),
            ("안테나 다이아몬드", g.antennaDiamondPath, g.antennaDiamondViewBox),
            ("감은 눈 왼쪽", g.closedEyeLeftPath, g.closedEyeLeftViewBox),
            ("감은 눈 오른쪽", g.closedEyeRightPath, g.closedEyeRightViewBox),
            ("미소", g.smilePath, g.mouthViewBox),
            ("채운 미소", g.filledSmilePath, g.filledMouthViewBox),
            ("평평한 입", g.flatPath, g.mouthViewBox),
            ("옅은 미소", g.gentlePath, g.mouthViewBox),
            ("아쉬운 입", g.frownPath, g.mouthViewBox),
            ("흔들리는 입", g.wavyPath, g.mouthViewBox),
            ("스파크", g.sparkPath, g.sparkViewBox),
            ("펄스", g.pulsePath, g.pulseViewBox)
        ]
    }

    func testEveryPencilPathParsesIntoANonEmptyShape() {
        for entry in allPencilPaths {
            let path = VFSVGPathParser.parse(entry.d)
            XCTAssertFalse(path.isEmpty, "\(entry.name) 경로가 비었다")
            let bounds = path.boundingRect
            XCTAssertTrue(bounds.width > 0 || bounds.height > 0, "\(entry.name) 경로에 넓이가 없다")
        }
    }

    /// 벡터가 자기 viewBox를 넘어가면 배치했을 때 이웃을 침범한다.
    func testEveryPencilPathStaysWithinItsDeclaredViewBox() {
        for entry in allPencilPaths {
            let bounds = VFSVGPathParser.parse(entry.d).boundingRect
            let box = CGRect(x: entry.viewBox.0, y: entry.viewBox.1,
                             width: entry.viewBox.2, height: entry.viewBox.3)
                .insetBy(dx: -0.5, dy: -0.5)
            XCTAssertTrue(
                box.contains(bounds),
                "\(entry.name)이 viewBox를 넘어간다: \(bounds) ⊄ \(box)"
            )
        }
    }

    /// 라이브 펄스는 호(`a`) 명령을 쓴다. 파서가 호를 못 그리면 이 모양만 조용히 사라진다.
    func testThePulseArcCommandIsActuallyRendered() {
        let path = VFSVGPathParser.parse(VFFairyGeometry.pulsePath)
        XCTAssertFalse(path.isEmpty, "펄스 호가 비었다")
        let bounds = path.boundingRect
        // 두 겹의 호가 모두 그려지면 대략 12×12를 채운다. 직선으로 흘렀다면 훨씬 납작하다.
        XCTAssertGreaterThan(bounds.width, 10, "펄스 호가 가로로 펴지지 않았다")
        XCTAssertGreaterThan(bounds.height, 10, "펄스 호가 세로로 펴지지 않았다")
    }

    /// 기본 페어리는 래스터 이미지를 쓰지 않는다. 전부 벡터다.
    func testBaseFairiesRequireNoRasterAsset() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        for needle in ["Image(", "UIImage", ".png", ".jpg", ".pdf", "imageLiteral"] {
            XCTAssertFalse(text.contains(needle), "기본 페어리에 래스터 흔적이 있다: \(needle)")
        }
    }

    /// 두 번째 SVG 파서를 들이지 않는다. 저장소의 `VFVectorPath` 하나만 쓴다.
    func testFairySourceUsesTheExistingVectorMechanism() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        XCTAssertTrue(text.contains("VFVectorPath"), "기존 벡터 기구를 써야 한다")
        XCTAssertFalse(text.contains("struct VFSVGPathParser"), "파서를 새로 만들면 안 된다")
        XCTAssertFalse(text.contains("enum VFSVGPathParser"), "파서를 새로 만들면 안 된다")
    }

    // MARK: - 11~12. 색 출처

    /// 모든 색은 의미 토큰에서 와야 한다. 화면 소스에 hex를 박으면 토큰이 무력해진다.
    ///
    /// `#Preview` 같은 매크로도 `#`으로 시작하므로, 색 코드 모양(`#` + 3·6·8자리
    /// 16진수)만 정확히 찾는다. 낱말 `#`을 통째로 막으면 거짓 실패가 난다.
    func testFairySourceContainsNoRawHexLiterals() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        XCTAssertFalse(text.contains("Color(hex:"), "페어리 소스에 hex 리터럴이 있다")

        let pattern = try NSRegularExpression(pattern: "#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\\b")
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let found = matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } }
        XCTAssertTrue(found.isEmpty, "페어리 소스에 색 코드가 남아 있다: \(found)")
    }

    /// 검사 자체가 동작하는지 확인한다. 색 코드를 못 찾는 검사는 통과해도 뜻이 없다.
    func testHexLiteralDetectorActuallyDetectsHexLiterals() throws {
        let pattern = try NSRegularExpression(pattern: "#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\\b")
        let sample = "let a = Color(hex: \"#9D93C8\")\n#Preview { }\n"
        let matches = pattern.matches(in: sample, range: NSRange(sample.startIndex..., in: sample))
        XCTAssertEqual(matches.count, 1, "색 코드 하나만 잡아야 한다 — #Preview는 아니다")
    }

    func testEveryFairySpecDrawsItsColoursFromSemanticTokens() {
        let allowed: Set<Color> = [
            VFFairyColor.victory, VFFairyColor.team, VFFairyColor.stadium,
            VFFairyColor.live, VFFairyColor.neutral, VFFairyColor.memory,
            VFFairyColor.concern, VFFairyColor.faceOnLight, VFFairyColor.faceOnDark,
            VFColor.subtleSurface, VFColor.bodyTertiary, VFColor.bodySecondary
        ]
        for kind in VFFairyKind.allCases {
            for appearance in VFFairyAppearance.allCases {
                let spec = kind.spec(for: appearance)
                XCTAssertTrue(allowed.contains(spec.body), "\(kind.rawValue)/\(appearance) 몸 색이 토큰 밖이다")
                XCTAssertTrue(allowed.contains(spec.face), "\(kind.rawValue)/\(appearance) 얼굴 색이 토큰 밖이다")
            }
        }
    }

    // MARK: - 13~15. 외형

    /// Pencil은 같은 인스턴스를 `paper` 위와 `night` 위에 아무 재정의 없이 놓는다.
    /// 인앱 글리프는 표면에 따라 다시 칠하지 않는다는 뜻이다.
    func testLightAndDarkSurfacesResolveToTheSameArtwork() {
        for kind in VFFairyKind.allCases {
            XCTAssertEqual(
                kind.spec(for: .onLightSurface), kind.spec(for: .onDarkSurface),
                "\(kind.rawValue)의 라이트/다크 구성이 달라졌다 — Pencil은 같은 아트워크를 쓴다"
            )
        }
    }

    /// 어느 표면에서든 얼굴이 몸과 구분돼야 한다.
    func testEveryKindKeepsFacialContrastAgainstItsBody() {
        for kind in VFFairyKind.allCases {
            let spec = kind.spec(for: .onLightSurface)
            XCTAssertNotEqual(spec.face, spec.body, "\(kind.rawValue)의 얼굴이 몸과 같은 색이라 사라진다")
        }
    }

    /// 모노크롬은 색을 지우되 **표정은 남긴다.** 표정까지 지우면 색약·그레이스케일에서
    /// 뜻을 전할 마지막 신호가 사라진다.
    func testMonochromeRemovesHueButKeepsSilhouetteAndExpression() {
        for kind in VFFairyKind.allCases {
            let colour = kind.spec(for: .onLightSurface)
            let mono = kind.spec(for: .monochrome)
            XCTAssertEqual(mono.eyes, colour.eyes, "\(kind.rawValue) 모노크롬에서 눈이 바뀌었다")
            XCTAssertEqual(mono.mouth, colour.mouth, "\(kind.rawValue) 모노크롬에서 입이 바뀌었다")
            XCTAssertEqual(mono.accessory, colour.accessory, "\(kind.rawValue) 모노크롬에서 곁들임이 바뀌었다")
            XCTAssertNotEqual(mono.body, mono.face, "\(kind.rawValue) 모노크롬에서 표정이 사라진다")
        }
    }

    /// 모노크롬은 종류가 달라도 한 톤이다. 색으로 구분되지 않아야 검증에 뜻이 있다.
    func testMonochromeCollapsesEveryKindToASingleTone() {
        let bodies = Set(VFFairyKind.allCases.map { $0.spec(for: .monochrome).body })
        XCTAssertEqual(bodies.count, 1, "모노크롬 몸 색이 여러 개다")
        let faces = Set(VFFairyKind.allCases.map { $0.spec(for: .monochrome).face })
        XCTAssertEqual(faces.count, 1, "모노크롬 얼굴 색이 여러 개다")
    }

    /// 색을 지워도 승·패·무·취소·라이브가 서로 다른 표정으로 남아야 한다.
    /// Differentiate Without Color에서 의미를 지키는 유일한 장치다.
    func testResultKindsStayDistinguishableWithoutColour() {
        let resultKinds: [VFFairyKind] = [.victory, .loss, .draw, .cancelled, .live]
        let expressions = resultKinds.map { kind -> String in
            let spec = kind.spec(for: .monochrome)
            return "\(spec.eyes)-\(spec.mouth)"
        }
        XCTAssertEqual(
            Set(expressions).count, resultKinds.count,
            "색을 지우면 결과 페어리를 구분할 수 없다: \(expressions)"
        )
    }

    // MARK: - 16~19. 접근성 계약

    func testMeaningfulKindsDeclareWhatTheyMustBePairedWith() {
        XCTAssertEqual(VFFairyKind.base.pairing, .decorative)
        XCTAssertEqual(VFFairyKind.team.pairing, .requiresTeamName)
        XCTAssertEqual(VFFairyKind.stadium.pairing, .requiresStadiumName)
        for kind in [VFFairyKind.victory, .loss, .draw, .cancelled, .live, .success, .empty, .error, .memory] {
            XCTAssertEqual(kind.pairing, .requiresResultText, "\(kind.rawValue)는 읽을 문구가 함께 있어야 한다")
        }
    }

    func testOnlyTheBaseKindIsPurelyDecorative() {
        let decorative = VFFairyKind.allCases.filter { !$0.isMeaningful }
        XCTAssertEqual(decorative, [.base], "장식으로 둘 수 있는 것은 기본형뿐이다")
    }

    /// 라벨은 부르는 쪽이 준다. 컴포넌트가 문구를 지어내지 않는다.
    func testGlyphAcceptsCallerProvidedAccessibilityText() {
        let labelled = VFFairyGlyph(.victory, accessibilityLabel: "승리")
        XCTAssertEqual(labelled.accessibilityLabel, "승리")
        let stadium = VFFairyGlyph(.stadium, accessibilityLabel: "잠실야구장")
        XCTAssertEqual(stadium.accessibilityLabel, "잠실야구장")
    }

    /// 라벨을 주지 않으면 장식이다. 기본값이 "숨김"이어야 사고가 나지 않는다.
    func testDecorativeGlyphHasNoLabelByDefault() {
        for kind in VFFairyKind.allCases {
            XCTAssertNil(VFFairyGlyph(kind).accessibilityLabel, "\(kind.rawValue) 기본값에 라벨이 붙어 있다")
        }
    }

    /// 컴포넌트 이름이나 원시값이 VoiceOver로 새어 나가면 안 된다.
    /// 소스에 고정 문구 라벨이 없다는 것으로 확인한다.
    func testComponentNamesAreNeverSpoken() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        XCTAssertFalse(
            text.contains("accessibilityLabel(\""),
            "페어리 소스가 고정 문구를 읽어 주고 있다 — 라벨은 부르는 쪽이 준다"
        )
        XCTAssertFalse(
            text.contains("accessibilityLabel(kind"),
            "종류 이름을 읽어 주면 안 된다"
        )
        XCTAssertFalse(
            text.contains("accessibilityLabel(String(describing"),
            "타입 이름을 읽어 주면 안 된다"
        )
        // 라벨을 통째로 넘겨받는 경로만 있어야 한다.
        XCTAssertTrue(text.contains("accessibilityLabel(label)"), "부르는 쪽 라벨을 쓰는 경로가 없다")
    }

    // MARK: - 20~21. 팀·구장 래퍼 경계

    /// 이 파일은 팀도 구장도 알지 못한다. 이후 래퍼가 그 지식을 가진다.
    func testFairyFoundationKnowsNothingAboutTeamsOrStadiums() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        let forbidden = [
            "KBOSeed", "KBOTeam", "KBOStadium", "TeamTheme", "VFTeamAccent",
            "samsung", "Samsung", "잠실", "라이온즈", "SwiftData", "AppDataStore",
            "UserPreferencesStore", "APIClient"
        ]
        for needle in forbidden {
            XCTAssertFalse(text.contains(needle), "기반 파일이 \(needle)을 알고 있다 — 래퍼로 미뤄야 한다")
        }
    }

    func testFairyFoundationImportsOnlySwiftUI() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        let imports = text
            .split(separator: "\n")
            .filter { $0.hasPrefix("import ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(imports, ["import SwiftUI"], "기반 파일은 SwiftUI 말고 아무것도 들이지 않는다")
    }

    // MARK: - 22. 유틸리티 아이콘 카브아웃

    func testNativeUtilityActionsStayOutsideTheFairySystem() {
        let utilities = [
            "back", "close", "edit", "delete", "settings", "chevron", "overflow",
            "retry", "camera", "photoPicker", "calendarPrevious", "calendarNext",
            "disclosure", "destructiveAction"
        ]
        for action in utilities {
            XCTAssertTrue(
                VFFairyIconPolicy.nativeUtilityActions.contains(action),
                "\(action)이 카브아웃 목록에 없다"
            )
            XCTAssertFalse(
                VFFairyIconPolicy.allowsFairy(for: action),
                "\(action)에 페어리를 허용하면 안 된다"
            )
        }
    }

    func testFairyEligibleRolesAreIdentityAndStateOnly() {
        for role in ["brandIdentity", "teamIdentity", "stadiumIdentity", "resultIdentity",
                     "emotionalMemory", "emptyState", "errorState"] {
            XCTAssertTrue(VFFairyIconPolicy.fairyEligibleRoles.contains(role), "\(role)")
            XCTAssertTrue(VFFairyIconPolicy.allowsFairy(for: role))
        }
        XCTAssertTrue(
            VFFairyIconPolicy.nativeUtilityActions
                .isDisjoint(with: VFFairyIconPolicy.fairyEligibleRoles),
            "유틸리티와 페어리 자리가 겹치면 안 된다"
        )
    }

    // MARK: - 화면 밀도 지침

    func testScreenDensityGuidanceMatchesPencil() {
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3, "Pencil 지침은 화면당 1~3개다")
        XCTAssertEqual(VFFairyIconPolicy.maximumEmotionalMomentsPerScreen, 1)
    }

    // MARK: - 23~30. 이번 패스의 경계

    /// 기반 글리프는 **Pencil이 지정한 자리에만** 나타나야 한다.
    ///
    /// 앞 패스에서는 "아직 어디에도 없다"를 확인했다. 배치 패스가 실제로 놓았으므로
    /// 이제는 허용 목록으로 묶는다. 검사 강도는 오히려 올라갔다 — 허용되지 않은
    /// 파일에 하나라도 번지면 실패한다.
    func testFairyGlyphAppearsOnlyInAuthorisedPlacements() throws {
        let authorised: Set<String> = [
            "VFCoreComponents.swift",   // 09_States 빈 기록 · 빈 시즌 · 오류
            "OnboardingView.swift",     // Onboarding_05_Complete 완료 성공 페어리
            "CalendarViews.swift",      // 선택일 결과 페어리
            "StatisticsViews.swift",    // 시즌 시그니처 페어리
            "ProfileSettingsView.swift" // 08_Profile_Settings 프로필 카드 아바타
        ]
        var found: Set<String> = []
        for folder in ["Features", "SharedComponents"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in e where url.pathExtension == "swift" {
                let body = stripComments(try String(contentsOf: url, encoding: .utf8))
                if body.contains("VFFairyGlyph(") { found.insert(url.lastPathComponent) }
            }
        }
        XCTAssertEqual(found, authorised, "기반 글리프가 허용되지 않은 곳에 번졌거나 빠졌다")
    }

    /// 완성된 다섯 화면의 정체성 식별자가 그대로 남아 있어야 한다.
    ///
    /// 식별자가 사는 곳은 화면 파일만이 아니다. 시즌 아카이브와 기록 상세는 의미 모델
    /// (`SeasonArchive`·`RecordDetail`)이 식별자를 들고 있고, 홈의 팀 아이덴티티는
    /// 공용 컴포넌트에 있다. 실제 위치를 확인하고 적었다.
    func testCompletedScreensRemainInPlace() throws {
        let expectations: [(String, String)] = [
            ("Features/Home/HomeView.swift", "home.root"),
            ("SharedComponents/VFHomeComponents.swift", "home.teamIdentity"),
            ("Features/Feed/FeedViews.swift", "feed.addRecord"),
            ("Features/Calendar/CalendarViews.swift", "calendar.selectedDetail"),
            ("Domain/SeasonArchive.swift", "statistics.root"),
            ("Domain/RecordDetail.swift", "recordDetail.root")
        ]
        for (path, identifier) in expectations {
            let text = try source(path)
            XCTAssertTrue(text.contains(identifier), "\(path)의 \(identifier)가 사라졌다")
        }
    }

    /// 앱 아이콘 카탈로그는 이번 패스에서 손대지 않는다.
    func testAppIconCatalogStillDeclaresExactlyTheShippedRenditions() throws {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/AppIcon.appiconset/Contents.json")
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = json?["images"] as? [[String: Any]] ?? []
        XCTAssertEqual(images.count, 3, "AppIcon 렌디션 수가 바뀌었다")
        let filenames = Set(images.compactMap { $0["filename"] as? String })
        XCTAssertEqual(
            filenames,
            ["AppIcon-1024.png", "AppIcon-1024-Dark.png", "AppIcon-1024-Tinted.png"],
            "AppIcon 파일 구성이 바뀌었다"
        )
        for name in filenames {
            let file = url.deletingLastPathComponent().appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: file.path), "\(name)이 없다")
        }
    }

    /// 런치 마크도 이번 패스의 범위가 아니다.
    func testLaunchMarkAssetIsUntouched() {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchMark.imageset/LaunchMark.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "LaunchMark.pdf가 사라졌다")
    }

    // MARK: - 31~34. 바깥 경계

    /// 기반 패스는 도메인·저장소·네트워크를 건드리지 않는다.
    func testFoundationTouchesNoDomainOrPersistenceOrNetworkContract() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        for needle in ["URLSession", "Codable", "@Model", "ModelContainer",
                       "UserDefaults", "FileManager", "async ", "await "] {
            XCTAssertFalse(text.contains(needle), "기반 파일이 \(needle)을 쓰고 있다")
        }
    }

    private func assertRect(
        _ rect: VFFairyGeometry.Rect,
        _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat,
        _ label: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(rect.x, x, accuracy: 0.001, "\(label) x", file: file, line: line)
        XCTAssertEqual(rect.y, y, accuracy: 0.001, "\(label) y", file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: 0.001, "\(label) width", file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: 0.001, "\(label) height", file: file, line: line)
    }
}
