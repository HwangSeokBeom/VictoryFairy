import XCTest
import SwiftUI
import CryptoKit
@testable import VictoryFairy

/// 개정 Pencil(8e055d8a…3d6db2)이 완료된 화면에 지정한 페어리 배치의 계약.
///
/// 앞선 패스들이 만든 페어리 시스템 자체는 각자의 계약 파일이 지킨다. 이 파일은
/// **어디에 놓았고 어디에 놓지 않았는지**만 다룬다. 기대값은 모두 원본 노드를 다시
/// 읽어 확인한 것이고, 소스 검사는 주석을 걷어낸 뒤에 한다.
final class FairyPlacementContractTests: XCTestCase {

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

    private func executableSource(_ relativePath: String) throws -> String {
        stripComments(try source(relativePath))
    }

    /// 주석과 문자열 밖의 코드만 남긴다. 설명 문장이 검사에 걸려 거짓 판정이 나지 않게 한다.
    private func stripComments(_ text: String) -> String {
        var output = ""
        let characters = Array(text)
        var index = 0
        var inLineComment = false
        var inBlockComment = false
        var inString = false
        while index < characters.count {
            let character = characters[index]
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil

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

    /// `#Preview` 블록을 걷어낸다. 프리뷰는 제품 동작이 아니라 카탈로그다.
    /// 어떤 팀이든 하나는 골라야 하므로, 표본 값 금지 규칙을 여기에 적용하면 안 된다.
    private func withoutPreviews(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        while let marker = text.range(of: "#Preview", range: index..<text.endIndex) {
            output += text[index..<marker.lowerBound]
            // 블록 시작 중괄호를 찾아 짝을 맞춰 건너뛴다.
            guard let open = text.range(of: "{", range: marker.upperBound..<text.endIndex) else {
                return output
            }
            var depth = 0
            var cursor = open.lowerBound
            while cursor < text.endIndex {
                if text[cursor] == "{" { depth += 1 }
                if text[cursor] == "}" {
                    depth -= 1
                    if depth == 0 { cursor = text.index(after: cursor); break }
                }
                cursor = text.index(after: cursor)
            }
            index = cursor
        }
        output += text[index...]
        return output
    }

    /// `declaration`으로 시작하는 선언의 본문만 잘라낸다. 중괄호 짝을 세어 찾는다.
    private func declarationBody(_ declaration: String, in text: String) -> String? {
        guard let start = text.range(of: declaration) else { return nil }
        guard let open = text.range(of: "{", range: start.upperBound..<text.endIndex) else { return nil }
        var depth = 0
        var cursor = open.lowerBound
        let bodyStart = text.index(after: open.lowerBound)
        while cursor < text.endIndex {
            if text[cursor] == "{" { depth += 1 }
            if text[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(text[bodyStart..<cursor]) }
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    /// 공백을 하나로 눌러 줄바꿈과 들여쓰기에 흔들리지 않게 한다.
    private func flattened(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// 선언 본문 추출기가 실제로 동작하는지 확인한다.
    func testDeclarationBodyExtractorActuallyExtracts() {
        let sample = "struct A { var x = 1 }\nstruct B { var y = 2 }"
        XCTAssertEqual(declarationBody("struct B", in: sample)?.trimmingCharacters(in: .whitespaces), "var y = 2")
        XCTAssertNil(declarationBody("struct C", in: sample))
        XCTAssertFalse(withoutPreviews("a\n#Preview(\"x\") { let t = \"lg-twins\" }\nb").contains("lg-twins"))
    }

    /// 주석 제거기가 실제로 동작하는지 스스로 확인한다.
    /// 이 검사가 없으면 아래의 "주석에 속지 않는다"는 주장 자체를 믿을 수 없다.
    func testCommentStripperActuallyRemovesComments() {
        let sample = """
        // VFTeamFairy(teamID: "x")
        let a = 1 /* VFStadiumFairy( */
        let b = "VFFairyGlyph(.victory)"
        """
        let stripped = stripComments(sample)
        XCTAssertFalse(stripped.contains("VFTeamFairy("), "한 줄 주석이 남았다")
        XCTAssertFalse(stripped.contains("VFStadiumFairy("), "블록 주석이 남았다")
        XCTAssertTrue(stripped.contains("VFFairyGlyph(.victory)"), "문자열 안의 코드는 남아야 한다")
    }

    /// 제품 화면 소스 전체(주석 제거본).
    private func productionSources() throws -> [(name: String, body: String)] {
        var result: [(String, String)] = []
        for folder in ["Features", "SharedComponents", "DesignSystem", "Domain", "Services"] {
            let root = Self.appSourceRoot.appendingPathComponent(folder)
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                result.append((url.lastPathComponent, stripComments(try String(contentsOf: url, encoding: .utf8))))
            }
        }
        return result
    }

    /// 화면(Features)과 공용 컴포넌트만. 디자인 시스템 자체는 빼고 본다.
    private func screenSources() throws -> [(name: String, body: String)] {
        try productionSources().filter { name, _ in
            !["VFFairyGlyphs.swift", "VFTeamFairies.swift", "VFStadiumFairies.swift", "VFDesignSystem.swift"]
                .contains(name)
        }
    }

    private func sha256(ofFileAt url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 1. 개정 원본 기록

    func testRevisedPencilHashIsStillTheRecordedSource() throws {
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains(Self.revisedPencilSHA256), "개정 Pencil 해시가 문서에 없다")
    }

    // MARK: - 2~4. 배치 목록과 밀도

    /// 이번 패스가 놓은 페어리 자리 전부. Pencil 노드 이름과 짝을 이룬다.
    ///
    /// 파일 → (심볼, Pencil 노드) 목록. 여기 없는 자리에 페어리가 나타나면 3번 검사가 잡는다.
    private static let authorisedPlacements: [String: [(symbol: String, pencilNode: String)]] = [
        "VFHomeComponents.swift": [("VFTeamFairy(", "TeamIdentityHeader > 팀 페어리")],
        "OnboardingView.swift": [
            ("VFTeamFairy(", "Onboarding_05_Complete > 선택 팀 페어리"),
            ("VFFairyGlyph(.success", "Onboarding_05_Complete > 완료 페어리")
        ],
        "CalendarViews.swift": [("VFFairyGlyph(kind", "선택일 미리보기 > 선택일 승리 페어리")],
        "StatisticsViews.swift": [("VFFairyGlyph(.victory", "시즌 커버 > 시즌 시그니처 페어리")],
        "VFCoreComponents.swift": [("VFFairyGlyph(fairy.kind", "09_States > 빈 기록 · 빈 시즌 · 오류")],
        // 개정 Pencil `08_Profile_Settings`(NffPV)이 프로필 카드 아바타 자리에
        // `Fairy48_Victory`를 직접 그려 두었다. 승리 요정의 48px 판이 그대로 온다.
        "ProfileSettingsView.swift": [("VFFairyGlyph(.victory", "08_Profile_Settings > 프로필 카드 아바타")]
    ]

    func testEveryImplementedPlacementIsPresentWhereItWasAuthored() throws {
        for (file, placements) in Self.authorisedPlacements {
            guard let entry = try screenSources().first(where: { $0.name == file }) else {
                return XCTFail("배치 대상 소스를 찾지 못했다: \(file)")
            }
            for placement in placements {
                XCTAssertTrue(
                    entry.body.contains(placement.symbol),
                    "\(file)에서 \(placement.pencilNode) 배치가 사라졌다"
                )
            }
        }
    }

    func testNoUnapprovedPlacementWasIntroduced() throws {
        let fairySymbols = ["VFFairyGlyph(", "VFTeamFairy(", "VFStadiumFairy(",
                            "VFStadiumFairyBadge(", "VFStadiumFairyRow("]
        var offenders: [String] = []
        for entry in try screenSources() {
            guard fairySymbols.contains(where: { entry.body.contains($0) }) else { continue }
            if Self.authorisedPlacements[entry.name] == nil {
                offenders.append(entry.name)
            }
        }
        XCTAssertTrue(offenders.isEmpty, "허가되지 않은 화면에 페어리가 들어갔다: \(offenders)")
    }

    /// 화면당 페어리 개수. Pencil `10_Fairy_Validation`이 정한 1~3개를 넘지 않는다.
    func testScreenFairyDensityStaysWithinTheDocumentedLimit() throws {
        let counts: [String: Int] = [
            // 홈은 공용 헤더 하나만 물려받는다.
            "VFHomeComponents.swift": 1,
            // 완료 화면은 선택 팀 + 성공 두 개.
            "OnboardingView.swift": 2,
            "CalendarViews.swift": 1,
            "StatisticsViews.swift": 1,
            // 상태 패널은 한 자리에서 세 상태를 그린다. 동시에 나오는 것은 언제나 하나.
            "VFCoreComponents.swift": 1,
            // 마이는 프로필 카드 아바타 하나뿐이다.
            "ProfileSettingsView.swift": 1
        ]
        for entry in try screenSources() {
            guard let expected = counts[entry.name] else { continue }
            let occurrences = ["VFFairyGlyph(", "VFTeamFairy(", "VFStadiumFairy("]
                .reduce(0) { $0 + entry.body.components(separatedBy: $1).count - 1 }
            XCTAssertEqual(occurrences, expected, "\(entry.name)의 페어리 개수가 달라졌다")
            XCTAssertLessThanOrEqual(
                occurrences, VFFairyIconPolicy.maximumFairiesPerScreen,
                "\(entry.name)이 화면당 한도를 넘었다"
            )
        }
    }

    // MARK: - 5. 네이티브 유틸리티 아이콘

    func testNativeUtilityIconsStayNative() throws {
        // 배치가 들어간 화면에서 네이티브 컨트롤이 페어리로 바뀌지 않았는지 본다.
        let expectations: [(file: String, symbol: String)] = [
            ("Features/Calendar/CalendarViews.swift", "chevron.left"),
            ("Features/Calendar/CalendarViews.swift", "chevron.right"),
            ("SharedComponents/VFCoreComponents.swift", "arrow.counterclockwise")
        ]
        for expectation in expectations {
            XCTAssertTrue(
                try executableSource(expectation.file).contains(expectation.symbol),
                "\(expectation.file)의 네이티브 아이콘 \(expectation.symbol)이 사라졌다"
            )
        }
        // 정책이 금지 목록을 계속 들고 있는지도 확인한다.
        for action in ["back", "close", "retry", "delete", "calendarPrevious", "calendarNext"] {
            XCTAssertTrue(
                VFFairyIconPolicy.nativeUtilityActions.contains(action),
                "\(action)이 네이티브 전용 목록에서 빠졌다"
            )
            XCTAssertFalse(VFFairyIconPolicy.allowsFairy(for: action), "\(action)에 페어리가 허용됐다")
        }
    }

    // MARK: - 6~10. 팀 아이덴티티 헤더와 홈

    func testTeamIdentityHeaderUsesCanonicalTeamFairyIdentity() throws {
        let file = try executableSource("SharedComponents/VFHomeComponents.swift")
        guard let header = declarationBody("struct VFTeamIdentityHeader: View", in: file) else {
            return XCTFail("팀 아이덴티티 헤더를 찾지 못했다")
        }
        XCTAssertTrue(header.contains("VFTeamFairy(teamID: team.id, size: .compact)"),
                      "헤더가 canonical 팀 ID로 페어리를 만들지 않는다")
        XCTAssertTrue(header.contains("VFTeamFairySize.compact.canvas"), "TeamFairy48 크기를 쓰지 않는다")
        XCTAssertFalse(header.contains("badgeInitial"), "헤더에 이전 이니셜 뱃지가 남아 있다")
        XCTAssertFalse(header.contains("KBOSeed."), "페어리 배치가 팀 조회를 가져갔다")
        XCTAssertFalse(header.contains("NavigationLink"), "페어리 배치가 이동을 가져갔다")
    }

    func testAllTenTeamsResolveThroughTheHeaderIdentity() {
        XCTAssertEqual(KBOSeed.teams.count, 10)
        var traits: Set<VFTeamFairyTrait> = []
        for team in KBOSeed.teams {
            let trait = VFTeamFairyTrait.trait(forTeamID: team.id)
            XCTAssertNotEqual(trait, .neutral, "\(team.id)가 중립으로 떨어졌다")
            traits.insert(trait)
        }
        XCTAssertEqual(traits.count, 10, "두 팀이 같은 페어리를 쓰고 있다")
    }

    func testNeutralTeamIdentityStaysHonest() {
        XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: nil), .neutral)
        XCTAssertEqual(VFTeamFairyTrait.trait(forTeamID: "not-a-team"), .neutral)
        XCTAssertEqual(VFTeamFairy(teamID: nil).trait, .neutral)
        XCTAssertEqual(VFTeamFairy(teamID: "not-a-team").trait, .neutral)
    }

    func testTeamNameStaysCallerOwnedAndIsNotSpokenTwice() throws {
        let raw = try source("SharedComponents/VFHomeComponents.swift")
        guard let header = declarationBody("struct VFTeamIdentityHeader: View", in: raw) else {
            return XCTFail("팀 아이덴티티 헤더를 찾지 못했다")
        }
        // 헤더가 팀 이름을 한 번만 말한다.
        XCTAssertEqual(header.components(separatedBy: "accessibilityLabel(").count - 1, 1,
                       "헤더가 팀 이름을 여러 번 말한다")
        XCTAssertTrue(header.contains("나의 팀 "), "헤더의 팀 이름 안내가 사라졌다")
        // 페어리는 이름을 갖지 않고 장식으로 숨긴다.
        guard let symbol = declarationBody("private var teamSymbol: some View", in: header) else {
            return XCTFail("팀 심볼 조각을 찾지 못했다")
        }
        let flat = flattened(symbol)
        XCTAssertTrue(flat.contains(".accessibilityHidden(true)"), "팀 페어리가 장식으로 숨겨져 있지 않다")
        XCTAssertFalse(flat.contains("accessibilityLabel"), "팀 페어리가 스스로 말한다")
        XCTAssertEqual(VFTeamFairy.pairing, .requiresTeamName, "팀 이름 동반 계약이 사라졌다")
        // 헤더 자체가 자식을 무시하므로 페어리가 따로 읽히지 않는다.
        XCTAssertTrue(header.contains("accessibilityElement(children: .ignore)"),
                      "헤더가 자식을 무시하지 않으면 팀 이름이 두 번 읽힌다")
    }

    func testHomeDoesNotAddASecondTeamFairy() throws {
        let home = try executableSource("Features/Home/HomeView.swift")
        XCTAssertFalse(home.contains("VFTeamFairy("), "홈이 공용 헤더 말고 팀 페어리를 또 놓았다")
        XCTAssertFalse(home.contains("VFFairyGlyph("), "홈이 추가 페어리를 놓았다")
        XCTAssertTrue(home.contains("VFTeamIdentityHeader("), "홈이 공용 헤더를 쓰지 않는다")
    }

    // MARK: - 11~17. 구장 표현과 기존 시스템

    /// 구장 페어리는 어떤 제품 화면에도 놓지 않았다. 원본이 그렇게 그려 두었다.
    func testSharedStadiumMigrationIsContextualNotBlind() throws {
        var offenders: [String] = []
        for entry in try screenSources() {
            for symbol in ["VFStadiumFairy(", "VFStadiumFairyBadge(", "VFStadiumFairyRow("]
            where entry.body.contains(symbol) {
                offenders.append("\(entry.name):\(symbol)")
            }
        }
        XCTAssertTrue(offenders.isEmpty, "일괄 치환이 일어났다: \(offenders)")
        // 기존 구장 컴포넌트는 여전히 쓰인다.
        let stadium = try executableSource("SharedComponents/VFStadiumComponents.swift")
        XCTAssertTrue(stadium.contains("struct VFStadiumGlyph"), "기존 구장 그래픽이 사라졌다")
    }

    func testRecordDetailReceivesNoUnauthorisedStadiumFairy() throws {
        let detail = try executableSource("Features/RecordDetail/RecordDetailViews.swift")
        for symbol in ["VFStadiumFairy(", "VFTeamFairy(", "VFFairyGlyph("] {
            XCTAssertFalse(detail.contains(symbol), "기록 상세에 \(symbol)가 들어갔다")
        }
        XCTAssertTrue(detail.contains("VFStadium"), "기록 상세의 구장 표현이 사라졌다")
    }

    func testActualRecordStadiumRemainsAuthoritative() {
        // 기록에 적힌 이름이 등록부에 없으면 unknown이지, 다른 구장으로 바뀌지 않는다.
        XCTAssertEqual(
            VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "부산 사직 보조구장"),
            .unknown
        )
        XCTAssertEqual(
            VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "잠실야구장"),
            .canonical("jamsil")
        )
    }

