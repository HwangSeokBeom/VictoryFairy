import Foundation
import SwiftUI

enum GameResult: String, CaseIterable, Identifiable {
    case win
    case loss
    case draw
    case canceled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .win: "승"
        case .loss: "패"
        case .draw: "무"
        case .canceled: "취소"
        }
    }

    var color: Color {
        switch self {
        case .win: VFColor.winGreen
        case .loss: VFColor.lossRed
        case .draw: VFColor.drawGray
        case .canceled: VFColor.canceledGray
        }
    }

    var diaryTitle: String {
        switch self {
        case .win: "승리"
        case .loss: "패배"
        case .draw: "무승부"
        case .canceled: "취소"
        }
    }
}

enum FeedResultFilter: String, CaseIterable, Identifiable {
    case all
    case win
    case loss
    case draw
    case canceled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "전체 결과"
        case .win: "승"
        case .loss: "패"
        case .draw: "무"
        case .canceled: "취소"
        }
    }

    var result: GameResult? {
        switch self {
        case .all: nil
        case .win: .win
        case .loss: .loss
        case .draw: .draw
        case .canceled: .canceled
        }
    }

    var queryValue: String? {
        result?.serverValue
    }
}

struct SeasonOption: Identifiable, Hashable {
    let season: Int
    let label: String
    let hasRecords: Bool

    var id: Int { season }

    init(season: Int, label: String? = nil, hasRecords: Bool = false) {
        self.season = season
        self.label = label ?? "\(season) 시즌"
        self.hasRecords = hasRecords
    }
}

struct KBOTeam: Identifiable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let city: String
    let homeStadiumName: String
    let primaryColorHex: String
    let secondaryColorHex: String
    let accentColorHex: String
    let textOnPrimaryHex: String
    let active: Bool

    var homeStadium: String { homeStadiumName }
}

enum KBOSeed {
    // 구현용 placeholder 컬러입니다. 실제 출시 전 공식 구단 컬러와 접근성 대비를 재검증해야 합니다.
    static let teams: [KBOTeam] = [
        .init(id: "lg-twins", name: "LG 트윈스", shortName: "LG", city: "서울", homeStadiumName: "잠실야구장", primaryColorHex: "#C30452", secondaryColorHex: "#000000", accentColorHex: "#C30452", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "doosan-bears", name: "두산 베어스", shortName: "두산", city: "서울", homeStadiumName: "잠실야구장", primaryColorHex: "#131230", secondaryColorHex: "#FFFFFF", accentColorHex: "#ED1C24", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "kiwoom-heroes", name: "키움 히어로즈", shortName: "키움", city: "서울", homeStadiumName: "고척스카이돔", primaryColorHex: "#570514", secondaryColorHex: "#B07F4A", accentColorHex: "#B07F4A", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "ssg-landers", name: "SSG 랜더스", shortName: "SSG", city: "인천", homeStadiumName: "인천 SSG 랜더스필드", primaryColorHex: "#CE0E2D", secondaryColorHex: "#FFB81C", accentColorHex: "#CE0E2D", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "kt-wiz", name: "KT 위즈", shortName: "KT", city: "수원", homeStadiumName: "수원 kt wiz 파크", primaryColorHex: "#000000", secondaryColorHex: "#ED1C24", accentColorHex: "#ED1C24", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "hanwha-eagles", name: "한화 이글스", shortName: "한화", city: "대전", homeStadiumName: "대전 한화생명 볼파크", primaryColorHex: "#F37321", secondaryColorHex: "#000000", accentColorHex: "#F37321", textOnPrimaryHex: "#111111", active: true),
        .init(id: "samsung-lions", name: "삼성 라이온즈", shortName: "삼성", city: "대구", homeStadiumName: "대구 삼성 라이온즈 파크", primaryColorHex: "#074CA1", secondaryColorHex: "#FFFFFF", accentColorHex: "#074CA1", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "kia-tigers", name: "KIA 타이거즈", shortName: "KIA", city: "광주", homeStadiumName: "광주-기아 챔피언스 필드", primaryColorHex: "#EA0029", secondaryColorHex: "#061A40", accentColorHex: "#EA0029", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "lotte-giants", name: "롯데 자이언츠", shortName: "롯데", city: "부산", homeStadiumName: "사직야구장", primaryColorHex: "#041E42", secondaryColorHex: "#D00F31", accentColorHex: "#D00F31", textOnPrimaryHex: "#FFFFFF", active: true),
        .init(id: "nc-dinos", name: "NC 다이노스", shortName: "NC", city: "창원", homeStadiumName: "창원NC파크", primaryColorHex: "#315288", secondaryColorHex: "#AF917B", accentColorHex: "#AF917B", textOnPrimaryHex: "#FFFFFF", active: true)
    ]

