import XCTest
@testable import VictoryFairy

/// 재설계가 지켜야 할 구조 경계를 소스 수준에서 확인한다.
///
/// 화면을 다시 그리는 과정에서 무심코 넘기 쉬운 선들이라, 컴파일이 아니라
/// 실제 소스를 훑어 검사한다.
final class ArchitectureBoundaryTests: XCTestCase {

    // MARK: - 소스 트리 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // VictoryFairyTests
            .deletingLastPathComponent()   // 저장소 루트
    }

    private static var appSourceRoot: URL {
        repositoryRoot.appendingPathComponent("VictoryFairy")
    }

    /// 앱 타깃의 모든 Swift 파일. 테스트 번들에서 소스 트리를 직접 읽는다.
    private func appSwiftFiles(file: StaticString = #filePath, line: UInt = #line) throws -> [(url: URL, text: String)] {
        let root = Self.appSourceRoot
        guard FileManager.default.fileExists(atPath: root.path) else {
            throw XCTSkip("소스 트리를 찾을 수 없어 건너뛴다: \(root.path)")
        }
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("소스 트리를 훑을 수 없다")
        }
        var results: [(URL, String)] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            results.append((url, text))
        }
        XCTAssertFalse(results.isEmpty, "앱 소스를 하나도 읽지 못했다", file: file, line: line)
        return results
    }

    private func relativePath(_ url: URL) -> String {
        url.path.replacingOccurrences(of: Self.repositoryRoot.path + "/", with: "")
    }

    // MARK: - LLM 경계

    /// iOS 앱에는 LLM 키도, LLM 클라이언트도 들어가면 안 된다.
    /// AI 기능은 백엔드를 거쳐야 한다.
    func testNoDirectLLMClientOrAPIKeyInTheApp() throws {
        let forbidden = [
            "api.anthropic.com",
            "api.openai.com",
            "generativelanguage.googleapis.com",
            "sk-ant-",
            "sk-proj-",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY"
        ]
        for (url, text) in try appSwiftFiles() {
            for needle in forbidden {
                XCTAssertFalse(
                    text.contains(needle),
                    "\(relativePath(url))에 LLM 직접 호출 흔적(\(needle))이 있다"
                )
            }
        }
    }

    // MARK: - 위젯·라이브 액티비티

    /// 이 저장소에는 위젯/라이브 액티비티 타깃이 없다.
    /// 재설계가 그 경계를 새로 만들지 않았는지 확인한다.
    func testNoWidgetKitOrActivityKitWasIntroduced() throws {
        for (url, text) in try appSwiftFiles() {
            XCTAssertFalse(text.contains("import WidgetKit"), "\(relativePath(url))에 WidgetKit이 들어왔다")
            XCTAssertFalse(text.contains("import ActivityKit"), "\(relativePath(url))에 ActivityKit이 들어왔다")
        }
    }

    // MARK: - 통계 계산의 순수성

    /// 통계 계산은 SwiftUI와 SwiftData에서 떨어져 있어야 하고, 그 자체로 테스트 가능해야 한다.
    func testStatisticsCalculationsStayFreeOfSwiftUIAndSwiftData() throws {
        let servicesRoot = Self.appSourceRoot.appendingPathComponent("Domain/Services")
        let files = try appSwiftFiles().filter { $0.url.path.hasPrefix(servicesRoot.path) }
        XCTAssertFalse(files.isEmpty, "Domain/Services에서 파일을 찾지 못했다")

        for (url, text) in files {
            XCTAssertFalse(text.contains("import SwiftUI"), "\(relativePath(url))이 SwiftUI에 의존한다")
            XCTAssertFalse(text.contains("import SwiftData"), "\(relativePath(url))이 SwiftData에 의존한다")
        }
    }

    /// 통계 서비스는 뷰 없이도 호출되고 값을 돌려줘야 한다.
    func testStatisticsServiceIsCallableWithoutAnyView() {
        let service = StatisticsService()
        let state = service.summary(logs: AttendanceLogSample.logs, season: 2026)
        XCTAssertGreaterThanOrEqual(state.wins, 0)
        XCTAssertGreaterThanOrEqual(state.losses, 0)
        XCTAssertEqual(
            state.wins + state.losses + state.draws + state.canceled,
            AttendanceLogSample.logs.count
        )
    }

    func testStatisticsServiceHandlesEmptyInputWithoutInventingData() {
        let state = StatisticsService().summary(logs: [], season: 2026)
        XCTAssertEqual(state.wins, 0)
        XCTAssertEqual(state.losses, 0)
        XCTAssertEqual(state.draws, 0)
        XCTAssertEqual(state.canceled, 0)
    }

    // MARK: - 디자인 토큰이 화면으로 새지 않는지

    /// 색 값은 디자인 시스템에만 있어야 한다.
    /// 기능 모듈이나 공용 컴포넌트에 hex 리터럴이 다시 생기면 실패한다.
    func testFeatureModulesDoNotRedefineColorLiterals() throws {
        let allowedRoots = [
            Self.appSourceRoot.appendingPathComponent("DesignSystem").path,
            Self.appSourceRoot.appendingPathComponent("Domain/TeamTheme.swift").path
        ]
        for (url, text) in try appSwiftFiles() {
            guard !allowedRoots.contains(where: { url.path.hasPrefix($0) }) else { continue }
            XCTAssertFalse(
                text.contains("Color(hex:"),
                "\(relativePath(url))이 색 리터럴을 다시 정의한다. 디자인 토큰을 쓰라"
            )
        }
    }

    // MARK: - 프리뷰가 백엔드를 부르지 않는지

    /// 프리뷰는 결정적이어야 하며 실제 서버를 부르면 안 된다.
    func testPreviewsDoNotCallTheProductionBackend() throws {
        for (url, text) in try appSwiftFiles() {
            let previewBlocks = text.components(separatedBy: "#Preview").dropFirst()
            for block in previewBlocks {
                // 프리뷰 본문만 대략적으로 훑는다.
                let snippet = String(block.prefix(1_200))
                XCTAssertFalse(
                    snippet.contains("URLSession"),
                    "\(relativePath(url))의 프리뷰가 네트워크를 호출한다"
                )
                XCTAssertFalse(
                    snippet.contains("APIClient("),
                    "\(relativePath(url))의 프리뷰가 API 클라이언트를 만든다"
                )
            }
        }
    }

    /// 프리뷰용 저장소는 지정한 suite 안에서만 살아야 한다.
    /// suite 이름이 다르면 상태가 서로 새지 않아야 프리뷰가 결정적이다.
    @MainActor
    func testPreviewPreferencesAreIsolatedPerSuite() {
        let onboarded = UserPreferencesStore.preview(
            suiteName: "VFBoundaryOnboarded",
            hasCompletedOnboarding: true,
            favoriteTeamID: "lg-twins"
        )
        let fresh = UserPreferencesStore.preview(
            suiteName: "VFBoundaryFresh",
            hasCompletedOnboarding: false
        )

        XCTAssertTrue(onboarded.hasCompletedOnboarding)
        XCTAssertEqual(onboarded.favoriteTeamID, "lg-twins")
        XCTAssertFalse(fresh.hasCompletedOnboarding, "다른 suite의 상태가 새어 들어왔다")
        XCTAssertNotEqual(fresh.favoriteTeamID, "lg-twins", "다른 suite의 팀 선택이 새어 들어왔다")
    }

    // MARK: - 번들 식별자와 스킴

    /// 번들 식별자와 공유 스킴은 이번 작업에서 바뀌면 안 된다.
    func testBundleIdentifierAndSchemesAreUnchanged() throws {
        let projectFile = Self.repositoryRoot
            .appendingPathComponent("VictoryFairy.xcodeproj/project.pbxproj")
        let text = try String(contentsOf: projectFile, encoding: .utf8)
        XCTAssertTrue(
            text.contains("PRODUCT_BUNDLE_IDENTIFIER = com.hwangseokbeom.victoryfairy;"),
            "번들 식별자가 바뀌었다"
        )

        let schemesRoot = Self.repositoryRoot
            .appendingPathComponent("VictoryFairy.xcodeproj/xcshareddata/xcschemes")
        let schemes = try FileManager.default
            .contentsOfDirectory(atPath: schemesRoot.path)
            .filter { $0.hasSuffix(".xcscheme") }
            .sorted()
        XCTAssertEqual(
            schemes,
            ["VictoryFairy-Dev.xcscheme", "VictoryFairy-Production.xcscheme", "VictoryFairy.xcscheme"],
            "공유 스킴 구성이 바뀌었다"
        )
    }
}
