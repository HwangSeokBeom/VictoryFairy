import XCTest

/// **응원 팀 변경** 시트가 실제 제품에서 어떻게 보이는지 남긴다.
///
/// 모든 캡처는 진짜 `ProfileSettingsView`에서 시작해 진짜 `TeamSelectionView`를 찍는다.
/// 방어 상태만 DEBUG 픽스처로 띄우는데, 그때도 화면은 같은 제품 화면이다.
final class TeamSelectionCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-team-selector-captures"
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

    private func scrollToOption(_ app: XCUIApplication, _ teamID: String) -> XCUIElement {
        let option = node(app, "teamSelection.team.\(teamID)")
        XCTAssertTrue(waits(option), "\(teamID) 옵션이 없다")
        for _ in 0..<12 where !option.isHittable { app.swipeUp() }
        return option
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
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestDisplayName", "민지"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @discardableResult
    private func openProfile(teamID: String = "samsung-lions",
                             catalog: String? = nil,
                             forceTabs: Bool = false,
                             accessibilitySize: Bool = false) -> XCUIApplication {
        var extra = ["-VFUITestTeamID", teamID]
        if let catalog { extra += ["-VFUITestTeamCatalog", catalog] }
        if forceTabs { extra += ["-VFUITestProfileFixture", "noTeam"] }
        let app = launch(extra, accessibilitySize: accessibilitySize)
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "마이 화면이 열리지 않았다")
        return app
    }

    @discardableResult
    private func openSelector(_ app: XCUIApplication) -> XCUIApplication {
        node(app, "profile.teamChange").tap()
        XCTAssertTrue(waits(node(app, "teamSelection.root"), 10), "팀 선택 시트가 열리지 않았다")
        return app
    }

    // MARK: - 1~3. 마이에서 시트까지

    func testCapture01to03_profileEntryAndSelector() {
        let app = openProfile()
        XCTAssertTrue(node(app, "profile.card").exists, "프로필 카드가 없다")
        capture("01-profile-before-opening")

        XCTAssertTrue(node(app, "profile.teamChange").isHittable, "응원 팀 변경을 누를 수 없다")
        capture("02-profile-team-change-entry")

        openSelector(app)
        XCTAssertTrue(app.navigationBars["응원 팀 변경"].exists, "시트 제목이 다르다")
        capture("03-selector-opened")
    }

    // MARK: - 4~7. 선택과 초안

    func testCapture04to07_selectionAndDraft() {
        let app = openSelector(openProfile())
        let current = scrollToOption(app, "samsung-lions")
        XCTAssertTrue(current.isSelected, "지금 팀이 선택돼 있지 않다")
        capture("04-current-team-selected")

        let other = scrollToOption(app, "lg-twins")
        XCTAssertFalse(other.isSelected, "고르지도 않은 팀이 선택돼 있다")
        capture("05-unselected-option")

        other.tap()
        XCTAssertTrue(node(app, "teamSelection.team.lg-twins").isSelected, "초안이 선택되지 않았다")
        XCTAssertFalse(node(app, "teamSelection.team.samsung-lions").isSelected,
                       "선택이 둘이다")
        capture("06-alternate-draft-selected")

        // 아직 커밋 전이다 — 취소하고 카드가 그대로인지 본다.
        node(app, "teamSelection.cancel").tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertTrue(node(app, "profile.team").label.contains("삼성"),
                      "초안이 카드에 새어 나갔다 — \(node(app, "profile.team").label)")
        capture("07-profile-card-unchanged-during-draft")
    }

    // MARK: - 8~10. 취소와 제스처 해제

    func testCapture08to10_cancellationAndInteractiveDismissal() {
        let app = openSelector(openProfile())
        scrollToOption(app, "lg-twins").tap()
        XCTAssertTrue(node(app, "teamSelection.cancel").isHittable, "취소를 누를 수 없다")
        capture("08-cancel-action")

        node(app, "teamSelection.cancel").tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertTrue(node(app, "profile.team").label.contains("삼성"), "취소가 팀을 바꿨다")
        capture("09-profile-after-cancellation")

        // 제스처로 닫는 경로도 같은 결과다.
        openSelector(app)
        scrollToOption(app, "kia-tigers").tap()
        let sheet = node(app, "teamSelection.root")
        let height = sheet.frame.height
        let start = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.02))
        start.press(forDuration: 0.1,
                    thenDragTo: start.withOffset(CGVector(dx: 0, dy: height)))
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10), "제스처로 닫히지 않았다")
        XCTAssertTrue(node(app, "profile.team").label.contains("삼성"), "제스처 해제가 팀을 바꿨다")
        capture("10-profile-after-interactive-dismissal")
    }

    // MARK: - 11~12. 완료

    func testCapture11to12_completion() {
        let app = openSelector(openProfile())
        scrollToOption(app, "lg-twins").tap()
        XCTAssertTrue(app.buttons["teamSelection.done"].isEnabled, "완료가 잠겨 있다")
        capture("11-done-action")

        node(app, "teamSelection.done").tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertTrue(node(app, "profile.team").label.contains("LG"),
                      "완료가 카드에 반영되지 않았다 — \(node(app, "profile.team").label)")
        capture("12-profile-after-completion")
    }

    // MARK: - 13~14. 방어 상태

    func testCapture13_invalidCurrentTeam() {
        let app = openSelector(openProfile(teamID: "retired-team", forceTabs: true))
        for teamID in ["samsung-lions", "lg-twins", "kia-tigers"] {
            XCTAssertFalse(node(app, "teamSelection.team.\(teamID)").isSelected,
                           "풀리지 않는 값인데 \(teamID)이 선택돼 있다")
        }
        XCTAssertFalse(app.buttons["teamSelection.done"].isEnabled, "완료가 열려 있다")
        capture("13-invalid-current-team")
    }

    /// 빈 목록이어도 시트는 그대로 서 있다. 예전에는 이 자리에서 빈 상태를 찾지
    /// 못했는데, 원인은 시트가 닫힌 것이 아니라 루트 식별자가 자식을 덮어쓴 것이었다.
    func testCapture14_emptyCatalogStaysPresented() {
        let app = openSelector(openProfile(catalog: "empty"))
        XCTAssertTrue(app.navigationBars["응원 팀 변경"].exists, "시트가 사라졌다")
        XCTAssertTrue(waits(node(app, "teamSelection.empty")), "빈 상태를 자기 이름으로 찾지 못한다")
        XCTAssertTrue(text(app, "보여 줄 팀이 없어요").exists, "빈 상태 문구가 없다")
        XCTAssertTrue(app.buttons["teamSelection.cancel"].isHittable, "취소를 누를 수 없다")
        XCTAssertTrue(app.buttons["teamSelection.done"].exists, "완료가 없다")
        XCTAssertFalse(app.buttons["teamSelection.done"].isEnabled, "빈 목록인데 완료가 열려 있다")
        XCTAssertEqual(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "teamSelection.team.")).count, 0,
            "빈 목록인데 팀 카드가 그려졌다")
        capture("14-empty-catalog-stable")
    }

    // MARK: - 15~17. 긴 이름 · 최대 목록 · 큰 글자

    func testCapture15to17_longNamesMaximumAndAccessibility() {
        let long = openSelector(openProfile(catalog: "longNames"))
        XCTAssertTrue(scrollToOption(long, "samsung-lions").label.contains("아주아주긴이름"),
                      "긴 이름이 적용되지 않았다")
        capture("15-long-team-names")
        long.terminate()

        let full = openSelector(openProfile(catalog: "maximum"))
        scrollToOption(full, "hanwha-eagles")
        capture("16-maximum-catalog-scrolled")
        full.terminate()

        let large = openSelector(openProfile(accessibilitySize: true))
        let option = scrollToOption(large, "samsung-lions")
        XCTAssertTrue(option.isSelected, "큰 글자에서 선택 상태가 사라졌다")
        capture("17-compact-accessibilityXXXL-selected")
    }

    // MARK: - 18. 온보딩 것이 없다는 증거

    func testCapture18_profileOnlyLayout() {
        let app = openSelector(openProfile())
        for forbidden in ["어느 팀의 승리요정인가요", "선택한 팀 컬러가 앱 테마에 반영돼요",
                          "나중에 설정에서 변경할 수 있어요", "선택 안 함", "아직 못 정했어요",
                          "시작하기", "검색", "추천"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 시트에 있다")
        }
        XCTAssertTrue(app.navigationBars["응원 팀 변경"].exists, "시트 제목이 다르다")
        capture("18-profile-only-layout")
    }
}
