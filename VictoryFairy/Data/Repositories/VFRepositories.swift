import Foundation

protocol TeamRepository {
    func fetchTeams() async throws -> [KBOTeam]
}

protocol PreferencesRepository {
    func fetchPreferences() async throws -> PreferencesDTO
    func updatePreferences(_ request: UpdatePreferencesRequest) async throws -> PreferencesDTO
}

protocol SeasonRepository {
    func fetchSeasons() async throws -> SeasonsDTO
}

protocol AttendanceLogRepository {
    func fetchAttendanceLogs(season: Int) async throws -> [AttendanceLogViewState]
    func createAttendanceLog(_ request: CreateAttendanceLogRequest) async throws -> AttendanceLogViewState
    func updateAttendanceLog(id: String, request: UpdateAttendanceLogRequest) async throws -> AttendanceLogViewState
    func deleteAttendanceLog(id: String) async throws
}

protocol FeedRepository {
    func fetchFeed(season: Int, result: GameResult?) async throws -> [AttendanceLogViewState]
}

protocol CalendarRepository {
    func fetchCalendar(year: Int, month: Int) async throws -> [AttendanceLogViewState]
}

protocol StatisticsRepository {
    func fetchStatistics(season: Int) async throws -> StatisticsViewState
}

protocol KBOStandingsRepository {
    func fetchStandings(season: Int) async throws -> KBOStandingsDTO
}

protocol KBOGameRepository {
    func fetchGames(date: String, teamID: String) async throws -> KBOGameCandidatesDTO
}

protocol DiaryDraftRepository {
    func createDiaryDraft(_ request: DiaryDraftRequest) async throws -> DiaryDraftDTO
    func createTemplateDraft(_ request: TemplateDraftRequest) async throws -> TemplateDraftResponse
}

protocol TicketParserRepository {
    func parseOCRText(_ request: TicketParseOCRTextRequest) async throws -> TicketParseOCRTextDTO
}

protocol PhotoAnalysisRepository {
    func analyzePhotos(_ files: [MultipartFile], locale: String) async throws -> PhotoAnalysisDTO
}

protocol NewsRepository {
    func fetchNews(teamID: String?, limit: Int) async throws -> NewsResponse
}

protocol MatchOutlookRepository {
    func fetchOutlook(_ request: MatchOutlookRequest) async throws -> MatchOutlookResponse
}

protocol UserProfileRepository {
    func fetchProfile() async throws -> UserProfileDTO
    func createProfile(_ request: UpsertUserProfileRequest) async throws -> UserProfileDTO
    func updateProfile(_ request: UpsertUserProfileRequest) async throws -> UserProfileDTO
    func uploadProfileImage(data: Data, mimeType: String) async throws
    func deleteProfileImage() async throws
}

protocol LegalLinksRepository {
    func fetchLegalLinks() async throws -> LegalLinksDTO
}

protocol CommunityRepository {
    func fetchPosts() async throws -> CommunityPostsResponse
    func createPost(_ request: CreateCommunityPostRequest) async throws -> CommunityPostDTO
    func reportPost(id: String, reason: String) async throws
    func blockAuthor(authorID: String) async throws
    func unblockAuthor(authorID: String) async throws
    func fetchBlockedUsers() async throws -> BlockedUsersResponse
}

struct RemoteTeamRepository: TeamRepository {
    let apiClient: APIClient

    func fetchTeams() async throws -> [KBOTeam] {
        let response: FlexibleListDTO<TeamDTO> = try await apiClient.get("/api/v1/teams", requiresDeviceID: false)
        return response.items.map(TeamMapper.map).filter(\.active)
    }
}

struct RemotePreferencesRepository: PreferencesRepository {
    let apiClient: APIClient

    func fetchPreferences() async throws -> PreferencesDTO {
        try await apiClient.get("/api/v1/me/preferences")
    }

