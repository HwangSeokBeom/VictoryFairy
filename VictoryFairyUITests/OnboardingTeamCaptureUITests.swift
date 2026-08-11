import XCTest

/// Pencil 온보딩 팀 단계의 기본·선택·좁은 폭·AccessibilityXXXL 증거를 만든다.
final class OnboardingTeamCaptureUITests: XCTestCase {
    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = environment?.isEmpty == false
            ? environment!
            : "/tmp/VictoryFairy-onboarding-team-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = app.windows.firstMatch.frame.width
        guard width <= 390 else {
            throw XCTSkip("좁은 폭 캡처는 390pt 이하에서만 만든다. 현재 폭 \(width)pt")
        }
    }

    private func requirePrimaryWidth(_ app: XCUIApplication) throws {
        let width = app.windows.firstMatch.frame.width
        guard width > 390 else {
            throw XCTSkip("기본 폭 캡처는 390pt 초과에서만 만든다. 현재 폭 \(width)pt")
        }
    }

    private func launchTeamStep(accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset"]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.welcome.start"].waitForExistence(timeout: 12))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(app.buttons["onboarding.overview.next"].waitForExistence(timeout: 8))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(node(app, "onboarding.selectTeam").waitForExistence(timeout: 8))
        return app
    }

    @discardableResult
    private func scrollToTeam(_ app: XCUIApplication, _ teamID: String) -> XCUIElement {
        let card = app.buttons["onboarding.team.\(teamID)"]
        for _ in 0..<16 {
            if card.exists, card.isHittable { return card }
            let scroll = node(app, "onboarding.scroll")
            XCTAssertTrue(scroll.exists, "온보딩 콘텐츠 스크롤을 찾지 못했다")
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(card.exists && card.isHittable, "\(teamID) 캡처 상태에 닿지 못했다")
        return card
    }

    private func capture(_ app: XCUIApplication, _ filename: String) {
        usleep(800_000)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = captureDirectory.appendingPathComponent(filename)
        do {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                print("CAPTURE_PRESERVED \(url.path)")
                return
            }
            try shot.pngRepresentation.write(to: url, options: .withoutOverwriting)
            print("CAPTURED \(url.path)")
        } catch {
            XCTFail("캡처를 저장하지 못했다: \(filename) — \(error)")
        }
    }

    func testCapture01_primaryDefault() throws {
        let app = launchTeamStep()
        try requirePrimaryWidth(app)
        XCTAssertFalse(app.buttons["onboarding.team.next"].isEnabled)
        capture(app, "01-onboarding-team-primary-default.png")
    }

    func testCapture02_primarySelected() throws {
        let app = launchTeamStep()
        try requirePrimaryWidth(app)
        scrollToTeam(app, "samsung-lions").tap()
        XCTAssertEqual(app.buttons["onboarding.team.next"].label, "이 팀으로 응원할게요")
        capture(app, "02-onboarding-team-primary-selected.png")
    }

    func testCapture03_compactDefault() throws {
        let app = launchTeamStep()
        try requireCompactWidth(app)
        XCTAssertFalse(app.buttons["onboarding.team.next"].isEnabled)
        capture(app, "03-onboarding-team-compact-default.png")
    }

    func testCapture04_compactSelected() throws {
        let app = launchTeamStep()
        try requireCompactWidth(app)
        scrollToTeam(app, "samsung-lions").tap()
        XCTAssertEqual(app.buttons["onboarding.team.next"].label, "이 팀으로 응원할게요")
        capture(app, "04-onboarding-team-compact-selected.png")
    }

    func testCapture05_accessibilityXXXLDefault() throws {
        let app = launchTeamStep(accessibilitySize: true)
        try requirePrimaryWidth(app)
        XCTAssertGreaterThanOrEqual(scrollToTeam(app, "lg-twins").frame.height, 80)
        capture(app, "05-onboarding-team-accessibility-xxxl-default.png")
    }

    func testCapture06_accessibilityXXXLSelected() throws {
        let app = launchTeamStep(accessibilitySize: true)
        try requirePrimaryWidth(app)
        let samsung = scrollToTeam(app, "samsung-lions")
        samsung.tap()
        XCTAssertTrue(samsung.isSelected)
        XCTAssertTrue(samsung.label.contains("선택됨"))
        capture(app, "06-onboarding-team-accessibility-xxxl-selected.png")
    }
}
