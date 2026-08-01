import XCTest

/// 세 단계 기록 작성 흐름이 **제품 생성 경로**에 붙은 뒤의 사용자 동선.
///
/// 여기서 확인하는 것은 소스가 아니라 실제로 화면에서 일어나는 일이다.
/// 다섯 개 생성 경로가 흐름을 열고, 두 개 수정 경로가 지금 편집기를 열고,
/// 저장은 기록 하나만 만들고, 취소는 아무것도 남기지 않는다.
///
/// 검증용 스테이징 호스트(`-VFUITestRecordCreateStaged`)는 **쓰지 않는다.**
/// 모든 진입은 사용자가 실제로 누르는 버튼에서 시작한다.
final class RecordCreateProductionIntegrationUITests: XCTestCase {

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
    /// 스크롤이 움직이지 않는다(실측: 일기 아래의 `AI 초안`에 영원히 닿지 못했다).
    /// 가로 여백은 본문 밖이라 언제나 바깥 스크롤이 받는다.
    private func edgeSwipe(_ app: XCUIApplication, up: Bool) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.75 : 0.3))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: up ? 0.3 : 0.75))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    /// 아래에 고정된 액션 막대 밑에 깔린 요소도 XCUI는 `isHittable`로 본다(실측).
    /// 그래서 닿을 수 있는지만 묻지 않고 **그 막대 위에 담겨 있는지**까지 보고,
    /// 지나쳤으면 되돌아온다 — 한쪽으로만 쓸면 위에 있는 것을 영영 놓친다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 16,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)
        let pinned = ["recordCreate.step3.complete", "recordCreate.step2.next",
                      "recordCreate.step2.skip", "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<maximumSwipes {
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
        XCTAssertTrue(element.isHittable,
                      "스크롤해도 누를 수 없다 — label=\"\(element.label)\" frame=\(element.frame) "
                      + "window=\(window) bar=\(app.buttons.matching(identifier: "recordCreate.step3.complete").firstMatch.frame)",
                      file: file, line: line)
        return element
    }

    /// 고정 액션 막대 위에 **담겨 있는지**까지 본다. `isHittable`만으로는 부족하다.
    private func assertContainedAboveActionBar(_ app: XCUIApplication, _ element: XCUIElement, _ name: String,
                                               file: StaticString = #filePath, line: UInt = #line) {
        let bar = app.buttons.matching(identifier: "recordCreate.step3.complete").firstMatch
        guard bar.exists else { return }
        XCTAssertLessThanOrEqual(element.frame.maxY, bar.frame.minY + 0.5,
                                 "\(name)이 고정 액션 막대에 가린다 — \(name)=\(element.frame) 막대=\(bar.frame)",
                                 file: file, line: line)
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
        // 검증용 스테이징 호스트로 새어 들어가지 않았는지 못박는다.
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "recordCreate.scenario."))
            .firstMatch.exists, "스테이징 픽스처로 열렸다 — 제품 경로가 아니다")
        return app
    }

    /// 세 단계 흐름의 1단계가, 그것도 **그 경로에서** 열렸는지.
    private func assertFlowOpened(_ app: XCUIApplication, origin: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다", file: file, line: line)
        XCTAssertFalse(app.staticTexts["필수 정보"].exists,
                       "생성 경로가 아직 한 장짜리 폼을 연다", file: file, line: line)
        for forbidden in ["임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500", "몇 점이었나요"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 생겼다", file: file, line: line)
        }
        // 시트 뒤에 깔린 화면(통계 상세)의 막대까지 세면 안 된다. 흐름 자신의 막대가
        // 둘이 아닌지만 본다.
        XCTAssertLessThanOrEqual(app.navigationBars.matching(identifier: "직관 기록 추가").count, 1,
                                 "흐름의 내비게이션 컨테이너가 둘이다", file: file, line: line)
    }

    /// 지금 편집기가 열렸는지. 수정 경로는 여기로 온다.
    private func assertCurrentEditorOpened(_ app: XCUIApplication,
                                           file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch),
                      "수정 편집기가 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(app.staticTexts["필수 정보"].firstMatch),
                      "한 장짜리 폼이 아니다", file: file, line: line)
        XCTAssertFalse(node(app, "recordCreate.step1.root").exists,
                       "수정이 마법사로 갔다", file: file, line: line)
        XCTAssertTrue(node(app, "logEditor.cancel").exists, "편집기의 취소가 사라졌다", file: file, line: line)
    }

    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        control.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(waits(item, 8), "\(option) 항목이 없다")
        item.tap()
    }

    /// 1단계를 저장 가능한 상태로 만든다. 응원팀은 사용자 설정에서 이미 온다.
    private func fillValidStep1(_ app: XCUIApplication, opponent: String = "KIA 타이거즈") {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: opponent)
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
    }

    /// 지금 피드에 보이는 기록 수.
    private func recordCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .count
    }

    /// 그 상대팀과의 기록 수.
    ///
    /// 저장소는 날짜·대진·구장·결과·점수가 같은 기록을 하나로 합친다. 그래서 테스트마다
    /// 상대팀을 달리해 서로의 기록이 섞이지 않게 하고, 셀 때도 대진으로 좁힌다.
    private func recordCount(_ app: XCUIApplication, opponent: String) -> Int {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                  "feed.record.", opponent))
            .count
    }

    private func gotoFeed(_ app: XCUIApplication) {
        app.buttons["tab.feed"].tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드로 가지 못했다")
    }

    // MARK: - 진입 경로

    private func homeApp(_ extra: [String] = []) -> XCUIApplication {
        let app = launch(["-VFUITestInitialTab", "home"] + extra)
        XCTAssertTrue(waits(node(app, "screen.home")), "홈이 뜨지 않았다")
        return app
    }

    private func feedApp(_ extra: [String] = []) -> XCUIApplication {
        let app = launch(["-VFUITestInitialTab", "feed"] + extra)
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드가 뜨지 않았다")
        return app
    }

    private func openHomeCreate(_ app: XCUIApplication) {
        scrollIntoView(app, node(app, "home.recordCTA")).tap()
        assertFlowOpened(app, origin: "home")
    }

    private func openFeedCreate(_ app: XCUIApplication) {
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertFlowOpened(app, origin: "feed")
    }

    // MARK: - 1~5. 다섯 개 생성 경로

    func testP01_homeStandardCreateOpensTheFlow() {
        let app = homeApp()
        openHomeCreate(app)
        // 고르지 않은 기분이 미리 선택돼 보이지 않는다 — 3단계까지 가서 확인한다.
        XCTAssertTrue(node(app, "recordCreate.progress").exists, "진행 표시가 없다")
    }

    func testP02_feedCreateOpensTheFlow() {
        let app = feedApp()
        openFeedCreate(app)
    }

    func testP03_calendarCreateKeepsTheSuppliedDate() {
        let app = launch(["-VFUITestInitialTab", "calendar",
                          "-VFUITestCalendarFixture", "selectedEmptyDate"])
        XCTAssertTrue(waits(node(app, "calendar.scenario.selectedEmptyDate")), "픽스처가 적용되지 않았다")
        scrollIntoView(app, node(app, "calendar.detailAddRecord")).tap()
        assertFlowOpened(app, origin: "calendar")
        // 캘린더가 고른 2026년 4월 20일이 그대로 온다.
        XCTAssertTrue(dateFieldSpeaksAprilTwentieth(app), "캘린더가 정해 준 날짜가 사라졌다")
    }

    /// 1단계 날짜 칸이 4월 20일을 말하고 있는가.
    ///
    /// 컴팩트 `DatePicker`는 값을 자기 라벨이 아니라 **안쪽 요소**가 들고 있고, 그
    /// 표기는 지역 설정에 따라 `4월 20일`일 수도 `4. 20.`일 수도 있다. 그래서 안쪽
    /// 라벨을 모두 모아 "4 다음에 곧 20"이 나오는지로 본다.
    private func dateFieldSpeaksAprilTwentieth(_ app: XCUIApplication) -> Bool {
        let field = scrollIntoView(app, node(app, "recordCreate.field.date"))
        var spoken = [field.label, field.value as? String ?? ""]
        let inner = field.descendants(matching: .any)
        for index in 0..<min(inner.count, 12) {
            let element = inner.element(boundBy: index)
            spoken.append(element.label)
            spoken.append(element.value as? String ?? "")
        }
        let joined = spoken.joined(separator: " ")
        return joined.range(of: "4[^0-9]{0,3}20", options: .regularExpression) != nil
    }

    func testP04_statisticsStadiumCreateFabricatesNoStadium() {
        let app = launch(["-VFUITestInitialTab", "statistics",
                          "-VFUITestStatisticsFixture", "noStadium"])
        XCTAssertTrue(waits(node(app, "statistics.scenario.noStadium")), "픽스처가 적용되지 않았다")
        scrollIntoView(app, node(app, "statistics.highlight.mostVisitedStadium")).tap()
        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "빈 상태가 없다")
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch).tap()

        assertFlowOpened(app, origin: "statisticsStadium")
        let stadium = scrollIntoView(app, node(app, "recordCreate.field.stadium"))
        XCTAssertEqual(stadium.value as? String ?? "", "선택하지 않음", "구장을 지어냈다")
    }

    func testP05_statisticsOpponentCreateFabricatesNoOpponent() {
        let app = launch(["-VFUITestInitialTab", "statistics",
                          "-VFUITestStatisticsFixture", "noOpponent"])
        XCTAssertTrue(waits(node(app, "statistics.scenario.noOpponent")), "픽스처가 적용되지 않았다")
        scrollIntoView(app, node(app, "statistics.highlight.mostFacedOpponent")).tap()
        XCTAssertTrue(waits(text(app, "아직 상대팀별 통계가 없어요")), "빈 상태가 없다")
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch).tap()

        assertFlowOpened(app, origin: "statisticsOpponent")
        let opponent = scrollIntoView(app, node(app, "recordCreate.field.opponentTeam"))
        XCTAssertEqual(opponent.value as? String ?? "", "선택하지 않음", "상대팀을 지어냈다")
    }

    // MARK: - 6~7. 수정 경로는 그대로다

    func testP06_homeAIPreflightEditStaysOnTheCurrentEditor() {
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

        assertCurrentEditorOpened(app)
        // AI 사전 고지가 스스로 올라온다 — 그 의도가 살아 있다.
        XCTAssertTrue(waits(text(app, "AI"), 10), "AI 사전 진입 의도가 사라졌다")
    }

    func testP07_recordDetailEditStaysOnTheCurrentEditor() {
        let app = feedApp(["-VFUITestFeedFixture", "populated"])
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record.")).firstMatch
        XCTAssertTrue(waits(record), "피드에 기록이 없다")
        record.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")))
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()

        assertCurrentEditorOpened(app)
        // 위에 있는 진입면부터 확인한다 — 아래로 내려간 뒤에는 되돌아와야 하므로.
        scrollIntoView(app, app.buttons["티켓으로 작성하기"].firstMatch)
        // 기존 값이 그대로 채워져 있다.
        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertFalse((seat.value as? String ?? "").isEmpty, "수정 프리필이 사라졌다")
        // 아래쪽 보조 기능도 그대로 있다.
        scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "AI로 후기 초안 만들기")).firstMatch)
    }

    // MARK: - 8~10. 저장

    func testP08_minimalSaveFromFeedCreatesExactlyOneRecord() {
        let app = feedApp()
        openFeedCreate(app)
        fillValidStep1(app, opponent: "KIA 타이거즈")

        scrollIntoView(app, node(app, "recordCreate.saveMinimal")).tap()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 20),
                      "최소 저장 뒤 흐름이 닫히지 않았다")
        XCTAssertTrue(waits(node(app, "screen.feed")), "저장 뒤 피드로 돌아오지 못했다")
        XCTAssertEqual(recordCount(app, opponent: "KIA"), 1, "최소 저장이 기록을 하나 만들지 않았다")
    }

    func testP09_fullCompletionFromHomeCreatesExactlyOneRecord() {
        let app = homeApp()
        openHomeCreate(app)
        fillValidStep1(app, opponent: "두산 베어스")

        // 2단계 — 선택 사항이지만 값을 적으면 함께 실려 간다.
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        seat.typeText("3루 K열 12번")
        node(app, "recordCreate.step2.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)

        // 3단계 — 기분은 아직 아무것도 선택돼 있지 않다.
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
        for mood in ["overwhelmed", "happy", "proud", "regret", "annoyed"] {
            let chip = node(app, "recordCreate.step3.mood.\(mood)")
            XCTAssertTrue(waits(chip), "\(mood) 칩이 없다")
            XCTAssertFalse(chip.isSelected, "고르지 않았는데 \(mood)이 선택돼 있다")
        }
        node(app, "recordCreate.step3.mood.happy").tap()
        XCTAssertTrue(node(app, "recordCreate.step3.mood.happy").isSelected, "기분이 선택되지 않았다")

        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()
        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 25),
                      "완성 뒤 흐름이 닫히지 않았다")
        XCTAssertTrue(waits(node(app, "screen.home")), "저장 뒤 홈으로 돌아오지 못했다")

        gotoFeed(app)
        XCTAssertEqual(recordCount(app, opponent: "두산"), 1, "완성 저장이 기록을 하나 만들지 않았다")
    }

    func testP10_duplicateCompletionTapsCreateOneRecord() {
        let app = feedApp()
        openFeedCreate(app)
        fillValidStep1(app, opponent: "롯데 자이언츠")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))

        let complete = scrollIntoView(app, node(app, "recordCreate.step3.complete"))
        complete.tap()
        // 곧바로 한 번 더. 저장 중 가드가 두 번째를 삼켜야 한다.
        if complete.exists, complete.isHittable { complete.tap() }

        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 25),
                      "완성 뒤 흐름이 닫히지 않았다")
        XCTAssertTrue(waits(node(app, "screen.feed")), "저장 뒤 피드로 돌아오지 못했다")
        XCTAssertEqual(recordCount(app, opponent: "롯데"), 1, "두 번 눌러 기록이 둘 생겼다")
        // 흐름이 다시 열리지도 않았다.
        XCTAssertFalse(node(app, "recordCreate.step3.root").exists, "두 번째 탭이 흐름을 되살렸다")
    }

    // MARK: - 11~13. 취소

    func testP11_cancellationFromEveryStepWritesNothing() {
        let app = feedApp()
        let before = recordCount(app)
        // 취소는 아무것도 남기지 않아야 하므로, 여기서 고르는 상대팀의 기록은
        // 실행이 끝날 때까지 한 건도 없어야 한다.

        // 1단계에서 취소.
        openFeedCreate(app)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "1단계 취소가 피드로 돌아오지 않았다")
        XCTAssertEqual(recordCount(app), before, "1단계 취소가 기록을 만들었다")

        // 2단계에서 취소.
        openFeedCreate(app)
        fillValidStep1(app, opponent: "한화 이글스")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "2단계 취소가 피드로 돌아오지 않았다")
        XCTAssertEqual(recordCount(app), before, "2단계 취소가 기록을 만들었다")

        // 3단계에서, 키보드를 띄운 채로 취소.
        openFeedCreate(app)
        fillValidStep1(app, opponent: "한화 이글스")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        diary.typeText("취소할 글")
        node(app, "recordCreate.step3.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "3단계 취소가 피드로 돌아오지 않았다")
        XCTAssertEqual(recordCount(app), before, "3단계 취소가 기록을 만들었다")
        XCTAssertEqual(recordCount(app, opponent: "한화"), 0, "취소했는데 그 경기 기록이 생겼다")
    }

    func testP12_reopeningCreateAfterCancellationStartsFresh() {
        let app = feedApp()
        openFeedCreate(app)
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        seat.typeText("남으면 안 되는 값")
        node(app, "recordCreate.step2.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")))

        // 다시 열면 1단계부터, 빈 초안으로 시작한다.
        openFeedCreate(app)
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.stadium")).value as? String ?? "",
                       "선택하지 않음", "취소한 구장이 되살아났다")
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.opponentTeam")).value as? String ?? "",
                       "선택하지 않음", "취소한 상대팀이 되살아났다")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        // 1단계가 아직 막혀 있으므로 2단계로 가지 않는다.
        XCTAssertFalse(node(app, "recordCreate.step2.root").exists, "빈 초안인데 2단계로 넘어갔다")
    }

    // MARK: - 13~15. 보조 기능 파리티

    func testP13_ticketOCRAndGameLookupAreReachableInStepOne() {
        let app = feedApp()
        openFeedCreate(app)

        // 두 도움 모두 눈에 보이고 누를 수 있다.
        let ocr = scrollIntoView(app, node(app, "recordCreate.assist.ticketOCR"))
        let lookup = scrollIntoView(app, node(app, "recordCreate.assist.findGame"))
        XCTAssertTrue(ocr.isHittable, "티켓 OCR을 누를 수 없다")
        XCTAssertTrue(lookup.isHittable, "경기 자동 찾기를 누를 수 없다")

        // 티켓 OCR은 지금 쓰는 화면을 그대로 연다.
        ocr.tap()
        XCTAssertTrue(waits(text(app, "티켓 이미지는 서버로 전송되지 않아요"), 10),
                      "지금 쓰는 티켓 OCR 화면이 열리지 않았다")
        app.buttons["취소"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "OCR을 닫고 1단계로 돌아오지 못했다")

        // 경기 자동 찾기는 결과가 없어도 무엇이 일어났는지 말한다.
        scrollIntoView(app, node(app, "recordCreate.assist.findGame")).tap()
        let status = node(app, "recordCreate.assist.lookupStatus")
        XCTAssertTrue(waits(status, 20), "경기 찾기가 결과를 말하지 않는다")
        XCTAssertFalse(status.label.isEmpty, "결과 안내가 비어 있다")
        // 어느 쪽도 저장하지 않는다 — 1단계는 그대로 열려 있다.
        XCTAssertTrue(node(app, "recordCreate.step1.root").exists, "보조 동작이 흐름을 닫았다")
    }

    func testP14_photoAnalysisAndAIDraftAreReachableInStepThree() {
        // 사진 상태만 결정적으로 심는다. 진입은 여전히 제품 경로(피드)다.
        let app = feedApp(["-VFUITestRecordCreateStagedPhotos", "one"])
        openFeedCreate(app)
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))

        // 사진 분석 — 사진이 있으므로 열린다.
        let analyze = scrollIntoView(app, node(app, "recordCreate.step3.analyzePhotos"))
        XCTAssertTrue(analyze.isEnabled, "사진이 있는데 사진 분석을 쓸 수 없다")
        analyze.tap()
        XCTAssertTrue(waits(text(app, "사진 분석을 위해 선택한 사진이 서버로 전송돼요"), 10),
                      "지금 쓰는 사진 분석 고지 화면이 열리지 않았다")
        app.buttons["취소"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "사진 분석을 닫고 3단계로 돌아오지 못했다")
        XCTAssertTrue(node(app, "recordCreate.step3.removePhoto.1").exists, "사진이 사라졌다")

        // AI 초안 — 사전 고지를 먼저 띄운다.
        let ai = scrollIntoView(app, node(app, "recordCreate.step3.aiDraft"))
        assertContainedAboveActionBar(app, ai, "AI 초안")
        ai.tap()
        XCTAssertTrue(waits(text(app, "AI 초안을 만들기 전에"), 10), "AI 사전 고지가 뜨지 않았다")
        app.buttons["취소"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "AI 초안을 닫고 3단계로 돌아오지 못했다")

        // 어느 쪽도 저장하지 않았다.
        XCTAssertTrue(node(app, "recordCreate.step3.complete").exists, "보조 동작이 흐름을 닫았다")
    }

    func testP15_valuesSurviveMovingBetweenStepsInProduction() {
        let app = feedApp()
        openFeedCreate(app)
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))

        let moment = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        moment.tap()
        moment.typeText("9회 역전")
        node(app, "recordCreate.step3.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        node(app, "recordCreate.step3.mood.proud").tap()

        // 1단계까지 되돌아갔다 다시 온다.
        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")))
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.stadium")).value as? String ?? "",
                       "잠실야구장", "1단계 값이 사라졌다")

        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 돌아오지 못했다")
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.step3.moment")).value as? String ?? "",
                       "9회 역전", "단계를 오가며 적어 둔 값이 사라졌다")
        XCTAssertTrue(node(app, "recordCreate.step3.mood.proud").isSelected, "고른 기분이 사라졌다")
    }

    /// 1단계가 비어 있는 채로 완성을 누르면 저장하지 않고 1단계로 되돌린다.
    ///
    /// 이 상태는 제품 흐름으로 만들 수 없다 — 1단계의 `다음`이 이미 막는다. 그래서
    /// **진입은 제품 경로(피드)로 하고**, 시작 위치만 DEBUG 인자로 옮겨 마지막
    /// 버튼의 방어를 실제 경로 위에서 확인한다.
    func testP16_invalidCompletionReturnsToStepOneWithoutSaving() {
        let app = feedApp(["-VFUITestRecordCreateInitialStep", "memory"])
        let before = recordCount(app)
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.origin.feed")), "피드 경로로 열리지 않았다")
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "마지막 단계에서 시작하지 않았다")

        // 3단계 값을 적어 둔다. 되돌아가도 남아야 한다.
        let moment = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        moment.tap()
        moment.typeText("남아야 하는 값")
        node(app, "recordCreate.step3.keyboardDone").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)

        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()

        // 저장하지 않고 1단계로 돌아왔고, 무엇이 빠졌는지 이미 말하고 있다.
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "완성이 1단계로 되돌리지 않았다")
        let message = node(app, "recordCreate.validationMessage")
        XCTAssertTrue(waits(message), "무엇이 빠졌는지 말하지 않는다")
        XCTAssertFalse(message.label.isEmpty)

        // 3단계로 다시 가면 적어 둔 값이 그대로다.
        scrollIntoView(app, node(app, "recordCreate.field.stadium"))
        node(app, "recordCreate.cancel").tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertEqual(recordCount(app), before, "막힌 완성이 기록을 만들었다")
    }
}
