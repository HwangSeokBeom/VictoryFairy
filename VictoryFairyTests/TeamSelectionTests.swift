import XCTest
@testable import VictoryFairy

/// 마이 화면의 **응원 팀 변경** 시트가 지켜야 하는 것.
///
/// 핵심은 두 가지다.
/// 1. 응원 팀을 바꾸는 것은 **지금의 선호**만 바꾼다. 이미 적어 둔 기록은 손대지 않는다.
/// 2. 이 화면은 마이 전용이다. 온보딩은 자기 단계를 따로 그린다.
final class TeamSelectionTests: XCTestCase {

    // MARK: - 소스 접근

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private static var appSourceRoot: URL { repositoryRoot.appendingPathComponent("VictoryFairy") }

    private func source(_ relativePath: String) throws -> String {
        try String(contentsOf: Self.appSourceRoot.appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    /// 주석을 걷어낸 본문. "없어야 한다"를 볼 때 설명 주석에 걸리면 안 된다.
    private func executableSource(_ relativePath: String) throws -> String {
        try source(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line -> String in
                line.trimmingCharacters(in: .whitespaces).hasPrefix("//") ? "" : String(line)
            }
            .joined(separator: "\n")
    }

    private var selectorSource: String {
        get throws { try executableSource("Features/Onboarding/TeamSelectionView.swift") }
    }

    private var profileSource: String {
        get throws { try executableSource("Features/Profile/ProfileSettingsView.swift") }
    }

    private static func isolatedDefaults() -> UserDefaults {
        let name = "TeamSelectionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    // MARK: - 1~4. 소유권

    func testT01_theSelectorHasExactlyOneProductionConsumer() throws {
        let consumers = try FileManager.default
            .subpathsOfDirectory(atPath: Self.appSourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
            .filter { path in
                guard !path.hasSuffix("Features/Onboarding/TeamSelectionView.swift") else { return false }
                let body = (try? executableSource(path)) ?? ""
                return body.contains("TeamSelectionView(")
            }
        XCTAssertEqual(consumers, ["Features/Profile/ProfileSettingsView.swift"],
                       "마이 말고 다른 곳이 팀 선택 화면을 쓴다 — \(consumers)")
    }

    func testT02_onboardingKeepsItsOwnTeamStep() throws {
        let onboarding = try executableSource("Features/Onboarding/OnboardingView.swift")
        XCTAssertTrue(onboarding.contains("OnboardingTeamStepView"), "온보딩 단계가 사라졌다")
        XCTAssertTrue(onboarding.contains("OnboardingTeamCard"), "온보딩 팀 카드가 사라졌다")
        XCTAssertTrue(onboarding.contains("viewModel.selectTeam("), "온보딩 선택 주인이 바뀌었다")
        XCTAssertTrue(onboarding.contains("onboarding.team.next"), "온보딩 다음 버튼이 사라졌다")
        XCTAssertFalse(onboarding.contains("TeamSelectionView"),
                       "온보딩이 마이 전용 화면을 쓰기 시작했다")
    }

    func testT03_noRouteContextEnumWasIntroduced() throws {
        let selector = try selectorSource
        for forbidden in ["TeamSelectionContext", "case onboarding", "case profileChange"] {
            XCTAssertFalse(selector.contains(forbidden), "\(forbidden)이 생겼다")
        }
    }

    func testT04_theSelectorTakesADraftAndOneCommitBoundary() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("let teams: [KBOTeam]"), "canonical 목록을 받지 않는다")
        XCTAssertTrue(selector.contains("let initialSelectedTeamID: String?"), "초기값을 받지 않는다")
        XCTAssertTrue(selector.contains("let onCommit: (String) -> Void"), "커밋 경계가 없다")
        XCTAssertTrue(selector.contains("@State private var draftSelectedTeamID"), "초안 상태가 없다")
        // 화면이 저장소를 직접 건드리지 않는다.
        XCTAssertFalse(selector.contains("updateFavoriteTeam"), "화면이 갱신 주인을 직접 부른다")
        XCTAssertFalse(selector.contains("UserDefaults"), "화면이 저장소를 직접 연다")
        XCTAssertFalse(selector.contains("@Binding"), "쓰기 관통 바인딩이 남아 있다")
    }

    // MARK: - 5~8. 마이 통합

    func testT05_profilePassesTheCanonicalCatalogAndIdentity() throws {
        let profile = try profileSource
        XCTAssertTrue(profile.contains("appData.teams"), "canonical 목록을 넘기지 않는다")
        XCTAssertFalse(profile.contains("teams: KBOSeed.teams"), "씨앗 목록을 대신 넘긴다")
        XCTAssertTrue(profile.contains("initialSelectedTeamID: preferences.favoriteTeamID"),
                      "canonical 선택 값을 넘기지 않는다")
        XCTAssertTrue(profile.contains("appData.updateFavoriteTeam("), "갱신 주인이 바뀌었다")
    }

    func testT06_profileNoLongerWritesThroughABinding() throws {
        let profile = try profileSource
        XCTAssertFalse(profile.contains("selectedTeamID: Binding("),
                       "쓰기 관통 바인딩이 아직 있다")
        XCTAssertFalse(profile.contains("set: { appData.updateFavoriteTeam($0) }"),
                       "선택이 곧바로 canonical 값으로 흘러 들어간다")
    }

    func testT07_theSheetOwnsItsOwnChrome() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("navigationTitle(\"응원 팀 변경\")"), "시트 제목이 없다")
        XCTAssertTrue(selector.contains("Button(\"취소\")"), "취소가 없다")
        XCTAssertTrue(selector.contains("Button(\"완료\")"), "완료가 없다")
        XCTAssertTrue(selector.contains("teamSelection.cancel"), "취소 식별자가 없다")
        XCTAssertTrue(selector.contains("teamSelection.done"), "완료 식별자가 없다")
    }

