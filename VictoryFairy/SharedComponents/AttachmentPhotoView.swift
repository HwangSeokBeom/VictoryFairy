import SwiftUI
import UIKit

/// 첨부 사진을 메인 스레드 밖에서 디코딩해 표시한다.
///
/// 셀 재사용 대비: `.task(id:)`가 ref가 바뀌면 이전 작업을 취소하고, 완료 시점에도
/// 요청 당시의 ref와 현재 ref를 다시 비교해 늦게 도착한 이미지가 다른 셀에 붙지 않게 한다.
/// 로딩 중에는 같은 자리를 차지하는 플레이스홀더를 그려 레이아웃이 흔들리지 않는다.
struct AttachmentPhotoView: View {
    let ref: String
    let target: PhotoDisplayTarget

    @State private var image: UIImage?
    @State private var loadedRef: String?

    private let service = PhotoAttachmentService()

    var body: some View {
        ZStack {
            if let image, loadedRef == ref {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // 사진 파일이 사라졌거나 아직 읽지 못한 경우.
                // 빈 회색 사각형 대신 사진 없음과 같은 자리표시자를 써서
                // 무엇이 비어 있는지 알 수 있게 한다.
                VFColor.supportAccentPale
                Image(systemName: "photo")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
        }
        .task(id: ref) {
            await load(for: ref)
        }
    }

    private func load(for requestedRef: String) async {
        let maxPixel = target.maxPixel
        #if DEBUG
        // UI 테스트용 메모리 이미지. 파일을 만들지 않고 그 자리에서 그린다.
        // 접두사가 맞지 않으면 nil이라 제품이 만든 참조는 절대 이 경로를 타지 않는다.
        if let generated = VFRecordDetailFixtures.inMemoryImage(for: requestedRef, maxPixel: maxPixel) {
            image = generated
            loadedRef = requestedRef
            return
        }
        #endif
        if let cached = service.cachedImage(for: requestedRef, maxPixel: maxPixel) {
            image = cached
            loadedRef = requestedRef
            return
        }
        let decoded = await service.imageAsync(for: requestedRef, maxPixel: maxPixel)
        guard !Task.isCancelled, requestedRef == ref else { return }
        image = decoded
        loadedRef = requestedRef
    }
}