    static let legacyIDMap: [String: String] = [
        "lg": "lg-twins",
        "doosan": "doosan-bears",
        "kiwoom": "kiwoom-heroes",
        "ssg": "ssg-landers",
        "kt": "kt-wiz",
        "hanwha": "hanwha-eagles",
        "samsung": "samsung-lions",
        "kia": "kia-tigers",
        "lotte": "lotte-giants",
        "nc": "nc-dinos"
    ]

    static func team(id: String?) -> KBOTeam? {
        guard let id else { return nil }
        let normalizedID = legacyIDMap[id] ?? id
        return teams.first { $0.id == normalizedID && $0.active }
    }

    static func normalizedTeamID(_ id: String?) -> String? {
        guard let id else { return nil }
        return legacyIDMap[id] ?? id
    }

    static func team(named name: String) -> KBOTeam? {
        teams.first { $0.name == name || $0.shortName == name }
    }

    static let stadiums = [
        "잠실야구장",
        "고척스카이돔",
        "인천 SSG 랜더스필드",
        "수원 KT 위즈파크",
        "대전 한화생명 볼파크",
        "대구 삼성 라이온즈 파크",
        "광주 KIA 챔피언스 필드",
        "사직야구장",
        "창원 NC 파크"
    ]
}

struct AttendanceLogViewState: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let dateText: String
    let matchup: String
    let stadium: String
    let result: GameResult
    let ourScore: Int?
    let opponentScore: Int?
    let seat: String
    let companion: String
    let memo: String
    let caption: String
    let diary: String
    let tags: [String]
    let photoLocalRefs: [String]
    var gameSource: String? = nil
    var linkedKBOGameID: String? = nil
    var officialRecordURL: String? = nil

    /// Favorite-team score. Kept as `ourScore` for current API compatibility.
    var scoreText: String {
        guard let ourScore, let opponentScore else { return result.title }
        return "\(ourScore):\(opponentScore)"
    }

    var resultScoreText: String {
        guard result != .canceled else { return "취소" }
        guard ourScore != nil, opponentScore != nil else { return result.title }
        return "\(scoreText) \(result.title)"
    }

    var accessibilitySummary: String {
        "\(dateText), \(matchup), \(result.title), \(scoreText), \(stadium), \(memo)"
    }

    var subtleSourceLabel: String? {
        switch KBODataSource(serverValue: gameSource) {
        case .adminSchedule, .adminResult, .adminImport:
            return "참고용 경기 정보"
        case .manualSeed, .unavailable, .unknown:
            return nil
        case .official:
            return "참고용 경기 정보"
        case .provider:
            return "참고용 경기 정보"
        case .scrapedDev:
            return "자동 입력 보조 정보"
        }
    }
}

struct HomeDashboardViewState {
    let title: String
    let subtitle: String
    let fairyIndex: String
    let fairyLabel: String
    let fairyFootnote: String
    let metrics: [MetricViewState]
    let recentLogs: [AttendanceLogViewState]
    let isEmpty: Bool

