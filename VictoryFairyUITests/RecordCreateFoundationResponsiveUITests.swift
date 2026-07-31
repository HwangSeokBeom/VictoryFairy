import XCTest

/// 좁은 폭(375pt)·소프트 키보드·실제 AccessibilityXXXL에서 **지금의 한 장짜리
/// 기록 편집기**가 그대로 쓸 수 있는지 잰다.
///
/// 이 패스는 세 단계 마법사를 만들지 않는다. 그래서 여기서 확인하는 것은
/// "Pencil Step 1~3과 같은가"가 아니라 "현재 폼이 망가지지 않았는가"다.
///
/// 편집기에는 접근성 식별자가 없다(감사 결과). 화면에 실제로 보이는 문구로 찾고,
/// 존재만으로 통과시키지 않는다 — 스크롤해서 눈에 들어오고 누를 수 있는지까지 잰다.
final class RecordCreateFoundationResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 기기 조건

    /// 좁은 폭 기기에서만 뜻이 있는 검사인지. 넓은 기기에서는 통과로 위장하지 않고
    /// 건너뛴다. 대응하는 검사는 SE3에서 실제로 돌아 통과한다.
    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = app.windows.firstMatch.frame.width
        guard width <= 390 else {
            throw XCTSkip("좁은 폭 검사는 375pt급 기기에서만 뜻이 있다 (현재 \(width)pt)")
        }
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

    /// 자리를 잡은 뒤의 좌표. 애니메이션 중의 값은 재지 않는다.
    private func settled(_ element: XCUIElement,
                         file: StaticString = #filePath, line: UInt = #line) -> CGRect {
        XCTAssertTrue(waits(element), "요소가 나타나지 않아 좌표를 잴 수 없다", file: file, line: line)
        var previous = element.frame
        for _ in 0..<25 {
            usleep(120_000)
            let current = element.frame
            if current == previous { return current }
            previous = current
        }
        return previous
    }

    /// 화면 안으로 끌어와 실제로 누를 수 있는지까지 확인한다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 25,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)
        // AccessibilityXXXL에서는 폼 전체가 2,300pt를 넘는다. 넉넉히 밀어 본다.
        for _ in 0..<maximumSwipes where !element.isHittable {
            app.swipeUp()
        }
        // 지나쳤으면 위로 되돌린다.
        if !element.isHittable, element.frame.minY < 0 {
            for _ in 0..<maximumSwipes where !element.isHittable { app.swipeDown() }
        }
        XCTAssertTrue(
            element.isHittable,
            "스크롤해도 화면 안으로 들어오지 않는다 — label=\"\(element.label)\" frame=\(element.frame)",
            file: file, line: line
        )
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

    // MARK: - 진입 경로

    /// 편집기가 실제로 열렸는지. 제목과 현재 폼의 카드로 확인한다.
    @discardableResult
    private func assertEditorIsOpen(_ app: XCUIApplication, editing: Bool,
                                    file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let title = editing ? "직관 기록 수정" : "직관 기록 추가"
        let heading = app.staticTexts[title].firstMatch
        XCTAssertTrue(waits(heading), "편집기가 열리지 않았다 (\(title))", file: file, line: line)
        XCTAssertTrue(waits(exactText(app, "필수 정보")), "현재 폼의 필수 정보 카드가 없다", file: file, line: line)
        assertNoVisibleWizard(app, file: file, line: line)
        return heading
    }

    /// 보이는 마법사가 생기지 않았는지. 이 패스는 단계 화면을 만들지 않는다.
    private func assertNoVisibleWizard(_ app: XCUIApplication,
                                       file: StaticString = #filePath, line: UInt = #line) {
        for forbidden in ["다음 · 그날의 디테일", "다음 · 나의 이야기", "이 단계는 건너뛸게요",
                          "여기까지만 저장할게요", "기록 완성하기", "임시저장",
                          "날씨", "먹은 것", "응원 준비물", "오늘 직관, 몇 점이었나요?"] {
            XCTAssertFalse(text(app, forbidden).exists,
                           "보이는 단계/미지원 항목 \(forbidden)이 생겼다", file: file, line: line)
        }
        XCTAssertFalse(text(app, "0 / 500").exists, "500자 제한이 생겼다", file: file, line: line)
    }

    private func openHomeCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.home")), "홈에 들어가지 못했다")
        scrollIntoView(app, node(app, "home.recordCTA")).tap()
        assertEditorIsOpen(app, editing: false)
    }

    private func openFeedCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertEditorIsOpen(app, editing: false)
    }

    private func openCalendarCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더에 들어가지 못했다")
        scrollIntoView(app, node(app, "calendar.detailAddRecord")).tap()
        assertEditorIsOpen(app, editing: false)
    }

    private func openRecordDetailEdit(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        let firstRecord = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(firstRecord), "피드에 기록이 없다")
        firstRecord.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "기록 상세에 들어가지 못했다")
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorIsOpen(app, editing: true)
    }

    private func homeApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "home"], accessibilitySize: accessibilitySize)
    }

    private func feedApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"],
               accessibilitySize: accessibilitySize)
    }

    private func longContentFeedApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "longContent"],
               accessibilitySize: accessibilitySize)
    }

    private func calendarApp(accessibilitySize: Bool = false) -> XCUIApplication {
        launch(["-VFUITestInitialTab", "calendar", "-VFUITestCalendarFixture", "selectedEmptyDate"],
               accessibilitySize: accessibilitySize)
    }

    // MARK: - 현재 폼이 온전한지

    /// 카드·필드·저장까지 실제로 닿을 수 있는지 한 번에 잰다.
    ///
    /// 글자 라벨 대신 **컨트롤**로만 잰다. 시트가 떠 있어도 뒤 화면의 요소가 접근성
    /// 트리에 남아서, "경기 날짜"·"구장"·"사진" 같은 글자는 홈·피드·캘린더의 것과
    /// 섞인다(측정으로 확인했다). 편집기에만 있는 컨트롤은 그런 혼동이 없다.
    private func assertCurrentFormRemainsUsable(_ app: XCUIApplication,
                                                file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame

        func assertInsideScreen(_ element: XCUIElement, _ name: String) {
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name)이 왼쪽으로 넘쳤다", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name)이 오른쪽으로 넘쳤다", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "\(name)이 너비 0으로 접혔다", file: file, line: line)
        }

        // 필수 정보 카드의 컨트롤.
        let opponentMenu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "상대팀")).firstMatch
        assertInsideScreen(scrollIntoView(app, opponentMenu, file: file, line: line), "상대팀 메뉴")
        let stadiumMenu = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "구장")).firstMatch
        assertInsideScreen(scrollIntoView(app, stadiumMenu, file: file, line: line), "구장 메뉴")
        // 경기 결과 네 버튼.
        for result in ["승", "패", "무", "취소"] {
            let button = app.buttons[result].firstMatch
            assertInsideScreen(scrollIntoView(app, button, file: file, line: line), "결과 \(result)")
        }

        // 사진 카드 · 선택 정보 카드.
        let addPhoto = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "사진 추가")).firstMatch
        assertInsideScreen(scrollIntoView(app, addPhoto, file: file, line: line), "사진 추가")
        assertInsideScreen(scrollIntoView(app, app.textFields["좌석"].firstMatch, file: file, line: line), "좌석")
        assertInsideScreen(scrollIntoView(app, app.textFields["한 줄 메모"].firstMatch, file: file, line: line), "한 줄 메모")
        assertInsideScreen(scrollIntoView(app, app.textViews.firstMatch, file: file, line: line), "직관 다이어리")

        // 저장까지 닿는다.
        assertInsideScreen(scrollIntoView(app, app.buttons["저장하기"].firstMatch, file: file, line: line), "저장하기")
    }

    // MARK: - 좁은 폭

    func testCompact01_homeStandardCreateRemainsUsable() throws {
        let app = homeApp()
        try requireCompactWidth(app)
        openHomeCreate(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testCompact02_homeAIPreflightEntryRemainsUsable() throws {
        // 홈 대시보드에 최근 기록이 있어야 승리요정 지수 카드가 나온다.
        let app = launch(["-VFUITestInitialTab", "home", "-VFUITestFeedFixture", "populated"])
        try requireCompactWidth(app)
        XCTAssertTrue(waits(node(app, "home.root")))
        // 실제 컨트롤은 승리요정 지수 카드 안의 반짝 버튼이다. 지연 생성되므로
        // 먼저 스크롤로 올린 뒤에 찾는다.
        let aiButton = app.buttons["AI 직관 기록 도우미"]
        for _ in 0..<12 { if aiButton.exists, aiButton.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(aiButton.exists, "AI 도우미 버튼이 나타나지 않았다")
        aiButton.tap()
        // 최근 기록이 없으면 "첫 직관 기록하기", 있으면 초안 버튼이 나온다.
        let startDraft = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                        "후기 초안 만들기", "최근 직관 다듬기")
        ).firstMatch
        XCTAssertTrue(waits(startDraft), "AI 도우미 시트가 열리지 않았다")
        startDraft.tap()
        // 최근 기록을 다듬는 경로이므로 수정 모드다.
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch), "AI 진입에서 편집기가 열리지 않았다")
        assertNoVisibleWizard(app)
    }

    func testCompact03_feedCreateRemainsUsable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testCompact04_calendarCreateKeepsTheSelectedDate() throws {
        let app = calendarApp()
        try requireCompactWidth(app)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")), "픽스처가 적용되지 않았다")
        openCalendarCreate(app)
        // 캘린더가 정한 날짜가 편집기에 그대로 온다.
        XCTAssertTrue(scrollIntoView(app, exactText(app, "경기 날짜")).exists)
        assertCurrentFormRemainsUsable(app)
    }

    func testCompact05_recordDetailEditRemainsUsable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testCompact06_editKeepsSeatAndCompanion() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertFalse((seat.value as? String ?? "").isEmpty, "좌석이 비어 있다")
        scrollIntoView(app, exactText(app, "동행 유형"))
    }

    func testCompact07_editWithExistingPhotoKeepsPhotoControls() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        // 사진 수 표시와 추가 버튼이 살아 있다.
        XCTAssertTrue(text(app, "/10").exists, "사진 개수 표시가 사라졌다")
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "사진 추가")).firstMatch)
    }

    func testCompact08_longDiaryRemainsReachable() throws {
        let app = longContentFeedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
        scrollIntoView(app, exactText(app, "직관 다이어리"))
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
    }

    func testCompact09_saveValidationErrorRemainsReachable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch).tap()
        // 새 기록은 상대팀·구장·결과가 비어 있으므로 저장을 막는 안내가 뜬다.
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 편집기는 그대로 열려 있다.
        assertEditorIsOpen(app, editing: false)
    }

    func testCompact10_featureSurfacesRemainReachable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        // 티켓 OCR
        scrollIntoView(app, app.buttons["티켓으로 작성하기"].firstMatch)
        // 사진 첨부
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "사진 추가")).firstMatch)
        // AI 초안과 기본 문장
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "기본 문장으로 채우기")).firstMatch)
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "AI로 후기 초안 만들기")).firstMatch)
        // 서버 없이도 경기 추천 자리는 살아 있다(찾지 못했다는 안내까지 포함).
        XCTAssertTrue(app.buttons["티켓으로 작성하기"].exists, "OCR 진입이 사라졌다")
    }

    func testCompact11_cancellationReturnsToThePresentingScreen() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertFalse(app.staticTexts["직관 기록 추가"].exists, "편집기가 남아 있다")
    }

    func testCompact12_noDuplicateNavigationContainerAppears() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 추가").count, 1,
                       "내비게이션 제목이 둘이다 — 두 번째 NavigationStack이 생겼다")
        XCTAssertEqual(app.navigationBars.count, 1, "내비게이션 바가 둘이다")
    }

    // MARK: - 소프트 키보드

    func testKeyboard01_diaryStaysVisibleWhileTyping() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        seat.typeText("3루 내야 지정석 K열 24번")

        // 입력 중인 필드가 키보드에 가리지 않는다.
        let keyboardTop = settled(app.keyboards.element).minY
        XCTAssertLessThan(settled(seat).maxY, keyboardTop + 0.5, "입력 중인 필드가 키보드에 가렸다")

        // 키보드를 내릴 수 있고, 내리면 저장에 닿는다.
        if app.buttons["Return"].exists { app.buttons["Return"].tap() } else { app.swipeDown() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
        // 입력한 값이 살아 있다.
        XCTAssertTrue((scrollIntoView(app, app.textFields["좌석"].firstMatch).value as? String ?? "")
            .contains("3루"), "키보드를 내리자 입력이 사라졌다")
    }

    func testKeyboard02_validationErrorRemainsReachableWithTheKeyboardUp() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        let memo = scrollIntoView(app, app.textFields["한 줄 메모"].firstMatch)
        memo.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        memo.typeText("키보드 확인")
        if app.buttons["Return"].exists { app.buttons["Return"].tap() } else { app.swipeDown() }
        scrollIntoView(app, app.buttons["저장하기"].firstMatch).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 시트가 하나뿐이고 편집기 상태가 남아 있다.
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 추가").count, 1)
        XCTAssertTrue((app.textFields["한 줄 메모"].firstMatch.value as? String ?? "").contains("키보드 확인"),
                      "검증 뒤 입력이 사라졌다")
    }

    // MARK: - AccessibilityXXXL

    /// 큰 글자가 실제로 적용됐는지 증명한다.
    ///
    /// 기본 글자 크기에서 잰 같은 요소의 높이와 견주어, 적용되지 않았으면 실패한다.
    /// 이렇게 해야 "큰 글자에서 통과"가 사실이 된다.
    private func assertAccessibilityCategoryApplied(_ reference: XCUIElement, defaultHeight: CGFloat,
                                                    file: StaticString = #filePath, line: UInt = #line) {
        let large = settled(reference).height
        XCTAssertGreaterThan(large, defaultHeight * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(defaultHeight)pt vs 현재 \(large)pt",
                             file: file, line: line)
    }

    /// 기본 글자 크기에서 잰 "필수 정보" 제목 높이. 게이트의 기준값이다.
    private func defaultRequiredHeadingHeight() -> CGFloat {
        let app = feedApp()
        openFeedCreate(app)
        let height = settled(exactText(app, "필수 정보")).height
        app.terminate()
        return height
    }

    func testAccessibility01_runtimeGateProvesTheCategoryApplied() {
        let baseline = defaultRequiredHeadingHeight()
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        assertAccessibilityCategoryApplied(exactText(app, "필수 정보"), defaultHeight: baseline)
    }

    func testAccessibility02_homeCreateRemainsUsable() {
        let app = homeApp(accessibilitySize: true)
        openHomeCreate(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testAccessibility03_calendarCreateRemainsUsable() {
        let app = calendarApp(accessibilitySize: true)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")))
        openCalendarCreate(app)
        assertCurrentFormRemainsUsable(app)
    }

    func testAccessibility04_recordDetailEditKeepsSeatAndCompanion() {
        let app = feedApp(accessibilitySize: true)
        openRecordDetailEdit(app)
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertFalse((seat.value as? String ?? "").isEmpty, "큰 글자에서 좌석이 비었다")
        scrollIntoView(app, exactText(app, "동행 유형"))
    }

    func testAccessibility05_longDiaryGrowsAndStaysReachable() {
        let app = longContentFeedApp(accessibilitySize: true)
        openRecordDetailEdit(app)
        let diaryHeading = scrollIntoView(app, exactText(app, "직관 다이어리"))
        XCTAssertGreaterThan(settled(diaryHeading).height, 0)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch)
    }

    func testAccessibility06_validationErrorRemainsReachable() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        scrollIntoView(app, app.buttons["저장하기"].firstMatch).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 10), "큰 글자에서 검증 안내가 사라졌다")
        scrollIntoView(app, warning)
    }

    func testAccessibility07_featureSurfacesRemainReachable() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        scrollIntoView(app, app.buttons["티켓으로 작성하기"].firstMatch)
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "사진 추가")).firstMatch)
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "AI로 후기 초안 만들기")).firstMatch)
    }

    func testAccessibility08_keyboardStillLeavesTheFieldVisible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        let field = scrollIntoView(app, app.textFields["한 줄 메모"].firstMatch)
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 12), "큰 글자에서 키보드가 올라오지 않았다")
        let keyboardTop = settled(app.keyboards.element).minY
        XCTAssertLessThan(settled(field).maxY, keyboardTop + 0.5, "큰 글자에서 입력 필드가 키보드에 가렸다")
        if app.buttons["Return"].exists { app.buttons["Return"].tap() } else { app.swipeDown() }
    }

    func testAccessibility09_cancellationRemainsPossible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(waits(node(app, "screen.feed")), "큰 글자에서 편집기를 닫지 못했다")
    }

    func testAccessibility10_noInternalNameIsSpoken() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        for internalName in ["RecordEditorDraft", "RecordCreateStep", "RecordEditorField",
                             "RecordEditorMode", "LogEditorViewModel", "photoLocalRefs",
                             "linkedKBOGameID", "appliedHighlightTags"] {
            XCTAssertFalse(text(app, internalName).exists, "내부 이름 \(internalName)이 읽힌다")
        }
    }
}
