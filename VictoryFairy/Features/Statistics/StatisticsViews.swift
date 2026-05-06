import SwiftUI

struct StatisticsViewModel {
    let state: StatisticsViewState
    var dataState: RemoteDataState = .loaded

    static let sample = StatisticsViewModel(state: .sample)
}

struct StatisticsView: View {
    @Environment(\.appTheme) private var theme
    let viewModel: StatisticsViewModel
    @State private var selectedSection: StatisticsSection = .kbo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(title: "통계") {
                    VFChip(title: "2026 시즌", isSelected: true, tint: theme.primary)
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .vfScreenBackground()
    }

    private var kboCurrentSection: some View {
        VStack(alignment: .leading, spacing: VFSpacing.lg) {
            sectionCard(title: "KBO 현재 통계") {
                if viewModel.state.kboSource == .unavailable || viewModel.state.kboStandings.isEmpty {
                    EmptyKBOStatsPlaceholder()
                } else {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        KBOStandingsMetadata(
                            sourceText: viewModel.state.kboSourceText,
                            updatedText: viewModel.state.kboUpdatedText
                        )
                        if viewModel.state.kboSource == .adminResult || viewModel.state.kboSource == .adminImport || viewModel.state.kboSource == .manualSeed {
                            Text("공식 순위와 다를 수 있어요.")
                                .font(.caption)
                                .foregroundStyle(VFColor.secondaryText)
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
                            .font(VFTypography.section)
                            .foregroundStyle(VFColor.primaryText)
                        Text(viewModel.state.totalGames == 0 ? "표본 수집 중" : "\(viewModel.state.totalGames)경기 기록")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.secondaryText)
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

            sectionCard(title: "최근 5경기") {
                if viewModel.state.recentResults.isEmpty {
                    Text("직관 기록을 추가하면 최근 결과가 표시돼요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                } else {
                    RecentResultStrip(results: viewModel.state.recentResults)
                }
            }

            NavigationLink {
                StadiumStatsView(rankings: viewModel.state.stadiumRankings)
            } label: {
                rankingSection(title: "구장별 랭킹", rankings: viewModel.state.stadiumRankings)
            }
            .buttonStyle(.plain)

            NavigationLink {
                OpponentStatsView(rankings: viewModel.state.opponentRankings)
            } label: {
                rankingSection(title: "상대팀별 랭킹", rankings: viewModel.state.opponentRankings)
            }
            .buttonStyle(.plain)
        }
    }

    private var resultLegend: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            legendRow("승", count: viewModel.state.wins, color: VFColor.winGreen)
            legendRow("패", count: viewModel.state.losses, color: VFColor.lossRed)
            legendRow("무", count: viewModel.state.draws, color: VFColor.drawGray)
            legendRow("취소", count: viewModel.state.canceled, color: VFColor.canceledGray)
        }
    }

    private func legendRow(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: VFSpacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(title) \(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.secondaryText)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text(title)
                    .font(VFTypography.section)
                    .foregroundStyle(VFColor.primaryText)
                content()
            }
        }
    }

    private func rankingSection(title: String, rankings: [RankingViewState]) -> some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text(title)
                        .font(VFTypography.section)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(VFColor.secondaryText)
                }

                if rankings.isEmpty {
                    Text("아직 집계할 기록이 없어요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
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
                    selection = section
                } label: {
                    Text(section.title)
                        .font(.system(.subheadline, design: .rounded).weight(selection == section ? .bold : .semibold))
                        .foregroundStyle(selection == section ? VFColor.primaryText : VFColor.secondaryText)
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
                            .fill(VFColor.card)
                            .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                        .stroke(selection == section ? VFColor.mutedLine : Color.clear, lineWidth: 1)
                }
                .accessibilityLabel(section.title)
                .accessibilityAddTraits(selection == section ? .isSelected : [])
            }
        }
        .padding(VFSpacing.xs)
        .background(Color(hex: "#E9EDF5"))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.lg, style: .continuous)
                .stroke(VFColor.mutedLine.opacity(0.9), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("통계 구분")
    }
}

struct EmptyKBOStatsPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            HStack(spacing: VFSpacing.sm) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(VFColor.scoreboardNavy)
                    .frame(width: 36, height: 36)
                    .background(VFColor.scoreboardNavy.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text("KBO 현재 통계 준비 중")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Text("데이터가 준비되면 현재 순위가 표시돼요.")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                }
            }
            Text("최근 갱신: 갱신일 정보 없음")
                .font(.caption)
                .foregroundStyle(VFColor.secondaryText)
                .padding(.top, VFSpacing.xs)
        }
    }
}

struct KBOStandingsMetadata: View {
    let sourceText: String?
    let updatedText: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.sm) {
                sourceLabel
                updatedLabel
            }

            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                sourceLabel
                updatedLabel
            }
        }
        .padding(.bottom, VFSpacing.xs)
    }

    private var sourceLabel: some View {
        Text(sourceText ?? "개발용 외부 수집 데이터")
            .font(.caption.weight(.semibold))
            .foregroundStyle(VFColor.secondaryText)
            .lineLimit(2)
    }

    private var updatedLabel: some View {
        Text(updatedText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(VFColor.primaryText)
            .lineLimit(2)
    }
}

struct KBOStandingsTable: View {
    let items: [KBOStandingViewState]

