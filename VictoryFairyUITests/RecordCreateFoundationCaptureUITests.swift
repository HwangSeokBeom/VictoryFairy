import XCTest

/// Record Create 기반 패스의 시각 회귀 증거를 남긴다.
///
/// 이 매트릭스가 증명하는 것은 **지금의 한 장짜리 폼이 그대로다**는 것이지,
/// 앞으로 만들 Pencil Step 1~3과 같다는 것이 아니다.
///
/// 저장 위치는 `VF_CAPTURE_DIR`, 파일 앞의 기기 꼬리표는 `VF_CAPTURE_TAG`로 정하고
/// 없으면 기본 임시 폴더에 남긴다. 저장소 안에는 쓰지 않는다.
final class RecordCreateFoundationCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-record-create-foundation-captures"
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

    /// 부분 일치. 화면 뒤에 남아 있는 발표 화면의 글자까지 잡을 수 있으므로,
    /// 편집기 안의 라벨을 찾을 때는 아래 `exactText`를 쓴다.
    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 편집기 안에서 정확히 일치하는 라벨.
    ///
    /// 시트가 떠 있어도 뒤 화면의 요소가 트리에 남는다 — "구장"이 홈의
    /// "주 관람 구장"에, "사진"이 캘린더의 보기 탭에 잡힌다. 나중에 얹힌 시트의
    /// 요소가 트리에서도 뒤에 오므로 **마지막** 일치를 고른다. 컨테이너를 잡아 두면
    /// 스크롤 뒤에 참조가 낡아 버리므로 앱 범위로 질의한다.
    private func exactText(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let matches = app.staticTexts.matching(NSPredicate(format: "label == %@", label))
        let count = matches.count
        return count > 0 ? matches.element(boundBy: count - 1) : matches.firstMatch
    }

    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 25) -> XCUIElement {
        guard waits(element) else { return element }
        for _ in 0..<maximumSwipes where !element.isHittable { app.swipeUp() }
        return element
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
        return app
    }

    /// 편집기가 실제로 열렸고 마법사가 없다는 것을 확인한 뒤에만 찍는다.
    private func assertEditorReadyForCapture(_ app: XCUIApplication, editing: Bool,
                                             file: StaticString = #filePath, line: UInt = #line) {
        let title = editing ? "직관 기록 수정" : "직관 기록 추가"
        XCTAssertTrue(waits(app.staticTexts[title].firstMatch),
                      "편집기가 열리지 않아 찍을 것이 없다 (\(title))", file: file, line: line)
        XCTAssertTrue(waits(exactText(app, "필수 정보")), "현재 폼이 아니다", file: file, line: line)
        for forbidden in ["다음 · 그날의 디테일", "이 단계는 건너뛸게요", "여기까지만 저장할게요",
                          "기록 완성하기", "임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500"] {
            XCTAssertFalse(text(app, forbidden).exists,
                           "\(forbidden)이 화면에 있다 — 찍으면 안 되는 상태다", file: file, line: line)
        }
    }

    /// 시트를 실제 사용자 동작으로 내린다.
    ///
    /// 화면 가운데에서 아래로 쓸면 편집기 `ScrollView`가 제스처를 먹는다(측정으로
    /// 확인했다). 내비게이션 바는 스크롤 뷰 밖이라 언제나 시트를 잡는다.
    private func dismissSheetFromNavigationBar(_ app: XCUIApplication) {
        if app.keyboards.element.exists {
            app.swipeDown()
            _ = app.keyboards.element.waitForNonExistence(timeout: 4)
        }
        // `firstMatch`는 시트 **뒤에 깔린** 화면의 막대를 집을 수 있다(측정으로 확인:
        // 구장별 통계 상세 위에서 편집기를 열면 "구장별 통계" 막대가 먼저 잡혀
        // 드래그가 시트에 닿지 않는다). 편집기 제목을 가진 막대를 먼저 찾고,
        // 없으면 트리에서 가장 나중에 얹힌 막대를 쓴다.
        let bars = app.navigationBars
        XCTAssertTrue(waits(bars.firstMatch), "시트의 내비게이션 바를 찾지 못했다")
        let titled = bars.matching(NSPredicate(
            format: "identifier == %@ OR identifier == %@", "직관 기록 추가", "직관 기록 수정")).firstMatch
        let bar = titled.exists ? titled : bars.element(boundBy: max(bars.count - 1, 0))
        XCTAssertTrue(bar.exists, "시트의 내비게이션 바를 찾지 못했다")
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 22))
        start.press(forDuration: 0.1, thenDragTo: end)
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

    // MARK: - 진입 경로

    private func homeApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "home"], accessibilitySize: accessibilitySize)
    }

    private func feedApp(_ fixture: String = "populated", accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", fixture],
               accessibilitySize: accessibilitySize)
    }

    private func calendarApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "calendar", "-VFUITestCalendarFixture", "selectedEmptyDate"],
               accessibilitySize: accessibilitySize)
    }

    private func openFeedCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")))
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertEditorReadyForCapture(app, editing: false)
    }

    private func openRecordDetailEdit(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(record), "피드에 기록이 없다")
        record.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")))
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorReadyForCapture(app, editing: true)
    }

    // MARK: - 1~5 진입 경로 캡처

    func testCapture01to05_entryRoutes() {
        let home = homeApp()
        XCTAssertTrue(waits(node(home, "screen.home")))
        scrollIntoView(home, node(home, "home.recordCTA")).tap()
        assertEditorReadyForCapture(home, editing: false)
        capture("01-home-standard-create")
        home.terminate()

        let feed = feedApp()
        openFeedCreate(feed)
        capture("03-feed-create")
        feed.terminate()

        let calendar = calendarApp()
        XCTAssertTrue(waits(node(calendar, "calendar.scenario.selectedEmptyDate")))
        scrollIntoView(calendar, node(calendar, "calendar.detailAddRecord")).tap()
        assertEditorReadyForCapture(calendar, editing: false)
        capture("04-calendar-create-initialDate")
        calendar.terminate()

        let detail = feedApp()
        openRecordDetailEdit(detail)
        capture("05-recordDetail-edit")
    }

    /// 홈 AI 진입. 최근 기록이 있으면 수정 모드, 없으면 생성 모드로 같은 편집기가 열린다.
    func testCapture02_homeAIPreflightEntry() {
        // 홈 대시보드에 최근 기록이 있어야 승리요정 지수 카드와 AI 도우미가 나온다.
        let app = launch(["-VFUITestInitialTab", "home", "-VFUITestFeedFixture", "populated"])
        XCTAssertTrue(waits(node(app, "home.root")), "홈이 뜨지 않았다")

        // 지연 생성되는 실제 제품 버튼. 먼저 스크롤로 올린 뒤에 찾는다.
        let aiButton = app.buttons["AI 직관 기록 도우미"]
        for _ in 0..<12 { if aiButton.exists, aiButton.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(aiButton.exists, "AI 도우미 버튼이 나타나지 않았다")
        XCTAssertTrue(aiButton.isHittable, "AI 도우미 버튼을 누를 수 없다")
        aiButton.tap()

        XCTAssertTrue(waits(text(app, "AI가 직관 기록을 정리해드릴게요")), "AI 도우미 시트가 없다")
        let startDraft = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                        "후기 초안 만들기", "최근 직관 다듬기")).firstMatch
        XCTAssertTrue(waits(startDraft), "최근 기록용 초안 버튼이 없다")
        startDraft.tap()

        // 최근 기록을 다듬는 경로이므로 수정 모드다.
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch), "수정 모드로 열리지 않았다")
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 수정").count, 1, "편집기가 둘이다")
        // `startsAIPreflightOnAppear`가 살아 있으면 사전 고지가 스스로 올라온다.
        XCTAssertTrue(waits(text(app, "AI"), 10), "AI 사전 고지가 뜨지 않았다")
        for forbidden in ["다음 · 그날의 디테일", "임시저장", "기록 완성하기", "0 / 500",
                          "날씨", "먹은 것", "응원 준비물"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 생겼다")
        }
        capture("02-home-ai-preflight-edit")
    }

    // MARK: - 6~7 편집 상태

    func testCapture06and07_editValuesAndPhoto() {
        let app = feedApp()
        openRecordDetailEdit(app)
        scrollIntoView(app, app.textFields["좌석"].firstMatch)
        capture("06-edit-seat-and-companion")
        scrollIntoView(app, exactText(app, "사진"))
        capture("07-edit-existing-photo")
    }

    // MARK: - 8~11 기능 진입면

    func testCapture08to11_featureSurfaces() {
        let ocr = feedApp()
        openFeedCreate(ocr)
        scrollIntoView(ocr, ocr.buttons["티켓으로 작성하기"].firstMatch).tap()
        _ = waits(ocr.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "티켓")).firstMatch, 8)
        capture("08-ticketOCR-entry")
        ocr.terminate()

        let photo = feedApp()
        openRecordDetailEdit(photo)
        scrollIntoView(photo, exactText(photo, "사진"))
        capture("09-photoAnalysis-entry")
        photo.terminate()

        let ai = feedApp()
        openFeedCreate(ai)
        scrollIntoView(ai, ai.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "AI로 후기 초안 만들기")).firstMatch)
        capture("10-aiDiary-entry")
        ai.terminate()

        // 경기 추천 자리. 서버가 없으면 "가져오지 못했어요" 안내까지가 현재 동작이다.
        let kbo = feedApp()
        openFeedCreate(kbo)
        scrollIntoView(kbo, exactText(kbo, "경기 날짜"))
        capture("11-kboSuggestion-entry")
    }

    // MARK: - 12 긴 일기

    func testCapture12_longDiary() {
        let app = feedApp("longContent")
        openRecordDetailEdit(app)
        scrollIntoView(app, exactText(app, "직관 다이어리"))
        capture("12-long-diary")
    }

    // MARK: - 13~14 좁은 폭 (SE3에서 실행할 때만 뜻이 있다)

    /// 좁은 폭 두 장. SE 3에서 돌릴 때만 뜻이 있다.
    func testCapture13and14_compactAndKeyboard() {
        let app = feedApp()
        let width = app.windows.firstMatch.frame.width
        openFeedCreate(app)
        // 현재 폼이 실제로 보이는지 확인한 뒤 찍는다.
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
        app.swipeDown(); app.swipeDown()
        XCTAssertFalse(app.keyboards.element.exists, "키보드가 떠 있는 채로 13번을 찍으려 한다")
        capture("13-compact-width")

        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(seat.frame.maxY, app.keyboards.element.frame.minY + 0.5,
                          "입력 필드가 키보드에 가렸다")
        seat.typeText("좁은폭")
        capture("14-compact-keyboard")
        XCTAssertTrue((seat.value as? String ?? "").contains("좁은폭"), "입력이 남지 않았다")
        if app.buttons["Return"].exists { app.buttons["Return"].tap() } else { app.swipeDown() }
        print("CAPTURE_WIDTH \(width)")
    }

    // MARK: - 15 큰 글자

    func testCapture15_accessibilityXXXL() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        capture("15-accessibilityXXXL")
    }

    // MARK: - 16~17 저장 안내

    func testCapture16and17_saveValidationAndSaveOutcome() {
        let invalid = feedApp()
        openFeedCreate(invalid)
        scrollIntoView(invalid, invalid.buttons["저장하기"].firstMatch).tap()
        let warning = invalid.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(invalid, warning)
        capture("16-save-validation-error")
        invalid.terminate()

        // 저장 실패 표현: UI 테스트에는 서버가 없으므로 저장은 언제나 기존 오프라인
        // 경로(로컬 저장 + 동기화 실패)로 간다. 이것이 지금 제품이 가진 유일한
        // 결정적 저장 실패 경로다. 새 실패 스위치를 만들지 않는다.
        let saving = feedApp()
        openRecordDetailEdit(saving)
        scrollIntoView(saving, saving.buttons["저장하기"].firstMatch).tap()
        // 저장 뒤에는 편집기가 닫히고 원래 화면으로 돌아온다.
        XCTAssertTrue(waits(node(saving, "recordDetail.root"), 15), "저장 뒤 상세로 돌아오지 못했다")
        capture("17-save-serverSyncFailure-localFallback")
    }

    // MARK: - 18 취소

    func testCapture18_cancellationPreservesTheRecord() {
        let app = feedApp()
        openRecordDetailEdit(app)

        // 원본 값을 기억한다.
        let seatField = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        let originalSeat = seatField.value as? String ?? ""
        XCTAssertFalse(originalSeat.isEmpty, "원본 좌석이 비어 있어 비교할 수 없다")

        // 지속되는 초안 값을 바꾸고, 폼을 맨 위에서 떨어뜨린다.
        seatField.tap()
        seatField.typeText("취소확인")
        if app.buttons["Return"].exists { app.buttons["Return"].tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        app.swipeUp()
        app.swipeUp()

        dismissSheetFromNavigationBar(app)

        XCTAssertTrue(app.staticTexts["직관 기록 수정"].waitForNonExistence(timeout: 10),
                      "실제 이탈 동작으로 편집기를 닫지 못했다")
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "취소 후 상세로 돌아오지 못했다")
        XCTAssertFalse(text(app, "취소확인").exists, "취소했는데 원본이 바뀌었다")
        capture("18-cancellation-return-state")

        // 다시 열면 원래 값이 그대로다.
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorReadyForCapture(app, editing: true)
        let reopened = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertEqual(reopened.value as? String ?? "", originalSeat, "취소한 값이 다시 살아났다")
        dismissSheetFromNavigationBar(app)
        XCTAssertTrue(waits(node(app, "recordDetail.root")))
    }
}
