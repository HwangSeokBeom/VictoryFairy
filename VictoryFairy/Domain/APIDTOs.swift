import Foundation

struct TeamDTO: Decodable, Identifiable {
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
}

struct PreferencesDTO: Decodable {
    let hasCompletedOnboarding: Bool?
    let favoriteTeamID: String?
    let teamThemeEnabled: Bool?
    let displayName: String?
    let selectedSeason: Int?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding
        case favoriteTeamID
        case teamThemeEnabled
        case displayName
        case selectedSeason
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
        favoriteTeamID = try container.decodeIfPresent(String.self, forKey: .favoriteTeamID)
        teamThemeEnabled = try container.decodeIfPresent(Bool.self, forKey: .teamThemeEnabled)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        selectedSeason = try container.decodeIfPresent(Int.self, forKey: .selectedSeason)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }
}

struct UpdatePreferencesRequest: Encodable {
    let hasCompletedOnboarding: Bool
    let favoriteTeamID: String?
    let teamThemeEnabled: Bool
    let displayName: String?
    var selectedSeason: Int? = nil
}

struct SeasonsDTO: Decodable {
    let currentSeason: Int?
    let items: [SeasonDTO]

    enum CodingKeys: String, CodingKey {
        case currentSeason
        case items
        case seasons
    }

    init(from decoder: Decoder) throws {
        if let array = try? [SeasonDTO](from: decoder) {
            currentSeason = nil
            items = array
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentSeason = try container.decodeIfPresent(Int.self, forKey: .currentSeason)
        items = try container.decodeIfPresent([SeasonDTO].self, forKey: .items)
            ?? container.decodeIfPresent([SeasonDTO].self, forKey: .seasons)
            ?? []
    }
}

struct SeasonDTO: Decodable {
    let season: Int
    let label: String?
    let hasRecords: Bool?

    enum CodingKeys: String, CodingKey {
        case season
        case year
        case label
        case hasRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
            ?? container.decodeIfPresent(Int.self, forKey: .year)
            ?? Calendar.current.component(.year, from: .now)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        hasRecords = try container.decodeIfPresent(Bool.self, forKey: .hasRecords)
    }
}

struct AttendanceLogDTO: Decodable, Identifiable {
    let id: String
    let gameDate: String
    let season: Int?
    let favoriteTeamID: String?
    let opponentTeamID: String?
    let stadiumName: String
    let result: String
    let ourScore: Int?
    let opponentScore: Int?
    let seatText: String?
    let companionType: String?
    let shortMemo: String?
    let diaryText: String?
    let moodTags: [String]
    let highlightTags: [String]
    let photoLocalRefs: [String]
    let gameSource: String?
    let linkedKBOGameID: String?
    let officialRecordURL: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gameDate
        case date
        case season
        case favoriteTeamID
        case opponentTeamID
        case stadiumName
        case stadium
        case result
        case ourScore
        case opponentScore
        case seatText
        case seat
        case companionType
        case companion
        case shortMemo
        case memo
        case diaryText
        case diary
        case moodTags
        case highlightTags
        case tags
        case photoLocalRefs
        case gameSource
        case source
        case linkedKBOGameID
        case kboGameID
        case officialRecordURL
        case kboRecordURL
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        gameDate = try container.decodeIfPresent(String.self, forKey: .gameDate)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? DateFormatter.vfAPIDate.string(from: .now)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        favoriteTeamID = try container.decodeIfPresent(String.self, forKey: .favoriteTeamID)
        opponentTeamID = try container.decodeIfPresent(String.self, forKey: .opponentTeamID)
        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName)
            ?? container.decodeIfPresent(String.self, forKey: .stadium)
            ?? "구장 미정"
        result = try container.decodeIfPresent(String.self, forKey: .result) ?? "win"
        ourScore = try container.decodeIfPresent(Int.self, forKey: .ourScore)
        opponentScore = try container.decodeIfPresent(Int.self, forKey: .opponentScore)
        seatText = try container.decodeIfPresent(String.self, forKey: .seatText)
            ?? container.decodeIfPresent(String.self, forKey: .seat)
        companionType = try container.decodeIfPresent(String.self, forKey: .companionType)
            ?? container.decodeIfPresent(String.self, forKey: .companion)
        shortMemo = try container.decodeIfPresent(String.self, forKey: .shortMemo)
            ?? container.decodeIfPresent(String.self, forKey: .memo)
        diaryText = try container.decodeIfPresent(String.self, forKey: .diaryText)
            ?? container.decodeIfPresent(String.self, forKey: .diary)
        moodTags = try container.decodeIfPresent([String].self, forKey: .moodTags)
            ?? container.decodeIfPresent([String].self, forKey: .tags)
            ?? []
        highlightTags = try container.decodeIfPresent([String].self, forKey: .highlightTags) ?? []
        photoLocalRefs = try container.decodeIfPresent([String].self, forKey: .photoLocalRefs) ?? []
        gameSource = try container.decodeIfPresent(String.self, forKey: .gameSource)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        linkedKBOGameID = try container.decodeIfPresent(String.self, forKey: .linkedKBOGameID)
            ?? container.decodeIfPresent(String.self, forKey: .kboGameID)
        officialRecordURL = try container.decodeIfPresent(String.self, forKey: .officialRecordURL)
            ?? container.decodeIfPresent(String.self, forKey: .kboRecordURL)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
    }

    static func matchupText(favoriteTeamID: String?, opponentTeamID: String?) -> String {
        let favorite = KBOSeed.team(id: favoriteTeamID)?.shortName ?? "우리팀"
        let opponent = KBOSeed.team(id: opponentTeamID)?.shortName ?? "상대팀"
        return "\(favorite) vs \(opponent)"
    }

    static func scoreText(result: String, ourScore: Int?, opponentScore: Int?) -> String {
        guard let ourScore, let opponentScore else {
            return GameResult(serverValue: result).title
        }
        return "\(ourScore):\(opponentScore) \(GameResult(serverValue: result).title)"
    }
}

