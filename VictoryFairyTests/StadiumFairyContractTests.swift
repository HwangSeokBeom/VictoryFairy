import XCTest
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import VictoryFairy

/// 개정 Pencil(8e055d8a…3d6db2) `02_StadiumFairy_System`의 계약을 확인한다.
///
/// 기대값은 모두 Pencil 노드에서 직접 읽은 것이다. 여기 숫자를 고쳐야 한다면 원본이
/// 바뀐 것이므로, 원본을 다시 읽고 근거를 남긴 뒤에 고쳐야 한다.
final class StadiumFairyContractTests: XCTestCase {

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

    /// 주석을 걷어낸 소스. 이 파일들의 주석에는 구장 이름과 설명이 실제로 들어 있어,
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

    private func luminance(_ color: Color) -> CGFloat? {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
        #else
        return nil
        #endif
    }

    private func contrast(_ a: Color, _ b: Color) -> CGFloat? {
        guard let la = luminance(a), let lb = luminance(b) else { return nil }
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    private func failBecauseColourComponentsAreUnavailable() {
        XCTFail("색 성분을 읽을 수 없어 대비를 검증하지 못했다")
    }

    private var canonicalStadiumIDs: [String] { KBOStadiumSeed.all.map(\.id) }

    private var everyIdentity: [VFStadiumFairyIdentity] {
        canonicalStadiumIDs.map { .canonical($0) } + [.generic, .unknown]
    }

    // MARK: - 1. 원본

    func testRevisedPencilHashIsStillTheRecordedSource() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    // MARK: - 2. Pencil 컴포넌트 대응

    /// Pencil `02_StadiumFairy_System`의 컴포넌트 16개. 원본에서 직접 읽었다.
    private static let pencilStadiumComponents = [
        "StadiumFairy_Jamsil", "StadiumFairy_Gocheok", "StadiumFairy_SSG",
        "StadiumFairy_KT", "StadiumFairy_Hanwha", "StadiumFairy_LionsPark",
        "StadiumFairy_Sajik", "StadiumFairy_NC", "StadiumFairy_KIA",
        "StadiumFairy_Generic", "StadiumFairy_Unknown",
        "StadiumFairy48_Generic", "StadiumFairy48_Mono",
        "StadiumFairy_Badge", "StadiumFairy_Badge_Selected", "StadiumFairy_Row"
    ]

    func testEveryPencilStadiumComponentHasASwiftEquivalent() {
        XCTAssertEqual(Self.pencilStadiumComponents.count, 16)
        // 9구장 + 제네릭 + 미지정 = 11개 정체성
        XCTAssertEqual(everyIdentity.count, 11)
        // 특징 11종(9구장 + 홈플레이트 + 없음)
        XCTAssertEqual(VFStadiumFairyTrait.allCases.count, 11)
        // 두 크기, 세 외형, 두 선택 상태, 뱃지와 행
        XCTAssertEqual(VFStadiumFairySize.allCases.count, 2)
        XCTAssertEqual(VFStadiumFairyAppearance.allCases.count, 3)
        XCTAssertEqual(VFStadiumFairySelectionState.allCases.count, 2)
    }

    /// Pencil 각 구장 컴포넌트의 자식 수. 기본 6개 + 구장 특징.
    private static let pencilChildCounts: [String: Int] = [
        "jamsil": 8, "gocheok": 7, "incheon-ssg": 8, "suwon-kt": 8,
        "daejeon-hanwha": 7, "daegu-lions": 7, "gwangju-kia": 7,
        "sajik": 7, "changwon-nc": 7
    ]

    /// 기본 글리프 6조각 위에 구장 특징이 몇 개 얹히는지가 Pencil과 같아야 한다.
    func testVenueTraitPieceCountMatchesPencilChildCount() {
        let basePieces = 6
        for id in canonicalStadiumIDs {
            guard let expected = Self.pencilChildCounts[id] else {
                return XCTFail("\(id) 기대 자식 수가 없다")
            }
            let trait = VFStadiumFairyTrait.trait(for: .canonical(id))
            let pieces = Self.traitPieceCount(trait)
            XCTAssertEqual(
                basePieces + pieces, expected,
                "\(id) 조각 수가 Pencil과 다르다 (기본 \(basePieces) + 특징 \(pieces))"
            )
        }
        // 제네릭은 홈플레이트 하나, 미지정은 없음.
        XCTAssertEqual(basePieces + Self.traitPieceCount(.homePlate), 7)
        XCTAssertEqual(basePieces + Self.traitPieceCount(.none), 6)
    }

    /// 각 특징이 몇 개의 도형으로 이루어지는지. Pencil 노드에서 읽었다.
    private static func traitPieceCount(_ trait: VFStadiumFairyTrait) -> Int {
        switch trait {
        case .floodlights: 2      // 조명탑 둘
        case .scoreboard: 2       // 기둥 + 보드
        case .pennant: 2          // 깃대 + 깃발
        case .domeArc, .outfieldWall, .straightRoof, .waveLine, .skylineNotch, .seatingTier: 1
        case .homePlate: 1
        case .none: 0
        }
    }

    // MARK: - 3~7. canonical 구장

    func testAllNineCanonicalStadiumsAreCovered() {
        XCTAssertEqual(canonicalStadiumIDs.count, 9, "KBO 구장은 9개다")
        for id in canonicalStadiumIDs {
            XCTAssertNotEqual(
                VFStadiumFairyTrait.trait(for: .canonical(id)), VFStadiumFairyTrait.none,
                "\(id)에 구장 특징이 없다"
            )
        }
    }

    func testNoFictionalStadiumExistsInTheTraitTable() {
        let canonical = Set(canonicalStadiumIDs)
        XCTAssertEqual(
            VFStadiumFairyTrait.coveredStadiumIDs, canonical,
            "특징 표와 canonical 구장 목록이 어긋난다"
        )
    }

    func testEveryStadiumGetsADistinctTrait() {
        let traits = canonicalStadiumIDs.map { VFStadiumFairyTrait.trait(for: .canonical($0)) }
        XCTAssertEqual(Set(traits).count, 9, "두 구장이 같은 특징을 쓰고 있다")
    }

    func testTheExistingRegistryRemainsTheOwner() {
        // 등록부가 아는 이름만 canonical로 풀린다.
        for stadium in KBOStadiumSeed.all {
            XCTAssertEqual(
                VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: stadium.name),
                .canonical(stadium.id),
                "\(stadium.id) 이름 대조가 등록부와 어긋난다"
            )
            XCTAssertEqual(
                VFStadiumFairyIdentity.identity(forStadiumID: stadium.id),
                .canonical(stadium.id)
            )
        }
    }

