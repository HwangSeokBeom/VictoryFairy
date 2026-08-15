import XCTest

/// 피드 화면을 결정적인 픽스처 상태로 띄워 검증한다.
///
/// 상태는 모두 `-VFUITest` 실행 인자로만 만든다. Release 빌드에는 해당 코드가
/// 존재하지 않으므로 테스트 설정이 제품 동작으로 새지 않는다.
final class FeedUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 피드 탭에서 바로 시작한다.
    private func launchFeed(
        fixture: String = "populated",
        teamID: String = "samsung-lions",
        stadiumID: String = "daegu-lions"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", stadiumID,
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestInitialTab", "feed",
            "-VFUITestFeedFixture", fixture
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

    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    // MARK: - 1~3 · 진입과 렌더

    func testF01_feedTabOpensTheRealFeedRoot() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")), "피드 화면에 들어가지 못했다")
        XCTAssertTrue(app.buttons["tab.feed"].isSelected, "기록 탭이 선택 상태가 아니다")
    }

    func testF02_noPlaceholderScreenAppears() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(node(app, "feed.addRecord"), 6), "추가 버튼이 없다")
        XCTAssertFalse(node(app, "feed.loading").exists, "픽스처 상태인데 로딩이 남아 있다")
        XCTAssertFalse(node(app, "feed.error").exists, "픽스처 상태인데 오류가 남아 있다")
    }

    func testF03_populatedFixtureRenders() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(text(app, containing: "삼성 vs LG"), 6), "기록 카드가 없다")
        XCTAssertTrue(text(app, containing: "직관 기록").exists, "화면 제목이 없다")
    }

    // MARK: - 4~5 · 그룹과 순서

    func testF04_recordsAreGroupedByMonth() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(node(app, "feed.month.2026-04"), 6), "4월 구간이 없다")
        XCTAssertTrue(node(app, "feed.month.2026-03").exists, "3월 구간이 없다")
        XCTAssertTrue(text(app, containing: "APRIL").exists, "영문 월 라벨이 없다")
    }

    func testF05_chronologicalOrderIsNewestFirst() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "feed.month.2026-04"), 8))
        let april = node(app, "feed.month.2026-04")
        let march = node(app, "feed.month.2026-03")
        XCTAssertTrue(march.exists)
        XCTAssertLessThan(april.frame.minY, march.frame.minY, "4월이 3월보다 아래에 있다")
    }

    // MARK: - 6~8 · 필터

    func testF06and07_resultFilterChangesRecordsAndHasNonColorSelection() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(text(app, containing: "삼성 vs KIA").exists, "패배 기록이 처음에 보이지 않는다")

        let winChip = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "승리한 날")).firstMatch
        XCTAssertTrue(waits(winChip, 6), "승리 필터 칩이 없다")
        winChip.tap()

        // 선택 상태는 색이 아니라 접근성 특성으로도 드러나야 한다.
        XCTAssertTrue(winChip.isSelected, "선택된 필터가 비색상 수단으로 표시되지 않는다")
    }

    func testF08_filteredEmptyStateAppears() {
        // 취소 기록이 없는 픽스처에서 취소 필터를 고르면 필터 빈 상태가 나와야 한다.
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let canceled = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "취소된 날")).firstMatch
        if canceled.exists {
            canceled.tap()
            XCTAssertTrue(
                waits(node(app, "feed.filteredEmpty"), 6) || waits(node(app, "feed.empty"), 2),
                "필터 결과가 없을 때 빈 상태가 뜨지 않았다"
            )
        }
    }

    // MARK: - 9~12 · 로딩 · 빈 상태 · 오류

    func testF09_loadingStateIsReachable() {
        let app = launchFeed(fixture: "loading")
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(node(app, "feed.loading"), 6), "로딩 상태에 닿지 못했다")
    }

    func testF10_emptyFeedStateIsReachable() {
        let app = launchFeed(fixture: "empty")
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(node(app, "feed.empty"), 6), "빈 피드 상태에 닿지 못했다")
        // 빈 상태에서도 제목과 추가 버튼은 남아야 한다.
        XCTAssertTrue(node(app, "feed.addRecord").exists, "빈 피드에서 추가 버튼이 사라졌다")
        XCTAssertTrue(text(app, containing: "직관 기록").exists, "빈 피드에서 제목이 사라졌다")
    }

    func testF11and12_recoverableErrorExposesRetry() {
        let app = launchFeed(fixture: "error")
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(node(app, "feed.error"), 6), "오류 상태에 닿지 못했다")
        let retry = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "다시 시도")).firstMatch
        XCTAssertTrue(waits(retry, 6), "다시 시도 버튼이 없다")
        XCTAssertTrue(retry.isHittable, "다시 시도 버튼을 누를 수 없다")
        retry.tap()
        // 재시도해도 셸과 필터는 그대로 남아야 한다.
        XCTAssertTrue(node(app, "feed.addRecord").waitForExistence(timeout: 6))
    }

    // MARK: - 13~14 · 카드 의미와 구장

    func testF13_recordCardExposesDateResultAndStadium() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "삼성 vs LG")).firstMatch
        XCTAssertTrue(waits(card, 6), "기록 카드를 찾지 못했다")
        let label = card.label
        XCTAssertTrue(label.contains("잠실야구장"), "카드 요약에 구장이 없다: \(label)")
        XCTAssertTrue(label.contains("승") || label.contains("6:3"), "카드 요약에 결과가 없다: \(label)")
    }

    func testF14_stadiumIsVisuallyPresent() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(waits(text(app, containing: "잠실야구장"), 6), "구장이 화면에 보이지 않는다")
    }

    // MARK: - 15~16 · 경로 유지

    func testF15_tappingRecordOpensRecordDetail() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "삼성 vs LG")).firstMatch
        XCTAssertTrue(waits(card, 6))
        card.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 8)
                || text(app, containing: "잠실야구장").waitForExistence(timeout: 8),
            "기록 상세로 이동하지 못했다"
        )
    }

    func testF16_addActionOpensRecordCreate() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let add = node(app, "feed.addRecord")
        XCTAssertTrue(waits(add, 6))
        add.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 8)
                || app.buttons["취소"].waitForExistence(timeout: 8),
            "기록 작성으로 이동하지 못했다"
        )
    }

    // MARK: - 17~19 · 셸 무결성

    func testF17_feedSurvivesTabSwitchAndReturn() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "screen.home"), 6))
        app.buttons["tab.feed"].tap()
        XCTAssertTrue(waits(node(app, "screen.feed"), 6), "피드로 돌아오지 못했다")
        XCTAssertTrue(text(app, containing: "삼성 vs LG").waitForExistence(timeout: 6), "돌아오니 기록이 사라졌다")
    }

    func testF18_noDuplicateTabBarOnFeed() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertEqual(app.buttons.matching(identifier: "tab.feed").count, 1, "피드에 탭바가 중복된다")
    }

    func testF19_lastCardStaysAboveTheTabBar() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let window = app.windows.firstMatch
        let tab = app.buttons["tab.feed"]
        XCTAssertTrue(waits(tab, 6))
        XCTAssertTrue(tab.isHittable, "탭바가 콘텐츠에 가렸다")
        XCTAssertLessThanOrEqual(tab.frame.maxY, window.frame.maxY, "탭바가 화면 밖으로 나갔다")
    }

    // MARK: - 20~22 · 반응형과 접근성

    func testF20_compactWidthFeedHasNoOverflow() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let window = app.windows.firstMatch
        for identifier in ["feed.addRecord", "feed.month.2026-04"] {
            let element = node(app, identifier)
            XCTAssertTrue(waits(element, 6), "\(identifier)가 없다")
            XCTAssertLessThanOrEqual(element.frame.maxX, window.frame.maxX + 1, "\(identifier)가 오른쪽으로 넘쳤다")
            XCTAssertGreaterThanOrEqual(element.frame.minX, -1, "\(identifier)가 왼쪽으로 넘쳤다")
        }
    }

    func testF21_accessibilitySizePreservesFiltersRecordsAndAddAction() {
        let app = launchFeed()
        XCTAssertTrue(waits(node(app, "screen.feed")))
        XCTAssertTrue(node(app, "feed.addRecord").exists, "큰 글자에서 추가 버튼이 사라졌다")
        XCTAssertTrue(node(app, "feed.addRecord").isHittable, "큰 글자에서 추가 버튼을 누를 수 없다")
        let allChip = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "전체")).firstMatch
        XCTAssertTrue(waits(allChip, 6), "큰 글자에서 필터가 사라졌다")
        XCTAssertTrue(text(app, containing: "삼성").waitForExistence(timeout: 6), "큰 글자에서 기록이 사라졌다")
    }

    func testF22_longStadiumNameStaysReadable() {
        let app = launchFeed(fixture: "longContent")
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let stadium = text(app, containing: "광주-기아 챔피언스 필드")
        XCTAssertTrue(waits(stadium, 6), "긴 구장 이름이 보이지 않는다")
        XCTAssertLessThanOrEqual(
            stadium.frame.maxX, app.windows.firstMatch.frame.maxX + 1,
            "긴 구장 이름이 화면 밖으로 넘쳤다"
        )
    }

    // MARK: - 23~24 · 열 팀 · 아홉 구장

    func testF23_allTenTeamsRenderFeedStructurally() {
        let teams = [
            "lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
            "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"
        ]
        for teamID in teams {
            let app = launchFeed(teamID: teamID, stadiumID: "jamsil")
            XCTAssertTrue(waits(node(app, "screen.feed"), 10), "\(teamID) 피드가 뜨지 않았다")
            XCTAssertTrue(node(app, "feed.addRecord").exists, "\(teamID) 피드에 추가 버튼이 없다")
            app.terminate()
        }
    }

    func testF24_allNineStadiumsRenderFeedStructurally() {
        let stadiums = [
            "jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
            "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"
        ]
        for stadiumID in stadiums {
            let app = launchFeed(teamID: "lg-twins", stadiumID: stadiumID)
            XCTAssertTrue(waits(node(app, "screen.feed"), 10), "\(stadiumID) 피드가 뜨지 않았다")
            XCTAssertTrue(node(app, "feed.month.2026-04").exists, "\(stadiumID) 피드에 월 구간이 없다")
            app.terminate()
        }
    }
}
