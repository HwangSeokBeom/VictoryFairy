import Foundation

/// Pencil `08_RecordDetail` 한 장이 필요로 하는 값 전체.
///
/// 화면이 아니라 **의미**만 담는다. 색도 뷰도 들어 있지 않고, 순수 계산이라 화면 없이
/// 그대로 검증할 수 있다. 값은 모두 저장된 직관 기록에서 나오며, Pencil이 예시로 적어 둔
/// 문장이나 숫자는 여기에 존재하지 않는다.
struct RecordDetailPresentation: Equatable {
    /// 기록의 정체성. 수정·삭제가 같은 기록을 가리키는지 확인할 때 쓴다.
    let recordID: UUID
    /// Pencil `내비 제목`. 화면 제목이 곧 기록의 날짜다.
    let navigationTitle: String
    /// Pencil `손글씨 제목`. 사용자가 남긴 한 줄 메모.
    let title: String?
    /// Pencil `장소 메타`. 구장과 좌석 가운데 실제로 적힌 것만 잇는다.
    let placeMeta: String?
    let matchup: RecordDetailMatchup
    let stadium: RecordDetailStadium
    let media: RecordDetailMedia
    let note: RecordDetailNote
    /// Pencil `무드 섹션`·`순간 섹션`이 쓰던 자리. 실제로 저장된 태그만 담는다.
    let moodTag: String?
    let highlightTags: [String]
    /// Pencil `디테일 섹션`. 도메인이 실제로 들고 있는 항목만 남는다.
    let details: [RecordDetailFact]
    /// 공식 기록 링크. 서버가 준 값이 있을 때만.
    let officialRecordURL: URL?
    /// 참고용 경기 정보 표기.
    let sourceLabel: String?
    let season: Int

