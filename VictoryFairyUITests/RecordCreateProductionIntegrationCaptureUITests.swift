import XCTest

/// 제품 통합의 시각 증거 18장.
///
/// 모든 캡처는 **실제 제품 진입 경로**를 먼저 확인한 뒤에 찍는다. 검증용 스테이징
/// 호스트(`-VFUITestRecordCreateStaged`)로는 한 장도 찍지 않는다.
final class RecordCreateProductionIntegrationCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-record-create-production-integration-captures"
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

    /// 세로 스크롤을 **화면 왼쪽 가장자리**에서 끈다.
    ///
    /// 화면 가운데에서 쓸면 3단계 일기 칸(`TextEditor`)이 제스처를 먹어 바깥
    /// 스크롤이 움직이지 않는다(실측). 가로 여백은 본문 밖이라 언제나 바깥 스크롤이 받는다.
    private func edgeSwipe(_ app: XCUIApplication, up: Bool) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.75 : 0.3))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.3 : 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

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

    /// 찍기 전에 언제나 확인하는 것: 어느 경로인지, 어떤 편집기인지, 없어야 할 것이 없는지.
    private func assertFlowReady(_ app: XCUIApplication, origin: String, step: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.\(step).root")), "\(step)이 아니다", file: file, line: line)
        XCTAssertFalse(app.staticTexts["필수 정보"].exists, "한 장짜리 폼이 떴다", file: file, line: line)
        assertNothingUnsupported(app, file: file, line: line)
    }

    private func assertEditorReady(_ app: XCUIApplication,
                                   file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch),
                      "수정 편집기가 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(app.staticTexts["필수 정보"].firstMatch), "한 장짜리 폼이 아니다", file: file, line: line)
        XCTAssertFalse(node(app, "recordCreate.step1.root").exists, "수정이 마법사로 갔다", file: file, line: line)
        assertNothingUnsupported(app, file: file, line: line)
    }

    private func assertNothingUnsupported(_ app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        for forbidden in ["임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500",
                          "몇 점이었나요", "별점", "테스트", "픽스처"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다", file: file, line: line)
        }
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

    private func openHomeCreate(_ extra: [String] = [], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestInitialTab", "home"] + extra, accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "screen.home")))
        scrollIntoView(app, node(app, "home.recordCTA")).tap()
        assertFlowReady(app, origin: "home", step: "step1")
        return app
    }

    private func openFeedCreate(_ extra: [String] = [], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestInitialTab", "feed"] + extra, accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "screen.feed")))
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertFlowReady(app, origin: "feed", step: "step1")
        return app
    }

    private func openRecordDetailEdit(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record.")).firstMatch
        XCTAssertTrue(waits(record), "피드에 기록이 없다")
        record.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")))
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorReady(app)
    }

    private func fillValidStep1(_ app: XCUIApplication) {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
    }

    private func gotoStep3(_ app: XCUIApplication) {
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
    }

    // MARK: - 1~5 다섯 개 생성 경로

    func testCapture01to05_productionCreateRoutes() {
        let home = openHomeCreate()
        capture("01-home-production-create-step1")
        home.terminate()

        let feed = openFeedCreate()
        capture("02-feed-production-create-step1")
        feed.terminate()

        let calendar = launch(["-VFUITestInitialTab", "calendar",
                               "-VFUITestCalendarFixture", "selectedEmptyDate"])
        XCTAssertTrue(waits(node(calendar, "calendar.scenario.selectedEmptyDate")))
        scrollIntoView(calendar, node(calendar, "calendar.detailAddRecord")).tap()
        assertFlowReady(calendar, origin: "calendar", step: "step1")
        let field = scrollIntoView(calendar, node(calendar, "recordCreate.field.date"))
        var spoken = [field.label, field.value as? String ?? ""]
        let inner = field.descendants(matching: .any)
        for index in 0..<min(inner.count, 12) {
            spoken.append(inner.element(boundBy: index).label)
            spoken.append(inner.element(boundBy: index).value as? String ?? "")
        }
        XCTAssertNotNil(spoken.joined(separator: " ").range(of: "4[^0-9]{0,3}20", options: .regularExpression),
                        "캘린더 날짜가 사라진 상태를 찍으려 한다")
        capture("03-calendar-production-create-suppliedDate")
        calendar.terminate()

        let stadium = launch(["-VFUITestInitialTab", "statistics",
                              "-VFUITestStatisticsFixture", "noStadium"])
        XCTAssertTrue(waits(node(stadium, "statistics.scenario.noStadium")))
        scrollIntoView(stadium, node(stadium, "statistics.highlight.mostVisitedStadium")).tap()
        scrollIntoView(stadium, stadium.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch).tap()
        assertFlowReady(stadium, origin: "statisticsStadium", step: "step1")
        XCTAssertEqual(scrollIntoView(stadium, node(stadium, "recordCreate.field.stadium")).value as? String ?? "",
                       "선택하지 않음", "구장을 지어낸 상태를 찍으려 한다")
        capture("04-statistics-stadium-production-create-noFabricatedStadium")
        stadium.terminate()

        let opponent = launch(["-VFUITestInitialTab", "statistics",
                               "-VFUITestStatisticsFixture", "noOpponent"])
        XCTAssertTrue(waits(node(opponent, "statistics.scenario.noOpponent")))
        scrollIntoView(opponent, node(opponent, "statistics.highlight.mostFacedOpponent")).tap()
        scrollIntoView(opponent, opponent.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch).tap()
        assertFlowReady(opponent, origin: "statisticsOpponent", step: "step1")
        XCTAssertEqual(scrollIntoView(opponent, node(opponent, "recordCreate.field.opponentTeam")).value as? String ?? "",
                       "선택하지 않음", "상대팀을 지어낸 상태를 찍으려 한다")
        capture("05-statistics-opponent-production-create-noFabricatedOpponent")
    }

    // MARK: - 6~7 1단계 도우미

    func testCapture06and07_stepOneAssistance() {
        let app = openFeedCreate()
        scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        XCTAssertTrue(node(app, "recordCreate.assist.ticketOCR").isHittable, "티켓 OCR에 닿을 수 없다")
        capture("06-step1-ticketOCR-access")

        scrollIntoView(app, node(app, "recordCreate.assist.findGame")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.assist.lookupStatus"), 20),
                      "경기 찾기가 결과를 말하지 않는다")
        scrollIntoView(app, node(app, "recordCreate.assist.lookupStatus"))
        capture("07-step1-kboSuggestion-access")
    }

    // MARK: - 8~9 2·3단계 제품 레이아웃

    func testCapture08and09_stepTwoAndStepThree() {
        let app = openFeedCreate()
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        assertNothingUnsupported(app)
        capture("08-step2-production-layout")

        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
        assertNothingUnsupported(app)
        // 고르지 않은 기분은 선택돼 보이지 않는다.
        for mood in ["overwhelmed", "happy", "proud", "regret", "annoyed"] {
            XCTAssertFalse(node(app, "recordCreate.step3.mood.\(mood)").isSelected,
                           "고르지 않은 \(mood)이 선택돼 보인다")
        }
        capture("09-step3-production-layout")
    }

    // MARK: - 10~11 3단계 도우미

    func testCapture10and11_stepThreeAssistance() {
        let app = openFeedCreate(["-VFUITestRecordCreateStagedPhotos", "one"])
        fillValidStep1(app)
        gotoStep3(app)

        let analyze = scrollIntoView(app, node(app, "recordCreate.step3.analyzePhotos"))
        XCTAssertTrue(analyze.isEnabled, "사진이 있는데 사진 분석을 쓸 수 없다")
        capture("10-step3-photoAnalysis-access")

        scrollIntoView(app, node(app, "recordCreate.step3.aiDraft"))
        XCTAssertTrue(node(app, "recordCreate.step3.aiDraft").isHittable, "AI 초안에 닿을 수 없다")
        capture("11-step3-aiDraft-access")
    }

    // MARK: - 12~13 저장 준비 상태

    func testCapture12and13_saveReadyStates() {
        let minimal = openFeedCreate()
        fillValidStep1(minimal)
        scrollIntoView(minimal, node(minimal, "recordCreate.saveMinimal"))
        capture("12-minimal-save-ready")
        minimal.terminate()

        let full = openFeedCreate()
        fillValidStep1(full)
        gotoStep3(full)
        node(full, "recordCreate.step3.mood.happy").tap()
        scrollIntoView(full, node(full, "recordCreate.step3.complete"))
        capture("13-full-completion-ready")
    }

    // MARK: - 14 막힌 완성

    /// 1단계가 비어 있는 채로 완성을 누르면 저장하지 않고 1단계로 되돌린다.
    ///
    /// 진입은 제품 경로(피드)다. 시작 위치만 DEBUG 인자로 옮겼다 — 그 상태는 제품
    /// 흐름으로 만들 수 없지만 마지막 버튼은 그래도 스스로 막아야 하기 때문이다.
    func testCapture14_invalidCompletionReturnsToStepOne() {
        let app = launch(["-VFUITestInitialTab", "feed",
                          "-VFUITestRecordCreateInitialStep", "memory"])
        XCTAssertTrue(waits(node(app, "screen.feed")))
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertFlowReady(app, origin: "feed", step: "step3")

        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "완성이 1단계로 되돌리지 않았다")
        let message = scrollIntoView(app, node(app, "recordCreate.validationMessage"))
        XCTAssertTrue(message.exists, "무엇이 빠졌는지 말하지 않는다")
        capture("14-invalid-completion-returned-to-step1")
    }

    // MARK: - 15 취소 뒤 돌아온 자리

    func testCapture15_cancellationReturnState() {
        let app = openFeedCreate()
        fillValidStep1(app)
        gotoStep3(app)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertFalse(node(app, "recordCreate.step3.root").exists, "흐름이 남아 있다")
        capture("15-cancellation-return-state")
    }

    // MARK: - 16~17 수정 두 경로는 그대로 지금 편집기다

    func testCapture16_homeAIPreflightEditRemainsTheCurrentEditor() {
        let app = launch(["-VFUITestInitialTab", "home", "-VFUITestFeedFixture", "populated"])
        XCTAssertTrue(waits(node(app, "home.root")))
        let aiButton = app.buttons["AI 직관 기록 도우미"]
        for _ in 0..<12 { if aiButton.exists, aiButton.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(aiButton.exists, "AI 도우미 버튼이 나타나지 않았다")
        aiButton.tap()
        let startDraft = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                        "후기 초안 만들기", "최근 직관 다듬기")).firstMatch
        XCTAssertTrue(waits(startDraft), "AI 도우미 시트가 열리지 않았다")
        startDraft.tap()
        assertEditorReady(app)
        capture("16-home-aiPreflight-edit-remains-logEditor")
    }

    func testCapture17_recordDetailEditRemainsTheCurrentEditor() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"])
        openRecordDetailEdit(app)
        scrollIntoView(app, app.textFields["좌석"].firstMatch)
        capture("17-recordDetail-edit-remains-logEditor")
    }

    // MARK: - 18 좁은 기기의 큰 글자

    /// SE 3에서 돌릴 때만 뜻이 있다. 그 밖의 기기에서는 폭을 함께 남긴다.
    func testCapture18_compactAccessibilityXXXL() {
        let app = openFeedCreate(accessibilitySize: true)
        let width = app.windows.firstMatch.frame.width
        scrollIntoView(app, node(app, "recordCreate.next"))
        capture("18-compact-accessibilityXXXL-step1")
        print("CAPTURE_WIDTH \(width)")
    }
}
