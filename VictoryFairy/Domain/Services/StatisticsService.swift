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
            stadiumRankings: ranking(logs: logs, key: \.stadium, unit: "회 방문"),
            opponentRankings: ranking(logs: logs, key: \.matchup, unit: "회 상대"),
            kboStandings: [],
            kboSourceText: nil,
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

    private func ranking(logs: [AttendanceLogViewState], key: KeyPath<AttendanceLogViewState, String>, unit: String) -> [RankingViewState] {
        Dictionary(grouping: logs, by: { $0[keyPath: key] })
            .map { name, grouped in
                let wins = grouped.filter { $0.result == .win }.count
                let losses = grouped.filter { $0.result == .loss }.count
                let decided = wins + losses
                let winRateText = decided == 0 ? "-" : "\(Int((Double(wins) / Double(decided) * 100).rounded()))%"
                return RankingViewState(title: name, subtitle: "\(grouped.count)\(unit)", trailing: "승률 \(winRateText)")
            }
            .sorted { $0.subtitle > $1.subtitle }
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
        let matchup = "\(favoriteTeamName) vs \(opponentTeamName)"
        let scoreText = {
            guard let favoriteTeamScore, let opponentTeamScore else { return result.title }
            return "\(favoriteTeamScore):\(opponentTeamScore)"
        }()
        let mood = moodTags.first ?? "경기장"
        let highlight = highlightTags.first ?? "응원 분위기"
        let companionText = companionType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : "\(companionType)와 "
        let seatSentence = seatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " \(seatText)에서 바라본 장면도 선명했다."
        let memoSentence = shortMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : " \(shortMemo)"

        if result == .canceled {
            return "오늘은 \(stadium)에서 \(matchup) 경기를 기다렸지만 경기가 취소됐다.\(seatSentence)\(memoSentence) 다음 직관을 다시 기대해 본다."
        }

        let resultText = "\(scoreText) \(result.diaryTitle)"
        switch tone {
        case "유쾌하게":
            return "\(companionText)\(stadium)에서 \(matchup) 직관 완료. 결과는 \(resultText). 오늘의 키워드는 \(mood), \(highlight).\(seatSentence)\(memoSentence)"
        case "SNS 캡션처럼":
            return "\(stadium) \(matchup) 직관. \(resultText)로 마무리된 \(mood) 가득했던 하루. #\(highlight)"
        case "감성적으로":
            return "오늘은 \(companionText)\(stadium)에서 \(matchup) 경기를 직관했다. 결과는 \(resultText)였고, \(mood)한 마음과 \(highlight)의 장면이 오래 남을 것 같다.\(seatSentence)\(memoSentence)"
        default:
            return "오늘은 \(companionText)\(stadium)에서 \(matchup) 경기를 직관했다. 결과는 \(resultText)였고, 경기장의 \(mood)한 분위기와 \(highlight)이 기억에 남았다.\(seatSentence)\(memoSentence)"
        }
    }
}
