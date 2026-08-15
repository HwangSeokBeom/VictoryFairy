import Foundation
#if DEBUG
import UIKit
#endif

/// UI 테스트가 결정적인 시작 상태를 만들기 위해 쓰는 실행 인자 처리기.
///
/// 이 타입은 **사용자가 직접 만들 수 있는 설정값만** 심는다. 가짜 기록이나 가짜 통계를
/// 넣지 않고, 검증도 우회하지 않는다. 따라서 제품 코드의 대체 데이터(fallback)가 될 수
/// 없다. `-VFUITest` 인자가 없으면 아무 일도 하지 않는다.
enum VFUITestConfiguration {
    /// 이 인자가 있을 때만 동작한다.
    private static let activationFlag = "-VFUITest"

    enum Argument {
        /// 저장된 설정을 모두 지우고 첫 실행 상태로 만든다.
        static let resetState = "-VFUITestReset"
        /// 응원 팀 ID를 미리 심는다. 값은 canonical 팀 ID여야 한다.
        static let teamID = "-VFUITestTeamID"
        /// 주 관람 구장 ID를 미리 심는다.
        static let stadiumID = "-VFUITestStadiumID"
        /// 온보딩 완료 플래그를 미리 심는다.
        static let onboardingCompleted = "-VFUITestOnboardingCompleted"
        /// 마이 화면의 방어 상태를 결정적으로 띄운다. DEBUG 전용.
        static let profileFixture = "-VFUITestProfileFixture"
    }

