import XCTest

/// Pencil 온보딩 팀 단계가 기본 폭, 320pt급 좁은 폭, AccessibilityXXXL에서
/// 실제로 선택·스크롤·복귀 가능한지 검증한다.
final class OnboardingTeamResponsiveUITests: XCTestCase {
    private let visualRows = [
        ["lg-twins", "doosan-bears"],
        ["samsung-lions", "kia-tigers"],
        ["ssg-landers", "kt-wiz"],
        ["nc-dinos", "lotte-giants"],
        ["kiwoom-heroes", "hanwha-eagles"]
    ]

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
            throw XCTSkip("320pt급 좁은 폭 검사는 390pt 이하에서만 뜻이 있다 (현재 \(width)pt)")
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
    private func scrollToTeam(_ app: XCUIApplication, _ teamID: String,
                              file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let card = app.buttons["onboarding.team.\(teamID)"]
        for _ in 0..<16 {
            if card.exists, card.isHittable { return card }
            dragScroll(app, upwards: true)
        }
        for _ in 0..<16 {
            if card.exists, card.isHittable { return card }
            dragScroll(app, upwards: false)
        }
        XCTAssertTrue(card.exists && card.isHittable,
                      "\(teamID) 팀 카드에 닿지 못했다",
                      file: file, line: line)
        return card
    }

    /// XXXL 한 열 목록에서는 전체 화면 swipe가 한 번에 여러 카드를 건너뛴다.
    /// 실제 콘텐츠 스크롤을 짧게 끌어 목표 카드의 중앙을 가시 영역에 넣는다.
    private func dragScroll(_ app: XCUIApplication, upwards: Bool) {
        let scroll = node(app, "onboarding.scroll")
        XCTAssertTrue(scroll.exists, "온보딩 콘텐츠 스크롤을 찾지 못했다")
        let startY: CGFloat = upwards ? 0.72 : 0.28
        let endY: CGFloat = upwards ? 0.42 : 0.58
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: startY))
        let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: endY))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func assertInsideWidth(_ app: XCUIApplication, _ element: XCUIElement, _ name: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 0.5,
                                    "\(name)이 왼쪽으로 잘렸다 — \(frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5,
                                 "\(name)이 오른쪽으로 잘렸다 — \(frame)", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, "\(name)이 접혔다", file: file, line: line)
    }

    func testR01_regularSizesKeepTheAuthoredTwoColumnRows() {
        let app = launchTeamStep()

        for row in visualRows.prefix(3) {
            let left = scrollToTeam(app, row[0])
            let right = scrollToTeam(app, row[1])
            XCTAssertLessThan(left.frame.minX, right.frame.minX)
            XCTAssertEqual(left.frame.minY, right.frame.minY, accuracy: 2)
            assertInsideWidth(app, left, row[0])
            assertInsideWidth(app, right, row[1])
        }
    }

    func testR02_compactWidthKeepsTwoColumnsAndAFixedUsableCTA() throws {
        let app = launchTeamStep()
        try requireCompactWidth(app)

        let left = scrollToTeam(app, "lg-twins")
        let right = scrollToTeam(app, "doosan-bears")
        XCTAssertLessThan(left.frame.minX, right.frame.minX)
        XCTAssertEqual(left.frame.minY, right.frame.minY, accuracy: 2)

        left.tap()
        let next = app.buttons["onboarding.team.next"]
        XCTAssertTrue(next.isEnabled)
        XCTAssertTrue(next.isHittable, "좁은 폭에서 CTA에 닿을 수 없다")
        XCTAssertEqual(next.label, "이 팀으로 응원할게요")
        assertInsideWidth(app, next, "CTA")
    }

    func testR03_compactWidthCanReachAllTenTeamsAndTheNote() throws {
        let app = launchTeamStep()
        try requireCompactWidth(app)

        for teamID in visualRows.flatMap({ $0 }) {
            assertInsideWidth(app, scrollToTeam(app, teamID), teamID)
        }

        let note = node(app, "onboarding.team.note")
        for _ in 0..<12 where !note.exists || !note.isHittable { dragScroll(app, upwards: true) }
        XCTAssertTrue(note.exists && note.isHittable, "안내 문구에 닿지 못했다")
        assertInsideWidth(app, note, "안내 문구")
    }

    func testR04_accessibilityXXXLUsesOneColumnWithLargeCards() {
        let app = launchTeamStep(accessibilitySize: true)

        let lg = scrollToTeam(app, "lg-twins")
        let doosan = scrollToTeam(app, "doosan-bears")
        XCTAssertEqual(lg.frame.minX, doosan.frame.minX, accuracy: 2)
        XCTAssertGreaterThan(doosan.frame.minY, lg.frame.minY)
        XCTAssertGreaterThanOrEqual(lg.frame.height, 80)
        assertInsideWidth(app, lg, "XXXL LG 카드")
        assertInsideWidth(app, doosan, "XXXL 두산 카드")
    }

    func testR05_accessibilityXXXLCanSelectTheBottomTeamAndAdvance() {
        let app = launchTeamStep(accessibilitySize: true)

        let hanwha = scrollToTeam(app, "hanwha-eagles")
        hanwha.tap()
        XCTAssertTrue(hanwha.isSelected)
        XCTAssertTrue(hanwha.label.contains("선택됨"))

        let next = app.buttons["onboarding.team.next"]
        XCTAssertTrue(next.isEnabled)
        XCTAssertTrue(next.isHittable, "XXXL에서 CTA가 화면 밖으로 밀렸다")
        next.tap()
        XCTAssertTrue(node(app, "onboarding.selectStadium").waitForExistence(timeout: 8))
    }

    func testR06_accessibilityXXXLNoteAndSelectionAreNotColorOnly() {
        let app = launchTeamStep(accessibilitySize: true)

        let samsung = scrollToTeam(app, "samsung-lions")
        samsung.tap()
        XCTAssertTrue(samsung.isSelected)
        XCTAssertTrue(samsung.label.contains("선택됨"))

        let note = node(app, "onboarding.team.note")
        for _ in 0..<16 where !note.exists || !note.isHittable { dragScroll(app, upwards: true) }
        XCTAssertTrue(note.exists && note.isHittable)
        XCTAssertEqual(note.label, "응원팀은 나중에 설정에서 변경할 수 있어요.")
    }
}
