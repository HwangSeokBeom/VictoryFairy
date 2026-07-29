import XCTest

/// 좁은 폭과 아주 큰 글자에서 시즌 아카이브가 실제로 쓸 수 있는지 확인한다.
///
/// 스크린샷은 "보기에 괜찮다"까지만 말해 준다. 여기서는 화면이 자리를 잡은 뒤의 실제
/// 좌표를 재서, 넘치거나 가려지거나 닿을 수 없는 곳이 없는지 확인한다.
final class StatisticsResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    @discardableResult
    private func launch(
        _ fixture: String,
        teamID: String = "samsung-lions",
        accessibilitySize: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "statistics",
            "-VFUITestStatisticsFixture", fixture
        ]
        if accessibilitySize {
            arguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "screen.statistics")), "시즌 화면에 들어가지 못했다", file: file, line: line)
        XCTAssertTrue(
            waits(node(app, "statistics.scenario.\(fixture)")),
            "픽스처 \(fixture)가 적용되지 않았다", file: file, line: line
        )
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 자리를 잡을 때까지 기다린 뒤의 좌표. 애니메이션 중의 값은 재지 않는다.
    private func settled(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> CGRect {
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

    @discardableResult
    private func scrollTo(
        _ app: XCUIApplication, _ identifier: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let element = node(app, identifier)
        if element.waitForExistence(timeout: 3), element.isHittable { return element }
        for _ in 0..<12 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(320_000)
        }
        XCTAssertTrue(element.exists, "\(identifier)에 스크롤해도 닿을 수 없다", file: file, line: line)
        return element
    }

    private func viewport(_ app: XCUIApplication) -> CGRect {
        app.windows.element(boundBy: 0).frame
    }

    /// 이 묶음은 좁은 기기에서만 뜻이 있다. 넓은 기기에서 돌면 통과 표시가 사실을 가린다.
    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = viewport(app).width
        guard width <= 390 else {
            throw XCTSkip("좁은 폭 검증은 375pt급 기기에서만 유효하다. 현재 폭 \(width)pt")
        }
    }

    // MARK: - 좁은 폭

    func testSR01_compactRootAndHeaderStayInsideTheViewport() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["statistics.root", "statistics.title", "statistics.hero"] {
            let frame = settled(node(app, identifier))
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1, "\(identifier)가 왼쪽으로 넘친다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier)가 오른쪽으로 넘친다")
        }
    }

    /// 시즌 선택 칩은 제목과 겹치지 않고 그대로 눌러야 한다.
    func testSR02_compactSeasonSelectorStaysUsable() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let title = settled(node(app, "statistics.title"))
        let selector = settled(node(app, "statistics.selectedSeason"))
        XCTAssertGreaterThanOrEqual(selector.minX, title.maxX - 1, "시즌 칩이 제목과 겹친다")
        XCTAssertTrue(node(app, "statistics.selectedSeason").isHittable, "시즌 칩을 누를 수 없다")
        XCTAssertGreaterThanOrEqual(selector.height, 44, "시즌 칩이 최소 터치 영역보다 작다")
    }

    /// 시즌 커버 안의 큰 승률과 전적이 서로 겹치지 않는다.
    func testSR03_compactHeroMetricsDoNotOverlap() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let hero = settled(node(app, "statistics.hero"))
        let headline = settled(node(app, "statistics.headline"))
        let winRate = settled(node(app, "statistics.winRate"))
        XCTAssertLessThanOrEqual(headline.maxY, winRate.minY + 1, "문장과 승률이 겹친다")
        XCTAssertLessThanOrEqual(winRate.maxY, hero.maxY + 1, "승률이 커버 밖으로 나갔다")
        XCTAssertLessThanOrEqual(winRate.maxX, hero.maxX + 1, "승률이 커버 오른쪽으로 넘친다")
    }

    func testSR04_compactChartsStayInsideTheViewport() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["statistics.distribution", "statistics.trend"] {
            let frame = settled(scrollTo(app, identifier))
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier)가 화면 밖으로 넘친다")
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1)
        }
    }

    /// 범례는 색 없이도 읽혀야 한다. 네 항목이 모두 남는지 확인한다.
    func testSR05_compactLegendKeepsEveryLabel() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["statistics.wins", "statistics.losses", "statistics.draws", "statistics.canceled"] {
            let element = node(app, identifier)
            XCTAssertTrue(waits(element), "\(identifier) 범례가 사라졌다")
            let frame = settled(element)
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier) 범례가 화면 밖이다")
        }
    }

    /// 데이터가 많은 상태에서도 구장 줄이 접혀 들어가고 화면을 넘지 않는다.
    func testSR06_compactStadiumRowsWrapInsteadOfOverflowing() throws {
        let app = launch("allStadiums")
        try requireCompactWidth(app)
        let screen = viewport(app)
        scrollTo(app, "statistics.stadiumAnalysis")
        for id in ["daegu-lions", "gwangju-kia", "incheon-ssg"] {
            let row = settled(scrollTo(app, "statistics.stadium.\(id)"))
            XCTAssertLessThanOrEqual(row.maxX, screen.maxX + 1, "\(id) 줄이 화면 밖으로 넘친다")
            XCTAssertGreaterThanOrEqual(row.height, 44, "\(id) 줄이 최소 터치 영역보다 작다")
        }
    }

    /// 가로 스크롤이 생기면 안 된다. 루트는 세로 스크롤만 한다.
    func testSR07_compactPageDoesNotScrollHorizontally() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        let root = settled(node(app, "statistics.root"))
        XCTAssertLessThanOrEqual(root.width, screen.width + 1, "루트가 화면보다 넓다")
        XCTAssertEqual(app.scrollViews.matching(identifier: "statistics.root").count, 1)
    }

    func testSR08_compactLastContentRemainsReachable() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let report = scrollTo(app, "statistics.seasonReport")
        XCTAssertTrue(report.isHittable, "좁은 폭에서 마지막 버튼에 닿을 수 없다")
    }

    // MARK: - AccessibilityXXXL

    /// 큰 글자가 정말 적용됐는지 화면에서 확인한다.
    ///
    /// 실행 인자 값을 잘못 적어도 앱은 그냥 기본 크기로 뜬다. 그러면 이 묶음 전체가 보통
    /// 크기를 검사하면서 통과해, 확인했다는 표시만 남고 사실은 아무것도 확인하지 않은
    /// 상태가 된다.
    private func requireAccessibilitySize(
        _ app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let title = settled(node(app, "statistics.title"), file: file, line: line)
        XCTAssertGreaterThan(
            title.height, 40,
            "큰 글자가 적용되지 않았다. 제목 높이 \(title.height)pt는 기본 크기 수준이다",
            file: file, line: line
        )
    }

    func testSR09_accessibilityTitleAndSelectorRemainUsable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertFalse(node(app, "statistics.title").label.isEmpty, "제목이 비었다")
        XCTAssertTrue(node(app, "statistics.selectedSeason").isHittable, "큰 글자에서 시즌 칩을 누를 수 없다")
        XCTAssertGreaterThanOrEqual(settled(node(app, "statistics.selectedSeason")).height, 44)
    }

    func testSR10_accessibilityMetricsGrowVerticallyWithoutOverflowing() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let screen = viewport(app)
        let hero = settled(node(app, "statistics.hero"))
        XCTAssertLessThanOrEqual(hero.maxX, screen.maxX + 1, "큰 글자에서 커버가 옆으로 넘친다")
        XCTAssertGreaterThan(hero.height, 200, "큰 글자인데 커버가 세로로 자라지 않았다")
        let winRate = settled(node(app, "statistics.winRate"))
        XCTAssertLessThanOrEqual(winRate.maxX, hero.maxX + 1, "승률이 커버 밖으로 나갔다")
    }

    /// 큰 글자에서는 점 차트 대신 같은 값을 담은 목록으로 바뀌어도 된다.
    /// 어느 쪽이든 달마다의 값에는 닿을 수 있어야 한다.
    func testSR11_accessibilityTrendValuesRemainReachable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let screen = viewport(app)
        for month in [3, 4] {
            let point = scrollTo(app, "statistics.trend.month.\(month)")
            XCTAssertTrue(point.exists, "\(month)월 값에 닿을 수 없다")
            XCTAssertLessThanOrEqual(settled(point).maxX, screen.maxX + 1, "\(month)월 칸이 화면 밖이다")
        }
        XCTAssertTrue(scrollTo(app, "statistics.trend.summary").exists, "흐름 요약에 닿을 수 없다")
    }

    func testSR12_accessibilityChartSummariesRemainReadable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let summary = scrollTo(app, "statistics.distribution.summary")
        XCTAssertTrue(summary.label.contains("전체 8경기"), "분포 요약이 잘렸다: \(summary.label)")
    }

    func testSR13_accessibilityTeamAndStadiumNamesStayReadable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(waits(node(app, "statistics.team.samsung-lions")), "큰 글자에서 팀 표시가 사라졌다")
        let stadium = scrollTo(app, "statistics.stadium.daegu-lions")
        XCTAssertTrue(stadium.label.contains("대구 삼성 라이온즈 파크"), "구장 이름이 잘렸다: \(stadium.label)")
    }

    /// 팀 이름이 잘리지 않도록 큰 글자에서는 라벨 아래로 접힌다.
    ///
    /// 접근성 이름은 잘려도 그대로 남기 때문에, 잘림 자체는 이름으로 잡을 수 없다.
    /// 대신 **줄바꿈이 실제로 일어났는지**를 좌표로 확인한다. 한 줄에 남아 있으면
    /// 큰 글자에서 이름이 말줄임표로 잘린 상태라는 뜻이다.
    func testSR18_accessibilityTeamNameMovesToItsOwnLineInsteadOfTruncating() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let eyebrow = settled(node(app, "statistics.hero.eyebrow"))
        let team = settled(node(app, "statistics.team.samsung-lions"))
        XCTAssertGreaterThanOrEqual(
            team.minY, eyebrow.maxY - 1,
            "큰 글자인데 팀 이름이 라벨과 같은 줄에 남아 잘린다"
        )
        let hero = settled(node(app, "statistics.hero"))
        XCTAssertLessThanOrEqual(team.maxX, hero.maxX + 1, "팀 이름이 커버 밖으로 넘친다")
    }

    /// 기본 글자 크기에서는 Pencil 배치대로 라벨과 팀이 한 줄에 있다.
    func testSR19_defaultSizeKeepsTheTeamMarkOnTheEyebrowRow() {
        let app = launch("compactReference")
        let eyebrow = settled(node(app, "statistics.hero.eyebrow"))
        let team = settled(node(app, "statistics.team.samsung-lions"))
        XCTAssertLessThan(team.minY, eyebrow.maxY, "기본 크기인데 팀 표시가 아래로 내려갔다")
        XCTAssertGreaterThan(team.minX, eyebrow.minX, "팀 표시가 라벨 오른쪽에 있지 않다")
    }

    func testSR14_accessibilityRetryRemainsReachable() {
        let app = launch("recoverableError", accessibilitySize: true)
        let retry = scrollTo(app, "statistics.retry")
        XCTAssertTrue(retry.isHittable, "큰 글자에서 다시 시도 버튼을 누를 수 없다")
        XCTAssertGreaterThanOrEqual(settled(retry).height, 44)
    }

    func testSR15_accessibilityTabBarRemainsUsable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        for tab in ["home", "statistics", "my"] {
            XCTAssertTrue(app.buttons["tab.\(tab)"].isHittable, "큰 글자에서 \(tab) 탭을 누를 수 없다")
        }
    }

    /// 큰 글자에서도 값의 의미는 남는다. 잘려서 사라지지 않는다.
    func testSR16_accessibilitySemanticsSurviveTheLargestTextSize() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertEqual(node(app, "statistics.winRate").label, "승률 71.4퍼센트, 5승 2패 기준")
        XCTAssertEqual(node(app, "statistics.wins").label, "승 5경기")
        XCTAssertEqual(node(app, "statistics.headline").label, "7번 중 5번을 이긴 시즌")
        XCTAssertTrue(text(app, containing: "8경기 · 5승 2패 1무").exists, "큰 글자에서 전적이 사라졌다")
    }

    func testSR17_accessibilityLastContentRemainsReachable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(scrollTo(app, "statistics.seasonReport").isHittable, "큰 글자에서 마지막 버튼에 닿을 수 없다")
    }
}
