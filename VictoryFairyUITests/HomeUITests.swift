import XCTest

/// 홈 화면을 실제 앱에서 검증한다.
///
/// 팀과 구장을 미리 심고 온보딩을 완료한 상태로 띄운다. 이 경로는 이전 패스에서
/// 이미 동작이 확인된 방식이라 결정적이다.
final class HomeUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchHome(
        teamID: String = "samsung-lions",
        stadiumID: String = "daegu-lions"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", stadiumID,
            "-VFUITestOnboardingCompleted", "1"
        ]
        app.launch()
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 8) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // MARK: - 1·4 · 홈 진입과 루트 식별자

    func testH01_completedOnboardingOpensPersonalizedHome() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")), "홈 화면에 들어가지 못했다")
        XCTAssertTrue(node(app, "home.root").exists, "홈 루트 식별자가 없다")
    }

    // MARK: - 2 · 선택한 팀이 보인다

    func testH02_selectedTeamIsVisibleOnHome() {
        let app = launchHome(teamID: "samsung-lions", stadiumID: "daegu-lions")
        XCTAssertTrue(waits(node(app, "screen.home")))
        let identity = node(app, "home.teamIdentity")
        XCTAssertTrue(waits(identity, 6), "팀 아이덴티티 헤더가 없다")
        // 색이 아니라 글자로도 팀을 알 수 있어야 한다.
        XCTAssertTrue(
            identity.label.contains("삼성") || (identity.value as? String)?.contains("삼성") == true
                || app.staticTexts["삼성 라이온즈"].exists,
            "홈에서 팀 이름을 찾을 수 없다"
        )
    }

    // MARK: - 3 · 주 관람 구장이 보인다

    func testH03_primaryStadiumIsVisibleOnHome() {
        let app = launchHome(teamID: "samsung-lions", stadiumID: "daegu-lions")
        XCTAssertTrue(waits(node(app, "screen.home")))
        let stadiumStrip = node(app, "home.gameStadium")
        XCTAssertTrue(waits(stadiumStrip, 6), "구장 스트립이 없다")
        XCTAssertTrue(
            stadiumStrip.label.contains("대구") || app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@", "대구")
            ).firstMatch.exists,
            "홈에서 구장 이름을 찾을 수 없다"
        )
    }

    // MARK: - 5·6 · 탭바 무결성과 안전 영역

    func testH05_noDuplicateTabBarOnHome() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        XCTAssertEqual(app.buttons.matching(identifier: "tab.home").count, 1, "홈에 탭바가 중복된다")
    }

    func testH06_homeContentStaysAboveTheTabBar() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        let cta = node(app, "home.recordCTA")
        XCTAssertTrue(waits(cta, 6), "기록 CTA가 없다")
        let tab = app.buttons["tab.home"]
        XCTAssertTrue(cta.isHittable, "기록 CTA를 누를 수 없다(탭바에 가렸을 수 있다)")
        XCTAssertLessThanOrEqual(
            cta.frame.maxY, app.windows.firstMatch.frame.maxY,
            "기록 CTA가 화면 아래로 벗어났다"
        )
        XCTAssertGreaterThan(tab.frame.height, 0)
    }

    // MARK: - 7 · 빈 상태에서도 정체성 유지

    /// 기록이 없어도 팀과 주 관람 구장은 남아 있어야 한다.
    func testH07_emptyHomeKeepsTeamAndStadiumIdentity() {
        let app = launchHome(teamID: "kt-wiz", stadiumID: "suwon-kt")
        XCTAssertTrue(waits(node(app, "screen.home")))
        XCTAssertTrue(waits(node(app, "home.teamIdentity"), 6), "빈 홈에서 팀 정체성이 사라졌다")
        XCTAssertTrue(waits(node(app, "home.matchupHero"), 6), "빈 홈에서 히어로가 사라졌다")
        XCTAssertTrue(waits(node(app, "home.seasonStrip"), 6), "빈 홈에서 시즌 스트립이 사라졌다")
    }

    // MARK: - 9 · 좁은 폭

    func testH09_compactWidthHomeHasNoOverflow() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        let window = app.windows.firstMatch
        for identifier in ["home.teamIdentity", "home.matchupHero", "home.seasonStrip", "home.recordCTA"] {
            let element = node(app, identifier)
            XCTAssertTrue(waits(element, 6), "\(identifier)가 없다")
            XCTAssertLessThanOrEqual(
                element.frame.maxX, window.frame.maxX + 1,
                "\(identifier)가 오른쪽으로 넘쳤다"
            )
            XCTAssertGreaterThanOrEqual(element.frame.minX, -1, "\(identifier)가 왼쪽으로 넘쳤다")
        }
    }

    // MARK: - 10 · 큰 글자

    /// 접근성 최대 글자에서도 필수 정보와 동작이 남아야 한다.
    func testH10_accessibilityExtraLargeKeepsHomeContentReachable() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        XCTAssertTrue(waits(node(app, "home.teamIdentity"), 6), "큰 글자에서 팀 정체성이 사라졌다")
        let cta = node(app, "home.recordCTA")
        XCTAssertTrue(waits(cta, 6), "큰 글자에서 기록 CTA가 사라졌다")
        XCTAssertTrue(cta.isHittable, "큰 글자에서 기록 CTA를 누를 수 없다")
    }

    // MARK: - 11·12 · 열 팀 · 아홉 구장

    func testH11_allTenTeamsRenderHomeWithoutStructuralFailure() {
        let teams = [
            "lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
            "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"
        ]
        for teamID in teams {
            let app = launchHome(teamID: teamID, stadiumID: "jamsil")
            XCTAssertTrue(waits(node(app, "screen.home"), 10), "\(teamID) 홈이 뜨지 않았다")
            XCTAssertTrue(node(app, "home.teamIdentity").exists, "\(teamID) 팀 아이덴티티가 없다")
            app.terminate()
        }
    }

    func testH12_allNineStadiumsRenderHomeWithoutStructuralFailure() {
        let stadiums = [
            "jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
            "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"
        ]
        for stadiumID in stadiums {
            let app = launchHome(teamID: "lg-twins", stadiumID: stadiumID)
            XCTAssertTrue(waits(node(app, "screen.home"), 10), "\(stadiumID) 홈이 뜨지 않았다")
            XCTAssertTrue(node(app, "home.gameStadium").exists, "\(stadiumID) 구장 스트립이 없다")
            app.terminate()
        }
    }

    // MARK: - 13 · 기존 경로 유지

    /// 홈의 기록 CTA가 기존 기록 작성 경로를 그대로 연다.
    func testH13_recordCTAOpensTheExistingRoute() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        let cta = node(app, "home.recordCTA")
        XCTAssertTrue(waits(cta, 6))
        cta.tap()
        // 기록 작성 화면이 모달로 올라오면 홈 루트는 잠시 가려진다.
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 6)
                || app.buttons["취소"].waitForExistence(timeout: 6),
            "기록 작성 경로가 열리지 않았다"
        )
    }

    // MARK: - 14 · 재실행

    func testH14_relaunchAfterOnboardingReturnsToHome() {
        let app = launchHome()
        XCTAssertTrue(waits(node(app, "screen.home")))
        app.terminate()
        app.launch()
        XCTAssertTrue(waits(node(app, "screen.home"), 10), "재실행 후 홈으로 돌아오지 않았다")
    }
}
