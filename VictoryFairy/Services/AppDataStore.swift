import Foundation

enum RemoteDataState: Equatable {
    case loading
    case loaded
    case empty
    case localOnly(String)
    case serverErrorUsingLocal(String)
    case error(String)

    var isFallback: Bool {
        if case .localOnly = self {
            return true
        }
        if case .serverErrorUsingLocal = self {
            return true
        }
        return false
    }
}

enum ServerConnectionStatus: Equatable {
    case checking
    case connected
    case localMode(String)

    var title: String {
        switch self {
        case .checking:
            return "서버 연결 확인 중"
        case .connected:
            return "서버 연결됨"
        case .localMode:
            return "로컬 모드"
        }
    }
}

@MainActor
final class AppDataStore: ObservableObject {
    @Published private(set) var teams: [KBOTeam]
    // 홈 대시보드는 feedLogs가 바뀔 때만 다시 집계한다. 이전에는 MainTabView.body가
    // 평가될 때마다 HomeViewModel(dashboard: .sample(logs:))로 40건 정렬·그룹핑을 다시 돌렸다.
    @Published private(set) var feedLogs: [AttendanceLogViewState] {
        didSet { homeDashboard = .sample(logs: feedLogs) }
    }
    @Published private(set) var homeDashboard: HomeDashboardViewState = .empty
    @Published private(set) var calendarLogs: [AttendanceLogViewState]
    @Published private(set) var statistics: StatisticsViewState
    @Published private(set) var serverStatus: ServerConnectionStatus = .checking
    @Published private(set) var feedState: RemoteDataState = .loading
    @Published private(set) var calendarState: RemoteDataState = .loading
    @Published private(set) var statisticsState: RemoteDataState = .loading
    @Published private(set) var lastSaveMessage: String?
    @Published private(set) var selectedFeedResultFilter: FeedResultFilter = .all
    // 캘린더 픽스처는 시작 달만 정한다. 그 뒤의 이동은 제품 경로 그대로 동작한다.
    // 매 렌더마다 값을 덮어쓰면 달 이동 자체가 불가능해진다.
    @Published private(set) var selectedCalendarMonth: Date =
        VFUITestConfiguration.initialCalendarMonth(Date.vfDate(year: 2026, month: 4, day: 1))
    @Published private(set) var selectedSeason: Int
    @Published private(set) var availableSeasons: [SeasonOption]
    @Published private(set) var userProfile: UserProfileDTO?
    @Published private(set) var legalLinks: LegalLinksDTO = .fallback

    private let preferences: UserPreferencesStore
    private let apiClient: APIClient
    private let teamRepository: TeamRepository
    private let preferencesRepository: PreferencesRepository
    private let seasonRepository: SeasonRepository
    private let attendanceLogRepository: AttendanceLogRepository
    private let feedRepository: FeedRepository
    private let calendarRepository: CalendarRepository
    private let statisticsRepository: StatisticsRepository
    private let kboStandingsRepository: KBOStandingsRepository
    private let kboGameRepository: KBOGameRepository
    private let diaryDraftRepository: DiaryDraftRepository
    private let photoAnalysisRepository: PhotoAnalysisRepository
    private let newsRepository: NewsRepository
    private let matchOutlookRepository: MatchOutlookRepository
    private let userProfileRepository: UserProfileRepository
    private let legalLinksRepository: LegalLinksRepository
    private let communityRepository: CommunityRepository
    private let localAttendanceLogRepository: LocalAttendanceLogRepository?
    private var didLoadInitialData = false
    private var isInitialLoadInFlight = false
    private var feedRefreshKeyInFlight: String?
    private var statisticsRefreshSeasonInFlight: Int?
    private var lastFallbackLogKey: String?
    private var remoteSelectedSeasonSupported = false
    private var didLoadUserProfile = false
    private var didLoadLegalLinks = false

    private var activeSeason: Int { selectedSeason }

    init(
        preferences: UserPreferencesStore,
        apiClient: APIClient = APIClient()
    ) {
        self.preferences = preferences
        self.apiClient = apiClient
        teamRepository = RemoteTeamRepository(apiClient: apiClient)
        preferencesRepository = RemotePreferencesRepository(apiClient: apiClient)
        seasonRepository = RemoteSeasonRepository(apiClient: apiClient)
        attendanceLogRepository = RemoteAttendanceLogRepository(apiClient: apiClient)
        feedRepository = RemoteFeedRepository(apiClient: apiClient)
        calendarRepository = RemoteCalendarRepository(apiClient: apiClient)
        statisticsRepository = RemoteStatisticsRepository(apiClient: apiClient)
        kboStandingsRepository = RemoteKBOStandingsRepository(apiClient: apiClient)
        kboGameRepository = RemoteKBOGameRepository(apiClient: apiClient)
        diaryDraftRepository = RemoteDiaryDraftRepository(apiClient: apiClient)
        photoAnalysisRepository = RemotePhotoAnalysisRepository(apiClient: apiClient)
        newsRepository = RemoteNewsRepository(apiClient: apiClient)
        matchOutlookRepository = RemoteMatchOutlookRepository(apiClient: apiClient)
        userProfileRepository = RemoteUserProfileRepository(apiClient: apiClient)
        legalLinksRepository = RemoteLegalLinksRepository(apiClient: apiClient)
        communityRepository = RemoteCommunityRepository(apiClient: apiClient)
        localAttendanceLogRepository = SwiftDataContainer.makeAttendanceLogRepository()
        selectedSeason = preferences.selectedSeason
        availableSeasons = [SeasonOption(season: preferences.selectedSeason, hasRecords: true)]
        teams = KBOSeed.teams
        feedLogs = []
        calendarLogs = []
        statistics = StatisticsService().summary(logs: [], season: preferences.selectedSeason)
        selectedCalendarMonth = Self.monthStart(year: preferences.selectedSeason, matching: selectedCalendarMonth)
    }

