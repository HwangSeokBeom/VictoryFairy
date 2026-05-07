import Foundation

struct StatisticsService {
    func summary(logs: [AttendanceLogViewState], season: Int) -> StatisticsViewState {
        let wins = logs.filter { $0.result == .win }.count
        let losses = logs.filter { $0.result == .loss }.count
        let draws = logs.filter { $0.result == .draw }.count
        let canceled = logs.filter { $0.result == .canceled }.count
        let decided = wins + losses
        let winRate = decided == 0 ? 0 : Int((Double(wins) / Double(decided) * 100).rounded())
        let scoredLogs = logs.filter { $0.result != .canceled && $0.ourScore != nil && $0.opponentScore != nil }
        let averageScored = average(scoredLogs.compactMap(\.ourScore))
        let averageAllowed = average(scoredLogs.compactMap(\.opponentScore))
        let streakText = currentStreakText(logs: logs)
        let winRateText = decided == 0 ? "표본 수집 중" : "\(winRate)%"

        return StatisticsViewState(
            season: season,
            totalGames: logs.count,
            wins: wins,
            losses: losses,
            draws: draws,
            canceled: canceled,
            kpis: [
                MetricViewState(title: "전체 승률", value: winRateText, detail: decided == 0 ? "승패 기록 필요" : "승패 기준"),
                MetricViewState(title: "총 직관", value: "\(logs.count)경기", detail: "무 \(draws) · 취소 \(canceled)"),
                MetricViewState(title: "평균 득점", value: averageScored, detail: "취소 제외"),
                MetricViewState(title: "평균 실점", value: averageAllowed, detail: streakText)
            ],
            recentResults: Array(logs.sorted { $0.date > $1.date }.prefix(5)).map(\.result),
            stadiumRankings: ranking(logs: logs, key: { $0.stadium }, unit: "회 방문"),
            opponentRankings: ranking(logs: logs, key: { opponentName(for: $0) }, unit: "회 상대"),
            stadiumStats: groupedStats(logs: logs, key: { $0.stadium }, latestPrefix: "최근 방문"),
            opponentStats: groupedStats(logs: logs, key: { opponentName(for: $0) }, latestPrefix: "최근 경기"),
            kboStandings: [],
            kboSourceText: nil,
            kboDisclosureText: nil,
            kboUpdatedText: "최근 갱신: 갱신일 정보 없음",
            kboSource: .unknown
        )
    }

    private func average(_ values: [Int]) -> String {
        guard !values.isEmpty else { return "-" }
        let value = Double(values.reduce(0, +)) / Double(values.count)
        return String(format: "%.1f", value)
    }

    private func currentStreakText(logs: [AttendanceLogViewState]) -> String {
        let ordered = logs.sorted { $0.date > $1.date }
        guard let first = ordered.first, first.result == .win || first.result == .loss else {
            return "연승/연패 없음"
        }
        var count = 0
        for log in ordered {
            guard log.result == first.result else { break }
            count += 1
        }
        return first.result == .win ? "\(count)연승" : "\(count)연패"
    }

    private func ranking(logs: [AttendanceLogViewState], key: (AttendanceLogViewState) -> String, unit: String) -> [RankingViewState] {
        Dictionary(grouping: logs, by: key)
            .map { name, grouped in
                let wins = grouped.filter { $0.result == .win }.count
                let losses = grouped.filter { $0.result == .loss }.count
                let decided = wins + losses
                let winRateText = decided == 0 ? "-" : "\(Int((Double(wins) / Double(decided) * 100).rounded()))%"
                return RankingViewState(title: name, subtitle: "\(grouped.count)\(unit)", trailing: "승률 \(winRateText)")
            }
            .sorted { $0.subtitle > $1.subtitle }
    }

    private func groupedStats(
        logs: [AttendanceLogViewState],
        key: (AttendanceLogViewState) -> String,
        latestPrefix: String
    ) -> [StatGroupViewState] {
        Dictionary(grouping: logs, by: key)
            .map { name, grouped in
                let wins = grouped.filter { $0.result == .win }.count
                let losses = grouped.filter { $0.result == .loss }.count
                let draws = grouped.filter { $0.result == .draw }.count
                let canceled = grouped.filter { $0.result == .canceled }.count
                let decided = wins + losses
                let latestDate = grouped.map(\.date).max()
                return StatGroupViewState(
                    name: name,
                    totalGames: grouped.count,
                    wins: wins,
                    losses: losses,
                    draws: draws,
                    canceled: canceled,
                    winRate: decided == 0 ? nil : Int((Double(wins) / Double(decided) * 100).rounded()),
                    latestDate: latestDate,
                    latestDateText: latestDate.map { "\(latestPrefix) \(DateFormatter.vfDisplayDate.string(from: $0))" } ?? "\(latestPrefix) 없음"
                )
            }
            .sorted {
                if ($0.winRate ?? -1) != ($1.winRate ?? -1) { return ($0.winRate ?? -1) > ($1.winRate ?? -1) }
                if $0.totalGames != $1.totalGames { return $0.totalGames > $1.totalGames }
                return ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast)
            }
    }

    private func opponentName(for log: AttendanceLogViewState) -> String {
        let parts = log.matchup.components(separatedBy: " vs ")
        guard parts.count == 2 else { return log.matchup }
        let favoriteShortNames = Set(KBOSeed.teams.map(\.shortName))
        if favoriteShortNames.contains(parts[0]), favoriteShortNames.contains(parts[1]) {
            return parts[1]
        }
        return parts[1]
    }
}

struct VictoryFairyIndexService {
    func index(wins: Int, losses: Int) -> Int? {
        guard wins + losses > 0 else { return nil }
        return Int((((Double(wins) + 0.5 * 6) / Double(wins + losses + 6)) * 100).rounded())
    }

    func grade(index: Int?) -> String {
        guard let index else { return "표본 수집 중" }
        if index >= 70 { return "전설의 승리요정" }
        if index >= 60 { return "승리 기운 있음" }
        if index >= 50 { return "평균 이상의 행운" }
        if index >= 40 { return "균형의 팬" }
        return "반등 대기 중"
    }
}

struct DiaryTemplateGenerator {
    func generate(
        favoriteTeamName: String,
        opponentTeamName: String,
        stadium: String,
        result: GameResult,
        favoriteTeamScore: Int?,
        opponentTeamScore: Int?,
        moodTags: [String],
        highlightTags: [String],
        companionType: String,
        seatText: String,
        shortMemo: String,
        tone: String = "담백하게"
    ) -> String {
        let scoreText = {
            guard let favoriteTeamScore, let opponentTeamScore else { return result.title }
            return "\(favoriteTeamScore):\(opponentTeamScore) \(result.diaryTitle)"
        }()

        if result == .canceled {
            return "경기는 취소됐지만, 야구장에 도착했던 순간과 함께한 시간은 기록으로 남겨두고 싶다."
        }

        if result == .win {
            return "오늘은 \(stadium)에서 \(favoriteTeamName)와 \(opponentTeamName)의 경기를 직관했다. 결과는 \(scoreText), 기분 좋게 마무리한 직관이었다."
        }

        return "오늘은 \(stadium)에서 \(favoriteTeamName)와 \(opponentTeamName)의 경기를 직관했다. 결과는 \(scoreText)였지만, 경기장의 분위기와 응원은 오래 기억에 남았다."
    }
}
