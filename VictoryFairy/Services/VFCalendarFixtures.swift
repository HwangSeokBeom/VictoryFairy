#if DEBUG
import Foundation

/// UI 테스트가 캘린더의 각 상태를 결정적으로 재현하기 위한 고정 데이터.
///
/// 파일 전체가 `#if DEBUG`이므로 Release 빌드에는 존재하지 않는다.
/// 날짜와 ID는 모두 고정값이며 `Date.now`나 무작위 `UUID`를 쓰지 않는다.
/// 사진 파일을 만들지 않고 SwiftData에도 쓰지 않으므로 시뮬레이터에 흔적이 남지 않는다.
enum VFCalendarFixtures {

    /// 모든 시나리오가 기준으로 삼는 달. 2026년 4월.
    static let referenceMonth: Date = day(2026, 4, 1)

    /// 12월 → 1월 전환을 확인하기 위한 달.
    static let yearBoundaryMonth: Date = day(2026, 12, 1)

    static func month(for scenario: VFUITestConfiguration.CalendarFixture) -> Date {
        switch scenario {
        case .yearBoundary: yearBoundaryMonth
        default: referenceMonth
        }
    }

    static func logs(for scenario: VFUITestConfiguration.CalendarFixture) -> [AttendanceLogViewState] {
        switch scenario {
        case .referenceMonth, .selectedRecord, .compactReference, .accessibilityReference:
            return referenceLogs
        case .multipleSameDayRecords:
            return referenceLogs + [sameDaySecondRecord]
        case .win:
            return [record(seed: 11, day: 12, result: .win, ours: 6, theirs: 3)]
        case .loss:
            return [record(seed: 12, day: 5, result: .loss, ours: 2, theirs: 5)]
        case .draw:
            return [record(seed: 13, day: 1, result: .draw, ours: 7, theirs: 7)]
        case .cancelled:
            return [record(seed: 14, day: 8, result: .canceled, ours: nil, theirs: nil)]
        case .longTeamName:
            return [record(seed: 15, day: 12, result: .win, ours: 4, theirs: 1,
                           matchup: "한화 이글스 vs 키움 히어로즈")]
        case .longStadiumName:
            return [record(seed: 16, day: 12, result: .win, ours: 4, theirs: 1,
                           stadium: "광주-기아 챔피언스 필드")]
        case .lightTeamAccent, .darkTeamAccent:
            return [record(seed: 17, day: 12, result: .win, ours: 4, theirs: 1)]
        case .scheduledDesignState, .liveDesignState, .postponedDesignState:
            // 설계 전용 상태는 기록이 아니라 상태 배지로만 표현된다.
            return []
        case .selectedEmptyDate, .emptyMonth, .loading, .recoverableError, .retrySuccess, .yearBoundary:
            return []
        }
    }

    /// 시나리오가 미리 고르는 날짜. 없으면 사용자가 직접 고를 때까지 선택 없음이다.
    static func selectedDate(for scenario: VFUITestConfiguration.CalendarFixture) -> Date? {
        switch scenario {
        case .selectedRecord, .multipleSameDayRecords, .win, .longTeamName, .longStadiumName,
             .lightTeamAccent, .darkTeamAccent, .compactReference, .accessibilityReference:
            return day(2026, 4, 12)
        case .loss: return day(2026, 4, 5)
        case .draw: return day(2026, 4, 1)
        case .cancelled: return day(2026, 4, 8)
        case .selectedEmptyDate: return day(2026, 4, 20)
        default: return nil
        }
    }

    /// 응원 팀. 밝은/어두운 강조색 확인용으로만 달라진다.
    static func teamID(for scenario: VFUITestConfiguration.CalendarFixture) -> String? {
        switch scenario {
        case .lightTeamAccent, .longTeamName: "hanwha-eagles"
        case .darkTeamAccent: "kt-wiz"
        default: nil
        }
    }

    // MARK: - 기준 기록

    /// 4월 12일 승, 4월 5일 패, 4월 1일 무. Pencil 기준 달과 같은 배치.
    static let referenceLogs: [AttendanceLogViewState] = [
        record(seed: 1, day: 12, result: .win, ours: 6, theirs: 3),
        record(seed: 2, day: 5, result: .loss, ours: 2, theirs: 5,
               matchup: "삼성 vs KIA", stadium: "대구 삼성 라이온즈 파크"),
        record(seed: 3, day: 1, result: .draw, ours: 7, theirs: 7,
               matchup: "삼성 vs NC", stadium: "대구 삼성 라이온즈 파크")
    ]

    /// 같은 날(4월 12일)의 두 번째 기록. 개수 보존 확인용.
    static let sameDaySecondRecord: AttendanceLogViewState =
        record(seed: 4, day: 12, result: .loss, ours: 1, theirs: 8,
               matchup: "삼성 vs LG", stadium: "잠실야구장")

    // MARK: - 만들기

    private static func fixtureID(_ seed: Int) -> UUID {
        UUID(uuidString: String(format: "CA1E0DA0-0000-4000-8000-%012d", seed))
            ?? UUID(uuidString: "CA1E0DA0-0000-4000-8000-000000000000")!
    }

    private static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 18
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        return components.date ?? Date(timeIntervalSince1970: 0)
    }

    private static func record(
        seed: Int,
        day dayOfMonth: Int,
        result: GameResult,
        ours: Int?,
        theirs: Int?,
        matchup: String = "삼성 vs LG",
        stadium: String = "잠실야구장"
    ) -> AttendanceLogViewState {
        let date = day(2026, 4, dayOfMonth)
        return AttendanceLogViewState(
            id: fixtureID(seed),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ours,
            opponentScore: theirs,
            seat: "3루 원정석",
            companion: "엄마랑",
            memo: "",
            caption: "",
            diary: "9회말 역전. 옆자리 분과 하이파이브했다.",
            tags: [],
            // 사진 파일을 만들지 않으므로 참조도 두지 않는다.
            photoLocalRefs: []
        )
    }
}

/// 제품에는 없는, 디자인에만 존재하는 경기 상태.
///
/// 홈에 예정 경기 데이터원이 없듯 캘린더에도 없다. 그래서 이 상태는 **표현 전용**이며
/// DEBUG 픽스처를 통해서만 만들어진다. 제품의 `GameResult`에서는 절대 나올 수 없다.
enum CalendarDesignOnlyStatus: String, CaseIterable {
    case scheduled
    case live
    case postponed

    var title: String {
        switch self {
        case .scheduled: "경기 예정"
        case .live: "경기 중"
        case .postponed: "우천 연기"
        }
    }

    var accessibilityIdentifier: String { "calendar.designStatus.\(rawValue)" }
}
#endif
