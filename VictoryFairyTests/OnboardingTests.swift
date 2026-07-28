import XCTest
@testable import VictoryFairy

/// 온보딩 필수 선택과 기존 사용자 마이그레이션을 확인한다.
@MainActor
final class OnboardingTests: XCTestCase {

    private var suiteIndex = 0

    /// 테스트마다 격리된 UserDefaults suite를 쓴다.
    private func makeStore(
        hasCompletedOnboarding: Bool = false,
        favoriteTeamID: String? = nil,
        primaryStadiumID: String? = nil
    ) -> UserPreferencesStore {
        suiteIndex += 1
        return UserPreferencesStore.preview(
            suiteName: "OnboardingTests.\(name).\(suiteIndex)",
            hasCompletedOnboarding: hasCompletedOnboarding,
            favoriteTeamID: favoriteTeamID,
            primaryStadiumID: primaryStadiumID
        )
    }

    // MARK: - 구장 모델

    func testStadiumSeedCoversEveryTeamHomeGround() {
        // 10개 팀, 잠실을 공유하므로 고유 구장은 9개.
        XCTAssertEqual(KBOStadiumSeed.all.count, 9)
        for team in KBOSeed.teams where team.active {
            let stadium = KBOStadiumSeed.recommendedStadium(forTeamID: team.id)
            XCTAssertNotNil(stadium, "\(team.id)의 홈 구장을 찾지 못했다")
            XCTAssertEqual(stadium?.name, team.homeStadiumName, "\(team.id) 구장 이름이 팀 데이터와 다르다")
        }
    }

    func testStadiumIdentifiersAreStableAndNotKoreanNames() {
        for stadium in KBOStadiumSeed.all {
            XCTAssertFalse(stadium.id.isEmpty)
            // 저장되는 식별자는 보이는 한국어 이름이 아니어야 한다.
            XCTAssertTrue(
                stadium.id.unicodeScalars.allSatisfy { $0.isASCII },
                "\(stadium.id)는 ASCII 식별자여야 한다"
            )
            XCTAssertNotEqual(stadium.id, stadium.name)
            XCTAssertFalse(stadium.name.isEmpty)
            XCTAssertFalse(stadium.shortName.isEmpty)
        }
        XCTAssertEqual(Set(KBOStadiumSeed.all.map(\.id)).count, KBOStadiumSeed.all.count, "구장 ID가 중복된다")
    }

    func testJamsilIsSharedByTwoTeams() {
        let jamsil = KBOStadiumSeed.stadium(id: "jamsil")
        XCTAssertEqual(jamsil?.homeTeamIDs.sorted(), ["doosan-bears", "lg-twins"])
    }

    func testRecommendedStadiumIsOrderedFirstButNotPreselected() {
        let ordered = KBOStadiumSeed.ordered(recommendedFor: "kia-tigers")
        XCTAssertEqual(ordered.first?.id, "gwangju-kia", "추천 구장이 맨 앞에 와야 한다")
        XCTAssertEqual(ordered.count, KBOStadiumSeed.all.count, "추천 때문에 구장이 사라지면 안 된다")

        // 추천은 정렬만 바꿀 뿐, 선택 상태를 만들지 않는다.
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.selectTeam("kia-tigers")
        XCTAssertNil(viewModel.selectedStadiumID, "팀 선택이 구장을 자동 선택하면 안 된다")
        XCTAssertFalse(viewModel.isStadiumSelectionValid)
    }

    // MARK: - 필수 선택

    func testFirstRunRequiresBothTeamAndStadium() {
        let viewModel = OnboardingViewModel(entry: .firstRun)
        XCTAssertEqual(viewModel.steps, [.welcome, .overview, .selectTeam, .selectStadium, .complete])
        XCTAssertFalse(viewModel.canComplete, "아무것도 고르지 않았는데 완료 가능하면 안 된다")
    }

    func testCannotAdvancePastTeamStepWithoutSelection() {
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.advance()  // welcome -> overview
        viewModel.advance()  // overview -> selectTeam
        XCTAssertEqual(viewModel.currentStep, .selectTeam)
        XCTAssertFalse(viewModel.canAdvance, "팀을 고르지 않으면 다음으로 갈 수 없어야 한다")

        viewModel.advance()
        XCTAssertEqual(viewModel.currentStep, .selectTeam, "선택 없이 단계가 넘어갔다")

        viewModel.selectTeam("lg-twins")
        XCTAssertTrue(viewModel.canAdvance)
        viewModel.advance()
        XCTAssertEqual(viewModel.currentStep, .selectStadium)
    }