    /// VoiceOver가 화면을 한 문장으로 요약해 읽을 값.
    var accessibilitySummary: String {
        var parts = [navigationTitle, matchup.spokenSummary]
        parts.append(stadium.spokenSummary)
        parts.append(media.spokenSummary)
        if let title { parts.append(title) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - 매치업과 결과

/// Pencil `스코어보드`가 보여 주는 값.
///
/// Pencil은 이닝별 라인스코어까지 그리지만 이 앱에는 이닝 기록 데이터원이 없다.
/// 지어내지 않고 실제로 저장된 두 팀과 최종 점수만 담는다.
struct RecordDetailMatchup: Equatable {
    /// 사용자의 응원 팀. 기록 문자열에서 찾지 못하면 없음.
    let myTeam: RecordDetailTeam?
    /// 상대 팀. 기록 문자열에 상대가 없으면 없음.
    let opponent: RecordDetailTeam?
    let result: GameResult
    /// 응원 팀 점수. 취소되었거나 적히지 않았으면 없음.
    let myScore: Int?
    let opponentScore: Int?

    /// 승패가 갈렸고 두 점수가 모두 있을 때만 점수를 보여 준다.
    var scoreText: String? {
        guard result != .canceled, let myScore, let opponentScore else { return nil }
        return "\(myScore) : \(opponentScore)"
    }

    /// 점수가 없을 때 그 자리에 대신 놓는 문구. 숫자를 지어내지 않는다.
    var scorePlaceholder: String? {
        guard scoreText == nil else { return nil }
        return result == .canceled ? "경기 취소" : "점수 미기록"
    }

    var resultTitle: String { result.title }

    /// 색이 아니라 글자로 결과를 전한다.
    var resultDescription: String { result.diaryTitle }

    var spokenSummary: String {
        var parts: [String] = []
        if let myTeam { parts.append(myTeam.name) }
        if let opponent { parts.append("상대 \(opponent.name)") }
        parts.append(resultDescription)
        // 화면의 "6 : 3"은 그대로 읽으면 알아듣기 어렵다. 말로 풀어 읽는다.
        if let myScore, let opponentScore, scoreText != nil {
            parts.append("\(myScore)대 \(opponentScore)")
        } else if let scorePlaceholder {
            parts.append(scorePlaceholder)
        }
        return parts.joined(separator: ", ")
    }
}

/// 매치업 한쪽. 정식 팀 등록부에서 찾은 팀이면 ID까지 들고 있다.
struct RecordDetailTeam: Equatable {
    /// 정식 등록부에 있으면 canonical 팀 ID. 없으면 없음.
    let teamID: String?
    /// 화면에 쓰는 이름. 등록부에 없으면 기록에 적힌 표기 그대로다.
    let name: String
    /// 뱃지에 찍는 짧은 표기.
    let badgeText: String

    /// 한국어 표시 문구를 식별자로 쓰지 않는다.
    var accessibilityIdentifierSuffix: String { teamID ?? "unregistered" }

    init?(team: KBOTeam?, fallbackLabel: String?) {
        if let team {
            teamID = team.id
            name = team.name
            badgeText = team.badgeInitial
            return
        }
        guard let label = fallbackLabel?.trimmedOrNil else { return nil }
        teamID = nil
        name = label
        badgeText = String(label.prefix(2))
    }
}

// MARK: - 구장

/// 이 기록이 열린 구장.
///
/// 기록에 남은 구장을 그대로 쓴다. 사용자의 주 관람 구장이나 응원 팀의 홈 구장으로
/// 바꿔치기하지 않는다.
struct RecordDetailStadium: Equatable {
    /// 정식 등록부(`KBOStadiumSeed`)에 있으면 그 ID. 없으면 없음.
    let stadiumID: String?
    /// 기록에 적힌 이름 그대로. 비어 있으면 없음.
    let name: String?
    /// 응원 팀의 홈 구장인지. 등록부에서 확인할 수 있을 때만 값이 있다.
    let isHomeGame: Bool?
    /// Pencil `구장 메타`. 도시와 홈 팀처럼 등록부가 아는 사실만 잇는다.
    let meta: String?

    /// 등록부에 없거나 이름이 비어 있는 경우.
    var isKnown: Bool { stadiumID != nil }

    /// Pencil `아이브로우`. 확인할 수 없으면 문구를 만들지 않는다.
    var eyebrow: String? {
        guard let isHomeGame else { return nil }
        return isHomeGame ? "HOME GAME · 홈 직관" : "AWAY GAME · 원정 직관"
    }

    var spokenSummary: String {
        guard let name else { return "구장 정보 없음" }
        guard let isHomeGame else { return name }
        return "\(name), \(isHomeGame ? "홈 경기" : "원정 경기")"
    }

    /// 한국어 구장 이름을 식별자로 만들지 않는다.
    var accessibilityIdentifierSuffix: String {
        guard let stadiumID else { return name == nil ? "missing" : "unknown" }
        return stadiumID
    }
}

// MARK: - 미디어

/// 사진 영역이 가질 수 있는 상태.
///
/// "사진 없음"과 "파일이 사라짐"을 같은 회색 사각형으로 뭉개지 않는다. 사용자가 사진을
/// 붙인 적이 없는 것과, 붙였는데 읽을 수 없는 것은 전혀 다른 사실이다.
enum RecordDetailMedia: Equatable {
    /// 사진을 붙인 적이 없다.
    case none
    /// 아직 읽는 중이다.
    case loading
    /// 실제 사진이 있다.
    case available(refs: [String])
    /// 참조는 있는데 파일이 없다.
    case missingFile(refs: [String])
    /// 파일은 있는데 이미지로 해석되지 않는다.
    case decodeFailed(refs: [String])

    var refs: [String] {
        switch self {
        case .none, .loading: []
        case .available(let refs), .missingFile(let refs), .decodeFailed(let refs): refs
        }
    }

    var hasUsableImage: Bool {
        if case .available = self { return true }
        return false
    }

    /// 화면에 그대로 보여 주는 안내. 내부 이름이나 파일 경로를 노출하지 않는다.
    var message: String? {
        switch self {
        case .none: "이 기록에는 사진이 없어요"
        case .loading: "사진을 불러오는 중이에요"
        case .available: nil
        case .missingFile: "사진 파일을 찾을 수 없어요"
        case .decodeFailed: "사진을 열 수 없어요"
        }
    }

    var spokenSummary: String {
        switch self {
        case .none: "사진 없음"
        case .loading: "사진 불러오는 중"
        case .available(let refs): "사진 \(refs.count)장"
        case .missingFile: "사진 파일 없음"
        case .decodeFailed: "사진을 열 수 없음"
        }
    }

    /// UI 테스트가 상태를 구분해 집을 수 있게 하는 접미사.
    var accessibilityIdentifierSuffix: String {
        switch self {
        case .none: "empty"
        case .loading: "loading"
        case .available: "photo"
        case .missingFile: "missingFile"
        case .decodeFailed: "decodeFailed"
        }
    }
}

// MARK: - 사용자가 쓴 기록

/// Pencil `일기 섹션`.
struct RecordDetailNote: Equatable {
    /// 사용자가 쓴 본문. 비어 있으면 없음.
    let body: String?
    /// Pencil `일기 서명`. 구장과 사용자 이름이 모두 있을 때만 만든다.
    let signature: String?

    var isEmpty: Bool { body == nil }

    /// 비어 있을 때 보여 줄 안내. 문장을 대신 써 주지 않는다.
    var emptyMessage: String { "이 기록에는 아직 일기가 없어요" }
}

// MARK: - 그날의 작은 것들

/// Pencil `디테일 셀`. 도메인이 실제로 들고 있는 항목만 만든다.
struct RecordDetailFact: Equatable, Identifiable {
    enum Kind: String, Equatable, CaseIterable {
        case companion
        case seat
    }

    let kind: Kind
    let label: String
    let value: String

    var id: String { kind.rawValue }
    var accessibilityIdentifier: String { "recordDetail.fact.\(kind.rawValue)" }
    var accessibilityLabel: String { "\(label), \(value)" }
}

// MARK: - 불러오기와 삭제

/// 상세 화면이 가질 수 있는 데이터 상태.
enum RecordDetailDataState: Equatable {
    case loaded
    case loading
    case error(String)
}

/// 삭제를 시도한 결과.
///
/// 기기 저장소에서 지우지 못했으면 기록은 그대로 남는다. 화면은 그 사실을 숨기지 않는다.
enum RecordDeletionOutcome: Equatable {
    case deleted
    case failed(String)

    var didDelete: Bool { self == .deleted }
}

// MARK: - 화면 식별자

/// 상세 화면이 쓰는 접근성 식별자.
///
/// 한 곳에 모아 두면 화면과 UI 테스트가 같은 문자열을 본다. 값은 모두 영문이며,
/// 화면에 보이는 한국어 문구를 정체성으로 쓰지 않는다.
/// 뒤로 가기와 날짜에는 따로 식별자를 두지 않는다. 뒤로 가기는 시스템 내비게이션 버튼
/// (`BackButton`)이 그대로 정체성을 갖고, 날짜는 화면 제목 자체라서 내비게이션 바 이름으로
/// 조회한다. 같은 것에 이름을 두 번 붙이지 않는다.
///
/// 매치업 히어로는 `scoreboard`가 그 영역이다.
enum RecordDetailAccessibilityID {
    static let root = "recordDetail.root"
    static let edit = "recordDetail.edit"
    static let overflow = "recordDetail.overflow"
    static let title = "recordDetail.title"
    static let placeMeta = "recordDetail.placeMeta"
    static let scoreboard = "recordDetail.scoreboard"
    static let result = "recordDetail.result"
    static let score = "recordDetail.score"
    static let media = "recordDetail.media"
    static let note = "recordDetail.note"
    static let noteEmpty = "recordDetail.note.empty"
    static let mood = "recordDetail.mood"
    static let highlights = "recordDetail.highlights"
    static let details = "recordDetail.details"
    static let share = "recordDetail.share"
    static let officialRecord = "recordDetail.officialRecord"
    static let delete = "recordDetail.delete"
    static let deleteConfirm = "recordDetail.delete.confirm"
    static let deleteCancel = "recordDetail.delete.cancel"
    static let loading = "recordDetail.loading"
    static let error = "recordDetail.error"
    static let retry = "recordDetail.retry"

    static func team(_ suffix: String) -> String { "recordDetail.team.\(suffix)" }
    static func opponent(_ suffix: String) -> String { "recordDetail.opponent.\(suffix)" }
    static func stadium(_ suffix: String) -> String { "recordDetail.stadium.\(suffix)" }
    static func media(_ suffix: String) -> String { "recordDetail.media.\(suffix)" }
}

// MARK: - 날짜 표기

extension DateFormatter {
    /// Pencil `내비 제목`이 쓰는 날짜. 앱 전체와 같은 ko_KR / Asia/Seoul 기준이다.
    static let vfRecordDetailTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter
    }()

    /// VoiceOver가 읽을 날짜. 요일까지 온전히 읽는다.
    static let vfRecordDetailVoiceOver: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter
    }()
}

extension String {
    /// 공백만 있는 값은 없는 것으로 본다.
    var trimmedOrNil: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
