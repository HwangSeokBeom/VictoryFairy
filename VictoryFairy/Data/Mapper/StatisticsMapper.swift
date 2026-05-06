import Foundation

enum StatisticsMapper {
    static func viewState(
        summary: StatisticsSummaryDTO,
        stadiums: [StadiumStatsDTO],
        opponents: [OpponentStatsDTO]
    ) -> StatisticsViewState {
        let winRate = summary.winRate.map { Int(($0 <= 1 ? $0 * 100 : $0).rounded()) } ?? 0
        let averageScored = summary.averageScored.map { String(format: "%.1f", $0) } ?? "-"
        let averageAllowed = summary.averageAllowed.map { String(format: "%.1f", $0) } ?? "-"

        return StatisticsViewState(
            season: summary.season,
            totalGames: summary.totalGames,
            wins: summary.wins,
            losses: summary.losses,
            draws: summary.draws,
            canceled: summary.canceled,
            kpis: [
                MetricViewState(title: "전체 승률", value: summary.wins + summary.losses == 0 ? "표본 수집 중" : "\(winRate)%", detail: summary.wins + summary.losses == 0 ? "승패 기록 필요" : "승패 기준"),
                MetricViewState(title: "총 직관", value: "\(summary.totalGames)경기", detail: "\(summary.season) 시즌"),
                MetricViewState(title: "평균 득점", value: averageScored, detail: "득점"),
                MetricViewState(title: "평균 실점", value: averageAllowed, detail: summary.currentStreakText)
            ],
            recentResults: summary.recentResults.map { GameResult(serverValue: $0) },
            stadiumRankings: stadiums.map {
                RankingViewState(
                    title: $0.name,
                    subtitle: "\($0.totalGames)회 방문",
                    trailing: "승률 \(percentText($0.winRate))"
                )
            },
            opponentRankings: opponents.map {
                RankingViewState(
                    title: $0.name,
                    subtitle: "\($0.totalGames)회 상대",
                    trailing: "승률 \(percentText($0.winRate))"
                )
            },
            kboStandings: [],
            kboSourceText: nil,
            kboUpdatedText: "최근 갱신: 갱신일 정보 없음",
            kboSource: .unknown
        )
    }

    static func applyingKBOStandings(_ standings: KBOStandingsDTO?, to state: StatisticsViewState) -> StatisticsViewState {
        guard let standings else { return state }
        return StatisticsViewState(
            season: state.season,
            totalGames: state.totalGames,
            wins: state.wins,
            losses: state.losses,
            draws: state.draws,
            canceled: state.canceled,
            kpis: state.kpis,
            recentResults: state.recentResults,
            stadiumRankings: state.stadiumRankings,
            opponentRankings: state.opponentRankings,
            kboStandings: standings.items.map {
                KBOStandingViewState(
                    rank: $0.rank,
                    teamName: $0.teamName,
                    wins: $0.wins,
                    losses: $0.losses,
                    draws: $0.draws,
                    winRateText: percentText($0.winRate),
                    gamesBehindText: $0.gamesBehind.map { String(format: "%.1f", $0) } ?? "-"
                )
            },
            kboSourceText: sourceText(for: standings),
            kboUpdatedText: updatedText(for: standings),
            kboSource: KBOStandingsSource(serverValue: standings.source)
        )
    }

    static func viewState(logs: [AttendanceLogViewState], season: Int) -> StatisticsViewState {
        StatisticsService().summary(logs: logs, season: season)
    }

    private static func percentText(_ value: Double?) -> String {
        guard let value else { return "-" }
        let percent = Int(((value <= 1 ? value * 100 : value)).rounded())
        return "\(percent)%"
    }

    private static func sourceText(for standings: KBOStandingsDTO) -> String? {
        let serverLabel = standings.sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeServerLabel = serverLabel?.contains("공식") == true ? nil : serverLabel

        switch KBOStandingsSource(serverValue: standings.source) {
        case .manualSeed, .adminResult, .adminImport:
            return safeServerLabel?.nilIfEmpty ?? "관리자 입력 데이터"
        case .official:
            return safeServerLabel?.nilIfEmpty ?? "외부 수집 데이터"
        case .provider:
            return safeServerLabel?.nilIfEmpty ?? "외부 제공 데이터"
        case .scrapedDev:
            return safeServerLabel?.nilIfEmpty ?? "개발용 외부 수집 데이터"
        case .unavailable:
            return nil
        case .unknown:
            return safeServerLabel?.nilIfEmpty ?? "참고용 데이터"
        }
    }

    private static func updatedText(for standings: KBOStandingsDTO) -> String {
        "최근 갱신: \(updatedDateText(for: standings) ?? "갱신일 정보 없음")"
    }

    private static func updatedDateText(for standings: KBOStandingsDTO) -> String? {
        if let dataLevelValue = [
            standings.updatedAt,
            standings.lastUpdatedAt,
            standings.collectedAt,
            standings.generatedAt
        ].compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }).first {
            return displayDateTimeText(from: dataLevelValue)
        }

        let itemValues = standings.items.flatMap {
            [$0.updatedAt, $0.lastUpdatedAt, $0.collectedAt, $0.generatedAt]
        }
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty }

        if let latest = itemValues
            .compactMap({ value -> (value: String, date: Date)? in
                guard let date = parseServerDate(value) else { return nil }
                return (value, date)
            })
            .max(by: { $0.date < $1.date }) {
            return DateFormatter.vfDisplayDateTime.string(from: latest.date)
        }

        return itemValues.first.map(displayDateTimeText(from:))
    }

    private static func displayDateTimeText(from value: String) -> String {
        guard let date = parseServerDate(value) else { return value }
        return DateFormatter.vfDisplayDateTime.string(from: date)
    }

    private static func parseServerDate(_ value: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        if let date = DateFormatter.vfAPIDate.date(from: value) {
            return date
        }

        return nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
