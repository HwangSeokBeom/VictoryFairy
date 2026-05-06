import Combine
import SwiftUI

@MainActor
final class AppThemeProvider: ObservableObject {
    @Published private(set) var theme: TeamTheme

    private let preferences: UserPreferencesStore
    private let appData: AppDataStore
    private var cancellables = Set<AnyCancellable>()

    init(preferences: UserPreferencesStore, appData: AppDataStore) {
        self.preferences = preferences
        self.appData = appData
        theme = Self.makeTheme(
            favoriteTeamID: preferences.favoriteTeamID,
            teamThemeEnabled: preferences.teamThemeEnabled,
            teams: appData.teams
        )

        preferences.$favoriteTeamID
            .combineLatest(preferences.$teamThemeEnabled)
            .combineLatest(appData.$teams)
            .map { favoriteAndEnabled, teams in
                Self.makeTheme(
                    favoriteTeamID: favoriteAndEnabled.0,
                    teamThemeEnabled: favoriteAndEnabled.1,
                    teams: teams
                )
            }
            .sink { [weak self] theme in
                self?.theme = theme
            }
            .store(in: &cancellables)
    }

    private static func makeTheme(favoriteTeamID: String?, teamThemeEnabled: Bool, teams: [KBOTeam]) -> TeamTheme {
        guard teamThemeEnabled, let favoriteTeamID else {
            return .neutral
        }
        let team = teams.first { $0.id == favoriteTeamID && $0.active } ?? KBOSeed.team(id: favoriteTeamID)
        guard let team else { return .neutral }
        return TeamTheme(team: team)
    }
}
