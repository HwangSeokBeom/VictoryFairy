import SwiftUI

@main
struct VictoryFairyApp: App {
    @StateObject private var preferences: UserPreferencesStore
    @StateObject private var appData: AppDataStore
    @StateObject private var themeProvider: AppThemeProvider

    init() {
        let preferences = UserPreferencesStore()
        let appData = AppDataStore(preferences: preferences)
        _preferences = StateObject(wrappedValue: preferences)
        _appData = StateObject(wrappedValue: appData)
        _themeProvider = StateObject(wrappedValue: AppThemeProvider(preferences: preferences, appData: appData))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(preferences)
                .environmentObject(appData)
                .environmentObject(themeProvider)
        }
    }
}
