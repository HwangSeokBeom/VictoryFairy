import XCTest

/// 스테이징된 2단계의 시각 증거 18장.
///
/// 이 매트릭스가 증명하는 것은 **지원하는 값만 만든 2단계가 이렇게 생겼다**는
/// 것이지, 사용자가 이 화면을 볼 수 있다는 것이 아니다.
final class RecordCreateStep2CaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false)
            ? environment!
            : "/tmp/VictoryFairy-record-create-step2-captures"
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

    private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons.matching(identifier: "recordCreate.step2.keyboardDone").firstMatch
        if done.waitForExistence(timeout: 5) { done.tap() }
        _ = app.keyboards.element.waitForNonExistence(timeout: 6)
    }

    @discardableResult
    private func launchStep2(accessibilitySize: Bool = false) -> XCUIApplication {
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
        choose(app, field: "recordCreate.field.stadium", option: "잠실야구장")
        choose(app, field: "recordCreate.field.opponentTeam", option: "KIA 타이거즈")
        scrollIntoView(app, node(app, "recordCreate.result.win")).tap()
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 들어가지 못했다")
        assertStagedStep2IsRendered(app)
        return app
    }

    /// 모든 캡처가 공유하는 전제: 제품 2단계 컴포넌트가 떠 있고, 진행 표시가 2단계이며,
    /// 3단계 레이아웃과 `임시저장`과 미지원 항목은 어디에도 없다.
    private func assertStagedStep2IsRendered(_ app: XCUIApplication) {
        XCTAssertTrue(node(app, "recordCreate.step2.title").exists, "2단계 제목이 없다")
        XCTAssertEqual(node(app, "recordCreate.step2.title").label, "그날의 디테일을 더해볼까요?")
        XCTAssertEqual(node(app, "recordCreate.progress").label, "3단계 중 2단계, 그날의 디테일")
        for forbidden in ["임시저장", "오늘의 이야기를 남겨주세요", "0 / 500",
                          "날씨", "맑음", "흐림", "밤경기", "먹은 것",
                          "응원 준비물", "유니폼", "응원봉", "응원수건", "유광점퍼"] {
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

    // MARK: - 1~2. 시작 상태와 좌석

    func testCapture01and02_emptyAndSeatEntered() {
        let app = launchStep2()
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "")
        for option in ["alone", "family", "friend"] {
            XCTAssertFalse(button(app, "recordCreate.companion.\(option)").isSelected, "\(option)이 미리 선택됐다")
        }
        capture("01-default-empty")

        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap(); seat.typeText("3루 내야 지정석 K열 24번")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "3루 내야 지정석 K열 24번")
        capture("02-seat-entered")
    }

    // MARK: - 3~5. 빠른 선택지

    func testCapture03to05_quickCompanionOptions() {
        for (identifier, label, name) in [("alone", "혼자", "03-companion-alone"),
                                          ("family", "엄마랑", "04-companion-family"),
                                          ("friend", "친구랑", "05-companion-friend")] {
            let app = launchStep2()
            scrollIntoView(app, button(app, "recordCreate.companion.\(identifier)")).tap()
            XCTAssertTrue(button(app, "recordCreate.companion.\(identifier)").isSelected,
                          "\(label)이 선택 상태가 아니다")
            XCTAssertFalse(node(app, "recordCreate.companion.customField").exists,
                           "빠른 선택인데 직접 입력 칸이 열렸다")
            capture(name)
            app.terminate()
        }
    }

    // MARK: - 6~8. 직접 입력과 둘 다 채운 상태

    func testCapture06to08_customCompanionAndBothFilled() {
        let app = launchStep2()
        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.companion.customField")), "직접 입력 칸이 없다")
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "")
        capture("06-companion-custom-selected")

        let field = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        field.tap(); field.typeText("회사 동료들과")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "회사 동료들과")
        capture("07-companion-custom-entered")

        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap(); seat.typeText("1루 응원석")
        dismissKeyboard(app)
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "1루 응원석")
        XCTAssertEqual(node(app, "recordCreate.companion.customField").value as? String ?? "", "회사 동료들과")
        capture("08-seat-and-companion")
    }

    // MARK: - 9. 뒤로 갔다 온 뒤

    func testCapture09_backPreservedState() {
        let app = launchStep2()
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap(); seat.typeText("외야 자유석")
        dismissKeyboard(app)
        scrollIntoView(app, button(app, "recordCreate.companion.family")).tap()

        button(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step1.root")), "1단계로 돌아오지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String ?? "", "잠실야구장")
        scrollIntoView(app, node(app, "recordCreate.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")), "2단계로 다시 들어가지 못했다")
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "외야 자유석")
        XCTAssertTrue(button(app, "recordCreate.companion.family").isSelected)
        capture("09-back-preserved-state")
    }

    // MARK: - 10~11. 다음과 건너뛰기

    func testCapture10_nextBoundary() {
        let app = launchStep2()
        scrollIntoView(app, node(app, "recordCreate.step2.next")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.stagedBoundary")), "경계로 가지 않았다")
        XCTAssertTrue(text(app, "아직 만들지 않았어요").exists, "경계 안내가 없다")
        XCTAssertFalse(text(app, "오늘의 이야기를 남겨주세요").exists, "3단계를 만든 척한다")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "다음이 저장했다")
        capture("10-next-boundary")
    }

    func testCapture11_skipBoundaryKeepsValues() {
        let app = launchStep2()
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap(); seat.typeText("3루 K열")
        dismissKeyboard(app)
        scrollIntoView(app, button(app, "recordCreate.companion.alone")).tap()

        scrollIntoView(app, node(app, "recordCreate.step2.skip")).tap()
        XCTAssertTrue(waits(node(app, "recordCreate.stagedBoundary")), "건너뛰기가 경계로 가지 않았다")
        XCTAssertFalse(node(app, "recordCreate.saveMessage").exists, "건너뛰기가 저장했다")
        capture("11-skip-boundary")

        // 값이 그대로 남아 있는지 눈으로도 확인한다.
        node(app, "recordCreate.back").tap()
        XCTAssertTrue(waits(node(app, "recordCreate.step2.root")))
        XCTAssertEqual(node(app, "recordCreate.field.seat").value as? String ?? "", "3루 K열")
        XCTAssertTrue(button(app, "recordCreate.companion.alone").isSelected)
    }

    // MARK: - 12~14. 좁은 폭과 키보드

    func testCapture12to14_compactAndKeyboards() {
        let app = launchStep2()
        let width = app.windows.firstMatch.frame.width
        XCTAssertFalse(app.keyboards.element.exists, "키보드가 뜬 채로 12번을 찍으려 한다")
        capture("12-compact-width")

        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(seat.frame.maxY, app.keyboards.element.frame.minY + 0.5, "좌석이 키보드에 가렸다")
        seat.typeText("3루")
        capture("13-compact-seat-keyboard")
        dismissKeyboard(app)

        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        let custom = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        custom.tap()
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 10), "키보드가 올라오지 않았다")
        XCTAssertLessThan(custom.frame.maxY, app.keyboards.element.frame.minY + 0.5,
                          "직접 입력 칸이 키보드에 가렸다")
        custom.typeText("동료들")
        capture("14-compact-custom-keyboard")
        dismissKeyboard(app)
        print("CAPTURE_WIDTH \(width)")
    }

    // MARK: - 15. 큰 글자

    func testCapture15_accessibilityXXXL() {
        let app = launchStep2(accessibilitySize: true)
        let screen = app.windows.firstMatch.frame
        for identifier in ["recordCreate.step2.title", "recordCreate.field.seat",
                           "recordCreate.companion.custom", "recordCreate.step2.next"] {
            let element = scrollIntoView(app, node(app, identifier))
            XCTAssertLessThanOrEqual(element.frame.maxX, screen.maxX + 0.5, "\(identifier)이 가로로 잘렸다")
        }
        capture("15-accessibilityXXXL")
    }

    // MARK: - 16~17. 긴 값

    func testCapture16and17_longValues() {
        let app = launchStep2()
        let screen = app.windows.firstMatch.frame
        let seat = scrollIntoView(app, node(app, "recordCreate.field.seat"))
        seat.tap(); seat.typeText("3루 내야 지정석 K열 24번 통로 바로 옆 자리")
        dismissKeyboard(app)
        XCTAssertLessThanOrEqual(node(app, "recordCreate.field.seat").frame.maxX, screen.maxX + 0.5,
                                 "긴 좌석이 잘렸다")
        capture("16-long-seat")

        scrollIntoView(app, button(app, "recordCreate.companion.custom")).tap()
        let custom = scrollIntoView(app, node(app, "recordCreate.companion.customField"))
        custom.tap(); custom.typeText("회사 동료들과 야구 동호회 사람들 그리고 사촌 동생까지")
        dismissKeyboard(app)
        XCTAssertLessThanOrEqual(node(app, "recordCreate.companion.customField").frame.maxX,
                                 screen.maxX + 0.5, "긴 동행 값이 잘렸다")
        capture("17-long-custom-companion")
    }

    // MARK: - 18. 지원하는 것만 있는 최종 레이아웃

    func testCapture18_supportedOnlyLayout() {
        let app = launchStep2()
        // 지원하는 것은 전부 있다.
        for identifier in ["recordCreate.progress", "recordCreate.step2.title", "recordCreate.step2.subtitle",
                           "recordCreate.field.seat", "recordCreate.companion.alone",
                           "recordCreate.companion.family", "recordCreate.companion.friend",
                           "recordCreate.companion.custom", "recordCreate.step2.next",
                           "recordCreate.step2.skip", "recordCreate.back", "recordCreate.cancel"] {
            XCTAssertTrue(node(app, identifier).exists, "\(identifier)이 없다")
        }
        // 지원하지 않는 것은 하나도 없다 — 비활성 자리표시자도 두지 않았다.
        for forbidden in ["날씨", "맑음", "흐림", "비", "밤경기", "먹은 것", "치킨", "생맥주",
                          "응원 준비물", "유니폼", "응원봉", "응원수건", "유광점퍼", "임시저장"] {
            XCTAssertFalse(text(app, forbidden).exists, "\(forbidden)이 화면에 있다")
        }
        capture("18-supported-only-layout")
    }
}
