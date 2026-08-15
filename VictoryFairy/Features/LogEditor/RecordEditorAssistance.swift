import Foundation

/// 기록 보조 기능(티켓 OCR · 경기 자동 찾기 · 사진 분석 · AI 초안)이 정본 초안에 값을
/// 옮기는 **하나뿐인 규칙**.
///
/// 지금 편집기(`LogEditorView`)와 세 단계 작성 흐름이 이 한 곳을 함께 쓴다. 그래서
/// 매핑이 두 벌이 되지 않고, 한쪽만 고쳐져 서로 다르게 동작하는 일도 없다.
///
/// 여기에는 화면도 통신도 없다. 값 변환뿐이고, 서버를 부르는 것은 여전히
/// `AppDataStore`다. 새 서비스도, 새 제공자도, 새 키도 만들지 않는다.
enum RecordEditorAssistance {
    /// 보조 기능이 고를 수 있는 기분 어휘. 지금 편집기가 쓰던 목록 그대로다.
    ///
    /// 3단계가 화면에 그리는 다섯 가지와는 다른 목록이다. 둘을 억지로 합치면 지금
    /// 편집기가 이미 저장해 온 값의 뜻이 바뀌므로, 서로 모르는 값은 **지우지 않고
    /// 그대로 보존한다**(`RecordCreateStep3View.moodSelection(for:)`).
    static let moods = ["짜릿함", "아쉬움", "편안함", "열광적", "분노", "감동"]
    static let highlights = ["홈런", "역전승", "끝내기", "연장전", "호수비", "응원 분위기", "우천 취소"]
    static let tones = ["담백하게", "감성적으로", "유쾌하게", "SNS 캡션처럼"]
    static let companions = ["혼자", "친구", "가족", "연인", "모임"]

    // MARK: - 티켓 OCR

    /// 티켓에서 읽어 낸 값을 초안에 옮긴다. 읽히지 않은 값은 건드리지 않는다.
    ///
    /// 지원하는 자리만 채운다 — 날짜·응원팀·상대팀·구장·좌석. 없는 사실을 지어내지
    /// 않고, 저장도 하지 않는다. 확인은 사용자의 몫이라는 안내 문구를 돌려준다.
    static func applyTicketSuggestion(
        _ suggestion: TicketFieldSuggestion,
        to draft: inout RecordEditorDraft
    ) -> String {
        if let gameDate = suggestion.gameDate {
            draft.date = gameDate
        }
        if let favoriteTeamName = suggestion.favoriteTeamName {
            draft.favoriteTeamName = favoriteTeamName
        }
        if let opponentTeamName = suggestion.opponentTeamName, opponentTeamName != draft.favoriteTeamName {
            draft.opponentTeamName = opponentTeamName
        }
        if let stadiumName = suggestion.stadiumName {
            draft.stadiumName = stadiumName
        }
        if let seatText = suggestion.seatText {
            draft.seat = seatText
        }
        draft.appliedHighlightTags = []
        return "인식한 내용이 정확한지 확인해 주세요."
    }

    // MARK: - 경기 자동 찾기