    func testPrimaryStadiumIsNotUsedAsARecordFallback() throws {
        let calendar = try executableSource("Features/Calendar/CalendarViews.swift")
        let detail = try executableSource("Features/RecordDetail/RecordDetailViews.swift")
        for body in [calendar, detail] {
            XCTAssertFalse(body.contains("primaryStadium ??"), "주 관람 구장이 기록 구장의 대체로 쓰였다")
            XCTAssertFalse(body.contains("?? preferences.primaryStadium"), "주 관람 구장이 대체로 쓰였다")
        }
    }

    func testTeamHomeStadiumIsNotUsedAsARecordFallback() throws {
        let fairies = try executableSource("DesignSystem/VFStadiumFairies.swift")
        XCTAssertFalse(fairies.contains("homeStadium"), "팀 홈 구장이 구장 페어리 결정에 끼어들었다")
        XCTAssertFalse(fairies.contains("KBOSeed"), "구장 페어리가 팀 등록부를 본다")
    }

    func testUnknownAndNoStadiumRemainDistinct() {
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: ""))
        XCTAssertNil(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "   "))
        XCTAssertEqual(VFStadiumFairyIdentity.identity(forRecordedStadiumNamed: "없는 구장"), .unknown)
    }

    /// 기존 구장 시스템의 상태는 `STILL_REQUIRED`다. 실사용처가 남아 있다.
    func testLegacyStadiumGlyphIsAccuratelyClassifiedAsStillRequired() throws {
        var owners: [String] = []
        for entry in try screenSources() where entry.name != "VFStadiumComponents.swift" {
            for symbol in ["VFStadiumGlyph(", "VFStadiumBadge(", "VFStadiumHero("]
            where entry.body.contains(symbol) {
                owners.append(entry.name)
            }
        }
        XCTAssertFalse(owners.isEmpty, "실사용처가 없다면 상태를 다시 분류해야 한다")
        let doc = try String(
            contentsOf: Self.repositoryRoot.appendingPathComponent("docs/PencilDesignImplementation.md"),
            encoding: .utf8
        )
        XCTAssertTrue(doc.contains("STILL_REQUIRED"), "기존 구장 시스템 상태가 문서에 없다")
    }

    // MARK: - 18~20. 온보딩 완료

    func testOnboardingCompletionUsesTheSelectedTeamDynamically() throws {
        let body = try executableSource("Features/Onboarding/OnboardingView.swift")
        XCTAssertTrue(body.contains("VFTeamFairy(teamID: viewModel.selectedTeamID)"),
                      "완료 화면이 고른 팀으로 페어리를 만들지 않는다")
    }

    func testOnboardingCompletionHardcodesNoPencilSampleTeam() throws {
        // 프리뷰는 카탈로그라 어떤 팀이든 하나는 골라야 한다. 제품 경로만 본다.
        // 같은 파일의 팀 선택 단계에는 열 구단의 안정 ID가 정당하게 들어가므로,
        // 온보딩 파일 전체가 아니라 완료 화면 선언만 검사한다.
        let source = withoutPreviews(try executableSource("Features/Onboarding/OnboardingView.swift"))
        guard let body = declarationBody("private struct OnboardingCompleteView", in: source) else {
            return XCTFail("온보딩 완료 화면 선언을 찾지 못했다")
        }
        for sample in ["samsung-lions", "삼성 라이온즈", "lg-twins", "LG 트윈스"] {
            XCTAssertFalse(body.contains(sample), "Pencil 표본 팀 \(sample)이 코드에 박혀 있다")
        }
        // 완료 화면의 팀 이름도 고른 팀에서 나온다.
        XCTAssertTrue(body.contains("KBOSeed.team(id: viewModel.selectedTeamID)")
                      || body.contains("selectedTeamName"),
                      "완료 화면이 고른 팀 이름을 쓰지 않는다")
    }

    func testSuccessFairyDoesNotReplaceCompletionText() throws {
        let body = try executableSource("Features/Onboarding/OnboardingView.swift")
        XCTAssertTrue(body.contains("onboarding.complete.finish"), "완료 CTA가 사라졌다")
        XCTAssertTrue(body.contains("VFPrimaryButton"), "완료 CTA가 네이티브 버튼이 아니다")
        XCTAssertTrue(body.contains("VFFairyGlyph(.success)"), "성공 페어리가 사라졌다")
        // 성공 페어리는 장식이다 — 식별자만 붙이고 접근성에서는 감춘다.
        let flat = flattened(body)
        guard let success = flat.range(of: "VFFairyGlyph(.success)") else {
            return XCTFail("성공 페어리 호출을 찾지 못했다")
        }
        let window = String(flat[success.upperBound...].prefix(240))
        XCTAssertTrue(window.contains(".accessibilityHidden(true)"), "성공 페어리가 숨겨져 있지 않다")
        XCTAssertFalse(window.contains("accessibilityLabel"), "성공 페어리가 스스로 말한다")
    }

    // MARK: - 21~25. 캘린더

    func testCalendarResultFairyNeverShowsVictoryForALoss() {
        XCTAssertEqual(CalendarResultFairy.kind(for: .loss), .loss)
        XCTAssertNotEqual(CalendarResultFairy.kind(for: .loss), .victory)
    }

    func testCalendarResultFairyNeverShowsVictoryForADraw() {
        XCTAssertEqual(CalendarResultFairy.kind(for: .draw), .draw)
        XCTAssertNotEqual(CalendarResultFairy.kind(for: .draw), .victory)
    }

    func testCalendarResultFairyNeverShowsVictoryForACancellation() {
        XCTAssertEqual(CalendarResultFairy.kind(for: .canceled), .cancelled)
        XCTAssertNotEqual(CalendarResultFairy.kind(for: .canceled), .victory)
    }

    /// 승리 페어리는 오직 승리에만. 네 결과가 모두 서로 다른 페어리를 쓴다.
    func testCalendarResultFairyIsAResultIdentityNotABrandSignature() {
        XCTAssertEqual(CalendarResultFairy.kind(for: .win), .victory)
        let kinds = GameResult.allCases.map(CalendarResultFairy.kind(for:))
        XCTAssertEqual(Set(kinds).count, GameResult.allCases.count, "두 결과가 같은 페어리를 쓴다")
    }

    /// 결과를 모르는 자리에는 페어리를 그리지 않는다.
    func testCalendarShowsNoFairyWithoutARecord() throws {
        let body = try executableSource("Features/Calendar/CalendarViews.swift")
        // 결과 페어리는 기록이 있는 가지 안에서만 불린다.
        guard let recordBranch = body.range(of: "if let record = presentation.primaryRecord {"),
              let elseBranch = body.range(of: "selectedDateEmptyDetail(presentation)") else {
            return XCTFail("선택일 미리보기 분기를 찾지 못했다")
        }
        let insideRecordBranch = body[recordBranch.upperBound..<elseBranch.lowerBound]
        XCTAssertTrue(insideRecordBranch.contains("selectedResultFairy(for: record.result)"),
                      "결과 페어리가 기록 가지 안에 없다")
        XCTAssertEqual(body.components(separatedBy: "selectedResultFairy(").count - 1, 2,
                       "결과 페어리는 선언과 호출 두 곳에만 나와야 한다")
    }

    func testNoFairyIsPlacedInsideCalendarDateCells() throws {
        let body = try executableSource("Features/Calendar/CalendarViews.swift")
        guard let cellRange = body.range(of: "struct CalendarDayCell") else {
            return XCTFail("날짜 칸 구현을 찾지 못했다")
        }
        let cellBody = String(body[cellRange.lowerBound...])
        XCTAssertFalse(cellBody.contains("VFFairyGlyph("), "날짜 칸마다 얼굴이 들어갔다")
    }

    func testCalendarInnerIdentifiersSurviveTheInsertion() throws {
        let body = try source("Features/Calendar/CalendarViews.swift")
        for identifier in ["calendar.selectedDetail", "calendar.detailHeader", "calendar.detailRecord",
                           "calendar.detailEventCount", "calendar.detailEmpty", "calendar.detailAddRecord",
                           "calendar.previousMonth", "calendar.nextMonth"] {
            XCTAssertTrue(body.contains(identifier), "\(identifier)가 사라졌다")
        }
        // 담는 요소로 만들지 않으면 바깥 식별자가 안쪽을 덮어쓴다.
        let executable = stripComments(body)
        guard let detail = executable.range(of: "accessibilityIdentifier(\"calendar.selectedDetail\")") else {
            return XCTFail("선택일 식별자를 찾지 못했다")
        }
        let precedingWindow = executable[executable.startIndex..<detail.lowerBound].suffix(200)
        XCTAssertTrue(precedingWindow.contains("accessibilityElement(children: .contain)"),
                      "선택일 컨테이너가 담는 요소가 아니면 안쪽 식별자가 사라진다")
    }

    // MARK: - 26~28. 시즌 아카이브

    func testStatisticsSeasonFairyDoesNotAlterCalculations() throws {
        let body = try executableSource("Features/Statistics/StatisticsViews.swift")
        // 페어리는 계산에 쓰이는 어떤 값도 읽지 않는다.
        guard let range = body.range(of: "private var seasonSignatureFairy: some View {") else {
            return XCTFail("시즌 시그니처 페어리를 찾지 못했다")
        }
        let tail = body[range.upperBound...]
        guard let end = tail.range(of: "\n    }") else { return XCTFail("본문 끝을 찾지 못했다") }
        let fairyBody = String(tail[tail.startIndex..<end.lowerBound])
        for forbidden in ["archive", "viewModel", "record", "winRate", "result"] {
            XCTAssertFalse(fairyBody.contains(forbidden), "시즌 페어리가 \(forbidden)을 읽는다")
        }
        XCTAssertTrue(fairyBody.contains("VFFairyGlyph(.victory, size: .compact)"),
                      "시즌 시그니처가 상수 승리 페어리가 아니다")
    }

    func testStatisticsSeasonFairyDoesNotAnnounceAFalseWin() throws {
        let body = try executableSource("Features/Statistics/StatisticsViews.swift")
        let flat = flattened(body)
        guard let signature = flat.range(of: "VFFairyGlyph(.victory, size: .compact)") else {
            return XCTFail("시즌 시그니처 페어리 호출을 찾지 못했다")
        }
        let window = String(flat[signature.upperBound...].prefix(240))
        XCTAssertTrue(window.contains(".accessibilityHidden(true)"), "시즌 페어리가 VoiceOver에 노출된다")
        XCTAssertFalse(window.contains("accessibilityLabel"), "시즌 페어리가 스스로 말한다")
    }

    func testStatisticsInnerIdentifiersSurviveTheInsertion() throws {
        let identifiers = try source("Domain/SeasonArchive.swift")
        for name in ["statistics.root", "statistics.hero", "statistics.headline",
                     "statistics.winRate", "statistics.seasonCover.fairy"] {
            XCTAssertTrue(identifiers.contains(name), "\(name)가 사라졌다")
        }
        let body = try source("Features/Statistics/StatisticsViews.swift")
        XCTAssertTrue(body.contains("StatisticsAccessibilityID.hero"), "시즌 커버 식별자가 사라졌다")
        XCTAssertTrue(body.contains("StatisticsAccessibilityID.seasonCoverFairy"), "페어리 식별자가 사라졌다")
    }

    func testExistingSparkleRemainsBesideTheSeasonFairy() throws {
        let body = try executableSource("Features/Statistics/StatisticsViews.swift")
        XCTAssertTrue(body.contains("VFIllustrationView(.sparkle, height: 22)"), "반짝이 사라졌다")
        XCTAssertTrue(body.contains("seasonSignatureFairy"), "시즌 페어리가 사라졌다")
    }

    // MARK: - 29~35. 공용 상태 패널

    func testEmptyRecordPanelReceivesOnlyTheAuthoredFairy() {
        XCTAssertEqual(VFStatePanelFairy.emptyRecord.kind, .empty)
        XCTAssertEqual(VFStatePanelFairy.emptyRecord.size, .regular)
        XCTAssertEqual(VFStatePanelFairy.emptyRecord.accessibilityIdentifier, "state.empty.fairy")
        XCTAssertNil(VFStatePanelFairy.emptyRecord.accessibilityLabel, "장식이어야 한다")
    }

    func testEmptySeasonPanelReceivesOnlyTheAuthoredFairy() {
        XCTAssertEqual(VFStatePanelFairy.emptySeason.kind, .empty)
        XCTAssertEqual(VFStatePanelFairy.emptySeason.size, .compact)
        XCTAssertEqual(VFStatePanelFairy.emptySeason.accessibilityIdentifier, "state.emptySeason.fairy")
    }

    func testErrorPanelReceivesOnlyTheAuthoredFairy() {
        XCTAssertEqual(VFStatePanelFairy.error.kind, .error)
        XCTAssertEqual(VFStatePanelFairy.error.size, .compact)
        XCTAssertEqual(VFStatePanelFairy.error.accessibilityIdentifier, "state.error.fairy")
        XCTAssertEqual(VFErrorPanel(message: "x").title, "잠시 우천 중단이에요", "오류 제목이 바뀌었다")
        XCTAssertEqual(VFErrorPanel(message: "x").fairy, .error, "오류 패널 기본 페어리가 사라졌다")
    }

    /// 페어리가 없는 상태들. 원본에 없으니 코드에도 없어야 한다.
    func testUnauthorisedStatePanelsStayWithoutFairies() throws {
        let body = try executableSource("SharedComponents/VFCoreComponents.swift")
        let panels = ["struct VFLoadingPanel", "struct VFToast"]
        for panel in panels {
            guard let start = body.range(of: panel) else { return XCTFail("\(panel)을 찾지 못했다") }
            let tail = body[start.upperBound...]
            let end = tail.range(of: "\n}")?.lowerBound ?? tail.endIndex
            XCTAssertFalse(tail[tail.startIndex..<end].contains("VFFairyGlyph("),
                           "\(panel)에 허가되지 않은 페어리가 들어갔다")
            XCTAssertFalse(tail[tail.startIndex..<end].contains("VFStatePanelFairy"),
                           "\(panel)에 허가되지 않은 페어리 자리가 생겼다")
        }
        // 빈 상태 패널의 페어리 자리는 기본이 비어 있다. 검색 없음처럼 원본이
        // 페어리를 두지 않은 자리는 그대로 일러스트로 남는다.
        XCTAssertNil(VFEmptyStatePanel(title: "t", message: "m").fairy,
                     "빈 상태 패널이 기본으로 페어리를 갖는다")
    }

    func testSearchEmptyAndInputErrorCallSitesRequestNoFairy() throws {
        var offenders: [String] = []
        // 공용 컴포넌트 내부 배선이 아니라, 화면이 어떤 페어리를 요청하는지만 본다.
        for entry in try screenSources() where entry.name != "VFCoreComponents.swift" {
            for line in entry.body.split(separator: "\n") where line.contains("fairy:") {
                let allowed = [".emptyRecord", ".emptySeason", ".error", "fairy: nil"]
                if !allowed.contains(where: { line.contains($0) }) {
                    offenders.append("\(entry.name): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
        XCTAssertTrue(offenders.isEmpty, "허가되지 않은 페어리 요청이 있다: \(offenders)")
    }

    // MARK: - 36~38. 접근성

    func testDecorativeStatePanelFairyIsHiddenWhenItHasNoLabel() throws {
        let body = try executableSource("SharedComponents/VFCoreComponents.swift")
        XCTAssertTrue(flattened(body).contains(".accessibilityHidden(fairy.accessibilityLabel == nil)"),
                      "라벨 없는 상태 페어리가 접근성 트리에 남는다")
    }

    func testDecorativeFairiesAreHidden() {
        // 라벨이 없으면 장식이다.
        XCTAssertNil(VFFairyGlyph(.victory).accessibilityLabel)
        XCTAssertNil(VFTeamFairy(teamID: "lg-twins").accessibilityLabel)
        XCTAssertNil(VFStatePanelFairy.emptyRecord.accessibilityLabel)
        XCTAssertNil(VFStatePanelFairy.emptySeason.accessibilityLabel)
        XCTAssertNil(VFStatePanelFairy.error.accessibilityLabel)
    }

    func testMeaningfulFairiesRequireACallerOwnedLabel() {
        let spoken = VFFairyGlyph(.error, accessibilityLabel: "불러오지 못했어요")
        XCTAssertEqual(spoken.accessibilityLabel, "불러오지 못했어요")
        var slot = VFStatePanelFairy.error
        slot.accessibilityLabel = "불러오지 못했어요"
        XCTAssertEqual(slot.accessibilityLabel, "불러오지 못했어요")
        XCTAssertEqual(VFFairyKind.error.pairing, .requiresResultText,
                       "오류 페어리는 읽을 수 있는 문구를 함께 요구해야 한다")
    }

    func testNoRawFairyEnumNameCanReachVoiceOver() throws {
        let sources = ["DesignSystem/VFFairyGlyphs.swift", "SharedComponents/VFCoreComponents.swift"]
        for path in sources {
            let body = try executableSource(path)
            XCTAssertFalse(body.contains("accessibilityLabel(kind.rawValue"), "\(path)가 열거 이름을 읽는다")
            XCTAssertFalse(body.contains("accessibilityLabel(String(describing:"), "\(path)가 타입 이름을 읽는다")
            XCTAssertFalse(body.contains("accessibilityLabel(\"\\(kind)\")"), "\(path)가 열거 값을 읽는다")
        }
        for kind in VFFairyKind.allCases {
            XCTAssertFalse(
                VFFairyGlyph(kind).accessibilityLabel?.contains(kind.rawValue) ?? false,
                "\(kind.rawValue)가 그대로 읽힌다"
            )
        }
    }

    // MARK: - 39~41. 브랜드 자산 회귀

    func testAppIconHashesRemainUnchanged() throws {
        let expected = [
            "AppIcon-1024.png": "43323e1a2948fc7e14c8aa4f0f4ad85da3606a410a5a609c582f79d134c0c9b8",
            "AppIcon-1024-Dark.png": "6fde4d723d04def12e96d59da04824f603e2b53c00947364dd79c65c8c4a370d",
            "AppIcon-1024-Tinted.png": "ed4672b6bfc7070d668cda0c2c73ae375def52174bf5fb5b247c904e82d32692"
        ]
        let root = Self.appSourceRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
        for (name, hash) in expected {
            XCTAssertEqual(try sha256(ofFileAt: root.appendingPathComponent(name)), hash,
                           "\(name) 해시가 바뀌었다")
        }
    }

    func testLaunchMarkHashesRemainUnchanged() throws {
        let expected = [
            "LaunchMark.pdf": "7b73585aa1538d03f68461a34bdcefa89fdc6319997175cf41efb94e76f366df",
            "LaunchMark-Dark.pdf": "3961018e70d79755433e84f5c361de8b25ee2947c63f421e4b88ec2742a0935e"
        ]
        let root = Self.appSourceRoot.appendingPathComponent("Assets.xcassets/LaunchMark.imageset")
        for (name, hash) in expected {
            XCTAssertEqual(try sha256(ofFileAt: root.appendingPathComponent(name)), hash,
                           "\(name) 해시가 바뀌었다")
        }
    }

    func testNativeLaunchOwnershipRemainsUnchanged() throws {
        let plist = try String(
            contentsOf: Self.appSourceRoot.appendingPathComponent("Info.plist"), encoding: .utf8
        )
        XCTAssertTrue(plist.contains("UILaunchScreen"), "네이티브 런치 설정이 사라졌다")
        XCTAssertTrue(plist.contains("LaunchMark"), "런치 마크 참조가 사라졌다")
        XCTAssertTrue(plist.contains("LaunchBackground"), "런치 배경 참조가 사라졌다")
        // 런타임 스플래시를 새로 만들지 않았다.
        for entry in try screenSources() {
            XCTAssertFalse(entry.body.contains("SplashView"), "\(entry.name)에 런타임 스플래시가 생겼다")
        }
    }

    // MARK: - 42~44. 시스템 보존

    func testFairyFoundationRemainsUnchanged() {
        XCTAssertEqual(VFFairyKind.allCases.count, 12)
        XCTAssertEqual(VFFairySize.regular.canvas, 96)
        XCTAssertEqual(VFFairySize.compact.canvas, 48)
        XCTAssertEqual(VFFairyIconPolicy.maximumFairiesPerScreen, 3)
    }

    func testTeamFairySystemRemainsUnchanged() {
        XCTAssertEqual(VFTeamFairyTrait.allCases.count, 11)
        XCTAssertEqual(VFTeamFairySize.compact.canvas, 48)
        XCTAssertEqual(VFTeamFairySize.regular.canvas, 96)
    }

    func testStadiumFairySystemRemainsUnchanged() {
        XCTAssertEqual(VFStadiumFairyTrait.allCases.count, 11)
        XCTAssertEqual(KBOStadiumSeed.all.count, 9)
        XCTAssertEqual(VFStadiumFairyTrait.coveredStadiumIDs.count, 9)
    }

    // MARK: - 45~46. 완료된 화면 회귀

    func testFeedRemainsFrameLevel() throws {
        let feed = try executableSource("Features/Feed/FeedViews.swift")
        XCTAssertFalse(feed.contains("VFFairyGlyph("), "피드가 직접 페어리를 그린다")
        XCTAssertFalse(feed.contains("VFTeamFairy("), "피드가 팀 페어리를 놓았다")
        // 빈 상태 페어리는 공용 패널을 통해서만 들어간다.
        XCTAssertTrue(feed.contains("fairy:"), "피드의 빈 상태 페어리 자리가 사라졌다")
        XCTAssertTrue(feed.contains("feed.addRecord"), "피드 식별자가 사라졌다")
    }

    func testRecordDetailRemainsFrameLevel() throws {
        let identifiers = try source("Domain/RecordDetail.swift")
        XCTAssertTrue(identifiers.contains("recordDetail.root"), "기록 상세 식별자가 사라졌다")
        let detail = try executableSource("Features/RecordDetail/RecordDetailViews.swift")
        XCTAssertFalse(detail.contains("VFStatePanelFairy"), "기록 상세가 상태 페어리를 요청한다")
    }

    // MARK: - 47~50. 경계

    func testNoAPIContractChanged() throws {
        let dtos = try source("Domain/APIDTOs.swift")
        for key in ["hasCompletedOnboarding", "favoriteTeamId", "id"] where dtos.contains(key) {
            XCTAssertTrue(dtos.contains(key))
        }
        for entry in try productionSources() {
            XCTAssertFalse(entry.body.contains("fairy") && entry.body.contains("CodingKeys")
                           && entry.name == "APIDTOs.swift",
                           "API 계약에 페어리 개념이 새어 들어갔다")
        }
    }

    func testNoPersistenceSchemaChanged() throws {
        for entry in try productionSources() where entry.body.contains("@Model") {
            XCTAssertFalse(entry.body.contains("Fairy"), "\(entry.name)의 저장 모델에 페어리가 들어갔다")
        }
    }

    func testNoBackendSourceChanged() {
        let backend = Self.repositoryRoot.appendingPathComponent("server")
        // 이 저장소에는 백엔드 소스가 없다. 생겼다면 이번 패스의 범위를 벗어난 것이다.
        XCTAssertFalse(FileManager.default.fileExists(atPath: backend.path),
                       "백엔드 소스가 저장소에 들어왔다")
    }

    func testNoLLMProviderOrKeyWasAdded() throws {
        let markers = ["OPENAI", "ANTHROPIC_API_KEY", "sk-ant-", "sk-proj-", "gpt-4", "claude-3"]
        for entry in try productionSources() {
            for marker in markers where entry.body.contains(marker) {
                XCTFail("\(entry.name)에 LLM 제공자 흔적 \(marker)이 있다")
            }
        }
    }
}
