import XCTest

/// 09_States의 구장 시트와 Memory Card를 compact/AccessibilityXXXL에서 실측한다.
final class StatesResponsiveUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func viewport(_ app: XCUIApplication) -> CGRect {
        app.windows.firstMatch.frame
    }

    private func requireCompactWidth(_ app: XCUIApplication) throws -> CGRect {
        let frame = viewport(app)
        guard frame.width <= 390 else {
            throw XCTSkip("SE 3 compact 검증은 390pt 이하에서만 유효하다. 현재 폭 \(frame.width)pt")
        }
        return frame
    }

    private func assertInsideWidth(
        _ element: XCUIElement,
        viewport: CGRect,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name)이 없다", file: file, line: line)
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX - 1,
                                    "\(name)이 왼쪽으로 잘렸다: \(frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX + 1,
                                 "\(name)이 오른쪽으로 잘렸다: \(frame)", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, "\(name)의 높이가 0이다", file: file, line: line)
    }

    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, limit: Int = 18) -> XCUIElement {
        for _ in 0..<limit {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(240_000)
        }
        XCTAssertTrue(element.exists && element.isHittable, "스크롤해도 요소에 닿지 못했다")
        return element
    }

    private func launchStadium(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestRecordCreateStaged", "fresh",
            "-VFUITestStadiumSheetFixture", fixture
        ]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForExistence(timeout: 15))
        scrollTo(app, node(app, "recordCreate.field.stadium")).tap()
        XCTAssertTrue(node(app, "stadiumSheet.root").waitForExistence(timeout: 10))
        XCTAssertTrue(node(app, "stadiumSheet.scenario.\(fixture)").exists)
        return app
    }

    private func memoryFixtureID(_ fixture: String) -> String {
        let seeds = ["noPhoto": 2, "longContent": 7]
        return String(format: "09F10000-0000-4000-8000-%012d", seeds[fixture]!)
    }

    private func launchShare(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestMemoryShareFixture", fixture
        ]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(node(app, "screen.feed").waitForExistence(timeout: 15))
        let share = scrollTo(app, node(app, "feed.share.\(memoryFixtureID(fixture))"))
        share.tap()
        XCTAssertTrue(node(app, "memoryShare.root").waitForExistence(timeout: 12))
        XCTAssertTrue(node(app, "memoryShare.scenario.\(fixture)").exists)
        return app
    }

    func testSR01_compactStadiumCatalogRemainsScrollableAndInsideSE3() throws {
        let app = launchStadium("allNine")
        let screen = try requireCompactWidth(app)
        assertInsideWidth(node(app, "stadiumSheet.root"), viewport: screen, name: "구장 시트")

        let root = node(app, "stadiumSheet.root")
        for id in ["jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
                   "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"] {
            let row = node(app, "stadiumSheet.stadium.\(id)")
            for _ in 0..<12 where !row.exists || !row.isHittable { root.swipeUp() }
            XCTAssertTrue(row.exists, "SE 3에서 canonical 구장에 닿지 못했다: \(id)")
            assertInsideWidth(row, viewport: screen, name: id)
        }
    }

    func testSR02_compactMemoryCardKeepsFiveBySixGeometryAndReachableControls() throws {
        let app = launchShare("noPhoto")
        let screen = try requireCompactWidth(app)
        let card = node(app, "memoryShare.card")
        assertInsideWidth(card, viewport: screen, name: "Memory Card")
        XCTAssertEqual(card.frame.width / card.frame.height, 5.0 / 6.0, accuracy: 0.03)
        for identifier in ["memoryShare.share", "memoryShare.save", "memoryShare.close"] {
            let control = scrollTo(app, node(app, identifier))
            XCTAssertTrue(control.isHittable, "SE 3에서 \(identifier)에 닿지 못했다")
            assertInsideWidth(control, viewport: screen, name: identifier)
        }
    }

    func testSR03_accessibilityXXXLStadiumRowWrapsWithoutLosingItsCanonicalName() {
        let app = launchStadium("longContent", accessibilitySize: true)
        let screen = viewport(app)
        let row = node(app, "stadiumSheet.stadium.jamsil")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertEqual(row.label, "잠실야구장")
        XCTAssertTrue((row.value as? String ?? "").contains("서울"))
        XCTAssertGreaterThanOrEqual(row.frame.height, 80, "AccessibilityXXXL 행이 고정 높이에 잘렸다")
        assertInsideWidth(row, viewport: screen, name: "AccessibilityXXXL 구장 행")
        XCTAssertTrue(node(app, "stadiumSheet.title").exists)
    }

    func testSR04_accessibilityXXXLSharePreservesFullSummaryAndReachableControls() {
        let app = launchShare("longContent", accessibilitySize: true)
        let card = node(app, "memoryShare.card")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(card.label.contains("등록부밖아주긴첫번째구단명"))
        XCTAssertTrue(card.label.contains("대한민국 어딘가에 실제로 기록된 등록부 밖의 아주 긴 야구장 이름"))
        for identifier in ["memoryShare.exportProof", "memoryShare.share", "memoryShare.save", "memoryShare.close"] {
            XCTAssertTrue(scrollTo(app, node(app, identifier)).isHittable,
                          "AccessibilityXXXL에서 \(identifier)에 닿지 못했다")
        }
        XCTAssertEqual(node(app, "memoryShare.exportProof").label, "디코딩 확인 · 1200 × 1440")
    }

    func testSR05_primaryStadiumSheetUsesSafeHorizontalBoundsAndSelectedTrait() {
        let app = launchStadium("canonicalSelected")
        let screen = viewport(app)
        let selected = node(app, "stadiumSheet.stadium.jamsil")
        XCTAssertTrue(selected.isSelected)
        assertInsideWidth(selected, viewport: screen, name: "선택 구장 행")
        assertInsideWidth(node(app, "stadiumSheet.title"), viewport: screen, name: "구장 시트 제목")
    }

    func testSR06_primarySharePreviewUsesSafeBoundsAndDeterministicExportProof() {
        let app = launchShare("noPhoto")
        let screen = viewport(app)
        let card = node(app, "memoryShare.card")
        assertInsideWidth(card, viewport: screen, name: "Memory Card")
        XCTAssertEqual(card.frame.width / card.frame.height, 5.0 / 6.0, accuracy: 0.03)
        XCTAssertEqual(scrollTo(app, node(app, "memoryShare.exportProof")).label,
                       "디코딩 확인 · 1200 × 1440")
    }
}
