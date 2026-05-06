import SwiftUI

@MainActor
final class UserPreferencesStore: ObservableObject {
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let favoriteTeamID = "favoriteTeamID"
        static let teamThemeEnabled = "teamThemeEnabled"
        static let userDisplayName = "userDisplayName"
    }

    private let defaults: UserDefaults

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    @Published var favoriteTeamID: String? {
        didSet {
            if let favoriteTeamID {
                defaults.set(favoriteTeamID, forKey: Key.favoriteTeamID)
            } else {
                defaults.removeObject(forKey: Key.favoriteTeamID)
            }
        }
    }

    @Published var teamThemeEnabled: Bool {
        didSet { defaults.set(teamThemeEnabled, forKey: Key.teamThemeEnabled) }
    }

    @Published var userDisplayName: String? {
        didSet {
            if let userDisplayName {
                defaults.set(userDisplayName, forKey: Key.userDisplayName)
            } else {
                defaults.removeObject(forKey: Key.userDisplayName)
            }
        }
    }

    var favoriteTeam: KBOTeam? {
        KBOSeed.team(id: favoriteTeamID)
    }

    var favoriteTeamName: String {
        favoriteTeam?.name ?? "선택 안 함"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        favoriteTeamID = KBOSeed.normalizedTeamID(defaults.string(forKey: Key.favoriteTeamID))
        teamThemeEnabled = defaults.object(forKey: Key.teamThemeEnabled) as? Bool ?? true
        userDisplayName = defaults.string(forKey: Key.userDisplayName)
    }

    static func preview(
        suiteName: String,
        hasCompletedOnboarding: Bool = true,
        favoriteTeamID: String? = nil,
        teamThemeEnabled: Bool = true
    ) -> UserPreferencesStore {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding)
        defaults.set(teamThemeEnabled, forKey: Key.teamThemeEnabled)
        if let favoriteTeamID {
            defaults.set(favoriteTeamID, forKey: Key.favoriteTeamID)
        } else {
            defaults.removeObject(forKey: Key.favoriteTeamID)
        }
        return UserPreferencesStore(defaults: defaults)
    }

    func completeOnboarding(favoriteTeamID: String?) {
        self.favoriteTeamID = favoriteTeamID
        hasCompletedOnboarding = true
    }
}
