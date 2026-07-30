import Foundation

/// 편집기 사진의 의미 있는 상태.
///
/// 지금 저장소가 다루는 것은 `photoLocalRefs` 한 벌뿐이지만, "그대로 둔 것"과
/// "새로 고른 것"과 "지운 것"은 서로 다른 뜻이다. 셋을 구분해 두어야 피커 취소나
/// 디코딩 실패가 기존 사진을 조용히 날리는 일을 막을 수 있다.
enum RecordEditorPhotoState: String, Equatable {
    /// 사진이 처음부터 없고 지금도 없다.
    case none
    /// 기존 사진이 그대로다.
    case existingUnchanged
    /// 사진이 없던 자리에 새로 골랐다.
    case newSelection
    /// 기존 사진에 더하거나 바꿔 넣었다.
    case replacedExisting
    /// 기존 사진을 사용자가 지웠고 새로 넣지 않았다.
    case removedExisting
}

/// 편집기 사진의 사용자 의도.
///
/// 피커 표시 여부나 진행 표시 같은 일시적인 것은 여기에 들어오지 않는다.
struct RecordEditorPhotoDraft: Equatable {
    /// 편집기를 열었을 때 기록이 갖고 있던 사진. 수정 중에도 바뀌지 않는다.
    private(set) var originalRefs: [String]
    /// 지금 화면이 들고 있는 사진.
    var refs: [String]

    init(originalRefs: [String] = [], refs: [String]? = nil) {
        self.originalRefs = originalRefs
        self.refs = refs ?? originalRefs
    }

    var state: RecordEditorPhotoState {
        if originalRefs.isEmpty {
            return refs.isEmpty ? .none : .newSelection
        }
        if refs.isEmpty { return .removedExisting }
        return refs == originalRefs ? .existingUnchanged : .replacedExisting
    }

    var hasChanges: Bool { refs != originalRefs }

    /// 사용자가 지운 사진. 되돌릴 수 있게 명시적 의도로만 남긴다.
    var removedRefs: [String] { originalRefs.filter { !refs.contains($0) } }

    /// 이번에 새로 더한 사진.
    var addedRefs: [String] { refs.filter { !originalRefs.contains($0) } }

    mutating func append(_ ref: String) {
        guard !refs.contains(ref) else { return }
        refs.append(ref)
    }

    mutating func remove(_ ref: String) {
        refs.removeAll { $0 == ref }
    }
}

/// 편집기가 다루는 **사용자가 쓴 기록 데이터** 전부. 하나뿐인 정본이다.
///
/// 여기에는 화면·색·시트·비동기 작업이 들어오지 않는다. 그래서 뷰 없이 그대로
/// 단위 테스트할 수 있고, 새로 만들기와 수정하기가 같은 타입을 쓴다.
///
/// Pencil이 그렸지만 아직 저장하지 않는 값(날씨·먹은 것·응원 준비물·별점)은 담지
/// 않는다. 담아 두고 `nil`로 비워 두면 "지원한다"는 거짓 신호가 된다.
struct RecordEditorDraft: Equatable {
    /// 수정 중인 기록의 정체성. 새로 만드는 중이면 없다.
    var editingRecordID: UUID?

    // 1단계 · 경기
    var date: Date
    var favoriteTeamName: String
    var opponentTeamName: String
    var stadiumName: String
    /// 아직 고르지 않았으면 `nil`이다. 임의의 결과를 미리 채우지 않는다.
    var result: GameResult?
    /// 적히지 않은 점수는 `nil`로 남는다. 0으로 바꾸지 않는다.
    var ourScore: Int?
    var opponentScore: Int?
    var gameSource: String?
    var linkedKBOGameID: String?
    var officialRecordURL: String?

    // 2단계 · 그날의 디테일
    var seat: String
    var companion: String

    // 3단계 · 나의 이야기
    var shortMemo: String
    var diary: String
    var moodTag: String
    var highlightTag: String
    /// 경기 정보에서 받아 온 하이라이트 태그. 있으면 이 값이 저장 태그가 된다.
    var appliedHighlightTags: [String]
    var photo: RecordEditorPhotoDraft

    init(
        editingRecordID: UUID?,
        date: Date,
        favoriteTeamName: String,
        opponentTeamName: String,
        stadiumName: String,
        result: GameResult?,
        ourScore: Int?,
        opponentScore: Int?,
        gameSource: String?,
        linkedKBOGameID: String?,
        officialRecordURL: String?,
        seat: String,
        companion: String,
        shortMemo: String,
        diary: String,
        moodTag: String,
        highlightTag: String,
        appliedHighlightTags: [String],
        photo: RecordEditorPhotoDraft
    ) {
        self.editingRecordID = editingRecordID
        self.date = date
        self.favoriteTeamName = favoriteTeamName
        self.opponentTeamName = opponentTeamName
        self.stadiumName = stadiumName
        self.result = result
        self.ourScore = ourScore
        self.opponentScore = opponentScore
        self.gameSource = gameSource
        self.linkedKBOGameID = linkedKBOGameID
        self.officialRecordURL = officialRecordURL
        self.seat = seat
        self.companion = companion
        self.shortMemo = shortMemo
        self.diary = diary
        self.moodTag = moodTag
        self.highlightTag = highlightTag
        self.appliedHighlightTags = appliedHighlightTags
        self.photo = photo
    }

