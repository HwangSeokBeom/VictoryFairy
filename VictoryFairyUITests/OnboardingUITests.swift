import XCTest

/// 온보딩 흐름을 실제 앱에서 자동으로 검증한다.
///
/// 상태는 `-VFUITest` 실행 인자로만 만든다. 앱은 이 인자가 없으면 그 코드를 타지 않으므로
/// 테스트 설정이 제품 동작으로 새지 않는다.
final class OnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        // 여기 있던 일괄 건너뛰기 가드를 걷어냈다.
        //
        // 그 가드는 "재설계된 온보딩에는 소개 단계와 `onboarding.overview.next`가
        // 없다"는 이유로 이름만 보고 열세 개를 건너뛰었다. 저장소를 확인해 보니
        // 사실이 아니다 — `OnboardingViewModel`에 `case overview`가 있고
        // `OnboardingView`가 `onboarding.overview.next` 식별자를 실제로 붙인다.
        // Pencil `11_Developer_Handoff`도 `/onboarding/overview`를 5단계 중 2단계로
        // 못박는다. 즉 단계도 식별자도 살아 있고, 가드가 멀쩡한 검사를 가리고 있었다.
        //
        // 이름으로 검사를 끄는 장치를 두지 않는다. 실패하는 것이 있으면 실패로
        // 드러나야 하고, 건너뛰기로 감추지 않는다.
    }

    // MARK: - 앱 실행 도우미

    /// 첫 실행 상태로 앱을 띄운다.
    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VFUITest", "-VFUITestReset"]
        app.launch()
        return app
    }

    /// 저장된 설정을 심고 앱을 띄운다.
    private func launch(teamID: String? = nil,
                        stadiumID: String? = nil,
                        onboardingCompleted: Bool? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["-VFUITest", "-VFUITestReset"]
        if let teamID { arguments += ["-VFUITestTeamID", teamID] }
        if let stadiumID { arguments += ["-VFUITestStadiumID", stadiumID] }
        if let onboardingCompleted {
            arguments += ["-VFUITestOnboardingCompleted", onboardingCompleted ? "1" : "0"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 8) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// SwiftUI가 컨테이너를 어떤 요소 종류로 노출할지는 보장되지 않는다.
    /// 식별자만 보고 어떤 종류든 찾는다.
    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    // MARK: - 1~2 · 첫 실행과 소개

    func test01_newInstallOpensWelcome() {
        let app = launchFresh()
        XCTAssertTrue(waits(node(app, "onboarding.welcome")), "첫 실행에서 환영 화면이 뜨지 않았다")
    }

    func test02_overviewIsReachable() {
        let app = launchFresh()
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.overview")), "소개 화면에 닿지 못했다")
    }

    // MARK: - 3~5 · 팀 선택

    /// 소개까지 진행해 팀 선택 화면을 띄운다.
    private func advanceToTeamStep(_ app: XCUIApplication) {
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")))
    }

    func test03_teamStepCannotAdvanceWithoutSelection() {
        let app = launchFresh()
        advanceToTeamStep(app)
        let next = app.buttons["onboarding.team.next"]
        XCTAssertTrue(waits(next))
        XCTAssertFalse(next.isEnabled, "팀을 고르지 않았는데 다음 버튼이 활성화돼 있다")
        next.tap()
        XCTAssertTrue(node(app, "onboarding.selectTeam").exists, "선택 없이 단계가 넘어갔다")
    }

    func test04_allTenTeamsAreReachable() {
        let app = launchFresh()
        advanceToTeamStep(app)
        let ids = [
            "lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
            "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"
        ]
        for id in ids {
            let card = app.buttons["onboarding.team.\(id)"]
            if !card.exists {
                // 목록이 길면 스크롤해서 찾는다.
                app.swipeUp()
            }
            XCTAssertTrue(waits(card, 4), "\(id) 팀 카드에 닿지 못했다")
        }
    }

    func test05_selectingTeamEnablesCTA() {
        let app = launchFresh()
        advanceToTeamStep(app)
        app.buttons["onboarding.team.lg-twins"].tap()
        let next = app.buttons["onboarding.team.next"]
        XCTAssertTrue(next.isEnabled, "팀을 골랐는데 다음 버튼이 잠겨 있다")
    }

    // MARK: - 6~8 · 구장 선택

    private func advanceToStadiumStep(_ app: XCUIApplication, teamID: String = "lg-twins") {
        advanceToTeamStep(app)
        app.buttons["onboarding.team.\(teamID)"].tap()
        app.buttons["onboarding.team.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")))
    }

    func test06_stadiumStepCannotAdvanceWithoutSelection() {
        let app = launchFresh()
        advanceToStadiumStep(app)
        let next = app.buttons["onboarding.stadium.next"]
        XCTAssertTrue(waits(next))
        XCTAssertFalse(next.isEnabled, "구장을 고르지 않았는데 다음 버튼이 활성화돼 있다")
        next.tap()
        XCTAssertTrue(node(app, "onboarding.selectStadium").exists, "선택 없이 단계가 넘어갔다")
    }

    func test07_allNineStadiumsAreReachable() {
        let app = launchFresh()
        advanceToStadiumStep(app)
        let ids = [
            "jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
            "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"
        ]
        for id in ids {
            let card = app.buttons["onboarding.stadium.\(id)"]
            if !card.exists { app.swipeUp() }
            XCTAssertTrue(waits(card, 4), "\(id) 구장 카드에 닿지 못했다")
        }
    }

    func test08_selectingStadiumEnablesCTA() {
        let app = launchFresh()
        advanceToStadiumStep(app)
        app.buttons["onboarding.stadium.jamsil"].tap()
        XCTAssertTrue(app.buttons["onboarding.stadium.next"].isEnabled)
    }

    // MARK: - 9~10 · 완료와 재실행

    private func completeOnboarding(_ app: XCUIApplication,
                                    teamID: String = "lg-twins",
                                    stadiumID: String = "jamsil") {
        advanceToStadiumStep(app, teamID: teamID)
        app.buttons["onboarding.stadium.\(stadiumID)"].tap()
        app.buttons["onboarding.stadium.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.complete")))
        app.buttons["onboarding.complete.finish"].tap()
    }

    func test09_completionEntersPersonalizedHome() {
        let app = launchFresh()
        completeOnboarding(app)
        XCTAssertTrue(waits(node(app, "screen.home")), "완료 후 홈에 들어가지 못했다")
        XCTAssertTrue(app.buttons["tab.home"].exists, "홈 진입 후 탭바가 없다")
    }

    func test10_completedOnboardingDoesNotRepeatAfterRelaunch() {
        // 이미 두 값을 가진 사용자로 실행한다.
        let app = launch(teamID: "kt-wiz", stadiumID: "suwon-kt", onboardingCompleted: true)
        XCTAssertTrue(waits(node(app, "screen.home")), "완료된 사용자에게 홈이 뜨지 않았다")
        XCTAssertFalse(node(app, "onboarding.welcome").exists, "온보딩이 다시 나타났다")
    }

    // MARK: - 11~15 · 재개와 마이그레이션

    func test11_interruptedOnboardingResumesAtCorrectStep() {
        // 팀만 저장된 상태 = 구장 단계에서 재개.
        let app = launch(teamID: "kia-tigers", onboardingCompleted: false)
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")), "구장 단계에서 재개하지 않았다")
        XCTAssertFalse(node(app, "onboarding.selectTeam").exists, "이미 고른 팀을 다시 묻고 있다")
    }

    func test12_existingUserWithTeamOnlyEntersStadiumRepair() {
        let app = launch(teamID: "doosan-bears", onboardingCompleted: true)
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")), "구장 보완 단계로 가지 않았다")
        // 홈 구장이 맨 위에 추천으로 나와야 한다.
        XCTAssertTrue(app.buttons["onboarding.stadium.jamsil"].exists)
    }

    func test13_existingUserWithBothValuesBypassesOnboarding() {
        let app = launch(teamID: "nc-dinos", stadiumID: "changwon-nc", onboardingCompleted: true)
        XCTAssertTrue(waits(node(app, "screen.home")))
        XCTAssertFalse(node(app, "onboarding.selectTeam").exists)
        XCTAssertFalse(node(app, "onboarding.selectStadium").exists)
    }

    func test14_invalidStoredTeamEntersTeamRepair() {
        let app = launch(teamID: "not-a-real-team", stadiumID: "sajik", onboardingCompleted: true)
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")), "팀 보완 단계로 가지 않았다")
        XCTAssertFalse(node(app, "onboarding.selectStadium").exists, "구장까지 다시 묻고 있다")
    }

    func test15_invalidStoredStadiumEntersStadiumRepair() {
        let app = launch(teamID: "samsung-lions", stadiumID: "not-a-real-stadium", onboardingCompleted: true)
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")), "구장 보완 단계로 가지 않았다")
        XCTAssertFalse(node(app, "onboarding.selectTeam").exists, "팀까지 다시 묻고 있다")
    }
}