struct CreateAttendanceLogRequest: Encodable {
    let gameDate: String
    let season: Int
    let favoriteTeamID: String
    let opponentTeamID: String
    let stadiumName: String
    let result: String
    let ourScore: Int?
    let opponentScore: Int?
    let seatText: String?
    let companionType: String?
    let shortMemo: String?
    let diaryText: String?
    let moodTags: [String]
    let highlightTags: [String]
    let photoLocalRefs: [String]
    var gameSource: String? = nil
    var linkedKBOGameID: String? = nil
    var officialRecordURL: String? = nil
}

struct UpdateAttendanceLogRequest: Encodable {
    let gameDate: String
    let season: Int
    let favoriteTeamID: String
    let opponentTeamID: String
    let stadiumName: String
    let result: String
    let ourScore: Int?
    let opponentScore: Int?
    let seatText: String?
    let companionType: String?
    let shortMemo: String?
    let diaryText: String?
    let moodTags: [String]
    let highlightTags: [String]
    let photoLocalRefs: [String]
    var gameSource: String? = nil
    var linkedKBOGameID: String? = nil
    var officialRecordURL: String? = nil
}

struct FeedItemDTO: Decodable, Identifiable {
    let id: String
    let gameDate: String
    let matchupText: String
    let scoreText: String
    let stadiumName: String
    let result: String
    let captionText: String
    let moodTags: [String]
    let highlightTags: [String]
    let hasDiary: Bool
    let hasPhotos: Bool
    let gameSource: String?
    let linkedKBOGameID: String?
    let officialRecordURL: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gameDate
        case date
        case favoriteTeamID
        case opponentTeamID
        case matchupText
        case scoreText
        case ourScore
        case opponentScore
        case stadiumName
        case result
        case captionText
        case shortMemo
        case memo
        case diaryText
        case moodTags
        case highlightTags
        case photoLocalRefs
        case hasDiary
        case hasPhotos
        case gameSource
        case source
        case linkedKBOGameID
        case kboGameID
        case officialRecordURL
        case kboRecordURL
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        gameDate = try container.decodeIfPresent(String.self, forKey: .gameDate)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? DateFormatter.vfAPIDate.string(from: .now)

