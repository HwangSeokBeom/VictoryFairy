import Foundation

/// 시즌 아카이브(Pencil `07_Statistics_SeasonArchive`)가 그릴 값 전체.
///
/// 화면이 아니라 **의미**만 담는다. 색도 뷰도 들어 있지 않고, 순수 계산이라 화면 없이
/// 그대로 검증할 수 있다. 값은 모두 실제 직관 기록에서 나오며, Pencil이 예시로 적어 둔
/// 문장이나 숫자는 여기에 존재하지 않는다.
struct SeasonArchivePresentation: Equatable {
    /// 보고 있는 시즌.
    let season: Int
    /// 고를 수 있는 시즌 목록. 내림차순이며 중복이 없다.
    let seasonOptions: [SeasonArchiveOption]
    /// Pencil `화면 제목`. 화면 제목이 곧 시즌이다.
    let title: String
    /// Pencil `시즌 부제`. 실제 개수만 쓴다.
    let subtitle: String
    /// Pencil `커버 문장`.
    let headline: SeasonHeadline
    let record: SeasonRecord
    let distribution: SeasonResultDistribution
    let trend: SeasonAttendanceTrend
    /// Pencil `올해의 기록들`의 각 줄.
    let highlights: [SeasonHighlight]
    /// 실제 기록에 남은 구장만. 주 관람 구장이나 팀 홈 구장으로 대체하지 않는다.
    let stadiums: [SeasonStadiumVisit]
    /// 응원 팀. 고르지 않았으면 없음.
    let team: SeasonTeamIdentity?

    /// 이 시즌에 보여 줄 기록이 하나도 없는지.
    var hasRecords: Bool { record.totalGames > 0 }

    /// VoiceOver가 화면을 요약해 읽을 한 문장.
    var accessibilitySummary: String {
        var parts = [title]
        if let team { parts.append(team.name) }
        parts.append(headline.text)
        parts.append(record.accessibleRecordText)
        return parts.joined(separator: ", ")
    }
}

/// 시즌 선택 칩과 선택 시트가 쓰는 한 항목.
struct SeasonArchiveOption: Equatable, Identifiable, Hashable {
    let season: Int
    /// 기록이 실제로 있는 시즌인지. 서버가 알려 준 값이 없으면 false다.
    let hasRecords: Bool

    var id: Int { season }
    /// Pencil `시즌 값`은 연도만 찍는다.
    var shortLabel: String { "\(season)" }
    var label: String { "\(season) 시즌" }
    /// UI 테스트가 특정 시즌을 집어 쓰는 식별자. 표시 문구가 아니라 연도로 만든다.
    var accessibilityIdentifier: String { "statistics.season.\(season)" }
}

// MARK: - 전적과 승률

/// 한 시즌의 전적.
///
/// **승률 분모 규칙**: 승 + 패. 무승부와 취소 경기는 분모에 넣지 않는다.
/// 이 규칙은 이 앱이 이미 쓰던 것과 같다(`StatisticsService.summary`의 `decided`).
/// 취소는 경기가 열리지 않은 것이고 무승부는 승패가 갈리지 않은 것이라, 둘 다
/// "이길 수 있었던 경기"가 아니다.
struct SeasonRecord: Equatable {
    /// 취소를 포함한 전체 직관 횟수. Pencil `8경기`.
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int

    static let empty = SeasonRecord(totalGames: 0, wins: 0, losses: 0, draws: 0, canceled: 0)

    /// 승패가 갈린 경기 수. 승률의 분모다.
    var decidedGames: Int { wins + losses }

    /// 0...1. 승패가 갈린 경기가 없으면 값 자체가 없다(0이 아니다).
    var winRate: Double? {
        guard decidedGames > 0 else { return nil }
        return Double(wins) / Double(decidedGames)
    }

