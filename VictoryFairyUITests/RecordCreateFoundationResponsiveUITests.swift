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

    /// 실제로 쓸 수 있는 구간 — 위쪽 고정 크롬 **아래**, 아래쪽 액션 영역 **위**.
    ///
    /// 창 안에 있다는 것만으로는 쓸 수 있다는 뜻이 아니다. 편집기의 내비게이션 막대는
    /// 창 위쪽을 덮고 있는데, 그 밑에 깔린 요소도 XCUI는 `isHittable`이라고 답한다
    /// (실측: 좌석 칸이 y 31–53에 서 있고 `직관 기록 수정` 막대가 y 46–100을 덮은
    /// 상태에서, 탭이 막대에 먹혀 키보드가 끝내 올라오지 않았다).
    ///
    /// 아래쪽 액션 영역은 **있을 수도 없을 수도 있다.** 없는 것이 맞는 배치이므로,
    /// `exists`를 먼저 묻고 있을 때만 `frame`을 읽는다 — 없는 요소의 `frame`을 읽으면
    /// XCUI가 스냅샷 오류를 던져 진짜 원인을 통째로 가린다.
    private func usableViewport(_ app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch.frame

        var ceiling = window.minY
        let bars = app.navigationBars
        for index in 0..<bars.count {
            let bar = bars.element(boundBy: index)
            guard bar.exists else { continue }
            let frame = bar.frame
            // 위에 붙어 있는 크롬만 천장으로 센다. 한복판의 막대는 크롬이 아니다.
            guard frame.minY <= window.midY else { continue }
            ceiling = max(ceiling, frame.maxY)
        }

        var floor = window.maxY
        for optional in [app.toolbars.firstMatch, app.keyboards.element] {
            guard optional.exists else { continue }
            let frame = optional.frame
            guard frame.maxY >= window.midY else { continue }
            floor = min(floor, frame.minY)
        }

        return CGRect(x: window.minX, y: ceiling,
                      width: window.width, height: max(0, floor - ceiling))
    }

    /// 실패 문구. **여기서는 무엇도 던지지 않는다.**
    private func viewportDiagnostics(_ app: XCUIApplication, _ element: XCUIElement,
                                     swipes: Int) -> String {
        let exists = element.exists
        let label = exists ? element.label : "NOT_PRESENT"
        let frame = exists ? "\(element.frame)" : "NOT_PRESENT"
        let hittable = exists ? "\(element.isHittable)" : "NOT_PRESENT"
        return "스크롤해도 쓸 수 있는 구간 안으로 들어오지 않는다 — "
            + "label=\"\(label)\" exists=\(exists) hittable=\(hittable) frame=\(frame) "
            + "창=\(app.windows.firstMatch.frame) 구간=\(usableViewport(app)) 스와이프=\(swipes)"
    }

    /// 쓸 수 있는 구간 안으로 끌어오고, 그 안에 **담겨 있는지**까지 확인한다.
    ///
    /// `isHittable`만으로는 통과시키지 않는다 — 위 크롬에 덮여 있어도 참이 되기 때문이다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 25,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)

        /// 자리를 잡은 뒤의 좌표로 판단한다. 스크롤이 아직 멈추지 않았으면 XCUI는
        /// 보이는 요소도 `isHittable`이 아니라고 답한다.
        func containedInUsableViewport() -> Bool {
            guard element.exists else { return false }
            let frame = settled(element, file: file, line: line)
            let viewport = usableViewport(app)
            return element.isHittable
                && frame.minY >= viewport.minY
                && frame.maxY <= viewport.maxY
        }

        // AccessibilityXXXL에서는 폼 전체가 2,300pt를 넘는다. 넉넉히 밀어 본다.
        var swipes = 0
        for _ in 0..<maximumSwipes {
            if containedInUsableViewport() { return element }
            guard element.exists else { app.swipeUp(); swipes += 1; continue }
            let frame = element.frame
            let viewport = usableViewport(app)
            if frame.maxY > viewport.maxY {
                app.swipeUp()
            } else if frame.minY < viewport.minY {
                // 위 크롬 밑으로 지나쳤다. 되돌린다.
                app.swipeDown()
            } else {
                app.swipeUp()
            }
            swipes += 1
        }

        XCTAssertTrue(containedInUsableViewport(),
                      viewportDiagnostics(app, element, swipes: swipes),
                      file: file, line: line)
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

    /// 생성 경로가 여는 것은 이제 세 단계 흐름의 1단계다.
    private func assertWizardStep1IsOpen(_ app: XCUIApplication, origin: String,
                                         file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(exactText(app, "어떤 경기였나요?")), "1단계 제목이 없다", file: file, line: line)
        XCTAssertFalse(exactText(app, "필수 정보").exists,
                       "생성 경로가 아직 한 장짜리 폼을 연다", file: file, line: line)
        for forbidden in ["임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500", "오늘 직관, 몇 점이었나요?"] {
            XCTAssertFalse(text(app, forbidden).exists,
                           "지원하지 않는 \(forbidden)이 생겼다", file: file, line: line)
        }
    }

    /// 1단계의 컨트롤이 좁은 폭·큰 글자에서 화면 안에 남는지.
    private func assertStep1RemainsUsable(_ app: XCUIApplication,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame

        func assertInsideScreen(_ element: XCUIElement, _ name: String) {
            let frame = settled(element)
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "\(name)이 왼쪽으로 넘쳤다", file: file, line: line)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "\(name)이 오른쪽으로 넘쳤다", file: file, line: line)
            XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
            XCTAssertGreaterThan(frame.width, 0, "\(name)이 너비 0으로 접혔다", file: file, line: line)
        }

        for identifier in ["recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam"] {
            assertInsideScreen(scrollIntoView(app, node(app, identifier), file: file, line: line), identifier)
        }
        for result in ["승리", "패배", "무승부", "경기 취소"] {
            assertInsideScreen(scrollIntoView(app, app.buttons[result].firstMatch, file: file, line: line), "결과 \(result)")
        }
        // 지금 편집기가 이미 가진 도움에 여기서도 닿는다.
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"), file: file, line: line), "티켓에서 불러오기")
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.assist.findGame"), file: file, line: line), "경기 자동 찾기")
        // 다음과 최소 저장까지 닿는다.
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.next"), file: file, line: line), "다음")
        assertInsideScreen(scrollIntoView(app, node(app, "recordCreate.saveMinimal"), file: file, line: line), "여기까지만 저장할게요")
    }

    private func openHomeCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.home")), "홈에 들어가지 못했다")
        scrollIntoView(app, node(app, "home.recordCTA")).tap()
        assertWizardStep1IsOpen(app, origin: "home")
    }

    private func openFeedCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertWizardStep1IsOpen(app, origin: "feed")
    }

    private func openCalendarCreate(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더에 들어가지 못했다")
        scrollIntoView(app, node(app, "calendar.detailAddRecord")).tap()
        assertWizardStep1IsOpen(app, origin: "calendar")
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
        //
        // 부분 일치는 쓰지 않는다. 시트 뒤 피드 카드의 라벨
        // ("… 잠실야구장 · 3루 원정석 · 엄마랑")이 "구장"을 품고 있어서, 부분 일치는
        // 편집기의 구장 메뉴 대신 그 카드를 집어 온다(SE 3에서 실제로 그랬다).
        // 메뉴 라벨은 제목으로 시작하므로 앞부분 일치로 좁힌다.
        let opponentMenu = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "상대팀")).firstMatch
        assertInsideScreen(scrollIntoView(app, opponentMenu, file: file, line: line), "상대팀 메뉴")
        let stadiumMenu = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "구장")).firstMatch
        assertInsideScreen(scrollIntoView(app, stadiumMenu, file: file, line: line), "구장 메뉴")
        // 경기 결과 네 버튼.
        for result in ["승", "패", "무", "취소"] {
            let button = app.buttons[result].firstMatch
            assertInsideScreen(scrollIntoView(app, button, file: file, line: line), "결과 \(result)")
        }

        // 사진 카드 · 선택 정보 카드.
        let addPhoto = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "사진 추가")).firstMatch
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
        assertStep1RemainsUsable(app)
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
        assertStep1RemainsUsable(app)
    }

    func testCompact04_calendarCreateKeepsTheSelectedDate() throws {
        let app = calendarApp()
        try requireCompactWidth(app)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")), "픽스처가 적용되지 않았다")
        openCalendarCreate(app)
        // 캘린더가 정한 날짜가 1단계에 그대로 온다.
        XCTAssertTrue(scrollIntoView(app, node(app, "recordCreate.field.date")).exists)
        assertStep1RemainsUsable(app)
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
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        // 새 기록은 상대팀·구장·결과가 비어 있으므로 진행을 막는 안내가 뜬다.
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 1단계는 그대로 열려 있다.
        assertWizardStep1IsOpen(app, origin: "feed")
    }

    func testCompact10_featureSurfacesRemainReachable() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        // 1단계의 도우미 — 티켓 OCR과 경기 자동 찾기.
        scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        scrollIntoView(app, node(app, "recordCreate.assist.findGame"))
        XCTAssertTrue(node(app, "recordCreate.assist.ticketOCR").isHittable, "OCR 진입을 누를 수 없다")
        // 사진 분석과 AI 초안은 3단계에 있다. 통합 UI 테스트가 거기서 확인한다.
    }

    func testCompact11_cancellationReturnsToThePresentingScreen() throws {
        let app = feedApp()
        try requireCompactWidth(app)
        openFeedCreate(app)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertFalse(node(app, "recordCreate.step1.root").exists, "흐름이 남아 있다")
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
        // 좌석은 한 장짜리 폼에만 있다. 그 폼의 주인은 이제 수정 경로다.
        let app = feedApp()
        try requireCompactWidth(app)
        openRecordDetailEdit(app)
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
        let score = scrollIntoView(app, node(app, "recordCreate.score.our"))
        score.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        score.typeText("6")
        // 숫자 키패드에는 Return이 없다. 화면이 주는 완료로 내린다.
        node(app, "recordCreate.score.done").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 8), "검증 안내가 뜨지 않았다")
        scrollIntoView(app, warning)
        // 시트가 하나뿐이고 적어 둔 값이 남아 있다.
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 추가").count, 1)
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.score.our")).value as? String ?? "", "6",
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
        let height = settled(exactText(app, "어떤 경기였나요?")).height
        app.terminate()
        return height
    }

    func testAccessibility01_runtimeGateProvesTheCategoryApplied() {
        let baseline = defaultRequiredHeadingHeight()
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        assertAccessibilityCategoryApplied(exactText(app, "어떤 경기였나요?"), defaultHeight: baseline)
    }

    func testAccessibility02_homeCreateRemainsUsable() {
        let app = homeApp(accessibilitySize: true)
        openHomeCreate(app)
        assertStep1RemainsUsable(app)
    }

    func testAccessibility03_calendarCreateRemainsUsable() {
        let app = calendarApp(accessibilitySize: true)
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")))
        openCalendarCreate(app)
        assertStep1RemainsUsable(app)
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
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        let warning = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "선택해 주세요")).firstMatch
        XCTAssertTrue(waits(warning, 10), "큰 글자에서 검증 안내가 사라졌다")
        scrollIntoView(app, warning)
    }

    func testAccessibility07_featureSurfacesRemainReachable() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        scrollIntoView(app, node(app, "recordCreate.assist.findGame"))
    }

    func testAccessibility08_keyboardStillLeavesTheFieldVisible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        let field = scrollIntoView(app, node(app, "recordCreate.score.our"))
        field.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 12), "큰 글자에서 키보드가 올라오지 않았다")
        let keyboardTop = settled(app.keyboards.element).minY
        XCTAssertLessThan(settled(field).maxY, keyboardTop + 0.5, "큰 글자에서 입력 필드가 키보드에 가렸다")
        node(app, "recordCreate.score.done").tap()
    }

    func testAccessibility09_cancellationRemainsPossible() {
        let app = feedApp(accessibilitySize: true)
        openFeedCreate(app)
        let cancel = node(app, "recordCreate.cancel")
        XCTAssertTrue(cancel.isHittable, "큰 글자에서 취소를 누를 수 없다")
        cancel.tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "큰 글자에서 흐름을 닫지 못했다")
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
