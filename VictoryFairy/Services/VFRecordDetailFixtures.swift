#if DEBUG
import Foundation
import UIKit

/// UI 테스트가 기록 상세의 각 상태를 결정적으로 재현하기 위한 고정 데이터.
///
/// 파일 전체가 `#if DEBUG`이므로 Release 빌드에는 존재하지 않는다.
/// 날짜와 ID는 모두 고정값이며 `Date.now`나 무작위 `UUID`를 쓰지 않는다.
/// SwiftData에 쓰지 않고 **사진 파일도 만들지 않는다** — 사진이 필요한 시나리오는
/// 그릴 때마다 메모리에서 만든 이미지를 쓴다. 그래서 시뮬레이터에 흔적이 남지 않고,
/// 번들에 넣을 테스트 전용 이미지 리소스도 없다.
enum VFRecordDetailFixtures {

    /// 기준 기록이 속한 시즌.
    static let referenceSeason = 2026

    /// 메모리 이미지에만 쓰는 사진 참조 접두사.
    /// 제품이 만드는 참조는 UUID 기반이라 이 접두사와 겹치지 않는다.
    static let inMemoryPhotoPrefix = "vf-uitest-inmemory-photo"

    private static let firstPhotoRef = "\(inMemoryPhotoPrefix)-1"
    /// 파일이 사라진 상황을 만드는 참조. 어떤 경로로도 존재하지 않는다.
    private static let missingPhotoRef = "vf-uitest-missing-photo"
    /// 파일은 있다고 보고하지만 이미지로 해석되지 않는 상황을 만드는 참조.
    private static let undecodablePhotoRef = "vf-uitest-undecodable-photo"

    // MARK: - 시나리오별 기록

    static func log(for scenario: VFUITestConfiguration.RecordDetailFixture) -> AttendanceLogViewState {
        switch scenario {
        case .referenceRecord, .withPhoto, .loading, .recoverableError, .retrySuccess,
             .deleteConfirmation, .deleteSuccess, .deleteFailure,
             .compactReference, .accessibilityReference:
            return referenceLog
        case .withoutPhoto:
            return record(seed: 2, photos: [])
        case .missingPhotoFile:
            return record(seed: 3, photos: [missingPhotoRef])
        case .failedPhotoDecode:
            return record(seed: 4, photos: [undecodablePhotoRef])
        case .longNote:
            return record(seed: 5, diary: longDiary)
        case .noNote:
            return record(seed: 6, diary: "")
        case .missingScore:
            return record(seed: 7, ours: nil, theirs: nil)
        case .missingOpponent:
            return record(seed: 8, matchup: "삼성")
        case .missingStadium:
            return record(seed: 9, stadium: "")
        case .unknownStadium:
            return record(seed: 10, stadium: "동대문운동장")
        case .win:
            return record(seed: 11, result: .win, ours: 6, theirs: 3)
        case .loss:
            return record(seed: 12, result: .loss, ours: 2, theirs: 7)
        case .draw:
            return record(seed: 13, result: .draw, ours: 4, theirs: 4)
        case .cancelled:
            return record(seed: 14, result: .canceled, ours: nil, theirs: nil)
        case .longTeamName:
            return record(seed: 15, matchup: "한화 이글스 vs 키움 히어로즈",
                          stadium: "대전 한화생명 볼파크")
        case .longStadiumName:
            return record(seed: 16, stadium: "광주-기아 챔피언스 필드")
        case .lightTeamAccent, .darkTeamAccent:
            return record(seed: 17)
        }
    }

    /// 사진 영역이 어떤 상태여야 하는지. 파일 시스템을 보지 않고 시나리오가 직접 정한다.
    static func media(for scenario: VFUITestConfiguration.RecordDetailFixture) -> RecordDetailMedia {
        switch scenario {
        case .withoutPhoto, .missingStadium, .noNote, .longNote, .missingScore,
             .missingOpponent, .unknownStadium:
            return .none
        case .missingPhotoFile:
            return .missingFile(refs: [missingPhotoRef])
        case .failedPhotoDecode:
            return .decodeFailed(refs: [undecodablePhotoRef])
        case .loading:
            return .loading
        default:
            return .available(refs: [firstPhotoRef])
        }
    }

    static func dataState(for scenario: VFUITestConfiguration.RecordDetailFixture) -> RecordDetailDataState {
        switch scenario {
        case .loading: .loading
        case .recoverableError: .error("연결이 원활하지 않아요. 네트워크를 확인하고 다시 시도해 주세요.")
        default: .loaded
        }
    }

