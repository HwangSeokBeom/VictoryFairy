import XCTest

/// 시즌 아카이브 캡처 매트릭스를 만든다.
///
/// 검증이 아니라 **증거를 남기는 것**이 목적이다. 각 캡처는 픽스처 표식을 확인한 뒤에
/// 찍으므로, 무엇을 찍었는지가 파일 이름과 실제 화면에서 함께 확인된다.
///
/// 저장 위치는 `VF_CAPTURE_DIR` 환경 변수로 정하고, 없으면 정해진 임시 폴더에 남긴다.
/// 저장소 안에는 쓰지 않는다.
final class StatisticsCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false) ? environment! : "/tmp/vf-statistics-captures"
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @discardableResult
    private func launch(
        _ fixture: String,
        teamID: String = "samsung-lions",
        accessibilitySize: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "statistics",
            "-VFUITestStatisticsFixture", fixture
        ]
        if accessibilitySize {
            arguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(
            node(app, "statistics.scenario.\(fixture)").waitForExistence(timeout: 15),
            "픽스처 \(fixture)가 적용되지 않았다"
        )
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

    /// 아래쪽 섹션을 찍으려면 먼저 스크롤해야 한다.
    private func scroll(_ app: XCUIApplication, to identifier: String) {
        let element = node(app, identifier)
        for _ in 0..<12 {
            if element.exists, element.isHittable { return }
            app.swipeUp()
            usleep(320_000)
        }
    }

    /// 실행 인자만으로 만들 수 있는 상태.
    private func captureSimple(_ fixture: String, _ name: String, teamID: String = "samsung-lions") {
        let app = launch(fixture, teamID: teamID)
        capture(app, name)
        app.terminate()
    }

    // MARK: - 1~16 · 상태 매트릭스

    func testCapture01_referenceSeason() { captureSimple("referenceSeason", "01-reference-season") }
    func testCapture02_multipleSeasons() { captureSimple("multipleSeasons", "02-multiple-seasons") }
    func testCapture03_previousSeason() { captureSimple("previousSeason", "03-previous-season") }
    func testCapture04_emptySeason() { captureSimple("empty", "04-empty-season") }
    func testCapture05_oneRecord() { captureSimple("oneRecord", "05-one-record") }
    func testCapture06_insufficientData() { captureSimple("insufficientData", "06-insufficient-data") }
    func testCapture07_noStadium() { captureSimple("noStadium", "07-no-stadium") }
    func testCapture08_missingScore() { captureSimple("missingScore", "08-missing-score") }
    func testCapture09_winOnly() { captureSimple("winOnly", "09-win-only") }
    func testCapture10_lossOnly() { captureSimple("lossOnly", "10-loss-only") }
    func testCapture11_drawOnly() { captureSimple("drawOnly", "11-draw-only") }
    func testCapture12_cancelledOnly() { captureSimple("cancelledOnly", "12-cancelled-only") }
    func testCapture13_mixedResults() { captureSimple("mixedResults", "13-mixed-results") }
    func testCapture14_loading() { captureSimple("loading", "14-loading") }
    func testCapture15_recoverableError() { captureSimple("recoverableError", "15-recoverable-error") }
    func testCapture16_retrySuccess() { captureSimple("retrySuccess", "16-retry-success") }

    // MARK: - 17~19 · 스크롤이 필요한 섹션

    func testCapture17_resultDistribution() {
        let app = launch("referenceSeason")
        scroll(app, to: "statistics.distribution")
        capture(app, "17-result-distribution")
    }

    func testCapture18_attendanceTrend() {
        let app = launch("referenceSeason")
        scroll(app, to: "statistics.trend.summary")
        capture(app, "18-attendance-trend")
    }

    func testCapture19_stadiumAnalysis() {
        let app = launch("allStadiums")
        scroll(app, to: "statistics.stadiumAnalysis")
        capture(app, "19-stadium-analysis")
    }

    // MARK: - 20~23 · 폭과 글자 크기

    func testCapture20_compactPopulated() {
        let app = launch("compactReference")
        capture(app, "20-compact-populated")
    }

    func testCapture21_compactDataHeavy() {
        let app = launch("allStadiums")
        scroll(app, to: "statistics.stadiumAnalysis")
        capture(app, "21-compact-data-heavy")
    }

    func testCapture22_accessibilityPopulated() {
        let app = launch("accessibilityReference", accessibilitySize: true)
        capture(app, "22-accessibility-populated")
    }

    func testCapture23_accessibilityErrorAndRetry() {
        let app = launch("recoverableError", accessibilitySize: true)
        capture(app, "23-accessibility-error-retry")
    }

    // MARK: - 24~28 · 이름과 강조색, 시즌 목록

    func testCapture24_longTeamName() {
        captureSimple("longTeamName", "24-long-team-name", teamID: "hanwha-eagles")
    }

    func testCapture25_longStadiumName() {
        let app = launch("longStadiumName")
        scroll(app, to: "statistics.stadiumAnalysis")
        capture(app, "25-long-stadium-name")
    }

    func testCapture26_lightTeamAccent() {
        captureSimple("lightTeamAccent", "26-light-team-accent", teamID: "hanwha-eagles")
    }

    func testCapture27_darkTeamAccent() {
        captureSimple("darkTeamAccent", "27-dark-team-accent", teamID: "kt-wiz")
    }

    func testCapture28_allSeasonOptions() {
        let app = launch("multipleSeasons")
        node(app, "statistics.selectedSeason").tap()
        XCTAssertTrue(node(app, "statistics.seasonPicker").waitForExistence(timeout: 8), "시즌 목록이 열리지 않았다")
        capture(app, "28-all-season-options")
    }
}