    func updatePreferences(_ request: UpdatePreferencesRequest) async throws -> PreferencesDTO {
        try await apiClient.put("/api/v1/me/preferences", body: request)
    }
}

struct RemoteSeasonRepository: SeasonRepository {
    let apiClient: APIClient

    func fetchSeasons() async throws -> SeasonsDTO {
        try await apiClient.get("/api/v1/seasons")
    }
}

struct RemoteAttendanceLogRepository: AttendanceLogRepository {
    let apiClient: APIClient

    func fetchAttendanceLogs(season: Int) async throws -> [AttendanceLogViewState] {
        let response: FlexibleListDTO<AttendanceLogDTO> = try await apiClient.get(
            "/api/v1/attendance-logs",
            queryItems: [URLQueryItem(name: "season", value: "\(season)")]
        )
        return response.items.map(AttendanceLogMapper.map)
    }

    func createAttendanceLog(_ request: CreateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        let response: AttendanceLogDTO = try await apiClient.post("/api/v1/attendance-logs", body: request)
        return AttendanceLogMapper.map(response)
    }

    func updateAttendanceLog(id: String, request: UpdateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        let response: AttendanceLogDTO = try await apiClient.put("/api/v1/attendance-logs/\(id)", body: request)
        return AttendanceLogMapper.map(response)
    }

    func deleteAttendanceLog(id: String) async throws {
        let _: EmptyAPIData = try await apiClient.delete("/api/v1/attendance-logs/\(id)")
    }
}

struct RemoteFeedRepository: FeedRepository {
    let apiClient: APIClient

    func fetchFeed(season: Int, result: GameResult? = nil) async throws -> [AttendanceLogViewState] {
        var queryItems = [URLQueryItem(name: "season", value: "\(season)")]
        if let result {
            queryItems.append(URLQueryItem(name: "result", value: result.serverValue))
        }
        let response: FlexibleListDTO<FeedItemDTO> = try await apiClient.get(
            "/api/v1/feed",
            queryItems: queryItems
        )
        return response.items.map(AttendanceLogMapper.map)
    }
}

struct RemoteCalendarRepository: CalendarRepository {
    let apiClient: APIClient

    func fetchCalendar(year: Int, month: Int) async throws -> [AttendanceLogViewState] {
        let response: CalendarMonthDTO = try await apiClient.get(
            "/api/v1/calendar",
            queryItems: [
                URLQueryItem(name: "year", value: "\(year)"),
                URLQueryItem(name: "month", value: "\(month)")
            ]
        )
        return response.days.flatMap { day in
            day.logs.map { AttendanceLogMapper.map($0, dateText: day.date) }
        }
    }
}

struct RemoteStatisticsRepository: StatisticsRepository {
    let apiClient: APIClient

    func fetchStatistics(season: Int) async throws -> StatisticsViewState {
        async let summary: StatisticsSummaryDTO = apiClient.get(
            "/api/v1/statistics/summary",
            queryItems: [URLQueryItem(name: "season", value: "\(season)")]
        )
        async let stadiums: FlexibleListDTO<StadiumStatsDTO> = apiClient.get(
            "/api/v1/statistics/stadiums",
            queryItems: [URLQueryItem(name: "season", value: "\(season)")]
        )
        async let opponents: FlexibleListDTO<OpponentStatsDTO> = apiClient.get(
            "/api/v1/statistics/opponents",
            queryItems: [URLQueryItem(name: "season", value: "\(season)")]
        )

        return try await StatisticsMapper.viewState(
            summary: summary,
            stadiums: stadiums.items,
            opponents: opponents.items
        )
    }
}

struct RemoteKBOStandingsRepository: KBOStandingsRepository {
    let apiClient: APIClient

    func fetchStandings(season: Int) async throws -> KBOStandingsDTO {
        try await apiClient.get(
            "/api/v1/kbo/standings",
            queryItems: [URLQueryItem(name: "season", value: "\(season)")]
        )
    }
}

struct RemoteKBOGameRepository: KBOGameRepository {
    let apiClient: APIClient

