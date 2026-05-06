import SwiftUI
import UIKit

struct AppRootView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var themeProvider: AppThemeProvider

    var body: some View {
        Group {
            if preferences.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .environment(\.appTheme, themeProvider.theme)
        .task {
            await appData.loadInitialDataIfNeeded()
        }
    }
}

struct MainTabView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    @State private var selectedTab: MainTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(viewModel: HomeViewModel(dashboard: .sample(logs: appData.feedLogs)))
            }
            .tag(MainTab.home)
            .tabItem {
                tabLabel(for: .home)
            }

            NavigationStack {
                FeedView(viewModel: FeedViewModel(logs: appData.feedLogs, selectedResultFilter: appData.selectedFeedResultFilter, dataState: appData.feedState))
            }
            .tag(MainTab.feed)
            .tabItem {
                tabLabel(for: .feed)
            }

            NavigationStack {
                AttendanceCalendarView(logs: appData.calendarLogs, dataState: appData.calendarState, month: appData.selectedCalendarMonth)
            }
            .tag(MainTab.calendar)
            .tabItem {
                tabLabel(for: .calendar)
            }

            NavigationStack {
                StatisticsView(viewModel: StatisticsViewModel(state: appData.statistics, dataState: appData.statisticsState))
            }
            .tag(MainTab.statistics)
            .tabItem {
                tabLabel(for: .statistics)
            }
        }
        .tint(Self.selectedTabColor)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.white.opacity(0.88), for: .tabBar)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private static let selectedTabColor = Color(hex: "#FF6B1A")

    private func tabLabel(for tab: MainTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .accessibilityLabel(selectedTab == tab ? "\(tab.title), 선택됨" : tab.title)
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = UIColor(Color.white.opacity(0.88))
        appearance.shadowColor = UIColor(Color.black.opacity(0.04))
        appearance.selectionIndicatorImage = Self.selectionIndicatorImage()

        let inactiveColor = UIColor(Color(hex: "#111827"))
        let selectedColor = UIColor(Self.selectedTabColor)
        let normalFont = UIFont.systemFont(ofSize: 11, weight: .medium)
        let selectedFont = UIFont.systemFont(ofSize: 11, weight: .bold)

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance].forEach { itemAppearance in
            itemAppearance.normal.iconColor = inactiveColor.withAlphaComponent(0.72)
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: inactiveColor.withAlphaComponent(0.72),
                .font: normalFont
            ]
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: selectedColor,
                .font: selectedFont
            ]
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func selectionIndicatorImage() -> UIImage {
        let size = CGSize(width: 78, height: 42)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor(Color(hex: "#FFF0E7")).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: 4, y: 3, width: size.width - 8, height: size.height - 6),
                cornerRadius: 20
            ).fill()
            UIColor(Color(hex: "#FFB082")).setStroke()
            context.cgContext.setLineWidth(1)
            UIBezierPath(
                roundedRect: CGRect(x: 4.5, y: 3.5, width: size.width - 9, height: size.height - 7),
                cornerRadius: 19.5
            ).stroke()
        }
        .resizableImage(withCapInsets: UIEdgeInsets(top: 20, left: 36, bottom: 20, right: 36), resizingMode: .stretch)
    }
}

private enum MainTab: Hashable {
    case home
    case feed
    case calendar
    case statistics

    var title: String {
        switch self {
        case .home: "홈"
        case .feed: "피드"
        case .calendar: "캘린더"
        case .statistics: "통계"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .feed: "rectangle.stack.fill"
        case .calendar: "calendar"
        case .statistics: "chart.bar.fill"
        }
    }
}

#Preview("앱 쉘") {
    let preferences = UserPreferencesStore.preview(suiteName: "AppShellPreview")
    let appData = AppDataStore(preferences: preferences)
    let themeProvider = AppThemeProvider(preferences: preferences, appData: appData)
    AppRootView()
        .environmentObject(preferences)
        .environmentObject(appData)
        .environmentObject(themeProvider)
}

#Preview("메인 탭 LG 테마") {
    let preferences = UserPreferencesStore.preview(suiteName: "MainTabLGPreview", favoriteTeamID: "lg-twins")
    let appData = AppDataStore(preferences: preferences)
    let themeProvider = AppThemeProvider(preferences: preferences, appData: appData)
    MainTabView()
        .environmentObject(preferences)
        .environmentObject(appData)
        .environmentObject(themeProvider)
        .environment(\.appTheme, TeamTheme(team: KBOSeed.teams[0]))
}

#Preview("메인 탭 기본 테마") {
    let preferences = UserPreferencesStore.preview(suiteName: "MainTabNeutralPreview")
    let appData = AppDataStore(preferences: preferences)
    MainTabView()
        .environmentObject(preferences)
        .environmentObject(appData)
        .environment(\.appTheme, .neutral)
}
