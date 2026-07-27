import SwiftUI

struct HomeViewModel {
    let dashboard: HomeDashboardViewState

    static let sample = HomeViewModel(dashboard: .sample())
    static let empty = HomeViewModel(dashboard: .empty)
}

/// Pencil `홈` 프레임의 구조를 그대로 따른다.
/// 워드마크 -> 인사 -> 가장 최근의 직관 -> 기록 CTA -> 시즌 스트립 -> 바로가기.
struct HomeView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: HomeViewModel
    @State private var isShowingLogEditor = false
    @State private var isShowingAIHelper = false
    @State private var isShowingAIDraftEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.sectionGap) {
                wordmarkHeader
                greetingBlock

                if viewModel.dashboard.isEmpty {
                    VFEmptyStatePanel(
                        title: "아직 직관 기록이 없어요",
                        message: "첫 직관의 기억부터 차곡차곡 모아드릴게요.\n사진 한 장이면 충분해요.",
                        illustration: .glove,
                        actionTitle: "첫 기록 남기기"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    recentAttendanceSection
                    logCTA
                    seasonStrip
                    fairyIndexSection
                }

                featureShortcuts
            }
            .padding(.horizontal, VFSpacing.screenHorizontalMargin)
            .padding(.top, VFSpacing.xxs)
            .vfTabContentPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - 헤더와 인사

    /// Pencil 홈 헤더의 워드마크. 원본의 알림 버튼은 앱에 알림 화면이 없어 넣지 않는다.
    /// 설정은 Pencil이 정한 `마이` 탭이 담당한다.
    private var wordmarkHeader: some View {
        HStack {
            Text("승리요정")
                .font(VFTypography.handwrittenLarge)
                .foregroundStyle(VFColor.primaryActionDeep)
            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var greetingBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(todayText)
                .font(VFTypography.handwritten)
                .foregroundStyle(VFColor.bodyTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text(greetingText)
                .font(VFTypography.display)
                .foregroundStyle(VFColor.bodyPrimary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 날짜 문자열은 공용 포매터가 만든다. View에서 날짜를 다시 계산하지 않는다.
    private var todayText: String {
        DateFormatter.vfHomeGreetingDate.string(from: .now)
    }

    private var greetingText: String {
        if let teamName = appData.team(id: preferences.favoriteTeamID)?.name {
            return "\(teamName) 팬의 기록,\n\(viewModel.dashboard.title)"
        }
        return viewModel.dashboard.title
    }

    // MARK: - 가장 최근의 직관

    private var recentAttendanceSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "가장 최근의 직관")

            if let recentLog = viewModel.dashboard.recentLogs.first {
                NavigationLink {
                    AttendancePostDetailView(log: recentLog)
                } label: {
                    VFPolaroidCard(log: recentLog)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var logCTA: some View {
        VFPrimaryButton(title: "오늘의 직관 남기기", systemImage: "square.and.pencil") {
            isShowingLogEditor = true
        }
    }

    // MARK: - 시즌 스트립

    /// Pencil `시즌 스트립`. 세 칸에 시즌 요약 수치를 늘어놓는다.
    /// 글자가 커지면 가로 세 칸이 좁아지므로 세로로 접힌다.
    private var seasonStrip: some View {
        let cells = Array(viewModel.dashboard.metrics.prefix(3).enumerated())
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.xs) {
                ForEach(cells, id: \.element.id) { index, metric in
                    seasonCell(metric: metric, index: index)
                }
            }
            VStack(spacing: VFSpacing.sm) {
                ForEach(cells, id: \.element.id) { index, metric in
                    seasonCell(metric: metric, index: index)
                }
            }
        }
        .padding(.vertical, VFSpacing.sm)
        .padding(.horizontal, VFSpacing.xs)
        .frame(maxWidth: .infinity)
        .background(VFColor.highlightSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.card, style: .continuous)
                .stroke(VFColor.inkOutline.opacity(0.65), lineWidth: VFStroke.hairline)
        )
    }

    private func seasonCell(metric: MetricViewState, index: Int) -> some View {
        VStack(spacing: VFSpacing.xxs) {
            VFIllustrationView(seasonCellIllustration(at: index), height: 30)
            Text(metric.value)
                .font(Font.system(.subheadline, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
            Text(metric.title)
                .font(VFTypography.badge)
                .foregroundStyle(VFColor.bodySecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) \(metric.value)")
    }

    /// Pencil 시즌 스트립은 칸마다 다른 일러스트를 쓴다(공·페넌트·야간조명).
    private func seasonCellIllustration(at index: Int) -> VFIllustration {
        switch index {
        case 0: .baseball
        case 1: .pennant
        default: .stadiumLight
        }
    }

    // MARK: - 승리요정 지수

    /// Pencil에는 없지만 앱의 핵심 기능이라 종이 언어로 다시 칠해 남겨둔다.
    private var fairyIndexSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "승리요정 지수")
            VictoryFairyIndexCard(
                index: viewModel.dashboard.fairyIndex,
                label: viewModel.dashboard.fairyLabel,
                footnote: viewModel.dashboard.fairyFootnote
            ) {
                isShowingAIHelper = true
            }
        }
    }

    // MARK: - 바로가기

    private var featureShortcuts: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "바로가기")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: VFSpacing.sm)],
                spacing: VFSpacing.sm
            ) {
                NavigationLink {
                    WinRateAnalysisView(statistics: appData.statistics, logs: appData.feedLogs)
                } label: {
                    shortcutCard(title: "승률 분석", subtitle: "내 직관 데이터 기준", illustration: .pennant)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    NewsView()
                } label: {
                    shortcutCard(title: "야구 소식", subtitle: "외부 기사 링크", illustration: .ticket)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MatchOutlookView()
                } label: {
                    shortcutCard(title: "경기 전망", subtitle: "재미로 보는 관전 포인트", illustration: .sparkle)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CommunityHomeView()
                } label: {
                    shortcutCard(title: "응원톡", subtitle: "팬 응원 나누기", illustration: .glove)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func shortcutCard(title: String, subtitle: String, illustration: VFIllustration) -> some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                VFIllustrationView(illustration, height: 34)
                Text(title)
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityAddTraits(.isButton)
    }
}