        let favoriteTeamID = try container.decodeIfPresent(String.self, forKey: .favoriteTeamID)
        let opponentTeamID = try container.decodeIfPresent(String.self, forKey: .opponentTeamID)
        matchupText = try container.decodeIfPresent(String.self, forKey: .matchupText)
            ?? AttendanceLogDTO.matchupText(favoriteTeamID: favoriteTeamID, opponentTeamID: opponentTeamID)

        result = try container.decodeIfPresent(String.self, forKey: .result) ?? "win"
        let ourScore = try container.decodeIfPresent(Int.self, forKey: .ourScore)
        let opponentScore = try container.decodeIfPresent(Int.self, forKey: .opponentScore)
        scoreText = try container.decodeIfPresent(String.self, forKey: .scoreText)
            ?? AttendanceLogDTO.scoreText(result: result, ourScore: ourScore, opponentScore: opponentScore)

        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName) ?? "구장 미정"
        let diaryText = try container.decodeIfPresent(String.self, forKey: .diaryText)
        let memo = try container.decodeIfPresent(String.self, forKey: .shortMemo)
            ?? container.decodeIfPresent(String.self, forKey: .memo)
        captionText = try container.decodeIfPresent(String.self, forKey: .captionText)
            ?? diaryText
            ?? memo
            ?? ""
        moodTags = try container.decodeIfPresent([String].self, forKey: .moodTags) ?? []
        highlightTags = try container.decodeIfPresent([String].self, forKey: .highlightTags) ?? []
        let photoLocalRefs = try container.decodeIfPresent([String].self, forKey: .photoLocalRefs) ?? []
        hasDiary = try container.decodeIfPresent(Bool.self, forKey: .hasDiary)
            ?? !(diaryText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        hasPhotos = try container.decodeIfPresent(Bool.self, forKey: .hasPhotos) ?? !photoLocalRefs.isEmpty
        gameSource = try container.decodeIfPresent(String.self, forKey: .gameSource)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        linkedKBOGameID = try container.decodeIfPresent(String.self, forKey: .linkedKBOGameID)
            ?? container.decodeIfPresent(String.self, forKey: .kboGameID)
        officialRecordURL = try container.decodeIfPresent(String.self, forKey: .officialRecordURL)
            ?? container.decodeIfPresent(String.self, forKey: .kboRecordURL)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

struct CalendarMonthDTO: Decodable {
    let year: Int
    let month: Int
    let summary: CalendarSummaryDTO
    let days: [CalendarDayDTO]
}

struct CalendarSummaryDTO: Decodable {
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
}

struct CalendarDayDTO: Decodable {
    let date: String
    let logs: [CalendarDayLogDTO]
}

struct CalendarDayLogDTO: Decodable, Identifiable {
    let id: String
    let matchupText: String
    let scoreText: String
    let stadiumName: String
    let result: String
    let shortMemo: String?
    let gameSource: String?
    let linkedKBOGameID: String?
    let officialRecordURL: String?
}

struct StatisticsSummaryDTO: Decodable {
    let season: Int
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let winRate: Double?
    let averageScored: Double?
    let averageAllowed: Double?
    let currentStreakText: String
    let victoryFairyIndex: Int?
    let victoryFairyGrade: String
    let recentResults: [String]

    enum CodingKeys: String, CodingKey {
        case season
        case totalGames
        case wins
        case losses
        case draws
        case canceled
        case winRate
        case averageScored
        case averageAllowed
        case currentStreakText
        case victoryFairyIndex
        case victoryFairyGrade
        case recentResults
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decodeIfPresent(Int.self, forKey: .season) ?? 2026
        totalGames = try container.decodeIfPresent(Int.self, forKey: .totalGames) ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        draws = try container.decodeIfPresent(Int.self, forKey: .draws) ?? 0
        canceled = try container.decodeIfPresent(Int.self, forKey: .canceled) ?? 0
        winRate = try container.decodeIfPresent(Double.self, forKey: .winRate)
        averageScored = try container.decodeIfPresent(Double.self, forKey: .averageScored)
        averageAllowed = try container.decodeIfPresent(Double.self, forKey: .averageAllowed)
        currentStreakText = try container.decodeIfPresent(String.self, forKey: .currentStreakText) ?? "연승/연패 없음"
        victoryFairyIndex = try container.decodeIfPresent(Int.self, forKey: .victoryFairyIndex)
        victoryFairyGrade = try container.decodeIfPresent(String.self, forKey: .victoryFairyGrade) ?? "집계 중"
        recentResults = try container.decodeIfPresent([String].self, forKey: .recentResults) ?? []
    }
}

struct StadiumStatsDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let winRate: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case stadiumName
        case totalGames
        case visitCount
        case wins
        case losses
        case draws
        case canceled
        case winRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .stadiumName)
            ?? "구장 미정"
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? name
        totalGames = try container.decodeIfPresent(Int.self, forKey: .totalGames)
            ?? container.decodeIfPresent(Int.self, forKey: .visitCount)
            ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        draws = try container.decodeIfPresent(Int.self, forKey: .draws) ?? 0
        canceled = try container.decodeIfPresent(Int.self, forKey: .canceled) ?? 0
        winRate = try container.decodeIfPresent(Double.self, forKey: .winRate)
    }
}