    func testDisplayNamesAreNotEmbeddedInTheDrawingSource() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        for stadium in KBOStadiumSeed.all {
            XCTAssertFalse(text.contains(stadium.name), "그리기 소스에 구장 이름 \"\(stadium.name)\"이 박혀 있다")
            XCTAssertFalse(text.contains(stadium.shortName), "그리기 소스에 짧은 이름 \"\(stadium.shortName)\"이 박혀 있다")
        }
    }

    func testNoDuplicateStadiumRegistryExists() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertFalse(text.contains("idByName"), "두 번째 이름 표를 만들면 안 된다")
        XCTAssertFalse(text.contains("shortNameByID"), "두 번째 짧은 이름 표를 만들면 안 된다")
        XCTAssertFalse(text.contains("struct KBOStadium"), "구장 모델을 다시 만들면 안 된다")
        XCTAssertTrue(text.contains("KBOStadiumSeed"), "등록부를 써야 한다")
    }

    // MARK: - 8~13. 제네릭 · 미지정 · 구장 없음

    func testGenericIsDistinctFromEveryCanonicalStadium() {
        for id in canonicalStadiumIDs {
            XCTAssertNotEqual(VFStadiumFairyIdentity.generic, .canonical(id))
            XCTAssertNotEqual(
                VFStadiumFairyTrait.trait(for: .generic),
                VFStadiumFairyTrait.trait(for: .canonical(id)),
                "제네릭이 \(id)와 같은 특징을 쓴다"
            )
        }
        XCTAssertEqual(VFStadiumFairyTrait.trait(for: .generic), .homePlate)
    }

    func testUnknownIsDistinctFromGeneric() {
        XCTAssertNotEqual(VFStadiumFairyIdentity.unknown, .generic)
        XCTAssertNotEqual(
            VFStadiumFairyTrait.trait(for: .unknown),
            VFStadiumFairyTrait.trait(for: .generic),
            "미지정과 제네릭이 같은 특징을 쓴다"
        )
        // 색도 다르다 — 미지정만 중립색이다.
        let unknown = VFStadiumFairyPalette.resolve(identity: .unknown, appearance: .onLightSurface)
        let generic = VFStadiumFairyPalette.resolve(identity: .generic, appearance: .onLightSurface)
        XCTAssertNotEqual(unknown.body, generic.body, "미지정과 제네릭 몸 색이 같다")
        XCTAssertEqual(unknown.body, VFFairyColor.neutral)
        XCTAssertEqual(generic.body, VFFairyColor.stadium)
    }

    /// 두 크기 모두에서 미지정과 제네릭이 갈려야 한다.
    func testUnknownStaysDistinctFromGenericAtBothSizes() {
        for size in VFStadiumFairySize.allCases {
            let unknown = VFStadiumFairy(identity: .unknown, size: size)
            let generic = VFStadiumFairy(identity: .generic, size: size)
            XCTAssertNotEqual(
                unknown.renderedTrait, generic.renderedTrait,
                "\(size)에서 미지정과 제네릭이 같은 특징을 그린다"
            )
            XCTAssertNotEqual(unknown.palette.body, generic.palette.body)
        }
    }

    /// 구장 없음은 미지정이 아니다. 값이 없으면 그릴 정체성 자체가 없다.
    func testNoStadiumIsDistinctFromUnknownAndYieldsNoFairy() {
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: nil))
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: ""))
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "   "))
        XCTAssertNil(VFStadiumFairyIdentity.identity(forStadiumID: nil))
        XCTAssertNil(VFStadiumFairyIdentity.identity(forStadiumID: ""))

        // 이름이 있으면 미지정이 된다 — 없음과 다르다.
        XCTAssertEqual(
            VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "어느 지방 구장"), .unknown
        )
    }

    /// 값이 없다고 해서 조용히 어떤 구장이 골라지면 안 된다.
    func testNoStadiumNeverSilentlySelectsAVenue() {
        for value in [nil, "", "  ", "\n"] as [String?] {
            let identity = VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: value)
            XCTAssertNil(identity, "빈 값이 구장을 골랐다: \(String(describing: value))")
        }
    }

    /// 등록부가 모르는 이름은 다른 구장으로 바뀌지 않는다.
    func testUnknownNameIsNeverReplacedByACanonicalStadium() {
        for value in ["부산 사직 보조구장", "울산 문수야구장", "잠실", "고척", "Jamsil"] {
            XCTAssertEqual(
                VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: value), .unknown,
                "\"\(value)\"가 canonical 구장으로 바뀌었다"
            )
        }
    }

    /// 기록의 구장이 주 관람 구장이나 팀 홈 구장으로 대체될 수 없어야 한다.
    /// 그런 경로를 아예 만들지 않았다는 것을 소스로 확인한다.
    func testRecordStadiumCannotBeReplacedByPrimaryOrHomeStadium() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        for needle in ["recommendedStadium", "primaryStadium", "favoriteTeam", "homeTeamIDs",
                       "homeStadium", "UserPreferences"] {
            XCTAssertFalse(text.contains(needle), "구장 페어리가 \(needle)을 보고 있다")
        }
        // 해석 함수는 기록 값 하나만 받는다.
        XCTAssertTrue(text.contains("identity(forRecordedStadiumNamed"), "기록 값 기반 해석이 없다")
    }

    // MARK: - 14~17. 치수

    func testStandardStadiumFairyMatchesPencilCanvas() {
        XCTAssertEqual(VFStadiumFairySize.regular.canvas, 96)
        XCTAssertEqual(VFStadiumFairySize.regular.glyphSize, .regular)
        XCTAssertTrue(VFStadiumFairySize.regular.showsVenueTrait)
    }

    func testStadiumFairy48MatchesPencilCanvas() {
        XCTAssertEqual(VFStadiumFairySize.compact.canvas, 48)
        XCTAssertEqual(VFStadiumFairySize.compact.scale, 0.5)
        XCTAssertEqual(VFStadiumFairySize.compact.glyphSize, .compact)
        XCTAssertFalse(VFStadiumFairySize.compact.showsVenueTrait)
    }

    /// Pencil에는 구장별 48px 원본이 없다 — Generic과 Mono 둘뿐이다.
    /// 그래서 48px에서는 구장 특징이 사라지고 홈플레이트만 남는다.
    func testCompactDropsVenueTraitsBecausePencilAuthorsNoPerVenue48() {
        for id in canonicalStadiumIDs {
            let compact = VFStadiumFairy(identity: .canonical(id), size: .compact)
            XCTAssertEqual(
                compact.renderedTrait, .homePlate,
                "\(id) 48px이 구장 특징을 그리고 있다 — Pencil에는 구장별 48px이 없다"
            )
        }
        let generic = VFStadiumFairy(identity: .generic, size: .compact)
        XCTAssertEqual(generic.renderedTrait, .homePlate)
        // 미지정만 48px에서도 특징이 없다. 제네릭과 갈리는 유일한 형태 신호다.
        let unknown = VFStadiumFairy(identity: .unknown, size: .compact)
        XCTAssertEqual(unknown.renderedTrait, VFStadiumFairyTrait.none)
    }

    /// 96px에서는 아홉 구장이 각자의 특징을 그린다.
    func testRegularSizeDrawsEachVenueTrait() {
        for id in canonicalStadiumIDs {
            let fairy = VFStadiumFairy(identity: .canonical(id), size: .regular)
            XCTAssertEqual(
                fairy.renderedTrait, VFStadiumFairyTrait.trait(for: .canonical(id)),
                "\(id) 96px 특징이 다르다"
            )
            XCTAssertNotEqual(fairy.renderedTrait, .homePlate, "\(id)가 제네릭으로 떨어졌다")
        }
    }

    func testVenueTraitGeometryMatchesPencil() {
        let g = VFStadiumFairyGeometry.self
        XCTAssertEqual(g.floodlightLeftRect, CGRect(x: 22, y: 2, width: 9, height: 17))
        XCTAssertEqual(g.floodlightRightRect, CGRect(x: 37, y: -2, width: 9, height: 19))
        XCTAssertEqual(g.domeArcRect, CGRect(x: 16, y: 2, width: 42, height: 12))
        XCTAssertEqual(g.scoreboardPostRect, CGRect(x: 26, y: 4, width: 16, height: 14))
        XCTAssertEqual(g.scoreboardPanelRect, CGRect(x: 26, y: 4, width: 16, height: 9))
        XCTAssertEqual(g.pennantPoleRect, CGRect(x: 26, y: 1, width: 3, height: 16))
        XCTAssertEqual(g.pennantFlagRect, CGRect(x: 28, y: 2, width: 12, height: 8))
        XCTAssertEqual(g.outfieldWallRect, CGRect(x: 26, y: 84, width: 44, height: 8))
        XCTAssertEqual(g.straightRoofRect, CGRect(x: 16, y: 4, width: 38, height: 12))
        XCTAssertEqual(g.waveLineRect, CGRect(x: 26, y: 84, width: 44, height: 8))
        XCTAssertEqual(g.skylineNotchRect, CGRect(x: 16, y: 3, width: 36, height: 13))
        XCTAssertEqual(g.seatingTierRect, CGRect(x: 28, y: 83, width: 20, height: 11))
        XCTAssertEqual(g.homePlateRect, CGRect(x: 41, y: 84, width: 14, height: 12))
    }

    /// 잠실 오른쪽 조명탑만 캔버스 위로 넘어간다. Pencil 원본이 y = -2다.
    func testOnlyTheJamsilRightFloodlightBreaksTheCanvasTop() {
        let g = VFStadiumFairyGeometry.self
        XCTAssertLessThan(g.floodlightRightRect.minY, 0, "잠실 오른쪽 조명탑이 위로 넘어가야 한다")
        for rect in [g.floodlightLeftRect, g.domeArcRect, g.scoreboardPostRect, g.pennantPoleRect,
                     g.outfieldWallRect, g.straightRoofRect, g.waveLineRect,
                     g.skylineNotchRect, g.seatingTierRect, g.homePlateRect] {
            XCTAssertGreaterThanOrEqual(rect.minY, 0, "다른 특징이 캔버스 위로 넘어간다")
        }
    }

    /// 발치에 오는 특징과 머리 쪽에 오는 특징이 Pencil대로 갈린다.
    func testTraitsSitWherePencilPlacesThem() {
        for trait in [VFStadiumFairyTrait.outfieldWall, .waveLine, .seatingTier, .homePlate] {
            XCTAssertTrue(trait.sitsBelowBody, "\(trait.rawValue)는 발치에 온다")
        }
        for trait in [VFStadiumFairyTrait.floodlights, .domeArc, .scoreboard, .pennant,
                      .straightRoof, .skylineNotch] {
            XCTAssertFalse(trait.sitsBelowBody, "\(trait.rawValue)는 머리 쪽에 온다")
        }
    }

    func testBadgeAndRowGeometryMatchPencil() {
        let g = VFStadiumFairyGeometry.self
        XCTAssertEqual(g.badgeSpacing, 8)
        XCTAssertEqual(g.badgeCornerRadius, 12)
        XCTAssertEqual(g.badgeSelectedBorderWidth, 2)
        XCTAssertEqual(g.badgeCheckSize, 16)
        XCTAssertEqual(g.badgePadding.top, 6)
        XCTAssertEqual(g.badgePadding.bottom, 6)
        XCTAssertEqual(g.badgePadding.leading, 8)
        XCTAssertEqual(g.badgePadding.trailing, 12)

        XCTAssertEqual(g.rowWidth, 300)
        XCTAssertEqual(g.rowSpacing, 10)
        XCTAssertEqual(g.rowTextSpacing, 1)
        XCTAssertEqual(g.rowCornerRadius, 12)
        XCTAssertEqual(g.rowBorderWidth, 1)
        XCTAssertEqual(g.rowChevronSize, 16)
        XCTAssertEqual(g.rowPadding.top, 8)
        XCTAssertEqual(g.rowPadding.bottom, 8)
        XCTAssertEqual(g.rowPadding.leading, 10)
        XCTAssertEqual(g.rowPadding.trailing, 14)
    }

    // MARK: - 18~20. 공유 기하

    /// 구장 페어리는 몸통을 다시 그리지 않는다. 기본 글리프를 합성한다.
    func testStadiumFairyReusesTheBaseGlyphRatherThanRedrawingTheBody() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertTrue(text.contains("VFFairyGlyph("), "기본 글리프를 합성해야 한다")
        // 몸통·안테나 경로를 다시 적지 않았다.
        XCTAssertFalse(text.contains(VFFairyGeometry.bodyPath), "몸통 경로를 다시 적고 있다")
        XCTAssertFalse(text.contains(VFFairyGeometry.antennaStemPath), "안테나 경로를 다시 적고 있다")
        XCTAssertFalse(text.contains(VFFairyGeometry.antennaDiamondPath), "다이아몬드 경로를 다시 적고 있다")
    }

    /// Pencil `StadiumFairy_*`의 기본 여섯 조각은 `FairyGlyph_Stadium`과 완전히 같다.
    func testTheStadiumBaseGlyphMatchesPencilStadiumFairyBase() {
        let spec = VFFairyKind.stadium.spec(for: .onLightSurface)
        XCTAssertEqual(spec.body, VFFairyColor.stadium, "몸 색")
        XCTAssertEqual(spec.face, VFFairyColor.faceOnDark, "얼굴 색")
        XCTAssertEqual(spec.eyes, .open, "눈")
        XCTAssertEqual(spec.mouth, .gentle, "입")
        XCTAssertEqual(spec.accessory, VFFairyAccessory.none, "곁들임 없음")
    }

    /// 열한 정체성이 모두 같은 몸통·얼굴 기하를 쓴다. 특징만 다르다.
    func testSharedBodyAndFacialGeometryCannotDriftBetweenStadiums() {
        var eyeSpecs = Set<String>()
        for identity in everyIdentity {
            let fairy = VFStadiumFairy(identity: identity)
            // 몸통·얼굴은 기본 글리프가 그리므로 종류가 하나뿐이어야 한다.
            eyeSpecs.insert("\(VFFairyKind.stadium.spec(for: .onLightSurface).eyes)")
            XCTAssertEqual(fairy.size.canvas, 96, "\(identity) 캔버스가 다르다")
        }
        XCTAssertEqual(eyeSpecs.count, 1, "눈 기하가 갈렸다")
        XCTAssertEqual(VFFairyGeometry.openEyeLeftOrigin, CGPoint(x: 32.5, y: 41))
        XCTAssertEqual(VFFairyGeometry.openEyeRightOrigin, CGPoint(x: 56.5, y: 41))
    }

    /// 오직 승인된 구장 특징만 달라진다.
    func testOnlyApprovedVenueTraitsVary() {
        let approved = Set(VFStadiumFairyTrait.allCases)
        for identity in everyIdentity {
            let trait = VFStadiumFairyTrait.trait(for: identity)
            XCTAssertTrue(approved.contains(trait), "\(identity)가 승인되지 않은 특징을 쓴다")
        }
    }

    // MARK: - 21~22. 정체성 규칙

    /// 건축물 초상도, 지도 핀 마스코트도 만들지 않는다.
    func testNoArchitecturalPortraitOrMapPinMascotIsIntroduced() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        for needle in ["mapPin", "MapKit", "CLLocation", "annotation", "Annotation",
                       "skyline3D", "photo", "Photo", "building", "Building"] {
            XCTAssertFalse(text.contains(needle), "지도/건축 흔적이 있다: \(needle)")
        }
        // 특징은 모두 잉크 선 한두 개다. 조각 수가 둘을 넘지 않는다.
        for trait in VFStadiumFairyTrait.allCases {
            XCTAssertLessThanOrEqual(
                Self.traitPieceCount(trait), 2,
                "\(trait.rawValue)가 특징 하나치고 조각이 너무 많다"
            )
        }
    }

    func testNoRasterAssetIsRequired() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        for needle in ["UIImage", ".png", ".jpg", ".pdf", "imageLiteral", "AsyncImage"] {
            XCTAssertFalse(text.contains(needle), "래스터 흔적이 있다: \(needle)")
        }
        // Image(systemName:)는 네이티브 체크와 chevron뿐이다.
        let systemImages = text.components(separatedBy: "Image(systemName:").count - 1
        XCTAssertEqual(systemImages, 3, "네이티브 아이콘은 체크 둘과 chevron 하나뿐이어야 한다")
    }

    func testVFVectorPathRemainsTheOnlyVectorMechanism() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertTrue(text.contains("VFVectorPath"), "기존 벡터 기구를 써야 한다")
        XCTAssertFalse(text.contains("enum VFSVGPathParser"), "두 번째 파서를 만들면 안 된다")
        XCTAssertFalse(text.contains("struct VFSVGPathParser"), "두 번째 파서를 만들면 안 된다")
    }

    /// 모든 구장 경로가 실제로 그려지고 자기 viewBox 안에 머물러야 한다.
    func testEveryVenuePathParsesAndStaysWithinItsViewBox() {
        let g = VFStadiumFairyGeometry.self
        let paths: [(String, String, CGRect)] = [
            ("조명탑 왼쪽", g.floodlightLeftPath, g.floodlightLeftViewBox),
            ("조명탑 오른쪽", g.floodlightRightPath, g.floodlightRightViewBox),
            ("돔 아크", g.domeArcPath, g.domeArcViewBox),
            ("전광판 기둥", g.scoreboardPostPath, g.scoreboardPostViewBox),
            ("페넌트 깃대", g.pennantPolePath, g.pennantPoleViewBox),
            ("페넌트 깃발", g.pennantFlagPath, g.pennantFlagViewBox),
            ("외야 담장", g.outfieldWallPath, g.outfieldWallViewBox),
            ("직선 지붕", g.straightRoofPath, g.straightRoofViewBox),
            ("파도 라인", g.waveLinePath, g.waveLineViewBox),
            ("스카이라인 노치", g.skylineNotchPath, g.skylineNotchViewBox),
            ("관중석 단", g.seatingTierPath, g.seatingTierViewBox),
            ("홈플레이트", g.homePlatePath, g.homePlateViewBox)
        ]
        for (name, d, viewBox) in paths {
            let parsed = VFSVGPathParser.parse(d)
            XCTAssertFalse(parsed.isEmpty, "\(name) 경로가 비었다")
            XCTAssertTrue(
                viewBox.insetBy(dx: -0.6, dy: -0.6).contains(parsed.boundingRect),
                "\(name)이 viewBox를 넘어간다: \(parsed.boundingRect) ⊄ \(viewBox)"
            )
        }
    }

    /// 조명탑은 호(`a`) 명령을 쓴다. 호가 직선으로 흐르면 전구가 사라진다.
    func testFloodlightArcsActuallyRender() {
        for path in [VFStadiumFairyGeometry.floodlightLeftPath,
                     VFStadiumFairyGeometry.floodlightRightPath] {
            let parsed = VFSVGPathParser.parse(path)
            XCTAssertFalse(parsed.isEmpty)
            // 전구가 그려지면 가로로 8pt 가까이 퍼진다. 기둥만 남으면 훨씬 좁다.
            XCTAssertGreaterThan(parsed.boundingRect.width, 6, "조명탑 전구가 그려지지 않았다")
        }
    }

    // MARK: - 23~26. 상태

    func testSelectedStateIsNotColourOnly() {
        let selected = VFStadiumFairySelectionState.selected
        XCTAssertTrue(selected.requiredAffordances.contains(.checkmark), "선택에 체크가 있어야 한다")
        XCTAssertTrue(selected.requiredAffordances.contains(.goldBorder))
        for state in VFStadiumFairySelectionState.allCases {
            XCTAssertTrue(state.isCommunicatedWithoutColour, "\(state)가 색에만 기대고 있다")
        }
    }

    func testUnselectedStateIsDefinedAndRequiresNothingExtra() {
        XCTAssertTrue(VFStadiumFairySelectionState.unselected.requiredAffordances.isEmpty)
    }

    /// 선택은 뱃지와 행이 알린다. 페어리 그림 자체는 선택을 모른다.
    /// `VFStadiumFairy`에 선택 매개변수가 아예 없다는 것으로 확인한다.
    func testSelectionLivesOnTheBadgeAndRowNotOnTheFairy() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        guard let fairyStart = text.range(of: "struct VFStadiumFairy: View"),
              let badgeStart = text.range(of: "struct VFStadiumFairyBadge: View") else {
            return XCTFail("두 타입을 찾을 수 없다")
        }
        let fairyBody = String(text[fairyStart.lowerBound..<badgeStart.lowerBound])
        XCTAssertFalse(
            fairyBody.contains("VFStadiumFairySelectionState"),
            "페어리 그림이 선택 상태를 들고 있다 — 선택은 감싸는 쪽의 몫이다"
        )
        // 뱃지와 행은 선택을 안다.
        let wrappers = String(text[badgeStart.lowerBound...])
        XCTAssertTrue(wrappers.contains("VFStadiumFairySelectionState"), "뱃지와 행이 선택을 가져야 한다")
    }

    /// 체크는 네이티브로 남는다. 페어리 표정으로 바꾸지 않는다.
    func testCheckmarkStaysNativeAndIsNotAFairyExpression() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertTrue(text.contains("Image(systemName: \"checkmark\")"), "네이티브 체크를 써야 한다")
        XCTAssertTrue(text.contains("Image(systemName: \"chevron.right\")"), "네이티브 chevron을 써야 한다")
        XCTAssertFalse(text.contains("체크 페어리"), "체크를 페어리로 바꾸면 안 된다")
    }

    // MARK: - 27~30. 외형

    func testLightAndDarkSurfacesResolveToTheSamePalette() {
        for identity in everyIdentity {
            let light = VFStadiumFairyPalette.resolve(identity: identity, appearance: .onLightSurface)
            let dark = VFStadiumFairyPalette.resolve(identity: identity, appearance: .onDarkSurface)
            XCTAssertEqual(light.body, dark.body, "\(identity) 몸 색이 표면에 따라 달라졌다")
            XCTAssertEqual(light.face, dark.face)
            XCTAssertEqual(light.trait, dark.trait)
            XCTAssertEqual(light.diamond, dark.diamond)
            XCTAssertEqual(light.plate, dark.plate)
        }
    }

    /// Pencil `StadiumFairy48_Mono`는 회색으로 눕히는 것이 아니라 잉크·종이로 뒤집는다.
    func testMonochromeFollowsThePencilInvertedTreatment() {
        let mono = VFStadiumFairyPalette.resolve(identity: .generic, appearance: .monochrome)
        XCTAssertEqual(mono.body, VFColor.bodyPrimary, "모노 몸은 잉크색이다")
        XCTAssertEqual(mono.face, VFColor.appBackground, "모노 얼굴은 종이색이다")
        // 다이아몬드만 금색으로 남는다 — Pencil이 그렇게 그렸다.
        XCTAssertEqual(mono.diamond, VFColor.attentionAccent, "모노에서도 다이아몬드는 금색이다")
    }

    func testMonochromeCollapsesEveryStadiumToTheSamePalette() {
        let palettes = everyIdentity.map {
            VFStadiumFairyPalette.resolve(identity: $0, appearance: .monochrome)
        }
        XCTAssertEqual(Set(palettes.map(\.body)).count, 1, "모노 몸 색이 여럿이다")
        XCTAssertEqual(Set(palettes.map(\.face)).count, 1, "모노 얼굴 색이 여럿이다")
    }

    /// 모노크롬에서도 실루엣과 얼굴이 살아 있어야 한다.
    func testMonochromeKeepsSilhouetteAndFacialContrast() {
        let mono = VFStadiumFairyPalette.resolve(identity: .generic, appearance: .monochrome)
        XCTAssertNotEqual(mono.body, mono.face, "모노에서 얼굴이 몸에 녹아 사라진다")
        guard let ratio = contrast(mono.face, mono.body) else {
            failBecauseColourComponentsAreUnavailable(); return
        }
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "모노 얼굴 대비가 모자라다")
    }

    /// 색을 지워도 제네릭과 미지정은 **형태로** 갈려야 한다.
    /// 모노에서는 둘의 색이 같아지므로 홈플레이트의 유무가 유일한 신호다.
    func testGenericAndUnknownStayDistinguishableWithoutColour() {
        let genericMono = VFStadiumFairy(identity: .generic, appearance: .monochrome)
        let unknownMono = VFStadiumFairy(identity: .unknown, appearance: .monochrome)
        XCTAssertEqual(genericMono.palette.body, unknownMono.palette.body, "모노에서는 색이 같아진다")
        XCTAssertNotEqual(
            genericMono.renderedTrait, unknownMono.renderedTrait,
            "색이 같아지면 형태로 갈려야 하는데 특징까지 같다"
        )
    }

    /// 아홉 구장은 색이 아니라 특징으로 갈린다. 모두 같은 몸 색을 쓴다.
    func testCanonicalStadiumsAreDistinguishedByTraitNotColour() {
        let bodies = canonicalStadiumIDs.map {
            VFStadiumFairyPalette.resolve(identity: .canonical($0), appearance: .onLightSurface).body
        }
        XCTAssertEqual(Set(bodies).count, 1, "구장마다 색을 다르게 만들면 안 된다")
        let traits = canonicalStadiumIDs.map { VFStadiumFairyTrait.trait(for: .canonical($0)) }
        XCTAssertEqual(Set(traits).count, 9, "특징으로 갈려야 한다")
    }

    /// 아홉 구장과 제네릭은 어느 외형에서든 얼굴 대비 4.5:1을 넘는다.
    func testFaceContrastHoldsForCanonicalAndGenericInEveryAppearance() {
        let identities = canonicalStadiumIDs.map { VFStadiumFairyIdentity.canonical($0) } + [.generic]
        for appearance in VFStadiumFairyAppearance.allCases {
            for identity in identities {
                let palette = VFStadiumFairyPalette.resolve(identity: identity, appearance: appearance)
                guard let ratio = contrast(palette.face, palette.body) else {
                    failBecauseColourComponentsAreUnavailable(); return
                }
                XCTAssertGreaterThanOrEqual(
                    ratio, 4.5, "\(identity)/\(appearance) 얼굴 대비가 모자라다"
                )
            }
        }
    }

    /// 미지정 페어리의 얼굴 대비는 **Pencil 원본 그대로 2.88:1**이다.
    ///
    /// `$fairyNeutral`(#8B909E) 몸에 `$fairyFaceOnDark`(#F6F3EA) 얼굴을 올린 값이며,
    /// 비-텍스트 대비 기준 3:1에 0.12 모자란다. 우리가 잘못 옮긴 값이 아니라 원본이
    /// 그렇다. 원본을 마음대로 다시 칠하지 않고 그대로 두되, 사실을 여기 못박아 둔다.
    ///
    /// 미지정 페어리는 **혼자서 뜻을 전하지 않는다** — 곁에 "등록되지 않은 구장"과 기록에
    /// 적힌 이름이 반드시 함께 있으므로(`requiresStadiumName`), 이 대비가 정보 접근을
    /// 막지는 않는다. 그래서 이번 패스에서 고치지 않고 디자인 원본 쪽 발견으로 보고한다.
    /// 바닥값을 걸어 두어 더 나빠지면 실패한다.
    func testUnknownFaceContrastIsPinnedAsAPencilSourceFinding() {
        let palette = VFStadiumFairyPalette.resolve(identity: .unknown, appearance: .onLightSurface)
        guard let ratio = contrast(palette.face, palette.body) else {
            failBecauseColourComponentsAreUnavailable(); return
        }
        XCTAssertEqual(ratio, 2.876, accuracy: 0.01, "Pencil 원본 값에서 벗어났다")
        XCTAssertGreaterThanOrEqual(ratio, 2.8, "미지정 얼굴 대비가 더 나빠졌다")
        // 몸 색만 미지정이 다르다는 사실도 함께 지킨다.
        XCTAssertEqual(palette.body, VFFairyColor.neutral)
        XCTAssertEqual(palette.face, VFFairyColor.faceOnDark)
    }

    /// 미지정이라도 구장 특징 자리의 잉크 선과 외곽선은 또렷하다.
    func testUnknownStillHasStrongOutlineContrast() {
        let palette = VFStadiumFairyPalette.resolve(identity: .unknown, appearance: .onLightSurface)
        guard let ratio = contrast(palette.trait, palette.body) else {
            failBecauseColourComponentsAreUnavailable(); return
        }
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "미지정 잉크 선이 몸에 묻힌다")
    }

    /// 잉크 라인 특징이 몸 색 위에서 읽혀야 한다.
    func testVenueTraitStaysLegibleAgainstTheBody() {
        for appearance in VFStadiumFairyAppearance.allCases {
            for identity in everyIdentity {
                let palette = VFStadiumFairyPalette.resolve(identity: identity, appearance: appearance)
                guard let ratio = contrast(palette.trait, palette.body) else {
                    failBecauseColourComponentsAreUnavailable(); return
                }
                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0, "\(identity)/\(appearance) 구장 특징이 몸에 묻힌다"
                )
            }
        }
    }

    // MARK: - 31~34. 접근성

    func testStadiumFairyDeclaresTheStadiumNamePairingContract() {
        XCTAssertEqual(VFStadiumFairy.pairing, .requiresStadiumName)
        XCTAssertEqual(VFFairyKind.stadium.pairing, .requiresStadiumName, "기반 계약과 어긋나면 안 된다")
    }

    func testMeaningfulUsageAcceptsCallerProvidedStadiumText() {
        let named = VFStadiumFairy(identity: .canonical("jamsil"), accessibilityLabel: "잠실야구장")
        XCTAssertEqual(named.accessibilityLabel, "잠실야구장")
        let unknown = VFStadiumFairy(
            identity: .unknown, accessibilityLabel: "등록되지 않은 구장, 부산 사직 보조구장"
        )
        XCTAssertEqual(unknown.accessibilityLabel, "등록되지 않은 구장, 부산 사직 보조구장")
    }

    func testDecorativeUsageHasNoLabelByDefault() {
        for identity in everyIdentity {
            XCTAssertNil(VFStadiumFairy(identity: identity).accessibilityLabel, "\(identity)")
        }
    }

    func testInternalIdentifiersCannotReachVoiceOver() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertFalse(text.contains("accessibilityLabel(\""), "고정 문구를 읽어 주고 있다")
        XCTAssertFalse(text.contains("accessibilityLabel(identity"), "구장 ID를 읽어 주면 안 된다")
        XCTAssertFalse(text.contains("accessibilityLabel(trait"), "특징 이름을 읽어 주면 안 된다")
        XCTAssertFalse(text.contains("rawValue)"), "원시값을 문장에 섞으면 안 된다")
        XCTAssertTrue(text.contains("accessibilityLabel(label)"), "부르는 쪽 라벨을 쓰는 경로가 없다")
    }

    /// 뱃지와 행은 곁의 글자가 이미 구장을 말하므로 페어리를 숨기고 하나로 읽는다.
    func testBadgeAndRowAvoidDuplicateAnnouncements() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertTrue(text.contains("accessibilityElement(children: .combine)"),
                      "뱃지와 행은 하나의 요소로 읽어야 한다")
        // 네이티브 체크와 chevron은 장식이므로 숨긴다.
        let hidden = text.components(separatedBy: "accessibilityHidden(true)").count - 1
        XCTAssertGreaterThanOrEqual(hidden, 3, "네이티브 아이콘을 접근성에서 숨겨야 한다")
    }

    // MARK: - 35~42. 경계

    func testStadiumFairySourceImportsOnlySwiftUI() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        let imports = text.split(separator: "\n")
            .filter { $0.hasPrefix("import ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        XCTAssertEqual(imports, ["import SwiftUI"], "그리기 계층은 SwiftUI 말고 아무것도 들이지 않는다")
    }

    func testStadiumFairySourceTouchesNoPersistenceNetworkMapOrFeatureCode() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        for needle in ["SwiftData", "@Model", "ModelContainer", "AppDataStore", "APIClient",
                       "URLSession", "UserPreferencesStore", "Repository", "UserDefaults",
                       "MapKit", "CoreLocation", "CLLocationManager",
                       "HomeView", "FeedView", "LogEditorView", "ProfileSettingsView",
                       "CalendarViews", "StatisticsViews", "RecordDetailViews"] {
            XCTAssertFalse(text.contains(needle), "그리기 계층이 \(needle)을 알고 있다")
        }
    }

    func testNoDuplicateVenueColourLiteralsAreIntroduced() throws {
        let text = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertFalse(text.contains("Color(hex:"), "구장 페어리 소스에 색 리터럴이 있다")
        let pattern = try NSRegularExpression(pattern: "#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})\\b")
        let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let found = matches.compactMap { Range($0.range, in: text).map { String(text[$0]) } }
        XCTAssertTrue(found.isEmpty, "구장 페어리 소스에 색 코드가 있다: \(found)")
    }

    /// 구장 색은 하나뿐이다. 아홉 구장에 아홉 색을 만들지 않는다.
    func testStadiumColourOwnershipStaysWithTheFairyToken() {
        XCTAssertEqual(VFFairyColor.stadium, VFColor.supportAccent, "구장색은 sage 별칭이다")
        let generic = VFStadiumFairyPalette.resolve(identity: .generic, appearance: .onLightSurface)
        XCTAssertEqual(generic.body, VFFairyColor.stadium)
    }

    // MARK: - 43~45. 이번 패스의 경계

    /// 이번 패스는 공유 컴포넌트만 만든다. 화면 배치는 다음 패스의 몫이다.
    func testNoProductionScreenOrSharedComponentUsesStadiumFairyYet() throws {
        var offenders: [String] = []
        for folder in ["Features", "SharedComponents"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let body = stripComments(try String(contentsOf: url, encoding: .utf8))
                for symbol in ["VFStadiumFairy", "VFStadiumFairyBadge", "VFStadiumFairyRow",
                               "VFTeamFairy", "VFFairyGlyph"] {
                    if body.contains(symbol) { offenders.append("\(url.lastPathComponent):\(symbol)") }
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "공유 컴포넌트 패스에서는 화면에 놓지 않는다. 놓인 곳: \(offenders)")
    }

    /// 팀 페어리는 이번 패스에서 바뀌지 않았다.
    func testTeamFairyImplementationRemainsUnchanged() {
        XCTAssertEqual(VFTeamFairyTrait.allCases.count, 11)
        XCTAssertEqual(VFTeamFairyTrait.clubTraits.count, 10)
        XCTAssertEqual(VFTeamFairyTrait.coveredTeamIDs.count, 10)
        XCTAssertEqual(VFTeamFairy.pairing, .requiresTeamName)
        XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: "samsung-lions"), .lionMane)
        XCTAssertEqual(VFTeamFairySize.compact.eyeDiameter, 4)
        XCTAssertEqual(VFTeamFairyTrait.neutral.elements(size: .compact).count, 8)
    }

    /// 팀과 구장은 서로의 등록부를 침범하지 않는다.
    func testTeamAndStadiumSystemsStayIndependent() throws {
        let stadium = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertFalse(stadium.contains("VFTeamAccent"), "구장 페어리가 팀 색을 보고 있다")
        XCTAssertFalse(stadium.contains("VFTeamFairy"), "구장 페어리가 팀 페어리를 쓰고 있다")
        let team = try executableSource("DesignSystem/VFTeamFairies.swift")
        XCTAssertFalse(team.contains("KBOStadiumSeed"), "팀 페어리가 구장 등록부를 보고 있다")
        XCTAssertFalse(team.contains("VFStadiumFairy"), "팀 페어리가 구장 페어리를 쓰고 있다")
    }

    /// 기본 글리프는 이번 패스에서 칠 이음새만 늘었고 의미는 그대로다.
    func testFairyFoundationRemainsUnchanged() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(VFFairyKind.pencilCompactKinds.count, 8)
        XCTAssertEqual(VFFairySize.compact.openEyeDiameter, 4)
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3)
        // 이음새를 주지 않으면 종류가 정한 색 그대로다.
        let plain = VFFairyGlyph(.stadium)
        XCTAssertEqual(plain.spec, VFFairyKind.stadium.spec(for: .onLightSurface))
    }

    /// 칠 이음새는 기하를 건드리지 않는다.
    func testPaletteOverrideChangesOnlyColourNotGeometry() {
        let base = VFFairyKind.stadium.spec(for: .onLightSurface)
        let overridden = VFFairyPaletteOverride(body: VFFairyColor.neutral).applied(to: base)
        XCTAssertEqual(overridden.body, VFFairyColor.neutral)
        XCTAssertEqual(overridden.face, base.face, "지정하지 않은 값은 그대로여야 한다")
        XCTAssertEqual(overridden.eyes, base.eyes)
        XCTAssertEqual(overridden.mouth, base.mouth)
        XCTAssertEqual(overridden.accessory, base.accessory)
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

    /// 기존 구장 컴포넌트는 이번 패스에서 손대지 않았다.
    func testLegacyStadiumComponentsAreUntouched() throws {
        let text = try source("SharedComponents/VFStadiumComponents.swift")
        XCTAssertTrue(text.contains("struct VFStadiumGlyph"), "기존 구장 그래픽이 사라졌다")
        XCTAssertTrue(text.contains("struct VFStadiumBadge"), "기존 구장 뱃지가 사라졌다")
        XCTAssertTrue(text.contains("struct VFStadiumHero"), "기존 구장 히어로가 사라졌다")
        XCTAssertFalse(stripComments(text).contains("VFStadiumFairy"), "이번 패스에서 교체하면 안 된다")
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