    /// 표본이 얼마나 쌓였는지. 화면이 정직한 문구를 고르는 근거다.
    enum Confidence: String, Equatable {
        /// 승패가 갈린 경기가 없다. 승률을 말할 수 없다.
        case undecided
        /// 승패가 1~2경기뿐이다. 숫자는 나오지만 표본이 적다.
        case insufficient
        /// 3경기 이상.
        case sufficient
    }

    var confidence: Confidence {
        switch decidedGames {
        case 0: .undecided
        case 1...2: .insufficient
        default: .sufficient
        }
    }

    /// Pencil `.625` 자리. 야구 승률 표기(소수 셋째 자리, 앞의 0을 떼는 형식)를 따른다.
    /// 승패가 갈리지 않았으면 숫자를 지어내지 않고 가로줄을 둔다.
    var winRateText: String {
        guard let winRate else { return "—" }
        let formatted = String(format: "%.3f", winRate)
        return formatted.hasPrefix("0") ? String(formatted.dropFirst()) : formatted
    }

    /// 화면에 보이는 `.714`는 VoiceOver가 읽기 어렵다. 읽을 문장은 따로 만든다.
    var accessibleWinRateText: String {
        guard let winRate else { return "승률 없음, 승패가 갈린 경기가 아직 없어요" }
        return "승률 \(String(format: "%.1f", winRate * 100))퍼센트, \(wins)승 \(losses)패 기준"
    }

    /// Pencil `8경기 · 5승 2패 1무`. 0인 항목은 적지 않는다.
    var recordText: String {
        guard totalGames > 0 else { return "기록 없음" }
        var parts: [String] = []
        if wins > 0 { parts.append("\(wins)승") }
        if losses > 0 { parts.append("\(losses)패") }
        if draws > 0 { parts.append("\(draws)무") }
        if canceled > 0 { parts.append("취소 \(canceled)") }
        guard !parts.isEmpty else { return "\(totalGames)경기" }
        return "\(totalGames)경기 · \(parts.joined(separator: " "))"
    }

    var accessibleRecordText: String {
        guard totalGames > 0 else { return "이 시즌 기록 없음" }
        var parts = ["직관 \(totalGames)경기"]
        if wins > 0 { parts.append("\(wins)승") }
        if losses > 0 { parts.append("\(losses)패") }
        if draws > 0 { parts.append("\(draws)무") }
        if canceled > 0 { parts.append("취소 \(canceled)경기") }
        return parts.joined(separator: ", ")
    }

    /// 표본이 적을 때 화면이 함께 띄울 안내. 넉넉하면 없음.
    var insufficientDataMessage: String? {
        switch confidence {
        case .undecided:
            guard totalGames > 0 else { return nil }
            return canceled == totalGames
                ? "경기가 열리지 않아 승률을 계산할 수 없어요."
                : "아직 승패가 갈린 경기가 없어 승률을 계산할 수 없어요."
        case .insufficient:
            return "승패 \(decidedGames)경기 기준이라 승률이 크게 흔들릴 수 있어요."
        case .sufficient:
            return nil
        }
    }
}

// MARK: - 한 문장 요약

/// Pencil `커버 문장` 자리를 채우는 시즌 한 줄 요약.
///
/// Pencil 원본의 문장("잠실의 기적을 두 눈으로 본 사람")은 사람이 쓴 예시다. 서버에도
/// 기기에도 그런 문장을 주는 필드가 없으므로, 실제 숫자와 실제 구장 이름만으로 문장을
/// 만든다. 같은 기록에서는 언제나 같은 문장이 나온다.
struct SeasonHeadline: Equatable {
    enum Kind: String, Equatable, CaseIterable {
        case noRecords
        case canceledOnly
        case undecided
        case firstRecord
        case insufficient
        case winning
        case even
        case losing
    }

    let kind: Kind
    let text: String