struct OpponentStatsDTO: Decodable, Identifiable {
    let id: String
    let name: String
    let totalGames: Int
    let wins: Int
    let losses: Int
    let draws: Int
    let canceled: Int
    let winRate: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case opponentTeamID
        case name
        case teamName
        case totalGames
        case matchCount
        case wins
        case losses
        case draws
        case canceled
        case winRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .opponentTeamID)
            ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .teamName)
            ?? KBOSeed.team(id: id)?.name
            ?? "상대팀"
        totalGames = try container.decodeIfPresent(Int.self, forKey: .totalGames)
            ?? container.decodeIfPresent(Int.self, forKey: .matchCount)
            ?? 0
        wins = try container.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        losses = try container.decodeIfPresent(Int.self, forKey: .losses) ?? 0
        draws = try container.decodeIfPresent(Int.self, forKey: .draws) ?? 0
        canceled = try container.decodeIfPresent(Int.self, forKey: .canceled) ?? 0
        winRate = try container.decodeIfPresent(Double.self, forKey: .winRate)
    }
}

struct NewsResponse: Decodable {
    let items: [NewsItemDTO]
    let message: String?
    let sourceDisclosure: String?

    enum CodingKeys: String, CodingKey {
        case items
        case news
        case message
        case sourceDisclosure
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([NewsItemDTO].self, forKey: .items)
            ?? container.decodeIfPresent([NewsItemDTO].self, forKey: .news)
            ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
        sourceDisclosure = try container.decodeIfPresent(String.self, forKey: .sourceDisclosure)
    }
}

struct NewsItemDTO: Decodable, Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String?
    let sourceName: String?
    let publishedAt: String?
    let url: String?
    let teamIDs: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case sourceName
        case source
        case publishedAt
        case publishedDate
        case url
        case link
        case teamIDs
        case teamIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "제목 없는 소식"
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
            ?? container.decodeIfPresent(String.self, forKey: .source)
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt)
            ?? container.decodeIfPresent(String.self, forKey: .publishedDate)
        url = try container.decodeIfPresent(String.self, forKey: .url)
            ?? container.decodeIfPresent(String.self, forKey: .link)
        teamIDs = try container.decodeIfPresent([String].self, forKey: .teamIDs)
            ?? container.decodeIfPresent([String].self, forKey: .teamIds)
            ?? []
    }
}

struct MatchOutlookRequest: Encodable {
    let favoriteTeamID: String
    let opponentTeamID: String
    let date: String
    let stadiumName: String
}