    // MARK: - 하나뿐인 초기화 경로

    /// 초안을 만드는 유일한 길.
    ///
    /// 각 섹션이 스스로 기본값을 정하지 못하게 한 곳에 모았다. 새로 만들 때는
    /// 지어낸 팀·상대·구장·점수·결과를 넣지 않는다. 사용자 설정에서 오는 응원팀만
    /// 반영하는데, 그건 지금 편집기도 이미 하던 일이다.
    static func make(
        mode: RecordEditorMode,
        existingRecord: AttendanceLogViewState? = nil,
        preferredFavoriteTeamName: String? = nil,
        defaultMoodTag: String,
        defaultHighlightTag: String,
        fallbackDate: Date
    ) -> RecordEditorDraft {
        guard let existingRecord, mode.isEditing else {
            return RecordEditorDraft(
                editingRecordID: nil,
                date: mode.initialDate ?? fallbackDate,
                favoriteTeamName: preferredFavoriteTeamName ?? "",
                opponentTeamName: "",
                stadiumName: "",
                result: nil,
                ourScore: nil,
                opponentScore: nil,
                gameSource: nil,
                linkedKBOGameID: nil,
                officialRecordURL: nil,
                seat: "",
                companion: "",
                shortMemo: "",
                diary: "",
                moodTag: defaultMoodTag,
                highlightTag: defaultHighlightTag,
                appliedHighlightTags: [],
                photo: RecordEditorPhotoDraft()
            )
        }
        return RecordEditorDraft(
            record: existingRecord,
            defaultMoodTag: defaultMoodTag,
            defaultHighlightTag: defaultHighlightTag
        )
    }

    /// 기존 기록 → 초안. 값을 지어내지도, 잃지도 않는다.
    init(
        record: AttendanceLogViewState,
        defaultMoodTag: String,
        defaultHighlightTag: String
    ) {
        let names = Self.teamNames(fromMatchup: record.matchup)
        editingRecordID = record.id
        date = record.date
        favoriteTeamName = names.favorite
        opponentTeamName = names.opponent
        // 기록에 적힌 구장 이름이 권위다. 등록부에 없어도 그대로 둔다.
        stadiumName = record.stadium
        result = record.result
        // 적히지 않은 점수는 계속 비어 있다.
        ourScore = record.ourScore
        opponentScore = record.opponentScore
        gameSource = record.gameSource
        linkedKBOGameID = record.linkedKBOGameID
        officialRecordURL = record.officialRecordURL
        seat = record.seat
        companion = record.companion
        shortMemo = record.memo
        diary = record.diary
        moodTag = record.tags.first ?? defaultMoodTag
        highlightTag = record.tags.dropFirst().first ?? defaultHighlightTag
        appliedHighlightTags = []
        photo = RecordEditorPhotoDraft(originalRefs: record.photoLocalRefs)
    }

    /// 저장에 실려 나갈 태그. 지금 저장 경로가 쓰던 규칙 그대로다.
    var saveTags: [String] {
        [moodTag] + (appliedHighlightTags.isEmpty ? [highlightTag] : appliedHighlightTags)
    }

    /// 초안 → 지금 쓰는 저장 입력. 저장 자체는 여기서 하지 않는다.
    ///
    /// 저장 주체는 계속 `AppDataStore`다. 이 함수는 값을 옮기기만 한다.
    /// 결과를 아직 고르지 않았으면 만들지 않는다 — 임의의 결과를 지어내지 않는다.
    /// 저장 경로는 그 전에 검증을 통과해야 하므로 실제로는 언제나 값이 있다.
    func makeSaveInput() -> LogEditorViewModel? {
        guard let result else { return nil }
        return LogEditorViewModel(
            date: date,
            favoriteTeam: favoriteTeamName,
            opponentTeam: opponentTeamName,
            stadium: stadiumName,
            result: result,
            ourScore: ourScore,
            opponentScore: opponentScore,
            gameSource: gameSource,
            linkedKBOGameID: linkedKBOGameID,
            officialRecordURL: officialRecordURL
        )
    }

    /// 처음 상태와 견주어 사용자가 실제로 바꾼 것이 있는지.
    ///
    /// 초안에는 시트·로딩·오류 같은 일시적인 것이 없으므로, 값만 비교하면 된다.
    func isDirty(comparedTo original: RecordEditorDraft) -> Bool {
        self != original
    }

    // MARK: - 대진 문자열 해석

    /// `"삼성 vs LG"` 같은 표시 문자열에서 두 팀 이름을 얻는다.
    ///
    /// 등록부에서 정식 이름을 찾되, 찾지 못하면 적힌 그대로 둔다. 없는 팀을
    /// 지어내지 않는다.
    static func teamNames(fromMatchup matchup: String) -> (favorite: String, opponent: String) {
        let parts = matchup
            .components(separatedBy: " vs ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let rawFavorite = parts.first ?? ""
        let rawOpponent = parts.dropFirst().first ?? ""
        return (
            KBOSeed.team(named: rawFavorite)?.name ?? rawFavorite,
            KBOSeed.team(named: rawOpponent)?.name ?? rawOpponent
        )
    }
}
