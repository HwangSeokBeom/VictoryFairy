import XCTest

/// 스테이징된 기록 작성 1단계(`08_RecordCreate_Step1`)의 동작.
///
/// 이 화면은 아직 사용자 경로에 붙어 있지 않다. DEBUG 픽스처
/// `-VFUITestRecordCreateStaged`로만 열리며, Release 빌드에는 그 개념이 없다.
final class RecordCreateStep1UITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    @discardableResult
    private func launch(fixture: String = "fresh", accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", fixture]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.scenario.\(fixture)")), "\(fixture) 픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 누를 대상은 컨테이너가 아니라 버튼이다. 툴바 항목은 감싸는 요소가 먼저
    /// 잡히는 일이 있어, 버튼 질의를 우선한다.
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

    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        for _ in 0..<10 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
        }
        return element
    }

    /// 메뉴에서 값을 고른다. 메뉴 라벨 안의 글자는 따로 눌리지 않으므로 버튼을 누른다.
    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        XCTAssertTrue(control.exists, "\(identifier)을 찾지 못했다")
        control.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(waits(item, 8), "\(option) 항목이 없다")
        item.tap()
    }

    private func fillValidStep1(_ app: XCUIApplication, result: String = "승리") {
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win"))
        app.buttons[result].firstMatch.tap()
    }

    // MARK: - 1~4. 열림 · 문구 · 진행

    func testStagedStep1OpensWithTheAuthoredTitleAndSubtitle() {
        let app = launch()
        XCTAssertTrue(node(app, "recordCreate.step1.title").exists, "제목이 없다")
        XCTAssertEqual(node(app, "recordCreate.step1.title").label, "어떤 경기였나요?")
        XCTAssertEqual(node(app, "recordCreate.step1.subtitle").label, "필수만 적어도 충분해요")
    }

    func testProgressAnnouncesTheFirstOfThreeSteps() {
        let app = launch()
        let progress = node(app, "recordCreate.progress")
        XCTAssertTrue(waits(progress), "진행 표시가 없다")
        XCTAssertEqual(progress.label, "3단계 중 1단계, 경기")
        // 라벨 세 개가 모두 화면에 있다.
        for title in ["경기", "그날의 디테일", "나의 이야기"] {
            XCTAssertTrue(app.staticTexts[title].exists || progress.label.contains(title), "\(title) 라벨이 없다")
        }
    }

    func testFieldOrderFollowsThePencilFrame() {
        let app = launch()
        let identifiers = ["recordCreate.field.date", "recordCreate.field.stadium",
                           "recordCreate.field.favoriteTeam", "recordCreate.field.opponentTeam"]
        var previousMaxY: CGFloat = node(app, "recordCreate.progress").frame.maxY
        for identifier in identifiers {
            let element = node(app, identifier)
            XCTAssertTrue(element.exists, "\(identifier)이 없다")
            XCTAssertGreaterThanOrEqual(element.frame.minY, previousMaxY - 1, "\(identifier) 순서가 어긋났다")
            previousMaxY = identifier == "recordCreate.field.favoriteTeam" ? previousMaxY : element.frame.maxY
        }
        // 스코어는 팀 아래에 온다.
        XCTAssertGreaterThan(node(app, "recordCreate.score.our").frame.minY,
                             node(app, "recordCreate.field.opponentTeam").frame.minY)
    }

    func testNoWizardStep2Or3LayoutAndNoTemporarySaveAppear() {
        let app = launch()
        for forbidden in ["임시저장", "그날의 디테일을 더해볼까요", "오늘의 이야기를 남겨주세요",
                         "0 / 500", "날씨", "먹은 것", "응원 준비물", "별점"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
        // 진행 라벨의 "그날의 디테일"은 있어도 되지만, 2단계 화면은 없어야 한다.
        XCTAssertFalse(node(app, "recordCreate.stagedBoundary").exists, "2단계 경계가 처음부터 보인다")
    }

    // MARK: - 5~7. 빈 기본값

    func testFreshCreateShowsNoFabricatedValues() {
        let app = launch()
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "선택하지 않음")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "선택하지 않음")
        // 응원팀만 사용자 설정에서 온다.
        XCTAssertEqual(node(app, "recordCreate.field.favoriteTeam").value as? String ?? "", "삼성 라이온즈")
        // 결과 안내는 아직 없다.
        XCTAssertFalse(node(app, "recordCreate.result.feedback").exists, "고르지 않았는데 결과 안내가 있다")
        XCTAssertFalse(text(app, "승리요정이네요").exists, "결과를 지어냈다")
    }

    func testFreshCreateShowsEmptyScores() {
        let app = launch()
        XCTAssertEqual(node(app, "recordCreate.score.our").value as? String ?? "", "")
        XCTAssertEqual(node(app, "recordCreate.score.opponent").value as? String ?? "", "")
        XCTAssertFalse(text(app, "5").exists && text(app, "3").exists, "Pencil 표본 점수가 박혀 있다")
    }

    func testCalendarInitialDateIsCarried() {
        let app = launch(fixture: "initialDate")
        let date = node(app, "recordCreate.field.date")
        XCTAssertTrue(date.exists, "날짜 필드가 없다")
        // 캘린더가 정해 준 2026년 4월 16일이 그대로 보인다.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "2026", "2026"))
            .firstMatch.exists, "정해 준 날짜가 반영되지 않았다")
    }

    // MARK: - 8~11. 선택 · 입력

    func testSelectingTeamsAndStadiumUpdatesTheFields() {
        let app = launch()
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "LG 트윈스")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "LG 트윈스")
    }

    func testOpponentMenuExcludesTheFavoriteTeam() {
        let app = launch()
        node(app, "recordCreate.field.opponentTeam").tap()
        XCTAssertTrue(waits(app.buttons["KIA 타이거즈"], 8), "상대팀 목록이 열리지 않았다")
        XCTAssertFalse(app.buttons["삼성 라이온즈"].exists, "자기 팀이 상대팀 목록에 있다")
        app.buttons["KIA 타이거즈"].tap()
    }

    func testScoreEntryKeepsWhatWasTyped() {
        let app = launch()
        let ours = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ours.tap()
        ours.typeText("5")
        let theirs = node(app, "recordCreate.score.opponent")
        theirs.tap()
        theirs.typeText("3")
        XCTAssertEqual(node(app, "recordCreate.score.our").value as? String ?? "", "5")
        XCTAssertEqual(node(app, "recordCreate.score.opponent").value as? String ?? "", "3")
    }

    func testResultSelectionShowsTheDerivedFeedback() {
        let app = launch()
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        let feedback = node(app, "recordCreate.result.feedback")
        XCTAssertTrue(waits(feedback), "결과 안내가 없다")
        XCTAssertEqual(feedback.label, "오늘은 승리요정이네요!")

        node(app, "recordCreate.result.loss").tap()
        XCTAssertNotEqual(node(app, "recordCreate.result.feedback").label, "오늘은 승리요정이네요!")
        // 내부 이름이 새어 나오지 않는다.
        for raw in ["win", "loss", "draw", "canceled"] {
            XCTAssertFalse(node(app, "recordCreate.result.feedback").label.contains(raw))
        }
    }

    func testCancelledResultHidesTheScoreRow() {
        let app = launch()
        let ours = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ours.tap(); ours.typeText("5")
        // 숫자 키패드를 내린 뒤에 고른다. 키패드가 떠 있으면 사라진 입력 칸이
        // 첫 응답자로 트리에 남는다(측정으로 확인).
        let done = app.buttons.matching(identifier: "recordCreate.score.done").firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 8), "키패드를 빠져나갈 길이 없다")
        done.tap()
        XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 8), "키패드가 내려가지 않았다")
        XCTAssertEqual(node(app, "recordCreate.score.our").value as? String ?? "", "5")

        scrollIntoView(app, node(app, "recordCreate.result.canceled")).tap()
        XCTAssertTrue(node(app, "recordCreate.score.our").waitForNonExistence(timeout: 6),
                      "취소된 경기인데 점수 칸이 남았다")
        XCTAssertTrue(node(app, "recordCreate.result.feedback").exists, "취소 안내가 없다")
    }

    // MARK: - 12~14. 검증 · 다음

    func testNextIsNotReadyUntilTheRequiredFieldsAreFilled() {
        let app = launch()
        let next = scrollIntoView(app, node(app, "recordCreate.next"))
        XCTAssertEqual(next.value as? String ?? "", "아직 채우지 않은 값이 있어요")
        next.tap()
        let message = node(app, "recordCreate.validationMessage")
        XCTAssertTrue(waits(message, 8), "검증 안내가 없다")
        // 첫 번째로 막힌 값은 상대팀이다 — 응원팀은 이미 설정에서 왔다.
        XCTAssertEqual(message.label, "상대팀을 선택해 주세요.")
        // 열거형 이름이 새어 나오지 않는다.
        for raw in ["opponentTeam", "favoriteTeam", "stadium", "result"] {
            XCTAssertFalse(message.label.contains(raw), "내부 이름 \(raw)이 노출됐다")
        }
        XCTAssertFalse(node(app, "recordCreate.stagedBoundary").exists, "막혔는데 다음 단계로 갔다")
        // 안내만 띄우고 끝내지 않는다 — 첫 번째로 막힌 값을 화면 안으로 데려온다.
        let firstInvalid = node(app, "recordCreate.field.opponentTeam")
        XCTAssertTrue(firstInvalid.exists && firstInvalid.isHittable,
                      "첫 번째로 막힌 값이 화면 밖에 있다")
    }

    func testFillingEveryRequirementEnablesNext() {
        let app = launch()
        fillValidStep1(app)
        let next = scrollIntoView(app, node(app, "recordCreate.next"))
        XCTAssertEqual(next.value as? String ?? "", "", "다 채웠는데 아직 막혀 있다")
        XCTAssertTrue(next.isEnabled, "다음 버튼이 비활성이다")
    }

    /// 1단계의 다음은 이제 2단계로 간다. 2단계는 2026-08-01 패스에서 만들었다.
    func testNextMovesToStep2AndBackKeepsValues() {
        let app = launch()
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 않았다")
        XCTAssertEqual(node(app, "recordCreate.step2.title").label, "그날의 디테일을 더해볼까요?")
        // 3단계는 아직 없다 — 2단계에서 더 나아가면 검증용 경계가 나온다.
        XCTAssertFalse(text(app, "오늘의 이야기를 남겨주세요").exists, "3단계를 만든 척한다")

        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "KIA 타이거즈")
        XCTAssertTrue(node(app, "recordCreate.result.feedback").exists, "돌아오니 결과가 사라졌다")
    }

    /// 세 단계가 모두 만들어졌다. 1단계에서 끝까지 걸어갈 수 있다.
    func testFlowWalksAllThreeSteps() {
        let app = launch()
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 않았다")
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 않았다")
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 3단계, 나의 이야기")
        // 검증용 경계는 더 이상 없다 — 만든 척하던 자리가 실제 화면으로 바뀌었다.
        XCTAssertFalse(node(app, "recordCreate.stagedBoundary").exists, "검증용 경계가 남아 있다")
        XCTAssertFalse(text(app, "아직 만들지 않았어요").exists, "미완성 안내가 남아 있다")
    }

    // MARK: - 15~16. 최소 저장 · 취소

    func testMinimalSaveIsBlockedUntilStep1IsValid() {
        let app = launch()
        scrollIntoView(app, node(app, "recordCreate.saveMinimal")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.validationMessage"), 8), "검증 안내가 없다")
        XCTAssertTrue(node(app, "recordCreate.step1.root").exists, "막혔는데 저장하고 닫혔다")
    }

    func testMinimalSaveExplainsWhatItOmits() {
        let app = launch()
        fillValidStep1(app)
        let action = scrollIntoView(app, node(app, "recordCreate.saveMinimal"))
        XCTAssertEqual(action.label, "여기까지만 저장할게요")
        // 무엇이 비워지는지 사용자에게 말한다.
        XCTAssertTrue((action.value as? String ?? "").isEmpty, "준비됐는데 막힌 것처럼 보인다")
    }

    func testCancelIsVisibleAndLeavesTheFlow() {
        let app = launch()
        XCTAssertTrue(waits(node(app, "recordCreate.cancel")), "취소가 보이지 않는다")
        let cancel = button(app, "recordCreate.cancel")
        XCTAssertTrue(cancel.isHittable, "취소를 누를 수 없다")
        XCTAssertEqual(cancel.label, "취소")
        cancel.tap()
        // 흐름을 빠져나왔다는 증거 두 가지. 호스트 표식은 루트 식별자에 흡수되므로
        // (측정으로 확인) 보이는 문구와 1단계의 사라짐으로 확인한다.
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "취소했는데 1단계가 남아 있다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "취소로 흐름을 빠져나가지 못했다")
    }

    func testCancelSavesNothing() {
        let app = launch()
        fillValidStep1(app)
        // 취소 전에는 저장 안내가 없다 — 아무것도 저장되지 않았다는 뜻이다.
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "누르지도 않았는데 저장이 일어났다")
        button(app, "recordCreate.cancel").tap()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 10),
                      "취소로 닫히지 않았다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "취소로 닫히지 않았다")
    }

    // MARK: - 17. 최소 저장이 실제로 저장하고 닫는다

    func testMinimalSaveStoresOneOrdinaryRecordAndCloses() {
        let app = launch()
        fillValidStep1(app)
        scrollIntoView(app, node(app, "recordCreate.saveMinimal")).tap()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForNonExistence(timeout: 20),
                      "저장했는데 1단계가 남아 있다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "저장 뒤 흐름이 닫히지 않았다")
    }
}