struct MatchOutlookResponse: Decodable, Hashable {
    let title: String
    let summary: String
    let points: [String]
    let confidenceLabel: String?
    let disclaimer: String?

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case points
        case confidenceLabel
        case disclaimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "오늘의 관전 포인트"
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? "내 직관 기록과 참고용 경기 정보를 바탕으로 만든 응원 포인트예요."
        points = try container.decodeIfPresent([String].self, forKey: .points) ?? []
        confidenceLabel = try container.decodeIfPresent(String.self, forKey: .confidenceLabel)
        disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
    }

    init(title: String, summary: String, points: [String], confidenceLabel: String?, disclaimer: String?) {
        self.title = title
        self.summary = summary
        self.points = points
        self.confidenceLabel = confidenceLabel
        self.disclaimer = disclaimer
    }

    static let fallback = MatchOutlookResponse(
        title: "오늘의 관전 포인트",
        summary: "서버에서 경기 전망을 불러오지 못했어요. 내 직관 기록 기준의 응원 포인트는 준비되는 대로 표시할게요.",
        points: [
            "최근 직관 흐름과 상대 기록을 가볍게 비교해 보세요.",
            "경기 결과보다 오늘의 응원 포인트와 현장 분위기에 집중해요."
        ],
        confidenceLabel: "재미용",
        disclaimer: "공식 예측이나 베팅 정보가 아닙니다."
    )
}

struct CommunityPostsResponse: Decodable {
    let items: [CommunityPostDTO]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case items
        case posts
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([CommunityPostDTO].self, forKey: .items)
            ?? container.decodeIfPresent([CommunityPostDTO].self, forKey: .posts)
            ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct CommunityPostDTO: Decodable, Identifiable, Hashable {
    let id: String
    let authorDisplayName: String?
    let teamID: String?
    let body: String
    let createdAt: String?
    let reportable: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case authorDisplayName
        case displayName
        case teamID
        case teamId
        case body
        case content
        case createdAt
        case reportable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
            ?? container.decodeIfPresent(String.self, forKey: .displayName)
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
            ?? container.decodeIfPresent(String.self, forKey: .teamId)
        body = try container.decodeIfPresent(String.self, forKey: .body)
            ?? container.decodeIfPresent(String.self, forKey: .content)
            ?? ""
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        reportable = try container.decodeIfPresent(Bool.self, forKey: .reportable)
    }
}

struct CreateCommunityPostRequest: Encodable {
    let body: String
    let teamID: String?
}

struct KBOStandingsDTO: Decodable {
    let season: Int
    let source: String
    let sourceLabel: String?
    let sourceDisclosure: String?
    let updatedAt: String?
    let lastUpdatedAt: String?
    let collectedAt: String?
    let generatedAt: String?
    let items: [KBOStandingDTO]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case season
        case source
        case sourceLabel
        case sourceDisclosure
        case updatedAt
        case lastUpdatedAt
        case collectedAt
        case generatedAt
        case items
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        season = try container.decodeIfPresent(Int.self, forKey: .season) ?? 2026
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "unavailable"
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
        sourceDisclosure = try container.decodeIfPresent(String.self, forKey: .sourceDisclosure)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        lastUpdatedAt = try container.decodeIfPresent(String.self, forKey: .lastUpdatedAt)
        collectedAt = try container.decodeIfPresent(String.self, forKey: .collectedAt)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        items = try container.decodeIfPresent([KBOStandingDTO].self, forKey: .items) ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct KBOStandingDTO: Decodable, Identifiable {
    var id: String { teamID }
    let rank: Int
    let teamID: String
    let teamName: String
    let wins: Int
    let losses: Int
    let draws: Int
    let winRate: Double?
    let gamesBehind: Double?
    let updatedAt: String?
    let lastUpdatedAt: String?
    let collectedAt: String?
    let generatedAt: String?
}

struct KBOGameCandidatesDTO: Decodable {
    let date: String
    let teamID: String
    let source: String
    let sourceLabel: String?
    let sourceDisclosure: String?
    let items: [KBOGameCandidateDTO]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case date
        case teamID
        case source
        case sourceLabel
        case sourceDisclosure
        case items
        case games
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? DateFormatter.vfAPIDate.string(from: .now)
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "manual"
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
        sourceDisclosure = try container.decodeIfPresent(String.self, forKey: .sourceDisclosure)
        items = try container.decodeIfPresent([KBOGameCandidateDTO].self, forKey: .items)
            ?? container.decodeIfPresent([KBOGameCandidateDTO].self, forKey: .games)
            ?? []
        message = try container.decodeIfPresent(String.self, forKey: .message)
    }
}

