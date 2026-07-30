import SwiftUI

@MainActor
final class UserPreferencesStore: ObservableObject {
    private enum Key {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let favoriteTeamID = "favoriteTeamID"
        static let teamThemeEnabled = "teamThemeEnabled"
        static let userDisplayName = "userDisplayName"
        static let selectedSeason = "selectedSeason"
        // 온보딩 확장분. 기존 키는 그대로 두고 새 키만 더한다.
        static let primaryStadiumID = "primaryStadiumID"
        static let hasSeenOverview = "hasSeenOnboardingOverview"
        static let onboardingSchemaVersion = "onboardingSchemaVersion"
    }

    /// 온보딩 저장 형식 버전. 값이 바뀌면 마이그레이션 분기를 추가한다.
    static let currentOnboardingSchemaVersion = 2

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

    @Published var selectedSeason: Int {
        didSet { defaults.set(selectedSeason, forKey: Key.selectedSeason) }
    }

    /// 주 관람 구장. 표시 이름이 아니라 안정적인 ID를 저장한다.
    @Published var primaryStadiumID: String? {
        didSet {
            if let primaryStadiumID {
                defaults.set(primaryStadiumID, forKey: Key.primaryStadiumID)
            } else {
                defaults.removeObject(forKey: Key.primaryStadiumID)
            }
        }
    }

    /// 앱 소개를 이미 봤는지. 기존 사용자에게 소개를 다시 보여주지 않기 위해 쓴다.
    @Published var hasSeenOnboardingOverview: Bool {
        didSet { defaults.set(hasSeenOnboardingOverview, forKey: Key.hasSeenOverview) }
    }

    private(set) var onboardingSchemaVersion: Int {
        didSet { defaults.set(onboardingSchemaVersion, forKey: Key.onboardingSchemaVersion) }
    }

    var favoriteTeam: KBOTeam? {
        KBOSeed.team(id: favoriteTeamID)
    }

    var primaryStadium: KBOStadium? {
        KBOStadiumSeed.stadium(id: primaryStadiumID)
    }

    var primaryStadiumName: String {
        primaryStadium?.name ?? "선택 안 함"
    }

    var favoriteTeamName: String {
        favoriteTeam?.name ?? "선택 안 함"
    }

