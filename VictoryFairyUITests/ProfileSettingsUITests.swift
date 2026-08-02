import XCTest

/// Pencil `08_Profile_Settings`(NffPV)이 그린 **마이** 탭 루트의 사용자 동선.
///
/// 확인하는 것은 소스가 아니라 화면이다. 다섯 번째 탭이 이 화면을 열고, 보이는
/// 값은 전부 실제 값이며, 뒷받침이 없는 행은 화면에 아예 없다.
final class ProfileSettingsUITests: XCTestCase {

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

    private func text(_ app: XCUIApplication, _ needle: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
    }

    /// 화면 어디에도 이 문구가 없다.
    private func assertAbsent(_ app: XCUIApplication, _ needle: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(text(app, needle).exists, "\(needle)이 화면에 있다", file: file, line: line)
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-VFUITest", "-VFUITestReset",
                               "-VFUITestOnboardingCompleted", "1"] + extra
        app.launch()
        return app
    }

    /// 제품 경로로 마이 탭을 연다. 픽스처 호스트를 쓰지 않는다.
    @discardableResult
    private func openMy(_ extra: [String] = []) -> XCUIApplication {
        let app = launch(extra)
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "screen.my")), "마이 탭이 열리지 않았다")
        XCTAssertTrue(waits(node(app, "profile.root")), "마이 화면 루트가 없다")
        return app
    }

    private func populated(_ extra: [String] = []) -> XCUIApplication {
        openMy(["-VFUITestTeamID", "samsung-lions",
                "-VFUITestStadiumID", "daegu-lions",
                "-VFUITestDisplayName", "민지"] + extra)
    }

    // MARK: - 1~3. 다섯 번째 탭이 이 화면을 연다

    func testM01_theFifthTabOpensProfileMy() {
        let app = populated()
        XCTAssertTrue(node(app, "profile.card").exists, "프로필 카드가 없다")
    }

    func testM02_exactlyFiveTabsRemain() {
        let app = populated()
        for identifier in ["tab.home", "tab.feed", "tab.calendar", "tab.statistics", "tab.my"] {
            XCTAssertTrue(node(app, identifier).exists, "\(identifier) 탭이 없다")
        }
        XCTAssertFalse(node(app, "tab.community").exists, "여섯 번째 탭이 생겼다")
    }

    func testM03_everyOtherTabCanReachMyAndBack() {
        let app = populated()
        for origin in ["tab.home", "tab.feed", "tab.calendar", "tab.statistics"] {
            app.buttons[origin].tap()
            XCTAssertTrue(waits(node(app, "screen.\(origin.replacingOccurrences(of: "tab.", with: ""))")),
                          "\(origin)으로 가지 못했다")
            app.buttons["tab.my"].tap()
            XCTAssertTrue(waits(node(app, "profile.root")), "\(origin)에서 마이로 오지 못했다")
        }
    }

    // MARK: - 4~7. 정체성

    func testM04_theRealDisplayNameIsShown() {
        let app = populated()
        XCTAssertEqual(node(app, "profile.name").label, "민지", "저장된 이름이 보이지 않는다")
    }

    func testM05_missingDisplayNameShowsNeutralWordingNotAName() {
        let app = openMy(["-VFUITestTeamID", "samsung-lions",
                          "-VFUITestStadiumID", "daegu-lions"])
        let name = node(app, "profile.name")
        XCTAssertTrue(waits(name), "이름 자리가 없다")
        XCTAssertEqual(name.label, "이름을 정하지 않았어요", "이름이 없는데 이름을 지어냈다")
        assertAbsent(app, "승리요정 민지")
    }

    func testM06_theRealFavouriteTeamIsShown() {
        let app = populated()
        XCTAssertTrue(node(app, "profile.team").label.contains("삼성"),
                      "저장된 응원 팀이 보이지 않는다 — \(node(app, "profile.team").label)")
    }

    /// 응원 팀이 없는 상태는 **제품 경로로 만들 수 없다.**
    ///
    /// `onboardingEntry`는 팀과 구장이 모두 유효할 때만 `.completed`가 되므로, 팀이
    /// 없으면 탭 자체가 뜨지 않고 온보딩이 뜬다. 그래서 여기서는 "팀 없는 마이 화면"
    /// 대신 그 불변식을 확인한다. 화면의 중립 표현 자체는 단위 테스트가 지킨다.
    func testM07_theProductCannotReachTheTabsWithoutAFavouriteTeam() {
        let app = launch(["-VFUITestDisplayName", "민지"])
        XCTAssertFalse(app.buttons["tab.my"].waitForExistence(timeout: 6),
                       "응원 팀 없이 탭이 떴다 — 온보딩 불변식이 깨졌다")
    }

    // MARK: - 8~10. 프로필 편집

    func testM08_theEditActionOpensTheExistingEditor() {
        let app = populated()
        let edit = node(app, "profile.edit")
        XCTAssertTrue(edit.isHittable, "프로필 수정을 누를 수 없다")
        edit.tap()
        XCTAssertTrue(waits(text(app, "프로필"), 10), "기존 프로필 편집기가 열리지 않았다")
    }

    func testM09_cancellingTheEditorKeepsTheName() {
        let app = populated()
        node(app, "profile.edit").tap()
        XCTAssertTrue(waits(text(app, "프로필"), 10))
        let cancel = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "취소", "닫기")).firstMatch
        if cancel.exists { cancel.tap() } else { app.swipeDown() }
        XCTAssertTrue(waits(node(app, "profile.root")), "편집기를 닫고 돌아오지 못했다")
        XCTAssertEqual(node(app, "profile.name").label, "민지", "취소했는데 이름이 바뀌었다")
    }

    /// 프로필 카드가 자식들을 하나로 뭉개지 않는다.
    ///
    /// 컨테이너에 식별자만 붙이면 SwiftUI가 그것을 자식 전부에 덮어써서, 카드
    /// 하나만 잡히고 이름·팀·수정은 사라진다(실측). 각각이 독립된 요소로 남아야
    /// 사용자도 VoiceOver도 따로 쓸 수 있다.
    func testM10_theProfileCardExposesIndependentSemantics() {
        let app = populated()

        for identifier in ["profile.card", "profile.name", "profile.team", "profile.edit"] {
            let matches = app.descendants(matching: .any).matching(identifier: identifier)
            XCTAssertEqual(matches.count, 1,
                           "\(identifier)이 \(matches.count)개로 잡힌다 — 카드가 자식을 덮어썼다")
        }

        // 수정은 진짜 버튼이고, 팀 요약과 서로 다른 요소다.
        let edit = app.buttons["profile.edit"]
        XCTAssertTrue(edit.exists, "프로필 수정이 버튼으로 노출되지 않는다")
        XCTAssertTrue(edit.isHittable, "프로필 수정을 누를 수 없다")
        XCTAssertEqual(edit.label, "프로필 수정", "수정 버튼이 자기 뜻을 말하지 않는다")

        let team = node(app, "profile.team")
        XCTAssertNotEqual(team.frame, edit.frame, "팀과 수정이 같은 요소로 합쳐졌다")
        XCTAssertTrue(team.label.contains("응원 팀"), "팀 요약이 자기 뜻을 말하지 않는다 — \(team.label)")

        // 카드 자체는 담기만 한다 — 자기 라벨로 자식을 대체하지 않는다.
        XCTAssertTrue(node(app, "profile.card").label.isEmpty,
                      "카드가 자식 대신 자기 라벨을 읽는다")

        XCTAssertTrue(node(app, "profile.teamChange").exists, "응원 팀 변경이 없다")
    }

    // MARK: - 11~14. 응원 팀 변경 — 이미 있던 계약

    func testM11_theTeamChangeRowIsPresentAndOpensTheExistingSelector() {
        let app = populated()
        let row = node(app, "profile.teamChange")
        XCTAssertTrue(row.isHittable, "응원 팀 변경을 누를 수 없다")
        row.tap()
        XCTAssertTrue(waits(text(app, "응원팀 변경"), 10), "기존 팀 선택 화면이 열리지 않았다")
    }

    func testM12_theSelectorOffersCanonicalTeams() {
        let app = populated()
        node(app, "profile.teamChange").tap()
        XCTAssertTrue(waits(text(app, "응원팀 변경"), 10))
        for team in ["LG 트윈스", "KIA 타이거즈"] {
            XCTAssertTrue(app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", team)).firstMatch.exists,
                "canonical 팀 \(team)이 목록에 없다")
        }
    }

    func testM13_choosingATeamUpdatesTheProfileCard() {
        let app = populated()
        node(app, "profile.teamChange").tap()
        XCTAssertTrue(waits(text(app, "응원팀 변경"), 10))
        let lg = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "LG 트윈스")).firstMatch
        XCTAssertTrue(waits(lg, 8), "LG 트윈스를 찾지 못했다")
        lg.tap()
        app.buttons["완료"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "profile.root")), "팀 선택을 닫고 돌아오지 못했다")
        XCTAssertTrue(node(app, "profile.team").label.contains("LG"),
                      "고른 팀이 카드에 반영되지 않았다 — \(node(app, "profile.team").label)")
    }

    func testM14_cancellingTheSelectorKeepsThePreviousTeam() {
        let app = populated()
        let before = node(app, "profile.team").label
        node(app, "profile.teamChange").tap()
        XCTAssertTrue(waits(text(app, "응원팀 변경"), 10))
        app.buttons["완료"].firstMatch.tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertEqual(node(app, "profile.team").label, before,
                       "아무것도 고르지 않았는데 팀이 바뀌었다")
    }

    // MARK: - 15~18. 앱 정보

    func testM15_legalRowsArePresent() {
        let app = populated()
        for identifier in ["profile.legal.privacy", "profile.legal.terms",
                           "profile.legal.accountDeletion"] {
            XCTAssertTrue(node(app, identifier).exists, "\(identifier) 행이 없다")
            XCTAssertTrue(node(app, identifier).isHittable, "\(identifier)을 누를 수 없다")
        }
    }

    func testM16_theVersionRowShowsARealBundleVersion() {
        let app = populated()
        let version = node(app, "profile.appVersion")
        XCTAssertTrue(waits(version), "앱 버전 행이 없다")
        let label = version.label
        XCTAssertTrue(label.contains("앱 버전"), "버전 행이 자기 이름을 말하지 않는다")
        XCTAssertFalse(label.contains("0.1.0"), "예전 하드코딩 버전이 보인다")
        XCTAssertFalse(label.contains("2.0.0"), "Pencil 견본 버전이 보인다")
        XCTAssertFalse(label.contains("알 수 없음"), "번들에서 버전을 읽지 못했다")
    }

    func testM17_theVersionRowIsNotAButton() {
        let app = populated()
        XCTAssertFalse(app.buttons["profile.appVersion"].exists,
                       "정보를 말하는 줄이 버튼으로 노출됐다")
    }

    func testM18_accountDeletionGuidanceDoesNotDeleteAnything() {
        let app = populated()
        XCTAssertTrue(node(app, "profile.legal.accountDeletion").exists, "계정 삭제 안내가 없다")
        // 안내일 뿐이므로 확인 대화상자나 파괴적 문구가 붙어 있으면 안 된다.
        assertAbsent(app, "정말 삭제")
        assertAbsent(app, "계정을 삭제할까요")
    }

    // MARK: - 19~21. 뒷받침 없는 것은 화면에 없다

    func testM19_unsupportedRowsAreAbsent() {
        let app = populated()
        for forbidden in ["경기 시작 알림", "직관 후 기록 리마인드", "기록 내보내기",
                          "데이터 내보내기", "사진 보관함 관리", "128장",
                          "추후 제공", "준비 중", "곧 제공"] {
            assertAbsent(app, forbidden)
        }
    }

    func testM20_logoutIsAbsent() {
        let app = populated()
        assertAbsent(app, "로그아웃")
        XCTAssertFalse(app.buttons["로그아웃"].exists, "로그아웃 버튼이 있다")
    }

    func testM21_noInventedSummaryOrTitleAppears() {
        let app = populated()
        assertAbsent(app, "세 번째 시즌")
        assertAbsent(app, "함께한")
        assertAbsent(app, "승률")
        assertAbsent(app, "총 기록 수")
        // NffPV는 화면 제목을 그리지 않는다.
        XCTAssertFalse(app.navigationBars["설정"].exists, "그리지 않은 제목이 남았다")
    }

    func testM22_theTabRootHasNoCloseButton() {
        let app = populated()
        // 탭 루트에는 닫을 것이 없다. 자식 시트는 자기 닫기를 가진다.
        XCTAssertFalse(app.navigationBars.buttons["닫기"].exists,
                       "탭 루트에 닫기가 있다")
    }

    // MARK: - 23~24. 긴 문자열

    func testM23_aLongDisplayNameStaysReadable() {
        let app = openMy(["-VFUITestTeamID", "samsung-lions",
                          "-VFUITestStadiumID", "daegu-lions",
                          "-VFUITestDisplayName",
                          "야구를정말사랑하는아주긴이름을가진사용자입니다"])
        let name = node(app, "profile.name")
        XCTAssertTrue(waits(name), "긴 이름이 사라졌다")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(name.frame.maxX, window.maxX + 0.5,
                                 "긴 이름이 화면 밖으로 나갔다 — \(name.frame)")
        XCTAssertGreaterThan(name.frame.height, 0, "긴 이름이 높이 0으로 접혔다")
    }

    func testM24_aLongTeamNameStaysInsideTheScreen() {
        let app = populated()
        let team = node(app, "profile.team")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(team.frame.maxX, window.maxX + 0.5,
                                 "팀 칩이 화면 밖으로 나갔다 — \(team.frame)")
    }

    // MARK: - 25. 여는 것만으로는 아무것도 쓰지 않는다

    func testM25_openingProfileWritesNothing() {
        let app = populated()
        let teamBefore = node(app, "profile.team").label
        let nameBefore = node(app, "profile.name").label
        // 다른 탭을 들렀다 온다.
        app.buttons["tab.home"].tap()
        XCTAssertTrue(waits(node(app, "screen.home")))
        app.buttons["tab.my"].tap()
        XCTAssertTrue(waits(node(app, "profile.root")))
        XCTAssertEqual(node(app, "profile.team").label, teamBefore, "여닫는 것만으로 팀이 바뀌었다")
        XCTAssertEqual(node(app, "profile.name").label, nameBefore,
                       "여닫는 것만으로 이름이 바뀌었다")
    }
}