struct KBOOfficialLinksDTO: Decodable, Hashable {
    let kboGameCenterURL: String?
    let kboRecordURL: String?
}

struct KBOAttendanceSuggestionDTO: Decodable, Hashable {
    let favoriteTeamID: String?
    let opponentTeamID: String?
    let stadiumName: String?
    let result: String?
    let ourScore: Int?
    let opponentScore: Int?
    let scoreText: String?
    let matchupText: String?
    let shortMemo: String?
    let diaryTemplate: String?
    let highlightTags: [String]

    enum CodingKeys: String, CodingKey {
        case favoriteTeamID
        case opponentTeamID
        case stadiumName
        case result
        case ourScore
        case opponentScore
        case scoreText
        case matchupText
        case shortMemo
        case diaryTemplate
        case highlightTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        favoriteTeamID = try container.decodeIfPresent(String.self, forKey: .favoriteTeamID)
        opponentTeamID = try container.decodeIfPresent(String.self, forKey: .opponentTeamID)
        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName)
        result = try container.decodeIfPresent(String.self, forKey: .result)
        ourScore = try container.decodeIfPresent(Int.self, forKey: .ourScore)
        opponentScore = try container.decodeIfPresent(Int.self, forKey: .opponentScore)
        scoreText = try container.decodeIfPresent(String.self, forKey: .scoreText)
        matchupText = try container.decodeIfPresent(String.self, forKey: .matchupText)
        shortMemo = try container.decodeIfPresent(String.self, forKey: .shortMemo)
        diaryTemplate = try container.decodeIfPresent(String.self, forKey: .diaryTemplate)
        highlightTags = try container.decodeIfPresent([String].self, forKey: .highlightTags) ?? []
    }
}

struct KBOGameCandidateDTO: Decodable, Identifiable, Hashable {
    var id: String { gameID }
    let gameID: String
    let date: String
    let season: Int?
    let homeTeamID: String
    let awayTeamID: String
    let homeTeamName: String
    let awayTeamName: String
    let stadiumName: String
    let status: String
    let homeScore: Int?
    let awayScore: Int?
    let winnerTeamID: String?
    let source: String?
    let sourceLabel: String?
    let sourceDisclosure: String?
    let officialLinks: KBOOfficialLinksDTO?
    let attendanceSuggestion: KBOAttendanceSuggestionDTO?
    let resultSummary: String?
    let highlightTags: [String]

    enum CodingKeys: String, CodingKey {
        case gameID
        case date
        case season
        case homeTeamID
        case awayTeamID
        case homeTeamName
        case awayTeamName
        case stadiumName
        case status
        case homeScore
        case awayScore
        case winnerTeamID
        case source
        case sourceLabel
        case sourceDisclosure
        case officialLinks
        case attendanceSuggestion
        case resultSummary
        case highlightTags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameID = try container.decodeIfPresent(String.self, forKey: .gameID) ?? UUID().uuidString
        date = try container.decodeIfPresent(String.self, forKey: .date) ?? DateFormatter.vfAPIDate.string(from: .now)
        season = try container.decodeIfPresent(Int.self, forKey: .season)
        homeTeamID = try container.decodeIfPresent(String.self, forKey: .homeTeamID) ?? ""
        awayTeamID = try container.decodeIfPresent(String.self, forKey: .awayTeamID) ?? ""
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName)
            ?? KBOSeed.team(id: homeTeamID)?.name
            ?? "홈팀"
        awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName)
            ?? KBOSeed.team(id: awayTeamID)?.name
            ?? "원정팀"
        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName) ?? "구장 미정"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        homeScore = try container.decodeIfPresent(Int.self, forKey: .homeScore)
        awayScore = try container.decodeIfPresent(Int.self, forKey: .awayScore)
        winnerTeamID = try container.decodeIfPresent(String.self, forKey: .winnerTeamID)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sourceLabel = try container.decodeIfPresent(String.self, forKey: .sourceLabel)
        sourceDisclosure = try container.decodeIfPresent(String.self, forKey: .sourceDisclosure)
        officialLinks = try container.decodeIfPresent(KBOOfficialLinksDTO.self, forKey: .officialLinks)
        attendanceSuggestion = try container.decodeIfPresent(KBOAttendanceSuggestionDTO.self, forKey: .attendanceSuggestion)
        resultSummary = try container.decodeIfPresent(String.self, forKey: .resultSummary)
        highlightTags = try container.decodeIfPresent([String].self, forKey: .highlightTags) ?? []
    }
}