    static func make(record: SeasonRecord, firstStadiumName: String?) -> SeasonHeadline {
        guard record.totalGames > 0 else {
            return SeasonHeadline(kind: .noRecords, text: "아직 이 시즌의 기록이 없어요")
        }
        if record.canceled == record.totalGames {
            return SeasonHeadline(
                kind: .canceledOnly,
                text: "\(record.totalGames)번 발걸음했지만 경기는 열리지 않았어요"
            )
        }
        if record.totalGames == 1 {
            if let stadium = firstStadiumName, !stadium.isEmpty {
                return SeasonHeadline(kind: .firstRecord, text: "\(stadium)에서 시작한 시즌")
            }
            return SeasonHeadline(kind: .firstRecord, text: "한 번의 직관으로 시작한 시즌")
        }
        guard record.decidedGames > 0 else {
            return SeasonHeadline(
                kind: .undecided,
                text: "\(record.draws)번 비긴, 아직 승패가 없는 시즌"
            )
        }
        if record.confidence == .insufficient {
            return SeasonHeadline(
                kind: .insufficient,
                text: "\(record.totalGames)번의 직관, 승률을 말하기엔 이른 시즌"
            )
        }
        if record.wins > record.losses {
            return SeasonHeadline(
                kind: .winning,
                text: "\(record.decidedGames)번 중 \(record.wins)번을 이긴 시즌"
            )
        }
        if record.wins == record.losses {
            return SeasonHeadline(
                kind: .even,
                text: "\(record.wins)승 \(record.losses)패, 정확히 반반인 시즌"
            )
        }
        return SeasonHeadline(
            kind: .losing,
            text: "\(record.wins)승 \(record.losses)패, 다음을 기다리는 시즌"
        )
    }
}

// MARK: - 결과 분포

/// 승·패·무·취소가 각각 얼마나 되는지.
///
/// 색만으로 뜻을 전하지 않도록 각 조각이 자기 라벨을 들고 있다.
struct SeasonResultDistribution: Equatable {
    let shares: [SeasonResultShare]
    let total: Int

    static let empty = SeasonResultDistribution(shares: [], total: 0)

    var isEmpty: Bool { total == 0 }

    /// 차트 대신 읽어 줄 문장. 차트를 볼 수 없어도 같은 값이 남는다.
    var summary: String {
        guard !isEmpty else { return "아직 집계할 경기가 없어요" }
        let detail = shares.map { "\($0.title) \($0.count)경기" }.joined(separator: ", ")
        return "전체 \(total)경기 중 \(detail)"
    }

    static func make(wins: Int, losses: Int, draws: Int, canceled: Int) -> SeasonResultDistribution {
        let total = wins + losses + draws + canceled
        guard total > 0 else { return .empty }
        let ordered: [(GameResult, Int)] = [
            (.win, wins), (.loss, losses), (.draw, draws), (.canceled, canceled)
        ]
        let shares = ordered.compactMap { result, count -> SeasonResultShare? in
            guard count > 0 else { return nil }
            return SeasonResultShare(
                result: result,
                count: count,
                fraction: Double(count) / Double(total)
            )
        }
        return SeasonResultDistribution(shares: shares, total: total)
    }
}

struct SeasonResultShare: Equatable, Identifiable {
    let result: GameResult
    let count: Int
    /// 0...1.
    let fraction: Double

    var id: String { result.rawValue }
    var title: String { result.title }
    /// Pencil 범례처럼 글자로도 뜻이 남는다.
    var label: String { "\(result.title) \(count)" }
    var accessibilityIdentifier: String { "statistics.distribution.\(result.rawValue)" }
    var percentText: String { "\(Int((fraction * 100).rounded()))%" }
}

// MARK: - 월별 직관 흐름

/// Pencil `타임라인`. 달마다 몇 번 갔는지.
///
/// Pencil은 3월부터 9월까지 고정된 일곱 칸을 그리지만, 이 앱에는 시즌이 언제 시작하고
/// 끝나는지 알려 주는 데이터원이 없다. 없는 기간을 지어내지 않고 **첫 기록이 있는 달부터
/// 마지막 기록이 있는 달까지**를 그린다. 그 사이에 기록이 없는 달은 빈 칸으로 남아
/// 시즌의 모양이 그대로 보인다.
struct SeasonAttendanceTrend: Equatable {
    let points: [SeasonAttendancePoint]

