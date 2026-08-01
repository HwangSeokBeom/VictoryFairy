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
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
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

    /// 생성 경로가 여는 세 단계 흐름의 1단계인지.
    private func assertWizardIsOpen(_ app: XCUIApplication, origin: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waits(node(app, "recordCreate.origin.\(origin)")),
                      "\(origin) 경로로 열리지 않았다", file: file, line: line)
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다", file: file, line: line)
        XCTAssertFalse(text(app, "필수 정보").exists, "생성 경로가 아직 한 장짜리 폼을 연다", file: file, line: line)
        for forbidden in ["임시저장", "날씨", "먹은 것", "응원 준비물", "0 / 500"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 생겼다", file: file, line: line)
        }
    }

    /// 눈에 보이는 취소로 흐름을 닫는다. 제스처는 큰 글자에서 통하지 않는다.
    private func cancelWizard(_ app: XCUIApplication) {
        if app.keyboards.element.exists {
            app.swipeDown()
            _ = app.keyboards.element.waitForNonExistence(timeout: 4)
        }
        let cancel = node(app, "recordCreate.cancel")
        XCTAssertTrue(waits(cancel), "흐름에 눈에 보이는 취소가 없다")
        XCTAssertTrue(cancel.isHittable, "취소를 누를 수 없다 — 화면 밖으로 밀렸다")
        cancel.tap()
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
        let startDraft = app.buttons.matching(
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

    /// 기록이 0건이면 AI 도우미가 없다 — 의도된 데이터 의존 부재다.
    ///
    /// 승리요정 지수는 기록에서 계산하는 통계이고 카드도 `dashboard.isEmpty`가
    /// 아닐 때만 그려진다. 데이터가 없는데 지수를 보여 주면 없는 사실을 지어내는
    /// 것이 된다. 그래서 "최근 기록 없음 → 생성 모드" 가지는 걷어냈고, 기록이 없을
    /// 때의 동선은 홈의 "오늘의 직관 남기기"가 갖는다.
    func testHomeAIPreflightWithoutRecentRecordHasNoHelperEntry() {
        let app = launch(["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "empty"])
        XCTAssertTrue(waits(node(app, "screen.feed")))
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "home.root")), "홈이 뜨지 않았다")

        for _ in 0..<12 { app.swipeUp() }
        XCTAssertFalse(app.buttons["AI 직관 기록 도우미"].exists,
                       "기록이 0건인데 AI 도우미 버튼이 생겼다 — 지수를 지어내고 있다")
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
        assertWizardIsOpen(app, origin: "feed")

        // 값을 적고 키보드를 띄운 채로 나간다.
        let score = scrollIntoView(app, node(app, "recordCreate.score.our"))
        score.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 8), "키보드가 올라오지 않았다")
        score.typeText("7")
        node(app, "recordCreate.score.done").tap()
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)

        cancelWizard(app)

        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "생성 흐름을 닫지 못했다")
        XCTAssertTrue(waits(node(app, "screen.feed")), "취소 후 피드로 돌아오지 못했다")
        XCTAssertTrue(node(app, "feed.empty").exists, "취소했는데 기록이 생겼다")

        // 다시 열면 새 초안이다 — 앞서 적은 값이 되살아나지 않는다.
        scrollIntoView(app, node(app, "feed.addRecord")).tap()
        assertWizardIsOpen(app, origin: "feed")
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.score.our")).value as? String ?? "", "",
                       "취소한 값이 다음 생성에 되살아났다")
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
        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch
        scrollIntoView(app, cta).tap()

        assertWizardIsOpen(app, origin: "statisticsStadium")
        // 구장을 지어내지 않는다. 1단계는 여전히 직접 고르라고 말한다.
        XCTAssertFalse(text(app, "잠실야구장").exists, "없는 구장을 지어냈다")
        XCTAssertFalse(text(app, "대구 삼성 라이온즈 파크").exists, "주 관람 구장을 끌어왔다")
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.stadium")).value as? String ?? "",
                       "선택하지 않음", "구장이 미리 채워졌다")

        cancelWizard(app)
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "흐름을 빠져나갈 수 없다")
        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "취소 후 구장 상세로 돌아오지 못했다")
    }

    /// 통계가 0건이어도 상대팀 상세로 들어갈 수 있고, 그 빈 상태의 기록 추가가 열린다.
    /// 상대팀 통계가 0건이어도 상세로 들어갈 수 있고, 그 빈 상태의 기록 추가가 열린다.
    ///
    /// `noOpponent` 픽스처는 대진이 적히지 않은 기록만 담는다. 상대팀 이름을
    /// 지어내지 않으므로 상대팀 통계가 정직하게 0건이 된다.
    func testOpponentDetailIsReachableWithZeroStatistics() {
        let app = openStatistics("noOpponent")
        let row = node(app, "statistics.highlight.mostFacedOpponent")
        scrollIntoView(app, row).tap()

        XCTAssertTrue(waits(text(app, "아직 상대팀별 통계가 없어요")), "상대팀 상세의 빈 상태가 없다")
        let cta = app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch
        scrollIntoView(app, cta).tap()

        assertWizardIsOpen(app, origin: "statisticsOpponent")
        // 상대팀을 지어내지 않는다.
        for fabricated in ["KIA 타이거즈", "LG 트윈스", "두산 베어스"] {
            XCTAssertFalse(text(app, fabricated).exists, "없는 상대팀 \(fabricated)을 지어냈다")
        }
        XCTAssertEqual(scrollIntoView(app, node(app, "recordCreate.field.opponentTeam")).value as? String ?? "",
                       "선택하지 않음", "상대팀이 미리 채워졌다")

        cancelWizard(app)
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "흐름을 빠져나갈 수 없다")
        XCTAssertTrue(waits(text(app, "아직 상대팀별 통계가 없어요")), "취소 후 상대팀 상세로 돌아오지 못했다")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(waits(node(app, "statistics.root")), "뒤로 가기가 되지 않는다")
    }

    // MARK: - 4. 시즌 아카이브 빈 상태 · AccessibilityXXXL

    private func launchStatistics(_ fixture: String, accessibilitySize: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestInitialTab", "statistics",
                         "-VFUITestStatisticsFixture", fixture]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "statistics.scenario.\(fixture)")), "\(fixture) 픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "statistics.root")), "시즌 화면이 뜨지 않았다")
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

    /// 큰 글자가 실제로 적용됐는지. 기본 크기의 같은 요소와 견준다.
    private func assertAccessibilityCategoryApplied(_ fixture: String, rowIdentifier: String) -> CGFloat {
        let normal = launchStatistics(fixture, accessibilitySize: false)
        let baseline = settled(scrollIntoView(normal, node(normal, rowIdentifier))).height
        normal.terminate()
        XCTAssertGreaterThan(baseline, 0, "기준 높이를 재지 못했다")
        return baseline
    }

    /// 구장 빈 상태 경로를 큰 글자에서 확인한다.
    func testStadiumEmptyRouteAtAccessibilityXXXL() {
        let baseline = assertAccessibilityCategoryApplied("noStadium",
                                                          rowIdentifier: "statistics.highlight.mostVisitedStadium")
        let app = launchStatistics("noStadium", accessibilitySize: true)
        let row = scrollIntoView(app, node(app, "statistics.highlight.mostVisitedStadium"))
        XCTAssertGreaterThan(settled(row).height, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt")
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(settled(row).maxX, screen.maxX + 0.5, "행이 가로로 잘렸다")
        row.tap()

        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "큰 글자에서 빈 제목이 없다")
        XCTAssertTrue(text(app, "직관 기록을 추가하면").exists, "큰 글자에서 빈 설명이 없다")
        let cta = scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch)
        XCTAssertLessThanOrEqual(settled(cta).maxX, screen.maxX + 0.5, "CTA가 가로로 잘렸다")
        cta.tap()

        assertWizardIsOpen(app, origin: "statisticsStadium")
        XCTAssertFalse(text(app, "잠실야구장").exists, "없는 구장을 지어냈다")
        cancelWizard(app)
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "큰 글자에서 흐름을 빠져나갈 수 없다")
        XCTAssertTrue(waits(text(app, "아직 구장별 통계가 없어요")), "취소 후 구장 상세로 돌아오지 못했다")
    }

    /// 상대팀 빈 상태 경로를 큰 글자에서 확인한다.
    func testOpponentEmptyRouteAtAccessibilityXXXL() {
        let baseline = assertAccessibilityCategoryApplied("noOpponent",
                                                          rowIdentifier: "statistics.highlight.mostFacedOpponent")
        let app = launchStatistics("noOpponent", accessibilitySize: true)
        let row = scrollIntoView(app, node(app, "statistics.highlight.mostFacedOpponent"))
        XCTAssertGreaterThan(settled(row).height, baseline * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — 기본 \(baseline)pt")
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(settled(row).maxX, screen.maxX + 0.5, "행이 가로로 잘렸다")
        row.tap()

        XCTAssertTrue(waits(text(app, "아직 상대팀별 통계가 없어요")), "큰 글자에서 빈 제목이 없다")
        XCTAssertTrue(text(app, "직관 기록을 추가하면").exists, "큰 글자에서 빈 설명이 없다")
        let cta = scrollIntoView(app, app.buttons.matching(
            NSPredicate(format: "label CONTAINS %@", "첫 직관 기록하기")).firstMatch)
        XCTAssertLessThanOrEqual(settled(cta).maxX, screen.maxX + 0.5, "CTA가 가로로 잘렸다")
        cta.tap()

        assertWizardIsOpen(app, origin: "statisticsOpponent")
        for fabricated in ["KIA 타이거즈", "LG 트윈스", "두산 베어스"] {
            XCTAssertFalse(text(app, fabricated).exists, "없는 상대팀 \(fabricated)을 지어냈다")
        }
        cancelWizard(app)
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "큰 글자에서 흐름을 빠져나갈 수 없다")
        XCTAssertTrue(waits(text(app, "아직 상대팀별 통계가 없어요")), "취소 후 상대팀 상세로 돌아오지 못했다")
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
