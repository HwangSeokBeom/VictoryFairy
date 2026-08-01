import XCTest

/// 스테이징된 기록 작성 2단계(`08_RecordCreate_Step2`)의 동작.
///
/// 1단계와 같은 DEBUG 픽스처로만 열린다. 2단계는 1단계를 지나야 나오므로, 모든
/// 테스트가 실제 흐름을 밟아 들어간다.
final class RecordCreateStep2UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func button(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let byIdentifier = app.buttons.matching(identifier: identifier).firstMatch
        return byIdentifier.exists ? byIdentifier : node(app, identifier)
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 아래에 고정된 액션 막대 밑에 깔린 요소도 XCUI는 `isHittable`로 본다(실측).
    /// 그래서 창 안에 들어왔는지, 그리고 고정 막대 위에 있는지까지 확인한다.
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        let pinned = ["recordCreate.step2.next", "recordCreate.step2.skip",
                      "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            guard element.exists else { app.swipeUp(); continue }
            let frame = element.frame
            let isPinnedControl = pinned.contains(element.identifier)
            let bar = app.buttons.matching(identifier: "recordCreate.step2.next").firstMatch
            let ceiling = (isPinnedControl || !bar.exists) ? window.maxY : min(window.maxY, bar.frame.minY)
            if element.isHittable, frame.minY >= window.minY, frame.maxY <= ceiling { return element }
            if frame.maxY > ceiling { app.swipeUp() } else { app.swipeDown() }
        }
        return element
    }

    private func launchStagedFlow(accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", "fresh"]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.scenario.fresh")), "픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        return app
    }

    /// 메뉴에서 값을 고른다.
    ///
    /// 큰 글자 + 좁은 폭(SE 3 · AccessibilityXXXL)에서는 목록이 화면보다 길어 아래쪽
    /// 항목이 접근성 트리에 아직 없다(실측). 그럴 때는 목록을 굴려서 찾는다.
    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        control.tap()
        let item = app.buttons[option].firstMatch
        for _ in 0..<8 {
            if item.waitForExistence(timeout: 2) { break }
            app.swipeUp()
        }
        XCTAssertTrue(item.exists, "\(option) 항목이 없다")
        item.tap()
    }

    /// 1단계를 채우고 2단계로 들어간다.
    @discardableResult
    private func enterStep2(_ app: XCUIApplication) -> XCUIApplication {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 들어가지 못했다")
        return app
    }

    private func typeInto(_ app: XCUIApplication, _ identifier: String, _ value: String) {
        let field = scrollIntoView(app, node(app, identifier))
        field.tap()
        field.typeText(value)
        let done = app.buttons.matching(identifier: "recordCreate.step2.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
    }

    // MARK: - 1~5. 열림 · 문구 · 진행 · 순서

    func test01_step1NextReachesStep2() {
        let app = launchStagedFlow()
        enterStep2(app)
        XCTAssertTrue(node(app, "recordCreate.step2.root").exists)
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 8),
                      "1단계가 남아 있다")
    }

    func test02_authoredTitleAndSubtitle() {
        let app = enterStep2(launchStagedFlow())
        XCTAssertEqual(node(app, "recordCreate.step2.title").label, "그날의 디테일을 더해볼까요?")
        XCTAssertEqual(node(app, "recordCreate.step2.subtitle").label, "모두 건너뛰어도 괜찮아요")
    }

    func test03_progressAnnouncesStepTwo() {
        let app = enterStep2(launchStagedFlow())
        let progress = node(app, "recordCreate.progress")
        XCTAssertTrue(waits(progress), "진행 표시가 없다")
        XCTAssertEqual(progress.label, "3단계 중 2단계, 그날의 디테일")
    }

    func test04_fieldOrderFollowsTheFrame() {
        let app = enterStep2(launchStagedFlow())
        let progress = node(app, "recordCreate.progress").frame
        let title = node(app, "recordCreate.step2.title").frame
        let seat = node(app, "recordCreate.field.seat").frame
        let alone = node(app, "recordCreate.companion.alone").frame
        let next = node(app, "recordCreate.step2.next").frame
        let skip = node(app, "recordCreate.step2.skip").frame
        XCTAssertLessThan(progress.maxY, title.minY + 1, "진행 표시가 제목 아래에 있다")
        XCTAssertLessThan(title.maxY, seat.minY + 1, "제목이 좌석 아래에 있다")
        XCTAssertLessThan(seat.maxY, alone.minY + 1, "좌석이 동행 아래에 있다")
        XCTAssertLessThan(alone.maxY, next.minY + 1, "동행이 다음 버튼 아래에 있다")
        XCTAssertLessThan(next.maxY, skip.minY + 1, "다음이 건너뛰기 아래에 있다")
    }

    func test05_emptyDefaults() {
        let app = enterStep2(launchStagedFlow())
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "")
        for option in ["alone", "family", "friend"] {
            XCTAssertFalse(button(app, "recordCreate.companion.\(option)").isSelected,
                           "\(option)이 미리 선택돼 있다")
        }
        XCTAssertFalse(node(app, "recordCreate.companion.customField").exists,
                       "직접 입력 칸이 처음부터 열려 있다")
    }

    // MARK: - 6~11. 좌석과 동행

    func test06_seatEntryIsKept() {
        let app = enterStep2(launchStagedFlow())
        typeInto(app, "recordCreate.field.seat", "3루 내야 K열 24번")
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "3루 내야 K열 24번")
    }

    func test07_eachQuickCompanionOptionSelects() {
        let app = enterStep2(launchStagedFlow())
        for (identifier, label) in [("alone", "혼자"), ("family", "엄마랑"), ("friend", "친구랑")] {
            let chip = scrollIntoView(app, button(app, "recordCreate.companion.\(identifier)"))
            chip.tap()
            XCTAssertTrue(button(app, "recordCreate.companion.\(identifier)").isSelected,
                          "\(label)이 선택 상태를 알리지 않는다")
            // 한 번에 하나만 선택된다.
            for other in ["alone", "family", "friend"] where other != identifier {
                XCTAssertFalse(button(app, "recordCreate.companion.\(other)").isSelected,
                               "\(other)이 함께 선택돼 있다")
            }
        }
    }

    func test08_customCompanionEntry() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.companion.customField")), "직접 입력 칸이 열리지 않았다")
        typeInto(app, "recordCreate.companion.customField", "회사 동료들과")
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "회사 동료들과")
        XCTAssertTrue(button(app, "recordCreate.companion.custom").isSelected, "직접 입력이 선택 상태가 아니다")
    }

    func test09_quickToCustomTransitionReplacesTheValue() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, button(app, "recordCreate.companion.family")).tap()
        XCTAssertTrue(button(app, "recordCreate.companion.family").isSelected)
        button(app, "recordCreate.companion.custom").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.companion.customField")), "직접 입력 칸이 열리지 않았다")
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "",
                       "빠른 선택 값이 직접 입력 칸에 그대로 남았다")
        XCTAssertFalse(button(app, "recordCreate.companion.family").isSelected, "빠른 선택이 아직 선택돼 있다")
    }

    func test10_customToQuickTransitionReplacesTheCustomValue() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        typeInto(app, "recordCreate.companion.customField", "사촌 동생이랑")
        scrollIntoView(app, button(app, "recordCreate.companion.friend")).tap()
        XCTAssertTrue(button(app, "recordCreate.companion.friend").isSelected, "빠른 선택으로 넘어가지 않았다")
        XCTAssertTrue(node(app, "recordCreate.companion.customField").waitForNonExistence(timeout: 6),
                      "직접 입력 칸이 남아 있다")
        XCTAssertFalse(text(app, "사촌 동생이랑").exists, "직접 입력 값이 남아 있다")
    }

    func test11_clearingCustomTextLeavesItEmptyAndOptional() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        typeInto(app, "recordCreate.companion.customField", "친구들")
        let field = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4))
        let done = app.buttons.matching(identifier: "recordCreate.step2.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "")
        // 비어 있어도 계속 나아갈 수 있다.
        XCTAssertTrue(scrollIntoView(app, node(app, "recordCreate.step2.next")).isHittable)
    }

    // MARK: - 12~16. 이동

    func test12_backPreservesStep1AndStep2Values() {
        let app = enterStep2(launchStagedFlow())
        typeInto(app, "recordCreate.field.seat", "3루 K열")
        scrollIntoView(app, button(app, "recordCreate.companion.family")).tap()

        button(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "KIA 타이거즈")
        XCTAssertTrue(node(app, "recordCreate.result.feedback").exists, "1단계 결과가 사라졌다")

        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 다시 들어가지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "3루 K열",
                       "좌석이 사라졌다")
        XCTAssertTrue(button(app, "recordCreate.companion.family").isSelected, "동행 선택이 사라졌다")
    }

    func test13_nextReachesStep3() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 않았다")
        XCTAssertEqual(node(app, "recordCreate.step3.title").label, "오늘의 이야기를 남겨주세요")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "다음이 저장을 했다")
        XCTAssertFalse(node(app, "recordCreate.step3.saveMessage").exists, "다음이 저장을 했다")
    }

    func test14_skipReachesStep3AndKeepsValues() {
        let app = enterStep2(launchStagedFlow())
        typeInto(app, "recordCreate.field.seat", "외야 자유석")
        scrollIntoView(app, button(app, "recordCreate.companion.alone")).tap()

        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "건너뛰기가 3단계로 가지 않았다")
        XCTAssertFalse(node(app, "recordCreate.step3.saveMessage").exists, "건너뛰기가 저장을 했다")

        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "외야 자유석",
                       "건너뛰었더니 좌석이 지워졌다")
        XCTAssertTrue(button(app, "recordCreate.companion.alone").isSelected, "건너뛰었더니 동행이 지워졌다")
    }

    func test15_repeatedNextTapsDoNotStack() {
        let app = enterStep2(launchStagedFlow())
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        // 한 번만 뒤로 누르면 2단계로 돌아온다 — 목적지가 겹쳐 쌓이지 않았다.
        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "목적지가 여러 겹 쌓였다")
    }

    func test16_cancelFromStep2CreatesNoRecord() {
        let app = enterStep2(launchStagedFlow())
        typeInto(app, "recordCreate.field.seat", "1루 응원석")
        let cancel = button(app, "recordCreate.cancel")
        XCTAssertTrue(waits(cancel), "2단계에서 취소가 보이지 않는다")
        XCTAssertTrue(cancel.isHittable, "취소를 누를 수 없다")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "취소 전에 저장이 일어났다")
        cancel.tap()
        XCTAssertTrue(node(app, "recordCreate.step2.root").waitForNonExistence(timeout: 10),
                      "취소로 흐름을 빠져나가지 못했다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "흐름이 닫히지 않았다")
    }

    // MARK: - 17~19. 만들지 않은 것

    func test17_unsupportedSectionsAreAbsent() {
        let app = enterStep2(launchStagedFlow())
        for forbidden in ["날씨", "맑음", "흐림", "밤경기", "먹은 것", "치킨",
                          "응원 준비물", "유니폼", "응원봉", "응원수건", "유광점퍼"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
    }

    func test18_temporarySaveIsAbsent() {
        let app = enterStep2(launchStagedFlow())
        XCTAssertFalse(text(app, "임시저장").exists, "임시저장이 생겼다")
        XCTAssertFalse(app.buttons["임시저장"].exists, "임시저장 버튼이 생겼다")
    }

    func test19_noDuplicateNavigationContainer() {
        let app = enterStep2(launchStagedFlow())
        XCTAssertEqual(app.navigationBars.count, 1, "내비게이션 컨테이너가 둘이다")
        XCTAssertEqual(app.staticTexts.matching(identifier: "recordCreate.step2.title").count, 1,
                       "2단계가 둘이다")
    }
}
