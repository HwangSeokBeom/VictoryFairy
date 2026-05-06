import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var pageIndex = 0
    var selectedTeamID: String?

    func moveNext() {
        pageIndex = min(pageIndex + 1, 2)
    }

    func complete(preferences: UserPreferencesStore) {
        preferences.completeOnboarding(favoriteTeamID: selectedTeamID)
    }

    func skip(preferences: UserPreferencesStore) {
        selectedTeamID = nil
        preferences.completeOnboarding(favoriteTeamID: nil)
    }
}
