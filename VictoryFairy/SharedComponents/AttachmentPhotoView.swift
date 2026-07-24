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
                Rectangle()
                    .fill(VFColor.mutedLine.opacity(0.35))
            }
        }
        .task(id: ref) {
            await load(for: ref)
        }
    }

    private func load(for requestedRef: String) async {
        let maxPixel = target.maxPixel
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
