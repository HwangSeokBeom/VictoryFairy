import XCTest

/// 좁은 폭과 아주 큰 글자에서 기록 상세가 실제로 쓸 수 있는지 확인한다.
///
/// 스크린샷은 "보기에 괜찮다"까지만 말해 준다. 여기서는 화면이 자리를 잡은 뒤의 실제
/// 좌표를 재서, 넘치거나 가려지거나 닿을 수 없는 곳이 없는지 확인한다.
final class RecordDetailResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    @discardableResult
    private func openDetail(
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
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", "populated",
            "-VFUITestRecordDetailFixture", fixture
        ]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()

        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다", file: file, line: line)
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feed.record.'"))
            .firstMatch
        XCTAssertTrue(waits(card), "피드에 누를 기록이 없다", file: file, line: line)
        card.tap()
        XCTAssertTrue(
            waits(node(app, "recordDetail.scenario.\(fixture)")),
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

    private func settled(
        _ element: XCUIElement,
        file: StaticString = #filePath, line: UInt = #line
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
        for _ in 0..<14 {
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

    func testDR01_compactRootAndHeroStayInsideTheViewport() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["recordDetail.root", "recordDetail.media", "recordDetail.scoreboard"] {
            let frame = settled(node(app, identifier))
            XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1, "\(identifier)가 왼쪽으로 넘친다")
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier)가 오른쪽으로 넘친다")
        }
    }

    /// 두 팀 이름과 큰 점수가 서로 겹치지 않는다.
    func testDR02_compactMatchupDoesNotOverlap() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let mine = settled(node(app, "recordDetail.team.samsung-lions"))
        let score = settled(node(app, "recordDetail.score"))
        let opponent = settled(node(app, "recordDetail.opponent.lg-twins"))
        // 가로로 나란히 있으면 왼→가운데→오른쪽 순서가 지켜져야 하고,
        // 세로로 접혔으면 서로 다른 줄에 있어야 한다.
        let horizontal = mine.maxX <= score.minX + 1 && score.maxX <= opponent.minX + 1
        let vertical = mine.maxY <= score.minY + 1 && score.maxY <= opponent.minY + 1
        XCTAssertTrue(horizontal || vertical, "팀 이름과 점수가 겹친다")
    }

    func testDR03_compactScoreboardStaysInsideTheCard() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let card = settled(node(app, "recordDetail.scoreboard"))
        let score = settled(node(app, "recordDetail.score"))
        XCTAssertLessThanOrEqual(score.maxX, card.maxX + 1, "점수가 카드 밖으로 나갔다")
        XCTAssertGreaterThanOrEqual(score.minX, card.minX - 1)
    }

    func testDR04_compactStadiumAndNoteStayInsideTheViewport() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        for identifier in ["recordDetail.stadium.jamsil", "recordDetail.note"] {
            let frame = settled(scrollTo(app, identifier))
            XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "\(identifier)가 화면 밖으로 넘친다")
        }
    }

    /// 구장 카드는 접근성 요소 하나로 묶여 있어, 카드 경계만 재면 **안쪽 글자가 잘려도**
    /// 통과한다. 잠실은 홈 팀이 둘이라 메타 줄이 가장 길다. 그래서 카드가 아니라 카드가
    /// 읽어 주는 문장에 두 정보가 모두 남아 있는지를 확인한다.
    func testDR04b_compactStadiumCaptionKeepsBothLines() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let stadium = scrollTo(app, "recordDetail.stadium.jamsil")
        XCTAssertTrue(stadium.exists)
        let spoken = stadium.label
        XCTAssertTrue(spoken.contains("잠실야구장"), "구장 이름이 사라졌다: \(spoken)")
        XCTAssertTrue(spoken.contains("원정"), "홈·원정 정보가 사라졌다: \(spoken)")
        XCTAssertTrue(spoken.contains("LG 트윈스"), "홈 팀 정보가 사라졌다: \(spoken)")
        XCTAssertTrue(spoken.contains("두산 베어스"), "두 번째 홈 팀이 잘렸다: \(spoken)")

        // 카드는 잘라내기(clip)를 하므로 안쪽 글자가 넘치면 조용히 사라진다.
        // 카드가 설계 최소 높이를 지키고 화면 안에 있는지까지 함께 확인한다.
        let frame = settled(stadium)
        let screen = viewport(app)
        XCTAssertGreaterThanOrEqual(frame.height, 116, "구장 카드가 설계 최소 높이보다 작다")
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, "구장 카드가 화면 밖으로 넘친다")
    }

    /// 긴 일기가 고정 높이에 갇혀 잘리지 않는다.
    func testDR05_compactLongNoteIsNotClipped() throws {
        let app = openDetail("longNote")
        try requireCompactWidth(app)
        let note = settled(scrollTo(app, "recordDetail.note"))
        XCTAssertGreaterThan(note.height, 200, "긴 일기가 고정 높이에 갇혔다")
        var reachedEnd = false
        for _ in 0..<16 where !reachedEnd {
            if text(app, containing: "다음에도 엄마랑").exists { reachedEnd = true; break }
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(reachedEnd, "좁은 폭에서 긴 일기의 끝에 닿을 수 없다")
    }

    func testDR06_compactActionsRemainReachable() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        XCTAssertTrue(scrollTo(app, "recordDetail.share").isHittable, "공유 버튼에 닿을 수 없다")
        XCTAssertTrue(scrollTo(app, "recordDetail.edit").isHittable, "수정 버튼에 닿을 수 없다")
        XCTAssertTrue(node(app, "recordDetail.overflow").isHittable, "더보기에 닿을 수 없다")
    }

    /// 가로 스크롤이 생기면 안 된다. 루트는 세로 스크롤만 한다.
    func testDR07_compactPageDoesNotScrollHorizontally() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let screen = viewport(app)
        let root = settled(node(app, "recordDetail.root"))
        XCTAssertLessThanOrEqual(root.width, screen.width + 1, "루트가 화면보다 넓다")
    }

    /// 마지막 콘텐츠가 탭바 뒤에 갇히지 않는다.
    func testDR08_compactLastContentStaysAboveTheTabBar() throws {
        let app = openDetail("compactReference")
        try requireCompactWidth(app)
        let edit = scrollTo(app, "recordDetail.edit")
        let editFrame = settled(edit)
        let tabBar = settled(app.buttons["tab.feed"])
        XCTAssertTrue(edit.isHittable, "마지막 버튼이 탭바에 가려 닿을 수 없다")
        XCTAssertLessThanOrEqual(editFrame.midY, tabBar.minY, "마지막 버튼의 중심이 탭바 아래에 있다")
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
        let title = settled(node(app, "recordDetail.title"), file: file, line: line)
        XCTAssertGreaterThan(
            title.height, 40,
            "큰 글자가 적용되지 않았다. 제목 높이 \(title.height)pt는 기본 크기 수준이다",
            file: file, line: line
        )
    }

    func testDR09_accessibilityNavigationRemainsUsable() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.isHittable, "뒤로 가기에 닿을 수 없다")
        XCTAssertTrue(node(app, "recordDetail.overflow").isHittable, "더보기에 닿을 수 없다")
    }

    func testDR10_accessibilityMatchupGrowsVerticallyWithoutOverflowing() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let screen = viewport(app)
        let card = settled(scrollTo(app, "recordDetail.scoreboard"))
        XCTAssertLessThanOrEqual(card.maxX, screen.maxX + 1, "큰 글자에서 스코어보드가 옆으로 넘친다")
        let mine = settled(node(app, "recordDetail.team.samsung-lions"))
        let opponent = settled(node(app, "recordDetail.opponent.lg-twins"))
        XCTAssertNotEqual(mine.minY, opponent.minY, "큰 글자인데 두 팀이 같은 줄에 겹쳐 있다")
        XCTAssertLessThanOrEqual(mine.maxX, card.maxX + 1)
        XCTAssertLessThanOrEqual(opponent.maxX, card.maxX + 1)
    }

    func testDR11_accessibilityScoreRemainsUnderstandable() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(node(app, "recordDetail.score").label.contains("6대 3"), "큰 글자에서 점수를 읽을 수 없다")
    }

    func testDR12_accessibilityStadiumRemainsReadable() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        let stadium = scrollTo(app, "recordDetail.stadium.jamsil")
        XCTAssertTrue(stadium.label.contains("잠실야구장"), "구장 이름이 잘렸다: \(stadium.label)")
    }

    func testDR13_accessibilityMediaStateIsAnnounced() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(waits(node(app, "recordDetail.media.photo")), "큰 글자에서 사진 상태가 사라졌다")
    }

    func testDR14_accessibilityNoteRemainsCompleteAndReachable() {
        let app = openDetail("longNote", accessibilitySize: true)
        let note = scrollTo(app, "recordDetail.note")
        XCTAssertTrue(note.exists)
        var reachedEnd = false
        for _ in 0..<20 where !reachedEnd {
            if text(app, containing: "다음에도 엄마랑").exists { reachedEnd = true; break }
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(reachedEnd, "큰 글자에서 긴 일기의 끝에 닿을 수 없다")
    }

    func testDR15_accessibilityActionsRemainReachable() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertTrue(scrollTo(app, "recordDetail.share").isHittable, "큰 글자에서 공유에 닿을 수 없다")
        XCTAssertTrue(scrollTo(app, "recordDetail.edit").isHittable, "큰 글자에서 수정에 닿을 수 없다")
    }

    func testDR16_accessibilityDeleteConfirmationRemainsUsable() {
        let app = openDetail("deleteConfirmation", accessibilitySize: true)
        node(app, "recordDetail.overflow").tap()
        let delete = app.buttons["기록 삭제하기"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 8), "큰 글자에서 삭제 항목이 없다")
        delete.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8), "큰 글자에서 확인 버튼이 없다")
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.isHittable)
        XCTAssertTrue(app.buttons["남겨둘래요"].firstMatch.isHittable)
        app.buttons["남겨둘래요"].firstMatch.tap()
    }

    /// 큰 글자에서도 값의 의미는 남는다. 잘려서 사라지지 않는다.
    func testDR17_accessibilitySemanticsSurviveTheLargestTextSize() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        requireAccessibilitySize(app)
        XCTAssertEqual(node(app, "recordDetail.result").label, "승리")
        XCTAssertEqual(node(app, "recordDetail.team.samsung-lions").label, "나의 팀 삼성 라이온즈")
        XCTAssertEqual(node(app, "recordDetail.title").label, "목이 다 쉰 날")
    }

    /// 화면 전체에 Dynamic Type 상한을 걸지 않는다.
    func testDR18_recordDetailDoesNotCapDynamicType() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let text = try String(
            contentsOf: root.appendingPathComponent("VictoryFairy/Features/RecordDetail/RecordDetailViews.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(text.contains("dynamicTypeSize("), "상세가 글자 크기에 상한을 건다")
        XCTAssertFalse(text.contains("minimumScaleFactor(0.5"), "구조 실패를 축소로 감춘다")
    }
}
