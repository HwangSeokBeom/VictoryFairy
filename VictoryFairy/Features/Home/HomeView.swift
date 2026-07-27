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
    @State private var isShowingAIHelper = false
    @State private var isShowingAIDraftEditor = false

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
                    featureShortcuts
                } else {
                    VictoryFairyIndexCard(
                        index: viewModel.dashboard.fairyIndex,
                        label: viewModel.dashboard.fairyLabel,
                        footnote: viewModel.dashboard.fairyFootnote
                    ) {
                        isShowingAIHelper = true
                    }

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

                    featureShortcuts

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
        .sheet(isPresented: $isShowingAIHelper) {
            HomeAIHelperSheet(
                recentLog: viewModel.dashboard.recentLogs.first,
                onStartDraft: {
                    isShowingAIHelper = false
                    DispatchQueue.main.async {
                        isShowingAIDraftEditor = true
                    }
                },
                onAddLog: {
                    isShowingAIHelper = false
                    DispatchQueue.main.async {
                        isShowingLogEditor = true
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAIDraftEditor) {
            NavigationStack {
                if let recentLog = viewModel.dashboard.recentLogs.first {
                    LogEditorView(editingLog: recentLog, startsAIPreflightOnAppear: true)
                } else {
                    LogEditorView()
                }
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
        VFCard(background: VFColor.subtleSurface) {
            HStack(spacing: VFSpacing.md) {
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("오늘 다녀온 경기가 있나요?")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("날짜와 팀만 골라도 경기 정보가 자동으로 채워져요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                }
                Spacer()
                Button {
                    isShowingLogEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(VFColor.primaryAction)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("직관 기록 추가")
            }
        }
    }

    private var featureShortcuts: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            sectionTitle("바로가기")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: VFSpacing.sm), GridItem(.flexible(), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                NavigationLink {
                    WinRateAnalysisView(statistics: appData.statistics, logs: appData.feedLogs)
                } label: {
                    shortcutCard(title: "승률 분석", subtitle: "내 직관 데이터 기준", systemImage: "chart.line.uptrend.xyaxis", tint: theme.primary)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NewsView()
                } label: {
                    shortcutCard(title: "야구 소식", subtitle: "외부 기사 링크", systemImage: "newspaper.fill", tint: VFColor.deepAccent)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MatchOutlookView()
                } label: {
                    shortcutCard(title: "경기 전망", subtitle: "재미로 보는 관전 포인트", systemImage: "sparkles", tint: VFColor.primaryAction)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CommunityHomeView()
                } label: {
                    shortcutCard(title: "응원톡", subtitle: "팬 응원 나누기", systemImage: "bubble.left.and.bubble.right.fill", tint: VFColor.supportAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shortcutCard(title: String, subtitle: String, systemImage: String, tint: Color) -> some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .frame(minHeight: 118, alignment: .topLeading)
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
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text(calendarPreviewText)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
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
                    .foregroundStyle(VFColor.bodyPrimary)
                Text("한 줄 메모를 다이어리로 확장하면 시즌 회고가 더 풍성해져요.")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.bodySecondary)
                VFSecondaryButton(title: "직관 다이어리 쓰기", systemImage: "square.and.pencil") {
                    isShowingLogEditor = true
                }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(VFColor.bodyPrimary)
            .padding(.top, VFSpacing.xs)
    }
}

private struct HomeAIHelperSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recentLog: AttendanceLogViewState?
    let onStartDraft: () -> Void
    let onAddLog: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("AI가 직관 기록을 정리해드릴게요")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("최근 직관 후기를 더 자연스럽게 다듬거나, 비어 있는 다이어리 초안을 만들 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VFCard(background: VFColor.subtleSurface) {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        if let recentLog {
                            Text(recentLog.matchup)
                                .font(VFTypography.cardTitle)
                                .foregroundStyle(VFColor.bodyPrimary)
                            Text("\(recentLog.dateText) · \(recentLog.stadium)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VFColor.bodySecondary)
                            Text("AI 초안은 저장 전 직접 확인해 주세요")
                                .font(.caption)
                                .foregroundStyle(VFColor.bodySecondary)
                        } else {
                            Text("AI 초안을 만들 직관 기록이 아직 없어요.")
                                .font(VFTypography.cardTitle)
                                .foregroundStyle(VFColor.bodyPrimary)
                            Text("첫 직관을 기록하면 경기 정보로 후기 초안을 시작할 수 있어요.")
                                .font(.subheadline)
                                .foregroundStyle(VFColor.bodySecondary)
                        }
                    }
                }

                Spacer()

                if let recentLog {
                    VFPrimaryButton(title: recentLog.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "최근 직관 후기 초안 만들기" : "최근 직관 다듬기", systemImage: "sparkles") {
                        dismiss()
                        onStartDraft()
                    }
                    VFSecondaryButton(title: "직관 기록 추가하기", systemImage: "calendar.badge.plus") {
                        dismiss()
                        onAddLog()
                    }
                } else {
                    VFPrimaryButton(title: "첫 직관 기록하기", systemImage: "calendar.badge.plus") {
                        dismiss()
                        onAddLog()
                    }
                }
            }
            .padding(VFSpacing.lg)
            .padding(.bottom, VFSpacing.sm)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .navigationTitle("AI 도우미")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
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
