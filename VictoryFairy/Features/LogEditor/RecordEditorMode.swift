import Foundation

/// 편집기가 새 기록을 만드는 중인지, 기존 기록을 고치는 중인지.
///
/// 두 경우가 서로 다른 상태 모델을 쓰지 않도록, 차이를 이 한 타입에 모은다.
/// 초안(`RecordEditorDraft`)은 하나뿐이고 모드만 다르다.
enum RecordEditorMode: Equatable, Hashable {
    /// 새 기록. 캘린더처럼 날짜를 정해 주는 진입점이 있으면 그 날짜로 시작한다.
    case create(initialDate: Date?)
    /// 기존 기록 수정. 반드시 원래 기록의 정체성을 그대로 들고 있는다.
    case edit(recordID: UUID)

    static var create: RecordEditorMode { .create(initialDate: nil) }

    var isEditing: Bool {
        if case .edit = self { return true }
        return false
    }

    /// 수정 중인 기록의 ID. 새로 만드는 중이면 없다.
    var editingRecordID: UUID? {
        if case .edit(let recordID) = self { return recordID }
        return nil
    }

    /// 진입점이 정해 준 시작 날짜. 수정에서는 기록 자신의 날짜가 이긴다.
    var initialDate: Date? {
        if case .create(let initialDate) = self { return initialDate }
        return nil
    }

    /// 화면 제목. 지금 편집기가 쓰던 문구와 같다.
    var navigationTitle: String {
        isEditing ? "직관 기록 수정" : "직관 기록 추가"
    }
}
