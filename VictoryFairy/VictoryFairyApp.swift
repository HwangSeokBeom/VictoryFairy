import SwiftUI

@main
struct VictoryFairyApp: App {
    @StateObject private var preferences: UserPreferencesStore
    @StateObject private var appData: AppDataStore
    @StateObject private var themeProvider: AppThemeProvider

    init() {
        // UI 테스트가 결정적인 상태로 시작할 수 있게 실행 인자를 먼저 반영한다.
        // `-VFUITest`가 없으면 아무 일도 하지 않으므로 제품 동작에는 영향이 없다.
        VFUITestConfiguration.applyIfNeeded()
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