struct DiaryDraftRequest: Encodable {
    let gameDate: String
    let favoriteTeamName: String
    let opponentTeamName: String
    let stadiumName: String
    let result: String
    let scoreText: String
    let moodTags: [String]
    let highlightTags: [String]
    let companionType: String?
    let tone: String
    let extraNoteSanitized: String?
    let locale: String
}

struct DiaryDraftDTO: Decodable {
    let draftText: String
    let summaryText: String?
    let shareText: String?
    let hashtags: [String]
    let model: String?
    let safetyNotice: String?
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case draftText
        case diaryText
        case summaryText
        case shareText
        case hashtags
        case model
        case safetyNotice
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        draftText = try container.decodeIfPresent(String.self, forKey: .draftText)
            ?? container.decodeIfPresent(String.self, forKey: .diaryText)
            ?? ""
        summaryText = try container.decodeIfPresent(String.self, forKey: .summaryText)
        shareText = try container.decodeIfPresent(String.self, forKey: .shareText)
        hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        model = try container.decodeIfPresent(String.self, forKey: .model)
        safetyNotice = try container.decodeIfPresent(String.self, forKey: .safetyNotice)
            ?? container.decodeIfPresent([String].self, forKey: .warnings)?.first
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

typealias DiaryDraftResponse = DiaryDraftDTO

struct TemplateDraftRequest: Encodable {
    let gameDate: String
    let favoriteTeamName: String
    let opponentTeamName: String
    let stadiumName: String
    let result: String
    let scoreText: String
    let moodTags: [String]
    let highlightTags: [String]
    let companionType: String?
    let tone: String
    let extraNoteSanitized: String?
    let locale: String
}

struct TemplateDraftResponse: Decodable {
    let draftText: String
    let summaryText: String?
    let shareText: String?
    let hashtags: [String]
    let safetyNotice: String?

    enum CodingKeys: String, CodingKey {
        case draftText
        case diaryText
        case summaryText
        case shareText
        case hashtags
        case safetyNotice
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        draftText = try container.decodeIfPresent(String.self, forKey: .draftText)
            ?? container.decodeIfPresent(String.self, forKey: .diaryText)
            ?? ""
        summaryText = try container.decodeIfPresent(String.self, forKey: .summaryText)
        shareText = try container.decodeIfPresent(String.self, forKey: .shareText)
        hashtags = try container.decodeIfPresent([String].self, forKey: .hashtags) ?? []
        safetyNotice = try container.decodeIfPresent(String.self, forKey: .safetyNotice)
    }

    var diaryDraft: DiaryDraftDTO {
        DiaryDraftDTO(
            draftText: draftText,
            summaryText: summaryText,
            shareText: shareText,
            hashtags: hashtags,
            model: "template",
            safetyNotice: safetyNotice,
            warnings: []
        )
    }
}

extension DiaryDraftDTO {
    init(
        draftText: String,
        summaryText: String?,
        shareText: String?,
        hashtags: [String],
        model: String?,
        safetyNotice: String?,
        warnings: [String]
    ) {
        self.draftText = draftText
        self.summaryText = summaryText
        self.shareText = shareText
        self.hashtags = hashtags
        self.model = model
        self.safetyNotice = safetyNotice
        self.warnings = warnings
    }
}

struct TicketParseOCRTextRequest: Encodable {
    let ocrText: String
    let locale: String
}

typealias TicketOCRParseRequest = TicketParseOCRTextRequest

struct TicketParseOCRTextDTO: Decodable {
    let gameDate: String?
    let favoriteTeamName: String?
    let opponentTeamName: String?
    let stadiumName: String?
    let seatText: String?
    let confidence: Double?
    let warnings: [TicketParseWarning]
    let teamCandidates: [TicketCandidate]

