import XCTest

/// 좁은 폭과 실제 AccessibilityXXXL에서 **응원 팀 변경** 시트가 그대로 쓸 수 있는지.
///
/// 확인하는 것은 존재가 아니라 쓸 수 있음이다. 뱃지가 이름을 덮지 않는지, 선택 표시가
/// 계속 보이는지, 스크롤해도 초안이 살아 있고 그 사이 커밋이 일어나지 않는지까지 본다.
final class TeamSelectionResponsiveUITests: XCTestCase {

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

    /// 위 크롬 아래에서 시작하는, 실제로 쓸 수 있는 구간.
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
        return CGRect(x: window.minX, y: top, width: window.width, height: max(0, window.maxY - top))
    }

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

    /// 옵션이 보일 때까지만 민다. 스크롤 자체가 커밋을 일으키면 안 된다.
    /// `LazyVGrid`는 화면 밖 항목을 만들지 않는다. 큰 글자에서 카드가 커지면 아래쪽
    /// 팀은 계층에 아예 없으므로, **존재를 먼저 기다리면 영원히 실패한다**(실측: SE 3
    /// AccessibilityXXXL). 그래서 밀면서 나타나기를 기다린다.
    @discardableResult
    private func scrollToOption(_ app: XCUIApplication, _ teamID: String,
                                file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let option = node(app, "teamSelection.team.\(teamID)")
        for _ in 0..<16 {
            if option.exists, option.isHittable { return option }
            app.swipeUp()
        }
        // 아래로 지나쳤을 수 있다. 되돌아오며 한 번 더 찾는다.
        for _ in 0..<16 {
            if option.exists, option.isHittable { return option }
            app.swipeDown()
        }
        XCTAssertTrue(option.exists && option.isHittable,
                      "\(teamID) 옵션에 닿을 수 없다 — exists=\(option.exists)",
                      file: file, line: line)
        return option
    }

    // MARK: - 진입

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestDisplayName", "민지"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// 마이 탭을 열고 응원 팀 변경 시트까지 들어간다. 모두 제품 경로다.
    @discardableResult
    private func openSelector(teamID: String = "samsung-lions",
                              catalog: String? = nil,
                              forceTabs: Bool = false,
                              accessibilitySize: Bool = false) -> XCUIApplication {
        var extra = ["-VFUITestTeamID", teamID]
        if let catalog { extra += ["-VFUITestTeamCatalog", catalog] }
        if forceTabs { extra += ["-VFUITestProfileFixture", "noTeam"] }
        let app = launch(extra, accessibilitySize: accessibilitySize)
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "마이 화면이 열리지 않았다")
        node(app, "profile.teamChange").tap()
        XCTAssertTrue(waits(node(app, "teamSelection.root"), 10), "팀 선택 시트가 열리지 않았다")
        return app
    }

    // MARK: - 1~3. 기본 배치와 초안

    func testS01_theCurrentTeamIsSelectedAndFits() {
        let app = openSelector()
        let option = scrollToOption(app, "samsung-lions")
        XCTAssertTrue(option.isSelected, "지금 응원 팀이 선택돼 있지 않다")
        assertInsideWidth(app, option, "선택된 옵션")
    }

    func testS02_anAlternateDraftShowsExactlyOneSelection() {
        let app = openSelector()
        scrollToOption(app, "lg-twins").tap()
        XCTAssertTrue(node(app, "teamSelection.team.lg-twins").isSelected, "초안이 선택되지 않았다")
        XCTAssertFalse(node(app, "teamSelection.team.samsung-lions").isSelected,
                       "예전 팀이 아직 선택돼 있다 — 선택이 둘이다")
    }

    func testS03_scrollingPreservesTheDraftAndCommitsNothing() {
        let app = openSelector()
        scrollToOption(app, "lg-twins").tap()
        for _ in 0..<3 { app.swipeUp() }
        for _ in 0..<3 { app.swipeDown() }
        // 지연 격자는 화면 밖 항목을 버린다. 다시 끌어온 뒤에 상태를 읽는다.
        XCTAssertTrue(scrollToOption(app, "lg-twins").isSelected,
                      "스크롤하자 초안이 사라졌다")
        // 아직 커밋되지 않았다 — 취소하면 원래 팀 그대로다.
        node(app, "teamSelection.cancel").tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertTrue(node(app, "profile.team").label.contains("삼성"),
                      "스크롤 중에 커밋이 일어났다 — \(node(app, "profile.team").label)")
    }

    // MARK: - 4~6. 방어 상태

    func testS04_anInvalidStoredTeamSelectsNothingAndDisablesCompletion() {
        let app = openSelector(teamID: "retired-team", forceTabs: true)
        for teamID in ["samsung-lions", "lg-twins", "kia-tigers"] {
            XCTAssertFalse(node(app, "teamSelection.team.\(teamID)").isSelected,
                           "풀리지 않는 값인데 \(teamID)이 선택돼 있다")
        }
        XCTAssertFalse(app.buttons["teamSelection.done"].isEnabled,
                       "유효한 초안이 없는데 완료를 누를 수 있다")
    }

    func testS05_anExplicitChoiceEnablesCompletionFromTheInvalidState() {
        let app = openSelector(teamID: "retired-team", forceTabs: true)
        XCTAssertFalse(app.buttons["teamSelection.done"].isEnabled)
        scrollToOption(app, "lg-twins").tap()
        XCTAssertTrue(app.buttons["teamSelection.done"].isEnabled,
                      "고른 뒤에도 완료가 잠겨 있다")
    }

    func testS06_anEmptyCatalogIsHonestAndDisablesCompletion() {
        let app = openSelector(catalog: "empty")
        XCTAssertTrue(waits(node(app, "teamSelection.empty")), "빈 상태가 없다")
        XCTAssertTrue(text(app, "보여 줄 팀이 없어요").exists, "빈 상태 문구가 없다")
        XCTAssertFalse(app.buttons["teamSelection.done"].isEnabled, "빈 목록인데 완료가 열려 있다")
        XCTAssertTrue(app.buttons["teamSelection.cancel"].isHittable, "빈 목록에서 취소할 수 없다")
    }

    // MARK: - 7~8. 긴 이름과 최대 목록

    func testS07_longTeamNamesWrapInsteadOfClipping() {
        let app = openSelector(catalog: "longNames")
        let option = scrollToOption(app, "samsung-lions")
        assertInsideWidth(app, option, "긴 이름 옵션")
        XCTAssertTrue(option.label.contains("아주아주긴이름"), "긴 이름이 적용되지 않았다")
    }

    func testS08_everyTeamInTheFullCatalogIsReachable() {
        let app = openSelector(catalog: "maximum")
        for teamID in ["lg-twins", "doosan-bears", "samsung-lions", "kia-tigers",
                       "ssg-landers", "kt-wiz", "nc-dinos", "lotte-giants",
                       "kiwoom-heroes", "hanwha-eagles"] {
            let option = scrollToOption(app, teamID)
            assertInsideWidth(app, option, teamID)
        }
    }

    // MARK: - 9~11. 의미와 크롬

    func testS09_optionsCarryStableIdentifiersAndSelectedTraits() {
        let app = openSelector()
        let option = node(app, "teamSelection.team.samsung-lions")
        XCTAssertTrue(waits(option), "안정된 식별자로 옵션을 찾지 못한다")
        XCTAssertTrue(option.isSelected, "선택 상태가 접근성에 노출되지 않는다")
        XCTAssertTrue(option.label.contains("선택됨"), "선택을 색으로만 말한다")
    }

    func testS10_onboardingCopyAndNeutralOptionStayAbsent() {
        let app = openSelector()
        for forbidden in ["어느 팀의 승리요정인가요", "선택한 팀 컬러가 앱 테마에 반영돼요",
                          "나중에 설정에서 변경할 수 있어요", "선택 안 함", "아직 못 정했어요"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 시트에 있다")
        }
    }

    func testS11_theSheetStaysBelowItsNavigationChrome() {
        let app = openSelector()
        let viewport = usableViewport(app)
        let option = settled(node(app, "teamSelection.team.lg-twins"))
        XCTAssertGreaterThanOrEqual(option.maxY, viewport.minY,
                                    "첫 옵션이 내비게이션 크롬에 완전히 가렸다 — \(option)")
        XCTAssertTrue(app.buttons["teamSelection.cancel"].isHittable, "취소에 닿을 수 없다")
        XCTAssertTrue(app.buttons["teamSelection.done"].isHittable, "완료에 닿을 수 없다")
    }

    // MARK: - 12~15. 좁은 폭 (SE 3에서만 뜻이 있다)

    func testCompact01_theSelectorFitsTheNarrowScreen() throws {
        let app = openSelector()
        try requireCompactWidth(app)
        assertInsideWidth(app, scrollToOption(app, "samsung-lions"), "선택된 옵션")
        assertInsideWidth(app, scrollToOption(app, "hanwha-eagles"), "마지막 옵션")
    }

    func testCompact02_longNamesFitTheNarrowScreen() throws {
        let app = openSelector(catalog: "longNames")
        try requireCompactWidth(app)
        assertInsideWidth(app, scrollToOption(app, "samsung-lions"), "긴 이름 옵션")
    }

    func testCompact03_scrolledStateKeepsSelectionVisible() throws {
        let app = openSelector()
        try requireCompactWidth(app)
        scrollToOption(app, "lg-twins").tap()
        for _ in 0..<4 { app.swipeUp() }
        for _ in 0..<4 { app.swipeDown() }
        XCTAssertTrue(node(app, "teamSelection.team.lg-twins").isSelected,
                      "좁은 폭에서 스크롤하자 선택이 사라졌다")
    }

    func testCompact04_completionAndCancellationStayReachable() throws {
        let app = openSelector()
        try requireCompactWidth(app)
        XCTAssertTrue(app.buttons["teamSelection.cancel"].isHittable, "취소에 닿을 수 없다")
        XCTAssertTrue(app.buttons["teamSelection.done"].isHittable, "완료에 닿을 수 없다")
    }

    // MARK: - 16~17. AccessibilityXXXL

    func testAccessibility01_theCategoryActuallyApplies() {
        let base = openSelector()
        let baseHeight = settled(scrollToOption(base, "samsung-lions")).height
        base.terminate()

        let large = openSelector(accessibilitySize: true)
        let largeHeight = settled(scrollToOption(large, "samsung-lions")).height
        XCTAssertGreaterThan(largeHeight, baseHeight * 1.2,
                             "AccessibilityXXXL이 적용되지 않았다 — \(baseHeight) vs \(largeHeight)")
    }

    func testAccessibility02_everyControlStaysUsableAtTheLargestType() {
        let app = openSelector(accessibilitySize: true)
        let option = scrollToOption(app, "samsung-lions")
        assertInsideWidth(app, option, "큰 글자 옵션")
        XCTAssertTrue(option.isSelected, "큰 글자에서 선택 상태가 사라졌다")
        XCTAssertTrue(app.buttons["teamSelection.cancel"].isHittable, "큰 글자에서 취소에 닿을 수 없다")
        XCTAssertTrue(app.buttons["teamSelection.done"].isHittable, "큰 글자에서 완료에 닿을 수 없다")
        assertInsideWidth(app, scrollToOption(app, "hanwha-eagles"), "큰 글자 마지막 옵션")
    }
}
