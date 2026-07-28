import Foundation
import Observation

/// Pencil `04_Onboarding` 프레임 순서.
enum OnboardingStep: String, CaseIterable, Hashable {
    case welcome
    case overview
    case selectTeam
    case selectStadium
    case complete

    var accessibilityIdentifier: String { "onboarding.\(rawValue)" }
}

/// 온보딩 진행 상태.
///
/// 팀과 구장은 둘 다 필수다. 건너뛰기가 없고, 두 값이 모두 유효해야 완료된다.
@MainActor
@Observable
final class OnboardingViewModel {
    private(set) var steps: [OnboardingStep]
    private(set) var stepIndex = 0
    var selectedTeamID: String?
    var selectedStadiumID: String?
    /// 저장 실패 시 보여줄 문구. Pencil `Onboarding_Error_SaveFailed`.
    private(set) var saveErrorMessage: String?

    /// 저장된 상태에 따라 필요한 단계만 구성한다.
    init(entry: OnboardingEntry, existingTeamID: String? = nil, existingStadiumID: String? = nil) {
        selectedTeamID = existingTeamID
        selectedStadiumID = existingStadiumID
        switch entry {
        case .firstRun:
            steps = [.welcome, .overview, .selectTeam, .selectStadium, .complete]
        case .repairStadium:
            // 기존 사용자: 이미 고른 팀은 다시 묻지 않는다.
            steps = [.selectStadium, .complete]
        case .repairTeam:
            steps = [.selectTeam, .complete]
        case .completed:
            steps = []
        }
    }

    var currentStep: OnboardingStep? {
        guard steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    var isFirstStep: Bool { stepIndex == 0 }

    var progress: (current: Int, total: Int) {
        (min(stepIndex + 1, steps.count), steps.count)
    }

    // MARK: - 검증

    var isTeamSelectionValid: Bool {
        KBOSeed.team(id: selectedTeamID) != nil
    }

    var isStadiumSelectionValid: Bool {
        KBOStadiumSeed.isValid(id: selectedStadiumID)
    }

    /// 지금 단계에서 다음으로 넘어갈 수 있는지. 필수 선택이 비면 false다.
    var canAdvance: Bool {
        switch currentStep {
        case .selectTeam: isTeamSelectionValid
        case .selectStadium: isStadiumSelectionValid
        case .welcome, .overview, .complete: true
        case nil: false
        }
    }

    /// 두 값이 모두 유효할 때만 완료할 수 있다.
    var canComplete: Bool {
        isTeamSelectionValid && isStadiumSelectionValid
    }

    // MARK: - 이동

    func advance() {
        guard canAdvance else { return }
        stepIndex = min(stepIndex + 1, max(steps.count - 1, 0))
    }

    /// 뒤로 간다. 이미 고른 값은 그대로 남는다.
    func goBack() {
        stepIndex = max(stepIndex - 1, 0)
    }

    func selectTeam(_ teamID: String) {
        selectedTeamID = teamID
        saveErrorMessage = nil
        // 팀을 바꿔도 이미 고른 구장을 말없이 갈아치우지 않는다.
    }

    func selectStadium(_ stadiumID: String) {
        selectedStadiumID = stadiumID
        saveErrorMessage = nil
    }

    /// 팀에 맞춘 추천 구장. 목록 맨 앞에 놓기만 하고 자동 선택하지 않는다.
    var recommendedStadium: KBOStadium? {
        KBOStadiumSeed.recommendedStadium(forTeamID: selectedTeamID)
    }

    var orderedStadiums: [KBOStadium] {
        KBOStadiumSeed.ordered(recommendedFor: selectedTeamID)
    }

    // MARK: - 저장

    @discardableResult
    func complete(preferences: UserPreferencesStore) -> Bool {
        guard canComplete else {
            saveErrorMessage = "응원 팀과 주 관람 구장을 모두 선택해 주세요."
            return false
        }
        let saved = preferences.completeOnboarding(
            favoriteTeamID: selectedTeamID,
            primaryStadiumID: selectedStadiumID
        )
        saveErrorMessage = saved ? nil : "설정을 저장하지 못했어요. 잠시 후 다시 시도해 주세요."
        return saved
    }

    func clearSaveError() {
        saveErrorMessage = nil
    }
}
