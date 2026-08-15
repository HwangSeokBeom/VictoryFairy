#if DEBUG
import Foundation

/// `09_States` 구장 시트와 한 기록 추억 카드의 결정적 DEBUG 전용 데이터.
/// 파일 전체가 조건부 컴파일되므로 아래 인자·시나리오·표시 문자열은 Release에 없다.
enum VFStatesFixtures {
    // MARK: - Stadium sheet

    static func stadiumCatalog(
        for scenario: VFUITestConfiguration.StadiumSheetFixture
    ) -> [KBOStadium] {
        switch scenario {
        case .empty:
            return []
        case .longContent:
            return KBOStadiumSeed.all.map { stadium in
                guard stadium.id == "jamsil" else { return stadium }
                return KBOStadium(
                    id: stadium.id,
                    name: stadium.name,
                    shortName: "잠실 아주 긴 구장 표시 이름 접근성 검증",
                    homeTeamIDs: stadium.homeTeamIDs + ["samsung-lions", "hanwha-eagles"]
                )
            }
        case .canonicalSelected, .invalidCurrent, .allNine:
            return KBOStadiumSeed.all
        }
    }

    static func initialStadiumName(
        for scenario: VFUITestConfiguration.StadiumSheetFixture
    ) -> String {
        switch scenario {
        case .canonicalSelected, .longContent, .allNine:
            return KBOStadiumSeed.stadium(id: "jamsil")?.name ?? ""
        case .invalidCurrent:
            return "과거의 미등록 구장"
        case .empty:
            return ""
        }
    }

    // MARK: - One-record Memory Card

    static func memoryShareLog(
        for scenario: VFUITestConfiguration.MemoryShareFixture
    ) -> AttendanceLogViewState {
        switch scenario {
        case .withPhoto:
            return record(seed: 1, photoRefs: [readablePhotoRef])
        case .noPhoto:
            return record(seed: 2, photoRefs: [])
        case .unreadablePhoto:
            return record(seed: 3, photoRefs: [unreadablePhotoRef])
        case .scored:
            return record(seed: 4, result: .win, ours: 6, theirs: 3)
        case .canceled:
            // 숫자가 있어도 취소가 우선이며 0:0을 그리지 않는지 검증한다.
            return record(seed: 5, result: .canceled, ours: 0, theirs: 0)
        case .missingScore:
            return record(seed: 6, result: .loss, ours: nil, theirs: nil)
        case .longContent:
            return record(
                seed: 7,
                matchup: "등록부밖아주긴첫번째구단명 vs 등록부밖아주긴두번째구단명",
                stadium: "대한민국 어딘가에 실제로 기록된 등록부 밖의 아주 긴 야구장 이름",
                result: .draw,
                ours: 12,
                theirs: 12
            )
        }
    }

    private static let readablePhotoRef = "\(VFRecordDetailFixtures.inMemoryPhotoPrefix)-states-card"
    private static let unreadablePhotoRef = "vf-uitest-states-card-unreadable"

    private static func fixtureID(_ seed: Int) -> UUID {
        UUID(uuidString: String(format: "09F10000-0000-4000-8000-%012d", seed))!
    }

    private static func record(
        seed: Int,
        matchup: String = "삼성 라이온즈 vs LG 트윈스",
        stadium: String = "잠실야구장",
        result: GameResult = .win,
        ours: Int? = 6,
        theirs: Int? = 3,
        photoRefs: [String] = []
    ) -> AttendanceLogViewState {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "Asia/Seoul")
        components.year = 2026
        components.month = 4
        components.day = 12
        components.hour = 18
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
            seat: "3루 원정석",
            companion: "친구",
            memo: "카드에 들어가면 안 되는 메모",
            caption: "카드에 들어가면 안 되는 캡션",
            diary: "카드에 들어가면 안 되는 일기",
            tags: ["카드제외"],
            photoLocalRefs: photoRefs
        )
    }
}
#endif
