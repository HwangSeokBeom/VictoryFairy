import XCTest

/// 좁은 폭과 실제 AccessibilityXXXL에서 **마이** 탭 루트가 그대로 쓸 수 있는지.
///
/// 확인하는 것은 존재가 아니라 쓸 수 있음이다. 카드가 세로로 자라고, 요정이 글자를
/// 덮지 않고, 모든 행이 위아래 크롬 사이에 남아 있는지까지 잰다.
final class ProfileSettingsResponsiveUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 기기 조건

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

    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 자리를 잡은 뒤의 좌표. 애니메이션 중의 값은 재지 않는다.
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

    /// 위 크롬 아래, 탭 막대 위 — 실제로 손이 닿는 구간.
    private func usableViewport(_ app: XCUIApplication) -> CGRect {
        let window = app.windows.firstMatch.frame
        var top = window.minY
        let bars = app.navigationBars
        for index in 0..<bars.count {
            let bar = bars.element(boundBy: index)
            guard bar.exists else { continue }
            let frame = bar.frame
            guard frame.minY <= window.midY else { continue }
            top = max(top, frame.maxY)
        }
        var bottom = window.maxY
        let tab = app.buttons.matching(identifier: "tab.my").firstMatch
        if tab.exists { bottom = min(bottom, tab.frame.minY) }
        return CGRect(x: window.minX, y: top, width: window.width, height: max(0, bottom - top))
    }

    /// 화면 안으로 끌어오되, 위 크롬에 덮인 상태를 통과시키지 않는다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(waits(element), "요소 자체가 없다", file: file, line: line)
        for _ in 0..<20 {
            let viewport = usableViewport(app)
            let frame = element.frame
            let visible = frame.intersection(viewport)
            let needed = min(44, frame.height)
            if element.isHittable, !visible.isNull, visible.height + 0.5 >= needed { return element }
            if frame.maxY > viewport.maxY { app.swipeUp() } else { app.swipeDown() }
        }
        let viewport = usableViewport(app)
        XCTAssertTrue(element.isHittable,
                      "스크롤해도 쓸 수 있는 구간 안으로 들어오지 않는다 — "
                      + "frame=\(element.frame) 구간=\(viewport)",
                      file: file, line: line)
        return element
    }

    /// 화면 가로 밖으로 나가지 않는다.
    private func assertInsideWidth(_ app: XCUIApplication, _ element: XCUIElement, _ name: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch.frame
        let frame = settled(element)
        XCTAssertGreaterThanOrEqual(frame.minX, window.minX - 0.5,
                                    "\(name)이 왼쪽으로 잘렸다 — \(frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 0.5,
                                 "\(name)이 오른쪽으로 잘렸다 — \(frame)", file: file, line: line)
        XCTAssertGreaterThan(frame.height, 0, "\(name)이 높이 0으로 접혔다", file: file, line: line)
    }

    // MARK: - 진입

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestOnboardingCompleted", "1"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @discardableResult
    private func openMy(_ extra: [String] = [], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(extra, accessibilitySize: accessibilitySize)
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "마이 화면이 열리지 않았다")
        return app
    }

    /// 이름과 팀은 인자로 받는다. 같은 실행 인자를 두 번 넘기면 앞의 값만 읽혀
    /// "긴 이름"을 심었다고 착각하게 된다(실측).
    private func populated(name: String = "민지", teamID: String = "samsung-lions",
                           accessibilitySize: Bool = false) -> XCUIApplication {
        openMy(["-VFUITestTeamID", teamID,
                "-VFUITestStadiumID", "daegu-lions",
                "-VFUITestDisplayName", name],
               accessibilitySize: accessibilitySize)
    }

    /// 팀이 없는 방어 상태. 제품 경로로는 닿을 수 없어 DEBUG 픽스처로만 띄운다.
    private func noTeam(accessibilitySize: Bool = false) -> XCUIApplication {
        openMy(["-VFUITestProfileFixture", "noTeam",
                "-VFUITestDisplayName", "민지"],
               accessibilitySize: accessibilitySize)
    }

    // MARK: - 1~5. 기본 상태들

    func testR01_populatedProfileFitsTheScreen() {
        let app = populated()
        assertInsideWidth(app, node(app, "profile.card"), "프로필 카드")
        assertInsideWidth(app, node(app, "profile.name"), "이름")
        assertInsideWidth(app, node(app, "profile.team"), "팀 요약")
    }

    func testR02_missingDisplayNameStaysReadable() {
        let app = openMy(["-VFUITestTeamID", "samsung-lions",
                          "-VFUITestStadiumID", "daegu-lions"])
        let name = node(app, "profile.name")
        XCTAssertTrue(waits(name), "이름 자리가 없다")
        XCTAssertEqual(name.label, "이름을 정하지 않았어요", "이름이 없는데 지어냈다")
        assertInsideWidth(app, name, "중립 이름")
    }

    func testR03_defensiveNoTeamStateRendersHonestly() {
        let app = noTeam()
        let team = node(app, "profile.team")
        XCTAssertTrue(waits(team), "팀 자리가 없다")
        XCTAssertTrue(team.label.contains("고르지 않"),
                      "팀이 없는데 팀을 지어냈다 — \(team.label)")
        assertInsideWidth(app, team, "팀 없음 상태")
    }

    func testR04_aLongDisplayNameWrapsInsteadOfClipping() {
        let app = populated(name: "야구를정말사랑하는아주긴이름을가진사용자입니다")
        let name = node(app, "profile.name")
        assertInsideWidth(app, name, "긴 이름")
        // 한 줄에 다 들어갈 수 없는 길이다 — 접히지 않고 자라야 한다.
        XCTAssertGreaterThan(settled(name).height, 20, "긴 이름이 한 줄로 잘렸다")
    }

    func testR05_aLongTeamNameStaysInsideTheScreen() {
        let app = populated(teamID: "kiwoom-heroes")
        assertInsideWidth(app, node(app, "profile.team"), "팀 요약")
    }

    // MARK: - 6~9. 의미 구조는 좁은 폭에서도 독립이다

    func testR06_cardChildrenStayIndependentAtEveryWidth() {
        let app = populated()
        for identifier in ["profile.card", "profile.name", "profile.team", "profile.edit"] {
            let matches = app.descendants(matching: .any).matching(identifier: identifier)
            XCTAssertEqual(matches.count, 1, "\(identifier)이 \(matches.count)개로 잡힌다")
        }
    }

    func testR07_theEditButtonKeepsAUsableTarget() {
        let app = populated()
        let edit = app.buttons["profile.edit"]
        XCTAssertTrue(waits(edit), "프로필 수정이 없다")
        XCTAssertTrue(edit.isHittable, "프로필 수정을 누를 수 없다")
        let frame = settled(edit)
        XCTAssertGreaterThanOrEqual(frame.width, 43.5, "수정 버튼 폭이 44pt 아래다 — \(frame)")
        XCTAssertGreaterThanOrEqual(frame.height, 43.5, "수정 버튼 높이가 44pt 아래다 — \(frame)")
    }

    func testR08_theFairyDoesNotOverlapTheName() {
        let app = populated()
        let name = settled(node(app, "profile.name"))
        let edit = settled(app.buttons["profile.edit"])
        // 요정은 이름 왼쪽, 수정은 오른쪽. 서로 겹치지 않는다.
        XCTAssertFalse(name.intersects(edit), "이름과 수정 버튼이 겹친다 — \(name) / \(edit)")
    }

    func testR09_theProfileCardGrowsVerticallyWithItsContent() {
        let short = populated()
        let shortHeight = settled(node(short, "profile.card")).height
        short.terminate()

        let long = populated(name: "야구를정말사랑하는아주긴이름을가진사용자입니다")
        let longHeight = settled(node(long, "profile.card")).height
        XCTAssertGreaterThan(longHeight, shortHeight,
                             "긴 이름인데 카드가 자라지 않았다 — \(shortHeight) vs \(longHeight)")
    }

    // MARK: - 10~14. 모든 행이 닿는다

    func testR10_theTeamChangeRowStaysReachable() {
        let app = populated()
        let row = scrollIntoView(app, node(app, "profile.teamChange"))
        XCTAssertTrue(row.isHittable, "응원 팀 변경을 누를 수 없다")
        assertInsideWidth(app, row, "응원 팀 변경")
    }

    func testR11_everyLegalRowStaysReachable() {
        let app = populated()
        for identifier in ["profile.legal.privacy", "profile.legal.terms",
                           "profile.legal.accountDeletion"] {
            let row = scrollIntoView(app, node(app, identifier))
            XCTAssertTrue(row.isHittable, "\(identifier)을 누를 수 없다")
            assertInsideWidth(app, row, identifier)
        }
    }

    func testR12_theVersionRowStaysReadable() {
        let app = populated()
        let version = scrollIntoView(app, node(app, "profile.appVersion"))
        assertInsideWidth(app, version, "앱 버전")
        XCTAssertFalse(version.label.contains("알 수 없음"), "번들에서 버전을 읽지 못했다")
    }

    func testR13_theLastRowStaysAboveTheTabBar() {
        let app = populated()
        let version = scrollIntoView(app, node(app, "profile.appVersion"))
        let tab = app.buttons["tab.my"]
        XCTAssertTrue(tab.exists, "탭 막대가 없다")
        XCTAssertLessThanOrEqual(settled(version).maxY, settled(tab).minY + 0.5,
                                 "마지막 행이 탭 막대에 가린다")
    }

    func testR14_theFirstRowStaysBelowTheTopChrome() {
        let app = populated()
        let viewport = usableViewport(app)
        let card = settled(node(app, "profile.card"))
        XCTAssertGreaterThanOrEqual(card.minY, viewport.minY - 0.5,
                                    "프로필 카드가 위 크롬 아래에 깔렸다 — \(card) 구간=\(viewport)")
    }

    // MARK: - 15~16. 뒷받침 없는 것은 좁은 폭에서도 없다

    func testR15_unsupportedRowsStayAbsent() {
        let app = populated()
        for forbidden in ["경기 시작 알림", "직관 후 기록 리마인드", "기록 내보내기",
                          "사진 보관함 관리", "추후 제공", "로그아웃"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
    }

    func testR16_theTabRootStillHasNoCloseButton() {
        let app = populated()
        XCTAssertFalse(app.navigationBars.buttons["닫기"].exists, "탭 루트에 닫기가 있다")
    }

    // MARK: - 17~20. 좁은 폭 (SE 3에서만 뜻이 있다)

    func testCompact01_populatedProfileFitsTheNarrowScreen() throws {
        let app = populated()
        try requireCompactWidth(app)
        assertInsideWidth(app, node(app, "profile.card"), "프로필 카드")
        assertInsideWidth(app, node(app, "profile.name"), "이름")
        assertInsideWidth(app, node(app, "profile.team"), "팀 요약")
    }

    func testCompact02_longNamesStayInsideTheNarrowScreen() throws {
        let app = populated(name: "야구를정말사랑하는아주긴이름을가진사용자입니다")
        try requireCompactWidth(app)
        assertInsideWidth(app, node(app, "profile.name"), "긴 이름")
        assertInsideWidth(app, node(app, "profile.team"), "팀 요약")
    }

    func testCompact03_theDefensiveNoTeamStateFitsTheNarrowScreen() throws {
        let app = noTeam()
        try requireCompactWidth(app)
        assertInsideWidth(app, node(app, "profile.team"), "팀 없음 상태")
    }

    func testCompact04_everyRowRemainsReachableOnTheNarrowScreen() throws {
        let app = populated()
        try requireCompactWidth(app)
        for identifier in ["profile.teamChange", "profile.legal.privacy",
                           "profile.legal.terms", "profile.legal.accountDeletion",
                           "profile.appVersion"] {
            let row = scrollIntoView(app, node(app, identifier))
            assertInsideWidth(app, row, identifier)
        }
    }

    // MARK: - 21~22. AccessibilityXXXL

    func testAccessibility01_theCategoryActuallyApplies() {
        let base = populated()
        let baseHeight = settled(node(base, "profile.name")).height
        base.terminate()

        let large = populated(accessibilitySize: true)
        let largeHeight = settled(node(large, "profile.name")).height
        XCTAssertGreaterThan(largeHeight, baseHeight * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — \(baseHeight) vs \(largeHeight)")
    }

    func testAccessibility02_everyRowStaysUsableAtTheLargestType() {
        let app = populated(accessibilitySize: true)
        assertInsideWidth(app, node(app, "profile.card"), "프로필 카드")
        assertInsideWidth(app, node(app, "profile.name"), "이름")
        XCTAssertTrue(app.buttons["profile.edit"].isHittable, "큰 글자에서 수정을 누를 수 없다")
        for identifier in ["profile.teamChange", "profile.legal.privacy",
                           "profile.legal.terms", "profile.legal.accountDeletion",
                           "profile.appVersion"] {
            let row = scrollIntoView(app, node(app, identifier))
            assertInsideWidth(app, row, identifier)
        }
    }
}