    static func sample(logs: [AttendanceLogViewState] = AttendanceLogSample.logs) -> HomeDashboardViewState {
        guard !logs.isEmpty else { return .empty }
        let wins = logs.filter { $0.result == .win }.count
        let losses = logs.filter { $0.result == .loss }.count
        let draws = logs.filter { $0.result == .draw }.count
        let canceled = logs.filter { $0.result == .canceled }.count
        let decided = wins + losses
        let winRate = decided == 0 ? 0 : Int((Double(wins) / Double(decided) * 100).rounded())
        let indexService = VictoryFairyIndexService()
        let index = indexService.index(wins: wins, losses: losses)
        let topStadium = Dictionary(grouping: logs, by: \.stadium)
            .max { $0.value.count < $1.value.count }
            .map { "\($0.key) \($0.value.count)회" } ?? "-"
        let recentFlow = logs
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map(\.result.title)
            .joined(separator: " ")

        return HomeDashboardViewState(
            title: "오늘의 승리요정",
            subtitle: "내 직관 기록으로 보는 이번 시즌",
            fairyIndex: index.map(String.init) ?? "-",
            fairyLabel: indexService.grade(index: index),
            fairyFootnote: "\(logs.count)경기 기준",
            metrics: [
                .init(title: "총 직관", value: "\(logs.count)경기", detail: "무 \(draws) · 취소 \(canceled)"),
                .init(title: "시즌 승률", value: "\(winRate)%", detail: "승패 기준"),
                .init(title: "최근 흐름", value: recentFlow.isEmpty ? "-" : recentFlow, detail: "최근 5경기"),
                .init(title: "최다 구장", value: topStadium, detail: "직관 기준")
            ],
            recentLogs: Array(logs.sorted { $0.date > $1.date }.prefix(1)),
            isEmpty: logs.isEmpty
        )
    }

    static let empty = HomeDashboardViewState(
        title: "오늘의 승리요정",
        subtitle: "내 직관 기록으로 보는 이번 시즌",
        fairyIndex: "-",
        fairyLabel: "표본 수집 중",
        fairyFootnote: "0경기 기준",
        metrics: [],
        recentLogs: [],
        isEmpty: true
    )
}

struct MetricViewState: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
}

struct RankingViewState: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let trailing: String
}

struct StatGroupViewState: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let winRate: Int?
    let latestDate: Date?
    let latestDateText: String

    var decidedGames: Int { wins + losses }
    var winRateText: String { winRate.map { "\($0)%" } ?? "-" }
    var recordText: String { "\(wins)승 \(losses)패 \(draws)무 \(canceled)취소" }
    var isSmallSample: Bool { decidedGames < 3 }
}

struct StatisticsViewState {
    let season: Int
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let kpis: [MetricViewState]
    let recentResults: [GameResult]
    let stadiumRankings: [RankingViewState]
    let opponentRankings: [RankingViewState]
    let stadiumStats: [StatGroupViewState]
    let opponentStats: [StatGroupViewState]
    let kboStandings: [KBOStandingViewState]
    let kboSourceText: String?
    let kboDisclosureText: String?
    let kboUpdatedText: String
    let kboSource: KBOStandingsSource

