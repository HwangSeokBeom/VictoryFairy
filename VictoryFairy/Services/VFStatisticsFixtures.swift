#if DEBUG
import Foundation

/// UI 테스트가 시즌 아카이브의 각 상태를 결정적으로 재현하기 위한 고정 데이터.
///
/// 파일 전체가 `#if DEBUG`이므로 Release 빌드에는 존재하지 않는다.
/// 날짜와 ID는 모두 고정값이며 `Date.now`나 무작위 `UUID`를 쓰지 않는다.
/// 사진 파일을 만들지 않고 SwiftData에도 쓰지 않으므로 시뮬레이터에 흔적이 남지 않는다.
///
/// 기준 시즌은 Pencil `07_Statistics_SeasonArchive`가 그린 값과 같은 **모양**을 갖는다.
/// 8경기 · 5승 2패 1무, 3월 3번 / 4월 5번, 라이온즈파크 5번, KIA 3번, 4월 3연승.
/// 다만 Pencil이 적어 둔 `.625`는 자기 전적(5승 2패)과 맞지 않는 표본 값이라 옮기지
/// 않는다. 실제 규칙(승 ÷ 승패)으로 계산하면 `.714`가 된다.
enum VFStatisticsFixtures {

    /// 모든 시나리오가 기준으로 삼는 시즌.
    static let referenceSeason = 2026
    /// 지난 시즌 선택을 확인하기 위한 시즌.
    static let previousSeason = 2025
    /// 더 오래된 시즌. 정렬 확인용.
    static let oldestSeason = 2024

    // MARK: - 시즌 목록과 시작 시즌

    static func seasons(for scenario: VFUITestConfiguration.StatisticsFixture) -> [SeasonArchiveOption] {
        switch scenario {
        case .multipleSeasons, .previousSeason:
            return [
                SeasonArchiveOption(season: referenceSeason, hasRecords: true),
                SeasonArchiveOption(season: previousSeason, hasRecords: true),
                SeasonArchiveOption(season: oldestSeason, hasRecords: true)
            ]
        default:
            return [SeasonArchiveOption(season: referenceSeason, hasRecords: true)]
        }
    }

    /// 앱이 처음 보여 줄 시즌.
    static func initialSeason(for scenario: VFUITestConfiguration.StatisticsFixture) -> Int {
        scenario == .previousSeason ? previousSeason : referenceSeason
    }

    /// 응원 팀. 밝은/어두운 강조색과 긴 팀 이름 확인용으로만 달라진다.
    static func teamID(for scenario: VFUITestConfiguration.StatisticsFixture) -> String? {
        switch scenario {
        case .lightTeamAccent, .longTeamName: "hanwha-eagles"
        case .darkTeamAccent: "kt-wiz"
        default: nil
        }
    }

    // MARK: - 시나리오별 기록

    /// 고른 시즌의 기록. 시즌을 바꾸면 값이 실제로 달라져야 선택이 검증된다.
    static func logs(
        for scenario: VFUITestConfiguration.StatisticsFixture,
        season: Int
    ) -> [AttendanceLogViewState] {
        switch scenario {
        case .multipleSeasons, .previousSeason:
            switch season {
            case referenceSeason: return referenceLogs
            case previousSeason: return previousSeasonLogs
            case oldestSeason: return oldestSeasonLogs
            default: return []
            }
        default:
            guard season == referenceSeason else { return [] }
            return singleSeasonLogs(for: scenario)
        }
    }

