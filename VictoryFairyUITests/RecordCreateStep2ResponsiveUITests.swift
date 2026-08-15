import XCTest

/// 스테이징된 2단계의 좁은 폭·키보드·큰 글자 동작.
///
/// 좁은 폭 검사는 375pt급 기기에서만 뜻이 있으므로 그 밖에서는 건너뛴다.
final class RecordCreateStep2ResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func button(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let byIdentifier = app.buttons.matching(identifier: identifier).firstMatch
        return byIdentifier.exists ? byIdentifier : node(app, identifier)
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// 아래에 고정된 액션 막대 밑에 깔린 요소도 XCUI는 `isHittable`로 본다(실측).
    /// 그래서 창 안에 들어왔는지, 그리고 고정 막대 위에 있는지까지 확인한다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        let pinned = ["recordCreate.step2.next", "recordCreate.step2.skip",
                      "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            guard element.exists else { app.swipeUp(); continue }
            let frame = element.frame
            let isPinnedControl = pinned.contains(element.identifier)
            let bar = app.buttons.matching(identifier: "recordCreate.step2.next").firstMatch
            let ceiling = (isPinnedControl || !bar.exists) ? window.maxY : min(window.maxY, bar.frame.minY)
            if element.isHittable, frame.minY >= window.minY, frame.maxY <= ceiling { return element }
            if frame.maxY > ceiling { app.swipeUp() } else { app.swipeDown() }
        }
        return element
    }

    private func settled(_ element: XCUIElement) -> CGRect {
        var previous = element.frame
        for _ in 0..<25 {
            usleep(120_000)
            let current = element.frame
            if current == previous { return current }
            previous = current
        }
        return previous
    }

    private func requireCompactWidth(_ app: XCUIApplication) throws -> CGRect {
        let screen = app.windows.firstMatch.frame
        guard screen.width <= 380 else {
            throw XCTSkip("좁은 폭 검증은 375pt급 기기에서만 유효하다. 현재 폭 \(screen.width)pt")
        }
        return screen
    }

    private func launchStep2(accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", "fresh"]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 들어가지 못했다")
        return app
    }

    /// 메뉴에서 값을 고른다.
    ///
    /// 큰 글자 + 좁은 폭(SE 3 · AccessibilityXXXL)에서는 목록이 화면보다 길어 아래쪽
    /// 항목이 접근성 트리에 아직 없다(실측). 그럴 때는 목록을 굴려서 찾는다.
    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        control.tap()
        let item = app.buttons[option].firstMatch
        for _ in 0..<8 {
            if item.waitForExistence(timeout: 2) { break }
            app.swipeUp()
        }
        XCTAssertTrue(item.exists, "\(option) 항목이 없다")
        item.tap()
    }

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons.matching(identifier: "recordCreate.step2.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
    }

    // MARK: - 좁은 폭

    func testCompact01_everyStep2ControlStaysInsideTheViewport() throws {
        let app = launchStep2()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.progress", "recordCreate.step2.title", "recordCreate.step2.subtitle",
                           "recordCreate.field.seat", "recordCreate.companion.alone",
                           "recordCreate.companion.family", "recordCreate.companion.friend",
                           "recordCreate.companion.custom"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(identifier)이 왼쪽으로 잘렸다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(identifier)이 오른쪽으로 잘렸다")
        }
    }

    func testCompact02_everyActionRemainsReachable() throws {
        let app = launchStep2()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.step2.next", "recordCreate.step2.skip",
                           "recordCreate.back", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "\(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 잘렸다")
        }
    }

    func testCompact03_pageDoesNotScrollHorizontally() throws {
        let app = launchStep2()
        let screen = try requireCompactWidth(app)
        let root = node(app, "recordCreate.step2.root")
        let before = settled(root).minX
        root.swipeLeft()
        XCTAssertEqual(settled(root).minX, before, accuracy: 0.5, "가로로 스크롤됐다")
        XCTAssertLessThanOrEqual(settled(root).maxX, screen.maxX + 0.5)
    }

    func testCompact04_longSeatStaysReadable() throws {
        let app = launchStep2()
        let screen = try requireCompactWidth(app)
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        seat.typeText("3루 내야 지정석 K열 24번 통로 바로 옆 자리")
        dismissKeyboard(app)
        let frame = settled(node(app, "recordCreate.field.seat"))
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "긴 좌석이 가로로 잘렸다")
        XCTAssertGreaterThan(frame.height, 0)
    }

    func testCompact05_longCustomCompanionStaysReadable() throws {
        let app = launchStep2()
        let screen = try requireCompactWidth(app)
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        let field = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        field.tap()
        field.typeText("회사 동료들과 야구 동호회 사람들 그리고 사촌 동생까지")
        dismissKeyboard(app)
        let frame = settled(node(app, "recordCreate.companion.customField"))
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "긴 동행 값이 가로로 잘렸다")
        XCTAssertGreaterThan(frame.height, 0)
    }

    // MARK: - 키보드

    func testKeyboard01_seatFieldStaysVisibleWhileTyping() throws {
        let app = launchStep2()
        _ = try requireCompactWidth(app)
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(settled(seat).maxY, app.keyboards.element.frame.minY + 0.5,
                          "좌석 칸이 키보드에 가렸다")
        seat.typeText("3루")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "3루")
    }

    func testKeyboard02_customCompanionFieldStaysVisibleAndDismissable() throws {
        let app = launchStep2()
        _ = try requireCompactWidth(app)
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        let field = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(settled(field).maxY, app.keyboards.element.frame.minY + 0.5,
                          "직접 입력 칸이 키보드에 가렸다")
        let done = app.buttons.matching(identifier: "recordCreate.step2.keyboardDone").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "키보드를 빠져나갈 길이 없다")
        done.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 8), "키보드가 내려가지 않았다")
        // 내린 뒤에는 두 액션 모두에 닿을 수 있다.
        for identifier in ["recordCreate.step2.next", "recordCreate.step2.skip"] {
            XCTAssertTrue(scrollIntoView(app, node(app, identifier)).isHittable, "\(identifier)에 닿을 수 없다")
        }
    }

    // MARK: - AccessibilityXXXL

    private func baselineHeight(of identifier: String) -> CGFloat {
        let normal = launchStep2()
        let height = settled(scrollIntoView(normal, node(normal, identifier))).height
        normal.terminate()
        return height
    }

    func testAccessibilityXXXL01_categoryActuallyApplies() {
        let baseline = baselineHeight(of: "recordCreate.step2.title")
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = launchStep2(accessibilitySize: true)
        let title = settled(scrollIntoView(app, node(app, "recordCreate.step2.title")))
        XCTAssertGreaterThan(title.height, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt")
    }

    func testAccessibilityXXXL02_everyControlStaysInsideTheViewport() {
        let app = launchStep2(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.progress", "recordCreate.step2.title", "recordCreate.step2.subtitle",
                           "recordCreate.field.seat", "recordCreate.companion.alone",
                           "recordCreate.companion.family", "recordCreate.companion.friend",
                           "recordCreate.companion.custom"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL03_actionsAndCancelRemainReachable() {
        let app = launchStep2(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.step2.next", "recordCreate.step2.skip",
                           "recordCreate.back", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "큰 글자에서 \(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL04_companionSelectionStillWorks() {
        let app = launchStep2(accessibilitySize: true)
        let chip = scrollIntoView(app, button(app, "recordCreate.companion.family"))
        chip.tap()
        XCTAssertTrue(button(app, "recordCreate.companion.family").isSelected,
                      "큰 글자에서 선택 상태가 전해지지 않는다")
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.companion.customField")),
                      "큰 글자에서 직접 입력 칸이 열리지 않는다")
    }

    func testAccessibilityXXXL05_progressStillReadsAsOneSentence() {
        let app = launchStep2(accessibilitySize: true)
        let progress = node(app, "recordCreate.progress")
        XCTAssertTrue(waits(progress), "진행 표시가 없다")
        XCTAssertEqual(progress.label, "3단계 중 2단계, 그날의 디테일")
        XCTAssertLessThanOrEqual(settled(progress).maxX, app.windows.firstMatch.frame.maxX + 0.5,
                                 "진행 표시가 가로로 잘렸다")
    }
}