    func fetchGames(date: String, teamID: String) async throws -> KBOGameCandidatesDTO {
        try await apiClient.get(
            "/api/v1/kbo/games",
            queryItems: [
                URLQueryItem(name: "date", value: date),
                URLQueryItem(name: "teamID", value: teamID)
            ]
        )
    }
}

struct RemoteDiaryDraftRepository: DiaryDraftRepository {
    let apiClient: APIClient

    func createDiaryDraft(_ request: DiaryDraftRequest) async throws -> DiaryDraftDTO {
        try await apiClient.post("/api/v1/ai/diary-draft", body: request)
    }

    func createTemplateDraft(_ request: TemplateDraftRequest) async throws -> TemplateDraftResponse {
        try await apiClient.post("/api/v1/diary/template-draft", body: request)
    }
}

struct RemoteTicketParserRepository: TicketParserRepository {
    let apiClient: APIClient

    func parseOCRText(_ request: TicketParseOCRTextRequest) async throws -> TicketParseOCRTextDTO {
        try await apiClient.post("/api/v1/ticket/parse-ocr-text", body: request)
    }
}

struct RemotePhotoAnalysisRepository: PhotoAnalysisRepository {
    let apiClient: APIClient

    func analyzePhotos(_ files: [MultipartFile], locale: String) async throws -> PhotoAnalysisDTO {
        try await apiClient.postMultipart(
            "/api/v1/photos/analyze",
            fields: ["locale": locale],
            files: files
        )
    }
}

struct RemoteNewsRepository: NewsRepository {
    let apiClient: APIClient

    func fetchNews(teamID: String?, limit: Int) async throws -> NewsResponse {
        var queryItems: [URLQueryItem] = []
        if let teamID {
            queryItems.append(URLQueryItem(name: "teamID", value: teamID))
        }
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        return try await apiClient.get("/api/v1/news", queryItems: queryItems)
    }
}

struct RemoteMatchOutlookRepository: MatchOutlookRepository {
    let apiClient: APIClient

    func fetchOutlook(_ request: MatchOutlookRequest) async throws -> MatchOutlookResponse {
        try await apiClient.post("/api/v1/match-outlook", body: request)
    }
}

struct RemoteUserProfileRepository: UserProfileRepository {
    let apiClient: APIClient

    func fetchProfile() async throws -> UserProfileDTO {
        try await apiClient.get("/api/v1/me/profile")
    }

    func createProfile(_ request: UpsertUserProfileRequest) async throws -> UserProfileDTO {
        try await apiClient.post("/api/v1/me/profile", body: request)
    }

    func updateProfile(_ request: UpsertUserProfileRequest) async throws -> UserProfileDTO {
        try await apiClient.put("/api/v1/me/profile", body: request)
    }

    func uploadProfileImage(data: Data, mimeType: String) async throws {
        let file = MultipartFile(
            fieldName: "image",
            fileName: "profile-image.jpg",
            mimeType: mimeType,
            data: data
        )
        let _: EmptyAPIData = try await apiClient.postMultipart("/api/v1/me/profile/image", files: [file])
    }

    func deleteProfileImage() async throws {
        let _: EmptyAPIData = try await apiClient.delete("/api/v1/me/profile/image")
    }
}

struct RemoteLegalLinksRepository: LegalLinksRepository {
    let apiClient: APIClient

    func fetchLegalLinks() async throws -> LegalLinksDTO {
        try await apiClient.get("/api/v1/legal-links", requiresDeviceID: false)
    }
}

struct RemoteCommunityRepository: CommunityRepository {
    let apiClient: APIClient

    func fetchPosts() async throws -> CommunityPostsResponse {
        try await apiClient.get("/api/v1/community/posts")
    }

    func createPost(_ request: CreateCommunityPostRequest) async throws -> CommunityPostDTO {
        try await apiClient.post("/api/v1/community/posts", body: request)
    }

