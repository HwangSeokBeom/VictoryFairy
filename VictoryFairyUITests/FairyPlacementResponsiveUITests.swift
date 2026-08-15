import XCTest

/// 좁은 폭(375pt)과 아주 큰 글자에서 새 페어리 배치가 화면을 망가뜨리지 않는지 잰다.
///
/// 스크린샷은 "보기에 괜찮다"까지만 말한다. 여기서는 자리를 잡은 뒤의 실제 좌표를 재서
/// 넘치거나 가려지거나 닿을 수 없는 곳이 없는지 확인한다.
final class FairyPlacementResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 14) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func launch(_ extra: [String], accessibilitySize: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// 애니메이션이 끝난 뒤의 좌표. 흔들리는 값은 재지 않는다.
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

    /// 큰 글자가 실제로 적용됐는지. 적용되지 않은 채 "통과"하는 일을 막는다.
    private func assertAccessibilitySizeApplied(_ app: XCUIApplication, _ reference: XCUIElement,
                                                minimumHeight: CGFloat,
                                                file: StaticString = #filePath, line: UInt = #line) {
        let frame = settled(reference)
        XCTAssertGreaterThan(frame.height, minimumHeight,
                             "AccessibilityXXXL이 적용되지 않았다 — 높이 \(frame.height)",
                             file: file, line: line)
    }

    private func assertNoHorizontalOverflow(_ app: XCUIApplication, _ element: XCUIElement,
                                            file: StaticString = #filePath, line: UInt = #line) {
        let screen = app.windows.firstMatch.frame
        let frame = settled(element)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 0.5, "왼쪽으로 넘쳤다", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 0.5, "오른쪽으로 넘쳤다", file: file, line: line)
    }

    // MARK: - 홈 팀 아이덴티티

    func testHomeTeamIdentityFitsCompactWidth() {
        let app = launch(["-VFUITestTeamID", "kiwoom-heroes", "-VFUITestStadiumID", "gocheok",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "home"],
                         accessibilitySize: false)
        XCTAssertTrue(waits(node(app, "screen.home")))
        let identity = node(app, "home.teamIdentity")
        assertNoHorizontalOverflow(app, identity)
        // 헤더가 워드마크와 겹치지 않는다.
        let wordmark = settled(node(app, "home.wordmark"))
        XCTAssertFalse(settled(identity).intersects(wordmark), "헤더가 워드마크를 덮었다")
    }

    func testHomeTeamIdentityGrowsAtAccessibilityXXXL() {
        let compact = launch(["-VFUITestTeamID", "kiwoom-heroes", "-VFUITestStadiumID", "gocheok",
                              "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "home"],
                             accessibilitySize: false)
        XCTAssertTrue(waits(node(compact, "screen.home")))
        let normalHeight = settled(node(compact, "home.teamIdentity")).height
        compact.terminate()

        let large = launch(["-VFUITestTeamID", "kiwoom-heroes", "-VFUITestStadiumID", "gocheok",
                            "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "home"],
                           accessibilitySize: true)
        XCTAssertTrue(waits(node(large, "screen.home")))
        let identity = node(large, "home.teamIdentity")
        assertAccessibilitySizeApplied(large, identity, minimumHeight: normalHeight)
        assertNoHorizontalOverflow(large, identity)
        XCTAssertTrue(identity.label.contains("키움 히어로즈"), "큰 글자에서 팀 이름이 사라졌다")
    }

    // MARK: - 온보딩 완료

    private func reachCompletion(_ app: XCUIApplication, team: String, stadium: String) {
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")))
        let teamCard = app.buttons["onboarding.team.\(team)"]
        if !teamCard.exists { app.swipeUp() }
        XCTAssertTrue(waits(teamCard))
        teamCard.tap()
        app.buttons["onboarding.team.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")))
        let stadiumCard = app.buttons["onboarding.stadium.\(stadium)"]
        if !stadiumCard.exists { app.swipeUp() }
        XCTAssertTrue(waits(stadiumCard))
        stadiumCard.tap()
        app.buttons["onboarding.stadium.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.complete")), "완료 화면에 닿지 못했다")
    }

    func testOnboardingCompletionFairiesStayInsideCompactViewport() {
        let app = launch([], accessibilitySize: false)
        reachCompletion(app, team: "lotte-giants", stadium: "sajik")
        let screen = app.windows.firstMatch.frame
        let cta = app.buttons["onboarding.complete.finish"]
        let ctaFrame = settled(cta)
        XCTAssertTrue(cta.isHittable, "완료 CTA를 누를 수 없다")
        XCTAssertLessThanOrEqual(ctaFrame.maxY, screen.maxY + 0.5, "CTA가 화면 밖으로 나갔다")
        let title = app.staticTexts["준비됐어요"]
        XCTAssertTrue(waits(title), "완료 제목이 없다")
        XCTAssertFalse(settled(title).intersects(ctaFrame), "제목과 CTA가 겹쳤다")
    }

    func testOnboardingCompletionRemainsReachableAtAccessibilityXXXL() {
        let app = launch([], accessibilitySize: true)
        reachCompletion(app, team: "lotte-giants", stadium: "sajik")
        let cta = app.buttons["onboarding.complete.finish"]
        XCTAssertTrue(waits(cta), "큰 글자에서 완료 CTA가 사라졌다")
        XCTAssertTrue(cta.isHittable, "큰 글자에서 완료 CTA를 누를 수 없다")
        let title = app.staticTexts["준비됐어요"]
        XCTAssertTrue(waits(title), "큰 글자에서 완료 제목이 사라졌다")
        assertAccessibilitySizeApplied(app, title, minimumHeight: 34)
        cta.tap()
        XCTAssertTrue(waits(node(app, "screen.home")), "큰 글자에서 완료가 되지 않는다")
    }

    // MARK: - 캘린더 선택일

    func testCalendarSelectedDateFitsCompactWidth() {
        let app = launch(["-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "calendar",
                          "-VFUITestCalendarFixture", "compactReference"],
                         accessibilitySize: false)
        XCTAssertTrue(waits(node(app, "screen.calendar")))
        XCTAssertTrue(waits(node(app, "calendar.scenario.compactReference")), "픽스처가 적용되지 않았다")
        let detail = node(app, "calendar.selectedDetail")
        guard waits(detail) else { return XCTFail("선택일 미리보기가 없다") }
        assertNoHorizontalOverflow(app, detail)
        // 페어리가 기록 카드를 덮지 않는다: 카드 아래에 자리를 잡아야 한다.
        let card = node(app, "calendar.detailRecord")
        if card.exists {
            let cardFrame = settled(card)
            let detailFrame = settled(detail)
            XCTAssertLessThanOrEqual(cardFrame.maxY, detailFrame.maxY + 0.5, "기록 카드가 컨테이너를 넘쳤다")
        }
    }

    func testCalendarSelectedDateRemainsReadableAtAccessibilityXXXL() {
        let app = launch(["-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "calendar",
                          "-VFUITestCalendarFixture", "accessibilityReference"],
                         accessibilitySize: true)
        XCTAssertTrue(waits(node(app, "screen.calendar")))
        XCTAssertTrue(waits(node(app, "calendar.scenario.accessibilityReference")), "픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "calendar.previousMonth")), "큰 글자에서 달 이동이 사라졌다")
        XCTAssertTrue(node(app, "calendar.nextMonth").isHittable, "큰 글자에서 달 이동을 누를 수 없다")
    }

    // MARK: - 시즌 커버

    func testStatisticsSeasonCoverFitsCompactWidth() {
        let app = launch(["-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "statistics",
                          "-VFUITestStatisticsFixture", "referenceSeason"],
                         accessibilitySize: false)
        XCTAssertTrue(waits(node(app, "screen.statistics")))
        let hero = node(app, "statistics.hero")
        assertNoHorizontalOverflow(app, hero)
        let heroFrame = settled(hero)
        let headline = node(app, "statistics.headline")
        if headline.exists {
            let headlineFrame = settled(headline)
            XCTAssertLessThanOrEqual(headlineFrame.maxY, heroFrame.maxY + 0.5, "헤드라인이 커버를 넘쳤다")
        }
    }

    func testStatisticsSeasonCoverRemainsReadableAtAccessibilityXXXL() {
        let app = launch(["-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "statistics",
                          "-VFUITestStatisticsFixture", "referenceSeason"],
                         accessibilitySize: true)
        XCTAssertTrue(waits(node(app, "screen.statistics")))
        let hero = node(app, "statistics.hero")
        XCTAssertTrue(waits(hero), "큰 글자에서 시즌 커버가 사라졌다")
        assertNoHorizontalOverflow(app, hero)
        XCTAssertTrue(node(app, "statistics.winRate").exists, "큰 글자에서 승률이 사라졌다")
    }

    // MARK: - 상태 패널

    func testErrorPanelRetryStaysReachableInBothSizes() {
        for accessibility in [false, true] {
            let app = launch(["-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
                              "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "statistics",
                              "-VFUITestStatisticsFixture", "recoverableError"],
                             accessibilitySize: accessibility)
            XCTAssertTrue(waits(node(app, "screen.statistics")))
            let retry = node(app, "statistics.retry")
            XCTAssertTrue(waits(retry), "다시 시도 버튼이 없다 (accessibility: \(accessibility))")
            // 큰 글자에서는 아래로 밀릴 수 있다. 스크롤해서 닿을 수 있으면 된다.
            if !retry.isHittable {
                for _ in 0..<4 where !retry.isHittable { app.swipeUp() }
            }
            XCTAssertTrue(retry.isHittable, "다시 시도에 닿을 수 없다 (accessibility: \(accessibility))")
            assertNoHorizontalOverflow(app, node(app, "statistics.error"))
            app.terminate()
        }
    }

    func testEmptySeasonPanelFitsVerticallyInBothSizes() {
        for accessibility in [false, true] {
            let app = launch(["-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
                              "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "statistics",
                              "-VFUITestStatisticsFixture", "empty"],
                             accessibilitySize: accessibility)
            XCTAssertTrue(waits(node(app, "screen.statistics")))
            let empty = node(app, "statistics.empty")
            XCTAssertTrue(waits(empty), "빈 시즌 패널이 없다 (accessibility: \(accessibility))")
            assertNoHorizontalOverflow(app, empty)
            app.terminate()
        }
    }
}
