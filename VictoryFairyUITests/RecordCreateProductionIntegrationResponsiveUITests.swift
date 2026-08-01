import XCTest

/// 제품 경로로 열린 세 단계 흐름의 좁은 폭·키보드·큰 글자 동작.
///
/// 검증용 스테이징 호스트를 쓰지 않는다. 다섯 경로 모두 사용자가 누르는 버튼에서
/// 시작하고, 좁은 폭 검증은 `VF-CalendarCompact-SE3`에서만 뜻이 있으므로 그 밖의
/// 기기에서는 명시적으로 건너뛴다(같은 이름의 짝이 SE 3에서 실제로 돈다).
final class RecordCreateProductionIntegrationResponsiveUITests: XCTestCase {

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

    /// 세로 스크롤을 **화면 왼쪽 가장자리**에서 끈다.
    ///
    /// 화면 가운데에서 쓸면 3단계 일기 칸(`TextEditor`)이 제스처를 먹어 바깥
    /// 스크롤이 움직이지 않는다(실측: 일기 아래의 `AI 초안`에 영원히 닿지 못했다).
    /// 가로 여백은 본문 밖이라 언제나 바깥 스크롤이 받는다.
    private func edgeSwipe(_ app: XCUIApplication, up: Bool) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.75 : 0.3))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.3 : 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// 아래에 고정된 액션 막대 밑에 깔린 요소도 XCUI는 `isHittable`로 본다(실측).
    /// 그래서 닿을 수 있는지만 묻지 않고, **그 막대 위에 담겨 있는지**까지 본다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        let pinned = ["recordCreate.step3.complete", "recordCreate.step2.next",
                      "recordCreate.step2.skip", "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<16 {
            guard element.exists else { edgeSwipe(app, up: true); continue }
            // 방금 끈 스크롤이 아직 멈추지 않았으면 XCUI는 보이는 요소도
            // `isHittable`이 아니라고 답한다. 재기 전에 가라앉기를 기다린다.
            usleep(250_000)
            let frame = element.frame
            let bar = app.buttons.matching(identifier: "recordCreate.step3.complete").firstMatch
            let ceiling = (pinned.contains(element.identifier) || !bar.exists)
                ? window.maxY : min(window.maxY, bar.frame.minY)
            if element.isHittable, frame.minY >= window.minY, frame.maxY <= ceiling { return element }
            edgeSwipe(app, up: frame.maxY > ceiling)
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

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recordCreate.scenario."))
            .firstMatch.exists, "스테이징 픽스처로 열렸다 — 제품 경로가 아니다")
        return app
    }

    private func requireCompactWidth(_ app: XCUIApplication) throws -> CGRect {
        let screen = app.windows.firstMatch.frame
        guard screen.width <= 380 else {
            throw XCTSkip("좁은 폭 검증은 375pt급 기기에서만 유효하다. 현재 폭 \(screen.width)pt")
        }
        return screen
    }

    private func assertFlowOpened(_ app: XCUIApplication, origin: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다", file: file, line: line)
    }

    /// 다섯 개 제품 생성 경로를 하나의 이름으로 연다.
    private func openCreate(_ origin: String, accessibilitySize: Bool = false,
                            extra: [String] = []) -> XCUIApplication {
        switch origin {
        case "home":
            let app = launch(["-VFUITestInitialTab", "home"] + extra, accessibilitySize: accessibilitySize)
            XCTAssertTrue(waits(node(app, "screen.home")))
            scrollIntoView(app, node(app, "home.recordCTA")).tap()
            assertFlowOpened(app, origin: origin)
            return app
        case "feed":
            let app = launch(["-VFUITestInitialTab", "feed"] + extra, accessibilitySize: accessibilitySize)
            XCTAssertTrue(waits(node(app, "screen.feed")))
            scrollIntoView(app, node(app, "feed.addRecord")).tap()
            assertFlowOpened(app, origin: origin)
            return app
        case "calendar":
            let app = launch(["-VFUITestInitialTab", "calendar",
                              "-VFUITestCalendarFixture", "selectedEmptyDate"] + extra,
                             accessibilitySize: accessibilitySize)
            XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")))
            scrollIntoView(app, node(app, "calendar.detailAddRecord")).tap()
            assertFlowOpened(app, origin: origin)
            return app
        case "statisticsStadium", "statisticsOpponent":
            let fixture = origin == "statisticsStadium" ? "noStadium" : "noOpponent"
            let row = origin == "statisticsStadium"
                ? "statistics.highlight.mostVisitedStadium"
                : "statistics.highlight.mostFacedOpponent"
            let app = launch(["-VFUITestInitialTab", "statistics",
                              "-VFUITestStatisticsFixture", fixture] + extra,
                             accessibilitySize: accessibilitySize)
            XCTAssertTrue(waits(node(app, "statistics.scenario.\(fixture)")))
            scrollIntoView(app, node(app, row)).tap()
            scrollIntoView(app, app.buttons.matching(
                NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch).tap()
            assertFlowOpened(app, origin: origin)
            return app
        default:
            XCTFail("모르는 경로 \(origin)")
            return XCUIApplication()
        }
    }

    private func fillValidStep1(_ app: XCUIApplication, opponent: String = "KIA 타이거즈") {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: opponent)
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
    }

    private func gotoStep3(_ app: XCUIApplication, viaSkip: Bool = true) {
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        scrollIntoView(app, node(app, viaSkip ? "recordCreate.step2.skip" : "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
    }

    private func assertInside(_ app: XCUIApplication, _ element: XCUIElement, _ name: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame
        let frame = settled(element)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name)이 왼쪽으로 넘쳤다", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name)이 오른쪽으로 넘쳤다", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
    }

    // MARK: - 1~5. 다섯 경로의 1단계가 좁은 폭에서 온전한가

    private func assertStep1Compact(_ app: XCUIApplication,
                                    file: StaticString = #filePath, line: UInt = #line) {
        for identifier in ["recordCreate.progress", "recordCreate.step1.title",
                           "recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam",
                           "recordCreate.assist.ticketOCR", "recordCreate.assist.findGame",
                           "recordCreate.next", "recordCreate.saveMinimal"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "\(identifier)이 없다", file: file, line: line)
            assertInside(app, element, identifier, file: file, line: line)
        }
    }

    func testCompact01_homeCreateStepOneFitsTheNarrowScreen() throws {
        let app = openCreate("home")
        _ = try requireCompactWidth(app)
        assertStep1Compact(app)
    }

    func testCompact02_feedCreateStepOneFitsTheNarrowScreen() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        assertStep1Compact(app)
    }

    func testCompact03_calendarCreateStepOneFitsAndKeepsTheDate() throws {
        let app = openCreate("calendar")
        _ = try requireCompactWidth(app)
        assertStep1Compact(app)
        let field = scrollIntoView(app, node(app, "recordCreate.field.date"))
        var spoken = [field.label, field.value as? String ?? ""]
        let inner = field.descendants(matching: .any)
        for index in 0..<min(inner.count, 12) {
            spoken.append(inner.element(boundBy: index).label)
            spoken.append(inner.element(boundBy: index).value as? String ?? "")
        }
        XCTAssertNotNil(spoken.joined(separator: " ").range(of: "4[^0-9]{0,3}20", options: .regularExpression),
                        "좁은 폭에서 캘린더 날짜가 사라졌다")
    }

    func testCompact04_statisticsStadiumCreateStepOneFitsTheNarrowScreen() throws {
        let app = openCreate("statisticsStadium")
        _ = try requireCompactWidth(app)
        assertStep1Compact(app)
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.stadium")).value as? String ?? "",
                       "선택하지 않음", "구장을 지어냈다")
    }

    func testCompact05_statisticsOpponentCreateStepOneFitsTheNarrowScreen() throws {
        let app = openCreate("statisticsOpponent")
        _ = try requireCompactWidth(app)
        assertStep1Compact(app)
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.opponentTeam")).value as? String ?? "",
                       "선택하지 않음", "상대팀을 지어냈다")
    }

    // MARK: - 6~10. 좁은 폭의 각 상태

    func testCompact06_stepOneValidationStaysReachable() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let message = scrollIntoView(app, node(app, "recordCreate.validationMessage"))
        XCTAssertTrue(message.exists, "좁은 폭에서 검증 안내가 사라졌다")
        assertInside(app, message, "검증 안내")
    }

    func testCompact07_stepOneAssistanceStaysReachableAndAnswers() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        scrollIntoView(app, node(app, "recordCreate.assist.findGame")).tap()
        let status = node(app, "recordCreate.assist.lookupStatus")
        XCTAssertTrue(waits(status, 20), "경기 찾기가 결과를 말하지 않는다")
        assertInside(app, scrollIntoView(app, status), "찾기 결과")
    }

    func testCompact08_stepTwoKeyboardKeepsTheFieldVisible() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))

        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        seat.typeText("3루 내야 지정석 K열 24번")
        XCTAssertLessThan(settled(seat).maxY, settled(app.keyboards.element).minY + 0.5,
                          "입력 중인 좌석 칸이 키보드에 가렸다")
        node(app, "recordCreate.step2.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        XCTAssertTrue((node(app, "recordCreate.field.seat").value as? String ?? "").contains("3루"),
                      "키보드를 내리자 입력이 사라졌다")
    }

    func testCompact09_stepThreeDiaryKeyboardKeepsTheFieldVisible() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        fillValidStep1(app)
        gotoStep3(app)

        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        diary.typeText("좁은 폭에서 쓴 일기")
        XCTAssertLessThan(settled(diary).minY, settled(app.keyboards.element).minY,
                          "일기 칸이 통째로 키보드에 가렸다")
        node(app, "recordCreate.step3.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        assertInside(app, scrollIntoView(app, node(app, "recordCreate.step3.complete")), "기록 완성하기")
    }

    func testCompact10_stepThreeAssistanceStaysReachableWithAPhoto() throws {
        let app = openCreate("feed", extra: ["-VFUITestRecordCreateStagedPhotos", "one"])
        _ = try requireCompactWidth(app)
        fillValidStep1(app)
        gotoStep3(app)

        assertInside(app, scrollIntoView(app, node(app, "recordCreate.step3.analyzePhotos")), "사진 분석")
        assertInside(app, scrollIntoView(app, node(app, "recordCreate.step3.aiDraft")), "AI 초안")
        XCTAssertTrue(node(app, "recordCreate.step3.removePhoto.1").exists, "심어 둔 사진이 없다")
    }

    // MARK: - 11~12. 좁은 폭의 저장과 취소

    func testCompact11_minimalSaveWorksOnTheNarrowScreen() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        // 저장소는 같은 경기끼리 기록을 합친다. 그래서 이 시험만의 상대팀을 쓰고
        // 셀 때도 그 대진으로 좁힌다.
        fillValidStep1(app, opponent: "NC 다이노스")
        scrollIntoView(app, node(app, "recordCreate.saveMinimal")).tap()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 20),
                      "좁은 폭에서 최소 저장이 닫히지 않았다")
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let saved = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                  "feed.record.", "NC")).count
        XCTAssertEqual(saved, 1, "좁은 폭에서 최소 저장이 기록을 하나 만들지 않았다")
    }

    func testCompact12_cancellationFromEveryStepWorksOnTheNarrowScreen() throws {
        let app = openCreate("feed")
        _ = try requireCompactWidth(app)
        for step in 0..<3 {
            if step > 0 {
                scrollIntoView(app, node(app, "feed.addRecord")).tap()
                assertFlowOpened(app, origin: "feed")
                fillValidStep1(app)
                scrollIntoView(app, node(app, "recordCreate.next")).tap()
                XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
                if step == 2 {
                    scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
                    XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
                }
            }
            let cancel = node(app, "recordCreate.cancel")
            XCTAssertTrue(cancel.isHittable, "\(step + 1)단계에서 취소를 누를 수 없다")
            cancel.tap()
            XCTAssertTrue(waits(node(app, "screen.feed")), "\(step + 1)단계 취소가 피드로 돌아오지 않았다")
        }
    }

    // MARK: - 13~16. AccessibilityXXXL

    /// 큰 글자가 실제로 적용됐는지. 기본 크기의 같은 요소와 견준다.
    private func defaultStep1TitleHeight() -> CGFloat {
        let app = openCreate("feed")
        let height = settled(node(app, "recordCreate.step1.title")).height
        app.terminate()
        return height
    }

    func testAccessibility01_theCategoryActuallyApplies() {
        let baseline = defaultStep1TitleHeight()
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = openCreate("feed", accessibilitySize: true)
        let large = settled(node(app, "recordCreate.step1.title")).height
        XCTAssertGreaterThan(large, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt vs 현재 \(large)pt")
    }

    func testAccessibility02_stepOneStaysUsableFromAProductionRoute() {
        let app = openCreate("home", accessibilitySize: true)
        assertStep1Compact(app)
        // 진행 표시가 한 문장으로 읽힌다.
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 1단계, 경기",
                       "큰 글자에서 진행 표시가 달라졌다")
    }

    func testAccessibility03_everyStepAnnouncesItsPositionAndStaysUsable() {
        let app = openCreate("feed", accessibilitySize: true,
                             extra: ["-VFUITestRecordCreateStagedPhotos", "one"])
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 1단계, 경기")
        fillValidStep1(app)

        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 2단계, 그날의 디테일")
        // 뒤로와 취소가 서로 다른 이름으로, 둘 다 닿는다.
        XCTAssertTrue(node(app, "recordCreate.back").isHittable, "큰 글자에서 이전을 누를 수 없다")
        XCTAssertTrue(node(app, "recordCreate.cancel").isHittable, "큰 글자에서 취소를 누를 수 없다")
        XCTAssertNotEqual(node(app, "recordCreate.back").label, node(app, "recordCreate.cancel").label,
                          "이전과 취소가 같은 이름으로 읽힌다")

        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 3단계, 나의 이야기")
        for identifier in ["recordCreate.step3.moment", "recordCreate.step3.diary",
                           "recordCreate.step3.analyzePhotos", "recordCreate.step3.aiDraft",
                           "recordCreate.step3.complete"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(element.exists, "큰 글자에서 \(identifier)이 사라졌다")
            assertInside(app, element, identifier)
        }
    }

    func testAccessibility04_noInternalNameOrPathIsSpoken() {
        let app = openCreate("feed", accessibilitySize: true,
                             extra: ["-VFUITestRecordCreateStagedPhotos", "one"])
        fillValidStep1(app)
        gotoStep3(app)
        for internalName in ["RecordEditorDraft", "RecordCreateStep", "RecordEditorField",
                             "RecordCreateLaunchContext", "RecordEditorAssistance",
                             "photoLocalRefs", "linkedKBOGameID", "appliedHighlightTags",
                             "file://", "/Documents/", "statisticsStadium"] {
            XCTAssertFalse(text(app, internalName).exists, "내부 이름 \(internalName)이 읽힌다")
        }
        // 도움 동작은 이해할 수 있는 한국어로 읽힌다.
        XCTAssertEqual(node(app, "recordCreate.step3.analyzePhotos").label, "사진 분석")
        XCTAssertEqual(node(app, "recordCreate.step3.aiDraft").label, "AI 초안")
    }
}
