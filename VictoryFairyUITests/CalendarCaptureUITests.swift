import XCTest

/// 캘린더 캡처 매트릭스 가운데 **조작이 필요한** 상태를 만든다.
///
/// 실행 인자만으로 만들 수 있는 상태는 `simctl`로 찍는 편이 빠르다. 하지만 달 이동,
/// 좁은 폭, 큰 글자, 이동한 화면은 실제로 눌러 보고 그 폭에서 띄워야 나온다.
/// 그래서 이 묶음은 검증이 아니라 **증거를 남기는 것**이 목적이다.
///
/// 저장 위치는 `VF_CAPTURE_DIR` 환경 변수로 정하고, 없으면 정해진 임시 폴더에 남긴다.
/// 저장소 안에는 쓰지 않는다.
final class CalendarCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false) ? environment! : "/tmp/vf-calendar-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
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
        XCTAssertTrue(node(app, "calendar.scenario.\(fixture)").waitForExistence(timeout: 15),
                      "픽스처 \(fixture)가 적용되지 않았다")
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// 화면을 파일로 남긴다. 테스트 첨부로도 함께 남겨 결과 번들에서 볼 수 있게 한다.
    private func capture(_ app: XCUIApplication, _ name: String) {
        usleep(900_000)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = captureDirectory.appendingPathComponent("\(name).png")
        do {
            try shot.pngRepresentation.write(to: url)
            print("CAPTURED \(url.path)")
        } catch {
            XCTFail("캡처를 저장하지 못했다: \(name) — \(error)")
        }
    }

    // MARK: - 달 이동

    func testCapture16_previousMonth() {
        let app = launch("referenceMonth")
        node(app, "calendar.previousMonth").tap()
        XCTAssertTrue(node(app, "calendar.day.2026-03-31").waitForExistence(timeout: 10))
        capture(app, "16-previous-month")
    }

    func testCapture17_nextMonth() {
        let app = launch("referenceMonth")
        node(app, "calendar.nextMonth").tap()
        XCTAssertTrue(node(app, "calendar.day.2026-05-31").waitForExistence(timeout: 10))
        capture(app, "17-next-month")
    }

    func testCapture18_decemberToJanuary() {
        let app = launch("yearBoundary")
        node(app, "calendar.nextMonth").tap()
        XCTAssertTrue(node(app, "calendar.day.2027-01-31").waitForExistence(timeout: 10))
        capture(app, "18-december-to-january")
    }

    // MARK: - 좁은 폭 (좁은 기기에서 실행할 때만 뜻이 있다)

    func testCapture19_compactReferenceMonth() {
        let app = launch("compactReference")
        capture(app, "19-compact-reference-month")
    }

    func testCapture20_compactSelectedRecordDetail() {
        let app = launch("selectedRecord")
        let detail = node(app, "calendar.detailRecord")
        for _ in 0..<5 where !detail.exists || !detail.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        capture(app, "20-compact-selected-detail")
    }

    // MARK: - AccessibilityXXXL

    func testCapture21_accessibilityReferenceMonth() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        capture(app, "21-accessibility-reference-month")
    }

    func testCapture22_accessibilitySelectedRecordDetail() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        let detail = node(app, "calendar.detailRecord")
        for _ in 0..<6 where !detail.exists || !detail.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        capture(app, "22-accessibility-selected-detail")
    }

    // MARK: - 이동한 화면

    func testCapture27_recordDetailDestination() {
        let app = launch("selectedRecord")
        let card = node(app, "calendar.detailRecord")
        XCTAssertTrue(card.waitForExistence(timeout: 12))
        card.tap()
        // 상세 화면은 매치업 원문 대신 두 팀을 각각 보여 준다. 문구가 아니라
        // 화면 정체성으로 도착을 확인한다.
        XCTAssertTrue(
            node(app, "recordDetail.root").waitForExistence(timeout: 12),
            "기록 상세로 가지 못했다"
        )
        capture(app, "27-record-detail-destination")
    }

    func testCapture28_recordCreateDestination() {
        let app = launch("selectedEmptyDate")
        let add = node(app, "calendar.detailAddRecord")
        for _ in 0..<5 where !add.exists || !add.isHittable {
            app.swipeUp()
            usleep(350_000)
        }
        XCTAssertTrue(add.waitForExistence(timeout: 12), "기록 추가 경로가 없다")
        add.tap()
        usleep(1_200_000)
        capture(app, "28-record-create-destination")
    }
}
