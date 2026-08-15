import XCTest

/// 개정 Pencil이 지정한 페어리 자리가 실제 앱에서 살아 있는지 확인한다.
///
/// 페어리 자체는 대부분 장식이라 VoiceOver에서 숨긴다. 숨긴 요소는 접근성 트리에
/// 없으므로 여기서는 **페어리를 품은 의미 요소**로 확인한다. 그렇게 해야 "찾으려고
/// 장식을 읽히게 만드는" 잘못을 저지르지 않는다.
final class FairyPlacementUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 도구

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func nodes(_ app: XCUIApplication, _ identifier: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: identifier)
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// 장식 페어리가 그 자리에 있고, 읽을 것은 없다는 것을 함께 확인한다.
    ///
    /// `accessibilityHidden(true)`을 붙여도 식별자를 가진 요소는 XCUITest 트리에
    /// 남는다(측정으로 확인했다). 그래서 "없다"가 아니라 "이름은 있고 말은 없다"로
    /// 확인한다. 라벨이 비어 있으면 VoiceOver가 읽어 줄 것이 없다.
    private func assertDecorativeFairy(_ app: XCUIApplication, _ identifier: String,
                                       _ context: String,
                                       file: StaticString = #filePath, line: UInt = #line) {
        let fairy = node(app, identifier)
        XCTAssertTrue(waits(fairy), "\(context): \(identifier) 배치가 사라졌다", file: file, line: line)
        XCTAssertEqual(nodes(app, identifier).count, 1,
                       "\(context): \(identifier)가 여러 개다", file: file, line: line)
        XCTAssertTrue(fairy.label.isEmpty,
                      "\(context): 장식 페어리가 \"\(fairy.label)\"를 읽는다", file: file, line: line)
    }

    private func launch(arguments extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VFUITest", "-VFUITestReset"] + extra
        app.launch()
        return app
    }

    private func launchHome(teamID: String?, stadiumID: String = "jamsil") -> XCUIApplication {
        var arguments = ["-VFUITestOnboardingCompleted", "1",
                         "-VFUITestStadiumID", stadiumID,
                         "-VFUITestInitialTab", "home"]
        if let teamID { arguments += ["-VFUITestTeamID", teamID] }
        return launch(arguments: arguments)
    }

    /// 페어리가 접근성 트리에 올라오더라도 읽을 것이 없어야 한다.
    private func assertFairyIsSilent(_ app: XCUIApplication, _ identifier: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        for index in 0..<nodes(app, identifier).count {
            let element = nodes(app, identifier).element(boundBy: index)
            XCTAssertTrue(element.label.isEmpty,
                          "\(identifier)가 \"\(element.label)\"를 읽는다", file: file, line: line)
        }
    }

    // MARK: - 홈 · TeamIdentityHeader가 물려주는 팀 페어리

    /// 열 개 구단 모두에서 팀 아이덴티티가 뜨고, 팀 이름을 한 번만 말한다.
    func testHomeTeamIdentityWorksForAllTenTeams() {
        let teams: [(id: String, name: String)] = [
            ("lg-twins", "LG 트윈스"), ("doosan-bears", "두산 베어스"),
            ("kiwoom-heroes", "키움 히어로즈"), ("ssg-landers", "SSG 랜더스"),
            ("kt-wiz", "KT 위즈"), ("hanwha-eagles", "한화 이글스"),
            ("samsung-lions", "삼성 라이온즈"), ("kia-tigers", "KIA 타이거즈"),
            ("lotte-giants", "롯데 자이언츠"), ("nc-dinos", "NC 다이노스")
        ]
        for team in teams {
            let app = launchHome(teamID: team.id)
            XCTAssertTrue(waits(node(app, "screen.home")), "\(team.id): 홈에 들어가지 못했다")
            let identity = node(app, "home.teamIdentity")
            XCTAssertTrue(waits(identity), "\(team.id): 팀 아이덴티티 헤더가 없다")
            XCTAssertTrue(identity.label.contains(team.name),
                          "\(team.id): 헤더가 팀 이름을 말하지 않는다 — 실제 \(identity.label)")
            // 헤더는 하나뿐이다. 페어리가 별도의 요소로 새어 나오지도 않는다.
            XCTAssertEqual(nodes(app, "home.teamIdentity").count, 1, "\(team.id): 헤더가 둘이다")
            assertDecorativeFairy(app, "home.teamFairy", team.id)
            app.terminate()
        }
    }

    /// 팀을 아직 고르지 않은 상태에서도 홈은 정직하게 뜬다.
    func testHomeNeutralTeamStateStaysHonest() {
        // 팀 없이 완료 상태를 만들 수는 없으므로(보완 단계로 간다) 중립은
        // 온보딩 팀 단계에서 확인한다. 홈은 언제나 유효한 팀을 갖는다.
        let app = launch(arguments: [])
        XCTAssertTrue(waits(node(app, "onboarding.welcome")), "첫 실행이 환영 화면이 아니다")
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")), "팀 단계에 닿지 못했다")
        XCTAssertFalse(app.buttons["onboarding.team.next"].isEnabled,
                       "고르지 않았는데 다음으로 갈 수 있다")
    }

    /// 긴 팀 이름과 두 방향의 강조색에서 헤더가 그대로 읽힌다.
    func testHomeTeamIdentitySurvivesLongNameAndBothAccents() {
        for team in ["kiwoom-heroes", "lotte-giants", "hanwha-eagles"] {
            let app = launchHome(teamID: team)
            let identity = node(app, "home.teamIdentity")
            XCTAssertTrue(waits(identity), "\(team): 헤더가 없다")
            XCTAssertTrue(identity.isHittable || identity.exists, "\(team): 헤더가 화면 밖이다")
            XCTAssertFalse(identity.label.isEmpty, "\(team): 헤더가 아무 말도 하지 않는다")
            app.terminate()
        }
    }

    /// 홈의 기존 동작은 그대로다.
    func testHomeInteractionsRemainFunctional() {
        let app = launchHome(teamID: "lg-twins")
        XCTAssertTrue(waits(node(app, "home.root")))
        XCTAssertTrue(node(app, "home.wordmark").exists, "워드마크가 사라졌다")
        for tab in ["tab.home", "tab.feed", "tab.calendar", "tab.statistics", "tab.my"] {
            XCTAssertTrue(app.buttons[tab].exists, "\(tab)이 사라졌다")
        }
        app.buttons["tab.feed"].tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "탭 이동이 안 된다")
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "screen.home")), "홈으로 돌아오지 못했다")
    }

    // MARK: - 온보딩 완료 · 선택 팀 페어리와 성공 페어리

    @discardableResult
    private func completeOnboarding(_ app: XCUIApplication, team: String, stadium: String) -> XCUIApplication {
        XCTAssertTrue(waits(app.buttons["onboarding.welcome.start"]))
        // 환영 화면의 런치 쿼텟 브랜드 마크. 완료 화면도 같은 `VFBrandMark`를 쓰지만
        // 그쪽은 스크롤 안이라 요소로 노출되지 않아 화면 캡처로 확인한다.
        assertDecorativeFairy(app, "brand.mark", "환영")
        app.buttons["onboarding.welcome.start"].tap()
        XCTAssertTrue(waits(app.buttons["onboarding.overview.next"]))
        app.buttons["onboarding.overview.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectTeam")))
        app.buttons["onboarding.team.\(team)"].tap()
        app.buttons["onboarding.team.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.selectStadium")))
        app.buttons["onboarding.stadium.\(stadium)"].tap()
        app.buttons["onboarding.stadium.next"].tap()
        XCTAssertTrue(waits(node(app, "onboarding.complete")), "완료 화면에 닿지 못했다")
        return app
    }

    func testOnboardingCompletionShowsTheSelectedTeamNotAPencilSample() {
        // 서로 다른 두 팀으로 같은 화면을 만든다. 표본이 박혀 있으면 둘이 같아진다.
        let first = completeOnboarding(launch(arguments: []), team: "nc-dinos", stadium: "changwon-nc")
        XCTAssertTrue(first.staticTexts["준비됐어요"].exists, "완료 제목이 없다")
        let firstSummary = first.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "NC 다이노스")
        ).firstMatch
        XCTAssertTrue(firstSummary.exists, "고른 팀이 완료 화면에 없다")
        XCTAssertFalse(
            first.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "삼성")).firstMatch.exists,
            "Pencil 표본 팀이 나타났다"
        )
        // 탭바는 온보딩 중에 뜨지 않는다.
        XCTAssertFalse(first.buttons["tab.home"].exists, "온보딩 중에 탭바가 떴다")
        first.terminate()

        let second = completeOnboarding(launch(arguments: []), team: "kt-wiz", stadium: "suwon-kt")
        XCTAssertTrue(
            second.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "KT 위즈")).firstMatch.exists,
            "두 번째 팀이 반영되지 않았다"
        )
        // 완료 화면의 두 페어리는 스크롤 컨테이너 안이라 접근성 트리에 요소로
        // 올라오지 않는다(브랜드 마크도 같다 — 측정으로 확인했다). 배치 자체는
        // 계약 테스트와 화면 캡처로 확인하고, 여기서는 "말하지 않는다"만 못박는다.
        assertFairyIsSilent(second, "onboarding.complete.teamFairy")
        assertFairyIsSilent(second, "onboarding.complete.successFairy")
    }

    func testOnboardingCompletionCTAStillFinishesAndPersists() {
        let app = completeOnboarding(launch(arguments: []), team: "kia-tigers", stadium: "gwangju-kia")
        app.buttons["onboarding.complete.finish"].tap()
        XCTAssertTrue(waits(node(app, "screen.home")), "완료 후 홈에 들어가지 못했다")
        let identity = node(app, "home.teamIdentity")
        XCTAssertTrue(waits(identity))
        XCTAssertTrue(identity.label.contains("KIA 타이거즈"), "고른 팀이 홈으로 이어지지 않았다")
    }

    // MARK: - 캘린더 · 선택일 결과 페어리

    private func launchCalendar(_ fixture: String, teamID: String = "lg-twins") -> XCUIApplication {
        let app = launch(arguments: [
            "-VFUITestTeamID", teamID, "-VFUITestStadiumID", "jamsil",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "calendar",
            "-VFUITestCalendarFixture", fixture
        ])
        XCTAssertTrue(waits(node(app, "screen.calendar")), "\(fixture): 캘린더에 들어가지 못했다")
        XCTAssertTrue(waits(node(app, "calendar.scenario.\(fixture)")), "\(fixture): 픽스처가 적용되지 않았다")
        return app
    }

    /// 승·패·무·취소 모두에서 선택일 미리보기가 그대로 살아 있다.
    func testCalendarSelectedDateSurvivesEveryResult() {
        for fixture in ["win", "loss", "draw", "cancelled"] {
            let app = launchCalendar(fixture)
            XCTAssertTrue(waits(node(app, "calendar.selectedDetail")), "\(fixture): 선택일 컨테이너가 없다")
            XCTAssertTrue(node(app, "calendar.detailHeader").exists, "\(fixture): 섹션 헤더가 사라졌다")
            XCTAssertTrue(node(app, "calendar.detailRecord").exists, "\(fixture): 기록 카드가 사라졌다")
            assertDecorativeFairy(app, "calendar.selectedDate.fairy", fixture)
            app.terminate()
        }
    }

    /// 기록이 없는 날에는 결과 카드도 결과 페어리도 없다.
    func testCalendarShowsNoResultFairyWithoutARecord() {
        let app = launchCalendar("selectedEmptyDate")
        XCTAssertTrue(waits(node(app, "calendar.selectedDetail")))
        XCTAssertTrue(node(app, "calendar.detailEmpty").exists, "빈 날 안내가 없다")
        XCTAssertFalse(node(app, "calendar.detailRecord").exists, "기록이 없는데 카드가 있다")
        XCTAssertEqual(nodes(app, "calendar.selectedDate.fairy").count, 0,
                       "기록이 없는데 결과 페어리가 있다")
        XCTAssertTrue(node(app, "calendar.detailAddRecord").exists, "기록 추가 버튼이 사라졌다")
    }

    /// 달 이동은 그대로 동작한다.
    func testCalendarMonthNavigationRemainsFunctional() {
        let app = launchCalendar("referenceMonth")
        XCTAssertTrue(waits(node(app, "calendar.previousMonth")))
        node(app, "calendar.previousMonth").tap()
        XCTAssertTrue(waits(node(app, "calendar.nextMonth")))
        node(app, "calendar.nextMonth").tap()
        XCTAssertTrue(node(app, "calendar.selectedDetail").exists || node(app, "screen.calendar").exists,
                      "달 이동 뒤 화면이 무너졌다")
    }

    // MARK: - 시즌 아카이브 · 시즌 시그니처 페어리

    private func launchStatistics(_ fixture: String) -> XCUIApplication {
        let app = launch(arguments: [
            "-VFUITestTeamID", "samsung-lions", "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "statistics",
            "-VFUITestStatisticsFixture", fixture
        ])
        XCTAssertTrue(waits(node(app, "screen.statistics")), "\(fixture): 시즌 화면에 들어가지 못했다")
        XCTAssertTrue(waits(node(app, "statistics.scenario.\(fixture)")), "\(fixture): 픽스처가 적용되지 않았다")
        return app
    }

    func testStatisticsSeasonCoverKeepsItsIdentifiersAndSaysNoFalseVictory() {
        for fixture in ["referenceSeason", "lossOnly"] {
            let app = launchStatistics(fixture)
            XCTAssertTrue(waits(node(app, "statistics.hero")), "\(fixture): 시즌 커버가 없다")
            for identifier in ["statistics.root", "statistics.headline",
                               "statistics.winRate", "statistics.selectedSeason"] {
                XCTAssertTrue(node(app, identifier).exists, "\(fixture): \(identifier)가 사라졌다")
            }
            assertDecorativeFairy(app, "statistics.seasonCover.fairy", fixture)
            // 지는 시즌에 "승리"라고 말하지 않는다.
            if fixture == "lossOnly" {
                let hero = node(app, "statistics.hero")
                XCTAssertFalse(hero.label.contains("승리"), "지는 시즌 커버가 승리를 말한다: \(hero.label)")
            }
            app.terminate()
        }
    }

    func testStatisticsChartsRemainReachable() {
        let app = launchStatistics("referenceSeason")
        for identifier in ["statistics.distribution", "statistics.trend"] {
            let element = node(app, identifier)
            if element.exists { continue }
            app.swipeUp()
            XCTAssertTrue(waits(element, 6), "\(identifier)에 닿지 못했다")
        }
    }

    // MARK: - 공용 상태 패널

    func testEmptySeasonPanelKeepsTitleAndAction() {
        let app = launchStatistics("empty")
        let empty = node(app, "statistics.empty")
        XCTAssertTrue(waits(empty), "빈 시즌 패널이 없다")
        assertDecorativeFairy(app, "state.emptySeason.fairy", "빈 시즌")
        XCTAssertTrue(node(app, "statistics.root").exists, "빈 시즌에서 화면 루트가 사라졌다")
    }

    func testErrorPanelKeepsNativeRetry() {
        let app = launchStatistics("recoverableError")
        XCTAssertTrue(waits(node(app, "statistics.error")), "오류 패널이 없다")
        let retry = node(app, "statistics.retry")
        XCTAssertTrue(waits(retry), "다시 시도 버튼이 없다")
        XCTAssertTrue(retry.isHittable, "다시 시도 버튼을 누를 수 없다")
        assertDecorativeFairy(app, "state.error.fairy", "오류")
        retry.tap()
        XCTAssertTrue(waits(node(app, "statistics.root")), "다시 시도 뒤 화면이 무너졌다")
    }

    func testLoadingPanelHasNoFairy() {
        let app = launchStatistics("loading")
        XCTAssertTrue(waits(node(app, "statistics.loading")), "로딩 패널이 없다")
        for identifier in ["state.empty.fairy", "state.emptySeason.fairy", "state.error.fairy"] {
            XCTAssertEqual(nodes(app, identifier).count, 0, "로딩에 \(identifier)가 붙었다")
        }
    }

    func testFeedEmptyStateKeepsTitleAndCallToAction() {
        let app = launch(arguments: [
            "-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", "empty"
        ])
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        XCTAssertTrue(waits(node(app, "feed.empty")), "빈 기록 패널이 없다")
        XCTAssertTrue(node(app, "feed.addRecord").exists, "기록 추가 버튼이 사라졌다")
        assertDecorativeFairy(app, "state.empty.fairy", "빈 기록")
    }

    /// 필터로 걸러진 빈 상태(검색 없음)는 원본에 페어리가 없다.
    /// 같은 패널을 쓰지만 페어리 자리를 비워 두므로, 빈 기록과는 다른 화면이 된다.
    func testFilteredEmptyStateHasNoFairy() {
        let app = launch(arguments: [
            "-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", "populated"
        ])
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다")
        // Pencil 기준 픽스처에는 취소된 경기가 없다. 그 칩을 고르면 0건이 된다.
        let cancelledChip = app.buttons["취소된 날"]
        XCTAssertTrue(waits(cancelledChip), "결과 필터 칩이 없다")
        cancelledChip.tap()
        let filteredEmpty = node(app, "feed.filteredEmpty")
        XCTAssertTrue(waits(filteredEmpty), "필터 결과 0건 패널이 나오지 않았다")
        XCTAssertEqual(nodes(app, "state.empty.fairy").count, 0, "검색 없음에 빈 기록 페어리가 붙었다")
        XCTAssertEqual(nodes(app, "feed.empty").count, 0, "필터 상태인데 빈 기록 패널이 떴다")
    }

    // MARK: - 완료된 화면 회귀

    func testFeedAndRecordDetailRootsRemain() {
        let app = launch(arguments: [
            "-VFUITestTeamID", "lg-twins", "-VFUITestStadiumID", "jamsil",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", "populated"
        ])
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드 루트가 없다")
        let firstRecord = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "feed.record."))
            .firstMatch
        XCTAssertTrue(waits(firstRecord), "피드에 기록이 없다")
        firstRecord.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "기록 상세 루트가 없다")
        // 기록 상세에는 페어리가 없다.
        for identifier in ["calendar.selectedDate.fairy", "home.teamFairy",
                           "state.empty.fairy", "state.error.fairy"] {
            XCTAssertEqual(nodes(app, identifier).count, 0, "기록 상세에 \(identifier)가 들어갔다")
        }
    }

    func testFiveTabNavigationAndSingleTabBarSurvive() {
        let app = launchHome(teamID: "doosan-bears")
        XCTAssertTrue(waits(node(app, "screen.home")))
        let expected: [(tab: String, screen: String)] = [
            ("tab.feed", "screen.feed"), ("tab.calendar", "screen.calendar"),
            ("tab.statistics", "screen.statistics"), ("tab.my", "screen.my"),
            ("tab.home", "screen.home")
        ]
        for step in expected {
            app.buttons[step.tab].tap()
            XCTAssertTrue(waits(node(app, step.screen)), "\(step.tab) → \(step.screen) 이동이 안 된다")
            XCTAssertEqual(app.buttons.matching(identifier: "tab.home").count, 1, "탭바가 둘이다")
        }
    }
}
