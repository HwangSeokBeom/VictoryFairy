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
        // 이름이 비어 있는 묶음은 만들지 않는다.
        //
        // 요약 쪽(`stadiumVisits`)은 이미 빈 이름을 걸러 내는데 여기서는 걸러 내지
        // 않아, 구장이 적히지 않은 기록이 이름 없는 줄로 상세 목록에 나타났다.
        // 그리고 그 때문에 목록이 절대 비지 않아, 화면이 갖고 있던 빈 상태에
        // 도달할 방법이 없었다.
        Dictionary(grouping: logs.filter { key($0).trimmedOrNil != nil }, by: key)
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

// MARK: - 시즌 아카이브 계산

extension StatisticsService {

    /// 시즌 아카이브가 쓰는 기준 달력. 기기 시간대 설정에 흔들리면 같은 기록이
    /// 기기마다 다른 달에 찍힌다.
    static func referenceCalendar() -> Calendar {
        CalendarMonth.referenceCalendar()
    }

    /// Pencil `07_Statistics_SeasonArchive` 한 장을 채우는 값 전체를 만든다.
    ///
    /// 화면은 이 결과를 그리기만 한다. 합계·승률·문장·연승·구장 순서를 화면 안에서
    /// 다시 계산하지 않는다.
    func seasonArchive(
        logs: [AttendanceLogViewState],
        season: Int,
        seasonOptions: [SeasonArchiveOption],
        favoriteTeam: KBOTeam?,
        calendar: Calendar = StatisticsService.referenceCalendar()
    ) -> SeasonArchivePresentation {
        let ordered = chronological(logs)
        let record = SeasonRecord(
            totalGames: ordered.count,
            wins: ordered.count(where: .win),
            losses: ordered.count(where: .loss),
            draws: ordered.count(where: .draw),
            canceled: ordered.count(where: .canceled)
        )
        let stadiums = stadiumVisits(logs: ordered)

        return SeasonArchivePresentation(
            season: season,
            seasonOptions: normalized(seasonOptions, includingSelected: season),
            title: "\(season) 시즌",
            subtitle: subtitle(record: record, stadiumCount: stadiums.count),
            headline: SeasonHeadline.make(
                record: record,
                firstStadiumName: ordered.first?.stadium.trimmedOrNil
            ),
            record: record,
            distribution: SeasonResultDistribution.make(
                wins: record.wins,
                losses: record.losses,
                draws: record.draws,
                canceled: record.canceled
            ),
            trend: SeasonAttendanceTrend.make(logs: ordered, calendar: calendar),
            highlights: highlights(
                logs: ordered,
                stadiums: stadiums,
                favoriteTeam: favoriteTeam,
                calendar: calendar
            ),
            stadiums: stadiums,
            team: SeasonTeamIdentity(team: favoriteTeam)
        )
    }

    /// 고를 수 있는 시즌 목록을 정리한다. 내림차순, 중복 없음, 보고 있는 시즌은 반드시 포함.
    func normalized(_ options: [SeasonArchiveOption], includingSelected season: Int) -> [SeasonArchiveOption] {
        var hasRecordsBySeason: [Int: Bool] = [:]
        for option in options {
            hasRecordsBySeason[option.season] = (hasRecordsBySeason[option.season] ?? false) || option.hasRecords
        }
        if hasRecordsBySeason[season] == nil { hasRecordsBySeason[season] = false }
        return hasRecordsBySeason
            .map { SeasonArchiveOption(season: $0.key, hasRecords: $0.value) }
            .sorted { $0.season > $1.season }
    }

    /// 기록에서 시즌을 찾아낸다. 저장된 날짜만 보고 결정하므로 호출 순서에 흔들리지 않는다.
    func discoveredSeasons(
        logs: [AttendanceLogViewState],
        calendar: Calendar = StatisticsService.referenceCalendar()
    ) -> [SeasonArchiveOption] {
        let seasons = Set(logs.map { calendar.component(.year, from: $0.date) })
        return seasons
            .map { SeasonArchiveOption(season: $0, hasRecords: true) }
            .sorted { $0.season > $1.season }
    }

