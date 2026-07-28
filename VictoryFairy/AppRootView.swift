import SwiftUI

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

/// 앱의 최상위 탭 경로.
///
/// `rawValue`는 화면에 보이지 않는 안정적인 경로 식별자다. Pencil이 정한 한국어
/// 라벨(기록·시즌)이 바뀌어도 경로 자체는 그대로 유지된다.
enum MainTab: String, Hashable, CaseIterable {
    case home
    case feed
    case calendar
    case statistics
    case my

    /// Pencil `탭바`가 정한 표시 라벨.
    var title: String {
        switch self {
        case .home: "홈"
        case .feed: "기록"
        case .calendar: "캘린더"
        case .statistics: "시즌"
        case .my: "마이"
        }
    }

    /// Pencil은 lucide 아이콘을 쓴다. iOS에는 해당 아이콘 세트를 넣지 않으므로
    /// 의미가 같은 SF Symbol로 옮긴다.
    /// house / notebook-pen / calendar-days / trophy / circle-user-round 순.
    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .feed: "book.pages.fill"
        case .calendar: "calendar"
        case .statistics: "trophy.fill"
        case .my: "person.crop.circle.fill"
        }
    }

    /// UI 테스트가 참조하는 탭 버튼 식별자.
    var accessibilityIdentifier: String { "tab.\(rawValue)" }

    /// UI 테스트가 참조하는 화면 루트 식별자.
    var screenIdentifier: String { "screen.\(rawValue)" }
}

struct MainTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appData: AppDataStore
    // UI 테스트가 특정 탭에서 바로 시작할 수 있게 한다.
    // Release에서는 `initialTabRawValue`가 항상 nil이라 언제나 홈에서 시작한다.
    @State private var selectedTab: MainTab =
        VFUITestConfiguration.initialTabRawValue.flatMap(MainTab.init(rawValue:)) ?? .home

    var body: some View {
        selectedContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .vfScreenBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VFTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, VFSpacing.screenHorizontalMargin)
                    .padding(.bottom, VFTabBarMetrics.customTabBarBottomInset)
            }
            .animation(
                VFMotion.respectingReduceMotion(VFMotion.tabTransition, reduceMotion: reduceMotion),
                value: selectedTab
            )
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .home:
            NavigationStack {
                // 대시보드는 AppDataStore가 feedLogs 변경 시 1회 집계해 보관한다.
                HomeView(viewModel: HomeViewModel(dashboard: appData.homeDashboard))
            }
            .accessibilityIdentifier(MainTab.home.screenIdentifier)
        case .feed:
            NavigationStack {
                // UI 테스트 픽스처 이음새. Release 빌드에서는 두 함수가 인자를 그대로
                // 돌려주므로 제품 경로에는 아무 영향이 없다.
                FeedView(viewModel: FeedViewModel(
                    logs: VFUITestConfiguration.feedLogs(
                        appData.feedLogs,
                        filter: appData.selectedFeedResultFilter
                    ),
                    selectedResultFilter: appData.selectedFeedResultFilter,
                    dataState: VFUITestConfiguration.feedState(appData.feedState)
                ))
            }
            .accessibilityIdentifier(MainTab.feed.screenIdentifier)
        case .calendar:
            NavigationStack {
                // UI 테스트 픽스처 이음새. Release 빌드에서는 두 함수가 인자를 그대로
                // 돌려주므로 제품 경로에는 아무 영향이 없다.
                //
                // 달은 여기서 가로채지 않는다. 시작 달만 `AppDataStore`가 한 번 정하고,
                // 그 뒤의 이동은 제품 경로 그대로 흐른다.
                AttendanceCalendarView(
                    logs: VFUITestConfiguration.calendarLogs(appData.calendarLogs),
                    dataState: VFUITestConfiguration.calendarState(appData.calendarState),
                    month: appData.selectedCalendarMonth
                )
            }
            .accessibilityIdentifier(MainTab.calendar.screenIdentifier)
        case .statistics:
            NavigationStack {
                StatisticsView(viewModel: StatisticsViewModel(state: appData.statistics, dataState: appData.statisticsState))
            }
            .accessibilityIdentifier(MainTab.statistics.screenIdentifier)
        case .my:
            NavigationStack {
                ProfileSettingsView()
            }
            .accessibilityIdentifier(MainTab.my.screenIdentifier)
        }
    }
}

/// Pencil `탭바`. 종이색 캡슐이 화면 하단에 떠 있는 형태.
private struct VFTabBar: View {
    @Binding var selectedTab: MainTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        // 탭 라벨은 접근성 크기까지 따라 키우면 다섯 칸이 서로 겹치고 잘린다.
        // 막대 자체는 크기를 묶어두고, 대신 VoiceOver가 각 탭의 온전한 이름을 읽는다.
        // 화면 본문은 이 제한과 무관하게 Dynamic Type을 그대로 따른다.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .background(VFColor.translucentSurface)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(VFColor.hairline, lineWidth: 1))
        .shadow(color: VFShadow.overlayColor, radius: VFShadow.overlayRadius, y: VFShadow.overlayOffsetY)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(for tab: MainTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                Text(tab.title)
                    .font(Font.system(.caption2, design: .default).weight(isSelected ? .bold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isSelected ? VFColor.primaryActionDeep : VFColor.bodyTertiary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background {
                if isSelected {
                    Capsule().fill(VFColor.primaryActionPale)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
    MainTabView()
        .environmentObject(preferences)
        .environmentObject(appData)
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

#Preview("탭 쉘 · AccessibilityXXXL") {
    let preferences = UserPreferencesStore.preview(suiteName: "MainTabXXXLPreview")
    let appData = AppDataStore(preferences: preferences)
    MainTabView()
        .environmentObject(preferences)
        .environmentObject(appData)
        .environment(\.appTheme, .neutral)
        .environment(\.dynamicTypeSize, .accessibility3)
}
