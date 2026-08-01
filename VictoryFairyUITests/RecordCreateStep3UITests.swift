import XCTest

/// 스테이징된 기록 작성 3단계(`08_RecordCreate_Step3`)의 동작.
///
/// 3단계는 1·2단계를 지나야 나오므로 모든 테스트가 실제 흐름을 밟아 들어간다.
final class RecordCreateStep3UITests: XCTestCase {

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
    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        let pinned = ["recordCreate.step3.complete", "recordCreate.back", "recordCreate.cancel"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<14 {
            guard element.exists else { app.swipeUp(); continue }
            let frame = element.frame
            let bar = app.buttons.matching(identifier: "recordCreate.step3.complete").firstMatch
            let ceiling = (pinned.contains(element.identifier) || !bar.exists)
                ? window.maxY : min(window.maxY, bar.frame.minY)
            if element.isHittable, frame.minY >= window.minY, frame.maxY <= ceiling { return element }
            if frame.maxY > ceiling { app.swipeUp() } else { app.swipeDown() }
        }
        return element
    }

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

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons.matching(identifier: "recordCreate.step3.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
    }

    /// 1단계가 비어 있는 채로 마지막 단계에 서 있는 상태를 연다.
    ///
    /// 제품 흐름으로는 닿을 수 없는 자리다 — 1단계의 `다음`이 막기 때문이다.
    /// 완성 버튼의 방어 검증만 확인하기 위한 DEBUG 픽스처다.
    @discardableResult
    private func launchIncompleteAtMemory() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VFUITest", "-VFUITestReset",
                               "-VFUITestTeamID", "samsung-lions",
                               "-VFUITestStadiumID", "daegu-lions",
                               "-VFUITestOnboardingCompleted", "1",
                               "-VFUITestRecordCreateStaged", "incompleteAtMemory"]
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "마지막 단계로 시작하지 못했다")
        return app
    }

    /// 스테이징 흐름을 열고 1·2단계를 지나 3단계까지 간다.
    @discardableResult
    private func launchStep3(accessibilitySize: Bool = false, fillsStep1: Bool = true,
                             viaSkip: Bool = false, photoFixture: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset",
                         "-VFUITestTeamID", "samsung-lions",
                         "-VFUITestStadiumID", "daegu-lions",
                         "-VFUITestOnboardingCompleted", "1",
                         "-VFUITestRecordCreateStaged", "fresh"]
        if let photoFixture {
            arguments += ["-VFUITestRecordCreateStagedPhotos", photoFixture]
        }
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        if fillsStep1 {
            choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
            choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
            scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        }
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 못했다")
        let onward = viaSkip ? "recordCreate.step2.skip" : "recordCreate.step2.next"
        scrollIntoView(app, node(app, onward)).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")), "3단계로 가지 못했다")
        return app
    }

    // MARK: - 1~5. 도착 · 문구 · 진행 · 순서

    func test01_step2NextReachesStep3() {
        let app = launchStep3()
        XCTAssertTrue(node(app, "recordCreate.step3.root").exists)
        XCTAssertTrue(node(app, "recordCreate.step2.root").waitForNonExistence(timeout: 8), "2단계가 남아 있다")
    }

    func test02_step2SkipAlsoReachesStep3() {
        let app = launchStep3(viaSkip: true)
        XCTAssertTrue(node(app, "recordCreate.step3.root").exists, "건너뛰기가 3단계로 오지 않았다")
    }

    func test03_authoredTitleAndSubtitle() {
        let app = launchStep3()
        XCTAssertEqual(node(app, "recordCreate.step3.title").label, "오늘의 이야기를 남겨주세요")
        XCTAssertEqual(node(app, "recordCreate.step3.subtitle").label, "사진 한 장과 짧은 한마디면 충분해요")
    }

    func test04_progressAnnouncesStepThree() {
        let app = launchStep3()
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 3단계, 나의 이야기")
    }

    func test05_fieldOrderAndEmptyDefaults() {
        let app = launchStep3()
        let progress = node(app, "recordCreate.progress").frame
        let title = node(app, "recordCreate.step3.title").frame
        let photo = node(app, "recordCreate.step3.addPhoto").frame
        let moment = node(app, "recordCreate.step3.moment").frame
        let mood = node(app, "recordCreate.step3.mood.happy").frame
        XCTAssertLessThan(progress.maxY, title.minY + 1, "진행 표시가 제목 아래에 있다")
        XCTAssertLessThan(title.maxY, photo.minY + 1, "제목이 사진 아래에 있다")
        XCTAssertLessThan(photo.maxY, moment.minY + 1, "사진이 순간 아래에 있다")
        XCTAssertLessThan(moment.maxY, mood.minY + 1, "순간이 기분 아래에 있다")
        // 빈 기본값. 흐름이 미리 넣어 둔 기분은 다섯 칩 중 어느 것도 아니다.
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "")
        for mood in ["overwhelmed", "happy", "proud", "regret", "annoyed"] {
            XCTAssertFalse(button(app, "recordCreate.step3.mood.\(mood)").isSelected, "\(mood)이 미리 선택됐다")
        }
        XCTAssertFalse(node(app, "recordCreate.step3.removePhoto.1").exists, "사진이 미리 들어 있다")
    }

    // MARK: - 6~10. 입력

    func test06_momentEntryIsKept() {
        let app = launchStep3()
        let field = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        field.tap(); field.typeText("9회초 역전 스리런")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "9회초 역전 스리런")
    }

    func test07_everyMoodOptionSelectsExclusively() {
        let app = launchStep3()
        for (suffix, label) in [("overwhelmed", "벅차오름"), ("happy", "행복"), ("proud", "뿌듯"),
                                ("regret", "아쉬움"), ("annoyed", "약오름")] {
            let chip = scrollIntoView(app, button(app, "recordCreate.step3.mood.\(suffix)"))
            chip.tap()
            XCTAssertTrue(button(app, "recordCreate.step3.mood.\(suffix)").isSelected,
                          "\(label)이 선택 상태를 알리지 않는다")
            for other in ["overwhelmed", "happy", "proud", "regret", "annoyed"] where other != suffix {
                XCTAssertFalse(button(app, "recordCreate.step3.mood.\(other)").isSelected,
                               "\(other)이 함께 선택돼 있다")
            }
        }
    }

    func test08_diaryKeepsMultilineText() {
        let app = launchStep3()
        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        diary.typeText("1회부터 조마조마\n9회 역전")
        dismissKeyboard(app)
        let written = node(app, "recordCreate.step3.diary").value as? String ?? ""
        XCTAssertTrue(written.contains("1회부터 조마조마"), "일기 첫 줄이 사라졌다")
        XCTAssertTrue(written.contains("9회 역전"), "일기 둘째 줄이 사라졌다")
    }

    func test09_diaryHasNoCounterOrLimit() {
        let app = launchStep3()
        XCTAssertFalse(text(app, "0 / 500").exists, "글자 수가 생겼다")
        XCTAssertFalse(text(app, "/ 500").exists, "글자 수 제한이 생겼다")
        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        diary.typeText(String(repeating: "가", count: 60))
        dismissKeyboard(app)
        XCTAssertEqual((node(app, "recordCreate.step3.diary").value as? String ?? "").count, 60, "일기가 잘렸다")
    }

    func test10_addPhotoControlIsPresentAndLabelled() {
        let app = launchStep3()
        let add = scrollIntoView(app, node(app, "recordCreate.step3.addPhoto"))
        XCTAssertTrue(add.exists && add.isHittable, "사진 추가에 닿을 수 없다")
        XCTAssertEqual(add.label, "사진 추가")
        // 파일 경로는 어디에도 노출되지 않는다.
        XCTAssertFalse(text(app, ".jpg").exists)
        XCTAssertFalse(text(app, "/Users/").exists)
    }

    // MARK: - 11~13. 이동과 보존

    func test11_backReachesStep2AndPreservesEverything() {
        let app = launchStep3()
        let moment = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        moment.tap(); moment.typeText("역전")
        dismissKeyboard(app)
        scrollIntoView(app, button(app, "recordCreate.step3.mood.happy")).tap()

        button(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 돌아오지 못했다")
        button(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")

        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "역전", "순간이 사라졌다")
        XCTAssertTrue(button(app, "recordCreate.step3.mood.happy").isSelected, "기분이 사라졌다")
    }

    func test12_cancelFromStep3CreatesNoRecord() {
        let app = launchStep3()
        let moment = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        moment.tap(); moment.typeText("취소 확인")
        dismissKeyboard(app)
        XCTAssertFalse(node(app, "recordCreate.step3.saveMessage").exists, "취소 전에 저장이 일어났다")
        let cancel = button(app, "recordCreate.cancel")
        XCTAssertTrue(cancel.isHittable, "취소를 누를 수 없다")
        cancel.tap()
        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 10), "취소로 닫히지 않았다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "흐름이 닫히지 않았다")
    }

    func test13_noNextOrSkipAfterStep3() {
        let app = launchStep3()
        XCTAssertFalse(node(app, "recordCreate.step2.next").exists, "3단계에 다음이 남아 있다")
        XCTAssertFalse(node(app, "recordCreate.step2.skip").exists, "3단계에 건너뛰기가 남아 있다")
        XCTAssertTrue(node(app, "recordCreate.step3.complete").exists, "완성 버튼이 없다")
    }

    // MARK: - 14~16. 완성

    func test14_completeSavesOneRecordAndDismisses() {
        let app = launchStep3()
        let moment = scrollIntoView(app, node(app, "recordCreate.step3.moment"))
        moment.tap(); moment.typeText("9회 역전")
        dismissKeyboard(app)
        scrollIntoView(app, button(app, "recordCreate.step3.mood.overwhelmed")).tap()

        let complete = scrollIntoView(app, node(app, "recordCreate.step3.complete"))
        XCTAssertEqual(complete.label, "기록 완성하기")
        complete.tap()
        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 20), "저장 뒤 닫히지 않았다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "흐름이 닫히지 않았다")
    }

    func test15_repeatedCompleteTapsDoNotStack() {
        let app = launchStep3()
        let complete = scrollIntoView(app, node(app, "recordCreate.step3.complete"))
        complete.tap()
        // 두 번째 누름은 대개 닿을 곳이 없다 — 첫 저장이 이미 흐름을 닫는다.
        // 아직 남아 있다면 한 번 더 눌러 본다. 그래도 결과는 하나여야 한다.
        if complete.exists, complete.isHittable { complete.tap() }
        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 20), "저장 뒤 닫히지 않았다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")))
        // 닫힌 뒤에는 3단계가 다시 열리지 않는다 — 두 번째 저장이 흐름을 되살리지 않았다.
        XCTAssertFalse(node(app, "recordCreate.step3.root").exists)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "흐름이 닫혔어요")).count, 1,
                       "닫힘 표시가 여러 개다")
    }

    /// 제품 흐름에서는 1단계의 `다음`이 막혀 여기에 닿을 수 없다. 그래도 완성
    /// 버튼은 저장 직전에 스스로 검증하므로, 그 방어 경로를 픽스처로 확인한다.
    func test16_invalidStep1RoutesBackWithTheMessage() {
        let app = launchIncompleteAtMemory()
        scrollIntoView(app, node(app, "recordCreate.step3.diary")).tap()
        app.typeText("일기만 남긴다")
        dismissKeyboard(app)

        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "막혔는데 1단계로 돌아오지 않았다")
        let message = node(app, "recordCreate.validationMessage")
        XCTAssertTrue(waits(message, 8), "검증 안내가 없다")
        XCTAssertEqual(message.label, "상대팀을 선택해 주세요.")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "막혔는데 저장했다")

        // 3단계 값은 그대로 남아 있다.
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        XCTAssertTrue((node(app, "recordCreate.step3.diary").value as? String ?? "").contains("일기만 남긴다"),
                      "되돌아오며 일기가 사라졌다")
    }

    // MARK: - 17~19. 만들지 않은 것

    func test17_ratingAndTemporarySaveAreAbsent() {
        let app = launchStep3()
        for forbidden in ["별점", "몇 점이었나요", "임시저장", "0 / 500"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
        XCTAssertFalse(app.buttons["임시저장"].exists, "임시저장 버튼이 생겼다")
    }

    func test18_assistanceParityIsPresentAndNothingElseIsInvented() {
        let app = launchStep3()
        // 지금 편집기가 이미 가진 두 가지는 3단계에서도 닿을 수 있다.
        XCTAssertTrue(node(app, "recordCreate.step3.analyzePhotos").exists, "사진 분석에 닿을 수 없다")
        XCTAssertTrue(node(app, "recordCreate.step3.aiDraft").exists, "AI 초안에 닿을 수 없다")
        // 1단계가 맡은 것과 없는 기능은 여전히 여기 없다.
        for forbidden in ["경기 선택", "티켓", "KBO", "날씨", "응원 준비물"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden) 표면을 지어냈다")
        }
    }

    func test19_noDuplicateNavigationContainer() {
        let app = launchStep3()
        XCTAssertEqual(app.navigationBars.count, 1, "내비게이션 컨테이너가 둘이다")
        XCTAssertEqual(app.staticTexts.matching(identifier: "recordCreate.step3.title").count, 1, "3단계가 둘이다")
    }
}