private struct HomeAIHelperSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recentLog: AttendanceLogViewState?
    let onStartDraft: () -> Void
    let onAddLog: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("AI가 직관 기록을 정리해드릴게요")
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("최근 직관 후기를 더 자연스럽게 다듬거나, 비어 있는 다이어리 초안을 만들 수 있어요.")
                    .font(VFTypography.supporting)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VFCard(background: VFColor.subtleSurface) {
                    VStack(alignment: .leading, spacing: VFSpacing.xs) {
                        if let recentLog {
                            Text(recentLog.matchup)
                                .font(VFTypography.cardTitle)
                                .foregroundStyle(VFColor.bodyPrimary)
                            VFMetaRow(
                                systemImage: "mappin.and.ellipse",
                                text: "\(recentLog.dateText) · \(recentLog.stadium)"
                            )
                            Text("AI 초안은 저장 전 직접 확인해 주세요")
                                .font(VFTypography.metadata)
                                .foregroundStyle(VFColor.bodyTertiary)
                        } else {
                            Text("AI 초안을 만들 직관 기록이 아직 없어요.")
                                .font(VFTypography.cardTitle)
                                .foregroundStyle(VFColor.bodyPrimary)
                            Text("첫 직관을 기록하면 경기 정보로 후기 초안을 시작할 수 있어요.")
                                .font(VFTypography.supporting)
                                .foregroundStyle(VFColor.bodySecondary)
                        }
                    }
                }

                Spacer(minLength: VFSpacing.md)

                if let recentLog {
                    VFPrimaryButton(
                        title: recentLog.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "최근 직관 후기 초안 만들기" : "최근 직관 다듬기",
                        systemImage: "sparkles"
                    ) {
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
            .padding(VFSpacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

#Preview("홈 · AccessibilityXXXL") {
    let preferences = UserPreferencesStore.preview(suiteName: "HomeXXXLPreview")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        HomeView(viewModel: .sample)
    }
    .environmentObject(preferences)
    .environmentObject(appData)
    .environment(\.dynamicTypeSize, .accessibility5)
}