    static let sample = StatisticsViewState(
        season: 2026,
        totalGames: 5,
        wins: 3,
        losses: 1,
        draws: 1,
        canceled: 0,
        kpis: [
            .init(title: "전체 승률", value: "62%", detail: "승패 기준"),
            .init(title: "총 직관", value: "5경기", detail: "2026 시즌"),
            .init(title: "평균 득점", value: "5.2", detail: "득점"),
            .init(title: "평균 실점", value: "3.8", detail: "실점"),
            .init(title: "현재 흐름", value: "2연승", detail: "최근 직관")
        ],
        recentResults: [.win, .win, .loss, .draw, .win],
        stadiumRankings: [
            .init(title: "잠실야구장", subtitle: "8회 방문", trailing: "승률 71%"),
            .init(title: "대전 한화생명 볼파크", subtitle: "2회 방문", trailing: "승률 50%")
        ],
        opponentRankings: [
            .init(title: "KIA", subtitle: "4회 상대", trailing: "승률 75%"),
            .init(title: "두산", subtitle: "3회 상대", trailing: "승률 33%")
        ],
        stadiumStats: [
            .init(name: "잠실야구장", totalGames: 8, wins: 5, losses: 2, draws: 1, canceled: 0, winRate: 71, latestDate: .now, latestDateText: "최근 방문 \(DateFormatter.vfDisplayDate.string(from: .now))"),
            .init(name: "대전 한화생명 볼파크", totalGames: 2, wins: 1, losses: 1, draws: 0, canceled: 0, winRate: 50, latestDate: .now, latestDateText: "최근 방문 \(DateFormatter.vfDisplayDate.string(from: .now))")
        ],
        opponentStats: [
            .init(name: "KIA", totalGames: 4, wins: 3, losses: 1, draws: 0, canceled: 0, winRate: 75, latestDate: .now, latestDateText: "최근 경기 \(DateFormatter.vfDisplayDate.string(from: .now))"),
            .init(name: "두산", totalGames: 3, wins: 1, losses: 2, draws: 0, canceled: 0, winRate: 33, latestDate: .now, latestDateText: "최근 경기 \(DateFormatter.vfDisplayDate.string(from: .now))")
        ],
        kboStandings: [
            .init(rank: 1, teamName: "KIA 타이거즈", wins: 0, losses: 0, draws: 0, winRateText: "-", gamesBehindText: "-"),
            .init(rank: 2, teamName: "한화 이글스", wins: 0, losses: 0, draws: 0, winRateText: "-", gamesBehindText: "-")
        ],
        kboSourceText: "참고용 경기 정보",
        kboDisclosureText: "공식 기록은 KBO 공식 사이트에서 확인해 주세요.",
        kboUpdatedText: "최근 갱신: 2026.05.06 20:58",
        kboSource: .manualSeed
    )
}

enum KBOStandingsSource: String, Hashable {
    case manualSeed = "manual-seed"
    case adminResult = "admin-result"
    case adminImport = "admin-import"
    case official
    case provider
    case scrapedDev = "scraped-dev"
    case unavailable
    case unknown

    init(serverValue: String?) {
        switch serverValue {
        case "manual-seed": self = .manualSeed
        case "admin-result": self = .adminResult
        case "admin-import": self = .adminImport
        case "official": self = .official
        case "provider": self = .provider
        case "scraped-dev": self = .scrapedDev
        case "unavailable": self = .unavailable
        default: self = .unknown
        }
    }
}

enum KBODataSource: String, Hashable {
    case adminSchedule = "admin-schedule"
    case adminResult = "admin-result"
    case adminImport = "admin-import"
    case manualSeed = "manual-seed"
    case official
    case provider
    case scrapedDev = "scraped-dev"
    case unavailable
    case unknown

    init(serverValue: String?) {
        switch serverValue {
        case "admin-schedule": self = .adminSchedule
        case "admin-result": self = .adminResult
        case "admin-import": self = .adminImport
        case "manual-seed": self = .manualSeed
        case "official": self = .official
        case "provider": self = .provider
        case "scraped-dev": self = .scrapedDev
        case "unavailable": self = .unavailable
        default: self = .unknown
        }
    }

    var displayLabel: String {
        switch self {
        case .adminSchedule, .adminResult, .adminImport:
            return "참고용 경기 정보"
        case .manualSeed:
            return "참고용 경기 정보"
        case .official:
            return "참고용 경기 정보"
        case .provider:
            return "참고용 경기 정보"
        case .scrapedDev:
            return "자동 입력 보조 정보"
        case .unavailable, .unknown:
            return "참고용 경기 정보"
        }
    }
}

enum KBOReviewSafeSource {
    static func visibleLabel(sourceLabel: String?, source: String?) -> String {
        let trimmed = sourceLabel?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceType = KBODataSource(serverValue: source)

        if sourceType == .official || trimmed?.contains("공식") == true {
            return "참고용 경기 정보"
        }

        if sourceType == .scrapedDev || trimmed?.contains("개발") == true {
            return "자동 입력 보조 정보"
        }

        return trimmed?.nilIfEmpty ?? "참고용 경기 정보"
    }