    static let empty = SeasonAttendanceTrend(points: [])

    var isEmpty: Bool { points.allSatisfy { $0.count == 0 } }
    var totalCount: Int { points.reduce(0) { $0 + $1.count } }
    var maxCount: Int { points.map(\.count).max() ?? 0 }

    /// 가장 많이 간 달. 같으면 이른 달을 고른다.
    var busiestPoint: SeasonAttendancePoint? {
        guard maxCount > 0 else { return nil }
        return points.first { $0.count == maxCount }
    }

    /// 차트를 읽을 수 없는 사람에게도 같은 값이 남도록 만드는 요약.
    var summary: String {
        guard let first = points.first, let last = points.last, !isEmpty else {
            return "아직 월별 기록이 없어요"
        }
        if points.count == 1 {
            return "\(first.label)에 \(first.count)번 직관했어요"
        }
        let busiest = busiestPoint.map { "가장 많았던 달은 \($0.label) \($0.count)번" }
        return [
            "\(first.label)부터 \(last.label)까지 \(totalCount)번 직관했어요",
            busiest
        ].compactMap { $0 }.joined(separator: ", ")
    }

    /// 기록에서 달 흐름을 만든다. 달 판단은 넘겨받은 달력(기준 시간대)으로만 한다.
    static func make(logs: [AttendanceLogViewState], calendar: Calendar) -> SeasonAttendanceTrend {
        guard !logs.isEmpty else { return .empty }
        var countByMonth: [Int: Int] = [:]
        for log in logs {
            let month = calendar.component(.month, from: log.date)
            countByMonth[month, default: 0] += 1
        }
        guard let lower = countByMonth.keys.min(), let upper = countByMonth.keys.max() else {
            return .empty
        }
        let points = (lower...upper).map {
            SeasonAttendancePoint(month: $0, count: countByMonth[$0] ?? 0)
        }
        return SeasonAttendanceTrend(points: points)
    }
}

struct SeasonAttendancePoint: Equatable, Identifiable {
    /// 1...12.
    let month: Int
    let count: Int

    var id: Int { month }
    var label: String { "\(month)월" }
    /// UI 테스트가 특정 달을 집어 쓰는 식별자. 표시 문구가 아니라 숫자로 만든다.
    var accessibilityIdentifier: String { "statistics.trend.month.\(month)" }
    var accessibilityLabel: String {
        count == 0 ? "\(label), 기록 없음" : "\(label), \(count)번 직관"
    }
}

// MARK: - 올해의 기록들

/// Pencil `올해의 기록들` 한 줄.
///
/// 데이터가 받쳐 주지 못하면 값을 지어내지 않고 `isAvailable == false`로 남긴다.
/// 화면은 그 사실을 그대로 보여 준다.
struct SeasonHighlight: Equatable, Identifiable {
    enum Kind: String, Equatable, CaseIterable {
        /// 실제 기록에 남은 구장 가운데 가장 자주 간 곳.
        case mostVisitedStadium
        /// 가장 자주 만난 상대 팀.
        case mostFacedOpponent
        /// 가장 길었던 연승.
        case longestWinStreak
        /// 가장 크게 이긴 날. Pencil `올해의 순간` 자리를 실제 데이터로 대신한다.
        case largestWinMargin
    }

    let kind: Kind
    let label: String
    let value: String
    let isAvailable: Bool

    var id: String { kind.rawValue }
    var accessibilityIdentifier: String { "statistics.highlight.\(kind.rawValue)" }
    var accessibilityLabel: String { "\(label), \(value)" }
}

// MARK: - 구장

