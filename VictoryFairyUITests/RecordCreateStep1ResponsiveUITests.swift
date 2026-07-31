import XCTest

/// 스테이징된 1단계의 좁은 폭·키보드·큰 글자 동작.
///
/// 좁은 폭 검사는 375pt급 기기에서만 뜻이 있으므로 그 밖에서는 건너뛴다.
/// 큰 글자 검사는 어느 기기에서도 유효하다.
final class RecordCreateStep1ResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    @discardableResult
    private func launch(fixture: String = "fresh", accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", fixture]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        for _ in 0..<12 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
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

    /// 좁은 폭에서만 뜻이 있는 검사인지 확인한다.
    private func requireCompactWidth(_ app: XCUIApplication) throws -> CGRect {
        let screen = app.windows.firstMatch.frame
        guard screen.width <= 380 else {
            throw XCTSkip("좁은 폭 검증은 375pt급 기기에서만 유효하다. 현재 폭 \(screen.width)pt")
        }
        return screen
    }

    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        control.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(waits(item, 8), "\(option) 항목이 없다")
        item.tap()
    }

    private func fillValidStep1(_ app: XCUIApplication) {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
    }

    // MARK: - 좁은 폭

    func testCompact01_everyStep1ControlStaysInsideTheViewport() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.progress", "recordCreate.step1.title", "recordCreate.step1.subtitle",
                           "recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(identifier)이 왼쪽으로 잘렸다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(identifier)이 오른쪽으로 잘렸다")
        }
    }

    func testCompact02_scoreAndResultControlsRemainReachable() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.score.our", "recordCreate.score.opponent",
                           "recordCreate.result.win", "recordCreate.result.loss",
                           "recordCreate.result.draw", "recordCreate.result.canceled"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "\(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 잘렸다")
        }
    }

    func testCompact03_bothActionsAndCancelRemainReachable() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.next", "recordCreate.saveMinimal", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "\(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 잘렸다")
        }
    }

    func testCompact04_pageDoesNotScrollHorizontally() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        let root = node(app, "recordCreate.step1.root")
        let before = settled(root).minX
        root.swipeLeft()
        XCTAssertEqual(settled(root).minX, before, accuracy: 0.5, "가로로 스크롤됐다")
        XCTAssertLessThanOrEqual(settled(root).maxX, screen.maxX + 0.5)
    }

    func testCompact05_longTeamNamesDoNotClip() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        // 가장 긴 구단명 두 개를 고른다.
        choose(app, field: "recordCreate.field.opponentTeam", option: "키움 히어로즈")
        choose(app, field: "recordCreate.field.stadium", option: "인천 SSG 랜더스필드")
        for identifier in ["recordCreate.field.opponentTeam", "recordCreate.field.stadium"] {
            let frame = settled(scrollIntoView(app, node(app, identifier)))
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(identifier)이 잘렸다")
            XCTAssertGreaterThan(frame.height, 0)
        }
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "인천 SSG 랜더스필드")
    }

    func testCompact06_validationMessageStaysReadable() throws {
        let app = launch()
        let screen = try requireCompactWidth(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let message = scrollIntoView(app, node(app, "recordCreate.validationMessage"))
        XCTAssertTrue(waits(message, 8), "검증 안내가 없다")
        let frame = settled(message)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "안내가 가로로 잘렸다")
        XCTAssertGreaterThan(frame.height, 0)
    }

    // MARK: - 키보드

    func testKeyboard01_scoreFieldStaysVisibleWhileTyping() throws {
        let app = launch()
        _ = try requireCompactWidth(app)
        let ours = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ours.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(settled(ours).maxY, app.keyboards.element.frame.minY + 0.5,
                          "입력 칸이 키보드에 가렸다")
        ours.typeText("7")
        XCTAssertEqual(node(app, "recordCreate.score.our").value as? String ?? "", "7")
    }

    func testKeyboard02_theNumberPadOffersAWayOutAndActionsStayReachable() throws {
        let app = launch()
        _ = try requireCompactWidth(app)
        fillValidStep1(app)
        let ours = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ours.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")

        // 숫자 키패드에는 Return이 없다. 빠져나갈 길이 반드시 보여야 한다.
        let done = app.buttons.matching(identifier: "recordCreate.score.done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "숫자 키패드를 빠져나갈 길이 없다")
        XCTAssertTrue(done.isHittable, "키패드 완료를 누를 수 없다")
        done.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 8), "키패드가 내려가지 않았다")

        // 키패드가 내려간 뒤에는 두 액션 모두에 닿을 수 있다.
        for identifier in ["recordCreate.next", "recordCreate.saveMinimal"] {
            let action = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(action.exists && action.isHittable, "\(identifier)에 닿을 수 없다")
        }
    }

    // MARK: - AccessibilityXXXL

    /// 큰 글자가 실제로 적용됐는지 기본 크기와 견주어 확인한다.
    private func baselineHeight(of identifier: String) -> CGFloat {
        let normal = launch()
        let height = settled(scrollIntoView(normal, node(normal, identifier))).height
        normal.terminate()
        return height
    }

    func testAccessibilityXXXL01_categoryActuallyApplies() {
        let baseline = baselineHeight(of: "recordCreate.step1.title")
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = launch(accessibilitySize: true)
        let title = settled(scrollIntoView(app, node(app, "recordCreate.step1.title")))
        XCTAssertGreaterThan(title.height, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt")
    }

    func testAccessibilityXXXL02_everyControlStaysInsideTheViewport() {
        let app = launch(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.progress", "recordCreate.step1.title", "recordCreate.step1.subtitle",
                           "recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam",
                           "recordCreate.score.our", "recordCreate.score.opponent"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL03_bothActionsAndCancelRemainReachable() {
        let app = launch(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.next", "recordCreate.saveMinimal", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "큰 글자에서 \(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL04_resultSelectionAndFeedbackStayUsable() {
        let app = launch(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        let feedback = scrollIntoView(app, node(app, "recordCreate.result.feedback"))
        XCTAssertTrue(waits(feedback), "큰 글자에서 결과 안내가 없다")
        XCTAssertEqual(feedback.label, "오늘은 승리요정이네요!")
        XCTAssertLessThanOrEqual(settled(feedback).maxX, screen.maxX + 0.5, "결과 안내가 잘렸다")
    }

    func testAccessibilityXXXL05_progressStillReadsAsOneSentence() {
        let app = launch(accessibilitySize: true)
        let progress = node(app, "recordCreate.progress")
        XCTAssertTrue(waits(progress), "진행 표시가 없다")
        XCTAssertEqual(progress.label, "3단계 중 1단계, 경기")
        XCTAssertLessThanOrEqual(settled(progress).maxX, app.windows.firstMatch.frame.maxX + 0.5,
                                 "진행 표시가 가로로 잘렸다")
    }
}