    static func disclosure(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? "세부 기록은 KBO 관련 공식 채널에서 확인해 주세요."
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct KBOStandingViewState: Identifiable, Hashable {
    let id = UUID()
    let rank: Int
    let teamName: String
    let wins: Int
    let losses: Int
    let draws: Int
    let winRateText: String
    let gamesBehindText: String
}

enum AttendanceLogSample {
    static let logs: [AttendanceLogViewState] = [
        .init(
            id: sampleID("9D0F0CB8-1C7A-4F57-A0B3-14BE8748A001"),
            date: Date.vfDate(year: 2026, month: 4, day: 12),
            dateText: "2026.04.12",
            matchup: "한화 vs KIA",
            stadium: "잠실야구장",
            result: .loss,
            ourScore: 3,
            opponentScore: 9,
            seat: "1루 네이비석 204블록",
            companion: "친구",
            memo: "KIA가 9:3으로 승리했던 경기",
            caption: "KIA가 9:3으로 승리했다. 한화 입장에서는 아쉬운 패배였지만 응원 분위기는 오래 남았다.",
            diary: "오늘은 친구와 잠실야구장에서 한화 이글스 vs KIA 타이거즈 경기를 직관했다. 결과는 3:9 패배였지만, 경기장의 분위기와 응원은 오래 기억에 남을 것 같다.",
            tags: ["아쉬움", "응원 분위기"],
            photoLocalRefs: []
        ),
        .init(
            id: sampleID("9D0F0CB8-1C7A-4F57-A0B3-14BE8748A002"),
            date: Date.vfDate(year: 2026, month: 4, day: 5),
            dateText: "2026.04.05",
            matchup: "LG vs 두산",
            stadium: "잠실야구장",
            result: .loss,
            ourScore: 3,
            opponentScore: 5,
            seat: "1루 오렌지석",
            companion: "가족",
            memo: "끝까지 응원했던 잠실 더비",
            caption: "결과는 아쉬웠지만 응원석 분위기는 끝까지 뜨거웠다.",
            diary: "잠실 라이벌전다운 긴장감이 있었다. 결과는 패배였지만 응원석의 열기는 시즌 내내 기억날 것 같다.",
            tags: ["잠실 더비", "응원 분위기"],
            photoLocalRefs: []
        ),
        .init(
            id: sampleID("9D0F0CB8-1C7A-4F57-A0B3-14BE8748A003"),
            date: Date.vfDate(year: 2026, month: 3, day: 30),
            dateText: "2026.03.30",
            matchup: "LG vs 한화",
            stadium: "대전 한화생명 볼파크",
            result: .draw,
            ourScore: 4,
            opponentScore: 4,
            seat: "원정 응원석",
            companion: "혼자",
            memo: "원정 첫 경기라 더 기억에 남았던 날",
            caption: "원정 첫 경기라 더 기억에 남았다.",
            diary: "새 구장의 분위기가 낯설면서도 좋았다. 승부는 나지 않았지만 원정 직관의 재미를 제대로 느꼈다.",
            tags: ["원정", "첫 방문"],
            photoLocalRefs: []
        ),
        .init(
            id: sampleID("9D0F0CB8-1C7A-4F57-A0B3-14BE8748A004"),
            date: Date.vfDate(year: 2026, month: 3, day: 22),
            dateText: "2026.03.22",
            matchup: "LG vs 삼성",
            stadium: "대구 삼성 라이온즈 파크",
            result: .canceled,
            ourScore: nil,
            opponentScore: nil,
            seat: "원정 응원석",
            companion: "친구",
            memo: "비 때문에 아쉽게 취소된 원정",
            caption: "비 때문에 경기는 취소됐지만 다음 원정을 기약했다.",
            diary: "대구까지 내려간 원정이었지만 비로 경기가 열리지 못했다. 그래도 구장 주변 분위기를 느낀 것만으로도 기억에 남았다.",
            tags: ["우천 취소", "원정"],
            photoLocalRefs: []
        )
    ]

    private static func sampleID(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }
}

extension Date {
    static func vfDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.year = year
        components.month = month
        components.day = day
        return components.date ?? .now
    }
}
