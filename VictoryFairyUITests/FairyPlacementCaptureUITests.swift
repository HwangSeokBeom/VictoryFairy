import XCTest

/// 페어리 배치 캡처 매트릭스를 만든다.
///
/// 검증이 아니라 **증거를 남기는 것**이 목적이다. 각 캡처는 화면이나 픽스처 표식을
/// 확인한 뒤에 찍으므로, 무엇을 찍었는지가 파일 이름과 실제 화면에서 함께 확인된다.
///
/// 저장 위치는 `VF_CAPTURE_DIR`, 파일 이름 앞의 기기 꼬리표는 `VF_CAPTURE_TAG`로
/// 정한다. 저장소 안에는 쓰지 않는다.
final class FairyPlacementCaptureUITests: XCTestCase {

    private var captureDirectory: URL {
        let environment = ProcessInfo.processInfo.environment["VF_CAPTURE_DIR"]
        let path = (environment?.isEmpty == false) ? environment! : "/tmp/vf-fairy-placement-captures"
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

    private func launch(_ extra: [String], accessibilitySize: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset"] + extra
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName",
                          "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
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

    private func home(_ teamID: String, stadium: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestTeamID", teamID, "-VFUITestStadiumID", stadium,
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "home"],
                         accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "home.teamIdentity")), "\(teamID): 홈 팀 아이덴티티가 없다")
        return app
    }

    private func calendar(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "calendar",
                          "-VFUITestCalendarFixture", fixture],
                         accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "calendar.scenario.\(fixture)")), "\(fixture): 픽스처가 적용되지 않았다")
        return app
    }

    private func statistics(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "statistics",
                          "-VFUITestStatisticsFixture", fixture],
                         accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "statistics.scenario.\(fixture)")), "\(fixture): 픽스처가 적용되지 않았다")
        return app
    }

    private func feed(_ fixture: String, accessibilitySize: Bool = false) -> XCUIApplication {
        let app = launch(["-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
                          "-VFUITestOnboardingCompleted", "1", "-VFUITestInitialTab", "feed",
                          "-VFUITestFeedFixture", fixture],
                         accessibilitySize: accessibilitySize)
        XCTAssertTrue(waits(node(app, "screen.feed")), "\(fixture): 피드에 들어가지 못했다")
        return app
    }

    // MARK: - 홈

    func test01_homeTeamIdentity() {
        let app = home("samsung-lions", stadium: "daegu-lions")
        capture("01-home-default-teamFairy")
        app.terminate()

        // 밝은 강조색과 어두운 강조색을 각각 남긴다.
        let light = home("hanwha-eagles", stadium: "daejeon-hanwha")
        capture("03-home-lightAccent-hanwha")
        light.terminate()

        let dark = home("doosan-bears", stadium: "jamsil")
        capture("04-home-darkAccent-doosan")
        dark.terminate()

        let large = home("kiwoom-heroes", stadium: "gocheok", accessibilitySize: true)
        capture("06-home-accessibilityXXXL")
        _ = large
    }

    /// 중립 팀 페어리는 홈에서 나올 수 없다(홈은 언제나 유효한 팀을 갖는다).
    /// 실제로 중립이 보이는 제품 자리는 아직 팀을 고르지 않은 온보딩 팀 단계다.
    func test02_neutralTeamIdentityInOnboarding() {
        let app = launch([])
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")), "팀 단계에 닿지 못했다")
        capture("02-neutral-team-not-yet-chosen")
    }

    // MARK: - 온보딩 완료

    private func reachCompletion(_ app: XCUIApplication, team: String, stadium: String) {
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")))
        let teamCard = app.buttons["onboarding.team.\(team)"]
        if !teamCard.exists { app.swipeUp() }
        XCTAssertTrue(waits(teamCard))
        teamCard.tap()
        app.buttons["onboarding.team.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")))
        let stadiumCard = app.buttons["onboarding.stadium.\(stadium)"]
        if !stadiumCard.exists { app.swipeUp() }
        XCTAssertTrue(waits(stadiumCard))
        stadiumCard.tap()
        app.buttons["onboarding.stadium.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.complete")), "완료 화면에 닿지 못했다")
    }

    func test03_onboardingCompletion() {
        let first = launch([])
        reachCompletion(first, team: "nc-dinos", stadium: "changwon-nc")
        capture("07-onboarding-complete-teamA-nc")
        capture("09-onboarding-complete-success")
        first.terminate()

        let second = launch([])
        reachCompletion(second, team: "kt-wiz", stadium: "suwon-kt")
        capture("08-onboarding-complete-teamB-kt")
        second.terminate()

        let large = launch([], accessibilitySize: true)
        reachCompletion(large, team: "lotte-giants", stadium: "sajik")
        capture("11-onboarding-complete-accessibilityXXXL")
    }

    // MARK: - 캘린더

    func test04_calendarResults() {
        for (fixture, name) in [("win", "12-calendar-win"), ("loss", "13-calendar-loss"),
                                ("draw", "14-calendar-draw"), ("cancelled", "15-calendar-cancelled"),
                                ("selectedEmptyDate", "16-calendar-noResult")] {
            let app = calendar(fixture)
            XCTAssertTrue(waits(node(app, "calendar.selectedDetail")), "\(fixture): 선택일 미리보기가 없다")
            capture(name)
            app.terminate()
        }
        let large = calendar("accessibilityReference", accessibilitySize: true)
        _ = large
        capture("18-calendar-accessibilityXXXL")
    }

    // MARK: - 시즌 아카이브

    func test05_statisticsSeasons() {
        for (fixture, name) in [("referenceSeason", "19-statistics-positiveSeason"),
                                ("lossOnly", "20-statistics-losingSeason"),
                                ("empty", "21-statistics-emptySeason")] {
            let app = statistics(fixture)
            capture(name)
            app.terminate()
        }
        let large = statistics("referenceSeason", accessibilitySize: true)
        _ = large
        capture("23-statistics-accessibilityXXXL")
    }

    // MARK: - 공용 상태

    func test06_sharedStates() {
        let emptyRecord = feed("empty")
        XCTAssertTrue(waits(node(emptyRecord, "feed.empty")), "빈 기록 패널이 없다")
        capture("24-state-emptyRecord")
        emptyRecord.terminate()

        let emptySeason = statistics("empty")
        XCTAssertTrue(waits(node(emptySeason, "statistics.empty")), "빈 시즌 패널이 없다")
        capture("25-state-emptySeason")
        emptySeason.terminate()

        let error = statistics("recoverableError")
        XCTAssertTrue(waits(node(error, "statistics.error")), "오류 패널이 없다")
        capture("26-state-error")
        error.terminate()

        let loading = statistics("loading")
        XCTAssertTrue(waits(node(loading, "statistics.loading")), "로딩 패널이 없다")
        capture("27-state-loading-noFairy")
        loading.terminate()

        // 필터 결과 0건 = Pencil `검색 없음`. 페어리 자리를 비워 둔다.
        let searchEmpty = feed("populated")
        let cancelledChip = searchEmpty.buttons["취소된 날"]
        XCTAssertTrue(waits(cancelledChip), "결과 필터 칩이 없다")
        cancelledChip.tap()
        XCTAssertTrue(waits(node(searchEmpty, "feed.filteredEmpty")), "필터 결과 0건 패널이 없다")
        capture("28-state-searchEmpty-noFairy")
        searchEmpty.terminate()

        let largeError = statistics("recoverableError", accessibilitySize: true)
        XCTAssertTrue(waits(node(largeError, "statistics.error")), "큰 글자에서 오류 패널이 없다")
        capture("30-state-error-accessibilityXXXL")
    }

    // MARK: - 완료 화면 회귀

    func test07_regressionScreens() {
        let app = feed("populated")
        capture("31-regression-feed")
        let firstRecord = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(firstRecord), "피드에 기록이 없다")
        firstRecord.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "기록 상세에 들어가지 못했다")
        capture("32-regression-recordDetail")
    }

    // MARK: - 좁은 폭 전용

    /// 좁은 폭 기기에서 실행할 때만 의미가 있다. 같은 화면을 375pt에서 남긴다.
    func test08_compactCaptures() {
        let app = home("kiwoom-heroes", stadium: "gocheok")
        capture("05-home-compact")
        app.terminate()

        let onboarding = launch([])
        reachCompletion(onboarding, team: "lotte-giants", stadium: "sajik")
        capture("10-onboarding-complete-compact")
        onboarding.terminate()

        let cal = calendar("compactReference")
        capture("17-calendar-compact")
        cal.terminate()

        let stats = statistics("referenceSeason")
        capture("22-statistics-compact")
        stats.terminate()

        let error = statistics("recoverableError")
        XCTAssertTrue(waits(node(error, "statistics.error")), "오류 패널이 없다")
        capture("29-state-error-compact")
    }
}
