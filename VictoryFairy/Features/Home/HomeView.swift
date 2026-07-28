import SwiftUI

struct HomeViewModel {
    let dashboard: HomeDashboardViewState

    static let sample = HomeViewModel(dashboard: .sample())
    static let empty = HomeViewModel(dashboard: .empty)
}

/// Pencil `04_Home_Default_TeamSelected` 프레임의 구현.
///
/// 순서는 원본을 그대로 따른다.
/// 워드마크 -> 팀 아이덴티티 헤더 -> 매치업 히어로 -> 가장 최근의 직관 -> 기록 CTA -> 시즌 스트립.
/// 그 아래 승리요정 지수와 바로가기는 Pencil에 없지만 이미 있는 기능이라 남긴다.
struct HomeView: View {
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: HomeViewModel
    @State private var isShowingLogEditor = false
    @State private var isShowingAIHelper = false
    @State private var isShowingAIDraftEditor = false

    private var team: KBOTeam? { preferences.favoriteTeam }
    private var primaryStadium: KBOStadium? { preferences.primaryStadium }
    private var latestLog: AttendanceLogViewState? { viewModel.dashboard.recentLogs.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.sectionGap) {
                wordmarkHeader

                if let team {
                    VFTeamIdentityHeader(
                        team: team,
                        seasonRecordText: seasonRecordText,
                        primaryStadium: primaryStadium
                    )
                }

                heroSection

                if latestLog != nil {
                    recentAttendanceSection
                }

                logCTA
                seasonStrip

                if !viewModel.dashboard.isEmpty {
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
            NavigationStack { LogEditorView() }
        }
        .sheet(isPresented: $isShowingAIHelper) {
            HomeAIHelperSheet(
                recentLog: latestLog,
                onStartDraft: {
                    isShowingAIHelper = false
                    DispatchQueue.main.async { isShowingAIDraftEditor = true }
                },
                onAddLog: {
                    isShowingAIHelper = false
                    DispatchQueue.main.async { isShowingLogEditor = true }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingAIDraftEditor) {
            NavigationStack {
                if let latestLog {
                    LogEditorView(editingLog: latestLog, startsAIPreflightOnAppear: true)
                } else {
                    LogEditorView()
                }
            }
        }
        .vfScreenBackground()
        .accessibilityIdentifier("home.root")
    }

    // MARK: - 워드마크

    /// Pencil 홈 헤더. 원본의 알림 버튼은 앱에 알림 화면이 없어 넣지 않는다.
    private var wordmarkHeader: some View {
        HStack {
            Text("승리요정")
                .font(Font.system(.title3, design: .default).weight(.heavy))
                .foregroundStyle(VFColor.bodyPrimary)
            Spacer()
        }
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("home.wordmark")
    }

    /// 시즌 전적 문구. 계산은 StatisticsService가 만든 값을 읽기만 한다.
    private var seasonRecordText: String? {
        let stats = appData.statistics
        guard stats.totalGames > 0 else { return nil }
        return "시즌 \(stats.wins)승 \(stats.losses)패 \(stats.draws)무"
    }

    // MARK: - 매치업 히어로

    /// Pencil 히어로는 "오늘 경기"를 보여주지만 홈에는 예정 경기 데이터원이 없다.
    /// 없는 경기를 지어내지 않고, 실제로 있는 가장 최근 직관을 같은 구성으로 보여준다.
    /// 기록이 없으면 팀과 주 관람 구장만으로 정직한 빈 히어로를 만든다.
    @ViewBuilder
    private var heroSection: some View {
        if let log = latestLog {
            let sides = log.resolvedMatchup.sides(favoriteTeamID: preferences.favoriteTeamID)
            VFMatchupHeroCard(
                statusTitle: log.result.diaryTitle,
                statusTint: log.result.color,
                dateText: log.dateText,
                leading: .init(
                    team: sides.mine,
                    fallbackLabel: log.resolvedMatchup.firstLabel,
                    role: "나의 팀",
                    isFavorite: true
                ),
                trailing: .init(
                    team: sides.opponent,
                    fallbackLabel: log.resolvedMatchup.secondLabel,
                    role: "상대",
                    isFavorite: false
                ),
                centerText: log.scoreText,
                centerSubtitle: log.seat.isEmpty ? nil : log.seat,
                // 이 구장은 경기가 열린 곳이다. 사용자의 주 관람 구장과 다르다.
                stadiumName: log.stadium.isEmpty ? nil : log.stadium,
                stadium: log.recordStadium,
                stadiumNote: nil,
                onStadiumTap: nil
            )
        } else if let team {
            emptyHero(team: team)
        }
    }

    /// 기록이 없을 때의 히어로. 값을 지어내지 않고 팀·구장 정체성만 유지한다.
    private func emptyHero(team: KBOTeam) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(spacing: 5) {
                Circle().fill(VFColor.bodyTertiary).frame(width: 6, height: 6)
                Text("아직 직관 기록이 없어요")
                    .font(Font.system(.caption2, design: .default).weight(.bold))
                    .foregroundStyle(VFColor.bodyOnDark.opacity(0.7))
            }
            Text("첫 직관을 남기면\n여기에 경기가 올라와요")
                .font(Font.system(.title3, design: .default).weight(.bold))
                .foregroundStyle(VFColor.bodyOnDark)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if let primaryStadium {
                VFStadiumGameStrip(
                    stadiumName: primaryStadium.name,
                    stadium: primaryStadium,
                    trailingNote: "주 관람 구장"
                )
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [VFColor.heroGradientTop, VFColor.heroGradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.panel, style: .continuous)
                .stroke(VFColor.nightHairline, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.matchupHero")
    }

    // MARK: - 가장 최근의 직관

    private var recentAttendanceSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            VFSectionHeader(title: "가장 최근의 직관")
            if let log = latestLog {
                NavigationLink {
                    AttendancePostDetailView(log: log)
                } label: {
                    VFPolaroidCard(log: log)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.recentRecord")
            }
        }
    }

    private var logCTA: some View {
        VFPrimaryButton(title: "오늘의 직관 남기기", systemImage: "square.and.pencil") {
            isShowingLogEditor = true
        }
        .accessibilityIdentifier("home.recordCTA")
    }

    // MARK: - 시즌 스트립

    /// Pencil 시즌 스트립. 값은 모두 실제 집계에서 온다.
    private var seasonStrip: some View {
        VFSeasonStrip(cells: seasonCells)
    }

    private var seasonCells: [VFSeasonStrip.Cell] {
        let stats = appData.statistics
        var cells: [VFSeasonStrip.Cell] = [
            .init(value: "\(stats.totalGames)번", label: "올해 직관"),
            .init(value: "\(stats.wins)승 \(stats.losses)패 \(stats.draws)무", label: "나의 전적")
        ]
        // 세 번째 칸은 실제 방문 기록이 있을 때만 보여준다.
        if let topStadium = stats.stadiumRankings.first {
            cells.append(.init(value: topStadium.trailing, label: topStadium.title))
        } else if let primaryStadium {
            cells.append(.init(value: "-", label: "\(primaryStadium.shortName) 방문"))
        }
        return cells
    }

    // MARK: - 승리요정 지수 (Pencil 외 기존 기능)

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

    // MARK: - 바로가기 (Pencil 외 기존 기능)

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
                    Button("취소") { dismiss() }
                }
            }
            .navigationTitle("AI 도우미")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }
}

