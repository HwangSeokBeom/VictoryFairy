import XCTest

/// Record Create 기반의 세 가지 진입/이탈 막힘을 실제 사용자 동선으로 확인한다.
///
/// 1. 홈 AI 도우미 진입 — 지연 생성되는 컨트롤을 먼저 스크롤로 올린 뒤 찾는다.
/// 2. 편집기 취소 — 폼을 스크롤한 뒤에도 시트를 내릴 수 있는지.
/// 3. 시즌 아카이브 구장·상대팀 상세 — 통계가 0건일 때도 들어갈 수 있는지.
///
/// 보이는 세 단계 화면은 만들지 않는다. 여기서 확인하는 것은 지금의 한 장짜리
/// 편집기에 **닿을 수 있는가**와 **빠져나올 수 있는가**뿐이다.
final class RecordCreateRouteRepairUITests: XCTestCase {

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
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    private func launch(_ extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VFUITest", "-VFUITestReset",
                               "-VFUITestTeamID", "samsung-lions",
                               "-VFUITestStadiumID", "daegu-lions",
                               "-VFUITestOnboardingCompleted", "1"] + extra
        app.launch()
        return app
    }

    /// 지연 생성되는 요소를 스크롤로 올린 뒤에 찾는다.
    ///
    /// SwiftUI는 화면 밖 콘텐츠를 접근성 트리에 올리지 않는다. 그래서 먼저
    /// 기다리면 영원히 못 찾는다 — 밀어 올리면서 나타나는지를 본다.
    @discardableResult
    private func scrollUntilExists(_ app: XCUIApplication, _ element: XCUIElement,
                                   maximumSwipes: Int = 12,
                                   file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        for _ in 0..<maximumSwipes {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists, "스크롤해도 요소가 나타나지 않는다", file: file, line: line)
        XCTAssertTrue(element.isHittable, "요소가 나타났지만 누를 수 없다", file: file, line: line)
        return element
    }

    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                maximumSwipes: Int = 25,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)
        for _ in 0..<maximumSwipes where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable, "스크롤해도 누를 수 없다 — label=\"\(element.label)\"",
                      file: file, line: line)
        return element
    }

    /// 편집기가 열렸는지. 마법사가 생기지 않았는지도 함께 본다.
    private func assertEditorIsOpen(_ app: XCUIApplication, editing: Bool,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let title = editing ? "직관 기록 수정" : "직관 기록 추가"
        XCTAssertTrue(waits(app.staticTexts[title].firstMatch),
                      "편집기가 열리지 않았다 (\(title))", file: file, line: line)
        for forbidden in ["다음 · 그날의 디테일", "이 단계는 건너뛸게요", "여기까지만 저장할게요",
                          "기록 완성하기", "임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 생겼다", file: file, line: line)
        }
        // 편집기는 하나뿐이다.
        XCTAssertEqual(app.staticTexts.matching(identifier: title).count, 1,
                       "편집기가 둘이다", file: file, line: line)
    }

    /// 실제 사용자 이탈 동작으로 시트를 내린다.
    ///
    /// 화면 가운데에서 아래로 쓸면 편집기 `ScrollView`가 제스처를 먹는다(측정으로
    /// 확인했다). 내비게이션 바는 스크롤 뷰 밖이라 언제나 시트를 잡는다 — iOS가
    /// 정한 시트 손잡이 영역이다.
    private func dismissSheetFromNavigationBar(_ app: XCUIApplication) {
        if app.keyboards.element.exists {
            app.swipeDown()
            _ = app.keyboards.element.waitForNonExistence(timeout: 4)
        }
        let bar = app.navigationBars.firstMatch
        XCTAssertTrue(waits(bar), "시트의 내비게이션 바를 찾지 못했다")
        let start = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 22))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    // MARK: - 1. 홈 AI 도우미 진입

    /// 최근 기록이 있을 때. 원본이 정한 대로 **수정 모드**로 열린다.
    func testHomeAIPreflightWithRecentRecordOpensEditMode() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"])
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드 픽스처가 적용되지 않았다")
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "home.root")), "홈이 뜨지 않았다")

        // 승리요정 지수 카드는 화면 아래쪽에 있어 스크롤해야 트리에 올라온다.
        let aiButton = app.buttons["AI 직관 기록 도우미"]
        scrollUntilExists(app, aiButton).tap()

        // 실제 AI 도우미 시트.
        XCTAssertTrue(waits(text(app, "AI가 직관 기록을 정리해드릴게요")), "AI 도우미 시트가 없다")
        let startDraft = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@",
                        "후기 초안 만들기", "최근 직관 다듬기")).firstMatch
        XCTAssertTrue(waits(startDraft), "최근 기록용 초안 버튼이 없다")
        startDraft.tap()

        // 최근 기록을 고쳐 쓰는 것이므로 수정 모드다.
        XCTAssertTrue(waits(app.staticTexts["직관 기록 수정"].firstMatch),
                      "AI 진입이 수정 모드로 열리지 않았다")
        XCTAssertEqual(app.staticTexts.matching(identifier: "직관 기록 수정").count, 1,
                       "편집기가 둘이다")
        // `startsAIPreflightOnAppear`가 살아 있으면 사전 고지가 스스로 올라온다.
        // 그 시트가 편집기 위를 덮으므로 여기서 폼 필드를 만지려 하지 않는다.
        XCTAssertTrue(waits(text(app, "AI"), 10), "AI 사전 진입 의도가 반영되지 않았다")
        // 보이는 단계 UI는 생기지 않았다.
        for forbidden in ["다음 · 그날의 디테일", "임시저장", "기록 완성하기", "0 / 500"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 생겼다")
        }
    }

    /// 최근 기록이 없을 때 홈이 어떤 상태인지 확인한다.
    ///
    /// `fairyIndexSection`은 `dashboard.isEmpty`가 아닐 때만 그려지고, 대시보드가
    /// 비는 조건과 최근 기록이 없는 조건이 같다. 그래서 기록이 0건이면 AI 도우미
    /// 버튼 자체가 없고, `HomeView`의 "최근 기록 없음 → 생성 모드" 가지에 닿을 수
    /// 없다. 이 테스트는 그 사실을 못박아 둔다 — 나중에 도달 가능해지면 실패해서
    /// 알려 준다.
    func testHomeAIPreflightWithoutRecentRecordHasNoHelperEntry() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "empty"])
        XCTAssertTrue(waits(node(app, "screen.feed")))
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "home.root")), "홈이 뜨지 않았다")

        for _ in 0..<12 { app.swipeUp() }
        XCTAssertFalse(app.buttons["AI 직관 기록 도우미"].exists,
                       "기록이 0건인데 AI 도우미 버튼이 생겼다 — 도달 가능해졌다면 생성 모드 검증을 추가해야 한다")
        // 표준 생성 동선은 그대로 살아 있다.
        for _ in 0..<12 where !node(app, "home.recordCTA").isHittable { app.swipeDown() }
        XCTAssertTrue(node(app, "home.recordCTA").exists, "표준 생성 진입점까지 사라졌다")
    }

    // MARK: - 2. 편집기 취소

    private func openRecordDetailEdit(_ app: XCUIApplication) {
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let record = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(record), "피드에 기록이 없다")
        record.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")))
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorIsOpen(app, editing: true)
    }

    /// 폼을 스크롤해 내려간 뒤에도 실제 사용자 동작으로 시트를 닫을 수 있고,
    /// 닫아도 원본이 그대로인지.
    func testEditCancellationAfterScrollingPreservesTheRecord() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"])
        openRecordDetailEdit(app)

        // 원본 값을 기억한다.
        let seatField = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        let originalSeat = seatField.value as? String ?? ""
        XCTAssertFalse(originalSeat.isEmpty, "원본 좌석이 비어 있어 비교할 수 없다")

        // 값을 바꾸고, 폼을 맨 위에서 떨어뜨린다.
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

        // 다시 열면 원래 값이 그대로다.
        scrollIntoView(app, node(app, "recordDetail.edit")).tap()
        assertEditorIsOpen(app, editing: true)
        let reopened = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        XCTAssertEqual(reopened.value as? String ?? "", originalSeat, "취소한 값이 다시 살아났다")
    }

    /// 새로 만들다 취소하면 기록이 생기지 않는다.
    func testCreateCancellationCreatesNoRecord() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "empty"])
        XCTAssertTrue(waits(node(app, "feed.empty")), "빈 피드 픽스처가 적용되지 않았다")
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertEditorIsOpen(app, editing: false)

        let seat = scrollIntoView(app, app.textFields["좌석"].firstMatch)
        seat.tap()
        seat.typeText("만들다 취소")
        if app.buttons["Return"].exists { app.buttons["Return"].tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
        app.swipeUp()

        dismissSheetFromNavigationBar(app)

        XCTAssertTrue(app.staticTexts["직관 기록 추가"].waitForNonExistence(timeout: 10),
                      "생성 편집기를 닫지 못했다")
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertTrue(node(app, "feed.empty").exists, "취소했는데 기록이 생겼다")
    }

    // MARK: - 3. 시즌 아카이브 상세 진입

    private func openStatistics(_ fixture: String) -> XCUIApplication {
        let app = launch(["-VFUITestInitialTab", "statistics", "-VFUITestStatisticsFixture", fixture])
        XCTAssertTrue(waits(node(app, "statistics.scenario.\(fixture)")), "\(fixture) 픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "statistics.root")), "시즌 화면이 뜨지 않았다")
        return app
    }

    /// 통계가 0건이어도 구장 상세로 들어갈 수 있고, 그 빈 상태의 기록 추가가 열린다.
    func testStadiumDetailIsReachableWithZeroStatistics() {
        // 구장이 적히지 않은 기록만 있는 시즌. 요약도 상세도 구장이 0건이다.
        let app = openStatistics("noStadium")
        let row = node(app, "statistics.highlight.mostVisitedStadium")
        scrollIntoView(app, row).tap()

        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "구장 상세의 빈 상태가 없다")
        let cta = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch
        scrollIntoView(app, cta).tap()

        assertEditorIsOpen(app, editing: false)
        // 구장을 지어내지 않는다.
        XCTAssertFalse(text(app, "잠실야구장").exists, "없는 구장을 지어냈다")
        XCTAssertFalse(text(app, "대구 삼성 라이온즈 파크").exists, "주 관람 구장을 끌어왔다")

        dismissSheetFromNavigationBar(app)
        XCTAssertTrue(app.staticTexts["직관 기록 추가"].waitForNonExistence(timeout: 10))
        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "취소 후 구장 상세로 돌아오지 못했다")
    }

    /// 통계가 0건이어도 상대팀 상세로 들어갈 수 있고, 그 빈 상태의 기록 추가가 열린다.
    /// 상대팀 상세도 요약 값과 무관하게 들어갈 수 있다.
    ///
    /// 지금 픽스처 가운데 상대팀 통계가 0건이 되는 것이 없어서(모든 기록에 상대팀이
    /// 적혀 있다) 빈 상태 자체는 여기서 확인하지 못한다. 확인하는 것은 **잠기지
    /// 않는다**는 것 — 예전에는 요약 값이 없으면 줄 자체가 비활성이었다.
    func testOpponentDetailIsReachableRegardlessOfSummaryValue() {
        let app = openStatistics("noStadium")
        let row = node(app, "statistics.highlight.mostFacedOpponent")
        scrollIntoView(app, row).tap()
        XCTAssertTrue(waits(app.navigationBars["상대팀별 통계"]), "상대팀 상세로 들어가지 못했다")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(waits(node(app, "statistics.root")), "뒤로 가기가 되지 않는다")
    }

    /// 값이 있을 때의 동작은 그대로다 — 상세로 들어가면 목록이 나오고 빈 상태가 아니다.
    func testPopulatedStatisticsDetailsStayCorrect() {
        let app = openStatistics("referenceSeason")
        // 요약 값이 그대로 계산된다.
        XCTAssertTrue(node(app, "statistics.winRate").exists, "승률이 사라졌다")

        let stadiumRow = node(app, "statistics.highlight.mostVisitedStadium")
        scrollIntoView(app, stadiumRow).tap()
        XCTAssertFalse(text(app, "아직 구장별 통계가 없어요").exists, "값이 있는데 빈 상태가 떴다")
        XCTAssertTrue(waits(text(app, "대구 삼성 라이온즈 파크")), "구장 목록이 없다")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(waits(node(app, "statistics.root")), "뒤로 가기가 되지 않는다")
        let opponentRow = node(app, "statistics.highlight.mostFacedOpponent")
        scrollIntoView(app, opponentRow).tap()
        XCTAssertFalse(text(app, "아직 상대팀별 통계가 없어요").exists, "값이 있는데 빈 상태가 떴다")
    }
}
