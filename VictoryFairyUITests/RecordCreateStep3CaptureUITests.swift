import XCTest

/// 스테이징된 3단계의 시각 증거 18장.
///
/// 지금 제품은 사진을 최대 열 장까지 다룬다. 그래서 3번은 여러 장 상태를 찍는다.
/// 시뮬레이터 사진 피커는 자동화가 불안정하므로, 사진 상태는 피커를 거치지 않는
/// 결정적 픽스처로 만든다.
final class RecordCreateStep3CaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-record-create-step3-captures"
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

    /// 모든 캡처가 공유하는 전제.
    private func assertStagedStep3IsRendered(_ app: XCUIApplication) {
        XCTAssertTrue(node(app, "recordCreate.step3.title").exists, "3단계 제목이 없다")
        XCTAssertEqual(node(app, "recordCreate.step3.title").label, "오늘의 이야기를 남겨주세요")
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 3단계, 나의 이야기")
        for forbidden in ["별점", "몇 점이었나요", "0 / 500", "임시저장",
                          "AI 초안", "AI 후기", "사진 분석", "경기 선택", "티켓"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
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

    private func type(_ app: XCUIApplication, into identifier: String, _ value: String) {
        let field = scrollIntoView(app, node(app, identifier))
        field.tap(); field.typeText(value)
        dismissKeyboard(app)
    }

    // MARK: - 1. 빈 상태

    func testCapture01_defaultEmpty() {
        let app = launchStep3()
        assertStagedStep3IsRendered(app)
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "")
        for mood in ["overwhelmed", "happy", "proud", "regret", "annoyed"] {
            XCTAssertFalse(button(app, "recordCreate.step3.mood.\(mood)").isSelected, "\(mood)이 미리 선택됐다")
        }
        capture("01-default-empty")
    }

    // MARK: - 2~3. 사진 (결정적 픽스처)

    func testCapture02_onePhoto() {
        let app = launchStep3(photoFixture: "one")
        assertStagedStep3IsRendered(app)
        XCTAssertTrue(waits(node(app, "recordCreate.step3.removePhoto.1")), "사진 한 장이 없다")
        XCTAssertFalse(node(app, "recordCreate.step3.removePhoto.2").exists, "두 장이 들어 있다")
        capture("02-one-photo")
    }

    /// 지금 제품은 사진을 열 장까지 다룬다. 여러 장 상태를 그대로 찍는다.
    func testCapture03_multiplePhotos() {
        let app = launchStep3(photoFixture: "many")
        assertStagedStep3IsRendered(app)
        XCTAssertTrue(waits(node(app, "recordCreate.step3.removePhoto.1")), "첫 사진이 없다")
        XCTAssertTrue(node(app, "recordCreate.step3.removePhoto.2").exists, "여러 장을 지원하지 않는다")
        capture("03-multiple-photos")
    }

    // MARK: - 4. 순간

    func testCapture04_momentEntered() {
        let app = launchStep3()
        type(app, into: "recordCreate.step3.moment", "9회초 박병호 역전 스리런")
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "9회초 박병호 역전 스리런")
        capture("04-moment-entered")
    }

    // MARK: - 5~9. 다섯 가지 기분

    func testCapture05to09_everyMood() {
        for (suffix, label, name) in [("overwhelmed", "벅차오름", "05-mood-overwhelmed"),
                                      ("happy", "행복", "06-mood-happy"),
                                      ("proud", "뿌듯", "07-mood-proud"),
                                      ("regret", "아쉬움", "08-mood-regret"),
                                      ("annoyed", "약오름", "09-mood-annoyed")] {
            let app = launchStep3()
            assertStagedStep3IsRendered(app)
            scrollIntoView(app, button(app, "recordCreate.step3.mood.\(suffix)")).tap()
            XCTAssertTrue(button(app, "recordCreate.step3.mood.\(suffix)").isSelected, "\(label)이 선택되지 않았다")
            capture(name)
            app.terminate()
        }
    }

    // MARK: - 10~11. 일기와 모두 채운 상태

    func testCapture10and11_diaryAndEverything() {
        let app = launchStep3(photoFixture: "one")
        type(app, into: "recordCreate.step3.diary", "1회부터 조마조마했던 하루.")
        XCTAssertTrue((node(app, "recordCreate.step3.diary").value as? String ?? "").contains("조마조마"))
        capture("10-diary-entered")

        type(app, into: "recordCreate.step3.moment", "9회초 역전 스리런")
        scrollIntoView(app, button(app, "recordCreate.step3.mood.overwhelmed")).tap()
        XCTAssertTrue(node(app, "recordCreate.step3.removePhoto.1").exists, "사진이 사라졌다")
        capture("11-everything-entered")
    }

    // MARK: - 12. 뒤로 갔다 온 뒤

    func testCapture12_backPreservedState() {
        let app = launchStep3()
        type(app, into: "recordCreate.step3.moment", "역전")
        scrollIntoView(app, button(app, "recordCreate.step3.mood.happy")).tap()
        button(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 돌아오지 못했다")
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step3.root")))
        XCTAssertEqual(node(app, "recordCreate.step3.moment").value as? String ?? "", "역전")
        XCTAssertTrue(button(app, "recordCreate.step3.mood.happy").isSelected)
        capture("12-back-preserved-state")
    }

    // MARK: - 13. 저장 준비

    func testCapture13_finalSaveReady() {
        let app = launchStep3(photoFixture: "one")
        type(app, into: "recordCreate.step3.moment", "9회초 역전")
        scrollIntoView(app, button(app, "recordCreate.step3.mood.proud")).tap()
        let complete = scrollIntoView(app, node(app, "recordCreate.step3.complete"))
        XCTAssertEqual(complete.label, "기록 완성하기")
        XCTAssertTrue(complete.isEnabled, "완성 버튼이 비활성이다")
        capture("13-final-save-ready")
    }

    // MARK: - 14. 검증이 1단계로 되돌린다

    func testCapture14_validationRoutesBackToStep1() {
        let app = launchIncompleteAtMemory()
        type(app, into: "recordCreate.step3.diary", "일기만 남긴다")
        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 않았다")
        let message = scrollIntoView(app, node(app, "recordCreate.validationMessage"))
        XCTAssertTrue(waits(message, 8), "검증 안내가 없다")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "막혔는데 저장했다")
        capture("14-validation-routes-to-step1")
    }

    // MARK: - 15. 저장 결과가 화면에 남는다

    func testCapture15_saveOutcomeIsReported() {
        // UI 테스트에는 서버가 없으므로 저장은 언제나 기존 오프라인 경로로 간다.
        // 그 경로가 남기는 안내가 3단계에서 어떻게 보이는지 그대로 찍는다.
        let app = launchStep3(photoFixture: "one")
        type(app, into: "recordCreate.step3.moment", "저장 확인")
        capture("15-save-outcome")
        scrollIntoView(app, node(app, "recordCreate.step3.complete")).tap()
        XCTAssertTrue(node(app, "recordCreate.step3.root").waitForNonExistence(timeout: 20), "저장 뒤 닫히지 않았다")
        XCTAssertTrue(waits(text(app, "흐름이 닫혔어요")), "흐름이 닫히지 않았다")
    }

    // MARK: - 16~17. 좁은 폭과 키보드

    func testCapture16and17_compactAndKeyboard() {
        let app = launchStep3()
        let width = app.windows.firstMatch.frame.width
        XCTAssertFalse(app.keyboards.element.exists, "키보드가 뜬 채로 16번을 찍으려 한다")
        capture("16-compact-width")

        let diary = scrollIntoView(app, node(app, "recordCreate.step3.diary"))
        diary.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        diary.typeText("좁은 폭에서")
        capture("17-compact-diary-keyboard")
        dismissKeyboard(app)
        print("CAPTURE_WIDTH \(width)")
    }

    // MARK: - 18. 큰 글자

    func testCapture18_accessibilityXXXL() {
        let app = launchStep3(accessibilitySize: true)
        assertStagedStep3IsRendered(app)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.step3.title", "recordCreate.step3.moment",
                           "recordCreate.step3.complete"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
        capture("18-accessibilityXXXL")
    }
}
