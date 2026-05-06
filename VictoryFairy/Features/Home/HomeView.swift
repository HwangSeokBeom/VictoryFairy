import SwiftUI

struct HomeViewModel {
    let dashboard: HomeDashboardViewState

    static let sample = HomeViewModel(dashboard: .sample())
    static let empty = HomeViewModel(dashboard: .empty)
}

struct HomeView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: HomeViewModel
    @State private var isShowingSettings = false
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                header

                if viewModel.dashboard.isEmpty {
                    EmptyStateView(
                        title: "아직 기록한 직관이 없어요",
                        message: "첫 직관을 기록하면 승리요정 지수가 시작돼요.",
                        buttonTitle: "첫 직관 기록하기"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    VictoryFairyIndexCard(
                        index: viewModel.dashboard.fairyIndex,
                        label: viewModel.dashboard.fairyLabel,
                        footnote: viewModel.dashboard.fairyFootnote
                    )

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                        ForEach(viewModel.dashboard.metrics) { metric in
                            MetricCard(metric: metric)
                        }
                    }

                    sectionTitle("최근 직관")
                    if let recentLog = viewModel.dashboard.recentLogs.first {
                        NavigationLink {
                            AttendancePostDetailView(log: recentLog)
                        } label: {
                            AttendancePostCard(log: recentLog, showsActions: false)
                        }
                        .buttonStyle(.plain)
                    }

                    calendarPreview

                    quickActionCard

                    diarySuggestion
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                ProfileSettingsView()
            }
        }
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView()
            }
        }
        .vfScreenBackground()
    }

    private var header: some View {
        ScreenHeaderView(title: viewModel.dashboard.title, subtitle: homeSubtitle) {
            HeaderIconButton(systemImage: "person.crop.circle", accessibilityLabel: "설정") {
                isShowingSettings = true
            }
        }
    }

    private var homeSubtitle: String {
        if let teamName = appData.team(id: preferences.favoriteTeamID)?.name {
            return "\(teamName) 직관 기록으로 보는 이번 시즌 흐름"
        }
        return viewModel.dashboard.subtitle
    }

    private var quickActionCard: some View {
        VFCard(background: VFColor.backgroundWarm) {
            HStack(spacing: VFSpacing.md) {
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("오늘 다녀온 경기가 있나요?")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Text("날짜와 팀만 골라도 경기 정보가 자동으로 채워져요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                }
                Spacer()
                Button {
                    isShowingLogEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(VFColor.victoryOrange)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("직관 기록 추가")
            }
        }
    }

    private var calendarPreview: some View {
        VFCard {
            HStack(spacing: VFSpacing.md) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primary)
                    .frame(width: 44, height: 44)
                    .background(theme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))

                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text("이번 주 직관 캘린더")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Text(calendarPreviewText)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                }

                Spacer()
                RecentResultStrip(results: viewModel.dashboard.recentLogs.map(\.result))
            }
        }
    }

    private var calendarPreviewText: String {
        if let recent = viewModel.dashboard.recentLogs.first {
            return "\(recent.dateText) \(recent.stadium) 직관 기록이 있어요"
        }
        return "기록을 추가하면 캘린더에 결과가 표시돼요"
    }

    private var diarySuggestion: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Text("지난 직관 후기를 완성해볼까요?")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                Text("한 줄 메모를 다이어리로 확장하면 시즌 회고가 더 풍성해져요.")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.secondaryText)
                VFSecondaryButton(title: "직관 다이어리 쓰기", systemImage: "square.and.pencil") {
                    isShowingLogEditor = true
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(VFColor.primaryText)
            .padding(.top, VFSpacing.xs)
    }
}

#Preview("홈 데이터") {
    let preferences = UserPreferencesStore.preview(suiteName: "HomeDataPreview")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        HomeView(viewModel: .sample)
    }
    .environmentObject(preferences)
    .environmentObject(appData)
}

#Preview("홈 빈 상태") {
    let preferences = UserPreferencesStore.preview(suiteName: "HomeEmptyPreview")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        HomeView(viewModel: .empty)
    }
    .environmentObject(preferences)
    .environmentObject(appData)
}
