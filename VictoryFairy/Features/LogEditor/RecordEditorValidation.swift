import Foundation

/// 초안 검증 결과. 화면은 이 값을 그리기만 하고, 규칙을 다시 쓰지 않는다.
struct RecordEditorValidationResult: Equatable {
    /// 저장을 막는 값들. 화면에 보이는 순서대로다.
    let blockingFields: [RecordEditorField]
    /// 막지는 않지만 사용자에게 한 번 확인시킬 것.
    let warnings: [RecordEditorValidationWarning]

    var isValid: Bool { blockingFields.isEmpty }
    /// 저장해도 되는가. 현재 편집기의 저장 조건과 같다.
    var isSaveReady: Bool { isValid }
    var firstInvalidField: RecordEditorField? { blockingFields.first }
    /// 아직 채워지지 않은 값이 속한 단계들.
    var invalidSteps: [RecordCreateStep] {
        var seen: [RecordCreateStep] = []
        for field in blockingFields where !seen.contains(field.step) {
            seen.append(field.step)
        }
        return seen
    }

    /// 화면에 띄울 한 문장. 첫 번째로 막힌 값만 말한다.
    var blockingMessage: String? {
        guard let firstInvalidField else { return nil }
        switch firstInvalidField {
        case .favoriteTeam: return "응원팀을 선택해 주세요."
        case .opponentTeam: return "상대팀을 선택해 주세요."
        case .stadium: return "구장을 선택해 주세요."
        case .result: return "경기 결과를 선택해 주세요."
        default: return "\(firstInvalidField.displayName)을(를) 확인해 주세요."
        }
    }
}

/// 저장을 막지는 않는 경고.
enum RecordEditorValidationWarning: String, Equatable {
    /// 점수와 결과가 서로 어긋나 보인다.
    case scoreDisagreesWithResult
}

/// 초안 검증 규칙. SwiftUI 밖에 있고, 뷰 없이 그대로 시험할 수 있다.
///
/// 뒤에 올 세 단계 흐름이 쓸 수 있도록 단계별로도 물어볼 수 있게 해 두었지만,
/// 지금 요구 조건 자체는 넓히지 않는다. 날씨·먹은 것·응원 준비물·별점·500자
/// 제한은 어느 것도 검증에 넣지 않는다.
enum RecordEditorValidation {

    static func validate(_ draft: RecordEditorDraft) -> RecordEditorValidationResult {
        var blocking: [RecordEditorField] = []

        if KBOSeed.team(named: draft.favoriteTeamName) == nil {
            blocking.append(.favoriteTeam)
        }
        if draft.opponentTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocking.append(.opponentTeam)
        }
        if draft.stadiumName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocking.append(.stadium)
        }
        if draft.result == nil {
            blocking.append(.result)
        }

        var warnings: [RecordEditorValidationWarning] = []
        if disagreesWithScore(draft) {
            warnings.append(.scoreDisagreesWithResult)
        }

        return RecordEditorValidationResult(blockingFields: blocking, warnings: warnings)
    }

    /// 한 단계만 따로 본다. 지금 화면은 쓰지 않지만 검증을 단계로 묶는 근거다.
    static func validate(_ draft: RecordEditorDraft, step: RecordCreateStep) -> RecordEditorValidationResult {
        let all = validate(draft)
        return RecordEditorValidationResult(
            blockingFields: all.blockingFields.filter { $0.step == step },
            warnings: step == .game ? all.warnings : []
        )
    }

    /// 점수와 결과가 어긋나 보이는가. 지금 화면이 쓰던 규칙 그대로다.
    static func disagreesWithScore(_ draft: RecordEditorDraft) -> Bool {
        guard let result = draft.result else { return false }
        guard let ours = draft.ourScore, let theirs = draft.opponentScore else { return false }
        switch result {
        case .win: return ours <= theirs
        case .loss: return ours >= theirs
        case .draw: return ours != theirs
        case .canceled: return false
        }
    }
}
