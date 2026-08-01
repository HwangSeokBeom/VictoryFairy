import XCTest

/// 스테이징된 3단계의 좁은 폭·키보드·큰 글자 동작.
final class RecordCreateStep3ResponsiveUITests: XCTestCase {

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

    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 아래에 고정된 액션 막대 밑에 깔린 요소도 XCUI는 `isHittable`로 본다(실측).
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        let pinned = ["recordCreate.step3.complete", "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            guard element.exists else { app.swipeUp(); continue }
            let frame = element.frame
            let bar = app.buttons.matching(identifier: "recordCreate.step3.complete").firstMatch
            let ceiling = (pinned.contains(element.identifier) || !bar.exists)
                ? window.maxY : min(window.maxY, bar.frame.minY)
            if element.isHittable, frame.minY >= window.minY, frame.maxY <= ceiling { return element }
            if frame.maxY > ceiling { app.swipeUp() } else { app.swipeDown() }
        }
        return element
    }

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
        let done = app.buttons.matching(identifier: "recordCreate.step3.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
    }

    /// 스테이징 흐름을 열고 1·2단계를 지나 3단계까지 간다.
    @discardableResult
    private func launchStep3(accessibilitySize: Bool = false, fillsStep1: Bool = true,
                             viaSkip: Bool = false, photoFixture: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", "fresh"]
        if let photoFixture {
            arguments += ["-VFUITestRecordCreateStagedPhotos", photoFixture]
        }
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        if fillsStep1 {
            choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
            choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
            scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        }
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        let onward = viaSkip ? "recordCreate.step2.skip" : "recordCreate.step2.next"
        scrollIntoView(app, node(app, onward)).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
        return app
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

    // MARK: - 좁은 폭

    func testCompact01_everyStep3ControlStaysInsideTheViewport() throws {
        let app = launchStep3()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.progress", "recordCreate.step3.title", "recordCreate.step3.subtitle",
                           "recordCreate.step3.addPhoto", "recordCreate.step3.moment",
                           "recordCreate.step3.mood.overwhelmed", "recordCreate.step3.mood.annoyed",
                           "recordCreate.step3.diary"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(identifier)이 왼쪽으로 잘렸다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(identifier)이 오른쪽으로 잘렸다")
        }
    }

    func testCompact02_everyActionRemainsReachable() throws {
        let app = launchStep3()
        let screen = try requireCompactWidth(app)
        for identifier in ["recordCreate.step3.complete", "recordCreate.back", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "\(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 잘렸다")
        }
    }

    func testCompact03_pageDoesNotScrollHorizontally() throws {
        let app = launchStep3()
        let screen = try requireCompactWidth(app)
        let root = node(app, "recordCreate.step3.root")
        let before = settled(root).minX
        root.swipeLeft()
        XCTAssertEqual(settled(root).minX, before, accuracy: 0.5, "가로로 스크롤됐다")
        XCTAssertLessThanOrEqual(settled(root).maxX, screen.maxX + 0.5)
    }

    func testCompact04_longMomentStaysReadable() throws {
        let app = launchStep3()
        let screen = try requireCompactWidth(app)
        let field = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        field.tap(); field.typeText("9회초 2사 만루에서 터진 박병호의 역전 스리런 홈런")
        dismissKeyboard(app)
        let frame = settled(node(app, "recordCreate.step3.moment"))
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "긴 순간이 가로로 잘렸다")
        XCTAssertGreaterThan(frame.height, 0)
    }

    func testCompact05_longDiaryStaysReachable() throws {
        let app = launchStep3()
        let screen = try requireCompactWidth(app)
        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        diary.typeText(String(repeating: "오늘은 정말 좋았다. ", count: 8))
        dismissKeyboard(app)
        let frame = settled(node(app, "recordCreate.step3.diary"))
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "긴 일기가 가로로 잘렸다")
        XCTAssertTrue(scrollIntoView(app, node(app, "recordCreate.step3.complete")).isHittable,
                      "긴 일기 뒤 완성 버튼에 닿을 수 없다")
    }

    // MARK: - 키보드

    func testKeyboard01_momentFieldStaysVisibleWhileTyping() throws {
        let app = launchStep3()
        _ = try requireCompactWidth(app)
        let field = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(settled(field).maxY, app.keyboards.element.frame.minY + 0.5, "순간 칸이 키보드에 가렸다")
        field.typeText("역전")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "역전")
    }

    func testKeyboard02_diaryKeyboardCanBeDismissedAndActionsReturn() throws {
        let app = launchStep3()
        _ = try requireCompactWidth(app)
        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(settled(diary).minY, app.keyboards.element.frame.minY, "일기 칸이 키보드 아래에 있다")
        let done = app.buttons.matching(identifier: "recordCreate.step3.keyboardDone").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "키보드를 빠져나갈 길이 없다")
        done.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 8), "키보드가 내려가지 않았다")
        XCTAssertTrue(scrollIntoView(app, node(app, "recordCreate.step3.complete")).isHittable,
                      "키보드를 내린 뒤 완성에 닿을 수 없다")
    }

    // MARK: - AccessibilityXXXL

    private func baselineHeight(of identifier: String) -> CGFloat {
        let normal = launchStep3()
        let height = settled(scrollIntoView(normal, node(normal, identifier))).height
        normal.terminate()
        return height
    }

    func testAccessibilityXXXL01_categoryActuallyApplies() {
        let baseline = baselineHeight(of: "recordCreate.step3.title")
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = launchStep3(accessibilitySize: true)
        let title = settled(scrollIntoView(app, node(app, "recordCreate.step3.title")))
        XCTAssertGreaterThan(title.height, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt")
    }

    func testAccessibilityXXXL02_everyControlStaysInsideTheViewport() {
        let app = launchStep3(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.progress", "recordCreate.step3.title", "recordCreate.step3.subtitle",
                           "recordCreate.step3.addPhoto", "recordCreate.step3.moment",
                           "recordCreate.step3.mood.overwhelmed", "recordCreate.step3.diary"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL03_actionsAndCancelRemainReachable() {
        let app = launchStep3(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.step3.complete", "recordCreate.back", "recordCreate.cancel"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists && element.isHittable, "큰 글자에서 \(identifier)에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(element).maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
    }

    func testAccessibilityXXXL04_moodSelectionStillWorks() {
        let app = launchStep3(accessibilitySize: true)
        let chip = scrollIntoView(app, button(app, "recordCreate.step3.mood.proud"))
        chip.tap()
        XCTAssertTrue(button(app, "recordCreate.step3.mood.proud").isSelected,
                      "큰 글자에서 기분 선택 상태가 전해지지 않는다")
    }

    func testAccessibilityXXXL05_progressStillReadsAsOneSentence() {
        let app = launchStep3(accessibilitySize: true)
        let progress = node(app, "recordCreate.progress")
        XCTAssertTrue(waits(progress), "진행 표시가 없다")
        XCTAssertEqual(progress.label, "3단계 중 3단계, 나의 이야기")
        XCTAssertLessThanOrEqual(settled(progress).maxX, app.windows.firstMatch.frame.maxX + 0.5,
                                 "진행 표시가 가로로 잘렸다")
    }
}
