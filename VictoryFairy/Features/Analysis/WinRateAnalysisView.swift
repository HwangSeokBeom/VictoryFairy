import SwiftUI

enum WinRateRankingSort: String, CaseIterable, Identifiable {
    case winRate
    case total
    case recent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .winRate: "승률 높은 순"
        case .total: "많이 본 순"
        case .recent: "최근순"
        }
    }
}

struct WinRateAnalysisView: View {
    @Environment(\.appTheme) private var theme
    let statistics: StatisticsViewState
    let logs: [AttendanceLogViewState]
    @State private var opponentSort: WinRateRankingSort = .winRate

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                overallCard
                if totalGames < 3 {
                    sampleWarning
                }
                insightGrid
                opponentRankingCard
                stadiumRankingCard
                recentTrendCard

                Text("내 직관 데이터 기준의 개인 기록 분석이며 공식 예측 정보가 아니에요.")
                    .font(.caption)
                    .foregroundStyle(VFColor.secondaryText)
                    .padding(.horizontal, VFSpacing.xs)
            }
            .padding(VFSpacing.lg)
            .vfTabContentPadding()
        }
        .navigationTitle("승률 분석")
        .navigationBarTitleDisplayMode(.inline)
        .vfScreenBackground()
    }

    private var totalGames: Int { logs.isEmpty ? statistics.totalGames : logs.count }
    private var wins: Int { logs.isEmpty ? statistics.wins : logs.filter { $0.result == .win }.count }
    private var losses: Int { logs.isEmpty ? statistics.losses : logs.filter { $0.result == .loss }.count }
    private var draws: Int { logs.isEmpty ? statistics.draws : logs.filter { $0.result == .draw }.count }
    private var canceled: Int { logs.isEmpty ? statistics.canceled : logs.filter { $0.result == .canceled }.count }
    private var decidedGames: Int { wins + losses }
    private var winRate: Int { decidedGames == 0 ? 0 : Int((Double(wins) / Double(decidedGames) * 100).rounded()) }

    private var overallCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: VFSpacing.xs) {
                        Text("전체 직관 승률")
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.primaryText)
                        Text("내 직관 데이터 기준")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VFColor.secondaryText)
                    }
                    Spacer()
                    Text("\(winRate)%")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(theme.primary)
                }

                HStack(spacing: VFSpacing.sm) {
                    analysisPill("총", "\(totalGames)", VFColor.scoreboardNavy)
                    analysisPill("승", "\(wins)", VFColor.winGreen)
                    analysisPill("패", "\(losses)", VFColor.lossRed)
                    analysisPill("무", "\(draws)", VFColor.drawGray)
                    analysisPill("취소", "\(canceled)", VFColor.canceledGray)
                }
            }
        }
    }

    private var insightGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
            insightCard("가장 승률이 좋은 상대", bestOpponentText, "person.2.fill", VFColor.winGreen)
            insightCard("가장 많이 간 구장", mostVisitedStadiumText, "mappin.and.ellipse", theme.primary)
            insightCard("최근 흐름", recentFlowText, "waveform.path.ecg", VFColor.victoryOrange)
        }
    }

    private var opponentRankingCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text("상대팀 승률 랭킹")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                }
                Picker("상대팀 정렬", selection: $opponentSort) {
                    ForEach(WinRateRankingSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                .pickerStyle(.segmented)

                if opponentRows.isEmpty {
                    emptyText("상대팀별로 집계할 기록이 아직 없어요.")
                } else {
                    ForEach(Array(sortedOpponentRows.prefix(8).enumerated()), id: \.element.id) { index, row in
                        AnalysisRankingBar(rank: index + 1, title: row.title, subtitle: row.recordText, percent: row.winRate, tint: teamTint(for: row.title))
                    }
                }
            }
        }
    }

    private var stadiumRankingCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("구장 승률 랭킹")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                if stadiumRows.isEmpty {
                    emptyText("구장별로 집계할 기록이 아직 없어요.")
                } else {
                    ForEach(Array(stadiumRows.prefix(8).enumerated()), id: \.element.id) { index, row in
                        AnalysisRankingBar(rank: index + 1, title: row.title, subtitle: row.recordText, percent: row.winRate, tint: theme.primary)
                    }
                }
            }
        }
    }

    private var recentTrendCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text("최근 흐름")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.primaryText)
                    Spacer()
                    Text("최근 \(recentResults.count)경기")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.secondaryText)
                }
                if recentResults.isEmpty {
                    emptyText("직관 기록을 추가하면 최근 흐름이 표시돼요.")
                } else {
                    RecentResultStrip(results: recentResults)
                }
            }
        }
    }

    private var sampleWarning: some View {
        HStack(spacing: VFSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(VFColor.victoryOrange)
            Text("아직 표본이 적어 재미용으로만 봐주세요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.primaryText)
            Spacer()
        }
        .padding(VFSpacing.md)
        .background(VFColor.victoryOrange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private func analysisPill(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: VFSpacing.xxs) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VFColor.secondaryText)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
    }

    private func insightCard(_ title: String, _ value: String, _ systemImage: String, _ tint: Color) -> some View {
        VFCard(padding: VFSpacing.md) {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.secondaryText)
                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .foregroundStyle(VFColor.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private func emptyText(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(VFColor.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var recentResults: [GameResult] {
        if !logs.isEmpty {
            return Array(logs.sorted { $0.date > $1.date }.prefix(10).map(\.result))
        }
        return statistics.recentResults
    }

    private var recentFlowText: String {
        let values = recentResults.prefix(5).map(\.title).joined(separator: " ")
        return values.isEmpty ? "표본 수집 중" : values
    }

    private var bestOpponentText: String {
        sortedOpponentRows.first.map { "\($0.title) \($0.winRate)%" } ?? "표본 수집 중"
    }

    private var mostVisitedStadiumText: String {
        stadiumRows.sorted { $0.total > $1.total }.first.map { "\($0.title) \($0.total)회" } ?? "표본 수집 중"
    }

    private var sortedOpponentRows: [AnalysisRankingRowModel] {
        switch opponentSort {
        case .winRate:
            return opponentRows.sorted {
                if $0.winRate != $1.winRate { return $0.winRate > $1.winRate }
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.latestDate > $1.latestDate
            }
        case .total:
            return opponentRows.sorted {
                if $0.total != $1.total { return $0.total > $1.total }
                if $0.winRate != $1.winRate { return $0.winRate > $1.winRate }
                return $0.latestDate > $1.latestDate
            }
        case .recent:
            return opponentRows.sorted { $0.latestDate > $1.latestDate }
        }
    }

    private var opponentRows: [AnalysisRankingRowModel] {
        if logs.isEmpty {
            return statistics.opponentRankings.map { AnalysisRankingRowModel(ranking: $0) }
        }
        return groupedRows(logs: logs, key: opponentKey)
    }

    private var stadiumRows: [AnalysisRankingRowModel] {
        if logs.isEmpty {
            return statistics.stadiumRankings.map { AnalysisRankingRowModel(ranking: $0) }
        }
        return groupedRows(logs: logs, key: { $0.stadium })
            .sorted {
                if $0.winRate != $1.winRate { return $0.winRate > $1.winRate }
                if $0.total != $1.total { return $0.total > $1.total }
                return $0.latestDate > $1.latestDate
            }
    }

    private func groupedRows(logs: [AttendanceLogViewState], key: (AttendanceLogViewState) -> String) -> [AnalysisRankingRowModel] {
        Dictionary(grouping: logs, by: key).map { title, values in
            let wins = values.filter { $0.result == .win }.count
            let losses = values.filter { $0.result == .loss }.count
            let draws = values.filter { $0.result == .draw }.count
            let canceled = values.filter { $0.result == .canceled }.count
            let decided = wins + losses
            let rate = decided == 0 ? 0 : Int((Double(wins) / Double(decided) * 100).rounded())
            return AnalysisRankingRowModel(
                title: title,
                total: values.count,
                wins: wins,
                losses: losses,
                draws: draws,
                canceled: canceled,
                winRate: rate,
                latestDate: values.map(\.date).max() ?? .distantPast
            )
        }
    }

    private func opponentKey(_ log: AttendanceLogViewState) -> String {
        let parts = log.matchup.components(separatedBy: " vs ")
        if parts.count == 2 {
            if let favorite = KBOSeed.team(id: theme.teamID) {
                return parts.first == favorite.shortName ? parts[1] : parts[0]
            }
            return parts[1]
        }
        return log.matchup
    }

    private func teamTint(for title: String) -> Color {
        guard let team = KBOSeed.teams.first(where: { title.contains($0.shortName) || title.contains($0.name) }) else {
            return theme.primary
        }
        return Color(hex: team.accentColorHex)
    }
}

private struct AnalysisRankingRowModel: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let total: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let winRate: Int
    let latestDate: Date

    init(title: String, total: Int, wins: Int, losses: Int, draws: Int, canceled: Int, winRate: Int, latestDate: Date) {
        self.title = title
        self.total = total
        self.wins = wins
        self.losses = losses
        self.draws = draws
        self.canceled = canceled
        self.winRate = winRate
        self.latestDate = latestDate
    }

    init(ranking: RankingViewState) {
        title = ranking.title
        total = Int(ranking.subtitle.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
        wins = 0
        losses = 0
        draws = 0
        canceled = 0
        winRate = Int(ranking.trailing.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
        latestDate = .distantPast
    }

    var recordText: String {
        if wins + losses + draws + canceled == 0 {
            return "\(total)경기"
        }
        return "\(total)경기 · \(wins)승 \(losses)패 \(draws)무"
    }
}

private struct AnalysisRankingBar: View {
    let rank: Int
    let title: String
    let subtitle: String
    let percent: Int
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            HStack(spacing: VFSpacing.sm) {
                Text("\(rank)")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(tint)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VFColor.secondaryText)
                }
                Spacer()
                Text("\(percent)%")
                    .font(.system(.headline, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VFColor.mutedLine.opacity(0.65))
                    Capsule()
                        .fill(tint.opacity(0.78))
                        .frame(width: max(8, proxy.size.width * CGFloat(percent) / 100))
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, VFSpacing.xs)
    }
}

#Preview("승률 분석") {
    NavigationStack {
        WinRateAnalysisView(statistics: .sample, logs: AttendanceLogSample.logs)
    }
}