// MARK: - 프리뷰

/// 프리뷰 전용 조립. 네트워크를 타지 않고 제품 데이터 경로로 새지 않는다.
@MainActor
private func homePreview(
    suite: String,
    teamID: String = "samsung-lions",
    stadiumID: String = "daegu-lions",
    dashboard: HomeDashboardViewState = .sample()
) -> some View {
    let preferences = UserPreferencesStore.preview(
        suiteName: suite,
        favoriteTeamID: teamID,
        primaryStadiumID: stadiumID
    )
    let appData = AppDataStore(preferences: preferences)
    return NavigationStack {
        HomeView(viewModel: HomeViewModel(dashboard: dashboard))
    }
    .environmentObject(preferences)
    .environmentObject(appData)
}

#Preview("홈 · Pencil 기준 상태") {
    homePreview(suite: "HomePencilPreview")
}

#Preview("홈 · 기록 없음") {
    homePreview(suite: "HomeEmptyPreview", dashboard: .empty)
}

#Preview("홈 · 긴 팀·구장 이름") {
    homePreview(suite: "HomeLongNamePreview", teamID: "hanwha-eagles", stadiumID: "daejeon-hanwha")
}

#Preview("홈 · 밝은 팀 강조색") {
    homePreview(suite: "HomeLightAccentPreview", teamID: "hanwha-eagles", stadiumID: "daejeon-hanwha")
}

#Preview("홈 · 어두운 팀 강조색") {
    homePreview(suite: "HomeDarkAccentPreview", teamID: "kt-wiz", stadiumID: "suwon-kt")
}

#Preview("홈 · AccessibilityXXXL") {
    homePreview(suite: "HomeXXXLPreview")
        .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("홈 · 열 팀 아이덴티티") {
    ScrollView {
        VStack(spacing: VFSpacing.sm) {
            ForEach(KBOSeed.teams) { team in
                VFTeamIdentityHeader(
                    team: team,
                    seasonRecordText: "시즌 5승 2패 1무",
                    primaryStadium: KBOStadiumSeed.recommendedStadium(forTeamID: team.id)
                )
            }
        }
        .padding(VFSpacing.md)
    }
    .vfScreenBackground()
}

#Preview("홈 · 아홉 구장 스트립") {
    ScrollView {
        VStack(spacing: VFSpacing.xs) {
            ForEach(KBOStadiumSeed.all) { stadium in
                VFStadiumGameStrip(stadiumName: stadium.name, stadium: stadium)
            }
        }
        .padding(VFSpacing.md)
        .background(VFColor.nightSurface)
    }
}