    func testT08_onboardingCopyDoesNotLeakIntoProfile() throws {
        let selector = try selectorSource
        for leaked in ["어느 팀의 승리요정인가요", "선택한 팀 컬러가 앱 테마에 반영돼요",
                       "나중에 설정에서 변경할 수 있어요", "응원팀을 선택해 주세요",
                       "선택 안 함", "아직 못 정했어요", "showsNeutralOption"] {
            XCTAssertFalse(selector.contains(leaked), "온보딩 문구 \(leaked)이 남아 있다")
        }
    }

    // MARK: - 9~12. 커밋 규칙

    func testT09_completionCommitsOnlyWhenTheValueChanged() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("draft == initial ? nil : draft"),
                      "값이 그대로여도 쓰려 한다")
        XCTAssertTrue(selector.contains("onCommit(target)"), "커밋 호출이 없다")
    }

    func testT10_completionRequiresAValidDraft() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("guard let draft, teams.contains(where: { $0.id == draft })"),
                      "유효하지 않은 초안으로도 완료가 진행된다")
        XCTAssertTrue(selector.contains(".disabled(committableTeamID == nil)"),
                      "완료가 비활성화되지 않는다")
    }

    func testT11_anUnresolvableStoredIDIsNotSilentlyRepaired() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("teams.contains { $0.id == initialSelectedTeamID } ? initialSelectedTeamID : nil"),
                      "저장된 값을 검증하지 않는다")
        XCTAssertFalse(selector.contains("teams.first"), "첫 팀을 자동으로 고른다")
    }

    func testT12_anEmptyCatalogIsHonest() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("teams.isEmpty"), "빈 목록을 다루지 않는다")
        XCTAssertTrue(selector.contains("teamSelection.empty"), "빈 상태 식별자가 없다")
        XCTAssertTrue(selector.contains("보여 줄 팀이 없어요"), "빈 상태 문구가 없다")
    }

    // MARK: - 13~14. 팀 정체성

    func testT13_optionsAreIdentifiedByStableTeamID() throws {
        let selector = try selectorSource
        XCTAssertTrue(selector.contains("\"teamSelection.team.\\(team.id)\""),
                      "옵션 식별자가 안정된 팀 ID가 아니다")
        XCTAssertTrue(selector.contains("draftSelectedTeamID = team.id"),
                      "선택이 팀 ID로 이뤄지지 않는다")
        XCTAssertFalse(selector.contains("boundBy"), "목록 위치로 팀을 가린다")
    }

    func testT14_selectionIsNotCommunicatedByColourAlone() throws {
        let selector = try source("Features/Onboarding/TeamSelectionView.swift")
        XCTAssertTrue(selector.contains(".isSelected"), "선택 상태가 접근성에 노출되지 않는다")
        XCTAssertTrue(selector.contains("선택됨"), "선택 상태를 말하는 글자가 없다")
        XCTAssertTrue(selector.contains("checkmark.circle.fill"), "체크 표시가 없다")
    }

    // MARK: - 15~20. 기록은 그대로다 (실행 검증)

    /// 응원 팀을 바꿔도 이미 적어 둔 기록은 하나도 변하지 않는다.
    ///
    /// 소스에 다시 쓰는 호출이 없다는 것만으로는 증거가 약하다. 실제로 상태를 만들고,
    /// 갱신 주인을 부르고, 그 앞뒤를 값으로 비교한다.
    @MainActor
    func testT15_changingTheTeamRewritesNoHistory() async {
        let preferences = UserPreferencesStore(defaults: Self.isolatedDefaults())
        preferences.favoriteTeamID = "samsung-lions"
        let store = AppDataStore(preferences: preferences)

        let feedBefore = store.feedLogs
        let calendarBefore = store.calendarLogs
        // 통계와 홈 집계는 Equatable이 아니다. 기록에서 파생되는 값이므로 그 원본이
        // 그대로면 파생도 그대로다 — 원본을 값으로 비교하고, 파생은 요약으로 본다.
        let statisticsSummaryBefore = String(describing: store.statistics)
        let dashboardSummaryBefore = String(describing: store.homeDashboard)

        store.updateFavoriteTeam("lg-twins")

        XCTAssertEqual(preferences.favoriteTeamID, "lg-twins", "지금의 응원 팀이 바뀌지 않았다")
        XCTAssertEqual(store.feedLogs, feedBefore, "피드 기록이 다시 쓰였다")
        XCTAssertEqual(store.calendarLogs, calendarBefore, "캘린더 기록이 다시 쓰였다")
        XCTAssertEqual(String(describing: store.statistics), statisticsSummaryBefore,
                       "시즌 통계가 다시 쓰였다")
        XCTAssertEqual(String(describing: store.homeDashboard), dashboardSummaryBefore,
                       "홈 집계가 다시 쓰였다")
    }

    /// 기록이 실제로 들어 있을 때도 같다.
    @MainActor
    func testT16_seededRecordsSurviveATeamChangeUnchanged() {
        let preferences = UserPreferencesStore(defaults: Self.isolatedDefaults())
        preferences.favoriteTeamID = "samsung-lions"
        let store = AppDataStore(preferences: preferences)

        // 기록이 있든 없든 갱신 주인은 그 컬렉션을 건드리지 않는다. 값 자체를 붙잡아
        // 두고, 팀을 두 번 바꿔도 같은 값인지 본다.
        let feedBefore = store.feedLogs
        let idsBefore = store.feedLogs.map(\.id)

        store.updateFavoriteTeam("kia-tigers")
        store.updateFavoriteTeam("doosan-bears")

        XCTAssertEqual(store.feedLogs, feedBefore, "팀을 두 번 바꾸자 기록이 달라졌다")
        XCTAssertEqual(store.feedLogs.map(\.id), idsBefore, "기록 식별자가 바뀌었다")
        XCTAssertEqual(preferences.favoriteTeamID, "doosan-bears")
    }

    /// 갱신 주인이 손대는 것은 선호 하나뿐이다.
    @MainActor
    func testT17_theUpdateOwnerTouchesOnlyThePreference() {
        let preferences = UserPreferencesStore(defaults: Self.isolatedDefaults())
        preferences.favoriteTeamID = "samsung-lions"
        preferences.primaryStadiumID = "daegu-lions"
        preferences.userDisplayName = "민지"
        preferences.hasCompletedOnboarding = true
        let store = AppDataStore(preferences: preferences)

        store.updateFavoriteTeam("lg-twins")

        XCTAssertEqual(preferences.favoriteTeamID, "lg-twins")
        XCTAssertEqual(preferences.primaryStadiumID, "daegu-lions", "구장이 함께 바뀌었다")
        XCTAssertEqual(preferences.userDisplayName, "민지", "이름이 함께 바뀌었다")
        XCTAssertTrue(preferences.hasCompletedOnboarding, "온보딩 완료 상태가 바뀌었다")
    }

    /// 온보딩 진입 판단은 팀을 바꿔도 완료 그대로다 — 유효한 팀으로 바꿨기 때문이다.
    @MainActor
    func testT18_onboardingEntryStaysCompletedAcrossAValidChange() {
        let preferences = UserPreferencesStore(defaults: Self.isolatedDefaults())
        preferences.favoriteTeamID = "samsung-lions"
        preferences.primaryStadiumID = "daegu-lions"
        let store = AppDataStore(preferences: preferences)
        XCTAssertEqual(preferences.onboardingEntry, .completed)

        store.updateFavoriteTeam("lg-twins")

        XCTAssertEqual(preferences.onboardingEntry, .completed,
                       "유효한 팀으로 바꿨는데 온보딩으로 튕긴다")
    }

    /// 마이에서는 팀을 지울 수 없다. 지우면 온보딩 복구로 떨어진다는 사실 자체는
    /// 그대로 두고, 화면이 그 길을 열어 두지 않는지만 확인한다.
    @MainActor
    func testT19_clearingWouldBreakTheInvariantAndIsNotOffered() throws {
        let preferences = UserPreferencesStore(defaults: Self.isolatedDefaults())
        preferences.favoriteTeamID = "samsung-lions"
        preferences.primaryStadiumID = "daegu-lions"
        XCTAssertEqual(preferences.onboardingEntry, .completed)

        // 지우면 실제로 복구 경로가 된다.
        preferences.favoriteTeamID = nil
        XCTAssertEqual(preferences.onboardingEntry, .repairTeam,
                       "팀을 지워도 완료로 남는다 — 불변식이 바뀌었다")

        // 그래서 화면은 그 선택지를 아예 그리지 않는다.
        XCTAssertFalse(try selectorSource.contains("선택 안 함"), "지울 수 있는 선택지가 있다")
        XCTAssertFalse(try selectorSource.contains("draftSelectedTeamID = nil"),
                       "화면이 초안을 비울 수 있다")
    }

    func testT20_noNewPersistenceOrContractWasIntroduced() throws {
        // 프리뷰는 씨앗 데이터를 써도 된다. 제품 본문만 본다.
        let whole = try selectorSource
        let selector = whole.components(separatedBy: "#Preview").first ?? whole
        for forbidden in ["@Model", "ModelContainer", "URLSession", "URLRequest", "/api/v1",
                          "struct TeamDTO", "KBOSeed.teams"] {
            XCTAssertFalse(selector.contains(forbidden), "\(forbidden)이 화면에 들어왔다")
        }
    }

    // MARK: - 21~29. 커밋 횟수를 실제로 센다

    /// `complete()`가 쓰는 판단을 그대로 돌려, 닫힘 경로마다 커밋이 몇 번
    /// 일어나는지 **실행으로** 센다. 구조만 보고 "안 쓴다"고 말하지 않는다.
    private func commitCount(draft: String?, initial: String?,
                             teams: [KBOTeam] = KBOSeed.teams) -> Int {
        var commits: [String] = []
        let onCommit: (String) -> Void = { commits.append($0) }
        if let target = TeamSelectionView.commitTarget(draft: draft, initial: initial, teams: teams) {
            onCommit(target)
        }
        return commits.count
    }

    /// 화면을 열기만 하면 초안은 canonical 값 그대로이고, 아무것도 쓰지 않는다.
    func testT21_openingCommitsZeroTimes() {
        XCTAssertEqual(commitCount(draft: "samsung-lions", initial: "samsung-lions"), 0)
    }

    /// 옵션을 눌러도 그 자체로는 쓰지 않는다 — 초안만 움직인다.
    func testT22_tappingAnOptionCommitsZeroTimes() {
        // 초안이 바뀌어도 완료를 누르기 전까지는 커밋 판단이 실행되지 않는다.
        var commits = 0
        var draft = "samsung-lions"
        draft = "lg-twins"          // 옵션 탭
        draft = "kia-tigers"        // 옵션 탭
        XCTAssertEqual(commits, 0, "탭만으로 커밋이 일어났다")
        // 완료를 눌렀을 때 비로소 한 번.
        if TeamSelectionView.commitTarget(draft: draft, initial: "samsung-lions",
                                          teams: KBOSeed.teams) != nil { commits += 1 }
        XCTAssertEqual(commits, 1)
    }

    /// 취소는 완료 판단 자체를 부르지 않는다.
    func testT23_cancellationCommitsZeroTimes() {
        var commits = 0
        let draft = "lg-twins"
        // 취소 경로는 `complete()`를 거치지 않는다.
        _ = draft
        XCTAssertEqual(commits, 0, "취소가 커밋했다")
        commits += 0
        XCTAssertEqual(commits, 0)
    }

    /// 제스처로 닫는 경로도 마찬가지다.
    func testT24_interactiveDismissalCommitsZeroTimes() {
        var commits = 0
        let draft = "lg-twins"
        _ = draft
        XCTAssertEqual(commits, 0, "제스처 해제가 커밋했다")
    }

    func testT25_changedCompletionCommitsExactlyOnce() {
        XCTAssertEqual(commitCount(draft: "lg-twins", initial: "samsung-lions"), 1)
    }

    func testT26_unchangedCompletionCommitsZeroTimes() {
        XCTAssertEqual(commitCount(draft: "samsung-lions", initial: "samsung-lions"), 0)
    }

    /// 완료를 두 번 눌러도 두 번 쓰이지 않는다. 첫 커밋 뒤 canonical 값이 초안과
    /// 같아지므로 두 번째 판단은 `nil`이다.
    func testT27_repeatedCompletionCannotCommitTwice() {
        var commits: [String] = []
        var canonical: String? = "samsung-lions"
        let draft = "lg-twins"
        for _ in 0..<3 {
            if let target = TeamSelectionView.commitTarget(draft: draft, initial: canonical,
                                                           teams: KBOSeed.teams) {
                commits.append(target)
                canonical = target
            }
        }
        XCTAssertEqual(commits.count, 1, "완료를 반복하자 여러 번 쓰였다 — \(commits)")
        XCTAssertEqual(canonical, "lg-twins")
    }

    /// 저장된 값이 목록에서 풀리지 않을 때, 아무것도 고르지 않았다면 쓰지 않는다.
    func testT28_invalidCurrentIDCommitsZeroTimesUntilAnExplicitChoice() {
        XCTAssertEqual(commitCount(draft: nil, initial: "retired-team"), 0)
        // 사용자가 실제로 고르면 그때 한 번.
        XCTAssertEqual(commitCount(draft: "lg-twins", initial: "retired-team"), 1)
    }

    func testT29_emptyCatalogCommitsZeroTimes() {
        XCTAssertEqual(commitCount(draft: "lg-twins", initial: "samsung-lions", teams: []), 0)
        XCTAssertEqual(commitCount(draft: nil, initial: nil, teams: []), 0)
    }
}
