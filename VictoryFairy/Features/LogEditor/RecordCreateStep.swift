import Foundation

/// 개정 Pencil `08_RecordCreate_Step1~3`이 정한 세 단계.
///
/// 이 타입은 **정체성과 순서만** 갖는다. 화면을 그리지 않고, 진행 표시·다음·이전·
/// 건너뛰기·부분 저장 같은 동작도 갖지 않는다. 지금 편집기는 여전히 한 장짜리
/// 스크롤 폼이고, 이 모델은 어떤 값이 어느 단계에 속하는지와 검증을 묶는 데만 쓴다.
///
/// 현재 단계는 저장하지 않는다. SwiftData·백엔드·사용자 설정 어디에도 넣지 않는다.
enum RecordCreateStep: String, CaseIterable, Identifiable, Hashable {
    /// Pencil `08_RecordCreate_Step1` — "어떤 경기였나요?"
    case game
    /// Pencil `08_RecordCreate_Step2` — "그날의 디테일을 더해볼까요?"
    case details
    /// Pencil `08_RecordCreate_Step3` — "오늘의 이야기를 남겨주세요"
    case memory

    var id: String { rawValue }

    /// 1부터 시작하는 자리. Pencil 진행 표시의 순서와 같다.
    var position: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    /// 전체 단계 수. Pencil이 세 단계로 못박았다.
    static var total: Int { allCases.count }

    var previous: RecordCreateStep? {
        position > 1 ? Self.allCases[position - 2] : nil
    }

    var next: RecordCreateStep? {
        position < Self.total ? Self.allCases[position] : nil
    }

    /// Pencil 진행 표시의 라벨. 화면에 보이는 문구이지, 내부 이름이 아니다.
    var accessibilityTitle: String {
        switch self {
        case .game: "경기"
        case .details: "그날의 디테일"
        case .memory: "나의 이야기"
        }
    }

    /// 이 단계가 소유하는, **지금 저장되는** 값들.
    var supportedFields: [RecordEditorField] {
        RecordEditorField.allCases.filter { $0.step == self }
    }

    /// 이 단계에 아직 결정되지 않은 Pencil 전용 항목이 남아 있는가.
    ///
    /// - `game`: "여기까지만 저장할게요"(부분 저장)
    /// - `details`: 날씨 · 먹은 것 · 응원 준비물
    /// - `memory`: 별점 · 500자 제한
    ///
    /// 이 패스는 그 어느 것도 구현하지 않는다. 목록 자체는 계약 테스트가 못박는다.
    var hasUnresolvedPencilFields: Bool { true }
}

/// 지금 실제로 저장되는 편집기 값. 각 값이 어느 단계에 속하는지 한 곳에서 정한다.
///
/// Pencil이 그렸지만 아직 저장하지 않는 항목(날씨·먹은 것·응원 준비물·별점)은
/// 여기에 넣지 않는다. 넣으면 "지원한다"는 거짓말이 된다.
enum RecordEditorField: String, CaseIterable, Identifiable, Hashable {
    // 1단계 · 경기
    case date
    case stadium
    case favoriteTeam
    case opponentTeam
    case result
    case ourScore
    case opponentScore
    case linkedKBOGame

    // 2단계 · 그날의 디테일
    case seat
    case companion

    // 3단계 · 나의 이야기
    case photos
    case shortMemo
    case moodTag
    case highlightTag
    case diary

    var id: String { rawValue }

    var step: RecordCreateStep {
        switch self {
        case .date, .stadium, .favoriteTeam, .opponentTeam, .result, .ourScore, .opponentScore, .linkedKBOGame:
            .game
        case .seat, .companion:
            .details
        case .photos, .shortMemo, .moodTag, .highlightTag, .diary:
            .memory
        }
    }

    /// 저장하려면 반드시 있어야 하는 값. 현재 편집기의 검증 범위를 넓히지 않는다.
    var isRequired: Bool {
        switch self {
        case .favoriteTeam, .opponentTeam, .stadium, .result: true
        default: false
        }
    }

    /// 검증 문구가 가리키는 이름. 화면에 이미 보이는 라벨과 같다.
    var displayName: String {
        switch self {
        case .date: "경기 날짜"
        case .stadium: "구장"
        case .favoriteTeam: "응원팀"
        case .opponentTeam: "상대팀"
        case .result: "경기 결과"
        case .ourScore: "응원팀 점수"
        case .opponentScore: "상대팀 점수"
        case .linkedKBOGame: "연결된 경기"
        case .seat: "좌석"
        case .companion: "동행 유형"
        case .photos: "사진"
        case .shortMemo: "한 줄 메모"
        case .moodTag: "분위기"
        case .highlightTag: "하이라이트"
        case .diary: "직관 다이어리"
        }
    }
}