    // 서버 상태는 요청이 성공/실패할 때마다 대입되는데, 값이 바뀌지 않아도
    // @Published가 발행돼 구독자를 깨웠다. 값이 실제로 바뀔 때만 대입한다.
    private func setServerStatus(_ newValue: ServerConnectionStatus) {
        guard newValue != serverStatus else { return }
        serverStatus = newValue
    }

    func loadInitialDataIfNeeded() async {
        guard !didLoadInitialData else { return }
        guard !isInitialLoadInFlight else { return }
        isInitialLoadInFlight = true
        defer { isInitialLoadInFlight = false }
        didLoadInitialData = true
        await refreshAll()
    }

    func refreshAll() async {
        setServerStatus(.checking)
        // 선행 요청을 모두 동시에 받는다. preferences와 seasons는 서로의 응답을
        // 소비하지 않으므로 병렬로 받고, selectedSeason 계열 쓰기는 두 응답이
        // 모두 도착한 뒤 applySeasonResolution에서 1회만 수행한다.
        async let profile: Void = loadUserProfileIfNeeded()
        async let legal: Void = loadLegalLinksIfNeeded()
        async let teams: Void = refreshTeams()
        async let remotePreferences = loadRemotePreferences()
        async let remoteSeasons = loadRemoteSeasons()
        let (preferencesResult, seasonsResult) = await (remotePreferences, remoteSeasons)
        await applySeasonResolution(preferences: preferencesResult, seasons: seasonsResult)
        _ = await (profile, legal, teams)
        await refreshContent()
    }

    func refreshContent() async {
        // 캘린더와 리그 순위는 피드/통계와 독립적이라 네트워크를 동시에 진행한다.
        // 통계는 feedLogs를 읽으므로 피드 뒤에 순차로 두고,
        // 리그 순위는 statistics를 갱신하므로 통계 계산이 끝난 뒤에 반영한다.
        let standingsSeason = activeSeason
        async let calendar: Void = refreshCalendar()
        async let standings: KBOStandingsDTO? = loadKBOStandings(season: standingsSeason)
        await refreshFeed()
        await refreshStatistics()
        applyKBOStandings(await standings, season: standingsSeason)
        await calendar
    }

    func selectFeedResultFilter(_ filter: FeedResultFilter) async {
        guard filter != selectedFeedResultFilter else { return }
        selectedFeedResultFilter = filter
        await refreshFeed()
    }

    var selectedSeasonLabel: String {
        availableSeasons.first { $0.season == selectedSeason }?.label ?? "\(selectedSeason) 시즌"
    }

    func selectSeason(_ season: Int) async {
        guard season != selectedSeason else { return }
        selectedSeason = season
        preferences.selectedSeason = season
        selectedCalendarMonth = Self.monthStart(year: season, matching: selectedCalendarMonth)
        statistics = StatisticsService().summary(logs: [], season: season)
        availableSeasons = normalizedSeasonOptions(availableSeasons + [SeasonOption(season: season, hasRecords: false)])
        if remoteSelectedSeasonSupported {
            await syncPreferencesToServer()
        }
        await refreshContent()
    }

    func moveCalendarMonth(by value: Int) async {
        if let nextMonth = Calendar.current.date(byAdding: .month, value: value, to: selectedCalendarMonth) {
            selectedCalendarMonth = Calendar.current.dateInterval(of: .month, for: nextMonth)?.start ?? nextMonth
        }
        await refreshCalendar()
    }

    func selectCalendarMonth(year: Int, month: Int) async {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let nextMonth = Calendar.current.date(from: components) else { return }
        selectedCalendarMonth = Calendar.current.dateInterval(of: .month, for: nextMonth)?.start ?? nextMonth

        if year != selectedSeason {
            selectedSeason = year
            preferences.selectedSeason = year
            statistics = StatisticsService().summary(logs: [], season: year)
            availableSeasons = normalizedSeasonOptions(availableSeasons + [SeasonOption(season: year, hasRecords: false)])
            if remoteSelectedSeasonSupported {
                await syncPreferencesToServer()
            }
            await refreshContent()
        } else {
            await refreshCalendar()
        }
    }

    func team(id: String?) -> KBOTeam? {
        guard let id else { return nil }
        return teams.first { $0.id == id && $0.active } ?? KBOSeed.team(id: id)
    }

    func teamName(id: String?) -> String {
        team(id: id)?.name ?? "선택 안 함"
    }

    /// 온보딩 완료. 응원 팀과 주 관람 구장이 모두 있어야 저장된다.
    @discardableResult
    func completeOnboarding(favoriteTeamID: String?, primaryStadiumID: String?) -> Bool {
        let saved = preferences.completeOnboarding(
            favoriteTeamID: favoriteTeamID,
            primaryStadiumID: primaryStadiumID
        )
        guard saved else { return false }
        Task {
            await syncPreferencesToServer()
        }
        return true
    }

    /// 주 관람 구장만 바꾼다. 응원 팀은 그대로 둔다.
    func updatePrimaryStadium(_ stadiumID: String?) {
        preferences.setPrimaryStadium(stadiumID)
    }

