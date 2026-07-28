import XCTest

/// 캘린더를 결정적인 픽스처 상태로 띄워 검증한다.
///
/// 실행 인자를 넣었다는 사실만으로 상태가 적용됐다고 믿지 않는다. 온보딩 초기화에서
/// 인자는 전달됐지만 다른 층이 값을 되돌려 놓아 조용히 제품 상태로 돌아간 적이 있다.
/// 그래서 모든 실행이 화면에서 시나리오 표식을 먼저 확인한다.
final class CalendarUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 실행과 조회 도구

    @discardableResult
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
            "-VFUITestInitialTab", "calendar",
            "-VFUITestCalendarFixture", fixture
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
        XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더 화면에 들어가지 못했다", file: file, line: line)
        XCTAssertTrue(
            waits(node(app, "calendar.scenario.\(fixture)")),
            "픽스처 \(fixture)가 적용되지 않고 제품 상태로 돌아갔다",
            file: file, line: line
        )
        return app
    }

    private func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func day(_ app: XCUIApplication, _ iso: String) -> XCUIElement {
        node(app, "calendar.day.\(iso)")
    }

    private func waits(_ element: XCUIElement, _ timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    private func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 화면이 자리를 잡은 뒤에 좌표를 읽는다. 애니메이션 중의 값을 재면 결과가 흔들린다.
    private func settled(_ app: XCUIApplication, _ element: XCUIElement) -> CGRect {
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

    private var monthTitleLabel: String { "2026년 4월" }

    /// 월 제목을 확인한다. 접근성 이름에는 "월 선택" 안내가 함께 붙으므로 포함으로 본다.
    private func assertMonthTitle(
        _ app: XCUIApplication, _ expected: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let element = node(app, "calendar.monthTitle")
        XCTAssertTrue(waits(element), "월 제목이 없다", file: file, line: line)
        XCTAssertTrue(
            element.label.hasPrefix(expected),
            "월 제목이 \(expected)이 아니다: \(element.label)",
            file: file, line: line
        )
    }

    // MARK: - A · 픽스처 활성화

    func testC01_referenceMonthFixtureActivates() {
        let app = launchVerified("referenceMonth")
        assertMonthTitle(app, monthTitleLabel)
    }

    func testC02_selectedRecordFixtureActivatesWithItsDateAndRecord() {
        let app = launchVerified("selectedRecord")
        assertMonthTitle(app, monthTitleLabel)
        XCTAssertTrue(day(app, "2026-04-12").isSelected, "픽스처가 고른 날짜가 선택 상태가 아니다")
        XCTAssertTrue(waits(node(app, "calendar.detailRecord")), "선택일 기록 카드가 없다")
    }

    func testC03_selectedEmptyDateFixtureActivates() {
        let app = launchVerified("selectedEmptyDate")
        XCTAssertTrue(day(app, "2026-04-20").isSelected)
        XCTAssertTrue(waits(node(app, "calendar.detailEmpty")), "빈 날짜 안내가 없다")
        XCTAssertFalse(node(app, "calendar.detailRecord").exists, "기록이 없는데 카드가 떴다")
    }

    func testC04_loadingFixtureActivates() {
        let app = launchVerified("loading")
        XCTAssertTrue(waits(node(app, "calendar.grid")), "불러오는 중에도 격자는 남아야 한다")
        XCTAssertTrue(app.activityIndicators.firstMatch.exists
                      || text(app, containing: "불러오").exists,
                      "불러오는 중 표시가 없다")
    }

    func testC05_emptyMonthFixtureKeepsAUsableGrid() {
        let app = launchVerified("emptyMonth")
        XCTAssertTrue(waits(node(app, "calendar.grid")), "기록이 없다고 격자가 사라졌다")
        XCTAssertTrue(day(app, "2026-04-15").exists, "빈 달인데 날짜를 고를 수 없다")
        XCTAssertTrue(day(app, "2026-04-15").isHittable)
    }

    func testC06_recoverableErrorFixtureExposesRetry() {
        let app = launchVerified("recoverableError")
        XCTAssertTrue(waits(node(app, "calendar.errorRetry")), "복구 안내가 없다")
        XCTAssertTrue(text(app, containing: "연결이 원활하지 않아요").exists, "오류 문구가 없다")
        let retry = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "다시 시도")).firstMatch
        XCTAssertTrue(waits(retry), "다시 시도할 방법이 없다")
        XCTAssertTrue(retry.isHittable, "다시 시도 버튼을 누를 수 없다")
        XCTAssertTrue(node(app, "calendar.grid").exists, "오류라고 격자가 사라졌다")
    }

    /// 다시 시도해도 보고 있던 달과 고른 날짜, 보기 모드가 그대로여야 한다.
    func testC07_retryPreservesMonthSelectionAndViewMode() {
        let app = launchVerified("recoverableError")
        day(app, "2026-04-15").tap()
        XCTAssertTrue(day(app, "2026-04-15").isSelected)
        let before = node(app, "calendar.monthTitle").label

        let retry = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "다시 시도")).firstMatch
        XCTAssertTrue(waits(retry))
        retry.tap()

        XCTAssertTrue(waits(node(app, "calendar.grid")))
        XCTAssertEqual(node(app, "calendar.monthTitle").label, before, "재시도가 보고 있던 달을 잃었다")
        XCTAssertTrue(day(app, "2026-04-15").isSelected, "재시도가 고른 날짜를 잃었다")
        XCTAssertTrue(app.buttons["기본 보기, 선택됨"].exists
                      || app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "기본")).firstMatch.exists,
                      "재시도가 보기 모드를 잃었다")
    }

    /// 다시 불러오기에 성공한 뒤의 화면. 오류가 걷히고 기록이 보인다.
    func testC07b_retrySuccessShowsLoadedContentWithoutError() {
        let app = launchVerified("retrySuccess")
        XCTAssertTrue(waits(node(app, "calendar.grid")))
        XCTAssertFalse(node(app, "calendar.errorRetry").exists, "성공 상태인데 오류 패널이 남아 있다")
        XCTAssertFalse(text(app, containing: "연결이 원활하지 않아요").exists)
        XCTAssertTrue(day(app, "2026-04-12").exists)
    }

    func testC08_everyResultFixtureActivates() {
        for (fixture, iso) in [("win", "2026-04-12"), ("loss", "2026-04-05"),
                               ("draw", "2026-04-01"), ("cancelled", "2026-04-08")] {
            let app = launchVerified(fixture)
            XCTAssertTrue(day(app, iso).isSelected, "\(fixture)에서 \(iso)가 선택되지 않았다")
            app.terminate()
        }
    }

    func testC09_everyDesignOnlyFixtureActivates() {
        for (fixture, title) in [("scheduledDesignState", "경기 예정"),
                                 ("liveDesignState", "경기 중"),
                                 ("postponedDesignState", "우천 연기")] {
            let app = launchVerified(fixture)
            let status = fixture.replacingOccurrences(of: "DesignState", with: "")
            XCTAssertTrue(
                waits(node(app, "calendar.designStatus.\(status)")),
                "\(fixture) 상태 배지가 없다"
            )
            XCTAssertTrue(text(app, containing: title).exists, "\(title) 문구가 보이지 않는다")
            app.terminate()
        }
    }

    func testC10_longContentFixturesActivate() {
        for fixture in ["longTeamName", "longStadiumName"] {
            let app = launchVerified(fixture)
            XCTAssertTrue(waits(node(app, "calendar.detailRecord")), "\(fixture) 기록 카드가 없다")
            app.terminate()
        }
    }

    func testC11_compactAndAccessibilityFixturesActivate() {
        for fixture in ["compactReference", "accessibilityReference"] {
            let app = launchVerified(fixture)
            XCTAssertTrue(waits(node(app, "calendar.grid")))
            app.terminate()
        }
    }

    // MARK: - B · 루트와 쉘

    func testC12_calendarTabOpensTheRealRootWithNoPlaceholder() {
        let app = launchVerified("referenceMonth")
        XCTAssertTrue(app.buttons["tab.calendar"].isSelected, "캘린더 탭이 선택 상태가 아니다")
        XCTAssertTrue(waits(node(app, "calendar.root")))
        XCTAssertTrue(node(app, "calendar.grid").exists)
        XCTAssertTrue(node(app, "calendar.legend").exists)
        XCTAssertFalse(text(app, containing: "준비 중").exists, "자리 표시 화면이 떠 있다")
    }

    func testC13_onlyOneTabBarExists() {
        let app = launchVerified("referenceMonth")
        for tab in ["home", "feed", "calendar", "statistics", "my"] {
            XCTAssertEqual(
                app.buttons.matching(identifier: "tab.\(tab)").count, 1,
                "\(tab) 탭 버튼이 여러 개다. 탭 바가 중첩됐다"
            )
        }
    }

    func testC14_contentStaysAboveTheTabBar() {
        let app = launchVerified("selectedRecord")
        let tabBar = settled(app, app.buttons["tab.calendar"])
        let legend = settled(app, node(app, "calendar.legend"))
        XCTAssertLessThanOrEqual(
            legend.maxY, tabBar.minY + 1,
            "범례가 탭 바 아래로 파고든다"
        )
    }

    func testC15_calendarStateSurvivesTabSwitching() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(day(app, "2026-04-12").isSelected)
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "screen.home")))
        app.buttons["tab.calendar"].tap()
        XCTAssertTrue(waits(node(app, "screen.calendar")))
        assertMonthTitle(app, monthTitleLabel)
        XCTAssertTrue(day(app, "2026-04-12").isSelected, "탭을 다녀오니 선택이 풀렸다")
    }

    // MARK: - C · 날짜 기하

    func testC16_weekdayOrderStartsOnSunday() {
        let app = launchVerified("referenceMonth")
        XCTAssertTrue(waits(node(app, "calendar.grid")))
        let symbols = ["일", "월", "화", "수", "목", "금", "토"]
        let frames = symbols.map { symbol -> CGRect in
            let element = app.staticTexts.matching(
                NSPredicate(format: "label == %@", symbol)
            ).firstMatch
            XCTAssertTrue(waits(element), "요일 \(symbol)이 없다")
            return element.frame
        }
        for index in 1..<frames.count {
            XCTAssertLessThan(
                frames[index - 1].minX, frames[index].minX,
                "요일 순서가 어긋났다: \(symbols[index - 1]) 다음이 \(symbols[index])가 아니다"
            )
        }
    }

    /// 2026-04-01은 수요일이다. 첫날이 네 번째 열에 놓여야 한다.
    func testC17_firstAndLastDatesLandInTheCorrectColumns() {
        let app = launchVerified("referenceMonth")
        let sunday = settled(app, app.staticTexts.matching(NSPredicate(format: "label == %@", "일")).firstMatch)
        let wednesday = settled(app, app.staticTexts.matching(NSPredicate(format: "label == %@", "수")).firstMatch)
        let thursday = settled(app, app.staticTexts.matching(NSPredicate(format: "label == %@", "목")).firstMatch)

        let first = settled(app, day(app, "2026-04-01"))
        XCTAssertEqual(first.midX, wednesday.midX, accuracy: 4, "4월 1일이 수요일 열에 있지 않다")
        XCTAssertGreaterThan(first.midX, sunday.midX, "첫날이 일요일 열에 있다")

        let last = settled(app, day(app, "2026-04-30"))
        XCTAssertEqual(last.midX, thursday.midX, accuracy: 4, "4월 30일이 목요일 열에 있지 않다")
    }

    func testC18_leadingAndTrailingAdjacentDatesAreReal() {
        let app = launchVerified("referenceMonth")
        for iso in ["2026-03-29", "2026-03-30", "2026-03-31"] {
            XCTAssertTrue(day(app, iso).exists, "앞 채움 칸 \(iso)이 실제 날짜가 아니다")
        }
        for iso in ["2026-05-01", "2026-05-02"] {
            XCTAssertTrue(day(app, iso).exists, "뒤 채움 칸 \(iso)이 실제 날짜가 아니다")
        }
        XCTAssertFalse(day(app, "2026-03-28").exists, "필요 없는 앞 칸이 그려졌다")
        XCTAssertFalse(day(app, "2026-05-03").exists, "필요 없는 뒤 칸이 그려졌다")
    }

    func testC19_previousAndNextMonthNavigation() {
        let app = launchVerified("referenceMonth")
        node(app, "calendar.previousMonth").tap()
        XCTAssertTrue(waits(day(app, "2026-03-31")), "이전 달로 가지 못했다")
        assertMonthTitle(app, "2026년 3월")

        node(app, "calendar.nextMonth").tap()
        XCTAssertTrue(waits(day(app, "2026-04-30")))
        assertMonthTitle(app, monthTitleLabel)
    }

    func testC20_decemberToJanuaryCrossesTheYearBoundary() {
        let app = launchVerified("yearBoundary")
        assertMonthTitle(app, "2026년 12월")
        node(app, "calendar.nextMonth").tap()
        XCTAssertTrue(waits(day(app, "2027-01-31")), "12월에서 1월로 넘어가지 못했다")
        assertMonthTitle(app, "2027년 1월")

        node(app, "calendar.previousMonth").tap()
        XCTAssertTrue(waits(day(app, "2026-12-31")), "1월에서 12월로 돌아가지 못했다")
        assertMonthTitle(app, "2026년 12월")
    }

    // MARK: - D · 선택 의미

    func testC21_selectionIsExposedAsASelectedTraitNotOnlyColour() {
        let app = launchVerified("referenceMonth")
        let target = day(app, "2026-04-12")
        XCTAssertTrue(waits(target))
        XCTAssertFalse(target.isSelected, "고르기 전인데 이미 선택 상태다")
        target.tap()
        XCTAssertTrue(day(app, "2026-04-12").isSelected, "고른 날짜에 선택 표시가 없다")
        XCTAssertFalse(day(app, "2026-04-13").isSelected, "옆 날짜까지 선택됐다")
    }

    func testC22_adjacentMonthDateIsDistinguishable() {
        let app = launchVerified("referenceMonth")
        let adjacent = day(app, "2026-03-30")
        XCTAssertTrue(waits(adjacent))
        XCTAssertTrue(adjacent.value as? String != nil && (adjacent.value as! String).contains("다른 달"),
                      "앞 달 칸임을 색 말고 값으로 알리지 않는다")
        let inMonth = day(app, "2026-04-15")
        XCTAssertFalse(((inMonth.value as? String) ?? "").contains("다른 달"))
    }

    func testC23_multipleEventCountIsShownAndAnnounced() {
        let app = launchVerified("multipleSameDayRecords")
        XCTAssertTrue(day(app, "2026-04-12").isSelected)
        XCTAssertTrue(waits(node(app, "calendar.detailEventCount")), "같은 날 기록 개수가 표시되지 않는다")
        XCTAssertTrue(node(app, "calendar.detailEventCount").label.contains("2"),
                      "개수가 2로 표시되지 않는다")
        XCTAssertTrue(((day(app, "2026-04-12").value as? String) ?? "").contains("기록 2개"),
                      "날짜 칸이 개수를 알리지 않는다")
    }

    func testC24_selectedDetailSectionAppearsForBothRecordAndEmptyDates() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(waits(node(app, "calendar.selectedDetail")))
        XCTAssertTrue(node(app, "calendar.detailHeader").exists)
        XCTAssertTrue(text(app, containing: "4월 12일의 기억").exists, "Pencil 섹션 제목이 없다")

        day(app, "2026-04-20").tap()
        XCTAssertTrue(waits(node(app, "calendar.detailEmpty")), "빈 날짜로 바꿨는데 안내가 없다")
    }

    /// 선택일 상세를 시트가 덮지 않는다. 예전에 시트가 자동으로 떠 가린 적이 있다.
    func testC25_noSheetCoversTheInlineSelectedDetail() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(waits(node(app, "calendar.detailRecord")))
        XCTAssertTrue(node(app, "calendar.grid").isHittable, "무언가가 격자를 덮고 있다")
        XCTAssertTrue(node(app, "calendar.monthTitle").isHittable, "무언가가 헤더를 덮고 있다")
        XCTAssertEqual(app.sheets.count, 0, "선택만 했는데 시트가 떴다")
    }

    // MARK: - E · 기록과 정체성

    func testC26_recordIdentityIsFullyVisible() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(waits(node(app, "calendar.detailRecord")))
        XCTAssertTrue(text(app, containing: "삼성").exists, "응원 팀이 보이지 않는다")
        XCTAssertTrue(text(app, containing: "LG").exists, "상대 팀이 보이지 않는다")
        XCTAssertTrue(text(app, containing: "6").exists, "점수가 보이지 않는다")
    }

    /// 기록의 구장이 주 관람 구장으로 바뀌어서는 안 된다.
    func testC27_eventStadiumIsNotReplacedByThePrimaryStadium() {
        let app = launchVerified("selectedRecord", extra: [])
        XCTAssertTrue(waits(node(app, "calendar.detailRecord")))
        XCTAssertTrue(text(app, containing: "잠실야구장").exists,
                      "원정 기록인데 구장이 사라졌다")
        XCTAssertFalse(node(app, "calendar.detailRecord").label.contains("대구 삼성 라이온즈 파크"),
                       "기록의 구장이 주 관람 구장으로 바뀌었다")
    }

    func testC28_longTeamAndStadiumNamesWrapWithoutOverflow() {
        for fixture in ["longTeamName", "longStadiumName"] {
            let app = launchVerified(fixture)
            let card = settled(app, node(app, "calendar.detailRecord"))
            let root = settled(app, node(app, "calendar.root"))
            XCTAssertLessThanOrEqual(card.maxX, root.maxX + 1, "\(fixture) 카드가 화면 밖으로 넘친다")
            XCTAssertGreaterThanOrEqual(card.minX, root.minX - 1)
            XCTAssertFalse(node(app, "calendar.detailRecord").label.contains("…"),
                           "\(fixture)에서 이름이 잘렸다")
            app.terminate()
        }
    }

    func testC29_everyCanonicalTeamRendersStructurally() {
        let teams = ["lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
                     "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"]
        for team in teams {
            let app = launch("referenceMonth", teamID: team)
            XCTAssertTrue(waits(node(app, "calendar.scenario.referenceMonth")),
                          "\(team)에서 픽스처가 적용되지 않았다")
            XCTAssertTrue(node(app, "calendar.grid").exists, "\(team)에서 격자가 없다")
            XCTAssertTrue(node(app, "calendar.legend").exists, "\(team)에서 범례가 없다")
            app.terminate()
        }
    }

    func testC30_everyCanonicalStadiumRendersStructurally() {
        let stadiums = ["jamsil", "gocheok", "incheon-ssg", "suwon-kt", "daejeon-hanwha",
                        "daegu-lions", "gwangju-kia", "sajik", "changwon-nc"]
        for stadium in stadiums {
            let app = launch("referenceMonth", stadiumID: stadium)
            XCTAssertTrue(waits(node(app, "calendar.scenario.referenceMonth")),
                          "\(stadium)에서 픽스처가 적용되지 않았다")
            XCTAssertTrue(node(app, "calendar.grid").exists, "\(stadium)에서 격자가 없다")
            app.terminate()
        }
    }

    func testC31_teamAccentFixturesApplyTheRequestedTeam() {
        let light = launchVerified("lightTeamAccent")
        XCTAssertTrue(waits(node(light, "calendar.grid")))
        light.terminate()

        let dark = launchVerified("darkTeamAccent")
        XCTAssertTrue(waits(node(dark, "calendar.grid")))
        dark.terminate()
    }

    // MARK: - F · 상태 의미

    func testC32_everyResultIsAnnouncedAsWordsNotColourAlone() {
        for (fixture, iso, word) in [("win", "2026-04-12", "승"), ("loss", "2026-04-05", "패"),
                                     ("draw", "2026-04-01", "무"), ("cancelled", "2026-04-08", "취소")] {
            let app = launchVerified(fixture)
            let value = (day(app, iso).value as? String) ?? ""
            XCTAssertTrue(value.contains(word),
                          "\(fixture)의 결과가 색 말고 값으로 전달되지 않는다: \(value)")
            app.terminate()
        }
    }

    func testC33_designOnlyStatusesAreDistinctAndLabelled() {
        var seen: Set<String> = []
        for (fixture, expected) in [("scheduledDesignState", "경기 예정"),
                                    ("liveDesignState", "경기 중"),
                                    ("postponedDesignState", "우천 연기")] {
            let app = launchVerified(fixture)
            let badge = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "calendar.designStatus.")
            ).firstMatch
            XCTAssertTrue(waits(badge), "\(fixture) 배지가 없다")
            XCTAssertTrue(seen.insert(badge.identifier).inserted,
                          "\(fixture)가 다른 상태와 같은 식별자를 쓴다")
            XCTAssertTrue(text(app, containing: expected).exists, "\(expected) 문구가 없다")
            app.terminate()
        }
        XCTAssertEqual(seen.count, 3)
    }

    /// 제품 상태에서는 디자인 전용 배지가 절대 나타나지 않는다.
    func testC34_designOnlyStatusNeverAppearsWithoutItsFixture() {
        for fixture in ["referenceMonth", "selectedRecord", "emptyMonth"] {
            let app = launchVerified(fixture)
            let badge = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "calendar.designStatus.")
            ).firstMatch
            XCTAssertFalse(badge.exists, "\(fixture)에서 디자인 전용 배지가 나타났다")
            for word in ["경기 예정", "경기 중", "우천 연기"] {
                XCTAssertFalse(text(app, containing: word).exists,
                               "\(fixture)에서 \(word)가 나타났다")
            }
            app.terminate()
        }
    }

    // MARK: - H · 이동 경로

    func testC35_recordDetailDestinationIsReachableAndReturns() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(waits(node(app, "calendar.detailRecord")))
        node(app, "calendar.detailRecord").tap()
        XCTAssertTrue(waits(text(app, containing: "삼성 vs LG"), 10), "기록 상세로 가지 못했다")

        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() } else { app.swipeRight() }
        XCTAssertTrue(waits(node(app, "calendar.grid")), "캘린더로 돌아오지 못했다")
        assertMonthTitle(app, monthTitleLabel)
        XCTAssertTrue(day(app, "2026-04-12").isSelected, "돌아오니 선택이 풀렸다")
    }

    func testC36_recordCreateDestinationIsReachableFromAnEmptyDate() {
        let app = launchVerified("selectedEmptyDate")
        XCTAssertTrue(waits(node(app, "calendar.detailAddRecord")), "기록 추가 경로가 없다")
        XCTAssertTrue(node(app, "calendar.detailAddRecord").isHittable)
        node(app, "calendar.detailAddRecord").tap()
        XCTAssertTrue(waits(app.sheets.firstMatch, 10)
                      || waits(text(app, containing: "기록"), 10),
                      "기록 작성 화면이 열리지 않았다")
    }

    func testC37_sectionHeaderDetailActionOpensTheRecord() {
        let app = launchVerified("selectedRecord")
        XCTAssertTrue(waits(node(app, "calendar.detailHeader")))
        let more = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "자세히")).firstMatch
        XCTAssertTrue(waits(more), "Pencil의 '자세히'가 동작하지 않는다")
        more.tap()
        XCTAssertTrue(waits(text(app, containing: "삼성 vs LG"), 10), "자세히가 상세로 가지 않는다")
    }
}
