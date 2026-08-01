import PhotosUI
import SwiftUI

/// 사진 첨부의 규칙이 사는 한 곳.
///
/// 지금 편집기가 하던 일을 그대로 옮겨 왔다 — 최대 열 장, 남은 자리만큼만 받고,
/// 한 장이 실패해도 나머지는 계속 넣으며, 실패나 취소로는 이미 있던 사진을 지우지
/// 않는다. 새 흐름이 같은 규칙을 다시 쓰지 않도록 두 화면이 이 타입을 함께 쓴다.
///
/// 피커가 들고 있는 `PhotosPickerItem`은 일시적인 값이라 초안에 들어오지 않는다.
/// 초안에 남는 것은 저장된 사진 참조(`RecordEditorPhotoDraft`)뿐이다.
enum RecordEditorPhotoAttachment {

    /// 한 기록에 붙일 수 있는 사진 수. 지금 편집기가 쓰던 값 그대로다.
    static let maximumPhotoCount = 10

    /// 사진을 받아들인 결과. 화면은 이 값을 안내 문구로만 옮긴다.
    enum ImportOutcome: Equatable {
        /// 고른 것이 없어 아무 일도 하지 않았다.
        case nothingSelected
        /// 자리가 없어 한 장도 받지 못했다.
        case limitReached(limit: Int)
        /// 몇 장을 받았다. 중간에 실패한 장이 있으면 마지막 오류를 함께 전한다.
        case finished(added: Int, failure: String?)

        /// 화면에 띄울 안내. 없으면 조용히 지나간다.
        var message: String? {
            switch self {
            case .nothingSelected: nil
            case .limitReached(let limit): "사진은 최대 \(limit)장까지 추가할 수 있어요."
            case .finished(_, let failure): failure
            }
        }
    }

    /// 아직 더 받을 수 있는 장수.
    static func remainingSlots(for photo: RecordEditorPhotoDraft) -> Int {
        max(0, maximumPhotoCount - photo.refs.count)
    }

    /// 고른 사진을 저장하고 초안에 더한다.
    ///
    /// 실패한 장은 건너뛰고 나머지를 계속 받는다. 이미 들어 있던 사진은 어떤
    /// 경우에도 그대로 남는다 — 지우는 것은 오직 사용자의 명시적 삭제뿐이다.
    /// 값을 받아 값을 돌려준다. `inout`을 쓰지 않으므로 `@Binding`을 들고 있는
    /// 화면에서도 `await` 너머로 안전하게 부를 수 있다.
    static func importItems(
        _ items: [PhotosPickerItem],
        into photo: RecordEditorPhotoDraft,
        service: PhotoAttachmentService = PhotoAttachmentService()
    ) async -> (photo: RecordEditorPhotoDraft, outcome: ImportOutcome) {
        guard !items.isEmpty else { return (photo, .nothingSelected) }
        let slots = remainingSlots(for: photo)
        guard slots > 0 else { return (photo, .limitReached(limit: maximumPhotoCount)) }

        var updated = photo
        var added = 0
        var failure: String?
        for item in items.prefix(slots) {
            do {
                let ref = try await service.savePhoto(from: item)
                updated.append(ref)
                added += 1
            } catch {
                failure = error.localizedDescription
            }
        }
        return (updated, .finished(added: added, failure: failure))
    }
}