    private static func singleSeasonLogs(
        for scenario: VFUITestConfiguration.StatisticsFixture
    ) -> [AttendanceLogViewState] {
        switch scenario {
        case .referenceSeason, .retrySuccess, .compactReference, .accessibilityReference:
            return referenceLogs
        case .oneRecord:
            return [record(seed: 40, month: 4, day: 12, result: .win, ours: 6, theirs: 3)]
        case .insufficientData:
            return [
                record(seed: 41, month: 4, day: 5, result: .loss, ours: 2, theirs: 5),
                record(seed: 42, month: 4, day: 12, result: .win, ours: 6, theirs: 3)
            ]
        case .noStadium:
            return [
                record(seed: 43, month: 4, day: 5, result: .loss, ours: 2, theirs: 5, stadium: ""),
                record(seed: 44, month: 4, day: 12, result: .win, ours: 6, theirs: 3, stadium: ""),
                record(seed: 45, month: 4, day: 19, result: .win, ours: 4, theirs: 1, stadium: "")
            ]
        case .noOpponent:
            // 대진이 적히지 않은 기록. 상대팀 이름을 지어내지 않으므로 상대팀 통계는
            // 0건이 되고, 구장은 그대로 남아 구장 분석은 정상으로 계산된다.
            return [
                record(seed: 46, month: 4, day: 6, result: .win, ours: 5, theirs: 2, matchup: ""),
                record(seed: 47, month: 4, day: 13, result: .loss, ours: 1, theirs: 4, matchup: ""),
                record(seed: 48, month: 4, day: 20, result: .win, ours: 7, theirs: 3, matchup: "")
            ]
        case .missingScore:
            return [
                record(seed: 46, month: 4, day: 5, result: .loss, ours: nil, theirs: nil),
                record(seed: 47, month: 4, day: 12, result: .win, ours: nil, theirs: nil),
                record(seed: 48, month: 4, day: 19, result: .win, ours: nil, theirs: nil)
            ]
        case .winOnly:
            return [
                record(seed: 49, month: 4, day: 5, result: .win, ours: 5, theirs: 1),
                record(seed: 50, month: 4, day: 12, result: .win, ours: 6, theirs: 3),
                record(seed: 51, month: 4, day: 19, result: .win, ours: 4, theirs: 2)
            ]
        case .lossOnly:
            return [
                record(seed: 52, month: 4, day: 5, result: .loss, ours: 1, theirs: 5),
                record(seed: 53, month: 4, day: 12, result: .loss, ours: 3, theirs: 6),
                record(seed: 54, month: 4, day: 19, result: .loss, ours: 2, theirs: 4)
            ]
        case .drawOnly:
            return [
                record(seed: 55, month: 4, day: 5, result: .draw, ours: 3, theirs: 3),
                record(seed: 56, month: 4, day: 12, result: .draw, ours: 5, theirs: 5),
                record(seed: 57, month: 4, day: 19, result: .draw, ours: 1, theirs: 1)
            ]
        case .cancelledOnly:
            return [
                record(seed: 58, month: 4, day: 5, result: .canceled, ours: nil, theirs: nil),
                record(seed: 59, month: 4, day: 12, result: .canceled, ours: nil, theirs: nil),
                record(seed: 60, month: 4, day: 19, result: .canceled, ours: nil, theirs: nil)
            ]
        case .mixedResults:
            return [
                record(seed: 61, month: 3, day: 28, result: .win, ours: 7, theirs: 2),
                record(seed: 62, month: 4, day: 5, result: .loss, ours: 1, theirs: 5),
                record(seed: 63, month: 4, day: 12, result: .draw, ours: 4, theirs: 4),
                record(seed: 64, month: 4, day: 19, result: .canceled, ours: nil, theirs: nil)
            ]
        case .longTeamName:
            return [
                record(seed: 65, month: 4, day: 12, result: .win, ours: 4, theirs: 1,
                       matchup: "한화 이글스 vs 키움 히어로즈", stadium: "대전 한화생명 볼파크"),
                record(seed: 66, month: 4, day: 19, result: .loss, ours: 2, theirs: 6,
                       matchup: "한화 이글스 vs 키움 히어로즈", stadium: "대전 한화생명 볼파크")
            ]
        case .longStadiumName:
            return [
                record(seed: 67, month: 4, day: 12, result: .win, ours: 4, theirs: 1,
                       matchup: "삼성 vs KIA", stadium: "광주-기아 챔피언스 필드"),
                record(seed: 68, month: 4, day: 19, result: .loss, ours: 2, theirs: 6,
                       matchup: "삼성 vs KIA", stadium: "광주-기아 챔피언스 필드")
            ]
        case .lightTeamAccent, .darkTeamAccent:
            return [
                record(seed: 69, month: 4, day: 12, result: .win, ours: 4, theirs: 1),
                record(seed: 70, month: 4, day: 19, result: .loss, ours: 2, theirs: 6),
                record(seed: 71, month: 4, day: 26, result: .win, ours: 5, theirs: 0)
            ]
        case .allStadiums:
            return allStadiumLogs
        case .empty, .loading, .recoverableError:
            return []
        case .multipleSeasons, .previousSeason:
            return referenceLogs
        }
    }