    func testCannotAdvancePastStadiumStepWithoutSelection() {
        let viewModel = OnboardingViewModel(entry: .repairStadium, existingTeamID: "lg-twins")
        XCTAssertEqual(viewModel.currentStep, .selectStadium)
        XCTAssertFalse(viewModel.canAdvance)
        viewModel.advance()
        XCTAssertEqual(viewModel.currentStep, .selectStadium)

        viewModel.selectStadium("jamsil")
        XCTAssertTrue(viewModel.canAdvance)
    }

    func testCompletionFailsWhenEitherValueIsMissing() {
        let store = makeStore()

        let noTeam = OnboardingViewModel(entry: .firstRun)
        noTeam.selectStadium("jamsil")
        XCTAssertFalse(noTeam.complete(preferences: store), "팀 없이 완료되면 안 된다")
        XCTAssertFalse(store.hasCompletedOnboarding)

        let noStadium = OnboardingViewModel(entry: .firstRun)
        noStadium.selectTeam("lg-twins")
        XCTAssertFalse(noStadium.complete(preferences: store), "구장 없이 완료되면 안 된다")
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNotNil(noStadium.saveErrorMessage, "실패 사유가 사용자에게 전달돼야 한다")
    }

    func testCompletionPersistsBothSelections() {
        let store = makeStore()
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.selectTeam("hanwha-eagles")
        viewModel.selectStadium("daejeon-hanwha")

        XCTAssertTrue(viewModel.complete(preferences: store))
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.favoriteTeamID, "hanwha-eagles")
        XCTAssertEqual(store.primaryStadiumID, "daejeon-hanwha")
        XCTAssertEqual(store.onboardingSchemaVersion, UserPreferencesStore.currentOnboardingSchemaVersion)
        XCTAssertEqual(store.onboardingEntry, .completed)
    }

    /// 저장된 값은 보이는 한국어 이름이 아니라 안정적인 ID여야 한다.
    func testPersistedValuesAreStableIdentifiers() {
        let store = makeStore()
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.selectTeam("nc-dinos")
        viewModel.selectStadium("changwon-nc")
        XCTAssertTrue(viewModel.complete(preferences: store))

        XCTAssertEqual(store.favoriteTeamID, "nc-dinos")
        XCTAssertNotEqual(store.favoriteTeamID, "NC 다이노스")
        XCTAssertNotEqual(store.primaryStadiumID, "창원NC파크")
    }

    // MARK: - 재개와 마이그레이션

    func testFreshInstallEntersFullOnboarding() {
        let store = makeStore()
        XCTAssertEqual(store.onboardingEntry, .firstRun)
    }

    /// 기존 사용자: 팀은 있고 구장이 없다. 구장 단계만 받아야 한다.
    func testExistingUserWithTeamOnlyEntersStadiumRepairOnly() {
        let store = makeStore(hasCompletedOnboarding: true, favoriteTeamID: "lg-twins")
        XCTAssertEqual(store.onboardingEntry, .repairStadium)

        let viewModel = OnboardingViewModel(
            entry: store.onboardingEntry,
            existingTeamID: store.favoriteTeamID,
            existingStadiumID: store.primaryStadiumID
        )
        XCTAssertEqual(viewModel.steps, [.selectStadium, .complete], "기존 사용자에게 팀을 다시 묻고 있다")
        XCTAssertEqual(viewModel.selectedTeamID, "lg-twins", "이미 고른 팀이 보존되지 않았다")
        XCTAssertTrue(viewModel.isTeamSelectionValid)
    }

    /// 두 값이 모두 유효한 기존 사용자는 온보딩을 다시 보지 않는다.
    func testExistingUserWithBothValuesIsMigratedToCompleted() {
        let store = makeStore(favoriteTeamID: "kt-wiz", primaryStadiumID: "suwon-kt")
        XCTAssertEqual(store.onboardingEntry, .completed)
        XCTAssertTrue(store.migrateOnboardingIfSatisfied())
        XCTAssertTrue(store.hasCompletedOnboarding)

        let viewModel = OnboardingViewModel(entry: store.onboardingEntry)
        XCTAssertTrue(viewModel.steps.isEmpty, "완료된 사용자에게 온보딩 단계가 남아 있다")
    }

    /// 저장된 구장 ID가 더 이상 유효하지 않으면 그 단계만 다시 받는다.
    func testInvalidStoredStadiumRoutesToRepairWithoutLosingTheTeam() {
        let store = makeStore(
            hasCompletedOnboarding: true,
            favoriteTeamID: "samsung-lions",
            primaryStadiumID: "no-such-stadium"
        )
        XCTAssertNil(store.primaryStadiumID, "유효하지 않은 구장 ID는 버려야 한다")
        XCTAssertEqual(store.favoriteTeamID, "samsung-lions", "구장이 잘못됐다고 팀까지 잃으면 안 된다")
        XCTAssertEqual(store.onboardingEntry, .repairStadium)
    }

    func testInvalidStoredTeamRoutesToTeamRepairOnly() {
        let store = makeStore(
            hasCompletedOnboarding: true,
            favoriteTeamID: "no-such-team",
            primaryStadiumID: "sajik"
        )
        XCTAssertEqual(store.onboardingEntry, .repairTeam)
        XCTAssertEqual(store.primaryStadiumID, "sajik", "팀이 잘못됐다고 구장까지 잃으면 안 된다")
    }

    /// 뒤로 갔다 와도 이미 고른 값이 남아야 한다.
    func testSelectionsSurviveBackNavigation() {
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.advance(); viewModel.advance()
        viewModel.selectTeam("lotte-giants")
        viewModel.advance()
        viewModel.selectStadium("sajik")
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, .selectTeam)
        XCTAssertEqual(viewModel.selectedTeamID, "lotte-giants")
        viewModel.advance()
        XCTAssertEqual(viewModel.selectedStadiumID, "sajik", "뒤로 갔다 오니 구장 선택이 사라졌다")
    }

    // MARK: - 독립성

    /// 팀을 바꿔도 구장이 말없이 바뀌면 안 된다.
    func testChangingTeamDoesNotSilentlyReplaceStadium() {
        let viewModel = OnboardingViewModel(entry: .firstRun)
        viewModel.selectTeam("lg-twins")
        viewModel.selectStadium("gocheok")
        viewModel.selectTeam("kia-tigers")
        XCTAssertEqual(viewModel.selectedStadiumID, "gocheok", "팀 변경이 구장을 덮어썼다")

        let store = makeStore(favoriteTeamID: "lg-twins", primaryStadiumID: "gocheok")
        store.setFavoriteTeam("kia-tigers")
        XCTAssertEqual(store.primaryStadiumID, "gocheok", "저장소에서도 구장이 유지돼야 한다")
    }

    /// 구장을 바꿔도 팀은 그대로여야 한다.
    func testChangingStadiumDoesNotAlterTeam() {
        let store = makeStore(favoriteTeamID: "doosan-bears", primaryStadiumID: "jamsil")
        store.setPrimaryStadium("gocheok")
        XCTAssertEqual(store.primaryStadiumID, "gocheok")
        XCTAssertEqual(store.favoriteTeamID, "doosan-bears")
    }

    /// 유효하지 않은 구장으로는 바꿀 수 없다.
    func testSettingAnUnknownStadiumIsRejected() {
        let store = makeStore(favoriteTeamID: "kiwoom-heroes", primaryStadiumID: "gocheok")
        store.setPrimaryStadium("not-a-stadium")
        XCTAssertEqual(store.primaryStadiumID, "gocheok", "알 수 없는 구장이 저장됐다")
    }

    /// 건너뛰기 경로가 존재하지 않는지 확인한다.
    /// 값 없이 완료를 호출해도 저장되지 않아야 한다.
    func testThereIsNoSkipPath() {
        let store = makeStore()
        XCTAssertFalse(store.completeOnboarding(favoriteTeamID: nil, primaryStadiumID: nil))
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertFalse(store.completeOnboarding(favoriteTeamID: "lg-twins", primaryStadiumID: nil))
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    /// 온보딩 단계 식별자는 UI 테스트가 참조하므로 안정적이어야 한다.
    func testOnboardingStepIdentifiersAreStable() {
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.accessibilityIdentifier),
            [
                "onboarding.welcome",
                "onboarding.overview",
                "onboarding.selectTeam",
                "onboarding.selectStadium",
                "onboarding.complete"
            ]
        )
    }
}
