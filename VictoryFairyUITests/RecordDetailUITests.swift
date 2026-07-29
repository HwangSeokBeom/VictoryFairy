import XCTest

/// 기록 상세를 결정적인 픽스처 상태로 띄워 검증한다.
///
/// 상세는 스스로 뜨는 화면이 아니라 피드나 캘린더에서 **눌러서** 들어가는 화면이다.
/// 그래서 모든 실행이 실제 목록에서 기록을 눌러 들어가고, 그 뒤에 화면에서 시나리오
/// 표식을 먼저 확인한 다음에만 다음 단언으로 넘어간다.
final class RecordDetailUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - 실행과 조회 도구

    enum Entry {
        case feed
        case calendar
    }

    private func app(
        _ fixture: String,
        via entry: Entry = .feed,
        teamID: String = "samsung-lions",
        accessibilitySize: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = [
            "-VFUITest", "-VFUITestReset",
            "-VFUITestTeamID", teamID,
            "-VFUITestStadiumID", "daegu-lions",
            "-VFUITestOnboardingCompleted", "1",
            "-VFUITestRecordDetailFixture", fixture
        ]
        switch entry {
        case .feed:
            arguments += ["-VFUITestInitialTab", "feed", "-VFUITestFeedFixture", "populated"]
        case .calendar:
            arguments += ["-VFUITestInitialTab", "calendar", "-VFUITestCalendarFixture", "selectedRecord"]
        }
        if accessibilitySize {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// 목록에서 기록을 눌러 상세로 들어간 뒤, 시나리오가 실제로 적용됐는지 확인한다.
    @discardableResult
    func openDetail(
        _ fixture: String,
        via entry: Entry = .feed,
        teamID: String = "samsung-lions",
        accessibilitySize: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIApplication {
        let app = app(fixture, via: entry, teamID: teamID, accessibilitySize: accessibilitySize)
        switch entry {
        case .feed:
            XCTAssertTrue(waits(node(app, "screen.feed")), "피드에 들어가지 못했다", file: file, line: line)
            let card = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH 'feed.record.'"))
                .firstMatch
            XCTAssertTrue(waits(card), "피드에 누를 기록이 없다", file: file, line: line)
            card.tap()
        case .calendar:
            XCTAssertTrue(waits(node(app, "screen.calendar")), "캘린더에 들어가지 못했다", file: file, line: line)
            let record = node(app, "calendar.detailRecord")
            XCTAssertTrue(waits(record), "캘린더 선택일에 기록이 없다", file: file, line: line)
            record.tap()
        }
        XCTAssertTrue(
            waits(node(app, "recordDetail.scenario.\(fixture)")),
            "픽스처 \(fixture)가 적용되지 않고 제품 상태로 돌아갔다",
            file: file, line: line
        )
        return app
    }

    func node(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func waits(_ element: XCUIElement, _ timeout: TimeInterval = 12) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    func text(_ app: XCUIApplication, containing needle: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 화면이 자리를 잡은 뒤에 좌표를 읽는다. 애니메이션 중의 값을 재면 결과가 흔들린다.
    func settled(_ element: XCUIElement) -> CGRect {
        XCTAssertTrue(waits(element), "요소가 나타나지 않아 좌표를 잴 수 없다")
        var previous = element.frame
        for _ in 0..<25 {
            usleep(120_000)
            let current = element.frame
            if current == previous { return current }
            previous = current
        }
        return previous
    }

    @discardableResult
    func scrollTo(
        _ app: XCUIApplication, _ identifier: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let element = node(app, identifier)
        if element.waitForExistence(timeout: 3), element.isHittable { return element }
        for _ in 0..<12 {
            if element.exists, element.isHittable { return element }
            app.swipeUp()
            usleep(320_000)
        }
        XCTAssertTrue(element.exists, "\(identifier)에 스크롤해도 닿을 수 없다", file: file, line: line)
        return element
    }

    private func label(_ app: XCUIApplication, _ identifier: String) -> String {
        let element = node(app, identifier)
        XCTAssertTrue(waits(element), "\(identifier)가 없다")
        return element.label
    }

    // MARK: - A · 픽스처 활성화와 진입 경로

    func testD01_referenceRecordOpensFromFeed() {
        let app = openDetail("referenceRecord", via: .feed)
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "상세 루트가 없다")
        XCTAssertEqual(label(app, "recordDetail.title"), "목이 다 쉰 날")
    }

    func testD02_referenceRecordOpensFromCalendar() {
        let app = openDetail("referenceRecord", via: .calendar)
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "캘린더에서 들어간 상세가 없다")
        XCTAssertEqual(label(app, "recordDetail.title"), "목이 다 쉰 날")
    }

    /// 두 진입 경로가 같은 기록 정체성을 넘긴다.
    func testD03_feedAndCalendarReachTheSameRecord() {
        let fromFeed = openDetail("referenceRecord", via: .feed)
        let feedScore = label(fromFeed, "recordDetail.score")
        let feedTitle = label(fromFeed, "recordDetail.title")
        fromFeed.terminate()

        let fromCalendar = openDetail("referenceRecord", via: .calendar)
        XCTAssertEqual(label(fromCalendar, "recordDetail.score"), feedScore, "두 경로가 다른 점수를 보여 준다")
        XCTAssertEqual(label(fromCalendar, "recordDetail.title"), feedTitle, "두 경로가 다른 기록을 연다")
    }

    func testD04_unknownScenarioDoesNotActivateAFixture() {
        let app = app("nope", via: .feed)
        XCTAssertTrue(waits(node(app, "screen.feed")))
        let markers = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'recordDetail.scenario.'"))
        XCTAssertEqual(markers.count, 0, "알 수 없는 이름이 픽스처를 켰다")
    }

    // MARK: - B · 루트와 내비게이션

    func testD05_backActionReturnsToTheList() {
        let app = openDetail("referenceRecord", via: .feed)
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(waits(back), "뒤로 가기 버튼이 없다")
        back.tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "뒤로 가기가 목록으로 돌아가지 않았다")
    }

    func testD06_onlyOneNavigationBarAndOneTabBar() {
        let app = openDetail("referenceRecord", via: .feed)
        XCTAssertLessThanOrEqual(app.navigationBars.count, 1, "내비게이션 바가 겹쳐 있다")
        XCTAssertEqual(app.buttons.matching(identifier: "tab.feed").count, 1, "탭바가 두 개다")
    }

    /// 눌러도 아무 일도 하지 않는 버튼이 없다.
    func testD07_overflowMenuOpensAndOffersRealActions() {
        let app = openDetail("referenceRecord", via: .feed)
        let overflow = node(app, "recordDetail.overflow")
        XCTAssertTrue(waits(overflow), "더보기 액션이 없다")
        overflow.tap()
        // 메뉴 항목은 정적 텍스트가 아니라 버튼으로 노출된다.
        XCTAssertTrue(app.buttons["기록 수정하기"].firstMatch.waitForExistence(timeout: 6), "수정 항목이 없다")
        XCTAssertTrue(app.buttons["기록 삭제하기"].firstMatch.exists, "삭제 항목이 없다")
    }

    // MARK: - C · 매치업과 정체성

    func testD08_matchupShowsBothTeamsAndTheResult() {
        let app = openDetail("referenceRecord")
        XCTAssertEqual(label(app, "recordDetail.team.samsung-lions"), "나의 팀 삼성 라이온즈")
        XCTAssertEqual(label(app, "recordDetail.opponent.lg-twins"), "상대 팀 LG 트윈스")
        XCTAssertTrue(text(app, containing: "승리").exists, "결과가 글자로 남아 있지 않다")
    }

    func testD09_scoreIsShown() {
        let app = openDetail("referenceRecord")
        XCTAssertTrue(label(app, "recordDetail.score").contains("6대 3"), "점수를 읽어 주지 않는다")
    }

    func testD10_dateTitleIsTheRecordDate() {
        let app = openDetail("referenceRecord")
        XCTAssertTrue(app.navigationBars["2026년 4월 12일"].waitForExistence(timeout: 8),
                      "제목이 기록 날짜가 아니다")
    }

    func testD11_placeMetaShowsStadiumAndSeat() {
        let app = openDetail("referenceRecord")
        XCTAssertEqual(label(app, "recordDetail.placeMeta"), "잠실야구장 · 3루 원정석 K열")
    }

    /// 열 개 구단 전부가 상세에서 자기 정체성을 보여 준다.
    func testD12_everyTeamRendersItsIdentity() {
        let teams = [
            "lg-twins", "doosan-bears", "kiwoom-heroes", "ssg-landers", "kt-wiz",
            "hanwha-eagles", "samsung-lions", "kia-tigers", "lotte-giants", "nc-dinos"
        ]
        for teamID in teams {
            let app = openDetail("referenceRecord", teamID: teamID)
            // 기록의 매치업은 삼성 vs LG다. 응원 팀이 그중 하나면 나의 팀으로,
            // 아니면 적힌 순서대로 나온다. 어느 쪽이든 두 팀이 모두 보여야 한다.
            let hasMine = node(app, "recordDetail.team.samsung-lions").exists
                || node(app, "recordDetail.team.lg-twins").exists
            XCTAssertTrue(hasMine, "\(teamID)에서 나의 팀 자리가 비었다")
            let hasOpponent = node(app, "recordDetail.opponent.lg-twins").exists
                || node(app, "recordDetail.opponent.samsung-lions").exists
            XCTAssertTrue(hasOpponent, "\(teamID)에서 상대 팀 자리가 비었다")
            app.terminate()
        }
    }

    func testD13_stadiumIdentityUsesTheRecordVenue() {
        let app = openDetail("referenceRecord")
        XCTAssertTrue(waits(node(app, "recordDetail.stadium.jamsil")), "기록 구장이 없다")
        XCTAssertFalse(node(app, "recordDetail.stadium.daegu-lions").exists,
                       "주 관람 구장이 기록 구장을 대신했다")
    }

    func testD14_unknownStadiumStaysHonest() {
        let app = openDetail("unknownStadium")
        XCTAssertTrue(waits(node(app, "recordDetail.stadium.unknown")), "등록되지 않은 구장 상태가 없다")
        XCTAssertTrue(text(app, containing: "동대문운동장").exists, "적힌 구장 이름이 사라졌다")
    }

    func testD15_missingStadiumStaysHonest() {
        let app = openDetail("missingStadium")
        XCTAssertTrue(waits(node(app, "recordDetail.stadium.missing")), "구장 없음 상태가 없다")
        XCTAssertEqual(label(app, "recordDetail.placeMeta"), "3루 원정석 K열")
    }

    func testD16_longStadiumNameWraps() {
        let app = openDetail("longStadiumName")
        let stadium = settled(scrollTo(app, "recordDetail.stadium.gwangju-kia"))
        XCTAssertGreaterThan(stadium.height, 60, "긴 구장 이름이 한 줄로 잘렸다")
    }

    // MARK: - D · 미디어

    func testD17_realPhotoIsShown() {
        let app = openDetail("withPhoto")
        XCTAssertTrue(waits(node(app, "recordDetail.media.photo")), "사진이 그려지지 않았다")
        XCTAssertEqual(label(app, "recordDetail.media.photo"), "이 기록의 사진")
    }

    func testD18_noPhotoStateIsDistinct() {
        let app = openDetail("withoutPhoto")
        XCTAssertTrue(waits(node(app, "recordDetail.media.empty")), "사진 없음 상태가 없다")
        XCTAssertTrue(text(app, containing: "사진이 없어요").exists)
        XCTAssertFalse(node(app, "recordDetail.media.photo").exists)
    }

    /// 파일이 사라진 것과 사진이 없는 것은 다른 사실이라 다르게 말한다.
    func testD19_missingPhotoFileIsNotTheSameAsNoPhoto() {
        let app = openDetail("missingPhotoFile")
        XCTAssertTrue(waits(node(app, "recordDetail.media.missingFile")), "파일 없음 상태가 없다")
        XCTAssertTrue(text(app, containing: "찾을 수 없어요").exists)
        XCTAssertFalse(node(app, "recordDetail.media.empty").exists, "파일 없음이 사진 없음으로 뭉개졌다")
    }

    func testD20_failedDecodeHasItsOwnState() {
        let app = openDetail("failedPhotoDecode")
        XCTAssertTrue(waits(node(app, "recordDetail.media.decodeFailed")), "열 수 없음 상태가 없다")
        XCTAssertTrue(text(app, containing: "열 수 없어요").exists)
    }

    /// 결과 스탬프는 사진 위에서도 늘 읽힌다.
    func testD21_resultStampIsAnnounced() {
        let app = openDetail("withPhoto")
        XCTAssertTrue(waits(node(app, "recordDetail.result")))
        XCTAssertEqual(label(app, "recordDetail.result"), "승리")
    }

    // MARK: - E · 사용자가 쓴 기록

    func testD22_shortNoteIsShown() {
        let app = openDetail("referenceRecord")
        let note = scrollTo(app, "recordDetail.note")
        XCTAssertTrue(note.exists, "일기가 없다")
        XCTAssertTrue(text(app, containing: "목이 다 쉬었다").exists)
    }

    func testD23_longNoteStaysCompleteAndReachable() {
        let app = openDetail("longNote")
        scrollTo(app, "recordDetail.note")
        // 마지막 문단까지 실제로 닿아야 한다.
        var reachedEnd = false
        for _ in 0..<14 where !reachedEnd {
            if text(app, containing: "다음에도 엄마랑").exists { reachedEnd = true; break }
            app.swipeUp()
            usleep(300_000)
        }
        XCTAssertTrue(reachedEnd, "긴 일기의 끝에 닿을 수 없다")
        XCTAssertTrue(text(app, containing: "잠실 3루가 그렇게 크게 울린").exists, "가운데 문단이 잘렸다")
    }

    func testD24_noNoteStateIsHonest() {
        let app = openDetail("noNote")
        XCTAssertTrue(waits(scrollTo(app, "recordDetail.note.empty")), "일기 없음 안내가 없다")
        XCTAssertFalse(node(app, "recordDetail.note").exists, "일기가 없는데 본문 카드가 떴다")
    }

    // MARK: - F · 결과 상태

    func testD25_winLossAndDrawEachRender() {
        for (fixture, spoken) in [("win", "승리"), ("loss", "패배"), ("draw", "무승부")] {
            let app = openDetail(fixture)
            XCTAssertEqual(label(app, "recordDetail.result"), spoken, "\(fixture) 결과가 틀렸다")
            XCTAssertTrue(node(app, "recordDetail.score").exists, "\(fixture)에 점수가 없다")
            app.terminate()
        }
    }

    func testD26_cancelledGameShowsNoScore() {
        let app = openDetail("cancelled")
        XCTAssertEqual(label(app, "recordDetail.result"), "취소")
        XCTAssertEqual(label(app, "recordDetail.score"), "경기 취소")
    }

    func testD27_missingScoreIsHonest() {
        let app = openDetail("missingScore")
        XCTAssertEqual(label(app, "recordDetail.score"), "점수 미기록")
    }

    func testD28_missingOpponentIsHonest() {
        let app = openDetail("missingOpponent")
        XCTAssertTrue(waits(node(app, "recordDetail.opponent.missing")), "상대 미기록 상태가 없다")
        XCTAssertEqual(label(app, "recordDetail.opponent.missing"), "상대 팀 미기록")
    }

    // MARK: - G · 불러오기와 복구

    func testD29_loadingStateIsShown() {
        let app = openDetail("loading")
        XCTAssertTrue(waits(node(app, "recordDetail.loading")), "불러오는 중 표시가 없다")
        XCTAssertFalse(node(app, "recordDetail.scoreboard").exists, "불러오는 중인데 본문이 떴다")
    }

    func testD30_recoverableErrorExposesRetry() {
        let app = openDetail("recoverableError")
        XCTAssertTrue(waits(node(app, "recordDetail.error")), "복구 안내가 없다")
        XCTAssertTrue(node(app, "recordDetail.retry").isHittable, "다시 시도 버튼을 누를 수 없다")
    }

    func testD31_retrySuccessShowsThePopulatedDetail() {
        let app = openDetail("retrySuccess")
        XCTAssertFalse(node(app, "recordDetail.error").exists, "성공 후에도 오류가 남아 있다")
        XCTAssertTrue(waits(node(app, "recordDetail.scoreboard")))
    }

    // MARK: - H · 편집

    func testD32_editOpensTheExistingEditorWithValuesPrefilled() {
        let app = openDetail("referenceRecord")
        scrollTo(app, "recordDetail.edit").tap()
        XCTAssertTrue(text(app, containing: "3루 원정석 K열").waitForExistence(timeout: 10),
                      "편집기가 기존 좌석 값을 불러오지 않았다")
        XCTAssertTrue(text(app, containing: "엄마랑").exists, "편집기가 기존 동행 값을 불러오지 않았다")
    }

    func testD33_cancellingTheEditorPreservesTheDetail() {
        let app = openDetail("referenceRecord")
        scrollTo(app, "recordDetail.edit").tap()
        XCTAssertTrue(text(app, containing: "3루 원정석 K열").waitForExistence(timeout: 10))
        let cancel = app.buttons["취소"].firstMatch
        if cancel.waitForExistence(timeout: 4) {
            cancel.tap()
        } else {
            app.swipeDown(velocity: .fast)
        }
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "편집을 취소했는데 상세로 돌아오지 않았다")
        XCTAssertEqual(label(app, "recordDetail.title"), "목이 다 쉰 날", "취소했는데 값이 바뀌었다")
    }

    // MARK: - I · 삭제

    func testD34_deleteAsksForConfirmationWithDestructiveWording() {
        let app = openDetail("deleteConfirmation")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(text(app, containing: "이 기록을 삭제할까요?").waitForExistence(timeout: 8),
                      "확인 대화상자가 없다")
        XCTAssertTrue(text(app, containing: "되돌릴 수 없어요").exists, "되돌릴 수 없다는 안내가 없다")
        // 확인 대화상자의 버튼은 접근성 트리에 두 번 노출된다. 첫 번째만 집는다.
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.exists, "삭제 버튼이 없다")
        XCTAssertTrue(app.buttons["남겨둘래요"].firstMatch.waitForExistence(timeout: 8), "취소 버튼이 없다")
    }

    /// 대화상자의 두 버튼 모두 읽을 수 있는 이름을 갖는다.
    ///
    /// 액션 시트로 만들었을 때 취소 버튼이 **이름 없는 버튼**으로 나온 적이 있다.
    /// 화면을 읽는 사람에게는 무엇을 누르는지 알 수 없는 칸이 되므로, 이름이 비어 있지
    /// 않은지 좌표가 아니라 이름으로 확인한다.
    func testD34b_bothConfirmationButtonsHaveReadableNames() {
        let app = openDetail("deleteConfirmation")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8))

        for identifier in ["recordDetail.delete.confirm", "recordDetail.delete.cancel"] {
            let button = node(app, identifier)
            XCTAssertTrue(button.exists, "\(identifier) 버튼이 없다")
            XCTAssertFalse(button.label.trimmingCharacters(in: .whitespaces).isEmpty,
                           "\(identifier) 버튼에 읽을 이름이 없다")
        }
    }

    func testD35_cancellingDeletionKeepsTheRecord() {
        let app = openDetail("deleteConfirmation")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["남겨둘래요"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["남겨둘래요"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "recordDetail.root")), "취소했는데 상세를 떠났다")
        XCTAssertEqual(label(app, "recordDetail.title"), "목이 다 쉰 날")
    }

    func testD36_successfulDeletionReturnsToTheList() {
        let app = openDetail("deleteSuccess")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["삭제하기"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "screen.feed")), "삭제 후 목록으로 돌아가지 않았다")
    }

    /// 삭제에 실패하면 화면을 떠나지 않는다. 기록도 그대로 남아 있다.
    func testD37_failedDeletionStaysOnTheDetail() {
        let app = openDetail("deleteFailure")
        node(app, "recordDetail.overflow").tap()
        app.buttons["기록 삭제하기"].firstMatch.tap()
        XCTAssertTrue(app.buttons["삭제하기"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["삭제하기"].firstMatch.tap()

        XCTAssertTrue(waits(node(app, "recordDetail.error")), "삭제 실패를 알리지 않는다")
        XCTAssertTrue(node(app, "recordDetail.root").exists, "삭제에 실패했는데 화면을 떠났다")
        XCTAssertEqual(label(app, "recordDetail.title"), "목이 다 쉰 날", "실패했는데 기록이 사라졌다")
    }

    // MARK: - J · 그 밖의 내용

    func testD38_detailsOnlyShowStoredFields() {
        let app = openDetail("referenceRecord")
        scrollTo(app, "recordDetail.details")
        XCTAssertEqual(label(app, "recordDetail.fact.companion"), "함께한 사람, 엄마랑")
        XCTAssertEqual(label(app, "recordDetail.fact.seat"), "좌석, 3루 원정석 K열")
        for invented in ["날씨", "먹은 것", "응원 준비물"] {
            XCTAssertFalse(text(app, containing: invented).exists, "\(invented)을 지어냈다")
        }
    }

    func testD39_moodAndHighlightComeFromStoredTags() {
        let app = openDetail("referenceRecord")
        scrollTo(app, "recordDetail.mood")
        XCTAssertEqual(label(app, "recordDetail.mood"), "이날의 기분, 벅차오름")
        XCTAssertTrue(text(app, containing: "역전승").exists, "하이라이트 태그가 없다")
    }

    func testD40_shareActionReachesTheShareScreen() {
        let app = openDetail("referenceRecord")
        scrollTo(app, "recordDetail.share").tap()
        XCTAssertTrue(text(app, containing: "공유").waitForExistence(timeout: 10), "공유 화면으로 가지 못했다")
    }
}