    // MARK: - 조각들

    /// Pencil `시즌 부제`. 실제로 센 값만 쓴다.
    private func subtitle(record: SeasonRecord, stadiumCount: Int) -> String {
        guard record.totalGames > 0 else { return "아직 이 시즌의 기록이 없어요" }
        guard stadiumCount > 0 else { return "\(record.totalGames)번의 직관" }
        return "\(record.totalGames)번의 직관, \(stadiumCount)개의 구장"
    }

    /// 같은 시각의 기록도 순서가 흔들리지 않도록 ID까지 보고 정렬한다.
    private func chronological(_ logs: [AttendanceLogViewState]) -> [AttendanceLogViewState] {
        logs.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// 실제 기록에 남은 구장만 센다. 이름이 비어 있는 기록은 구장 분석에서 빠진다.
    private func stadiumVisits(logs: [AttendanceLogViewState]) -> [SeasonStadiumVisit] {
        let named = logs.filter { $0.stadium.trimmedOrNil != nil }
        guard !named.isEmpty else { return [] }

        let grouped = Dictionary(grouping: named) { $0.stadium.trimmingCharacters(in: .whitespaces) }
        let ranked = grouped
            .map { name, group -> (name: String, group: [AttendanceLogViewState], latest: Date) in
                (name, group, group.map(\.date).max() ?? .distantPast)
            }
            .sorted {
                if $0.group.count != $1.group.count { return $0.group.count > $1.group.count }
                if $0.latest != $1.latest { return $0.latest > $1.latest }
                return $0.name < $1.name
            }

        return ranked.enumerated().map { index, entry in
            SeasonStadiumVisit(
                stadiumID: KBOStadiumSeed.all.first { $0.name == entry.name }?.id,
                name: entry.name,
                rank: index + 1,
                visits: entry.group.count,
                wins: entry.group.count(where: .win),
                losses: entry.group.count(where: .loss),
                draws: entry.group.count(where: .draw),
                canceled: entry.group.count(where: .canceled)
            )
        }
    }

    /// Pencil `올해의 기록들` 네 줄. 데이터가 없으면 없다고 말한다.
    private func highlights(
        logs: [AttendanceLogViewState],
        stadiums: [SeasonStadiumVisit],
        favoriteTeam: KBOTeam?,
        calendar: Calendar
    ) -> [SeasonHighlight] {
        [
            mostVisitedStadium(stadiums),
            mostFacedOpponent(logs: logs, favoriteTeam: favoriteTeam),
            longestWinStreak(logs: logs, calendar: calendar),
            largestWinMargin(logs: logs)
        ]
    }

    private func mostVisitedStadium(_ stadiums: [SeasonStadiumVisit]) -> SeasonHighlight {
        guard let top = stadiums.first else {
            return SeasonHighlight(
                kind: .mostVisitedStadium,
                label: "가장 많이 간 구장",
                value: "구장이 적힌 기록이 아직 없어요",
                isAvailable: false
            )
        }
        return SeasonHighlight(
            kind: .mostVisitedStadium,
            label: "가장 많이 간 구장",
            value: "\(top.name) · \(top.visitsText)",
            isAvailable: true
        )
    }

    private func mostFacedOpponent(
        logs: [AttendanceLogViewState],
        favoriteTeam: KBOTeam?
    ) -> SeasonHighlight {
        let unavailable = SeasonHighlight(
            kind: .mostFacedOpponent,
            label: "가장 많이 만난 상대",
            value: "상대 팀을 읽을 수 있는 기록이 아직 없어요",
            isAvailable: false
        )

        var byOpponent: [String: (count: Int, latest: Date)] = [:]
        for log in logs {
            let sides = log.resolvedMatchup.sides(favoriteTeamID: favoriteTeam?.id)
            guard let name = (sides.opponent?.name ?? log.resolvedMatchup.secondLabel).trimmedOrNil,
                  name != favoriteTeam?.name else { continue }
            let previous = byOpponent[name] ?? (0, .distantPast)
            byOpponent[name] = (previous.count + 1, max(previous.latest, log.date))
        }

        let ranked = byOpponent
            .map { (name: $0.key, count: $0.value.count, latest: $0.value.latest) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.latest != $1.latest { return $0.latest > $1.latest }
                return $0.name < $1.name
            }
        guard let top = ranked.first else { return unavailable }
        return SeasonHighlight(
            kind: .mostFacedOpponent,
            label: "가장 많이 만난 상대",
            value: "\(top.name) · \(top.count)번",
            isAvailable: true
        )
    }

    /// 가장 길었던 연승. 승패가 갈린 경기만 이어서 본다.
    ///
    /// 무승부와 취소는 승패를 가르지 않았으므로 연승을 끊지도, 잇지도 않는다.
    /// 같은 길이가 여럿이면 **먼저 만들어진** 연승을 고른다.
    private func longestWinStreak(logs: [AttendanceLogViewState], calendar: Calendar) -> SeasonHighlight {
        var bestLength = 0
        var bestEnd: Date?
        var currentLength = 0
        var currentEnd: Date?

        for log in logs {
            switch log.result {
            case .win:
                currentLength += 1
                currentEnd = log.date
                if currentLength > bestLength {
                    bestLength = currentLength
                    bestEnd = currentEnd
                }
            case .loss:
                currentLength = 0
                currentEnd = nil
            case .draw, .canceled:
                continue
            }
        }

        guard bestLength >= 2, let end = bestEnd else {
            return SeasonHighlight(
                kind: .longestWinStreak,
                label: "최다 연승",
                value: "아직 연승 기록이 없어요",
                isAvailable: false
            )
        }
        let month = calendar.component(.month, from: end)
        return SeasonHighlight(
            kind: .longestWinStreak,
            label: "최다 연승",
            value: "\(month)월 · \(bestLength)연승",
            isAvailable: true
        )
    }

    /// Pencil `올해의 순간` 자리. 선수 이름이나 상황을 알려 주는 데이터원이 없으므로
    /// 실제 점수로 확인할 수 있는 **가장 크게 이긴 날**로 대신한다.
    private func largestWinMargin(logs: [AttendanceLogViewState]) -> SeasonHighlight {
        let candidates = logs.compactMap { log -> (log: AttendanceLogViewState, margin: Int)? in
            guard log.result == .win,
                  let ours = log.ourScore,
                  let theirs = log.opponentScore,
                  ours > theirs else { return nil }
            return (log, ours - theirs)
        }
        let best = candidates.sorted {
            if $0.margin != $1.margin { return $0.margin > $1.margin }
            if $0.log.date != $1.log.date { return $0.log.date > $1.log.date }
            return $0.log.id.uuidString < $1.log.id.uuidString
        }.first

        guard let best else {
            return SeasonHighlight(
                kind: .largestWinMargin,
                label: "가장 크게 이긴 날",
                value: "점수가 적힌 승리가 아직 없어요",
                isAvailable: false
            )
        }
        let dateText = DateFormatter.vfCalendarDayTitle.string(from: best.log.date)
        let ours = best.log.ourScore ?? 0
        let theirs = best.log.opponentScore ?? 0
        return SeasonHighlight(
            kind: .largestWinMargin,
            label: "가장 크게 이긴 날",
            value: "\(dateText) · \(ours)-\(theirs)",
            isAvailable: true
        )
    }
}

private extension Array where Element == AttendanceLogViewState {
    func count(where result: GameResult) -> Int {
        reduce(0) { $1.result == result ? $0 + 1 : $0 }
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