    /// 삭제를 눌렀을 때 돌려줄 결과. 저장소를 건드리지 않고 결과만 정한다.
    static func scriptedDeletion(
        for scenario: VFUITestConfiguration.RecordDetailFixture
    ) -> RecordDeletionOutcome? {
        switch scenario {
        case .deleteSuccess: .deleted
        case .deleteFailure: .failed("기록을 지우지 못했어요. 잠시 후 다시 시도해 주세요.")
        default: nil
        }
    }

    /// 응원 팀. 밝은/어두운 강조색과 긴 팀 이름 확인용으로만 달라진다.
    static func teamID(for scenario: VFUITestConfiguration.RecordDetailFixture) -> String? {
        switch scenario {
        case .lightTeamAccent, .longTeamName: "hanwha-eagles"
        case .darkTeamAccent: "kt-wiz"
        default: nil
        }
    }

    /// 일기 서명에 쓰는 이름. 실제 사용자 설정과 같은 자리에 심는다.
    static let displayName = "민지"

    // MARK: - 기준 기록

    /// Pencil `08_RecordDetail`과 같은 모양의 기록.
    /// 2026년 4월 12일, 삼성 vs LG, 잠실 원정, 6:3 승.
    static let referenceLog: AttendanceLogViewState = record(seed: 1)

    private static let longDiary = """
    3점 뒤진 9회초, 다들 반쯤 포기했을 때 대타가 걸어 나왔다. 옆자리 아저씨가 \
    "이번엔 진짜다"라고 혼잣말하는 걸 들었고, 나는 그 말을 믿지 않았다.

    그런데 정말로 넘어갔다. 잠실 3루가 그렇게 크게 울린 건 처음이었다. 엄마랑 둘이 \
    부둥켜안고 소리를 질렀고, 목이 다 쉬어서 집에 오는 길에는 말도 제대로 못 했다.

    야구를 보는 이유를 누가 물으면 이 날 이야기를 하면 될 것 같다. 아홉 번을 지더라도 \
    이런 한 번이 있으니까. 다음에도 엄마랑 같이 오기로 했다. 🥹⚾️
    """

    // MARK: - 만들기

    private static func fixtureID(_ seed: Int) -> UUID {
        UUID(uuidString: String(format: "D37A11ED-0000-4000-8000-%012d", seed))
            ?? UUID(uuidString: "D37A11ED-0000-4000-8000-000000000000")!
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
        result: GameResult = .win,
        ours: Int? = 6,
        theirs: Int? = 3,
        matchup: String = "삼성 vs LG",
        stadium: String = "잠실야구장",
        diary: String = "9회초 대타 한 방으로 뒤집은 날. 목이 다 쉬었다.",
        photos: [String] = [firstPhotoRef]
    ) -> AttendanceLogViewState {
        let date = day(referenceSeason, 4, 12)
        return AttendanceLogViewState(
            id: fixtureID(seed),
            date: date,
            dateText: DateFormatter.vfDisplayDate.string(from: date),
            matchup: matchup,
            stadium: stadium,
            result: result,
            ourScore: ours,
            opponentScore: theirs,
            seat: "3루 원정석 K열",
            companion: "엄마랑",
            memo: "목이 다 쉰 날",
            caption: "",
            diary: diary,
            tags: ["벅차오름", "역전승"],
            photoLocalRefs: photos
        )
    }

    // MARK: - 메모리 이미지

    /// 사진 파일을 만들지 않고 그 자리에서 그린다.
    ///
    /// 접두사가 맞지 않으면 `nil`이라, 제품이 만든 참조는 절대 이 그림으로 대체되지
    /// 않는다. 같은 참조는 언제나 같은 그림을 낸다.
    static func inMemoryImage(for ref: String, maxPixel: CGFloat) -> UIImage? {
        guard ref.hasPrefix(inMemoryPhotoPrefix) else { return nil }
        let side = max(min(maxPixel, 720), 120)
        let size = CGSize(width: side, height: side * 0.68)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.05, green: 0.10, blue: 0.18, alpha: 1).setFill()
            context.fill(rect)
            // 잔디와 내야를 아주 단순한 도형으로 그린다. 실제 사진처럼 보이게 하지 않는다.
            UIColor(red: 0.16, green: 0.40, blue: 0.26, alpha: 1).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: -size.width * 0.2, y: size.height * 0.35,
                           width: size.width * 1.4, height: size.height * 1.2)
            )
            UIColor(red: 0.62, green: 0.44, blue: 0.28, alpha: 1).setFill()
            let infield = UIBezierPath()
            infield.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.52))
            infield.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.74))
            infield.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.96))
            infield.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.74))
            infield.close()
            infield.fill()
            UIColor(red: 0.95, green: 0.72, blue: 0.24, alpha: 1).setFill()
            context.cgContext.fillEllipse(
                in: CGRect(x: size.width * 0.16, y: size.height * 0.14,
                           width: size.width * 0.08, height: size.width * 0.08)
            )
        }
    }
}
#endif
