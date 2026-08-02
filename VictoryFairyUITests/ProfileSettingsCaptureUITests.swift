import XCTest

/// Pencil `08_Profile_Settings`(NffPV)이 실제 제품에서 어떻게 보이는지 남긴다.
///
/// 모든 캡처는 **진짜 `ProfileSettingsView`**를 찍는다. 팀 없는 방어 상태 한 장만
/// DEBUG 픽스처로 띄우는데, 그것도 화면은 같은 제품 화면이다. 온보딩은 건드리지 않는다.
final class ProfileSettingsCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-profile-my-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var tag: String {
        let value = ProcessInfo.processInfo.environment["VF_CAPTURE_TAG"]
        return (value?.isEmpty == false) ? value! : "device"
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        for _ in 0..<12 where !element.isHittable { app.swipeUp() }
    }

    private func capture(_ name: String) {
        usleep(900_000)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(tag)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = captureDirectory.appendingPathComponent("\(tag)-\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("CAPTURED \(url.path)")
        } catch {
            XCTFail("캡처를 저장하지 못했다: \(error)")
        }
    }

    // MARK: - 진입

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestOnboardingCompleted", "1"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @discardableResult
    private func openMy(_ extra: [String] = [], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(extra, accessibilitySize: accessibilitySize)
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "마이 화면이 열리지 않았다")
        return app
    }

    /// 이름과 팀은 인자로 받는다. 같은 실행 인자를 두 번 넘기면 앞의 값만 읽혀
    /// "긴 이름"을 심었다고 착각하게 된다(실측).
    private func populated(name: String = "민지", teamID: String = "samsung-lions",
                           accessibilitySize: Bool = false) -> XCUIApplication {
        openMy(["-VFUITestTeamID", teamID,
                "-VFUITestStadiumID", "daegu-lions",
                "-VFUITestDisplayName", name],
               accessibilitySize: accessibilitySize)
    }

    // MARK: - 1~4. 기본 화면과 카드

    func testCapture01to04_defaultProfileAndCard() {
        let app = populated()
        XCTAssertTrue(node(app, "profile.card").exists, "프로필 카드가 없다")
        capture("01-profile-my-default")
        capture("02-profile-card")

        // 카드의 네 의미 요소가 각각 독립이다.
        for identifier in ["profile.card", "profile.name", "profile.team", "profile.edit"] {
            XCTAssertEqual(app.descendants(matching: .any).matching(identifier: identifier).count, 1,
                           "\(identifier)이 독립 요소가 아니다")
        }
        capture("03-independent-card-semantics")

        XCTAssertTrue(app.buttons["profile.edit"].isHittable, "프로필 수정을 누를 수 없다")
        capture("04-profile-edit-affordance")
    }

    // MARK: - 5. 프로필 편집기

    func testCapture05_profileEditorPresented() {
        let app = populated()
        app.buttons["profile.edit"].tap()
        XCTAssertTrue(waits(text(app, "프로필"), 10), "프로필 편집기가 열리지 않았다")
        capture("05-profile-editor-presented")
    }

    // MARK: - 6~7. 빠진 값들

    func testCapture06_missingDisplayName() {
        let app = openMy(["-VFUITestTeamID", "samsung-lions",
                          "-VFUITestStadiumID", "daegu-lions"])
        XCTAssertEqual(node(app, "profile.name").label, "이름을 정하지 않았어요",
                       "중립 이름 상태가 아니다")
        capture("06-missing-display-name")
    }

    /// 제품 경로로는 닿을 수 없는 **방어** 상태다. DEBUG 픽스처로만 띄운다.
    func testCapture07_defensiveNoTeamState() {
        let app = openMy(["-VFUITestProfileFixture", "noTeam",
                          "-VFUITestDisplayName", "민지"])
        let team = node(app, "profile.team")
        XCTAssertTrue(waits(team), "팀 자리가 없다")
        XCTAssertTrue(team.label.contains("고르지 않"), "방어 상태가 아니다 — \(team.label)")
        capture("07-defensive-no-team")
    }

    // MARK: - 8~10. 긴 문자열과 요정

    func testCapture08to10_longNamesAndFairy() {
        let long = populated(name: "야구를정말사랑하는아주긴이름을가진사용자입니다")
        capture("08-long-display-name")
        long.terminate()

        let longTeam = populated(teamID: "kiwoom-heroes")
        capture("09-long-team-name")
        longTeam.terminate()

        let app = populated()
        XCTAssertTrue(node(app, "profile.card").exists)
        capture("10-victory-fairy-treatment")
    }

    // MARK: - 11~13. 팀 변경

    func testCapture11to13_teamChangeFlow() {
        let app = populated()
        let row = node(app, "profile.teamChange")
        XCTAssertTrue(row.isHittable, "응원 팀 변경을 누를 수 없다")
        capture("11-team-change-row")

        row.tap()
        XCTAssertTrue(waits(text(app, "응원팀 변경"), 10), "팀 선택 화면이 열리지 않았다")
        capture("12-team-selection-presented")

        let lg = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "LG 트윈스")).firstMatch
        XCTAssertTrue(waits(lg, 8), "LG 트윈스를 찾지 못했다")
        lg.tap()
        app.buttons["완료"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "마이로 돌아오지 못했다")
        XCTAssertTrue(node(app, "profile.team").label.contains("LG"),
                      "고른 팀이 카드에 반영되지 않았다")
        capture("13-selected-team-in-card")
    }

    // MARK: - 14~16. 앱 정보

    func testCapture14to16_appInformation() {
        let app = populated()
        let version = node(app, "profile.appVersion")
        scrollTo(app, version)
        capture("14-app-information-section")

        for identifier in ["profile.legal.privacy", "profile.legal.terms",
                           "profile.legal.accountDeletion"] {
            XCTAssertTrue(node(app, identifier).exists, "\(identifier)이 없다")
        }
        capture("15-legal-rows")

        XCTAssertFalse(version.label.contains("0.1.0"), "예전 하드코딩 버전이 보인다")
        XCTAssertFalse(version.label.contains("2.0.0"), "Pencil 견본 버전이 보인다")
        capture("16-bundle-version-row")
    }

    // MARK: - 17. 좁은 폭 · 큰 글자

    func testCapture17_compactAndAccessibilityXXXL() {
        let app = populated(accessibilitySize: true)
        XCTAssertTrue(node(app, "profile.card").exists, "큰 글자에서 카드가 없다")
        capture("17-compact-accessibilityXXXL")
    }

    // MARK: - 18. 뒷받침 없는 것이 없다는 증거

    func testCapture18_supportedOnlyLayout() {
        let app = populated()
        for forbidden in ["경기 시작 알림", "직관 후 기록 리마인드", "기록 내보내기",
                          "데이터 내보내기", "사진 보관함 관리", "128장", "로그아웃",
                          "추후 제공", "세 번째 시즌"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
        XCTAssertFalse(node(app, "profile.appVersion").label.contains("0.1.0"))
        XCTAssertFalse(node(app, "profile.appVersion").label.contains("2.0.0"))
        XCTAssertFalse(app.navigationBars.buttons["닫기"].exists, "탭 루트에 닫기가 있다")
        capture("18-supported-only-layout")
    }
}
