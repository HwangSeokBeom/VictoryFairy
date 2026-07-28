#if DEBUG
import Foundation

/// UI 테스트가 피드의 각 상태를 결정적으로 재현하기 위한 고정 기록.
///
/// 파일 전체가 `#if DEBUG`로 감싸여 있어 Release 빌드에는 존재하지 않는다.
/// 따라서 제품 대체 데이터(fallback)가 될 수 없다.
///
/// 날짜와 ID는 모두 고정값이다. `Date.now`나 무작위 `UUID`를 쓰지 않으므로
/// 언제 실행해도 같은 순서와 같은 그룹이 나온다.
enum VFFeedFixtures {

    static func logs(for fixture: VFUITestConfiguration.FeedFixture) -> [AttendanceLogViewState] {
        switch fixture {
        case .populated: pencilReference
        case .multiMonth: multiMonth
        case .longContent: longContent
        case .empty, .error, .loading: []
        }
    }

    // MARK: - Pencil 기준 상태

    /// Pencil `05_Feed_RecordList`가 그리는 네 건. 4월 3건 + 3월 1건.
    static let pencilReference: [AttendanceLogViewState] = [
        make(
            seed: 1, year: 2026, month: 4, day: 12,
            matchup: "삼성 vs LG", stadium: "잠실야구장",
            result: .win, ours: 6, theirs: 3,
            seat: "3루 원정석", companion: "엄마랑",
            diary: "9회말 역전. 옆자리 분과 하이파이브했다.",
            hasPhoto: true
        ),
        make(
            seed: 2, year: 2026, month: 4, day: 5,
            matchup: "삼성 vs KIA", stadium: "대구 삼성 라이온즈 파크",
            result: .loss, ours: 2, theirs: 5,
            seat: "1루 익사이팅석", companion: "지수랑",
            diary: "졌지만 치킨은 맛있었다. 다음엔 이긴다.",
            hasPhoto: true
        ),
        make(
            seed: 3, year: 2026, month: 4, day: 1,
            matchup: "삼성 vs NC", stadium: "대구 삼성 라이온즈 파크",
            result: .draw, ours: 7, theirs: 7,
            seat: "3루 내야석", companion: "혼자",
            diary: "연장 12회. 무승부도 이 정도면 추억이다.",
            hasPhoto: false
        ),
        make(
            seed: 4, year: 2026, month: 3, day: 28,
            matchup: "삼성 vs 두산", stadium: "대구 삼성 라이온즈 파크",
            result: .win, ours: 4, theirs: 1,
            seat: "중앙 테이블석", companion: "아빠랑",
            diary: "개막 2연전 스윕! 올해는 진짜 다르다.",
            hasPhoto: true
        )
    ]

    // MARK: - 여러 달 · 같은 날 · 연도 경계

    /// 그룹화와 정렬을 흔드는 경우를 모두 담는다.
    /// 같은 날 두 건, 3월과 4월, 그리고 직전 시즌 10월까지.
    static let multiMonth: [AttendanceLogViewState] = pencilReference + [
        make(
            seed: 5, year: 2026, month: 4, day: 12,
            matchup: "삼성 vs LG", stadium: "잠실야구장",
            result: .loss, ours: 1, theirs: 8,
            seat: "3루 원정석", companion: "친구랑",
            diary: "같은 날 더블헤더 두 번째 경기.",
            hasPhoto: false
        ),
        make(
            seed: 6, year: 2025, month: 10, day: 30,
            matchup: "삼성 vs KT", stadium: "수원 kt wiz 파크",
            result: .canceled, ours: nil, theirs: nil,
            seat: "1루 응원석", companion: "동생이랑",
            diary: "우천 취소. 다음을 기약했다.",
            hasPhoto: false
        )
    ]

    // MARK: - 긴 내용

    /// 사진 없음 · 긴 메모 · 가장 긴 구장 이름으로 레이아웃을 밀어붙인다.
    static let longContent: [AttendanceLogViewState] = [
        make(
            seed: 7, year: 2026, month: 4, day: 20,
            matchup: "한화 vs KIA", stadium: "광주-기아 챔피언스 필드",
            result: .win, ours: 12, theirs: 11,
            seat: "3루 지정석 상단 통로 옆자리", companion: "회사 동료들이랑",
            diary: "연장 11회까지 가는 난타전이었다. 점수가 계속 뒤집혀서 마지막까지 자리를 못 떴고, 목이 다 쉬었는데도 끝나고 나서 한참을 서서 박수를 쳤다. 이런 경기를 직접 본 게 처음이라 오래 기억에 남을 것 같다.",
            hasPhoto: false
        )
    ]

    // MARK: - 만들기

    /// 고정 시드로 결정적인 UUID를 만든다.
    private static func fixtureID(_ seed: Int) -> UUID {
        UUID(uuidString: String(format: "F1E0D000-0000-4000-8000-%012d", seed))
            ?? UUID(uuidString: "F1E0D000-0000-4000-8000-000000000000")!
    }

    private static func make(
        seed: Int,
        year: Int, month: Int, day: Int,
        matchup: String, stadium: String,
        result: GameResult, ours: Int?, theirs: Int?,
        seat: String, companion: String,
        diary: String, hasPhoto: Bool
    ) -> AttendanceLogViewState {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 18
        components.minute = 30
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.calendar = Calendar(identifier: .gregorian)
        let date = components.date ?? Date(timeIntervalSince1970: 0)

        return AttendanceLogViewState(
            id: fixtureID(seed),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ours,
            opponentScore: theirs,
            seat: seat,
            companion: companion,
            memo: "",
            caption: "",
            diary: diary,
            tags: [],
            // 픽스처는 사진 파일을 만들지 않는다. 저장소에 남는 가짜 데이터를 만들지
            // 않기 위해서다. 따라서 사진 참조도 두지 않는다. `hasPhoto`는 앞으로
            // 실제 파일을 붙일 때를 위한 자리이며 지금은 항상 빈 배열을 만든다.
            photoLocalRefs: []
        )
    }
}
#endif
