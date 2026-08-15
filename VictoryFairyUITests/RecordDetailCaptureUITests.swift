import XCTest

/// 기록 상세 캡처 매트릭스를 만든다.
///
/// 검증이 아니라 **증거를 남기는 것**이 목적이다. 상세는 눌러서 들어가는 화면이라
/// 모든 캡처가 실제 목록에서 기록을 눌러 들어간 뒤, 시나리오 표식을 확인하고 찍는다.
///
/// 저장 위치는 `VF_CAPTURE_DIR` 환경 변수로 정하고, 없으면 정해진 임시 폴더에 남긴다.
/// 저장소 안에는 쓰지 않는다.
final class RecordDetailCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false) ? environment! : "/tmp/vf-recorddetail-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private enum Entry {
        case feed
        case calendar
    }

    @discardableResult
    private func openDetail(
        _ fixture: String,
        via entry: Entry = .feed,
        teamID: String = "samsung-lions",
        accessibilitySize: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestRecordDetailFixture", fixture
        ]
        switch entry {
        case .feed:
            arguments += ["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"]
        case .calendar:
            arguments += ["-VFUITestInitialTab", "calendar", "-VFUITestCalendarFixture", "selectedRecord"]
        }
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()

        switch entry {
        case .feed:
            let card = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'feed.record.'"))
                .firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 15), "피드에 누를 기록이 없다")
            card.tap()
        case .calendar:
            let record = node(app, "calendar.detailRecord")
            XCTAssertTrue(record.waitForExistence(timeout: 15), "캘린더에 기록이 없다")
            record.tap()
        }
        XCTAssertTrue(
            node(app, "recordDetail.scenario.\(fixture)").waitForExistence(timeout: 15),
            "픽스처 \(fixture)가 적용되지 않았다"
        )
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

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

    /// 화면 밖에 있어도 요소는 "존재"하므로 `exists`만 보면 스크롤하지 않고 끝난다.
    /// 실제로 보이는 자리에 올 때까지 창 안쪽에 들어왔는지로 판단한다.
    private func scroll(_ app: XCUIApplication, to identifier: String) {
        let element = node(app, identifier)
        let window = app.windows.element(boundBy: 0).frame
        for _ in 0..<14 {
            if element.exists, element.isHittable, window.contains(element.frame.origin),
               element.frame.maxY <= window.maxY {
                return
            }
            app.swipeUp()
            usleep(320_000)
        }
    }

    private func captureSimple(_ fixture: String, _ name: String, teamID: String = "samsung-lions") {
        let app = openDetail(fixture, teamID: teamID)
        capture(app, name)
        app.terminate()
    }

    // MARK: - 1~16 · 상태 매트릭스

    func testCapture01_referenceRecord() { captureSimple("referenceRecord", "01-reference-record") }
    func testCapture02_withPhoto() { captureSimple("withPhoto", "02-with-photo") }
    func testCapture03_withoutPhoto() { captureSimple("withoutPhoto", "03-without-photo") }
    func testCapture04_missingPhotoFile() { captureSimple("missingPhotoFile", "04-missing-photo-file") }
    func testCapture05_failedPhotoDecode() { captureSimple("failedPhotoDecode", "05-failed-photo-decode") }

    func testCapture06_shortNote() {
        let app = openDetail("referenceRecord")
        scroll(app, to: "recordDetail.note")
        capture(app, "06-short-note")
    }

    func testCapture07_longNote() {
        let app = openDetail("longNote")
        scroll(app, to: "recordDetail.note")
        capture(app, "07-long-note")
    }

    func testCapture08_noNote() {
        let app = openDetail("noNote")
        scroll(app, to: "recordDetail.note.empty")
        capture(app, "08-no-note")
    }

    func testCapture09_missingScore() { captureSimple("missingScore", "09-missing-score") }
    func testCapture10_missingOpponent() { captureSimple("missingOpponent", "10-missing-opponent") }

    func testCapture11_missingStadium() {
        let app = openDetail("missingStadium")
        scroll(app, to: "recordDetail.stadium.missing")
        capture(app, "11-missing-stadium")
    }

    func testCapture12_unknownStadium() {
        let app = openDetail("unknownStadium")
        scroll(app, to: "recordDetail.stadium.unknown")
        capture(app, "12-unknown-stadium")
    }

    func testCapture13_win() { captureSimple("win", "13-win") }
    func testCapture14_loss() { captureSimple("loss", "14-loss") }
    func testCapture15_draw() { captureSimple("draw", "15-draw") }
    func testCapture16_cancelled() { captureSimple("cancelled", "16-cancelled") }

    // MARK: - 17~22 · 상태와 흐름

    func testCapture17_loading() { captureSimple("loading", "17-loading") }
    func testCapture18_recoverableError() { captureSimple("recoverableError", "18-recoverable-error") }
    func testCapture19_retrySuccess() { captureSimple("retrySuccess", "19-retry-success") }

    func testCapture20_deleteConfirmation() {
        let app = openDetail("deleteConfirmation")
        node(app, "recordDetail.overflow").tap()
        let delete = app.buttons["기록 삭제하기"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 8))
        delete.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8))
        capture(app, "20-delete-confirmation")
    }

    func testCapture21_deleteFailure() {
        let app = openDetail("deleteFailure")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["삭제하기"].firstMatch.tap()
        XCTAssertTrue(node(app, "recordDetail.error").waitForExistence(timeout: 10))
        capture(app, "21-delete-failure")
    }

    func testCapture22_editDestination() {
        let app = openDetail("referenceRecord")
        scroll(app, to: "recordDetail.edit")
        node(app, "recordDetail.edit").tap()
        _ = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "3루 원정석"))
            .firstMatch.waitForExistence(timeout: 10)
        capture(app, "22-edit-destination")
    }

    // MARK: - 23~26 · 폭과 글자 크기

    func testCapture23_compactPopulated() {
        let app = openDetail("compactReference")
        capture(app, "23-compact-populated")
    }

    func testCapture24_compactLongContent() {
        let app = openDetail("longNote")
        scroll(app, to: "recordDetail.note")
        capture(app, "24-compact-long-content")
    }

    func testCapture25_accessibilityPopulated() {
        let app = openDetail("accessibilityReference", accessibilitySize: true)
        capture(app, "25-accessibility-populated")
    }

    func testCapture26_accessibilityDeleteConfirmation() {
        let app = openDetail("deleteConfirmation", accessibilitySize: true)
        node(app, "recordDetail.overflow").tap()
        let delete = app.buttons["기록 삭제하기"].firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 10))
        delete.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 10))
        capture(app, "26-accessibility-delete-confirmation")
    }

    // MARK: - 27~32 · 이름, 강조색, 진입 경로

    func testCapture27_longTeamName() {
        captureSimple("longTeamName", "27-long-team-name", teamID: "hanwha-eagles")
    }

    func testCapture28_longStadiumName() {
        let app = openDetail("longStadiumName")
        scroll(app, to: "recordDetail.stadium.gwangju-kia")
        capture(app, "28-long-stadium-name")
    }

    func testCapture29_lightTeamAccent() {
        captureSimple("lightTeamAccent", "29-light-team-accent", teamID: "hanwha-eagles")
    }

    func testCapture30_darkTeamAccent() {
        captureSimple("darkTeamAccent", "30-dark-team-accent", teamID: "kt-wiz")
    }

    func testCapture31_reachedFromFeed() {
        let app = openDetail("referenceRecord", via: .feed)
        capture(app, "31-reached-from-feed")
    }

    func testCapture32_reachedFromCalendar() {
        let app = openDetail("referenceRecord", via: .calendar)
        capture(app, "32-reached-from-calendar")
    }
}