    /// 정식 구장 아홉 곳에 한 번씩. 화면이 모든 구장을 실제로 그리는지 확인한다.
    /// 구장 이름은 등록부에서 가져오므로 이름이 바뀌면 이 픽스처도 함께 따라간다.
    static let allStadiumLogs: [AttendanceLogViewState] = KBOStadiumSeed.all.enumerated().map { index, stadium in
        record(
            seed: 80 + index,
            month: 4,
            day: index + 1,
            result: index % 2 == 0 ? .win : .loss,
            ours: index % 2 == 0 ? 5 : 1,
            theirs: index % 2 == 0 ? 2 : 4,
            matchup: "삼성 vs LG",
            stadium: stadium.name
        )
    }

    // MARK: - 기준 시즌

    /// Pencil 기준 시즌. 8경기 · 5승 2패 1무.
    ///
    /// 3월 3번, 4월 5번이라 타임라인이 Pencil과 같은 모양이 된다.
    /// 대구 삼성 라이온즈 파크 5번, KIA 3번, 4월 3연승도 Pencil 표본과 같다.
    static let referenceLogs: [AttendanceLogViewState] = [
        record(seed: 1, month: 3, day: 22, result: .win, ours: 5, theirs: 2,
               matchup: "삼성 vs KIA", stadium: lionsPark),
        record(seed: 2, month: 3, day: 28, result: .loss, ours: 1, theirs: 4,
               matchup: "삼성 vs LG", stadium: "잠실야구장"),
        record(seed: 3, month: 3, day: 30, result: .draw, ours: 3, theirs: 3,
               matchup: "삼성 vs NC", stadium: lionsPark),
        record(seed: 4, month: 4, day: 3, result: .win, ours: 7, theirs: 6,
               matchup: "삼성 vs 두산", stadium: "잠실야구장"),
        record(seed: 5, month: 4, day: 9, result: .win, ours: 4, theirs: 0,
               matchup: "삼성 vs NC", stadium: lionsPark),
        record(seed: 6, month: 4, day: 12, result: .win, ours: 9, theirs: 1,
               matchup: "삼성 vs KIA", stadium: lionsPark),
        record(seed: 7, month: 4, day: 18, result: .loss, ours: 2, theirs: 6,
               matchup: "삼성 vs KIA", stadium: "광주-기아 챔피언스 필드"),
        record(seed: 8, month: 4, day: 25, result: .win, ours: 6, theirs: 3,
               matchup: "삼성 vs LG", stadium: lionsPark)
    ]

    /// 지난 시즌. 기준 시즌과 전적이 확실히 달라야 시즌 선택이 검증된다.
    /// 2경기 · 1승 1패, 5월에만 기록이 있다.
    static let previousSeasonLogs: [AttendanceLogViewState] = [
        record(seed: 20, year: previousSeason, month: 5, day: 10, result: .win, ours: 3, theirs: 2,
               matchup: "삼성 vs 롯데", stadium: lionsPark),
        record(seed: 21, year: previousSeason, month: 5, day: 24, result: .loss, ours: 0, theirs: 7,
               matchup: "삼성 vs 롯데", stadium: "사직야구장")
    ]

    /// 가장 오래된 시즌. 취소 한 건만 있어 승률을 계산할 수 없다.
    static let oldestSeasonLogs: [AttendanceLogViewState] = [
        record(seed: 30, year: oldestSeason, month: 6, day: 15, result: .canceled, ours: nil, theirs: nil,
               matchup: "삼성 vs SSG", stadium: "인천 SSG 랜더스필드")
    ]

    private static let lionsPark = "대구 삼성 라이온즈 파크"

    // MARK: - 만들기

    private static func fixtureID(_ seed: Int) -> UUID {
        UUID(uuidString: String(format: "57A7DA7A-0000-4000-8000-%012d", seed))
            ?? UUID(uuidString: "57A7DA7A-0000-4000-8000-000000000000")!
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
        year: Int = referenceSeason,
        month: Int,
        day dayOfMonth: Int,
        result: GameResult,
        ours: Int?,
        theirs: Int?,
        matchup: String = "삼성 vs LG",
        stadium: String = "잠실야구장"
    ) -> AttendanceLogViewState {
        let date = day(year, month, dayOfMonth)
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
            diary: "",
            tags: [],
            // 사진 파일을 만들지 않으므로 참조도 두지 않는다.
            photoLocalRefs: []
        )
    }
}
#endif
