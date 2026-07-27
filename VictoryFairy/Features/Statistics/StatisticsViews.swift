import SwiftUI

struct StatisticsViewModel {
    let state: StatisticsViewState
    var dataState: RemoteDataState = .loaded

    static let sample = StatisticsViewModel(state: .sample)
}

struct StatisticsView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var appData: AppDataStore
    let viewModel: StatisticsViewModel
    @State private var selectedSection: StatisticsSection = .kbo
    @State private var isShowingSeasonPicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "통계", subtitle: "KBO 흐름과 내 직관 데이터를 함께 봐요") {
                    Button {
                        isShowingSeasonPicker = true
                    } label: {
                        VFChip(title: appData.selectedSeasonLabel, isSelected: true, tint: theme.primary)
                    }
                    .buttonStyle(.plain)
                }

                DataStateBanner(state: viewModel.dataState)

                StatisticsSectionPicker(selection: $selectedSection)

                if selectedSection == .kbo {
                    kboCurrentSection
                } else {
                    myAttendanceSection
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingSeasonPicker) {
            SeasonPickerSheet(
                seasons: appData.availableSeasons,
                selectedSeason: appData.selectedSeason
            ) { season in
                Task {
                    await appData.selectSeason(season)
                }
            }
            .presentationDetents([.medium])
        }
        .vfScreenBackground()
    }

    private var kboCurrentSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            sectionCard(title: "KBO 현재") {
                if viewModel.state.kboSource == .unavailable || viewModel.state.kboStandings.isEmpty {
                    EmptyKBOStatsPlaceholder(disclosureText: viewModel.state.kboDisclosureText)
                } else {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        SourceUpdatedInfoView(
                            sourceText: viewModel.state.kboSourceText,
                            updatedText: viewModel.state.kboUpdatedText
                        )
                        if viewModel.state.kboSource == .adminResult || viewModel.state.kboSource == .adminImport || viewModel.state.kboSource == .manualSeed {
                            Text("참고용으로만 확인해 주세요.")
                                .font(.caption)
                                .foregroundStyle(VFColor.bodySecondary)
                        }
                        if let disclosureText = viewModel.state.kboDisclosureText {
                            Text(disclosureText)
                                .font(.caption)
                                .foregroundStyle(VFColor.bodySecondary)
                        }
                        KBOStandingsTable(items: viewModel.state.kboStandings)
                    }
                }
            }
        }
    }

    private var myAttendanceSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            VFCard {
                HStack(spacing: VFSpacing.lg) {
                    ResultDonutChart(
                        wins: viewModel.state.wins,
                        losses: viewModel.state.losses,
                        draws: viewModel.state.draws,
                        canceled: viewModel.state.canceled
                    )
                    .frame(width: 132, height: 132)

                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        Text("내 직관 통계")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text(viewModel.state.totalGames == 0 ? "표본 수집 중" : "\(viewModel.state.totalGames)경기 기록")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodySecondary)
                        resultLegend
                    }
                    Spacer()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                ForEach(viewModel.state.kpis) { metric in
                    MetricCard(metric: metric)
                }
            }

            NavigationLink {
                WinRateAnalysisView(statistics: viewModel.state, logs: appData.feedLogs)
            } label: {
                VFCard(background: VFColor.subtleSurface) {
                    HStack(spacing: VFSpacing.md) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(VFColor.primaryAction)
                            .frame(width: 44, height: 44)
                            .background(VFColor.primaryAction.opacity(0.12))
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                            Text("승률 분석")
                                .font(VFTypography.cardTitle)
                                .foregroundStyle(VFColor.bodyPrimary)
                            Text("내 직관 데이터 기준으로 상대팀, 구장, 최근 흐름을 더 자세히 봐요.")
                                .font(.subheadline)
                                .foregroundStyle(VFColor.bodySecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            sectionCard(title: "최근 5경기") {
                if viewModel.state.recentResults.isEmpty {
                    Text("직관 기록을 추가하면 최근 결과가 표시돼요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                } else {
                    RecentResultStrip(results: viewModel.state.recentResults)
                }
            }

            NavigationLink {
                StadiumStatsView(stats: viewModel.state.stadiumStats)
            } label: {
                rankingSection(title: "구장별 랭킹", rankings: viewModel.state.stadiumRankings)
            }
            .buttonStyle(.plain)

            NavigationLink {
                OpponentStatsView(stats: viewModel.state.opponentStats)
            } label: {
                rankingSection(title: "상대팀별 랭킹", rankings: viewModel.state.opponentRankings)
            }
            .buttonStyle(.plain)
        }
    }

    private var resultLegend: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            legendRow("승", count: viewModel.state.wins, color: VFColor.gameWin)
            legendRow("패", count: viewModel.state.losses, color: VFColor.gameLoss)
            legendRow("무", count: viewModel.state.draws, color: VFColor.gameDraw)
            legendRow("취소", count: viewModel.state.canceled, color: VFColor.gameCanceled)
        }
    }

    private func legendRow(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: VFSpacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(title) \(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(VFColor.bodyPrimary)
                content()
            }
        }
    }

    private func rankingSection(title: String, rankings: [RankingViewState]) -> some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(VFColor.bodySecondary)
                }

                if rankings.isEmpty {
                    Text("아직 집계할 기록이 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                } else {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, item in
                        StatRankingRow(rank: index + 1, item: item)
                        if item.id != rankings.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

enum StatisticsSection: String, CaseIterable, Identifiable {
    case kbo
    case mine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kbo: "KBO 현재"
        case .mine: "내 직관"
        }
    }
}

