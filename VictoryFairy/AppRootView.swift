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
        selectedContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                FloatingTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, VFSpacing.md)
                    .padding(.top, 6)
                    .padding(.bottom, VFTabBarMetrics.customTabBarBottomInset)
                    .background(.clear)
            }
        .animation(.snappy(duration: 0.22), value: selectedTab)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                // 대시보드는 AppDataStore가 feedLogs 변경 시 1회 집계해 보관한다.
                HomeView(viewModel: HomeViewModel(dashboard: appData.homeDashboard))
            }
        case .feed:
            NavigationStack {
                FeedView(viewModel: FeedViewModel(logs: appData.feedLogs, selectedResultFilter: appData.selectedFeedResultFilter, dataState: appData.feedState))
            }
        case .calendar:
            NavigationStack {
                AttendanceCalendarView(logs: appData.calendarLogs, dataState: appData.calendarState, month: appData.selectedCalendarMonth)
            }
        case .statistics:
            NavigationStack {
                StatisticsView(viewModel: StatisticsViewModel(state: appData.statistics, dataState: appData.statisticsState))
            }
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: VFTabBarMetrics.customTabBarHeight)
        .background(VFColor.cardTranslucent)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 16, y: 6)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 18, weight: isSelected ? .bold : .semibold))
                Text(tab.title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? VFColor.victoryOrange : VFColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background {
                if isSelected {
                    Capsule()
                        .fill(VFColor.victoryOrange.opacity(0.13))
                        .overlay(Capsule().stroke(VFColor.victoryOrange.opacity(0.28), lineWidth: 1))
                }
            }
            .scaleEffect(isSelected ? 1.03 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSelected ? "\(tab.title), 선택됨" : tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private enum MainTab: Hashable, CaseIterable {
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