    func reportPost(id: String, reason: String) async throws {
        let _: EmptyAPIData = try await apiClient.post(
            "/api/v1/community/posts/\(id)/report",
            body: ReportCommunityPostRequest(reason: reason)
        )
    }

    func blockAuthor(authorID: String) async throws {
        let _: EmptyAPIData = try await apiClient.post("/api/v1/community/users/\(authorID)/block", body: EmptyAPIData())
    }

    func unblockAuthor(authorID: String) async throws {
        let _: EmptyAPIData = try await apiClient.delete("/api/v1/community/users/\(authorID)/block")
    }

    func fetchBlockedUsers() async throws -> BlockedUsersResponse {
        try await apiClient.get("/api/v1/community/blocked-users")
    }
}

struct SampleTeamRepository: TeamRepository {
    func fetchTeams() async throws -> [KBOTeam] {
        KBOSeed.teams
    }
}

struct SampleAttendanceLogRepository: AttendanceLogRepository, FeedRepository, CalendarRepository {
    func fetchAttendanceLogs(season: Int) async throws -> [AttendanceLogViewState] {
        AttendanceLogSample.logs
    }

    func createAttendanceLog(_ request: CreateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        request.localViewState
    }

    func updateAttendanceLog(id: String, request: UpdateAttendanceLogRequest) async throws -> AttendanceLogViewState {
        AttendanceLogSample.logs.first { $0.id.uuidString == id } ?? request.localViewState
    }

    func deleteAttendanceLog(id: String) async throws {}

    func fetchFeed(season: Int, result: GameResult? = nil) async throws -> [AttendanceLogViewState] {
        guard let result else { return AttendanceLogSample.logs }
        return AttendanceLogSample.logs.filter { $0.result == result }
    }

    func fetchCalendar(year: Int, month: Int) async throws -> [AttendanceLogViewState] {
        AttendanceLogSample.logs
    }
}

struct SampleStatisticsRepository: StatisticsRepository {
    func fetchStatistics(season: Int) async throws -> StatisticsViewState {
        .sample
    }
}

extension CreateAttendanceLogRequest {
    var localViewState: AttendanceLogViewState {
        AttendanceLogMapper.map(AttendanceLogMapper.entity(from: self))
    }
}

extension UpdateAttendanceLogRequest {
    var localViewState: AttendanceLogViewState {
        let createRequest = CreateAttendanceLogRequest(
            gameDate: gameDate,
            season: season,
            favoriteTeamID: favoriteTeamID,
            opponentTeamID: opponentTeamID,
            stadiumName: stadiumName,
            result: result,
            ourScore: ourScore,
            opponentScore: opponentScore,
            seatText: seatText,
            companionType: companionType,
            shortMemo: shortMemo,
            diaryText: diaryText,
            moodTags: moodTags,
            highlightTags: highlightTags,
            photoLocalRefs: photoLocalRefs,
            gameSource: gameSource,
            linkedKBOGameID: linkedKBOGameID,
            officialRecordURL: officialRecordURL
        )
        return createRequest.localViewState
    }
}

extension GameResult {
    init(serverValue: String?) {
        switch serverValue?.lowercased() {
        case "win", "w", "승":
            self = .win
        case "loss", "lose", "l", "패":
            self = .loss
        case "draw", "tie", "d", "무":
            self = .draw
        case "canceled", "cancelled", "cancel", "취소":
            self = .canceled
        default:
            self = .win
        }
    }

    var serverValue: String {
        switch self {
        case .win: "win"
        case .loss: "loss"
        case .draw: "draw"
        case .canceled: "canceled"
        }
    }
}

extension Date {
    static func vfParseServerDate(_ value: String) -> Date {
        if let date = ISO8601DateFormatter().date(from: value) {
            return date
        }
        if let date = DateFormatter.vfAPIDate.date(from: value) {
            return date
        }
        return .now
    }
}

extension DateFormatter {
    static let vfAPIDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let vfDisplayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    static let vfDisplayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()
}