    func updateFavoriteTeam(_ favoriteTeamID: String?) {
        preferences.favoriteTeamID = favoriteTeamID
        Task {
            await syncPreferencesToServer()
        }
    }

    func updateTeamThemeEnabled(_ isEnabled: Bool) {
        preferences.teamThemeEnabled = isEnabled
        Task {
            await syncPreferencesToServer()
        }
    }

    func saveAttendanceLog(
        viewModel: LogEditorViewModel,
        seat: String,
        companion: String,
        shortMemo: String,
        diary: String,
        tags: [String],
        photoLocalRefs: [String] = []
    ) async -> Bool {
        let favoriteTeamID = KBOSeed.team(named: viewModel.favoriteTeam)?.id
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
            ?? KBOSeed.teams[0].id
        let opponentTeamID = resolvedOpponentTeamID(for: viewModel.opponentTeam, favoriteTeamID: favoriteTeamID)
        let request = CreateAttendanceLogRequest(
            gameDate: DateFormatter.vfAPIDate.string(from: viewModel.date),
            season: Calendar.current.component(.year, from: viewModel.date),
            favoriteTeamID: favoriteTeamID,
            opponentTeamID: opponentTeamID,
            stadiumName: viewModel.stadium,
            result: viewModel.result.serverValue,
            // 적히지 않은 점수는 계속 비어 있다. 0으로 채우면 없는 사실이 저장된다.
            ourScore: viewModel.result == .canceled ? nil : viewModel.ourScore,
            opponentScore: viewModel.result == .canceled ? nil : viewModel.opponentScore,
            seatText: seat.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            companionType: companion.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            shortMemo: shortMemo.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            diaryText: diary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            moodTags: Array(tags.prefix(1)),
            highlightTags: Array(tags.dropFirst()),
            photoLocalRefs: photoLocalRefs,
            gameSource: viewModel.gameSource,
            linkedKBOGameID: viewModel.linkedKBOGameID,
            officialRecordURL: viewModel.officialRecordURL
        )

        let localLog: AttendanceLogViewState
        do {
            localLog = try await localAttendanceLogRepository?.createAttendanceLog(request) ?? request.localViewState
        } catch {
            localLog = request.localViewState
        }
        applySavedLog(localLog)

        do {
            _ = try await attendanceLogRepository.createAttendanceLog(request)
            try? await localAttendanceLogRepository?.markSyncState(id: localLog.id.uuidString, state: "synced")
            setServerStatus(.connected)
            lastSaveMessage = "기기에 먼저 저장하고 서버에도 동기화했어요."
            logAPIFallback(endpoint: "POST /api/v1/attendance-logs", fallback: "none", error: nil)
            await refreshContent()
            return true
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            lastSaveMessage = "기기에 저장했어요. 서버 연결 시 다시 동기화할 수 있어요."
            logAPIFallback(endpoint: "POST /api/v1/attendance-logs", fallback: "localOnly", error: error)
            await refreshStatistics()
            return false
        }
    }

    func updateAttendanceLog(
        id: UUID,
        viewModel: LogEditorViewModel,
        seat: String,
        companion: String,
        shortMemo: String,
        diary: String,
        tags: [String],
        photoLocalRefs: [String] = []
    ) async -> Bool {
        let favoriteTeamID = KBOSeed.team(named: viewModel.favoriteTeam)?.id
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
            ?? KBOSeed.teams[0].id
        let opponentTeamID = resolvedOpponentTeamID(for: viewModel.opponentTeam, favoriteTeamID: favoriteTeamID)
        let request = UpdateAttendanceLogRequest(
            gameDate: DateFormatter.vfAPIDate.string(from: viewModel.date),
            season: Calendar.current.component(.year, from: viewModel.date),
            favoriteTeamID: favoriteTeamID,
            opponentTeamID: opponentTeamID,
            stadiumName: viewModel.stadium,
            result: viewModel.result.serverValue,
            // 적히지 않은 점수는 계속 비어 있다. 0으로 채우면 없는 사실이 저장된다.
            ourScore: viewModel.result == .canceled ? nil : viewModel.ourScore,
            opponentScore: viewModel.result == .canceled ? nil : viewModel.opponentScore,
            seatText: seat.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            companionType: companion.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            shortMemo: shortMemo.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            diaryText: diary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            moodTags: Array(tags.prefix(1)),
            highlightTags: Array(tags.dropFirst()),
            photoLocalRefs: photoLocalRefs,
            gameSource: viewModel.gameSource,
            linkedKBOGameID: viewModel.linkedKBOGameID,
            officialRecordURL: viewModel.officialRecordURL
        )

        let localLog: AttendanceLogViewState
        do {
            localLog = try await localAttendanceLogRepository?.updateAttendanceLog(id: id.uuidString, request: request) ?? request.localViewState
        } catch {
            localLog = request.localViewState
        }
        applyUpdatedLog(localLog, replacing: id)

        do {
            _ = try await attendanceLogRepository.updateAttendanceLog(id: id.uuidString, request: request)
            try? await localAttendanceLogRepository?.markSyncState(id: localLog.id.uuidString, state: "synced")
            setServerStatus(.connected)
            lastSaveMessage = "수정 내용을 기기와 서버에 반영했어요."
            logAPIFallback(endpoint: "PUT /api/v1/attendance-logs/:id", fallback: "none", error: nil)
            await refreshContent()
            return true
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            lastSaveMessage = "수정 내용을 기기에 저장했어요. 서버 연결 시 다시 동기화할 수 있어요."
            logAPIFallback(endpoint: "PUT /api/v1/attendance-logs/:id", fallback: "localOnly", error: error)
            await refreshStatistics()
            return false
        }
    }

