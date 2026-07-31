import XCTest

/// 스테이징된 1단계의 시각 증거 18장.
///
/// 이 매트릭스가 증명하는 것은 **지금 만든 1단계 화면이 이렇게 생겼다**는 것이지,
/// 사용자가 이 화면을 볼 수 있다는 것이 아니다. 화면은 아직 DEBUG 픽스처로만 열린다.
///
/// 저장 위치는 `VF_CAPTURE_DIR`, 파일 앞의 기기 꼬리표는 `VF_CAPTURE_TAG`로 정한다.
/// 저장소 안에는 쓰지 않는다.
final class RecordCreateStep1CaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-record-create-step1-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var tag: String {
        let value = ProcessInfo.processInfo.environment["VF_CAPTURE_TAG"]
        return (value?.isEmpty == false) ? value! : "device"
    }

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

    @discardableResult
    private func scrollIntoView(_ app: XCUIApplication, _ element: XCUIElement) -> XCUIElement {
        for _ in 0..<12 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
        }
        return element
    }

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
        // 픽스처가 정말 적용됐는지 먼저 못박는다.
        XCTAssertTrue(waits(node(app, "recordCreate.scenario.\(fixture)")), "\(fixture) 픽스처가 적용되지 않았다")
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계가 열리지 않았다")
        assertStagedStep1IsRendered(app)
        return app
    }

    /// 모든 캡처가 공유하는 전제: 제품 1단계 컴포넌트가 떠 있고, 2·3단계 레이아웃과
    /// `임시저장`과 미지원 항목은 어디에도 없다.
    private func assertStagedStep1IsRendered(_ app: XCUIApplication) {
        XCTAssertTrue(node(app, "recordCreate.step1.title").exists, "1단계 제목이 없다")
        XCTAssertEqual(node(app, "recordCreate.step1.title").label, "어떤 경기였나요?")
        XCTAssertTrue(node(app, "recordCreate.progress").exists, "진행 표시가 없다")
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 1단계, 경기")
        for forbidden in ["임시저장", "그날의 디테일을 더해볼까요", "오늘의 이야기를 남겨주세요",
                          "0 / 500", "날씨", "먹은 것", "응원 준비물", "별점"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
    }

    private func choose(_ app: XCUIApplication, field identifier: String, option: String) {
        let control = scrollIntoView(app, node(app, identifier))
        control.tap()
        let item = app.buttons[option].firstMatch
        XCTAssertTrue(waits(item, 8), "\(option) 항목이 없다")
        item.tap()
    }

    private func selectResult(_ app: XCUIApplication, _ rawValue: String) {
        scrollIntoView(app, node(app, "recordCreate.result.\(rawValue)")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.result.feedback"), 8), "결과 안내가 없다")
    }

    private func typeScore(_ app: XCUIApplication, ours: String, theirs: String) {
        let ourField = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ourField.tap(); ourField.typeText(ours)
        let theirField = node(app, "recordCreate.score.opponent")
        theirField.tap(); theirField.typeText(theirs)
        if app.keyboards.element.exists {
            app.swipeDown()
            _ = app.keyboards.element.waitForNonExistence(timeout: 5)
        }
    }

    private func capture(_ name: String) {
        usleep(900_000)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "\(tag)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = captureDirectory.appendingPathComponent("\(tag)-\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("CAPTURED \(url.path)")
        } catch {
            XCTFail("캡처를 저장하지 못했다: \(error)")
        }
    }

    // MARK: - 1~3. 시작 상태

    func testCapture01to03_entryStates() {
        let empty = launch()
        // 지어낸 값이 하나도 없다.
        XCTAssertEqual(node(empty, "recordCreate.field.stadium").value as? String ?? "", "선택하지 않음")
        XCTAssertEqual(node(empty, "recordCreate.field.opponentTeam").value as? String ?? "", "선택하지 않음")
        XCTAssertFalse(node(empty, "recordCreate.result.feedback").exists, "결과를 지어냈다")
        capture("01-default-empty")

        // 응원팀만 사용자 설정에서 온다.
        XCTAssertEqual(node(empty, "recordCreate.field.favoriteTeam").value as? String ?? "", "삼성 라이온즈")
        capture("02-preferred-team-prefilled")
        empty.terminate()

        let dated = launch(fixture: "initialDate")
        XCTAssertTrue(dated.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "2026", "2026"))
            .firstMatch.exists, "정해 준 날짜가 반영되지 않았다")
        capture("03-calendar-initial-date")
    }

    // MARK: - 4~5. 값 채우기

    func testCapture04and05_stadiumAndOpponent() {
        let app = launch()
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
        capture("04-stadium-entered")

        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "KIA 타이거즈")
        capture("05-opponent-selected")
    }

    // MARK: - 6~9. 네 가지 결과

    func testCapture06to09_everyResult() {
        for (index, item) in [("win", "승리", "06-result-win"),
                              ("loss", "패배", "07-result-loss"),
                              ("draw", "무승부", "08-result-draw"),
                              ("canceled", "경기 취소", "09-result-cancelled")].enumerated() {
            let app = launch()
            choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
            choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
            selectResult(app, item.0)
            let feedback = node(app, "recordCreate.result.feedback")
            XCTAssertFalse(feedback.label.contains(item.0), "내부 이름이 노출됐다")
            XCTAssertFalse(feedback.label.isEmpty, "\(item.0) 안내가 비었다")
            if item.0 == "win" {
                XCTAssertEqual(feedback.label, "오늘은 승리요정이네요!")
            }
            if item.0 == "canceled" {
                XCTAssertFalse(node(app, "recordCreate.score.our").exists, "취소인데 점수 칸이 남았다")
            }
            scrollIntoView(app, node(app, "recordCreate.saveMinimal"))
            capture(item.2)
            XCTAssertEqual(index >= 0, true)
            app.terminate()
        }
    }

    // MARK: - 10~11. 점수

    func testCapture10and11_scoresAndWarning() {
        let agreeing = launch()
        choose(agreeing, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(agreeing, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        typeScore(agreeing, ours: "5", theirs: "3")
        selectResult(agreeing, "win")
        XCTAssertFalse(node(agreeing, "recordCreate.scoreWarning").exists, "맞는 점수인데 경고가 떴다")
        scrollIntoView(agreeing, node(agreeing, "recordCreate.saveMinimal"))
        capture("10-valid-with-scores")
        agreeing.terminate()

        let disagreeing = launch()
        choose(disagreeing, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(disagreeing, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        typeScore(disagreeing, ours: "2", theirs: "7")
        selectResult(disagreeing, "win")
        let warning = scrollIntoView(disagreeing, node(disagreeing, "recordCreate.scoreWarning"))
        XCTAssertTrue(waits(warning, 8), "점수·결과 불일치 경고가 없다")
        capture("11-score-result-warning")
    }

    // MARK: - 12~13. 검증과 저장 준비

    func testCapture12and13_validationAndMinimalSaveReady() {
        let invalid = launch()
        scrollIntoView(invalid, node(invalid, "recordCreate.next")).tap()
        let message = scrollIntoView(invalid, node(invalid, "recordCreate.validationMessage"))
        XCTAssertTrue(waits(message, 8), "검증 안내가 없다")
        XCTAssertEqual(message.label, "상대팀을 선택해 주세요.")
        capture("12-validation-error")
        invalid.terminate()

        let ready = launch()
        choose(ready, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(ready, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        selectResult(ready, "win")
        let save = scrollIntoView(ready, node(ready, "recordCreate.saveMinimal"))
        XCTAssertTrue((save.value as? String ?? "").isEmpty, "준비됐는데 막힌 것처럼 보인다")
        XCTAssertTrue(node(ready, "recordCreate.next").isEnabled, "다음이 아직 비활성이다")
        capture("13-minimal-save-ready")
    }

    // MARK: - 14~15. 좁은 폭

    func testCapture14and15_compactWidthAndKeyboard() {
        let app = launch()
        let width = app.windows.firstMatch.frame.width
        if app.keyboards.element.exists { app.swipeDown() }
        XCTAssertFalse(app.keyboards.element.exists, "키보드가 뜬 채로 14번을 찍으려 한다")
        capture("14-compact-width")

        let ours = scrollIntoView(app, node(app, "recordCreate.score.our"))
        ours.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(ours.frame.maxY, app.keyboards.element.frame.minY + 0.5, "입력 칸이 키보드에 가렸다")
        ours.typeText("4")
        capture("15-compact-keyboard")
        XCTAssertEqual(node(app, "recordCreate.score.our").value as? String ?? "", "4")
        print("CAPTURE_WIDTH \(width)")
    }

    // MARK: - 16~17. 큰 글자 · 긴 이름

    func testCapture16_accessibilityXXXL() {
        let app = launch(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.step1.title", "recordCreate.field.stadium", "recordCreate.next"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
        capture("16-accessibilityXXXL")
    }

    func testCapture17_longTeamNames() {
        let app = launch()
        choose(app, field: "recordCreate.field.opponentTeam", option: "키움 히어로즈")
        choose(app, field: "recordCreate.field.stadium", option: "인천 SSG 랜더스필드")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "인천 SSG 랜더스필드")
        XCTAssertEqual(node(app, "recordCreate.field.opponentTeam").value as? String ?? "", "키움 히어로즈")
        let screen = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(node(app, "recordCreate.field.stadium").frame.maxX, screen.maxX + 0.5,
                                 "긴 구장 이름이 잘렸다")
        capture("17-long-team-names")
    }

    // MARK: - 18. 1단계의 다음이 닿는 곳

    /// 2단계를 만든 뒤로 1단계의 다음은 검증용 경계가 아니라 2단계로 간다.
    func testCapture18_nextReachesStep2() {
        let app = launch()
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        selectResult(app, "win")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 가지 않았다")
        XCTAssertEqual(node(app, "recordCreate.step2.title").label, "그날의 디테일을 더해볼까요?")
        // 3단계는 여전히 없고, 임시저장도 없다.
        XCTAssertFalse(text(app, "오늘의 이야기를 남겨주세요").exists, "3단계를 만든 척한다")
        XCTAssertFalse(text(app, "임시저장").exists, "임시저장이 생겼다")
        capture("18-next-reaches-step2")

        // 돌아오면 1단계 값이 그대로다.
        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
    }
}