    /// 이 앱이 UserDefaults에 직접 쓰는 키 전체. 초기화 대상은 여기까지다.
    private static let managedKeys = [
        "hasCompletedOnboarding",
        "favoriteTeamID",
        "primaryStadiumID",
        "hasSeenOnboardingOverview",
        "onboardingSchemaVersion",
        "teamThemeEnabled",
        "userDisplayName",
        "selectedSeason"
    ]

    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains(activationFlag)
    }

    /// 실행 인자에 따라 UserDefaults를 준비한다. 앱 시작 시 한 번만 호출한다.
    static func applyIfNeeded(to defaults: UserDefaults = .standard) {
        guard isActive else { return }
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains(Argument.resetState) {
            // `removePersistentDomain`은 앱 자신의 standard 도메인에서 확실히 동작하지
            // 않는다(이미 캐시된 값이 남는다). 우리가 관리하는 키만 명시적으로 지운다.
            // 다른 앱이나 시스템 설정은 건드리지 않는다.
            for key in managedKeys {
                defaults.removeObject(forKey: key)
            }
            maskResidualValues(in: defaults)
        }

        if let teamID = value(for: Argument.teamID, in: arguments) {
            defaults.set(teamID, forKey: "favoriteTeamID")
        }
        if let stadiumID = value(for: Argument.stadiumID, in: arguments) {
            defaults.set(stadiumID, forKey: "primaryStadiumID")
        }
        if let completed = value(for: Argument.onboardingCompleted, in: arguments) {
            defaults.set(completed == "1" || completed.lowercased() == "true",
                         forKey: "hasCompletedOnboarding")
        }
        if let name = displayNameOverride(arguments: arguments) {
            defaults.set(name, forKey: "userDisplayName")
        }

        #if DEBUG
        // 강조색 확인용 캘린더 픽스처는 응원 팀까지 정한다. 명시적인 `-VFUITestTeamID`
        // 보다 나중에 적용해, 시나리오가 요구한 팀이 실제로 화면에 반영되게 한다.
        if let fixtureTeamID = calendarFixtureTeamID {
            defaults.set(fixtureTeamID, forKey: "favoriteTeamID")
        }
        if let fixtureTeamID = statisticsFixtureTeamID {
            defaults.set(fixtureTeamID, forKey: "favoriteTeamID")
        }
        // 시즌 아카이브 픽스처는 시작 시즌만 심는다. 그 뒤의 시즌 선택은 제품 경로
        // 그대로 흐른다. 화면을 그릴 때마다 덮어쓰면 시즌을 바꿀 수 없게 된다.
        if let fixtureSeason = statisticsInitialSeason {
            defaults.set(fixtureSeason, forKey: "selectedSeason")
        }
        if let fixtureTeamID = recordDetailFixtureTeamID {
            defaults.set(fixtureTeamID, forKey: "favoriteTeamID")
        }
        // 일기 서명은 사용자 이름이 있을 때만 나온다. 실제 설정과 같은 자리에 심는다.
        if recordDetailFixture != nil {
            defaults.set(VFRecordDetailFixtures.displayName, forKey: "userDisplayName")
        }
        #endif
    }

    /// 지워도 되살아나는 값을 앱 도메인에서 덮어써 무력화한다.
    ///
    /// `UserDefaults.standard`는 여러 도메인을 순서대로 뒤진다. 시뮬레이터에는
    /// 앱 컨테이너 밖(`<device>/data/Library/Preferences/<bundle>.plist`)에 같은
    /// 번들 ID의 값이 남아 있을 수 있고, 그 도메인은 앱을 지워도 사라지지 않는다.
    /// 샌드박스 안에서 하는 `removeObject`는 앱 자신의 도메인만 지우므로 그런
    /// 잔재는 그대로 살아남아 "첫 실행"이 첫 실행이 아니게 된다.
    ///
    /// 그래서 지운 뒤에도 값이 보이면, 앱 도메인에 "비어 있음"에 해당하는 값을
    /// 직접 써서 아래 도메인을 가린다. 빈 문자열은 `UserPreferencesStore`가 값
    /// 없음으로 읽는다.
    private static func maskResidualValues(in defaults: UserDefaults) {
        // 잔재가 남았을 때 어떤 값으로 가릴지. 지운 상태와 같은 뜻이어야 한다.
        let blankedText = ["favoriteTeamID", "primaryStadiumID", "userDisplayName"]
        let blankedFlags: [String: Bool] = [
            "hasCompletedOnboarding": false,
            "hasSeenOnboardingOverview": false,
            // 팀 테마는 값이 없을 때 켜진 것으로 읽는다. 그 기본값을 유지한다.
            "teamThemeEnabled": true
        ]

        for key in blankedText where defaults.string(forKey: key) != nil {
            defaults.set("", forKey: key)
        }
        for (key, value) in blankedFlags where defaults.object(forKey: key) != nil {
            defaults.set(value, forKey: key)
        }
        // 시즌과 스키마 버전은 온보딩 진입을 좌우하지 않고, 값을 새로 쓰면 오히려
        // 다른 픽스처가 정한 시작 시즌을 덮어쓴다. 지우는 데서 멈춘다.
    }

    /// 앱이 처음 열 탭. UI 테스트와 화면 캡처가 특정 탭에서 바로 시작하기 위해 쓴다.
    /// Release에는 이 개념이 없다.
    static var initialTabRawValue: String? {
        #if DEBUG
        guard isActive else { return nil }
        return value(for: "-VFUITestInitialTab", in: ProcessInfo.processInfo.arguments)
        #else
        return nil
        #endif
    }

    // MARK: - 피드 결정적 픽스처

    /// 피드 UI 테스트가 쓰는 상태 이름.
    enum FeedFixture: String {
        /// Pencil 기준 상태: 4월 3건 + 3월 1건.
        case populated
        /// 여러 달과 같은 날 기록, 연도 경계까지 포함한 확장 상태.
        case multiMonth
        /// 기록 없음.
        case empty
        /// 복구 가능한 오류.
        case error
        /// 불러오는 중.
        case loading
        /// 사진 없음 · 긴 메모 · 긴 구장 이름.
        case longContent
    }

    /// 실행 인자가 지정한 피드 픽스처. Release에는 이 개념 자체가 없다.
    static var feedFixture: FeedFixture? {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestFeedFixture", in: ProcessInfo.processInfo.arguments) else {
            return nil
        }
        return FeedFixture(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 피드에 보여줄 기록. 픽스처가 없으면 실제 데이터를 그대로 돌려준다.
    ///
    /// `#if DEBUG` 안에서만 분기가 존재하므로 Release 빌드에서는 이 함수가
    /// 인자를 그대로 반환하는 것 외에 아무 일도 하지 않는다. 제품 대체 데이터가 될 수 없다.
    ///
    /// 실제 경로에서는 저장소가 이미 필터를 적용해 넘겨주므로, 픽스처도 같은 규칙으로
    /// 걸러야 필터 동작을 그대로 검증할 수 있다.
    static func feedLogs(
        _ production: [AttendanceLogViewState],
        filter: FeedResultFilter = .all
    ) -> [AttendanceLogViewState] {
        #if DEBUG
        if let fixture = memoryShareFixture {
            let log = VFStatesFixtures.memoryShareLog(for: fixture)
            guard let result = filter.result else { return [log] }
            return log.result == result ? [log] : []
        }
        if let fixture = feedFixture {
            let all = VFFeedFixtures.logs(for: fixture)
            guard let result = filter.result else { return all }
            return all.filter { $0.result == result }
        }
        #endif
        return production
    }

    /// 홈 대시보드. 피드 픽스처가 있으면 같은 기록으로 다시 집계한다.
    ///
    /// 홈의 대시보드는 저장소에서 온 `feedLogs`로 만들어지므로, 피드 픽스처만으로는
    /// 홈이 비어 있었다. 그래서 "최근 기록이 있는 홈"을 결정적으로 만들 방법이 없었고
    /// 승리요정 지수 카드와 AI 도우미 진입을 검증할 수 없었다. Release에서는 인자를
    /// 그대로 돌려주므로 제품 경로에는 아무 영향이 없다.
    static func homeDashboard(_ production: HomeDashboardViewState) -> HomeDashboardViewState {
        #if DEBUG
        if let fixture = feedFixture {
            return .sample(logs: VFFeedFixtures.logs(for: fixture))
        }
        #endif
        return production
    }

    /// 피드 데이터 상태. 픽스처가 없으면 실제 상태를 그대로 돌려준다.
    static func feedState(_ production: RemoteDataState) -> RemoteDataState {
        #if DEBUG
        switch feedFixture {
        case .error: return .error("연결이 원활하지 않아요. 네트워크를 확인하고 다시 시도해 주세요.")
        case .loading: return .loading
        case .some: return .loaded
        case nil: break
        }
        #endif
        return production
    }

    // MARK: - 캘린더 결정적 픽스처

    /// 캘린더 UI 테스트가 쓰는 상태 이름.
    enum CalendarFixture: String {
        case referenceMonth
        case selectedRecord
        case selectedEmptyDate
        case multipleSameDayRecords
        case loading
        case emptyMonth
        case recoverableError
        case retrySuccess
        case win
        case loss
        case draw
        case cancelled
        case scheduledDesignState
        case liveDesignState
        case postponedDesignState
        case longTeamName
        case longStadiumName
        case lightTeamAccent
        case darkTeamAccent
        case compactReference
        case accessibilityReference
        case yearBoundary
    }

    static var calendarFixture: CalendarFixture? {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestCalendarFixture", in: ProcessInfo.processInfo.arguments) else {
            return nil
        }
        return CalendarFixture(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 캘린더에 보여줄 기록. 픽스처가 없으면 실제 데이터를 그대로 돌려준다.
    static func calendarLogs(_ production: [AttendanceLogViewState]) -> [AttendanceLogViewState] {
        #if DEBUG
        if let fixture = calendarFixture {
            return VFCalendarFixtures.logs(for: fixture)
        }
        #endif
        return production
    }

    /// 캘린더가 **처음** 보여줄 달. 픽스처가 없으면 실제 값을 그대로 돌려준다.
    ///
    /// 앱이 시작할 때 한 번만 쓴다. 화면을 그릴 때마다 쓰면 사용자가 달을 옮겨도
    /// 곧바로 픽스처 값으로 되돌아가, 달 이동이 영원히 막힌다.
    static func initialCalendarMonth(_ production: Date) -> Date {
        #if DEBUG
        if let fixture = calendarFixture {
            return VFCalendarFixtures.month(for: fixture)
        }
        #endif
        return production
    }

    static func calendarState(_ production: RemoteDataState) -> RemoteDataState {
        #if DEBUG
        switch calendarFixture {
        case .recoverableError: return .error("연결이 원활하지 않아요. 네트워크를 확인하고 다시 시도해 주세요.")
        case .loading: return .loading
        case .some: return .loaded
        case nil: break
        }
        #endif
        return production
    }

    /// 픽스처가 미리 고르는 날짜.
    static var calendarPreselectedDate: Date? {
        #if DEBUG
        guard let fixture = calendarFixture else { return nil }
        return VFCalendarFixtures.selectedDate(for: fixture)
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// 디자인에만 존재하는 경기 상태. 이 프로퍼티 자체가 DEBUG에만 있다.
    ///
    /// Release에서는 타입도 프로퍼티도 없으므로 제품이 이 상태를 만들 방법이 없다.
    /// 화면 쪽에서는 `#if DEBUG` 없이 쓸 수 있도록 아래에 중립 형태를 따로 둔다.
    static var calendarDesignOnlyStatus: CalendarDesignOnlyStatus? {
        switch calendarFixture {
        case .scheduledDesignState: return .scheduled
        case .liveDesignState: return .live
        case .postponedDesignState: return .postponed
        default: return nil
        }
    }
    #endif

    /// 픽스처가 요구한 응원 팀. 없으면 저장된 값을 그대로 쓴다.
    static var calendarFixtureTeamID: String? {
        #if DEBUG
        guard let fixture = calendarFixture else { return nil }
        return VFCalendarFixtures.teamID(for: fixture)
        #else
        return nil
        #endif
    }

    /// UI 테스트가 "픽스처가 정말 적용됐는지"를 화면에서 확인할 수 있게 하는 표식.
    /// 조용히 제품 상태로 돌아가 버리는 일을 잡아내기 위한 것이다.
    static var activeCalendarScenarioIdentifier: String? {
        #if DEBUG
        guard let fixture = calendarFixture else { return nil }
        return "calendar.scenario.\(fixture.rawValue)"
        #else
        return nil
        #endif
    }

    // MARK: - 시즌 아카이브 결정적 픽스처

    /// 시즌 아카이브 UI 테스트가 쓰는 상태 이름.
    enum StatisticsFixture: String {
        /// Pencil 기준 상태: 8경기 · 5승 2패 1무.
        case referenceSeason
        /// 여러 시즌을 고를 수 있는 상태.
        case multipleSeasons
        /// 지난 시즌이 이미 골라진 상태.
        case previousSeason
        /// 이 시즌 기록 없음.
        case empty
        /// 기록 한 건.
        case oneRecord
        /// 승패 표본이 적은 상태.
        case insufficientData
        /// 구장이 적히지 않은 기록.
        case noStadium
        /// 대진이 적히지 않은 기록. 상대팀 통계가 0건이 된다.
        case noOpponent
        /// 점수가 적히지 않은 기록.
        case missingScore
        case winOnly
        case lossOnly
        case drawOnly
        case cancelledOnly
        case mixedResults
        /// 불러오는 중.
        case loading
        /// 복구 가능한 오류.
        case recoverableError
        /// 다시 불러오기에 성공한 뒤.
        case retrySuccess
        case longTeamName
        case longStadiumName
        case lightTeamAccent
        case darkTeamAccent
        case compactReference
        case accessibilityReference
        /// 정식 구장 아홉 곳이 모두 한 화면에 나오는 상태.
        case allStadiums
    }

    static var statisticsFixture: StatisticsFixture? {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestStatisticsFixture", in: ProcessInfo.processInfo.arguments) else {
            return nil
        }
        return StatisticsFixture(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 시즌 아카이브가 집계할 기록. 픽스처가 없으면 실제 데이터를 그대로 돌려준다.
    ///
    /// 고른 시즌을 함께 받는다. 시즌을 바꿨을 때 값이 실제로 달라져야, 선택이 화면까지
    /// 이어졌는지 확인할 수 있다.
    static func statisticsLogs(
        _ production: [AttendanceLogViewState],
        season: Int
    ) -> [AttendanceLogViewState] {
        #if DEBUG
        if let fixture = statisticsFixture {
            return VFStatisticsFixtures.logs(for: fixture, season: season)
        }
        #endif
        return production
    }

    /// 고를 수 있는 시즌 목록. 픽스처가 없으면 실제 목록을 그대로 돌려준다.
    static func statisticsSeasons(_ production: [SeasonArchiveOption]) -> [SeasonArchiveOption] {
        #if DEBUG
        if let fixture = statisticsFixture {
            return VFStatisticsFixtures.seasons(for: fixture)
        }
        #endif
        return production
    }

    static func statisticsState(_ production: RemoteDataState) -> RemoteDataState {
        #if DEBUG
        switch statisticsFixture {
        case .recoverableError: return .error("연결이 원활하지 않아요. 네트워크를 확인하고 다시 시도해 주세요.")
        case .loading: return .loading
        case .some: return .loaded
        case nil: break
        }
        #endif
        return production
    }

    /// 픽스처가 요구한 시작 시즌. 없으면 저장된 값을 그대로 쓴다.
    static var statisticsInitialSeason: Int? {
        #if DEBUG
        guard let fixture = statisticsFixture else { return nil }
        return VFStatisticsFixtures.initialSeason(for: fixture)
        #else
        return nil
        #endif
    }

    /// 픽스처가 요구한 응원 팀. 없으면 저장된 값을 그대로 쓴다.
    static var statisticsFixtureTeamID: String? {
        #if DEBUG
        guard let fixture = statisticsFixture else { return nil }
        return VFStatisticsFixtures.teamID(for: fixture)
        #else
        return nil
        #endif
    }

    /// UI 테스트가 "픽스처가 정말 적용됐는지"를 화면에서 확인할 수 있게 하는 표식.
    /// 조용히 제품 상태로 돌아가 버리는 일을 잡아내기 위한 것이다.
    static var activeStatisticsScenarioIdentifier: String? {
        #if DEBUG
        guard let fixture = statisticsFixture else { return nil }
        return "statistics.scenario.\(fixture.rawValue)"
        #else
        return nil
        #endif
    }

    // MARK: - 기록 상세 결정적 픽스처

    /// 기록 상세 UI 테스트가 쓰는 상태 이름.
    enum RecordDetailFixture: String {
        /// Pencil 기준 상태: 2026년 4월 12일 잠실 원정 6:3 승.
        case referenceRecord
        case withPhoto
        case withoutPhoto
        /// 참조는 있는데 파일이 없다.
        case missingPhotoFile
        /// 파일은 있는데 이미지로 해석되지 않는다.
        case failedPhotoDecode
        case longNote
        case noNote
        case missingScore
        case missingOpponent
        case missingStadium
        case unknownStadium
        case win
        case loss
        case draw
        case cancelled
        case loading
        case recoverableError
        case retrySuccess
        case deleteConfirmation
        case deleteSuccess
        case deleteFailure
        case longTeamName
        case longStadiumName
        case lightTeamAccent
        case darkTeamAccent
        case compactReference
        case accessibilityReference
    }

    static var recordDetailFixture: RecordDetailFixture? {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestRecordDetailFixture", in: ProcessInfo.processInfo.arguments) else {
            return nil
        }
        return RecordDetailFixture(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 상세 화면이 보여 줄 기록. 픽스처가 없으면 실제 기록을 그대로 돌려준다.
    static func recordDetailLog(_ production: AttendanceLogViewState) -> AttendanceLogViewState {
        #if DEBUG
        if let fixture = recordDetailFixture {
            return VFRecordDetailFixtures.log(for: fixture)
        }
        #endif
        return production
    }

    /// 사진 영역 상태. 픽스처가 없으면 실제로 확인한 상태를 그대로 돌려준다.
    static func recordDetailMedia(_ production: RecordDetailMedia) -> RecordDetailMedia {
        #if DEBUG
        if let fixture = recordDetailFixture {
            return VFRecordDetailFixtures.media(for: fixture)
        }
        #endif
        return production
    }

    static func recordDetailState(_ production: RecordDetailDataState) -> RecordDetailDataState {
        #if DEBUG
        if let fixture = recordDetailFixture {
            return VFRecordDetailFixtures.dataState(for: fixture)
        }
        #endif
        return production
    }

    /// 삭제 결과를 대신 정해 주는 이음새.
    ///
    /// 픽스처가 지정한 시나리오에서는 **저장소를 건드리지 않고** 결과만 돌려준다.
    /// 그래서 UI 테스트가 삭제 실패 경로를 확인해도 실제 기록이 사라지지 않는다.
    static func recordDetailDeletion(
        _ production: () async -> RecordDeletionOutcome
    ) async -> RecordDeletionOutcome {
        #if DEBUG
        if let fixture = recordDetailFixture,
           let scripted = VFRecordDetailFixtures.scriptedDeletion(for: fixture) {
            return scripted
        }
        #endif
        return await production()
    }

    /// 픽스처가 요구한 응원 팀. 없으면 저장된 값을 그대로 쓴다.
    static var recordDetailFixtureTeamID: String? {
        #if DEBUG
        guard let fixture = recordDetailFixture else { return nil }
        return VFRecordDetailFixtures.teamID(for: fixture)
        #else
        return nil
        #endif
    }

    /// UI 테스트가 "픽스처가 정말 적용됐는지"를 화면에서 확인할 수 있게 하는 표식.
    static var activeRecordDetailScenarioIdentifier: String? {
        #if DEBUG
        guard let fixture = recordDetailFixture else { return nil }
        return "recordDetail.scenario.\(fixture.rawValue)"
        #else
        return nil
        #endif
    }

    // MARK: - 기록 작성 1단계 스테이징 호스트

    /// 아직 사용자에게 열리지 않은 세 단계 흐름을 UI 테스트가 띄우기 위한 상태 이름.
    ///
    /// 이것은 **여덟 번째 제품 경로가 아니다.** 일곱 개 사용자 경로는 그대로
    /// `LogEditorView`를 띄운다. 이 값은 `#if DEBUG` 안에서만 존재하므로 Release
    /// 빌드에는 개념 자체가 없고, 사용자가 켤 방법도 없다.
    enum RecordCreateStagedFixture: String {
        /// 아무것도 심지 않은 새 기록. 응원팀만 사용자 설정에서 온다.
        case fresh
        /// 캘린더처럼 날짜를 정해 주는 진입점에서 온 경우.
        case initialDate
        /// 1단계가 아직 비어 있는 채로 마지막 단계에 서 있는 상태.
        ///
        /// 제품 흐름에서는 1단계의 `다음`이 막혀 여기에 닿을 수 없다. 그래도 마지막
        /// 완성 버튼은 저장 직전에 스스로 검증해야 하므로, 그 방어 경로를 눈으로
        /// 확인할 수 있게 시작 위치만 옮겨 주는 픽스처다.
        case incompleteAtMemory
    }

    /// 실행 인자가 지정한 스테이징 픽스처. Release에는 이 개념 자체가 없다.
    static var recordCreateStagedFixture: RecordCreateStagedFixture? {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestRecordCreateStaged", in: ProcessInfo.processInfo.arguments) else {
            return nil
        }
        return RecordCreateStagedFixture(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// 스테이징 호스트가 1단계에 심어 줄 시작 날짜.
    ///
    /// 캘린더 진입점이 날짜를 건네는 경로를 그대로 흉내낸다. 값을 지어내는 것이
    /// 아니라, 사용자가 캘린더에서 고를 수 있는 날짜와 같은 자리를 채운다.
    static var recordCreateStagedInitialDate: Date? {
        #if DEBUG
        guard recordCreateStagedFixture == .initialDate else { return nil }
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 16
        return Calendar.current.date(from: components)
        #else
        return nil
        #endif
    }

    /// 스테이징 3단계가 시작할 때 들고 있을 사진 수.
    ///
    /// 시뮬레이터 사진 피커는 자동화가 불안정하다. 그래서 사진 상태만은 피커를
    /// 거치지 않고 심되, **실제 사진 파이프라인**(`PhotoAttachmentService`)으로
    /// 진짜 파일을 만들어 넣는다 — 디코딩·썸네일·삭제가 모두 제품 경로 그대로 돈다.
    /// Release에는 이 개념 자체가 없다.
    static func recordCreateStagedPhotoRefs() -> [String] {
        #if DEBUG
        guard isActive,
              let raw = value(for: "-VFUITestRecordCreateStagedPhotos", in: ProcessInfo.processInfo.arguments)
        else { return [] }
        let count: Int
        switch raw {
        case "one": count = 1
        case "many": count = 2
        default: count = 0
        }
        guard count > 0 else { return [] }

        let service = PhotoAttachmentService()
        let palette: [UIColor] = [.systemTeal, .systemOrange]
        return (0..<count).compactMap { index in
            let size = CGSize(width: 320, height: 320)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                palette[index % palette.count].setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            return try? service.saveImage(image)
        }
        #else
        return []
        #endif
    }

    /// 흐름이 시작할 단계. 저장되는 값이 아니라 **시작 위치**일 뿐이다.
    ///
    /// 두 가지가 이 값을 정할 수 있다.
    /// - 검증용 스테이징 픽스처 `incompleteAtMemory`
    /// - 독립 인자 `-VFUITestRecordCreateInitialStep`
    ///
    /// 두 번째가 필요한 이유: 1단계가 비어 있는 채로 마지막 단계에 서 있는 상태는
    /// 제품 흐름으로 만들 수 없다(1단계의 `다음`이 이미 막는다). 그런데 마지막
    /// 완성 버튼은 저장 직전에 스스로 검증해야 하고, 그 방어를 **제품 진입 경로에서**
    /// 확인하려면 시작 위치만 옮길 수단이 필요하다. 이 인자는 화면 루트를 바꾸지
    /// 않으므로 진입은 여전히 홈·기록 같은 실제 경로다.
    ///
    /// Release에는 이 개념 자체가 없다.
    static var recordCreateStagedInitialStep: RecordCreateStep? {
        #if DEBUG
        if recordCreateStagedFixture == .incompleteAtMemory { return .memory }
        guard isActive,
              let raw = value(for: "-VFUITestRecordCreateInitialStep", in: ProcessInfo.processInfo.arguments)
        else { return nil }
        return RecordCreateStep(rawValue: raw)
        #else
        return nil
        #endif
    }

    /// UI 테스트가 "픽스처가 정말 적용됐는지"를 화면에서 확인할 수 있게 하는 표식.
    static var activeRecordCreateStagedScenarioIdentifier: String? {
        #if DEBUG
        guard let fixture = recordCreateStagedFixture else { return nil }
        return "recordCreate.scenario.\(fixture.rawValue)"
        #else
        return nil
        #endif
    }

    /// `-Key value` 형태에서 값을 읽는다.
    /// 결정적 UI 검증을 위해 표시 이름을 미리 심는다. **DEBUG에서만 존재한다.**
    ///
    /// 이 인자 이름은 배포 바이너리에 남으면 안 된다. 런타임 조건으로 동작만 막으면
    /// 문자열 리터럴은 그대로 실려 나간다 — 실제로 Release 아카이브 문자열 스캔에서
    /// `-VFUITestDisplayName`이 발견됐다. 그래서 리터럴과 파싱을 통째로 `#if DEBUG`
    /// 안에 두고, Release에서는 이 함수가 언제나 `nil`을 돌려준다.
    ///
    /// 제품의 표시 이름은 이것과 무관하게 언제나 저장된 값에서 온다.
    static func displayNameOverride(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> String? {
        #if DEBUG
        return value(for: "-VFUITestDisplayName", in: arguments)
        #else
        return nil
        #endif
    }

    private static func value(for key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key),
              arguments.index(after: index) < arguments.endIndex else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }
}

#if DEBUG
extension VFUITestConfiguration {
    /// 응원 팀이 없는 **방어 렌더링**을 결정적으로 확인하기 위한 자리.
    ///
    /// 제품에서는 이 상태에 닿을 수 없다. `onboardingEntry`는 팀과 구장이 모두
    /// 유효할 때만 `.completed`가 되므로, 팀이 없으면 탭이 아니라 온보딩이 뜬다.
    /// 그렇다고 그 불변식을 느슨하게 만들 수는 없다 — 온보딩은 그대로 두고,
    /// **검증할 때만** 탭 경로를 띄운다.
    ///
    /// 화면 자체는 진짜 `ProfileSettingsView`다. 두 번째 마이 화면을 만들지 않는다.
    /// 이 인자와 아래 값은 `#if DEBUG` 안에만 있으므로 Release 바이너리에는
    /// 문자열조차 남지 않는다(아카이브에서 확인한다).
    static var forcesMainTabsForProfileFixture: Bool {
        guard isActive else { return false }
        return value(for: Argument.profileFixture,
                     in: ProcessInfo.processInfo.arguments) == "noTeam"
    }
}
#endif

#if DEBUG
extension VFUITestConfiguration {
    /// 응원 팀 변경 시트가 받을 팀 목록을 결정적으로 바꾼다. **DEBUG 전용.**
    ///
    /// 빈 목록·아주 긴 이름·최대 개수는 제품 경로로 만들 수 없다. 그렇다고 화면을
    /// 하나 더 만들지 않는다 — 진짜 `TeamSelectionView`가 받는 값만 이 자리에서
    /// 갈아 끼운다. 인자 이름과 이 분기는 `#if DEBUG` 안에만 있으므로 Release
    /// 바이너리에는 문자열조차 남지 않는다(아카이브에서 확인한다).
    static func teamCatalog(_ teams: [KBOTeam]) -> [KBOTeam] {
        guard isActive,
              let raw = value(for: "-VFUITestTeamCatalog",
                              in: ProcessInfo.processInfo.arguments) else {
            return teams
        }
        switch raw {
        case "empty":
            return []
        case "longNames":
            // 이름만 길게 바꾼다. ID는 그대로라 선택 정체성은 흔들리지 않는다.
            return teams.map { team in
                KBOTeam(id: team.id,
                        name: "아주아주긴이름을가진구단이름테스트용" + team.shortName,
                        shortName: team.shortName,
                        city: team.city,
                        homeStadiumName: team.homeStadiumName,
                        primaryColorHex: team.primaryColorHex,
                        secondaryColorHex: team.secondaryColorHex,
                        accentColorHex: team.accentColorHex,
                        textOnPrimaryHex: team.textOnPrimaryHex,
                        active: team.active)
            }
        case "maximum":
            // 지금 제품이 아는 최대치가 곧 canonical 목록이다. 팀을 지어내지 않는다.
            return teams
        default:
            return teams
        }
    }
}
#else
extension VFUITestConfiguration {
    /// Release에서는 인자를 그대로 돌려준다. 제품 경로에는 아무 영향이 없다.
    static func teamCatalog(_ teams: [KBOTeam]) -> [KBOTeam] { teams }
}
#endif

#if DEBUG
extension VFUITestConfiguration {
    enum StadiumSheetFixture: String {
        case canonicalSelected
        case invalidCurrent
        case empty
        case longContent
        case allNine
    }

    static var stadiumSheetFixture: StadiumSheetFixture? {
        guard isActive,
              let raw = value(for: "-VFUITestStadiumSheetFixture",
                              in: ProcessInfo.processInfo.arguments) else { return nil }
        return StadiumSheetFixture(rawValue: raw)
    }

    static func stadiumCatalog(_ production: [KBOStadium]) -> [KBOStadium] {
        guard let fixture = stadiumSheetFixture else { return production }
        return VFStatesFixtures.stadiumCatalog(for: fixture)
    }

    static func stadiumDraft(_ production: RecordEditorDraft) -> RecordEditorDraft {
        guard let fixture = stadiumSheetFixture else { return production }
        var result = production
        result.stadiumName = VFStatesFixtures.initialStadiumName(for: fixture)
        return result
    }

    static var activeStadiumSheetScenarioIdentifier: String? {
        guard let fixture = stadiumSheetFixture else { return nil }
        return "stadiumSheet.scenario.\(fixture.rawValue)"
    }

    enum MemoryShareFixture: String {
        case withPhoto
        case noPhoto
        case unreadablePhoto
        case scored
        case canceled
        case missingScore
        case longContent
    }

    static var memoryShareFixture: MemoryShareFixture? {
        guard isActive,
              let raw = value(for: "-VFUITestMemoryShareFixture",
                              in: ProcessInfo.processInfo.arguments) else { return nil }
        return MemoryShareFixture(rawValue: raw)
    }

    static var activeMemoryShareScenarioIdentifier: String? {
        guard let fixture = memoryShareFixture else { return nil }
        return "memoryShare.scenario.\(fixture.rawValue)"
    }
}
#else
extension VFUITestConfiguration {
    static func stadiumCatalog(_ production: [KBOStadium]) -> [KBOStadium] { production }
    static func stadiumDraft(_ production: RecordEditorDraft) -> RecordEditorDraft { production }
    static var activeStadiumSheetScenarioIdentifier: String? { nil }
    static var activeMemoryShareScenarioIdentifier: String? { nil }
}
#endif