    /// 기록을 지운다.
    ///
    /// 기기 저장소에서 지우지 못했으면 **아무것도 지우지 않고** 실패를 알린다. 예전에는
    /// 실패를 삼키고 화면에서만 사라지게 해서, 다시 열면 되살아나는 기록을 사용자가
    /// 지웠다고 믿게 만들었다. 서버 삭제 실패는 다르다 — 기기에서 이미 지웠으므로
    /// 오프라인 삭제로 보고 성공으로 다룬다.
    @discardableResult
    func deleteAttendanceLog(_ log: AttendanceLogViewState) async -> RecordDeletionOutcome {
        do {
            try await localAttendanceLogRepository?.deleteAttendanceLog(id: log.id.uuidString)
        } catch {
            logAPIFallback(endpoint: "DELETE local attendance-log", fallback: "none", error: error)
            return .failed("기록을 지우지 못했어요. 잠시 후 다시 시도해 주세요.")
        }
        removeLog(id: log.id)

        do {
            try await attendanceLogRepository.deleteAttendanceLog(id: log.id.uuidString)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "DELETE /api/v1/attendance-logs/:id", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "DELETE /api/v1/attendance-logs/:id", fallback: "localOnly", error: error)
        }
        await refreshStatistics()
        return .deleted
    }

    func createDiaryDraft(request: DiaryDraftRequest) async throws -> DiaryDraftDTO {
        do {
            let draft = try await diaryDraftRepository.createDiaryDraft(request)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/ai/diary-draft", fallback: "none", error: nil)
            return draft
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/ai/diary-draft", fallback: "templateAvailable", error: error)
            throw error
        }
    }

    func createTemplateDraft(request: TemplateDraftRequest) async throws -> TemplateDraftResponse {
        do {
            let draft = try await diaryDraftRepository.createTemplateDraft(request)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/diary/template-draft", fallback: "none", error: nil)
            return draft
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/diary/template-draft", fallback: "local-template", error: error)
            throw error
        }
    }

    func fetchKBOGameCandidates(date: Date, favoriteTeamID: String) async throws -> KBOGameCandidatesDTO {
        let apiDate = DateFormatter.vfAPIDate.string(from: date)
        let normalizedTeamID = KBOSeed.normalizedTeamID(favoriteTeamID) ?? favoriteTeamID
        do {
            logKBO("request games date=\(apiDate) teamID=\(normalizedTeamID)")
            let response = try await kboGameRepository.fetchGames(date: apiDate, teamID: normalizedTeamID)
            logKBO("response items=\(response.items.count) source=\(response.source)")
            setServerStatus(.connected)
            logAPIFallback(endpoint: "GET /api/v1/kbo/games", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "GET /api/v1/kbo/games", fallback: "manual-input", error: error)
            throw error
        }
    }

    func analyzePhotos(localRefs: [String]) async throws -> PhotoAnalysisDTO {
        let files = localRefs.prefix(3).compactMap { ref -> MultipartFile? in
            guard let data = try? PhotoAttachmentService().compressedData(for: ref, maxPixel: 1280, quality: 0.72) else {
                return nil
            }
            return MultipartFile(fieldName: "photos", fileName: "\(ref).jpg", mimeType: "image/jpeg", data: data)
        }
        guard !files.isEmpty else {
            throw APIError.emptyData
        }
        do {
            let analysis = try await photoAnalysisRepository.analyzePhotos(files, locale: "ko-KR")
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/photos/analyze", fallback: "none", error: nil)
            return analysis
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/photos/analyze", fallback: "disabled-or-local", error: error)
            throw error
        }
    }

    func fetchNews(teamID: String?, limit: Int = 20) async throws -> NewsResponse {
        let teamID = validNewsTeamID(from: teamID)
        do {
            let response = try await newsRepository.fetchNews(teamID: teamID, limit: limit)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "GET /api/v1/news", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "GET /api/v1/news", fallback: "empty-state", error: error)
            throw error
        }
    }

    private func validNewsTeamID(from value: String?) -> String? {
        guard let value else { return nil }
        if let team = KBOSeed.team(id: KBOSeed.normalizedTeamID(value)) {
            return team.id
        }
        return KBOSeed.team(named: value)?.id
    }

    private func applyUserProfile(_ profile: UserProfileDTO) {
        let normalizedTeamID = KBOSeed.normalizedTeamID(profile.favoriteTeamID) ?? profile.favoriteTeamID
        userProfile = UserProfileDTO(
            nickname: profile.nickname,
            favoriteTeamID: normalizedTeamID,
            profileEmoji: profile.profileEmoji ?? "⚾",
            profileImageURL: profile.profileImageURL
        )
        preferences.userDisplayName = profile.nickname
        preferences.favoriteTeamID = normalizedTeamID
    }

    private func isMissingProfile(_ error: Error) -> Bool {
        if case APIError.httpStatus(404) = error {
            return true
        }
        if case let APIError.server(code, _) = error {
            return code == "PROFILE_NOT_FOUND" || code == "PROFILE_REQUIRED"
        }
        return false
    }

    func fetchMatchOutlook(request: MatchOutlookRequest) async throws -> MatchOutlookResponse {
        do {
            let response = try await matchOutlookRepository.fetchOutlook(request)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/match-outlook", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/match-outlook", fallback: "none", error: error)
            throw error
        }
    }

    func loadUserProfileIfNeeded(force: Bool = false) async {
        guard force || !didLoadUserProfile else { return }
        didLoadUserProfile = true
        do {
            let profile = try await userProfileRepository.fetchProfile()
            applyUserProfile(profile)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "GET /api/v1/me/profile", fallback: "none", error: nil)
        } catch {
            if isMissingProfile(error) {
                userProfile = nil
                setServerStatus(.connected)
            } else {
                logAPIFallback(endpoint: "GET /api/v1/me/profile", fallback: "profileNotRequired", error: error)
            }
        }
    }

    func saveUserProfile(_ request: UpsertUserProfileRequest) async throws -> UserProfileDTO {
        let normalizedRequest = UpsertUserProfileRequest(
            nickname: request.nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            favoriteTeamID: KBOSeed.normalizedTeamID(request.favoriteTeamID) ?? request.favoriteTeamID,
            profileEmoji: request.profileEmoji?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "⚾"
        )
        do {
            let profile: UserProfileDTO
            if userProfile == nil {
                profile = try await userProfileRepository.createProfile(normalizedRequest)
                logAPIFallback(endpoint: "POST /api/v1/me/profile", fallback: "none", error: nil)
            } else {
                profile = try await userProfileRepository.updateProfile(normalizedRequest)
                logAPIFallback(endpoint: "PUT /api/v1/me/profile", fallback: "none", error: nil)
            }
            applyUserProfile(profile)
            didLoadUserProfile = true
            setServerStatus(.connected)
            return profile
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: userProfile == nil ? "POST /api/v1/me/profile" : "PUT /api/v1/me/profile", fallback: "none", error: error)
            throw error
        }
    }

    func uploadProfileImage(data: Data, mimeType: String) async throws {
        do {
            try await userProfileRepository.uploadProfileImage(data: data, mimeType: mimeType)
            let profile = try await userProfileRepository.fetchProfile()
            applyUserProfile(profile)
            didLoadUserProfile = true
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/me/profile/image", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/me/profile/image", fallback: "none", error: error)
            throw error
        }
    }

    func deleteProfileImage() async throws {
        do {
            try await userProfileRepository.deleteProfileImage()
            let profile = try await userProfileRepository.fetchProfile()
            applyUserProfile(profile)
            didLoadUserProfile = true
            setServerStatus(.connected)
            logAPIFallback(endpoint: "DELETE /api/v1/me/profile/image", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "DELETE /api/v1/me/profile/image", fallback: "none", error: error)
            throw error
        }
    }

    func loadLegalLinksIfNeeded(force: Bool = false) async {
        guard force || !didLoadLegalLinks else { return }
        didLoadLegalLinks = true
        do {
            legalLinks = try await legalLinksRepository.fetchLegalLinks()
            logAPIFallback(endpoint: "GET /api/v1/legal-links", fallback: "none", error: nil)
        } catch {
            legalLinks = .fallback
            logAPIFallback(endpoint: "GET /api/v1/legal-links", fallback: "github-pages", error: error)
        }
    }

    func legalURL(_ keyPath: KeyPath<LegalLinksDTO, String>) -> URL {
        URL(string: legalLinks[keyPath: keyPath]) ?? URL(string: LegalLinksDTO.fallback[keyPath: keyPath])!
    }

    func fetchCommunityPosts() async throws -> CommunityPostsResponse {
        do {
            let response = try await communityRepository.fetchPosts()
            setServerStatus(.connected)
            logAPIFallback(endpoint: "GET /api/v1/community/posts", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "GET /api/v1/community/posts", fallback: "none", error: error)
            throw error
        }
    }

    func createCommunityPost(_ request: CreateCommunityPostRequest) async throws -> CommunityPostDTO {
        do {
            let response = try await communityRepository.createPost(request)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/community/posts", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/community/posts", fallback: "none", error: error)
            throw error
        }
    }

    func reportCommunityPost(id: String, reason: String) async throws {
        do {
            try await communityRepository.reportPost(id: id, reason: reason)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/community/posts/{id}/report", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/community/posts/{id}/report", fallback: "none", error: error)
            throw error
        }
    }

    func blockCommunityAuthor(authorID: String) async throws {
        do {
            try await communityRepository.blockAuthor(authorID: authorID)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "POST /api/v1/community/users/{authorID}/block", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "POST /api/v1/community/users/{authorID}/block", fallback: "none", error: error)
            throw error
        }
    }

    func unblockCommunityAuthor(authorID: String) async throws {
        do {
            try await communityRepository.unblockAuthor(authorID: authorID)
            setServerStatus(.connected)
            logAPIFallback(endpoint: "DELETE /api/v1/community/users/{authorID}/block", fallback: "none", error: nil)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "DELETE /api/v1/community/users/{authorID}/block", fallback: "none", error: error)
            throw error
        }
    }

    func fetchBlockedUsers() async throws -> BlockedUsersResponse {
        do {
            let response = try await communityRepository.fetchBlockedUsers()
            setServerStatus(.connected)
            logAPIFallback(endpoint: "GET /api/v1/community/blocked-users", fallback: "none", error: nil)
            return response
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "GET /api/v1/community/blocked-users", fallback: "none", error: error)
            throw error
        }
    }

    // 원격 설정 조회: 응답만 돌려주고 상태는 쓰지 않는다(쓰기는 applySeasonResolution 1곳).
    private func loadRemotePreferences() async -> Result<PreferencesDTO, Error> {
        do {
            return .success(try await preferencesRepository.fetchPreferences())
        } catch {
            return .failure(error)
        }
    }

    // 시즌 목록 조회: 응답만 돌려주고 상태는 쓰지 않는다(쓰기는 applySeasonResolution 1곳).
    private func loadRemoteSeasons() async -> Result<SeasonsDTO, Error> {
        do {
            return .success(try await seasonRepository.fetchSeasons())
        } catch {
            return .failure(error)
        }
    }

    // selectedSeason / selectedCalendarMonth / availableSeasons 쓰기를 여기 한 곳에 모은다.
    // 두 응답이 모두 도착한 뒤에만 실행되므로 병렬 조회로 인한 경합이 없다.
    // 쓰기 순서는 기존 직렬 구현과 동일하게 preferences 반영 후 seasons 반영이다.
    private func applySeasonResolution(
        preferences preferencesResult: Result<PreferencesDTO, Error>,
        seasons seasonsResult: Result<SeasonsDTO, Error>
    ) async {
        switch preferencesResult {
        case .success(let remote):
            remoteSelectedSeasonSupported = remote.selectedSeason != nil
            preferences.applyRemote(remote)
            if let remoteSeason = remote.selectedSeason {
                selectedSeason = remoteSeason
                selectedCalendarMonth = Self.monthStart(year: remoteSeason, matching: selectedCalendarMonth)
            }
            setServerStatus(.connected)
        case .failure(let error):
            setServerStatus(.localMode(error.localizedDescription))
        }

        switch seasonsResult {
        case .success(let response):
            let remoteOptions = response.items.map {
                SeasonOption(season: $0.season, label: $0.label, hasRecords: $0.hasRecords ?? false)
            }
            // 유효 시즌 = 서버 목록 ∪ 로컬 기록이 있는 시즌.
            // 서버가 과거 시즌을 목록에서 내려도 기기에 기록이 남아 있으면 계속 볼 수 있어야 한다.
            let localSeasons = (try? await localAttendanceLogRepository?.fetchAvailableSeasons()) ?? []
            // normalizedSeasonOptions는 나중 항목의 라벨을 채택하므로 서버 옵션을 뒤에 둔다.
            // 로컬에만 있는 시즌은 SeasonOption 기본 라벨("<연도> 시즌")로 남는다.
            let validSeasons = normalizedSeasonOptions(
                localSeasons.map { SeasonOption(season: $0, hasRecords: true) } + remoteOptions
            )
            availableSeasons = validSeasons.isEmpty ? await localSeasonOptions() : validSeasons
            // 서버에도 로컬에도 없는 시즌일 때만 서버가 알려준 현재 시즌으로 스냅한다.
            // 유효 시즌 집합이 비면(서버 목록 없음 + 로컬 기록 없음) 판단 근거가 없으므로 기존 값을 유지한다.
            if let currentSeason = response.currentSeason,
               !validSeasons.isEmpty,
               !validSeasons.contains(where: { $0.season == selectedSeason }) {
                selectedSeason = currentSeason
                preferences.selectedSeason = currentSeason
                selectedCalendarMonth = Self.monthStart(year: currentSeason, matching: selectedCalendarMonth)
            }
            setServerStatus(.connected)
        case .failure(let error):
            availableSeasons = await localSeasonOptions()
            logAPIFallback(endpoint: "GET /api/v1/seasons", fallback: "local", error: error)
        }
    }

    private func syncPreferencesToServer() async {
        do {
            _ = try await preferencesRepository.updatePreferences(preferences.updateRequest(selectedSeason: remoteSelectedSeasonSupported ? selectedSeason : nil))
            setServerStatus(.connected)
        } catch {
            setServerStatus(.localMode(error.localizedDescription))
        }
    }

    private func refreshTeams() async {
        do {
            let remoteTeams = try await teamRepository.fetchTeams()
            teams = remoteTeams.isEmpty ? KBOSeed.teams : remoteTeams
            setServerStatus(.connected)
        } catch {
            teams = KBOSeed.teams
            setServerStatus(.localMode(error.localizedDescription))
        }
    }

    private func refreshFeed() async {
        let season = activeSeason
        let result = selectedFeedResultFilter.result
        let requestKey = "\(season)|\(result?.serverValue ?? "all")"
        guard feedRefreshKeyInFlight != requestKey else { return }
        feedRefreshKeyInFlight = requestKey
        defer { feedRefreshKeyInFlight = nil }
        feedState = .loading
        do {
            let remoteLogs = try await feedRepository.fetchFeed(season: season, result: result)
            guard requestKey == "\(activeSeason)|\(selectedFeedResultFilter.result?.serverValue ?? "all")" else { return }
            let localLogs = (try? await localAttendanceLogRepository?.fetchFeed(season: season, result: result)) ?? []
            let logs = merge(remoteLogs: remoteLogs, localLogs: localLogs)
            feedLogs = logs
            feedState = logs.isEmpty ? .empty : .loaded
            setServerStatus(.connected)
        } catch {
            guard requestKey == "\(activeSeason)|\(selectedFeedResultFilter.result?.serverValue ?? "all")" else { return }
            let localLogs = (try? await localAttendanceLogRepository?.fetchFeed(season: season, result: result)) ?? []
            feedLogs = localLogs
            feedState = fallbackState(
                error: error,
                localIsEmpty: localLogs.isEmpty,
                localMessage: "서버 피드를 불러오지 못해 기기 저장 기록을 보여줘요."
            )
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: feedEndpointDescription(season: season, result: result), fallback: localLogs.isEmpty ? "empty-local" : "local", error: error)
        }
    }

    private func refreshCalendar() async {
        calendarState = .loading
        let calendarYear = Calendar.current.component(.year, from: selectedCalendarMonth)
        let calendarMonth = Calendar.current.component(.month, from: selectedCalendarMonth)
        do {
            let remoteLogs = try await calendarRepository.fetchCalendar(year: calendarYear, month: calendarMonth)
            let localLogs = (try? await localAttendanceLogRepository?.fetchCalendar(year: calendarYear, month: calendarMonth)) ?? []
            let logs = merge(remoteLogs: remoteLogs, localLogs: localLogs)
            calendarLogs = logs
            calendarState = logs.isEmpty ? .empty : .loaded
            setServerStatus(.connected)
        } catch {
            let localLogs = (try? await localAttendanceLogRepository?.fetchCalendar(year: calendarYear, month: calendarMonth)) ?? []
            calendarLogs = localLogs
            calendarState = fallbackState(
                error: error,
                localIsEmpty: localLogs.isEmpty,
                localMessage: "서버 캘린더를 불러오지 못해 기기 저장 기록을 보여줘요."
            )
            setServerStatus(.localMode(error.localizedDescription))
            logAPIFallback(endpoint: "GET /api/v1/calendar", fallback: localLogs.isEmpty ? "empty-local" : "local", error: error)
        }
    }

    private func refreshStatistics() async {
        let season = activeSeason
        guard statisticsRefreshSeasonInFlight != season else { return }
        statisticsRefreshSeasonInFlight = season
        defer { statisticsRefreshSeasonInFlight = nil }
        statisticsState = .loading
        let localLogs = (try? await localAttendanceLogRepository?.fetchAttendanceLogs(season: season)) ?? []
        guard season == activeSeason else { return }
        let mergedLogs = merge(remoteLogs: feedLogs, localLogs: localLogs)
        if mergedLogs.isEmpty {
            // 기록이 없을 때만 서버 통계(summary/stadiums/opponents 3요청)를 받는다.
            do {
                let remoteStatistics = try await statisticsRepository.fetchStatistics(season: season)
                guard season == activeSeason else { return }
                statistics = remoteStatistics
                setServerStatus(.connected)
            } catch {
                guard season == activeSeason else { return }
                statistics = StatisticsMapper.viewState(logs: localLogs, season: season)
                setServerStatus(.localMode(error.localizedDescription))
                logAPIFallback(endpoint: "GET /api/v1/statistics/*", fallback: localLogs.isEmpty ? "empty-local" : "local", error: error)
            }
        } else {
            // 기록이 있으면 서버 통계 결과를 어차피 버리므로 요청하지 않고 로컬에서 계산한다.
            statistics = StatisticsMapper.viewState(logs: mergedLogs, season: season)
            setServerStatus(.connected)
        }
        statisticsState = statistics.isEmpty ? .empty : .loaded
    }

    // 리그 순위 조회: feedLogs/statistics에 의존하지 않는 순수 네트워크 요청이라 병렬로 진행한다.
    private func loadKBOStandings(season: Int) async -> KBOStandingsDTO? {
        do {
            return try await kboStandingsRepository.fetchStandings(season: season)
        } catch {
            logAPIFallback(endpoint: "GET /api/v1/kbo/standings?season=\(season)", fallback: "placeholder", error: error)
            return nil
        }
    }

    // 리그 순위 반영: statistics를 read-modify-write하므로 통계 계산이 끝난 뒤에만 호출한다.
    private func applyKBOStandings(_ standings: KBOStandingsDTO?, season: Int) {
        guard season == activeSeason, let standings else { return }
        statistics = StatisticsMapper.applyingKBOStandings(standings, to: statistics)
        setServerStatus(.connected)
        logAPIFallback(endpoint: "GET /api/v1/kbo/standings?season=\(season)", fallback: "none", error: nil)
    }

    private func applySavedLog(_ log: AttendanceLogViewState) {
        if selectedFeedResultFilter.result == nil || selectedFeedResultFilter.result == log.result {
            feedLogs = merge(remoteLogs: [log], localLogs: feedLogs)
        }
        let calendarYear = Calendar.current.component(.year, from: selectedCalendarMonth)
        let calendarMonth = Calendar.current.component(.month, from: selectedCalendarMonth)
        if Calendar.current.component(.year, from: log.date) == calendarYear,
           Calendar.current.component(.month, from: log.date) == calendarMonth {
            calendarLogs = merge(remoteLogs: [log], localLogs: calendarLogs)
        }
        statistics = StatisticsMapper.viewState(logs: feedLogs, season: activeSeason)
        feedState = feedLogs.isEmpty ? .empty : .loaded
        calendarState = calendarLogs.isEmpty ? .empty : .loaded
        statisticsState = statistics.isEmpty ? .empty : .loaded
    }

    private func applyUpdatedLog(_ log: AttendanceLogViewState, replacing id: UUID) {
        feedLogs.removeAll { $0.id == id }
        calendarLogs.removeAll { $0.id == id }
        applySavedLog(log)
    }

    private func removeLog(id: UUID) {
        feedLogs.removeAll { $0.id == id }
        calendarLogs.removeAll { $0.id == id }
        statistics = StatisticsMapper.viewState(logs: feedLogs, season: activeSeason)
        feedState = feedLogs.isEmpty ? .empty : .loaded
        calendarState = calendarLogs.isEmpty ? .empty : .loaded
        statisticsState = statistics.isEmpty ? .empty : .loaded
    }

    private func merge(remoteLogs: [AttendanceLogViewState], localLogs: [AttendanceLogViewState]) -> [AttendanceLogViewState] {
        var seen = Set<String>()
        return (localLogs + remoteLogs)
            .sorted { $0.date > $1.date }
            .filter { log in
                let key = dedupeKey(for: log)
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
    }

    private func dedupeKey(for log: AttendanceLogViewState) -> String {
        [
            DateFormatter.vfAPIDate.string(from: log.date),
            log.matchup,
            log.stadium,
            log.result.rawValue,
            log.ourScore.map(String.init) ?? "",
            log.opponentScore.map(String.init) ?? ""
        ].joined(separator: "|")
    }

    private func localSeasonOptions() async -> [SeasonOption] {
        let currentYear = Calendar.current.component(.year, from: .now)
        let localSeasons = (try? await localAttendanceLogRepository?.fetchAvailableSeasons()) ?? []
        let sampleSeasons = AttendanceLogSample.logs.map { Calendar.current.component(.year, from: $0.date) }
        let seasons = Set([selectedSeason, currentYear] + localSeasons + sampleSeasons)
        return normalizedSeasonOptions(seasons.map { SeasonOption(season: $0, hasRecords: localSeasons.contains($0) || sampleSeasons.contains($0)) })
    }

    private func normalizedSeasonOptions(_ options: [SeasonOption]) -> [SeasonOption] {
        var bestBySeason: [Int: SeasonOption] = [:]
        for option in options {
            if let existing = bestBySeason[option.season] {
                bestBySeason[option.season] = SeasonOption(
                    season: option.season,
                    label: option.label.isEmpty ? existing.label : option.label,
                    hasRecords: existing.hasRecords || option.hasRecords
                )
            } else {
                bestBySeason[option.season] = option
            }
        }
        return bestBySeason.values.sorted { $0.season > $1.season }
    }

    private func feedEndpointDescription(season: Int, result: GameResult?) -> String {
        if let result {
            return "GET /api/v1/feed?season=\(season)&result=\(result.serverValue)"
        }
        return "GET /api/v1/feed?season=\(season)"
    }

    private static func monthStart(year: Int, matching date: Date) -> Date {
        let month = Calendar.current.component(.month, from: date)
        return Date.vfDate(year: year, month: month, day: 1)
    }

    private func fallbackState(error: Error, localIsEmpty: Bool, localMessage: String) -> RemoteDataState {
        if let apiError = error as? APIError, apiError == .notModifiedWithoutCache {
            return localIsEmpty
                ? .localOnly("서버가 새 데이터를 보내지 않아 로컬 모드로 표시해요.")
                : .serverErrorUsingLocal("서버가 새 데이터를 보내지 않아 기기 저장 기록을 보여줘요.")
        }
        return localIsEmpty
            ? .localOnly("서버에 연결할 수 없어 로컬 모드로 표시해요.")
            : .serverErrorUsingLocal(localMessage)
    }

    private func logAPIFallback(endpoint: String, fallback: String, error: Error?) {
        #if DEBUG
        let reason: String
        if let apiError = error as? APIError {
            reason = apiError.debugReason
        } else if let error {
            reason = error.localizedDescription
        } else {
            lastFallbackLogKey = nil
            print("[API] \(endpoint) fallback=\(fallback)")
            return
        }
        let logKey = "\(endpoint)|\(fallback)|\(reason)"
        guard logKey != lastFallbackLogKey else { return }
        lastFallbackLogKey = logKey
        print("[API] \(endpoint) failed reason=\(reason) fallback=\(fallback)")
        #endif
    }

    private func logKBO(_ message: String) {
        #if DEBUG
        print("[KBO] \(message)")
        #endif
    }

    private func resolvedOpponentTeamID(for opponentTeamName: String, favoriteTeamID: String) -> String {
        if let team = KBOSeed.team(named: opponentTeamName), team.id != favoriteTeamID {
            return team.id
        }
        return KBOSeed.teams.first { $0.id != favoriteTeamID }?.id ?? "doosan-bears"
    }
}