    /// 이 후보를 적용하면 사용자가 쓰던 다이어리를 덮어쓰게 되는가.
    ///
    /// 덮어쓰기 전에 물어보는 규칙 자체를 여기 둔다. 두 편집기가 같은 판단을 쓴다.
    static func requiresDiaryOverwriteConfirmation(
        for candidate: KBOGameCandidateDTO,
        draft: RecordEditorDraft,
        favoriteTeamID: String?
    ) -> Bool {
        guard !candidate.isScheduled else { return false }
        guard !candidate.suggestedDiaryTemplate(favoriteTeamID: favoriteTeamID).isEmpty else { return false }
        return !draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 고른 경기 후보를 초안에 적용한다. 저장하지 않는다.
    ///
    /// 공식 기록 주소와 출처 메타데이터를 그대로 실어 둔다. 후보가 없을 때 경기를
    /// 지어내는 길은 없다 — 이 함수는 후보를 받아야만 부를 수 있다.
    static func applyKBOGameCandidate(
        _ candidate: KBOGameCandidateDTO,
        to draft: inout RecordEditorDraft,
        favoriteTeamID: String,
        lookupSource: String?,
        shouldOverwriteDiary: Bool
    ) -> String {
        let perspective = candidate.favoriteTeamPerspective(favoriteTeamID: favoriteTeamID)
        draft.date = Date.vfParseServerDate(candidate.date)
        draft.opponentTeamName = perspective.opponentTeamName
        draft.stadiumName = candidate.suggestedStadiumName
        draft.gameSource = candidate.source ?? lookupSource
        draft.linkedKBOGameID = candidate.gameID
        draft.officialRecordURL = candidate.officialRecordURL?.absoluteString

        if !candidate.isScheduled, let result = perspective.result {
            draft.result = result
        }
        if !candidate.isScheduled,
           let favoriteScore = perspective.favoriteTeamScore,
           let opponentScore = perspective.opponentTeamScore {
            draft.ourScore = favoriteScore
            draft.opponentScore = opponentScore
        }

        if !candidate.isScheduled {
            draft.moodTag = candidate.preferredMoodTag(for: draft.result ?? .canceled, availableMoods: moods)
            draft.highlightTag = candidate.preferredHighlightTag(availableHighlights: highlights)
            draft.appliedHighlightTags = candidate.suggestedHighlightTags
            // 사용자가 쓴 한 줄 메모는 지우지 않는다.
            if draft.shortMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.shortMemo = candidate.suggestedShortMemo(favoriteTeamID: favoriteTeamID)
            }
            let suggestedDiary = candidate.suggestedDiaryTemplate(favoriteTeamID: favoriteTeamID)
            if shouldOverwriteDiary || draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.diary = suggestedDiary
            }
        }
        return "경기 정보를 적용했어요. 저장 전 내용을 확인해 주세요."
    }

    // MARK: - 사진 분석

    /// 사진 분석 결과를 초안에 적용한다.
    ///
    /// 아는 어휘에 들어맞는 기분·하이라이트만 옮기고, 다이어리 힌트는 이미 쓴 글을
    /// 지우지 않고 뒤에 잇는다. 사진은 건드리지 않는다.
    static func applyPhotoAnalysis(
        _ analysis: PhotoAnalysisDTO,
        to draft: inout RecordEditorDraft
    ) {
        if let mood = analysis.suggestedMoodTags.first, moods.contains(mood) {
            draft.moodTag = mood
        }
        if let highlight = analysis.suggestedHighlightTags.first, highlights.contains(highlight) {
            draft.highlightTag = highlight
        }
        if let hint = analysis.diaryHintText?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            draft.diary = draft.diary.isEmpty ? hint : "\(draft.diary)\n\n\(hint)"
        }
    }

    // MARK: - AI 초안

    /// AI 초안 요청. 지금 쓰는 제공자와 입력 경계를 그대로 쓴다.
    ///
    /// 비어 있는 태그는 실어 보내지 않는다. 고르지 않은 기분을 빈 문자열로 보내면
    /// 서버에는 "이름 없는 태그"라는 없는 사실이 전해진다.
    static func makeDiaryDraftRequest(from draft: RecordEditorDraft, tone: String) -> DiaryDraftRequest {
        DiaryDraftRequest(
            gameDate: DateFormatter.vfAPIDate.string(from: draft.date),
            favoriteTeamName: draft.favoriteTeamName,
            opponentTeamName: draft.opponentTeamName,
            stadiumName: draft.stadiumName,
            result: (draft.result ?? .canceled).serverValue,
            scoreText: scoreText(for: draft),
            moodTags: nonEmptyTags([draft.moodTag]),
            highlightTags: nonEmptyTags([draft.highlightTag]),
            companionType: sanitizedCompanionType(draft.companion),
            tone: tone.aiToneValue,
            extraNoteSanitized: draft.shortMemo.sanitizedExtraNote,
            locale: "ko-KR"
        )
    }

    static func makeTemplateDraftRequest(from draft: RecordEditorDraft, tone: String) -> TemplateDraftRequest {
        let request = makeDiaryDraftRequest(from: draft, tone: tone)
        return TemplateDraftRequest(
            gameDate: request.gameDate,
            favoriteTeamName: request.favoriteTeamName,
            opponentTeamName: request.opponentTeamName,
            stadiumName: request.stadiumName,
            result: request.result,
            scoreText: request.scoreText,
            moodTags: request.moodTags,
            highlightTags: request.highlightTags,
            companionType: request.companionType,
            tone: request.tone,
            extraNoteSanitized: request.extraNoteSanitized,
            locale: request.locale
        )
    }

    /// 서버에 닿지 못했을 때 기기에서 만드는 기본 문장. 새 제공자가 아니다.
    static func localTemplateDraft(from draft: RecordEditorDraft, tone: String) -> DiaryDraftDTO {
        let text = DiaryTemplateGenerator().generate(
            favoriteTeamName: draft.favoriteTeamName,
            opponentTeamName: draft.opponentTeamName,
            stadium: draft.stadiumName,
            result: draft.result ?? .canceled,
            favoriteTeamScore: draft.result == .canceled ? nil : draft.ourScore,
            opponentTeamScore: draft.result == .canceled ? nil : draft.opponentScore,
            moodTags: nonEmptyTags([draft.moodTag]),
            highlightTags: nonEmptyTags([draft.highlightTag]),
            companionType: draft.companion,
            seatText: draft.seat,
            shortMemo: draft.shortMemo,
            tone: tone
        )
        return DiaryDraftDTO(
            draftText: text,
            summaryText: "기본 문장 초안",
            shareText: nil,
            hashtags: ["#승리요정", "#KBO직관"],
            model: "local-template",
            safetyNotice: "저장 전 직접 확인해 주세요.",
            warnings: []
        )
    }

    /// 만들어진 초안을 다이어리에 넣을 방법. 사용자가 쓴 글을 말없이 지우지 않는다.
    enum DiaryApplyPlan: Equatable {
        /// 비어 있어 그대로 넣으면 된다.
        case replaceEmpty(String)
        /// 이미 쓴 글이 있다. 바꿀지 이어 붙일지 물어야 한다.
        case needsChoice(String)
        /// 넣을 것이 없다.
        case none
    }

    static func diaryApplyPlan(for draftText: String, existingDiary: String) -> DiaryApplyPlan {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        return existingDiary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .replaceEmpty(trimmed)
            : .needsChoice(trimmed)
    }

    static func appendingDiary(_ text: String, to existing: String) -> String {
        existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? text
            : "\(existing)\n\n\(text)"
    }

    // MARK: - 공통

    static func sanitizedCompanionType(_ companion: String) -> String? {
        let trimmed = companion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch trimmed {
        case "혼자": return "alone"
        case "친구": return "friends"
        case "가족": return "family"
        case "연인": return "partner"
        default: return "group"
        }
    }

    /// AI 초안 요청에 실어 보내는 점수 문구. 없는 점수를 0으로 지어내지 않는다.
    static func scoreText(for draft: RecordEditorDraft) -> String {
        guard draft.result != .canceled else { return "취소" }
        guard let ours = draft.ourScore, let theirs = draft.opponentScore else {
            return draft.result?.title ?? ""
        }
        return "\(ours):\(theirs) \(draft.result?.title ?? "")"
    }

    /// 비어 있는 태그를 빼고 남긴다. 고르지 않은 것은 보내지 않는다.
    static func nonEmptyTags(_ tags: [String]) -> [String] {
        tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

extension String {
    var aiToneValue: String {
        switch self {
        case "감성적으로": "warm"
        case "유쾌하게": "playful"
        case "SNS 캡션처럼": "social"
        default: "plain"
        }
    }

    var sanitizedExtraNote: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collapsed = trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(collapsed.prefix(120))
    }
}