/// 실제 기록에 남은 구장 하나.
///
/// 기록이 남긴 구장 이름을 그대로 쓴다. 주 관람 구장이나 응원 팀의 홈 구장으로
/// 바꿔치기하지 않는다. 정식 등록부에 있는 구장이면 안정적인 ID까지 함께 들고 있다.
struct SeasonStadiumVisit: Equatable, Identifiable {
    /// 정식 등록부(`KBOStadiumSeed`)에 있으면 그 ID. 없으면 없음.
    let stadiumID: String?
    /// 기록에 남은 이름 그대로.
    let name: String
    /// 순위. 1부터.
    let rank: Int
    let visits: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int

    var id: String { "\(rank)-\(name)" }

    var decidedGames: Int { wins + losses }

    var winRateText: String {
        guard decidedGames > 0 else { return "—" }
        let formatted = String(format: "%.3f", Double(wins) / Double(decidedGames))
        return formatted.hasPrefix("0") ? String(formatted.dropFirst()) : formatted
    }

    var recordText: String {
        var parts: [String] = []
        if wins > 0 { parts.append("\(wins)승") }
        if losses > 0 { parts.append("\(losses)패") }
        if draws > 0 { parts.append("\(draws)무") }
        if canceled > 0 { parts.append("취소 \(canceled)") }
        return parts.isEmpty ? "결과 없음" : parts.joined(separator: " ")
    }

    var visitsText: String { "\(visits)번" }

    /// 한국어 표시 문구를 식별자로 쓰지 않는다. 등록부에 없는 구장은 순위로 구분한다.
    var accessibilityIdentifier: String {
        "statistics.stadium.\(stadiumID ?? "rank\(rank)")"
    }

    var accessibilityLabel: String {
        "\(name), \(visitsText) 방문, \(recordText)"
    }
}

// MARK: - 팀

/// 이 시즌이 누구의 시즌인지.
struct SeasonTeamIdentity: Equatable {
    let teamID: String
    let name: String
    let shortName: String
    let homeStadiumName: String

    var accessibilityIdentifier: String { "statistics.team.\(teamID)" }

    init?(team: KBOTeam?) {
        guard let team else { return nil }
        teamID = team.id
        name = team.name
        shortName = team.shortName
        homeStadiumName = team.homeStadiumName
    }
}

// MARK: - 화면 식별자

/// 시즌 아카이브가 쓰는 접근성 식별자.
///
/// 한 곳에 모아 두면 화면과 UI 테스트가 같은 문자열을 본다. 값은 모두 영문이며,
/// 화면에 보이는 한국어 문구를 정체성으로 쓰지 않는다.
enum StatisticsAccessibilityID {
    static let root = "statistics.root"
    static let title = "statistics.title"
    static let subtitle = "statistics.subtitle"
    static let selectedSeason = "statistics.selectedSeason"
    static let hero = "statistics.hero"
    static let heroEyebrow = "statistics.hero.eyebrow"
    static let headline = "statistics.headline"
    static let winRate = "statistics.winRate"
    static let totalAttendance = "statistics.totalAttendance"
    static let wins = "statistics.wins"
    static let losses = "statistics.losses"
    static let draws = "statistics.draws"
    static let canceled = "statistics.canceled"
    static let distribution = "statistics.distribution"
    static let distributionSummary = "statistics.distribution.summary"
    static let trend = "statistics.trend"
    static let trendSummary = "statistics.trend.summary"
    static let highlights = "statistics.highlights"
    static let stadiumAnalysis = "statistics.stadiumAnalysis"
    static let stadiumAnalysisEmpty = "statistics.stadiumAnalysis.empty"
    static let loading = "statistics.loading"
    static let empty = "statistics.empty"
    static let insufficientData = "statistics.insufficientData"
    static let error = "statistics.error"
    static let retry = "statistics.retry"
    static let seasonReport = "statistics.seasonReport"
    static let leagueStandings = "statistics.leagueStandings"
}