private extension UserPreferencesStore {
    func updateRequest(selectedSeason: Int?) -> UpdatePreferencesRequest {
        UpdatePreferencesRequest(
            hasCompletedOnboarding: hasCompletedOnboarding,
            favoriteTeamID: KBOSeed.normalizedTeamID(favoriteTeamID),
            teamThemeEnabled: teamThemeEnabled,
            displayName: userDisplayName,
            selectedSeason: selectedSeason
        )
    }

    func applyRemote(_ preferences: PreferencesDTO) {
        if let hasCompletedOnboarding = preferences.hasCompletedOnboarding {
            self.hasCompletedOnboarding = self.hasCompletedOnboarding || hasCompletedOnboarding
        }
        if let favoriteTeamID = preferences.favoriteTeamID {
            self.favoriteTeamID = KBOSeed.normalizedTeamID(favoriteTeamID)
        }
        if let teamThemeEnabled = preferences.teamThemeEnabled {
            self.teamThemeEnabled = teamThemeEnabled
        }
        if let displayName = preferences.displayName {
            self.userDisplayName = displayName
        }
        if let selectedSeason = preferences.selectedSeason {
            self.selectedSeason = selectedSeason
        }
    }
}

private extension StatisticsViewState {
    var isEmpty: Bool {
        totalGames == 0 && kboStandings.isEmpty
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
