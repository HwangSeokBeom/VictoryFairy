import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import VictoryFairy

/// 개정 Pencil(8e055d8a…3d6db2) `02_TeamFairy_System`의 Team Fairy 계약을 확인한다.
///
/// 기대값은 모두 Pencil 노드에서 직접 읽은 것이다. 여기 숫자를 고쳐야 한다면 원본이
/// 바뀐 것이므로, 원본을 다시 읽고 근거를 남긴 뒤에 고쳐야 한다.
final class TeamFairyContractTests: XCTestCase {

    static let revisedPencilSHA256 = "8e055d8abc51d541228c734ce007fe28d3b357cb3f3c691fe32454d7ab3d6db2"

    // MARK: - 소스 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func source(_ path: String) throws -> String {
        let url = Self.appSourceRoot.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("소스를 찾을 수 없다: \(url.path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 주석을 걷어낸 소스. 이 파일들의 주석에는 구단 이름이 실제로 들어 있어,
    /// 그대로 훑으면 설명 문장이 검사에 걸려 거짓 판정이 난다.
    private func executableSource(_ path: String) throws -> String {
        stripComments(try source(path))
    }

    private func stripComments(_ text: String) -> String {
        var output = ""
        let characters = Array(text)
        var index = 0
        var inLine = false, inBlock = false, inString = false
        while index < characters.count {
            let c = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            if inLine {
                if c == "\n" { inLine = false; output.append(c) }
                index += 1; continue
            }
            if inBlock {
                if c == "*", next == "/" { inBlock = false; index += 2; continue }
                index += 1; continue
            }
            if inString {
                if c == "\\" { index += 2; continue }
                if c == "\"" { inString = false }
                output.append(c); index += 1; continue
            }
            if c == "/", next == "/" { inLine = true; index += 2; continue }
            if c == "/", next == "*" { inBlock = true; index += 2; continue }
            if c == "\"" { inString = true }
            output.append(c); index += 1
        }
        return output
    }

    // MARK: - 대비 계산

    private func components(_ color: Color) -> (CGFloat, CGFloat, CGFloat)? {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (r, g, b)
        #else
        return nil
        #endif
    }

    private func luminance(_ color: Color) -> CGFloat? {
        guard let (r, g, b) = components(color) else { return nil }
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    private func contrast(_ a: Color, _ b: Color) -> CGFloat? {
        guard let la = luminance(a), let lb = luminance(b) else { return nil }
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private var canonicalTeamIDs: [String] { KBOSeed.teams.filter(\.active).map(\.id) }

    // MARK: - 1. 원본

    func testRevisedPencilHashIsStillTheRecordedSource() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    // MARK: - 2. Pencil 컴포넌트 대응

    /// Pencil `TeamFairy_*` 11종 + `TeamFairy48`. 이름은 원본에서 직접 읽었다.
    private static let pencilTeamFairyComponents = [
        "TeamFairy_Samsung", "TeamFairy_LG", "TeamFairy_Doosan", "TeamFairy_KIA",
        "TeamFairy_KT", "TeamFairy_SSG", "TeamFairy_NC", "TeamFairy_Lotte",
        "TeamFairy_Kiwoom", "TeamFairy_Hanwha", "TeamFairy_Neutral"
    ]

    /// Pencil 각 컴포넌트의 자식 수. 우리 요소 목록이 이 수와 같아야 한다.
    private static let pencilChildCounts: [VFTeamFairyTrait: Int] = [
        .lionMane: 11, .twinAntenna: 13, .bearFeatures: 15, .tigerStripes: 15,
        .wizardHat: 9, .rocketFin: 12, .dinoSpikes: 13, .giantFrame: 9,
        .heroMask: 12, .eagleWings: 13, .neutral: 10
    ]

    func testEveryPencilTeamFairyComponentHasASwiftTrait() {
        XCTAssertEqual(Self.pencilTeamFairyComponents.count, 11, "Pencil TeamFairy_* 는 11종이다")
        XCTAssertEqual(VFTeamFairyTrait.allCases.count, 11, "Swift 특징도 11종이어야 한다")
        XCTAssertEqual(VFTeamFairyTrait.clubTraits.count, 10, "중립을 뺀 구단 특징은 10종이다")
    }

    /// 요소 수가 Pencil 자식 수와 정확히 같아야 한다. 조각을 빠뜨리거나 더하면 잡힌다.
    func testElementCountMatchesPencilChildCountForEveryTrait() {
        for trait in VFTeamFairyTrait.allCases {
            guard let expected = Self.pencilChildCounts[trait] else {
                return XCTFail("\(trait.rawValue) 기대 자식 수가 없다")
            }
            XCTAssertEqual(
                trait.elements(size: .regular).count, expected,
                "\(trait.rawValue) 요소 수가 Pencil과 다르다"
            )
        }
    }

    // MARK: - 3~6. canonical 팀

    func testAllTenCanonicalTeamsAreCovered() {
        XCTAssertEqual(canonicalTeamIDs.count, 10, "KBO 구단은 10개다")
        for id in canonicalTeamIDs {
            XCTAssertNotEqual(
                VFTeamFairyTrait.trait(forTeamID: id), .neutral,
                "\(id)에 구단 특징이 없어 중립으로 떨어진다"
            )
        }
    }

    func testNoFictionalTeamExistsInTheTraitTable() {
        let canonical = Set(canonicalTeamIDs)
        for id in VFTeamFairyTrait.coveredTeamIDs {
            XCTAssertTrue(canonical.contains(id), "\(id)는 canonical 팀이 아니다")
        }
        XCTAssertEqual(VFTeamFairyTrait.coveredTeamIDs, canonical, "특징 표와 canonical 목록이 어긋난다")
    }

    func testEveryTeamGetsADistinctTrait() {
        let traits = canonicalTeamIDs.map { VFTeamFairyTrait.trait(forTeamID: $0) }
        XCTAssertEqual(Set(traits).count, 10, "두 구단이 같은 특징을 쓰고 있다")
    }

    /// 팀 정체성은 canonical ID로만 온다. 표시 이름을 정체성으로 쓰지 않는다.
    func testCanonicalTeamIDsAreTheIdentityAndLegacyIDsNormalise() {
        XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: "samsung-lions"), .lionMane)
        // 예전 짧은 ID도 KBOSeed가 정규화해 같은 특징으로 온다.
        if KBOSeed.normalizedTeamID("lg") != nil {
            XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: "lg"), .twinAntenna, "예전 ID가 정규화되지 않는다")
        }
        // 한국어 표시 이름은 정체성이 아니다.
        XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: "삼성 라이온즈"), .neutral, "표시 이름을 ID로 받아들이면 안 된다")
    }

    func testDisplayNamesAreNotEmbeddedInTheDrawingSource() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        for name in KBOSeed.teams.map(\.name) {
            XCTAssertFalse(text.contains(name), "그리기 소스에 팀 표시 이름 \"\(name)\"이 박혀 있다")
        }
    }

    // MARK: - 5. 중립

    func testNeutralIsDistinctFromEveryCanonicalTeam() {
        let neutral = VFTeamFairyTrait.trait(forTeamID: nil)
        XCTAssertEqual(neutral, .neutral)
        for id in canonicalTeamIDs {
            XCTAssertNotEqual(VFTeamFairyTrait.trait(forTeamID: id), neutral, "\(id)가 중립과 같다")
        }
    }

    /// 중립은 "모르는 팀"이 아니라 "아직 고르지 않음"이다. 특정 구단 색을 쓰지 않는다.
    func testNeutralUsesASemanticTokenRatherThanAnyTeamAccent() {
        let neutral = VFTeamFairyPalette.resolve(teamID: nil, appearance: .onLightSurface)
        XCTAssertEqual(neutral.accent, VFFairyColor.team, "중립은 fairyTeam 토큰을 써야 한다")
        for id in canonicalTeamIDs {
            XCTAssertNotEqual(
                neutral.accent, VFTeamAccent.color(forTeamID: id),
                "중립 색이 \(id) 팀 색과 같아 특정 구단을 암시한다"
            )
        }
    }

    /// 중립은 구단 특징을 하나도 달지 않는다. 표준 캡만 쓴다.
    func testNeutralCarriesNoClubSpecificGeometry() {
        let names = Set(VFTeamFairyTrait.neutral.elements(size: .regular).map(\.name))
        for forbidden in ["사자 갈기", "곰 귀 왼쪽", "호랑이 귀 왼쪽", "마법사 모자",
                          "랜더스 핀", "공룡 스파이크", "히어로 마스크", "독수리 날개 왼쪽",
                          "안테나 줄기 2", "캡 투톤 우측"] {
            XCTAssertFalse(names.contains(forbidden), "중립에 구단 특징 \(forbidden)이 있다")
        }
        XCTAssertTrue(names.contains("캡 돔"), "중립도 같은 가족이라 캡은 있어야 한다")
    }

    // MARK: - 17~19. 선택 상태

    /// Pencil에 팀 페어리의 선택 변형이 없다는 사실을 계약으로 남긴다.
    /// 선택은 감싸는 카드가 알린다.
    func testSelectionDoesNotAlterTheFairyArtwork() {
        for id in canonicalTeamIDs.map({ Optional($0) }) + [nil] {
            let unselected = VFTeamFairy(teamID: id, selection: .unselected)
            let selected = VFTeamFairy(teamID: id, selection: .selected)
            XCTAssertEqual(
                unselected.elements, selected.elements,
                "\(id ?? "중립") 선택 상태가 그림을 바꾸고 있다 — Pencil은 카드로 알린다"
            )
            XCTAssertEqual(unselected.palette.accent, selected.palette.accent,
                           "\(id ?? "중립") 선택이 색을 바꾸고 있다")
        }
    }

    func testSelectedStateIsNeverCommunicatedByColourAlone() {
        XCTAssertTrue(VFTeamFairySelection.selected.requiredAffordances.contains(.checkmark),
                      "선택은 체크 표시를 반드시 동반해야 한다")
        XCTAssertFalse(VFTeamFairySelection.selected.requiredAffordances.isEmpty)
        for state in VFTeamFairySelection.allCases {
            XCTAssertTrue(state.isCommunicatedWithoutColour, "\(state) 상태가 색에만 기대고 있다")
        }
    }

    func testUnselectedStateRequiresNothingExtra() {
        XCTAssertTrue(VFTeamFairySelection.unselected.requiredAffordances.isEmpty)
        XCTAssertTrue(VFTeamFairySelection.unselected.supplementaryAffordances.isEmpty)
    }

    /// 체크 표시는 네이티브로 남는다. 페어리로 바꾸지 않는다.
    func testCheckmarkRemainsANativeAffordanceAndIsNotDrawnByTheFairy() throws {
        XCTAssertTrue(VFTeamFairyAffordance.allCases.contains(.checkmark))
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        XCTAssertFalse(text.contains("checkmark.circle"), "페어리가 체크 표시를 직접 그리고 있다")
        XCTAssertFalse(text.contains("circle-check"), "페어리가 체크 표시를 직접 그리고 있다")
        for trait in VFTeamFairyTrait.allCases {
            let names = trait.elements(size: .regular).map(\.name)
            XCTAssertFalse(names.contains(where: { $0.contains("체크") }), "\(trait.rawValue)가 체크를 그린다")
        }
    }

    // MARK: - 11~13. 치수

    func testStandardTeamFairyBoundsMatchPencil() {
        XCTAssertEqual(VFTeamFairySize.regular.canvas, 96)
        let elements = VFTeamFairyTrait.neutral.elements(size: .regular)
        func rect(_ name: String) -> CGRect? { elements.first { $0.name == name }?.rect }

        XCTAssertEqual(rect("바디"), CGRect(x: 17, y: 16, width: 63, height: 64))
        XCTAssertEqual(rect("캡 돔"), CGRect(x: 25, y: 10, width: 46, height: 26))
        XCTAssertEqual(rect("캡 재봉선"), CGRect(x: 47, y: 12, width: 2, height: 19))
        XCTAssertEqual(rect("캡 챙"), CGRect(x: 12, y: 31, width: 24, height: 6))
        XCTAssertEqual(rect("캡 버튼"), CGRect(x: 45, y: 7.5, width: 6, height: 6))
        XCTAssertEqual(rect("안테나 줄기"), CGRect(x: 56, y: 7, width: 6, height: 9))
        XCTAssertEqual(rect("안테나 다이아몬드"), CGRect(x: 56.5, y: 0.5, width: 9, height: 9))
        XCTAssertEqual(rect("눈 왼쪽"), CGRect(x: 32.5, y: 43, width: 7, height: 7))
        XCTAssertEqual(rect("눈 오른쪽"), CGRect(x: 56.5, y: 43, width: 7, height: 7))
        XCTAssertEqual(rect("입"), CGRect(x: 41, y: 57, width: 14, height: 6))
    }

    /// 얼굴이 기본 글리프보다 2pt 아래에 있다. 캡이 위쪽을 차지하기 때문이다.
    func testTeamFairyFaceSitsLowerThanTheBaseGlyphFace() {
        XCTAssertEqual(VFTeamFairyGeometry.eyeLeftOrigin.y - VFFairyGeometry.openEyeLeftOrigin.y, 2)
        XCTAssertEqual(VFTeamFairyGeometry.mouthRect.minY - VFFairyGeometry.mouthRect.y, 2)
    }

    func testTeamFairy48BoundsMatchPencil() {
        XCTAssertEqual(VFTeamFairySize.compact.canvas, 48)
        let elements = VFTeamFairyTrait.neutral.elements(size: .compact)
        func rect(_ name: String) -> CGRect? { elements.first { $0.name == name }?.rect }

        XCTAssertEqual(rect("바디"), CGRect(x: 8.5, y: 8, width: 31.5, height: 32))
        XCTAssertEqual(rect("캡 돔"), CGRect(x: 12.5, y: 5, width: 23, height: 13))
        XCTAssertEqual(rect("캡 챙"), CGRect(x: 6, y: 15.5, width: 12, height: 3))
        XCTAssertEqual(rect("안테나 줄기"), CGRect(x: 28, y: 3.5, width: 3, height: 4.5))
        XCTAssertEqual(rect("안테나 다이아몬드"), CGRect(x: 28.25, y: 0.25, width: 4.5, height: 4.5))
        XCTAssertEqual(rect("눈 왼쪽"), CGRect(x: 16.25, y: 21.5, width: 4, height: 4))
        XCTAssertEqual(rect("눈 오른쪽"), CGRect(x: 28.25, y: 21.5, width: 4, height: 4))
        XCTAssertEqual(rect("입"), CGRect(x: 20.5, y: 28.5, width: 7, height: 3))
    }

    /// Pencil `TeamFairy48`은 자식이 8개다 — 재봉선·버튼·구단 특징이 모두 빠진다.
    func testTeamFairy48DropsFineDetailExactlyAsPencilDoes() {
        for trait in VFTeamFairyTrait.allCases {
            let elements = trait.elements(size: .compact)
            XCTAssertEqual(elements.count, 8, "\(trait.rawValue) 48px 요소 수가 Pencil(8)과 다르다")
            let names = Set(elements.map(\.name))
            XCTAssertFalse(names.contains("캡 재봉선"), "48px에 재봉선이 남아 있다")
            XCTAssertFalse(names.contains("캡 버튼"), "48px에 버튼이 남아 있다")
            XCTAssertEqual(
                names, ["바디", "캡 돔", "캡 챙", "안테나 줄기", "안테나 다이아몬드", "눈 왼쪽", "눈 오른쪽", "입"],
                "\(trait.rawValue) 48px 구성이 Pencil과 다르다"
            )
        }
    }

    /// 48px에서 모든 팀이 같은 구성이라, 팀을 구분하는 것은 **캡 색뿐이다.**
    /// 그래서 작은 크기에서는 팀 이름을 곁에 두는 것이 필수다.
    func testAtCompactSizeOnlyTheCapColourDistinguishesTeams() {
        let shapes = canonicalTeamIDs.map { id in
            VFTeamFairyTrait.trait(forTeamID: id).elements(size: .compact).map(\.name)
        }
        for names in shapes {
            XCTAssertEqual(names, shapes[0], "48px 구성이 팀마다 달라지면 안 된다")
        }
        XCTAssertEqual(VFTeamFairy.pairing, .requiresTeamName, "팀 이름 병기가 필수여야 한다")
    }

    /// 48px 팀 페어리는 기본 글리프의 일반 축소본으로 대체할 수 없다.
    func testTeamFairy48IsNotTheGenericCompactBaseGlyph() {
        XCTAssertFalse(
            VFFairyKind.team.hasPencilCompactVariant,
            "기본 글리프 team 종류에는 Pencil 48px 원본이 없다"
        )
        let teamNames = Set(VFTeamFairyTrait.neutral.elements(size: .compact).map(\.name))
        XCTAssertTrue(teamNames.contains("캡 돔"), "팀 48px에는 캡이 있어야 한다")
        // 기본 글리프에는 캡이라는 개념 자체가 없다.
        XCTAssertNotEqual(
            VFTeamFairyGeometry.mouthViewBox,
            CGRect(x: VFFairyGeometry.mouthViewBox.0, y: VFFairyGeometry.mouthViewBox.1,
                   width: VFFairyGeometry.mouthViewBox.2, height: VFFairyGeometry.mouthViewBox.3),
            "팀 입 viewBox가 기본 글리프와 같아졌다"
        )
    }

    /// 48px 입은 viewBox가 경로에 맞게 좁혀진다. 96px의 것을 그대로 쓰면 어긋난다.
    func testCompactMouthUsesTheTightenedPencilViewBox() {
        let compact = VFTeamFairyTrait.neutral.elements(size: .compact).first { $0.name == "입" }
        guard case let .path(_, viewBox)? = compact?.shape else { return XCTFail("48px 입이 없다") }
        XCTAssertEqual(viewBox, CGRect(x: 43, y: 59, width: 10, height: 3))

        let regular = VFTeamFairyTrait.neutral.elements(size: .regular).first { $0.name == "입" }
        guard case let .path(_, regularViewBox)? = regular?.shape else { return XCTFail("96px 입이 없다") }
        XCTAssertEqual(regularViewBox, CGRect(x: 41, y: 57, width: 14, height: 6))
        XCTAssertNotEqual(viewBox, regularViewBox, "두 크기의 입 viewBox가 같아졌다")
    }

    func testCompactStrokesUseOpticalCorrectionRatherThanAPlainHalving() {
        XCTAssertGreaterThan(VFTeamFairySize.compact.heavyStroke, VFTeamFairySize.regular.heavyStroke / 2)
        XCTAssertGreaterThan(VFTeamFairySize.compact.lineStroke, VFTeamFairySize.regular.lineStroke / 2)
        XCTAssertGreaterThan(VFTeamFairySize.compact.brimStroke, VFTeamFairySize.regular.brimStroke / 2)
        XCTAssertGreaterThan(VFTeamFairySize.compact.eyeDiameter, VFTeamFairySize.regular.eyeDiameter / 2)
        XCTAssertEqual(VFTeamFairySize.compact.eyeDiameter, 4)
    }

    // MARK: - 14~16. 공유 기하

    /// 열한 종류 모두 같은 몸통 실루엣을 쓴다. 열 개의 다른 캐릭터가 되지 않게 한다.
    func testEveryTraitSharesTheSameBodySilhouette() {
        var paths = Set<String>()
        var viewBoxes = Set<CGRect>()
        for trait in VFTeamFairyTrait.allCases {
            guard let body = trait.elements(size: .regular).first(where: { $0.name == "바디" }),
                  case let .path(d, viewBox) = body.shape else {
                return XCTFail("\(trait.rawValue)에 바디가 없다")
            }
            paths.insert(d)
            viewBoxes.insert(viewBox)
        }
        XCTAssertEqual(paths.count, 1, "몸통 경로가 팀마다 다르다")
        XCTAssertEqual(viewBoxes.count, 1, "몸통 viewBox가 팀마다 다르다")
        XCTAssertEqual(paths.first, VFFairyGeometry.bodyPath, "기본 글리프와 같은 몸통을 써야 한다")
    }

    /// 롯데만 몸통을 키운다. 실루엣은 같고 크기만 다르다 — Pencil이 그렇게 그렸다.
    func testOnlyTheGiantTraitScalesTheSharedBody() {
        let standard = CGRect(x: 17, y: 16, width: 63, height: 64)
        for trait in VFTeamFairyTrait.allCases where trait != .giantFrame {
            let body = trait.elements(size: .regular).first { $0.name == "바디" }
            XCTAssertEqual(body?.rect, standard, "\(trait.rawValue) 몸통 크기가 표준과 다르다")
        }
        let giant = VFTeamFairyTrait.giantFrame.elements(size: .regular).first { $0.name == "바디" }
        XCTAssertEqual(giant?.rect, CGRect(x: 14.5, y: 13, width: 68, height: 68))
        // 48px에서는 롯데도 표준 몸통으로 돌아간다. Pencil TeamFairy48이 하나뿐이기 때문이다.
        let giantCompact = VFTeamFairyTrait.giantFrame.elements(size: .compact).first { $0.name == "바디" }
        XCTAssertEqual(giantCompact?.rect, CGRect(x: 8.5, y: 8, width: 31.5, height: 32))
    }

    /// 얼굴은 열한 종류가 모두 같은 자리, 같은 크기다.
    func testEveryTraitSharesTheSameFacialGeometry() {
        for trait in VFTeamFairyTrait.allCases {
            let elements = trait.elements(size: .regular)
            func rect(_ name: String) -> CGRect? { elements.first { $0.name == name }?.rect }
            XCTAssertEqual(rect("눈 왼쪽"), CGRect(x: 32.5, y: 43, width: 7, height: 7), "\(trait.rawValue) 왼눈")
            XCTAssertEqual(rect("눈 오른쪽"), CGRect(x: 56.5, y: 43, width: 7, height: 7), "\(trait.rawValue) 오른눈")
            XCTAssertEqual(rect("입"), CGRect(x: 41, y: 57, width: 14, height: 6), "\(trait.rawValue) 입")
        }
    }

    /// 안테나도 모두 같다. LG만 하나 더 단다.
    func testEveryTraitSharesTheSameAntennaGeometry() {
        for trait in VFTeamFairyTrait.allCases {
            let elements = trait.elements(size: .regular)
            func rect(_ name: String) -> CGRect? { elements.first { $0.name == name }?.rect }
            XCTAssertEqual(rect("안테나 줄기"), CGRect(x: 56, y: 7, width: 6, height: 9), "\(trait.rawValue)")
            XCTAssertEqual(rect("안테나 다이아몬드"), CGRect(x: 56.5, y: 0.5, width: 9, height: 9), "\(trait.rawValue)")
        }
        let lgNames = Set(VFTeamFairyTrait.twinAntenna.elements(size: .regular).map(\.name))
        XCTAssertTrue(lgNames.contains("안테나 줄기 2"), "LG는 안테나가 둘이다")
        for trait in VFTeamFairyTrait.allCases where trait != .twinAntenna {
            let names = Set(trait.elements(size: .regular).map(\.name))
            XCTAssertFalse(names.contains("안테나 줄기 2"), "\(trait.rawValue)에 둘째 안테나가 있다")
        }
    }

    /// 몸통·얼굴·안테나 밖에서만 팀이 갈린다.
    func testOnlyApprovedAccentGeometryVariesBetweenTeams() {
        let shared = Set(["바디", "안테나 줄기", "안테나 다이아몬드", "눈 왼쪽", "눈 오른쪽", "입"])
        for trait in VFTeamFairyTrait.allCases {
            let sharedElements = trait.elements(size: .regular).filter { shared.contains($0.name) }
            XCTAssertEqual(sharedElements.count, 6, "\(trait.rawValue)에 공유 조각이 빠졌거나 겹친다")
        }
    }

    // MARK: - 8~10. 색 소유권

    func testTeamAccentsComeFromTheCanonicalRegistry() {
        for id in canonicalTeamIDs {
            let palette = VFTeamFairyPalette.resolve(teamID: id, appearance: .onLightSurface)
            XCTAssertEqual(palette.accent, VFTeamAccent.color(forTeamID: id), "\(id) 강조색 출처가 다르다")
        }
    }

    func testNoDuplicateTeamColourLiteralsInTheFairySource() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        XCTAssertFalse(text.contains("Color(hex:"), "팀 페어리 소스에 색 리터럴이 있다")
        let pattern = try NSRegularExpression(pattern: "#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\\b")
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let found = matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } }
        XCTAssertTrue(found.isEmpty, "팀 페어리 소스에 색 코드가 있다: \(found)")
        XCTAssertFalse(text.contains("byTeamID: [String: Color]"), "두 번째 팀 색 표를 만들면 안 된다")
    }

    func testNoExistingTeamColourChanged() {
        let expected = [
            "lg-twins": "#B5195B", "doosan-bears": "#1A2C55", "kiwoom-heroes": "#7A1F33",
            "ssg-landers": "#CE4A2D", "kt-wiz": "#2E2E36", "hanwha-eagles": "#E5691F",
            "samsung-lions": "#1E63C4", "kia-tigers": "#C42B26", "lotte-giants": "#1F3E73",
            "nc-dinos": "#1F5B78"
        ]
        for (id, hex) in expected {
            XCTAssertEqual(VFTeamAccent.color(forTeamID: id), Color(hex: hex), "\(id) 강조색이 바뀌었다")
        }
    }

    // MARK: - 20~22. 외형

    func testLightAndDarkSurfacesResolveToTheSamePalette() {
        for id in canonicalTeamIDs.map({ Optional($0) }) + [nil] {
            let light = VFTeamFairyPalette.resolve(teamID: id, appearance: .onLightSurface)
            let dark = VFTeamFairyPalette.resolve(teamID: id, appearance: .onDarkSurface)
            let label = id ?? "중립"
            XCTAssertEqual(light.accent, dark.accent, "\(label) 강조색이 표면에 따라 달라졌다")
            XCTAssertEqual(light.body, dark.body, "\(label) 몸")
            XCTAssertEqual(light.face, dark.face, "\(label) 얼굴")
            XCTAssertEqual(light.outline, dark.outline, "\(label) 외곽선")
            XCTAssertEqual(light.diamond, dark.diamond, "\(label) 다이아몬드")
        }
    }

    /// 모노크롬은 팀 색을 지운다. 열 팀이 모두 같은 톤이 된다.
    func testMonochromeCollapsesEveryTeamToTheSamePalette() {
        let palettes = (canonicalTeamIDs.map { Optional($0) } + [nil]).map {
            VFTeamFairyPalette.resolve(teamID: $0, appearance: .monochrome)
        }
        XCTAssertEqual(Set(palettes.map(\.accent)).count, 1, "모노크롬 강조색이 여럿이다")
        XCTAssertEqual(Set(palettes.map(\.body)).count, 1)
        XCTAssertEqual(Set(palettes.map(\.face)).count, 1)
    }

    /// 색을 지워도 몸·캡·얼굴 세 층이 서로 구분돼야 한다. 구조가 남아야 뜻이 남는다.
    func testMonochromeKeepsThreeDistinctStructuralTones() {
        let mono = VFTeamFairyPalette.resolve(teamID: "samsung-lions", appearance: .monochrome)
        XCTAssertNotEqual(mono.body, mono.accent, "모노크롬에서 캡이 몸에 녹아 사라진다")
        XCTAssertNotEqual(mono.accent, mono.face, "모노크롬에서 캡과 얼굴이 같다")
        XCTAssertNotEqual(mono.body, mono.face, "모노크롬에서 얼굴이 몸에 녹아 사라진다")

        guard let bodyL = luminance(mono.body), let accentL = luminance(mono.accent),
              let faceL = luminance(mono.face) else { failBecauseColourComponentsAreUnavailable(); return }
        XCTAssertGreaterThan(bodyL, accentL, "몸이 캡보다 밝아야 한다")
        XCTAssertGreaterThan(accentL, faceL, "캡이 얼굴보다 밝아야 한다")
    }

    private func failBecauseColourComponentsAreUnavailable() {
        // UIKit 없이 도는 환경에서는 광도를 잴 수 없다. 그런 환경에서 통과로 위장하지 않는다.
        XCTFail("색 성분을 읽을 수 없어 대비를 검증하지 못했다")
    }

    // MARK: - 23~25. 대비

    /// 캡이 팀 색이라 몸이나 외곽선 가운데 **적어도 한쪽과는** 뚜렷이 갈려야 한다.
    /// 양쪽 모두와 어중간한 중간 톤이면 캡이 사라진다.
    func testEveryTeamCapStaysLegibleAgainstBodyOrOutline() {
        let body = VFColor.highlightSurface
        let outline = VFColor.inkOutline
        for id in canonicalTeamIDs {
            let accent = VFTeamAccent.color(forTeamID: id)
            guard let vsBody = contrast(accent, body), let vsOutline = contrast(accent, outline) else {
                failBecauseColourComponentsAreUnavailable(); return
            }
            XCTAssertGreaterThanOrEqual(
                max(vsBody, vsOutline), 3.0,
                "\(id) 캡이 몸(\(String(format: "%.2f", vsBody)))과 외곽선(\(String(format: "%.2f", vsOutline))) 양쪽에 묻힌다"
            )
        }
    }

    /// 가장 밝은 팀과 가장 어두운 팀을 계산해서 고른다. 기억이 아니라 저장소 값으로 정한다.
    func testLightestAndDarkestTeamAccentsAreIdentifiedFromRepositoryValues() {
        let ranked = canonicalTeamIDs.compactMap { id -> (String, CGFloat)? in
            guard let l = luminance(VFTeamAccent.color(forTeamID: id)) else { return nil }
            return (id, l)
        }.sorted { $0.1 < $1.1 }
        guard ranked.count == 10 else { failBecauseColourComponentsAreUnavailable(); return }

        XCTAssertEqual(ranked.first?.0, "doosan-bears", "가장 어두운 팀 강조색이 바뀌었다")
        XCTAssertEqual(ranked.last?.0, "hanwha-eagles", "가장 밝은 팀 강조색이 바뀌었다")
    }

    func testTheLightestTeamAccentSurvivesAgainstTheOutline() {
        // 한화는 몸과의 대비가 가장 낮다(≈2.85). 외곽선이 형태를 지킨다.
        guard let vsOutline = contrast(VFTeamAccent.color(forTeamID: "hanwha-eagles"), VFColor.inkOutline) else {
            failBecauseColourComponentsAreUnavailable(); return
        }
        XCTAssertGreaterThanOrEqual(vsOutline, 3.0, "가장 밝은 팀 캡의 윤곽이 사라진다")
    }

    func testTheDarkestTeamAccentSurvivesAgainstTheBody() {
        // 두산은 외곽선과의 대비가 가장 낮다(≈1.05). 크림 몸이 형태를 지킨다.
        guard let vsBody = contrast(VFTeamAccent.color(forTeamID: "doosan-bears"), VFColor.highlightSurface) else {
            failBecauseColourComponentsAreUnavailable(); return
        }
        XCTAssertGreaterThanOrEqual(vsBody, 4.5, "가장 어두운 팀 캡이 몸과 갈리지 않는다")
    }

    /// 얼굴은 팀 색과 무관하게 크림 몸 위에 놓이므로 모든 팀에서 안전해야 한다.
    func testFaceContrastHoldsForEveryTeam() {
        for id in canonicalTeamIDs {
            let palette = VFTeamFairyPalette.resolve(teamID: id, appearance: .onLightSurface)
            guard let ratio = contrast(palette.face, palette.body) else { failBecauseColourComponentsAreUnavailable(); return }
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(id) 얼굴 대비가 모자라다")
        }
    }

    /// 키움만 눈이 팀 색 마스크 위에 올라간다. 그 조합도 읽혀야 한다.
    func testHeroMaskEyesStayLegibleAgainstTheAccentMask() {
        let palette = VFTeamFairyPalette.resolve(teamID: "kiwoom-heroes", appearance: .onLightSurface)
        let eye = VFTeamFairyTrait.heroMask.elements(size: .regular).first { $0.name == "눈 왼쪽" }
        XCTAssertEqual(eye?.fill, .onAccent, "키움 눈은 마스크 위 밝은 색이어야 한다")
        guard let ratio = contrast(palette.onAccent, palette.accent) else { failBecauseColourComponentsAreUnavailable(); return }
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "키움 눈이 마스크에 묻힌다")
    }

    // MARK: - 26~28. 접근성

    func testTeamFairyDeclaresTheTeamNamePairingContract() {
        XCTAssertEqual(VFTeamFairy.pairing, .requiresTeamName)
        XCTAssertEqual(VFFairyKind.team.pairing, .requiresTeamName, "기반의 계약과 어긋나면 안 된다")
    }

    func testMeaningfulUsageAcceptsCallerProvidedTeamText() {
        let fairy = VFTeamFairy(teamID: "samsung-lions", accessibilityLabel: "삼성 라이온즈 응원 팀")
        XCTAssertEqual(fairy.accessibilityLabel, "삼성 라이온즈 응원 팀")
        let neutral = VFTeamFairy(teamID: nil, accessibilityLabel: "아직 응원 팀을 선택하지 않음")
        XCTAssertEqual(neutral.accessibilityLabel, "아직 응원 팀을 선택하지 않음")
    }

    func testDecorativeUsageHasNoLabelByDefault() {
        for id in canonicalTeamIDs {
            XCTAssertNil(VFTeamFairy(teamID: id).accessibilityLabel, "\(id) 기본값에 라벨이 붙어 있다")
        }
        XCTAssertNil(VFTeamFairy(teamID: nil).accessibilityLabel)
    }

    /// 팀 ID·특징 이름·컴포넌트 이름이 VoiceOver로 새어 나가면 안 된다.
    func testInternalIdentifiersCannotReachVoiceOver() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        XCTAssertFalse(text.contains("accessibilityLabel(\""), "고정 문구를 읽어 주고 있다")
        XCTAssertFalse(text.contains("accessibilityLabel(teamID"), "팀 ID를 읽어 주면 안 된다")
        XCTAssertFalse(text.contains("accessibilityLabel(trait"), "특징 이름을 읽어 주면 안 된다")
        XCTAssertFalse(text.contains("rawValue)"), "원시값을 문장에 섞으면 안 된다")
        XCTAssertTrue(text.contains("accessibilityLabel(label)"), "부르는 쪽 라벨을 쓰는 경로가 없다")
    }

    // MARK: - 29~31. 정체성 규칙

    /// 구단 로고나 공식 마스코트를 옮기지 않는다. 이름에서 온 일반 개념만 쓴다.
    func testNoOfficialLogoOrMascotArtworkIsUsed() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        for needle in ["logo", "Logo", "mascot", "Mascot", "emblem", "Emblem", "wordmark", "Wordmark"] {
            XCTAssertFalse(text.contains(needle), "로고/마스코트 흔적이 있다: \(needle)")
        }
        // 구단 약칭을 그려 넣는 방식(가짜 이니셜)도 쓰지 않는다.
        for team in KBOSeed.teams {
            XCTAssertFalse(text.contains("\"\(team.shortName)\""), "\(team.id) 약칭을 그려 넣고 있다")
        }
    }

    func testNoRasterAssetIsRequired() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        for needle in ["Image(", "UIImage", ".png", ".jpg", ".pdf", "imageLiteral", "AsyncImage"] {
            XCTAssertFalse(text.contains(needle), "래스터 흔적이 있다: \(needle)")
        }
    }

    func testVFVectorPathRemainsTheOnlyVectorMechanism() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        XCTAssertTrue(text.contains("VFVectorPath"), "기존 벡터 기구를 써야 한다")
        XCTAssertFalse(text.contains("enum VFSVGPathParser"), "두 번째 파서를 만들면 안 된다")
        XCTAssertFalse(text.contains("struct VFSVGPathParser"), "두 번째 파서를 만들면 안 된다")
    }

    /// 모든 팀 경로가 실제로 그려지고 자기 viewBox 안에 머물러야 한다.
    func testEveryTeamPathParsesAndStaysWithinItsViewBox() {
        for trait in VFTeamFairyTrait.allCases {
            for element in trait.elements(size: .regular) {
                guard case let .path(d, viewBox) = element.shape else { continue }
                let parsed = VFSVGPathParser.parse(d)
                XCTAssertFalse(parsed.isEmpty, "\(trait.rawValue)/\(element.name) 경로가 비었다")
                let bounds = parsed.boundingRect
                XCTAssertTrue(
                    viewBox.insetBy(dx: -0.6, dy: -0.6).contains(bounds),
                    "\(trait.rawValue)/\(element.name)이 viewBox를 넘어간다: \(bounds) ⊄ \(viewBox)"
                )
            }
        }
    }

    // MARK: - 33~35. 경계

    func testTeamFairySourceImportsOnlySwiftUI() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        let imports = text.split(separator: "\n")
            .filter { $0.hasPrefix("import ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(imports, ["import SwiftUI"], "그리기 계층은 SwiftUI 말고 아무것도 들이지 않는다")
    }

    func testTeamFairySourceTouchesNoPersistenceNetworkOrFeatureCode() throws {
        let text = try executableSource("DesignSystem/VFTeamFairies.swift")
        for needle in ["SwiftData", "@Model", "ModelContainer", "AppDataStore", "APIClient",
                       "URLSession", "UserPreferencesStore", "Repository", "UserDefaults",
                       "HomeView", "FeedView", "LogEditorView", "ProfileSettingsView"] {
            XCTAssertFalse(text.contains(needle), "그리기 계층이 \(needle)을 알고 있다")
        }
    }

    /// 기반 글리프는 여전히 팀을 몰라야 한다. 지식은 래퍼에만 있다.
    func testTheBaseGlyphFoundationStillKnowsNothingAboutTeams() throws {
        let text = try executableSource("DesignSystem/VFFairyGlyphs.swift")
        for needle in ["KBOSeed", "VFTeamAccent", "VFTeamFairy"] {
            XCTAssertFalse(text.contains(needle), "기반 파일이 \(needle)을 알고 있다")
        }
    }

    // MARK: - 36~43. 이번 패스의 경계

    /// 팀 페어리는 **Pencil이 지정한 두 자리에만** 나타나야 한다.
    ///
    /// 앞 패스에서는 "아직 놓지 않았다"를 확인했다. 배치 패스가 놓았으므로 이제는
    /// 허용 목록으로 묶는다. 허용되지 않은 화면에 번지면 실패한다.
    func testTeamFairyAppearsOnlyInAuthorisedPlacements() throws {
        let authorised: Set<String> = [
            "VFHomeComponents.swift",  // TeamIdentityHeader 팀 페어리
            "OnboardingView.swift"     // Onboarding_05_Complete 선택 팀 페어리
        ]
        var found: Set<String> = []
        for folder in ["Features", "SharedComponents"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in e where url.pathExtension == "swift" {
                let body = stripComments(try String(contentsOf: url, encoding: .utf8))
                if body.contains("VFTeamFairy(") { found.insert(url.lastPathComponent) }
            }
        }
        XCTAssertEqual(found, authorised, "팀 페어리가 허용되지 않은 곳에 번졌거나 빠졌다")
    }

    /// `VFTeamIdentityHeader`가 이제 팀 페어리를 쓴다. 예전 약칭 원은 사라졌다.
    func testTeamIdentityHeaderUsesTeamFairy48() throws {
        let text = try source("SharedComponents/VFHomeComponents.swift")
        let body = stripComments(text)
        XCTAssertTrue(body.contains("VFTeamFairy(teamID: team.id, size: .compact)"),
                      "헤더가 팀 페어리 48을 쓰지 않는다")
        XCTAssertFalse(body.contains("team.badgeInitial"), "예전 약칭 표기가 남아 있다")
        // 팀 이름과 정체성 식별자는 그대로여야 한다.
        XCTAssertTrue(text.contains("home.teamIdentity"), "팀 아이덴티티 식별자가 사라졌다")
        XCTAssertTrue(text.contains("home.teamFairy"), "팀 페어리 식별자가 없다")
        // 페어리는 장식이다. 헤더가 이미 팀 이름을 읽어 준다.
        XCTAssertTrue(body.contains("accessibilityHidden(true)"), "팀 페어리가 숨겨지지 않았다")
    }

    func testCompletedScreensRemainInPlace() throws {
        let expectations: [(String, String)] = [
            ("Features/Home/HomeView.swift", "home.root"),
            ("Features/Feed/FeedViews.swift", "feed.addRecord"),
            ("Features/Calendar/CalendarViews.swift", "calendar.selectedDetail"),
            ("Domain/SeasonArchive.swift", "statistics.root"),
            ("Domain/RecordDetail.swift", "recordDetail.root")
        ]
        for (path, identifier) in expectations {
            XCTAssertTrue(try source(path).contains(identifier), "\(path)의 \(identifier)가 사라졌다")
        }
    }

    func testAppIconCatalogRemainsUnchanged() throws {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/AppIcon.appiconset/Contents.json")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let images = json?["images"] as? [[String: Any]] ?? []
        XCTAssertEqual(images.count, 3, "AppIcon 렌디션 수가 바뀌었다")
        XCTAssertEqual(
            Set(images.compactMap { $0["filename"] as? String }),
            ["AppIcon-1024.png", "AppIcon-1024-Dark.png", "AppIcon-1024-Tinted.png"]
        )
    }

    func testLaunchMarkRemainsUnchanged() {
        let url = Self.appSourceRoot
            .appendingPathComponent("Assets.xcassets/LaunchMark.imageset/LaunchMark.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "LaunchMark.pdf가 사라졌다")
    }
}
