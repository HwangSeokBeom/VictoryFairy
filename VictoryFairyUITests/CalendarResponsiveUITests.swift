import XCTest

/// 좁은 폭과 아주 큰 글자에서 캘린더가 실제로 쓸 수 있는지 확인한다.
///
/// 스크린샷은 "보기에 괜찮다"까지만 말해 준다. 여기서는 화면이 자리를 잡은 뒤의
/// 실제 좌표를 재서, 넘치거나 가려지거나 닿을 수 없는 곳이 없는지 확인한다.
final class CalendarResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    @discardableResult
    private func launch(
        _ fixture: String,
        accessibilitySize: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "calendar",
            "-VFUITestCalendarFixture", fixture
        ]
        if accessibilitySize {
            arguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더에 들어가지 못했다", file: file, line: line)
        XCTAssertTrue(
            waits(node(app, "calendar.scenario.\(fixture)")),
            "픽스처 \(fixture)가 적용되지 않았다", file: file, line: line
        )
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func day(_ app: XCUIApplication, _ iso: String) -> XCUIElement {
        node(app, "calendar.day.\(iso)")
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

    /// 격자는 `LazyVGrid`라 보이지 않는 줄은 아직 만들어지지 않는다. 큰 글자에서는
    /// 한 화면에 두세 줄만 들어가므로, 아래쪽 날짜는 스크롤해야 비로소 생긴다.
    /// "닿을 수 있다"는 요구는 스크롤을 포함한다.
    @discardableResult
    private func scrollToDay(
        _ app: XCUIApplication, _ iso: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let element = day(app, iso)
        if element.waitForExistence(timeout: 3), element.isHittable { return element }
        for _ in 0..<10 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(element.exists, "\(iso) 칸에 스크롤해도 닿을 수 없다", file: file, line: line)
        return element
    }

    /// 화면 전체 폭. 좁은 기기인지 여기서 확인한다.
    private func viewport(_ app: XCUIApplication) -> CGRect {
        app.windows.element(boundBy: 0).frame
    }

    private let aprilDates = (1...30).map { String(format: "2026-04-%02d", $0) }

    // MARK: - 좁은 폭

    /// 이 묶음은 좁은 기기에서만 뜻이 있다. 넓은 기기에서 돌면 통과 표시가 사실을 가린다.
    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = viewport(app).width
        guard width <= 390 else {
            throw XCTSkip("좁은 폭 검증은 375pt급 기기에서만 유효하다. 현재 폭 \(width)pt")
        }
    }

    func testR01_compactRootAndHeaderStayInsideTheViewport() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        let root = settled(node(app, "calendar.root"))
        XCTAssertGreaterThanOrEqual(root.minX, screen.minX - 1, "루트가 왼쪽으로 넘친다")
        XCTAssertLessThanOrEqual(root.maxX, screen.maxX + 1, "루트가 오른쪽으로 넘친다")

        let title = settled(node(app, "calendar.monthTitle"))
        XCTAssertLessThanOrEqual(title.maxX, screen.maxX + 1, "월 제목이 화면 밖으로 나간다")
    }

    func testR02_monthControlsDoNotOverlapTheTitle() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let title = settled(node(app, "calendar.monthTitle"))
        let previous = settled(node(app, "calendar.previousMonth"))
        let next = settled(node(app, "calendar.nextMonth"))

        XCTAssertGreaterThanOrEqual(previous.minX, title.maxX - 1, "이전 달 버튼이 제목과 겹친다")
        XCTAssertGreaterThanOrEqual(next.minX, previous.maxX - 1, "두 화살표가 서로 겹친다")
        XCTAssertLessThanOrEqual(next.maxX, viewport(app).maxX + 1, "다음 달 버튼이 화면 밖이다")
        XCTAssertTrue(previous.width >= 40 && previous.height >= 40, "이전 달 버튼이 44pt에 못 미친다")
        XCTAssertTrue(next.width >= 40 && next.height >= 40, "다음 달 버튼이 44pt에 못 미친다")
    }

    func testR03_allSevenColumnsAndEveryCellStayInsideTheGrid() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let grid = settled(node(app, "calendar.grid"))
        let screen = viewport(app)
        XCTAssertLessThanOrEqual(grid.maxX, screen.maxX + 1, "격자가 화면 밖으로 넘친다")

        var columnCentres: Set<Int> = []
        for iso in aprilDates {
            let cell = settled(day(app, iso))
            XCTAssertGreaterThanOrEqual(cell.minX, grid.minX - 1, "\(iso) 칸이 격자 왼쪽을 벗어난다")
            XCTAssertLessThanOrEqual(cell.maxX, grid.maxX + 1, "\(iso) 칸이 격자 오른쪽을 벗어난다")
            XCTAssertGreaterThan(cell.width, 0)
            columnCentres.insert(Int(cell.midX.rounded()))
        }
        XCTAssertEqual(columnCentres.count, 7, "열이 7개가 아니다: \(columnCentres.sorted())")
    }

    /// 선택 원이 자기 칸 안에 머물러야 옆 날짜를 침범하지 않는다.
    ///
    /// 같은 주 안의 좌우 이웃과 비교한다. 4월 12일은 일요일이라 첫 열이고, 그 "왼쪽"은
    /// 윗줄 맨 오른쪽이다. 줄이 다른 칸과 가로 위치를 비교하면 뜻이 없다.
    func testR04_selectedCircleStaysInsideItsOwnCell() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)

        let midWeek = day(app, "2026-04-15")   // 수요일. 좌우 모두 같은 줄에 있다.
        XCTAssertTrue(waits(midWeek))
        midWeek.tap()
        XCTAssertTrue(day(app, "2026-04-15").isSelected, "고른 날짜가 선택되지 않았다")

        let selected = settled(day(app, "2026-04-15"))
        let left = settled(day(app, "2026-04-14"))
        let right = settled(day(app, "2026-04-16"))

        // 같은 줄인지는 세로로 겹치는가로 본다. 기록이나 선택 표시가 있는 칸은 점까지
        // 포함해 더 길어서, 가운데 좌표는 같은 줄이어도 어긋난다.
        XCTAssertTrue(selected.intersects(left.insetBy(dx: -selected.width, dy: 0)),
                      "왼쪽 이웃이 같은 줄이 아니다")
        XCTAssertTrue(selected.intersects(right.insetBy(dx: -selected.width, dy: 0)),
                      "오른쪽 이웃이 같은 줄이 아니다")
        XCTAssertGreaterThanOrEqual(selected.minX, left.maxX - 1, "선택 표시가 왼쪽 칸을 침범한다")
        XCTAssertLessThanOrEqual(selected.maxX, right.minX + 1, "선택 표시가 오른쪽 칸을 침범한다")

        // 첫 열에서도 격자 왼쪽 경계를 넘지 않아야 한다.
        let grid = settled(node(app, "calendar.grid"))
        let firstColumn = settled(day(app, "2026-04-12"))
        XCTAssertGreaterThanOrEqual(firstColumn.minX, grid.minX - 1, "첫 열 선택 표시가 격자를 벗어난다")
    }

    func testR05_legendAndSelectedDetailStayInsideTheViewport() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["calendar.legend", "calendar.selectedDetail", "calendar.detailRecord"] {
            let frame = settled(node(app, identifier))
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1, "\(identifier)이 왼쪽으로 넘친다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier)이 오른쪽으로 넘친다")
        }
    }

    func testR06_gridIsNotWrappedInAHorizontalScrollView() throws {
        let app = launch("compactReference")
        try requireCompactWidth(app)
        let grid = settled(node(app, "calendar.grid"))
        let first = settled(day(app, "2026-04-05"))
        app.swipeLeft()
        usleep(400_000)
        let afterGrid = settled(node(app, "calendar.grid"))
        let afterFirst = settled(day(app, "2026-04-05"))
        XCTAssertEqual(grid.minX, afterGrid.minX, accuracy: 1,
                       "옆으로 쓸었더니 격자가 움직였다. 가로 스크롤이 생겼다")
        XCTAssertEqual(first.minX, afterFirst.minX, accuracy: 1,
                       "옆으로 쓸었더니 날짜 칸이 움직였다")
    }

    func testR07_selectedDetailActionRemainsReachableAfterScrolling() throws {
        let app = launch("selectedEmptyDate")
        try requireCompactWidth(app)
        let action = node(app, "calendar.detailAddRecord")
        XCTAssertTrue(waits(action), "기록 추가 버튼이 없다")
        if !action.isHittable {
            app.swipeUp()
            usleep(400_000)
        }
        XCTAssertTrue(action.isHittable, "스크롤해도 기록 추가 버튼에 닿을 수 없다")
        let tabBar = settled(app.buttons["tab.calendar"])
        XCTAssertLessThanOrEqual(settled(action).maxY, tabBar.minY + 1,
                                 "기록 추가 버튼이 탭 바에 가린다")
    }

    // MARK: - AccessibilityXXXL

    /// 큰 글자가 정말 적용됐는지 화면에서 확인한다.
    ///
    /// 실행 인자 값을 잘못 적어도 앱은 그냥 기본 크기로 뜬다. 그러면 이 묶음 전체가
    /// 보통 크기를 검사하면서 통과해, 확인했다는 표시만 남고 사실은 아무것도
    /// 확인하지 않은 상태가 된다. 캡처를 보고서야 알아챈 적이 있어 관문을 둔다.
    private func requireAccessibilitySize(
        _ app: XCUIApplication,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let title = settled(node(app, "calendar.monthTitle"), file: file, line: line)
        XCTAssertGreaterThan(
            title.height, 40,
            "큰 글자가 적용되지 않았다. 월 제목 높이 \(title.height)pt는 기본 크기 수준이다",
            file: file, line: line
        )
    }

    func testR08_accessibilityRootRemainsScrollableAndControlsHittable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(waits(node(app, "calendar.root")))
        XCTAssertTrue(node(app, "calendar.previousMonth").isHittable, "이전 달 버튼에 닿을 수 없다")
        XCTAssertTrue(node(app, "calendar.nextMonth").isHittable, "다음 달 버튼에 닿을 수 없다")
        XCTAssertTrue(node(app, "calendar.monthTitle").exists, "월 제목이 사라졌다")
        XCTAssertFalse(node(app, "calendar.monthTitle").label.isEmpty)
    }

    func testR09_accessibilityDateCellsRemainHittableAndSelectable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let target = scrollToDay(app, "2026-04-20")
        XCTAssertGreaterThanOrEqual(settled(target).height, 32, "날짜 칸이 너무 작아졌다")
        XCTAssertTrue(target.isHittable, "큰 글자에서 날짜를 누를 수 없다")
        target.tap()
        XCTAssertTrue(day(app, "2026-04-20").isSelected, "큰 글자에서 선택이 되지 않는다")
    }

    func testR10_accessibilityGridStillFitsTheViewportWidth() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let screen = viewport(app)
        let grid = settled(node(app, "calendar.grid"))
        XCTAssertLessThanOrEqual(grid.maxX, screen.maxX + 1, "큰 글자에서 격자가 화면 밖으로 넘친다")
        // 세로로는 스크롤해서 닿으면 된다. 가로로 넘치는지가 확인할 값이다.
        for iso in ["2026-04-01", "2026-04-15", "2026-04-30"] {
            let cell = settled(scrollToDay(app, iso))
            XCTAssertLessThanOrEqual(cell.maxX, screen.maxX + 1, "\(iso) 칸이 화면 밖이다")
            XCTAssertGreaterThanOrEqual(cell.minX, screen.minX - 1)
        }
    }

    func testR11_accessibilitySelectedDetailRemainsReachableAndReadable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let detail = node(app, "calendar.selectedDetail")
        for _ in 0..<6 where !detail.exists || !detail.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(waits(detail), "큰 글자에서 선택일 상세에 닿을 수 없다")
        XCTAssertTrue(text(app, containing: "4월 12일").exists, "선택일 제목을 읽을 수 없다")
        XCTAssertTrue(text(app, containing: "삼성").exists, "팀 이름을 읽을 수 없다")
        XCTAssertTrue(text(app, containing: "잠실").exists, "구장 이름을 읽을 수 없다")
    }

    func testR12_accessibilityRecordDetailActionRemainsReachable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let card = node(app, "calendar.detailRecord")
        for _ in 0..<6 where !card.exists || !card.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(waits(card), "큰 글자에서 기록 카드에 닿을 수 없다")
        XCTAssertTrue(card.isHittable, "기록 카드를 누를 수 없다")
    }

    func testR13_accessibilityRecordCreateActionRemainsReachable() {
        let app = launch("selectedEmptyDate", accessibilitySize: true)
        requireAccessibilitySize(app)
        let action = node(app, "calendar.detailAddRecord")
        for _ in 0..<6 where !action.exists || !action.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(waits(action), "큰 글자에서 기록 추가 버튼이 사라졌다")
        XCTAssertTrue(action.isHittable, "큰 글자에서 기록 추가 버튼을 누를 수 없다")
    }

    func testR14_accessibilityLegendAndTabBarRemainUsable() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let legend = node(app, "calendar.legend")
        for _ in 0..<5 where !legend.exists {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(waits(legend), "큰 글자에서 범례가 사라졌다")
        for tab in ["home", "calendar", "my"] {
            XCTAssertTrue(app.buttons["tab.\(tab)"].isHittable, "큰 글자에서 \(tab) 탭을 누를 수 없다")
        }
    }

    /// 큰 글자에서도 날짜의 의미는 값으로 남는다. 잘려서 사라지지 않는다.
    func testR15_accessibilitySemanticsSurviveTheLargestTextSize() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(waits(day(app, "2026-04-12")))
        let value = (day(app, "2026-04-12").value as? String) ?? ""
        XCTAssertTrue(value.contains("선택됨"), "큰 글자에서 선택 상태가 전달되지 않는다: \(value)")
        XCTAssertTrue(value.contains("승"), "큰 글자에서 결과가 전달되지 않는다: \(value)")
        XCTAssertFalse(day(app, "2026-04-12").label.isEmpty, "날짜 이름이 비었다")
    }
}
