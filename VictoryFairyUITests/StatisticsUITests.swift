import XCTest

/// 시즌 아카이브를 결정적인 픽스처 상태로 띄워 검증한다.
///
/// 실행 인자를 넣었다는 사실만으로 상태가 적용됐다고 믿지 않는다. 캘린더에서 표식 없이
/// 검증했다가 조용히 제품 상태로 돌아간 적이 있어, 모든 실행이 화면에서 시나리오 표식을
/// 먼저 확인한다.
final class StatisticsUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 실행과 조회 도구

    private func launch(
        _ fixture: String,
        teamID: String = "samsung-lions",
        stadiumID: String = "daegu-lions",
        extra: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", stadiumID,
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "statistics",
            "-VFUITestStatisticsFixture", fixture
        ] + extra
        app.launch()
        return app
    }

    /// 시나리오가 실제로 적용됐는지 화면에서 확인한 뒤에만 다음 단언으로 넘어간다.
    @discardableResult
    private func launchVerified(
        _ fixture: String,
        teamID: String = "samsung-lions",
        extra: [String] = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = launch(fixture, teamID: teamID, extra: extra)
        XCTAssertTrue(waits(node(app, "screen.statistics")), "시즌 화면에 들어가지 못했다", file: file, line: line)
        XCTAssertTrue(
            waits(node(app, "statistics.scenario.\(fixture)")),
            "픽스처 \(fixture)가 적용되지 않고 제품 상태로 돌아갔다",
            file: file, line: line
        )
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 화면이 자리를 잡은 뒤에 좌표를 읽는다. 애니메이션 중의 값을 재면 결과가 흔들린다.
    private func settled(_ element: XCUIElement) -> CGRect {
        XCTAssertTrue(waits(element), "요소가 나타나지 않아 좌표를 잴 수 없다")
        var previous = element.frame
        for _ in 0..<20 {
            usleep(120_000)
            let current = element.frame
            if current == previous { return current }
            previous = current
        }
        return previous
    }

    /// 아래쪽 섹션은 스크롤해야 닿는다. "볼 수 있다"는 요구는 스크롤을 포함한다.
    @discardableResult
    private func scrollTo(
        _ app: XCUIApplication, _ identifier: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let element = node(app, identifier)
        if element.waitForExistence(timeout: 3), element.isHittable { return element }
        for _ in 0..<10 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(element.exists, "\(identifier)에 스크롤해도 닿을 수 없다", file: file, line: line)
        return element
    }

    private func label(_ app: XCUIApplication, _ identifier: String) -> String {
        let element = node(app, identifier)
        XCTAssertTrue(waits(element), "\(identifier)가 없다")
        return element.label
    }

    // MARK: - A · 픽스처 활성화와 화면 구조

    func testS01_referenceSeasonFixtureActivates() {
        let app = launchVerified("referenceSeason")
        XCTAssertTrue(label(app, "statistics.title").hasPrefix("2026 시즌"))
        XCTAssertEqual(label(app, "statistics.subtitle"), "8번의 직관, 3개의 구장")
    }

    /// 자리만 잡아 둔 표시가 남아 있지 않다.
    func testS02_noPlaceholderCopyRemains() {
        let app = launchVerified("referenceSeason")
        for placeholder in ["준비 중", "Coming soon", "TODO", "Lorem", "표본 수집 중"] {
            XCTAssertFalse(text(app, containing: placeholder).exists, "자리표시 문구가 남아 있다: \(placeholder)")
        }
    }

    func testS03_onlyOneTabBarExists() {
        let app = launchVerified("referenceSeason")
        XCTAssertTrue(app.buttons["tab.statistics"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "tab.statistics").count, 1, "탭바가 두 개다")
        XCTAssertEqual(app.buttons.matching(identifier: "tab.home").count, 1)
    }

    /// 탭 안의 화면은 자기 내비게이션 스택을 다시 만들지 않는다.
    func testS04_noNestedNavigationStack() {
        let app = launchVerified("referenceSeason")
        XCTAssertLessThanOrEqual(app.navigationBars.count, 1, "내비게이션 바가 겹쳐 있다")
    }

    /// 마지막 콘텐츠까지 스크롤해서 실제로 누를 수 있어야 한다.
    /// 탭바가 화면 위에 떠 있으므로, 가려진 채로 끝나면 그 버튼은 존재만 하고 쓸 수 없다.
    func testS05_lastContentStaysReachableAboveTheTabBar() {
        let app = launchVerified("referenceSeason")
        let report = scrollTo(app, "statistics.seasonReport")
        let reportFrame = settled(report)
        let tabBar = settled(app.buttons["tab.statistics"])
        XCTAssertTrue(report.isHittable, "마지막 버튼이 탭바에 가려 닿을 수 없다")
        XCTAssertLessThanOrEqual(reportFrame.midY, tabBar.minY, "마지막 버튼의 중심이 탭바 아래에 있다")
    }

    // MARK: - B · 시즌 선택

    func testS06_selectedSeasonIsShown() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.selectedSeason"), "시즌 선택, 2026 시즌")
    }

    func testS07_seasonOptionsAreListedNewestFirst() {
        let app = launchVerified("multipleSeasons")
        node(app, "statistics.selectedSeason").tap()
        XCTAssertTrue(waits(node(app, "statistics.seasonPicker")), "시즌 목록이 열리지 않았다")
        let years = [2026, 2025, 2024]
        for year in years {
            XCTAssertTrue(waits(node(app, "statistics.season.\(year)")), "\(year) 시즌을 고를 수 없다")
        }
        let positions = years.map { settled(node(app, "statistics.season.\($0)")).minY }
        XCTAssertEqual(positions, positions.sorted(), "시즌이 최신순으로 정렬되지 않았다")
    }

    func testS08_previousSeasonFixtureStartsOnThatSeason() {
        let app = launchVerified("previousSeason")
        XCTAssertTrue(label(app, "statistics.title").hasPrefix("2025 시즌"))
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 2경기")
    }

    /// 시즌을 바꾸면 화면의 값이 실제로 달라진다.
    func testS09_selectingAPreviousSeasonUpdatesTheMetrics() {
        let app = launchVerified("multipleSeasons")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 8경기")

        node(app, "statistics.selectedSeason").tap()
        XCTAssertTrue(waits(node(app, "statistics.season.2025")))
        node(app, "statistics.season.2025").tap()

        let title = node(app, "statistics.title")
        XCTAssertTrue(waits(title))
        var updated = false
        for _ in 0..<25 where !updated {
            updated = title.label.hasPrefix("2025 시즌")
            if !updated { usleep(300_000) }
        }
        XCTAssertTrue(updated, "시즌을 바꿨는데 제목이 그대로다: \(title.label)")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 2경기", "시즌을 바꿨는데 값이 그대로다")
        XCTAssertEqual(label(app, "statistics.selectedSeason"), "시즌 선택, 2025 시즌")
    }

    // MARK: - C · 핵심 수치

    func testS10_attendanceTotalAndRecordAreCorrect() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 8경기")
        XCTAssertTrue(text(app, containing: "8경기 · 5승 2패 1무").exists, "전적 한 줄이 없다")
    }

    func testS11_winLossDrawAndCancelledAreEachVisible() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.wins"), "승 5경기")
        XCTAssertEqual(label(app, "statistics.losses"), "패 2경기")
        XCTAssertEqual(label(app, "statistics.draws"), "무 1경기")
        XCTAssertEqual(label(app, "statistics.canceled"), "취소 0경기")
    }

    /// 화면에 찍힌 값은 `.714`이고, 읽어 주는 문장은 퍼센트로 풀어 준다.
    func testS12_winRateIsMathematicallyCorrect() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.winRate"), "승률 71.4퍼센트, 5승 2패 기준")
        XCTAssertEqual(node(app, "statistics.winRate").value as? String, ".714",
                       "화면에 찍힌 승률이 규칙대로 계산되지 않았다")
        XCTAssertNotEqual(node(app, "statistics.winRate").value as? String, ".625",
                          "Pencil 표본 승률이 화면에 나왔다")
    }

    func testS13_headlineComesFromTheRecords() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.headline"), "7번 중 5번을 이긴 시즌")
    }

    // MARK: - D · 상태

    func testS14_loadingFixtureShowsALoadingState() {
        let app = launchVerified("loading")
        XCTAssertTrue(waits(node(app, "statistics.loading")), "불러오는 중 표시가 없다")
        XCTAssertFalse(node(app, "statistics.empty").exists, "불러오는 중인데 빈 상태가 떴다")
    }

    func testS15_emptySeasonShowsAnHonestEmptyState() {
        let app = launchVerified("empty")
        XCTAssertTrue(waits(node(app, "statistics.empty")), "빈 시즌 안내가 없다")
        XCTAssertTrue(text(app, containing: "2026 시즌 기록이 아직 없어요").exists)
        XCTAssertFalse(node(app, "statistics.hero").exists, "기록이 없는데 시즌 커버가 떴다")
        XCTAssertEqual(label(app, "statistics.subtitle"), "아직 이 시즌의 기록이 없어요")
    }

    func testS16_oneRecordSeasonStaysUsable() {
        let app = launchVerified("oneRecord")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 1경기")
        XCTAssertEqual(label(app, "statistics.headline"), "잠실야구장에서 시작한 시즌")
        XCTAssertTrue(waits(node(app, "statistics.trend.month.4")), "한 건일 때 월별 흐름이 사라졌다")
    }

    func testS17_insufficientDataIsFlaggedWithoutHidingTheNumber() {
        let app = launchVerified("insufficientData")
        XCTAssertTrue(waits(node(app, "statistics.insufficientData")), "표본 경고가 없다")
        XCTAssertTrue(label(app, "statistics.insufficientData").contains("승패 2경기 기준"))
        XCTAssertEqual(label(app, "statistics.winRate"), "승률 50.0퍼센트, 1승 1패 기준")
    }

    func testS18_cancelledOnlySeasonReportsNoWinRate() {
        let app = launchVerified("cancelledOnly")
        XCTAssertEqual(label(app, "statistics.winRate"), "승률 없음, 승패가 갈린 경기가 아직 없어요")
        XCTAssertEqual(label(app, "statistics.canceled"), "취소 3경기")
        XCTAssertTrue(label(app, "statistics.insufficientData").contains("경기가 열리지 않아"))
        XCTAssertTrue(text(app, containing: "발걸음했지만").exists, "취소만 있는 시즌 문장이 없다")
    }

    func testS19_drawOnlySeasonReportsNoWinRate() {
        let app = launchVerified("drawOnly")
        XCTAssertEqual(label(app, "statistics.draws"), "무 3경기")
        XCTAssertEqual(label(app, "statistics.winRate"), "승률 없음, 승패가 갈린 경기가 아직 없어요")
    }

    func testS20_winOnlyAndLossOnlySeasonsAreCorrect() {
        let winApp = launchVerified("winOnly")
        XCTAssertEqual(label(winApp, "statistics.winRate"), "승률 100.0퍼센트, 3승 0패 기준")
        XCTAssertEqual(label(winApp, "statistics.losses"), "패 0경기")

        let lossApp = launchVerified("lossOnly")
        XCTAssertEqual(label(lossApp, "statistics.winRate"), "승률 0.0퍼센트, 0승 3패 기준")
        XCTAssertEqual(label(lossApp, "statistics.wins"), "승 0경기")
    }

    func testS21_mixedResultsShowEveryCategory() {
        let app = launchVerified("mixedResults")
        XCTAssertEqual(label(app, "statistics.wins"), "승 1경기")
        XCTAssertEqual(label(app, "statistics.losses"), "패 1경기")
        XCTAssertEqual(label(app, "statistics.draws"), "무 1경기")
        XCTAssertEqual(label(app, "statistics.canceled"), "취소 1경기")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 4경기")
    }

    func testS22_recoverableErrorExposesRetry() {
        let app = launchVerified("recoverableError")
        XCTAssertTrue(waits(node(app, "statistics.error")), "복구 안내가 없다")
        XCTAssertTrue(waits(node(app, "statistics.retry")), "다시 시도 버튼이 없다")
        XCTAssertTrue(node(app, "statistics.retry").isHittable)
        XCTAssertTrue(text(app, containing: "연결이 원활하지 않아요").exists, "오류 문구가 없다")
    }

    /// 다시 시도를 눌러도 보고 있던 시즌은 그대로 남는다.
    func testS23_retryKeepsTheSelectedSeason() {
        let app = launchVerified("recoverableError")
        XCTAssertTrue(label(app, "statistics.title").hasPrefix("2026 시즌"))
        node(app, "statistics.retry").tap()
        usleep(900_000)
        XCTAssertTrue(label(app, "statistics.title").hasPrefix("2026 시즌"), "다시 시도 후 시즌이 바뀌었다")
        XCTAssertTrue(node(app, "statistics.scenario.recoverableError").exists, "다시 시도 후 상태가 사라졌다")
    }

    func testS24_retrySuccessShowsThePopulatedArchive() {
        let app = launchVerified("retrySuccess")
        XCTAssertFalse(node(app, "statistics.error").exists, "성공 후에도 오류가 남아 있다")
        XCTAssertTrue(waits(node(app, "statistics.hero")))
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 8경기")
    }

    // MARK: - E · 차트

    func testS25_resultDistributionIsPresentWithASemanticSummary() {
        let app = launchVerified("referenceSeason")
        XCTAssertTrue(waits(node(app, "statistics.distribution")))
        XCTAssertEqual(
            label(app, "statistics.distribution.summary"),
            "전체 8경기 중 승 5경기, 패 2경기, 무 1경기"
        )
    }

    func testS26_attendanceTrendShowsEveryRecordedMonth() {
        let app = launchVerified("referenceSeason")
        scrollTo(app, "statistics.trend.month.3")
        XCTAssertEqual(label(app, "statistics.trend.month.3"), "3월, 3번 직관")
        XCTAssertEqual(label(app, "statistics.trend.month.4"), "4월, 5번 직관")
        XCTAssertFalse(node(app, "statistics.trend.month.5").exists, "기록이 없는 달을 만들어 냈다")
    }

    func testS27_trendExposesAReadableSummary() {
        let app = launchVerified("referenceSeason")
        let summary = scrollTo(app, "statistics.trend.summary")
        XCTAssertTrue(summary.label.contains("3월부터 4월까지"), "흐름 요약이 없다: \(summary.label)")
        XCTAssertTrue(summary.label.contains("가장 많았던 달은 4월"))
    }

    func testS28_emptyTrendIsHonestRatherThanFabricated() {
        let app = launchVerified("empty")
        XCTAssertFalse(node(app, "statistics.trend.month.4").exists, "빈 시즌에 월 칸이 그려졌다")
    }

    // MARK: - F · 팀 아이덴티티

    func testS29_selectedTeamAppearsInTheSeasonCover() {
        let app = launchVerified("referenceSeason")
        XCTAssertTrue(waits(node(app, "statistics.team.samsung-lions")), "응원 팀이 커버에 없다")
        XCTAssertEqual(label(app, "statistics.team.samsung-lions"), "응원 팀 삼성 라이온즈")
    }

    /// 밝은 강조색과 어두운 강조색 모두에서 팀 표시가 남는다.
    func testS30_lightAndDarkTeamAccentsBothRender() {
        let light = launchVerified("lightTeamAccent", teamID: "hanwha-eagles")
        XCTAssertTrue(waits(node(light, "statistics.team.hanwha-eagles")), "밝은 강조색 팀이 없다")

        let dark = launchVerified("darkTeamAccent", teamID: "kt-wiz")
        XCTAssertTrue(waits(node(dark, "statistics.team.kt-wiz")), "어두운 강조색 팀이 없다")
    }

    /// 열 개 구단 전부가 시즌 커버에 표시된다.
    func testS31_everyTeamRendersItsIdentity() {
        let teams = [
            "lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
            "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"
        ]
        for teamID in teams {
            let app = launchVerified("referenceSeason", teamID: teamID)
            XCTAssertTrue(
                waits(node(app, "statistics.team.\(teamID)"), 15),
                "\(teamID) 아이덴티티가 커버에 나오지 않았다"
            )
            app.terminate()
        }
    }

    func testS32_longTeamNameStaysReadable() {
        let app = launchVerified("longTeamName", teamID: "hanwha-eagles")
        XCTAssertTrue(waits(node(app, "statistics.team.hanwha-eagles")))
        let opponent = node(app, "statistics.highlight.mostFacedOpponent")
        XCTAssertTrue(waits(opponent))
        XCTAssertTrue(opponent.label.contains("키움 히어로즈"), "긴 상대 팀 이름이 잘렸다: \(opponent.label)")
    }

    // MARK: - G · 구장 아이덴티티

    func testS33_stadiumAnalysisUsesTheActualRecordVenues() {
        let app = launchVerified("referenceSeason")
        scrollTo(app, "statistics.stadiumAnalysis")
        XCTAssertTrue(waits(node(app, "statistics.stadium.daegu-lions")), "기록 구장이 없다")
        XCTAssertTrue(node(app, "statistics.stadium.jamsil").exists)
        XCTAssertTrue(node(app, "statistics.stadium.gwangju-kia").exists)
        XCTAssertTrue(
            label(app, "statistics.stadium.daegu-lions").contains("5번 방문"),
            "구장 방문 횟수가 틀렸다: \(label(app, "statistics.stadium.daegu-lions"))"
        )
    }

    /// 기록에 없는 구장(주 관람 구장)이 대신 나오지 않는다.
    func testS34_primaryStadiumNeverReplacesARecordVenue() {
        // 주 관람 구장은 잠실로 두지만, 기록은 대전에만 남아 있다.
        let app = launch("longTeamName", teamID: "hanwha-eagles", stadiumID: "jamsil")
        XCTAssertTrue(waits(node(app, "statistics.scenario.longTeamName")), "픽스처가 적용되지 않았다")
        scrollTo(app, "statistics.stadiumAnalysis")
        XCTAssertTrue(node(app, "statistics.stadium.daejeon-hanwha").exists, "기록 구장이 사라졌다")
        XCTAssertFalse(node(app, "statistics.stadium.jamsil").exists, "기록에 없는 구장이 나왔다")
    }

    func testS35_missingStadiumStateIsHonest() {
        let app = launchVerified("noStadium")
        scrollTo(app, "statistics.stadiumAnalysis")
        XCTAssertTrue(waits(node(app, "statistics.stadiumAnalysis.empty")), "구장 없음 안내가 없다")
        XCTAssertEqual(label(app, "statistics.subtitle"), "3번의 직관")
        let highlight = node(app, "statistics.highlight.mostVisitedStadium")
        XCTAssertTrue(highlight.label.contains("구장이 적힌 기록이 아직 없어요"))
    }

    func testS36_longStadiumNameWraps() {
        let app = launchVerified("longStadiumName")
        scrollTo(app, "statistics.stadium.gwangju-kia")
        let row = settled(node(app, "statistics.stadium.gwangju-kia"))
        XCTAssertGreaterThan(row.height, 40, "긴 구장 이름이 한 줄로 잘렸다")
        XCTAssertTrue(label(app, "statistics.stadium.gwangju-kia").contains("광주-기아 챔피언스 필드"))
    }

    /// 정식 구장 아홉 곳이 모두 그려진다.
    func testS37_everyCanonicalStadiumRenders() {
        let app = launchVerified("allStadiums")
        let ids = ["jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
                   "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"]
        scrollTo(app, "statistics.stadiumAnalysis")
        for id in ids {
            XCTAssertTrue(
                scrollTo(app, "statistics.stadium.\(id)").exists,
                "\(id) 구장이 화면에 없다"
            )
        }
    }

    // MARK: - H · 기록 하이라이트

    func testS38_highlightsShowRealValues() {
        let app = launchVerified("referenceSeason")
        XCTAssertTrue(label(app, "statistics.highlight.mostVisitedStadium").contains("대구 삼성 라이온즈 파크 · 5번"))
        XCTAssertTrue(label(app, "statistics.highlight.mostFacedOpponent").contains("KIA 타이거즈 · 3번"))
        XCTAssertTrue(label(app, "statistics.highlight.longestWinStreak").contains("4월 · 3연승"))
        XCTAssertTrue(label(app, "statistics.highlight.largestWinMargin").contains("4월 12일 · 9-1"))
    }

    func testS39_missingScoresLeaveTheMarginHighlightHonest() {
        let app = launchVerified("missingScore")
        XCTAssertTrue(
            label(app, "statistics.highlight.largestWinMargin").contains("점수가 적힌 승리가 아직 없어요"),
            "점수가 없는데 값을 지어냈다"
        )
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 3경기")
    }

    // MARK: - I · 탐색

    func testS40_tabSwitchingAndReturningKeepsTheArchive() {
        let app = launchVerified("referenceSeason")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 8경기")

        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "screen.home")), "홈으로 넘어가지 못했다")
        app.buttons["tab.statistics"].tap()

        XCTAssertTrue(waits(node(app, "screen.statistics")))
        XCTAssertTrue(waits(node(app, "statistics.scenario.referenceSeason")), "돌아왔더니 픽스처가 풀렸다")
        XCTAssertEqual(label(app, "statistics.totalAttendance"), "직관 8경기")
    }

    func testS41_stadiumHighlightOpensTheDetailedStadiumScreen() {
        let app = launchVerified("referenceSeason")
        node(app, "statistics.highlight.mostVisitedStadium").tap()
        XCTAssertTrue(text(app, containing: "구장별 통계").waitForExistence(timeout: 8), "구장 상세로 가지 못했다")
    }

    func testS42_leagueStandingsRemainReachable() {
        let app = launchVerified("referenceSeason")
        scrollTo(app, "statistics.leagueStandings").tap()
        XCTAssertTrue(text(app, containing: "KBO").waitForExistence(timeout: 8), "리그 순위표로 가지 못했다")
    }
}
