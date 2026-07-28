import Foundation

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
        if let fixture = feedFixture {
            let all = VFFeedFixtures.logs(for: fixture)
            guard let result = filter.result else { return all }
            return all.filter { $0.result == result }
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

    /// `-Key value` 형태에서 값을 읽는다.
    private static func value(for key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key),
              arguments.index(after: index) < arguments.endIndex else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }
}