    var body: some View {
        VStack(spacing: 0) {
            standingsHeader
            ForEach(items) { item in
                Divider()
                    .overlay(VFColor.mutedLine.opacity(0.65))
                HStack(spacing: VFSpacing.sm) {
                    Text("\(item.rank)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.scoreboardNavy)
                        .frame(width: 34, alignment: .leading)
                    Text(item.teamName)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(item.wins)").frame(width: 24, alignment: .trailing)
                    Text("\(item.losses)").frame(width: 24, alignment: .trailing)
                    Text("\(item.draws)").frame(width: 24, alignment: .trailing)
                    Text(item.winRateText)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .frame(width: 54, alignment: .trailing)
                }
                .font(.caption)
                .foregroundStyle(VFColor.primaryText)
                .padding(.vertical, VFSpacing.sm + 2)
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
        .foregroundStyle(VFColor.secondaryText)
        .padding(.bottom, VFSpacing.xs)
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
                    .stroke(VFColor.mutedLine, lineWidth: 18)
            } else {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    DonutSegment(start: segment.start, end: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                }
            }

            VStack(spacing: VFSpacing.xxs) {
                Text(total == 0 ? "기록 없음" : "총 \(total)경기")
                    .font(.system(total == 0 ? .subheadline : .headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(VFColor.primaryText)
                Text(total == 0 ? "표본 수집 중" : "직관")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.secondaryText)
            }
        }
        .padding(10)
    }

    private var total: Int { wins + losses + draws + canceled }

    private var segments: [(start: Double, end: Double, color: Color)] {
        var cursor = -0.25
        return [(wins, VFColor.winGreen), (losses, VFColor.lossRed), (draws, VFColor.drawGray), (canceled, VFColor.canceledGray)]
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
    let rankings: [RankingViewState]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("구장별 통계")
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)

                if rankings.isEmpty {
                    EmptyStateView(
                        title: "아직 구장별 통계가 없어요.",
                        message: "직관 기록을 추가하면 구장별 성적이 계산돼요.",
                        buttonTitle: "추후 제공",
                        systemImage: "mappin.and.ellipse"
                    )
                    .disabled(true)
                } else {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, item in
                        VFCard {
                            VStack(alignment: .leading, spacing: VFSpacing.md) {
                                HStack {
                                    Text(item.title)
                                        .font(VFTypography.section)
                                        .foregroundStyle(VFColor.primaryText)
                                    Spacer()
                                    Text("\(index + 1)위")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.primary)
                                }

                                HStack(spacing: VFSpacing.sm) {
                                    statPill(title: "방문", value: item.subtitle, detail: "직관 기준")
                                    statPill(title: "성적", value: item.trailing, detail: "승패 기준")
                                }

                                Text("기록 목록은 추후 제공")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(VFColor.secondaryText)
                                    .padding(.horizontal, VFSpacing.sm)
                                    .frame(minHeight: 30)
                                    .background(VFColor.offWhite)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle("구장별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }

    private func statPill(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.secondaryText)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(VFColor.primaryText)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption)
                .foregroundStyle(VFColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(VFSpacing.md)
        .background(VFColor.offWhite)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

struct OpponentStatsView: View {
    @Environment(\.appTheme) private var theme
    let rankings: [RankingViewState]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("상대팀별 통계")
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)

                if rankings.isEmpty {
                    EmptyStateView(
                        title: "아직 상대팀별 통계가 없어요.",
                        message: "직관 기록을 추가하면 상대팀별 성적이 계산돼요.",
                        buttonTitle: "추후 제공",
                        systemImage: "person.2"
                    )
                    .disabled(true)
                } else {
                    ForEach(Array(rankings.enumerated()), id: \.element.id) { index, item in
                        VFCard {
                            HStack(spacing: VFSpacing.md) {
                                Text("\(index + 1)")
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(theme.textOnPrimary)
                                    .frame(width: 34, height: 34)
                                    .background(theme.primary)
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                                    Text(item.title)
                                        .font(VFTypography.cardTitle)
                                        .foregroundStyle(VFColor.primaryText)
                                    Text(item.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(VFColor.secondaryText)
                                }
                                Spacer()
                                Text(item.trailing)
                                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(theme.primary)
                            }
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
        }
        .navigationTitle("상대팀별 통계")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }
}

struct SeasonStatsView: View {
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("시즌 기록")
                    .font(VFTypography.title)
                    .foregroundStyle(VFColor.primaryText)

                VictoryFairyIndexCard(index: "63", label: "2026 시즌", footnote: "12경기")

                VFCard {
                    VStack(alignment: .leading, spacing: VFSpacing.md) {
                        Text("7승 4패 1무")
                            .font(VFTypography.section)
                            .foregroundStyle(VFColor.primaryText)
                        Text("승률 63%")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(theme.primary)

                        Divider()

                        Text("월별 직관 횟수")
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.primaryText)
                        HStack(alignment: .bottom, spacing: VFSpacing.sm) {
                            monthBar("3월", height: 52)
                            monthBar("4월", height: 92)
                            monthBar("5월", height: 28)
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                                Text("최다 구장")
                                    .foregroundStyle(VFColor.secondaryText)
                                Text("잠실 8회")
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: VFSpacing.xs) {
                                Text("최다 상대팀")
                                    .foregroundStyle(VFColor.secondaryText)
                                Text("KIA 4회")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.subheadline)

                        HStack {
                            Text("시즌 리포트")
                                .font(VFTypography.cardTitle)
                            Spacer()
                            Text("추후 제공")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(VFColor.secondaryText)
                                .padding(.horizontal, VFSpacing.sm)
                                .frame(minHeight: 28)
                                .background(VFColor.offWhite)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(VFSpacing.lg)
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
                .foregroundStyle(VFColor.secondaryText)
        }
    }
}

#Preview("통계") {
    NavigationStack {
        StatisticsView(viewModel: .sample)
    }
}
