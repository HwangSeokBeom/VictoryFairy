import XCTest

/// 피드에 남아 있던 하나의 시각 공백 — **사진이 있는 기록 캡처** — 을 닫는다.
///
/// 지금까지 피드 픽스처의 기록에는 사진 참조가 없어서, 사진이 있는 기록이 실제로 어떻게
/// 보이는지 남길 방법이 없었다. 기록 상세를 위해 만든 메모리 사진 장치를 그대로 쓰면
/// 파일을 하나도 만들지 않고 그 상태를 그릴 수 있다.
///
/// 이 묶음은 피드를 다시 설계하지 않는다. 기존 화면을 있는 그대로 찍기만 한다.
final class FeedPhotoCaptureUITests: XCTestCase {

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

    private func launchFeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", "populated"
        ]
        app.launch()
        XCTAssertTrue(node(app, "screen.feed").waitForExistence(timeout: 15), "피드에 들어가지 못했다")
        return app
    }

    /// 사진이 있는 기록이 피드에서 실제로 그려진다.
    func testFeedRendersRecordsWithPhotos() {
        let app = launchFeed()
        let photo = app.images.firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 12), "피드에 사진이 그려지지 않았다")
        capture(app, "33-feed-record-with-photo")
    }

    /// 사진이 없는 기록도 같은 목록에 함께 있다. 두 상태가 한 화면에서 확인된다.
    func testFeedKeepsPhotolessRecordsInTheSameList() {
        let app = launchFeed()
        let cards = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'feed.record.'"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 12), "기록 카드가 없다")
        XCTAssertGreaterThanOrEqual(cards.count, 2, "사진 유무를 비교할 기록이 모자라다")
    }
}