    enum CodingKeys: String, CodingKey {
        case gameDate
        case date
        case favoriteTeamName
        case favoriteTeam
        case opponentTeamName
        case opponentTeam
        case stadiumName
        case stadium
        case seatText
        case seat
        case confidence
        case warnings
        case teamCandidates
        case candidates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gameDate = try container.decodeIfPresent(String.self, forKey: .gameDate)
            ?? container.decodeIfPresent(String.self, forKey: .date)
        favoriteTeamName = try container.decodeIfPresent(String.self, forKey: .favoriteTeamName)
            ?? container.decodeIfPresent(String.self, forKey: .favoriteTeam)
        opponentTeamName = try container.decodeIfPresent(String.self, forKey: .opponentTeamName)
            ?? container.decodeIfPresent(String.self, forKey: .opponentTeam)
        stadiumName = try container.decodeIfPresent(String.self, forKey: .stadiumName)
            ?? container.decodeIfPresent(String.self, forKey: .stadium)
        seatText = try container.decodeIfPresent(String.self, forKey: .seatText)
            ?? container.decodeIfPresent(String.self, forKey: .seat)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        warnings = try container.decodeIfPresent([TicketParseWarning].self, forKey: .warnings) ?? []
        teamCandidates = try container.decodeIfPresent([TicketCandidate].self, forKey: .teamCandidates)
            ?? container.decodeIfPresent([TicketCandidate].self, forKey: .candidates)
            ?? []
    }
}

typealias TicketOCRParseResponse = TicketParseOCRTextDTO

struct TicketCandidate: Decodable, Hashable, Identifiable {
    var id: String { [teamID, teamName, role].compactMap(\.self).joined(separator: "-") }
    let teamID: String?
    let teamName: String?
    let role: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case teamID
        case id
        case teamName
        case name
        case role
        case confidence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
            ?? container.decodeIfPresent(String.self, forKey: .id)
        teamName = try container.decodeIfPresent(String.self, forKey: .teamName)
            ?? container.decodeIfPresent(String.self, forKey: .name)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
    }
}

struct TicketParseWarning: Decodable, Hashable, Identifiable {
    var id: String { code ?? message }
    let code: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case code
        case message
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let value = try? container.decode(String.self) {
            code = nil
            message = value
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? "확인이 필요해요."
    }
}

struct PhotoAnalysisDTO: Decodable {
    let summaryText: String?
    let suggestedMoodTags: [String]
    let suggestedHighlightTags: [String]
    let diaryHintText: String?

    enum CodingKeys: String, CodingKey {
        case summaryText
        case suggestedMoodTags
        case suggestedHighlightTags
        case diaryHintText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summaryText = try container.decodeIfPresent(String.self, forKey: .summaryText)
        suggestedMoodTags = try container.decodeIfPresent([String].self, forKey: .suggestedMoodTags) ?? []
        suggestedHighlightTags = try container.decodeIfPresent([String].self, forKey: .suggestedHighlightTags) ?? []
        diaryHintText = try container.decodeIfPresent(String.self, forKey: .diaryHintText)
    }
}

struct FlexibleListDTO<Element: Decodable>: Decodable {
    let items: [Element]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case logs
        case feed
        case teams
        case stadiums
        case opponents
        case data
        case nextCursor
    }

    init(from decoder: Decoder) throws {
        if let array = try? [Element](from: decoder) {
            items = array
            nextCursor = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([Element].self, forKey: .items)
            ?? container.decodeIfPresent([Element].self, forKey: .logs)
            ?? container.decodeIfPresent([Element].self, forKey: .feed)
            ?? container.decodeIfPresent([Element].self, forKey: .teams)
            ?? container.decodeIfPresent([Element].self, forKey: .stadiums)
            ?? container.decodeIfPresent([Element].self, forKey: .opponents)
            ?? container.decodeIfPresent([Element].self, forKey: .data)
            ?? []
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}