struct StatisticsSectionPicker: View {
    @Binding var selection: StatisticsSection

    var body: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(StatisticsSection.allCases) { section in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        selection = section
                    }
                } label: {
                    Text(section.title)
                        .font(.system(.subheadline, design: .rounded).weight(selection == section ? .bold : .semibold))
                        .foregroundStyle(selection == section ? VFColor.primaryAction : VFColor.bodySecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .padding(.vertical, VFSpacing.xs)
                        .contentShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .background {
                    if selection == section {
                        RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                            .fill(VFColor.primaryAction.opacity(0.12))
                            .shadow(color: VFColor.primaryAction.opacity(0.12), radius: 8, y: 3)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                        .stroke(selection == section ? VFColor.primaryAction.opacity(0.28) : Color.clear, lineWidth: 1)
                }
                .accessibilityLabel(selection == section ? "\(section.title), 선택됨" : section.title)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(VFSpacing.xs)
        .background(VFColor.translucentSurface)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 0.8)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("통계 구분")
    }
}

struct EmptyKBOStatsPlaceholder: View {
    var disclosureText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(spacing: VFSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(VFColor.deepAccent)
                    .frame(width: 36, height: 36)
                    .background(VFColor.deepAccent.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text("KBO 현재 통계 준비 중")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("데이터가 준비되면 현재 순위가 표시돼요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
            Text("최근 갱신: 갱신일 정보 없음")
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
                .padding(.top, VFSpacing.xs)
            if let disclosureText {
                Text(disclosureText)
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
    }
}

struct SourceUpdatedInfoView: View {
    let sourceText: String?
    let updatedText: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                combinedLabel
            }
        }
        .padding(VFSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .padding(.bottom, VFSpacing.xs)
    }

    private var combinedLabel: some View {
        Text("\(sourceText ?? "참고용 경기 정보") · \(updatedText)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(VFColor.bodyPrimary)
            .lineLimit(2)
    }
}

struct KBOStandingsTable: View {
    let items: [KBOStandingViewState]

    var body: some View {
        VStack(spacing: VFSpacing.xs) {
            standingsHeader
            ForEach(items) { item in
                KBOStandingRow(item: item)
            }
        }
    }

    private var standingsHeader: some View {
        HStack(spacing: VFSpacing.sm) {
            Text("순위").frame(width: 34, alignment: .leading)
            Text("팀").frame(maxWidth: .infinity, alignment: .leading)
            Text("승").frame(width: 24, alignment: .trailing)
            Text("패").frame(width: 24, alignment: .trailing)
            Text("무").frame(width: 24, alignment: .trailing)
            Text("승률").frame(width: 54, alignment: .trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(VFColor.bodySecondary)
        .padding(.bottom, VFSpacing.xs)
    }
}

struct KBOStandingRow: View {
    let item: KBOStandingViewState

    var body: some View {
        HStack(spacing: VFSpacing.sm) {
            Text("\(item.rank)")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .foregroundStyle(item.rank <= 3 ? .white : VFColor.deepAccent)
                .frame(width: 32, height: 32)
                .background(item.rank <= 3 ? VFColor.deepAccent : VFColor.subtleSurface)
                .clipShape(Circle())
            Text(item.teamName)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.88)
                .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text("\(item.wins)-\(item.losses)-\(item.draws)")
                    .frame(width: 64, alignment: .trailing)
                Text(item.winRateText)
                    .fontWeight(.bold)
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.system(.caption, design: .rounded).monospacedDigit())
        }
        .foregroundStyle(VFColor.bodyPrimary)
        .padding(.vertical, VFSpacing.sm)
        .padding(.horizontal, VFSpacing.sm)
        .background(VFColor.appBackground.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

struct ResultDonutChart: View {
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int

    var body: some View {
        ZStack {
            if total == 0 {
                Circle()
                    .stroke(VFColor.hairline, lineWidth: 18)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    DonutSegment(start: segment.start, end: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                }
            }

            VStack(spacing: VFSpacing.xxs) {
                Text(total == 0 ? "기록 없음" : "총 \(total)경기")
                    .font(.system(total == 0 ? .subheadline : .headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(VFColor.bodyPrimary)
                Text(total == 0 ? "표본 수집 중" : "직관")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
        .padding(10)
    }

    private var total: Int { wins + losses + draws + canceled }

    private var segments: [(start: Double, end: Double, color: Color)] {
        var cursor = -0.25
        return [(wins, VFColor.gameWin), (losses, VFColor.gameLoss), (draws, VFColor.gameDraw), (canceled, VFColor.gameCanceled)]
            .compactMap { count, color in
                guard count > 0 else { return nil }
                let length = Double(count) / Double(total)
                let segment = (start: cursor, end: cursor + length, color: color)
                cursor += length
                return segment
            }
    }
}

struct DonutSegment: Shape {
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(start * 360),
            endAngle: .degrees(end * 360),
            clockwise: false
        )
        return path
    }
}

struct StadiumStatsView: View {
    @Environment(\.appTheme) private var theme
    let stats: [StatGroupViewState]
    @State private var sort: WinRateRankingSort = .winRate
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                statsSortPicker

                if stats.isEmpty {
                    EmptyStateView(
                        title: "아직 구장별 통계가 없어요.",
                        message: "직관 기록을 추가하면 구장별 성적이 계산돼요.",
                        buttonTitle: "첫 직관 기록하기",
                        systemImage: "mappin.and.ellipse"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, item in
                        DetailedStatCard(rank: index + 1, item: item, rankTint: theme.primary, countTitle: "방문")
                    }
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("구장별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView()
            }
        }
        .vfScreenBackground()
    }

    private var statsSortPicker: some View {
        Picker("구장 통계 정렬", selection: $sort) {
            ForEach(WinRateRankingSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortedStats: [StatGroupViewState] {
        StatGroupSorter.sorted(stats, by: sort)
    }
}

private struct DetailedStatCard: View {
    let rank: Int
    let item: StatGroupViewState
    let rankTint: Color
    let countTitle: String

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(alignment: .top, spacing: VFSpacing.sm) {
                    Text("\(rank)")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(rankTint)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                        Text(item.name)
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.latestDateText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                    Spacer()
                    if item.isSmallSample {
                        Text("표본 적음")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(VFColor.primaryAction)
                            .padding(.horizontal, VFSpacing.xs)
                            .frame(minHeight: 24)
                            .background(VFColor.primaryAction.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: VFSpacing.sm) {
                    statPill(title: countTitle, value: "\(item.totalGames)경기", detail: "직관 기준", tint: VFColor.deepAccent)
                    statPill(title: "승률", value: item.winRateText, detail: "승패 기준", tint: VFColor.gameWin)
                }

                HStack(spacing: VFSpacing.xs) {
                    resultMiniPill("승", item.wins, VFColor.gameWin)
                    resultMiniPill("패", item.losses, VFColor.gameLoss)
                    resultMiniPill("무", item.draws, VFColor.gameDraw)
                    resultMiniPill("취소", item.canceled, VFColor.gameCanceled)
                }
            }
        }
    }

    private func statPill(title: String, value: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VFSpacing.md)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private func resultMiniPill(_ title: String, _ count: Int, _ color: Color) -> some View {
        Text("\(title) \(count)")
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, VFSpacing.sm)
            .frame(minHeight: 28)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct OpponentStatsView: View {
    @Environment(\.appTheme) private var theme
    let stats: [StatGroupViewState]
    @State private var sort: WinRateRankingSort = .winRate
    @State private var isShowingLogEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                statsSortPicker

                if stats.isEmpty {
                    EmptyStateView(
                        title: "아직 상대팀별 통계가 없어요.",
                        message: "직관 기록을 추가하면 상대팀별 성적이 계산돼요.",
                        buttonTitle: "첫 직관 기록하기",
                        systemImage: "person.2"
                    ) {
                        isShowingLogEditor = true
                    }
                } else {
                    ForEach(Array(sortedStats.enumerated()), id: \.element.id) { index, item in
                        DetailedStatCard(rank: index + 1, item: item, rankTint: theme.primary, countTitle: "상대")
                    }
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("상대팀별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingLogEditor) {
            NavigationStack {
                LogEditorView()
            }
        }
        .vfScreenBackground()
    }

    private var statsSortPicker: some View {
        Picker("상대팀 통계 정렬", selection: $sort) {
            ForEach(WinRateRankingSort.allCases) { sort in
                Text(sort.title).tag(sort)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortedStats: [StatGroupViewState] {
        StatGroupSorter.sorted(stats, by: sort)
    }
}

private enum StatGroupSorter {
    static func sorted(_ stats: [StatGroupViewState], by sort: WinRateRankingSort) -> [StatGroupViewState] {
        switch sort {
        case .winRate:
            stats.sorted {
                if ($0.winRate ?? -1) != ($1.winRate ?? -1) { return ($0.winRate ?? -1) > ($1.winRate ?? -1) }
                if $0.totalGames != $1.totalGames { return $0.totalGames > $1.totalGames }
                return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
            }
        case .total:
            stats.sorted {
                if $0.totalGames != $1.totalGames { return $0.totalGames > $1.totalGames }
                if ($0.winRate ?? -1) != ($1.winRate ?? -1) { return ($0.winRate ?? -1) > ($1.winRate ?? -1) }
                return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
            }
        case .recent:
            stats.sorted { ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast) }
        }
    }
}

struct SeasonStatsView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("시즌 기록")
                    .font(VFTypography.display)
                    .foregroundStyle(VFColor.bodyPrimary)

                VictoryFairyIndexCard(index: "63", label: "2026 시즌", footnote: "12경기")

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        Text("7승 4패 1무")
                            .font(VFTypography.sectionTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("승률 63%")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(theme.primary)

                        Divider()

                        Text("월별 직관 횟수")
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        HStack(alignment: .bottom, spacing: VFSpacing.sm) {
                            monthBar("3월", height: 52)
                            monthBar("4월", height: 92)
                            monthBar("5월", height: 28)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                                Text("최다 구장")
                                    .foregroundStyle(VFColor.bodySecondary)
                                Text("잠실 8회")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: VFSpacing.xs) {
                                Text("최다 상대팀")
                                    .foregroundStyle(VFColor.bodySecondary)
                                Text("KIA 4회")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.subheadline)

                        HStack {
                            Text("시즌 리포트")
                                .font(VFTypography.cardTitle)
                            Spacer()
                            Text("직관 기록 기반")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(VFColor.bodySecondary)
                                .padding(.horizontal, VFSpacing.sm)
                                .frame(minHeight: 28)
                                .background(VFColor.subtleSurface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("시즌 기록")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }

    private func monthBar(_ label: String, height: CGFloat) -> some View {
        VStack(spacing: VFSpacing.xs) {
            RoundedRectangle(cornerRadius: VFRadius.sm)
                .fill(theme.primary)
                .frame(width: 48, height: height)
            Text(label)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
        }
    }
}

#Preview("통계") {
    NavigationStack {
        StatisticsView(viewModel: .sample)
    }
}