    /// 빈 문자열은 값이 없는 것으로 본다.
    ///
    /// 빈 팀 ID나 빈 구장 ID는 어떤 canonical 값과도 맞지 않으므로 저장돼 있어도
    /// 의미가 없다. 이렇게 두면 "지웠다"는 뜻을 값 하나로 표현할 수 있어, 하위
    /// 도메인에 남은 옛 값을 앱 도메인에서 확실히 덮어쓸 수 있다.
    private static func storedText(_ defaults: UserDefaults, _ key: String) -> String? {
        guard let value = defaults.string(forKey: key) else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : value
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Key.hasCompletedOnboarding)
        favoriteTeamID = KBOSeed.normalizedTeamID(Self.storedText(defaults, Key.favoriteTeamID))
        // 저장된 구장이 더 이상 유효하지 않으면 값을 버리고 복구 단계에서 다시 받는다.
        let storedStadiumID = Self.storedText(defaults, Key.primaryStadiumID)
        primaryStadiumID = KBOStadiumSeed.isValid(id: storedStadiumID) ? storedStadiumID : nil
        onboardingSchemaVersion = defaults.object(forKey: Key.onboardingSchemaVersion) as? Int ?? 1
        // 이미 온보딩을 마친 기존 사용자는 소개를 본 것으로 간주한다.
        hasSeenOnboardingOverview = defaults.object(forKey: Key.hasSeenOverview) as? Bool
            ?? defaults.bool(forKey: Key.hasCompletedOnboarding)
        teamThemeEnabled = defaults.object(forKey: Key.teamThemeEnabled) as? Bool ?? true
        userDisplayName = Self.storedText(defaults, Key.userDisplayName)
        selectedSeason = defaults.object(forKey: Key.selectedSeason) as? Int
            ?? Calendar.current.component(.year, from: .now)
    }

    static func preview(
        suiteName: String,
        hasCompletedOnboarding: Bool = true,
        favoriteTeamID: String? = nil,
        teamThemeEnabled: Bool = true,
        primaryStadiumID: String? = nil,
        hasSeenOverview: Bool? = nil
    ) -> UserPreferencesStore {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        // 프리뷰와 테스트가 서로의 상태를 물려받지 않도록 suite를 비우고 시작한다.
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding)
        defaults.set(teamThemeEnabled, forKey: Key.teamThemeEnabled)
        defaults.set(Calendar.current.component(.year, from: .now), forKey: Key.selectedSeason)
        if let favoriteTeamID {
            defaults.set(favoriteTeamID, forKey: Key.favoriteTeamID)
        } else {
            defaults.removeObject(forKey: Key.favoriteTeamID)
        }
        if let primaryStadiumID {
            defaults.set(primaryStadiumID, forKey: Key.primaryStadiumID)
        } else {
            defaults.removeObject(forKey: Key.primaryStadiumID)
        }
        if let hasSeenOverview {
            defaults.set(hasSeenOverview, forKey: Key.hasSeenOverview)
        }
        return UserPreferencesStore(defaults: defaults)
    }

    /// 온보딩을 마친다. 두 값 모두 있어야 완료로 인정한다.
    /// 하나라도 비어 있으면 저장하지 않고 false를 돌려준다.
    @discardableResult
    func completeOnboarding(favoriteTeamID: String?, primaryStadiumID: String?) -> Bool {
        guard let teamID = KBOSeed.normalizedTeamID(favoriteTeamID),
              KBOSeed.team(id: teamID) != nil,
              let stadiumID = primaryStadiumID,
              KBOStadiumSeed.isValid(id: stadiumID) else {
            return false
        }
        self.favoriteTeamID = teamID
        self.primaryStadiumID = stadiumID
        hasSeenOnboardingOverview = true
        onboardingSchemaVersion = Self.currentOnboardingSchemaVersion
        hasCompletedOnboarding = true
        return true
    }

    /// 응원 팀만 바꾼다. 구장 선택은 건드리지 않는다.
    func setFavoriteTeam(_ teamID: String?) {
        favoriteTeamID = KBOSeed.normalizedTeamID(teamID)
    }

    /// 주 관람 구장만 바꾼다. 팀 선택은 건드리지 않는다.
    func setPrimaryStadium(_ stadiumID: String?) {
        guard KBOStadiumSeed.isValid(id: stadiumID) else { return }
        primaryStadiumID = stadiumID
    }

    /// 저장된 상태에서 온보딩을 어디서부터 시작할지 정한다.
    ///
    /// 기존 사용자를 보호하는 것이 핵심이다. 이미 고른 팀은 다시 묻지 않고,
    /// 빠진 값만 채운다. 기록 등 다른 사용자 데이터는 절대 지우지 않는다.
    var onboardingEntry: OnboardingEntry {
        let hasValidTeam = favoriteTeam != nil
        let hasValidStadium = primaryStadium != nil

        if hasValidTeam && hasValidStadium {
            return .completed
        }
        if hasValidTeam {
            // 팀은 있는데 구장이 없다 — 기존 설치본의 전형적인 경우.
            // 구장 한 단계만 받는다.
            return .repairStadium
        }
        if hasValidStadium {
            // 구장만 있고 팀이 없다(팀 ID가 사라진 경우).
            return .repairTeam
        }
        return .firstRun
    }

    /// 온보딩 상태를 완료로 승격한다. 값이 모두 유효할 때만 동작한다.
    @discardableResult
    func migrateOnboardingIfSatisfied() -> Bool {
        guard onboardingEntry == .completed else { return false }
        if !hasCompletedOnboarding { hasCompletedOnboarding = true }
        if !hasSeenOnboardingOverview { hasSeenOnboardingOverview = true }
        if onboardingSchemaVersion != Self.currentOnboardingSchemaVersion {
            onboardingSchemaVersion = Self.currentOnboardingSchemaVersion
        }
        return true
    }
}

/// 저장된 상태에 따라 온보딩이 시작되는 지점.
enum OnboardingEntry: Equatable {
    /// 팀과 구장이 모두 유효하다. 온보딩을 보여주지 않는다.
    case completed
    /// 처음 설치. 전체 온보딩을 보여준다.
    case firstRun
    /// 팀은 유효하고 구장만 없다. 구장 단계만 보여준다.
    case repairStadium
    /// 구장은 유효하고 팀만 없다. 팀 단계만 보여준다.
    case repairTeam
}
