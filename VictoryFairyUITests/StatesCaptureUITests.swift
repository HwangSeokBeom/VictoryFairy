import XCTest

/// 09_States 최종 시각 증거 14장만 생성한다.
///
/// 권위 캡처는 `/tmp/VictoryFairy-09-states-captures`에 저장한다.
/// 전체 UI 스위트가 나중에 다시 돌더라도 이미 확정된 파일은 덮어쓰지 않는다.
final class StatesCaptureUITests: XCTestCase {
    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = environment?.isEmpty == false
            ? environment!
            : "/tmp/VictoryFairy-09-states-captures"
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

    @discardableResult
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement, limit: Int = 18) -> XCUIElement {
        for _ in 0..<limit {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(240_000)
        }
        XCTAssertTrue(element.exists && element.isHittable, "캡처할 요소에 닿지 못했다")
        return element
    }

    private func requireCompactWidth(_ app: XCUIApplication) throws {
        let width = app.windows.firstMatch.frame.width
        guard width <= 390 else {
            throw XCTSkip("SE 3 전용 캡처는 390pt 이하에서만 만든다. 현재 폭 \(width)pt")
        }
    }

    private func capture(_ app: XCUIApplication, _ filename: String) {
        usleep(900_000)
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = captureDirectory.appendingPathComponent(filename)
        do {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                print("CAPTURE_PRESERVED \(url.path)")
                return
            }
            try shot.pngRepresentation.write(to: url, options: .withoutOverwriting)
            print("CAPTURED \(url.path)")
        } catch {
            XCTFail("캡처를 저장하지 못했다: \(filename) — \(error)")
        }
    }

    private func launchStadium(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestRecordCreateStaged", "fresh",
            "-VFUITestStadiumSheetFixture", fixture
        ]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(node(app, "recordCreate.step1.root").waitForExistence(timeout: 15))
        XCTAssertTrue(node(app, "stadiumSheet.scenario.\(fixture)").exists)
        return app
    }

    @discardableResult
    private func openStadium(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launchStadium(fixture, accessibilitySize: accessibilitySize)
        scrollTo(app, node(app, "recordCreate.field.stadium")).tap()
        XCTAssertTrue(node(app, "stadiumSheet.root").waitForExistence(timeout: 10))
        return app
    }

    private func shareFixtureID(_ fixture: String) -> String {
        let seeds = [
            "withPhoto": 1, "noPhoto": 2, "unreadablePhoto": 3,
            "scored": 4, "canceled": 5, "longContent": 7
        ]
        return String(format: "09F10000-0000-4000-8000-%012d", seeds[fixture]!)
    }

    private func launchShare(
        _ fixture: String,
        fromDetail: Bool,
        accessibilitySize: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", "samsung-lions",
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestMemoryShareFixture", fixture
        ]
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(node(app, "screen.feed").waitForExistence(timeout: 15))
        let id = shareFixtureID(fixture)

        if fromDetail {
            scrollTo(app, node(app, "feed.record.\(id)")).tap()
            XCTAssertTrue(node(app, "recordDetail.root").waitForExistence(timeout: 12))
            scrollTo(app, node(app, "recordDetail.share")).tap()
        } else {
            scrollTo(app, node(app, "feed.share.\(id)")).tap()
        }
        XCTAssertTrue(node(app, "memoryShare.root").waitForExistence(timeout: 12))
        XCTAssertTrue(node(app, "memoryShare.scenario.\(fixture)").exists)
        return app
    }

    // MARK: - Stadium 1...7

    func testCapture01_recordCreateBeforeOpening() {
        let app = launchStadium("canonicalSelected")
        XCTAssertEqual(node(app, "recordCreate.field.stadium").value as? String, "잠실야구장")
        capture(app, "01-stadium-record-create-before-opening.png")
    }

    func testCapture02_canonicalSelectedSheet() {
        let app = openStadium("canonicalSelected")
        XCTAssertTrue(node(app, "stadiumSheet.stadium.jamsil").isSelected)
        capture(app, "02-stadium-canonical-selected-sheet.png")
    }

    func testCapture03_allNineCatalogScrolled() {
        let app = openStadium("allNine")
        let last = node(app, "stadiumSheet.stadium.changwon-nc")
        for _ in 0..<12 where !last.exists || !last.isHittable {
            node(app, "stadiumSheet.root").swipeUp()
        }
        XCTAssertTrue(last.exists)
        capture(app, "03-stadium-all-nine-scrolled.png")
    }

    func testCapture04_invalidInitialZeroSelection() {
        let app = openStadium("invalidCurrent")
        for id in ["jamsil", "gocheok", "incheon-ssg", "suwon-kt"] {
            XCTAssertFalse(node(app, "stadiumSheet.stadium.\(id)").isSelected)
        }
        capture(app, "04-stadium-invalid-zero-selection.png")
    }

    func testCapture05_emptyCatalog() {
        let app = openStadium("empty")
        XCTAssertTrue(node(app, "stadiumSheet.empty").exists)
        capture(app, "05-stadium-empty-catalog.png")
    }

    func testCapture06_se3SelectedFullCatalog() throws {
        let app = openStadium("allNine")
        try requireCompactWidth(app)
        XCTAssertTrue(node(app, "stadiumSheet.stadium.jamsil").isSelected)
        capture(app, "06-stadium-se3-selected-full-catalog.png")
    }

    func testCapture07_accessibilityXXXLLongRow() {
        let app = openStadium("longContent", accessibilitySize: true)
        XCTAssertGreaterThanOrEqual(node(app, "stadiumSheet.stadium.jamsil").frame.height, 80)
        capture(app, "07-stadium-accessibility-xxxl-long-row.png")
    }

    // MARK: - Share 8...14

    func testCapture08_detailRealRecordWithPhoto() {
        let app = launchShare("withPhoto", fromDetail: true)
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        capture(app, "08-share-detail-real-record-with-photo.png")
    }

    func testCapture09_noPhotoPlaceholder() {
        let app = launchShare("noPhoto", fromDetail: true)
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        capture(app, "09-share-no-photo-placeholder.png")
    }

    func testCapture10_unreadablePhotoFallback() {
        let app = launchShare("unreadablePhoto", fromDetail: true)
        XCTAssertTrue(node(app, "memoryShare.card").exists)
        capture(app, "10-share-unreadable-photo-fallback.png")
    }

    func testCapture11_canceledHonestState() {
        let app = launchShare("canceled", fromDetail: true)
        let label = node(app, "memoryShare.card").label
        XCTAssertTrue(label.contains("경기 취소"))
        XCTAssertFalse(label.contains("0 : 0"))
        capture(app, "11-share-canceled-honest-state.png")
    }

    func testCapture12_feedRealRecordMemoryCard() {
        let app = launchShare("scored", fromDetail: false)
        XCTAssertTrue(node(app, "memoryShare.scenario.scored").exists)
        capture(app, "12-share-feed-real-record-memory-card.png")
    }

    func testCapture13_se3Preview() throws {
        let app = launchShare("noPhoto", fromDetail: false)
        try requireCompactWidth(app)
        let card = node(app, "memoryShare.card")
        XCTAssertEqual(card.frame.width / card.frame.height, 5.0 / 6.0, accuracy: 0.03)
        capture(app, "13-share-se3-preview.png")
    }

    func testCapture14_accessibilityXXXLAndDecodedExportProof() {
        let app = launchShare("longContent", fromDetail: false, accessibilitySize: true)
        let proof = scrollTo(app, node(app, "memoryShare.exportProof"))
        XCTAssertEqual(proof.label, "디코딩 확인 · 1200 × 1440")
        capture(app, "14-share-accessibility-xxxl-export-proof.png")
    }
}
