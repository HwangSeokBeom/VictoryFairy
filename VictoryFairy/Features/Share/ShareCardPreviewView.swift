import Photos
import SwiftUI
import UIKit

/// 기록이 소유한 로컬 참조만 순서대로 읽어 첫 정상 이미지를 고른다.
/// 로더가 네트워크 진입점을 받지 않으므로 실패해도 외부 미디어를 요청할 수 없다.
enum MemorySharePhotoResolver {
    static func firstReadable(
        in refs: [String],
        load: (String) -> UIImage?
    ) -> (reference: String, image: UIImage)? {
        for ref in refs {
            if let image = load(ref) { return (ref, image) }
        }
        return nil
    }
}

/// jYs0S의 단일 기록 카드. 화면 크기나 Dynamic Type과 무관한 고정 300×360 구성이다.
struct MemoryShareCardCanvas: View {
    let content: MemoryShareCardContent
    let photo: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.14))
                .frame(width: 296, height: 348)
                .offset(y: 6)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VFColor.memoryCardSurface)
                .frame(width: 296, height: 348)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(VFColor.hairline, lineWidth: 1.2)
                )

            VStack(alignment: .leading, spacing: 8) {
                photoRegion
                    .frame(width: 272, height: 230)

                cardInformation
                    .frame(width: 272, height: 90, alignment: .topLeading)
            }
        }
        .frame(width: MemoryShareCardGeometry.logicalSize.width,
               height: MemoryShareCardGeometry.logicalSize.height)
        // `VFResultStamp`의 @ScaledMetric도 export에서는 고정되어야 한다.
        .environment(\.dynamicTypeSize, .medium)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(content.accessibilitySummary)
        .accessibilityIdentifier("memoryShare.card")
    }

    private var photoRegion: some View {
        ZStack(alignment: .bottomTrailing) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 272, height: 230)
                    .clipped()
            } else {
                MemorySharePhotoPlaceholder()
            }

            VFResultStamp(result: content.result, size: 48)
                .padding(10)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var cardInformation: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.matchupAndScoreText)
                .font(.system(size: 16, weight: .bold, design: .default))
                .foregroundStyle(VFColor.bodyPrimary)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .fixedSize(horizontal: false, vertical: true)

            Text(content.metadataText)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(VFColor.bodySecondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text("승리요정")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .italic()
                .foregroundStyle(VFColor.primaryActionDeep)
                .lineLimit(1)
        }
    }
}

/// 사진이 없거나 모든 로컬 참조를 읽지 못할 때 쓰는 결정적·네트워크 없는 표면.
private struct MemorySharePhotoPlaceholder: View {
    var body: some View {
        ZStack {
            VFColor.highlightSurface
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(VFColor.primaryAction.opacity(0.30), lineWidth: 1)
                .padding(10)
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(VFColor.bodyTertiary)
                Text("기록 사진 없음")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
        .frame(width: 272, height: 230)
        .accessibilityIdentifier("memoryShare.placeholder")
    }
}

@MainActor
enum MemoryShareCardRenderer {
    static func render(content: MemoryShareCardContent, photo: UIImage?) -> UIImage? {
        let renderer = ImageRenderer(
            content: MemoryShareCardCanvas(content: content, photo: photo)
                .frame(width: MemoryShareCardGeometry.logicalSize.width,
                       height: MemoryShareCardGeometry.logicalSize.height)
        )
        renderer.scale = MemoryShareCardGeometry.exportScale
        return renderer.uiImage
    }
}

enum MemoryShareSaveError: Error {
    case permissionDenied
}

@MainActor
enum MemorySharePhotoLibrarySaver {
    static func save(_ image: UIImage) async throws {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        let granted: Bool
        switch current {
        case .authorized, .limited:
            granted = true
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { result in
                    continuation.resume(returning: result)
                }
            }
            granted = status == .authorized || status == .limited
        default:
            granted = false
        }

        guard granted else { throw MemoryShareSaveError.permissionDenied }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

/// 공유와 저장의 부작용 경계를 한곳에 둔다.
/// 공유·취소·화면 닫기는 저장 클로저를 호출하지 않고, 명시적 저장만 호출한다.
@MainActor
final class MemoryShareOutputController: ObservableObject {
    typealias Renderer = () -> UIImage?
    typealias Saver = (UIImage) async throws -> Void

    @Published var shareImage: UIImage?
    @Published var isShowingShareSheet = false
    @Published var message: String?
    private(set) var explicitSaveInvocationCount = 0

    private let renderer: Renderer
    private let saver: Saver

    init(renderer: @escaping Renderer, saver: @escaping Saver) {
        self.renderer = renderer
        self.saver = saver
    }

    func prepareNativeShare() {
        guard let image = renderer() else {
            message = "카드를 이미지로 만들지 못했어요."
            return
        }
        shareImage = image
        isShowingShareSheet = true
    }

    func saveToPhotos() async {
        guard let image = renderer() else {
            message = "카드를 이미지로 만들지 못했어요."
            return
        }
        explicitSaveInvocationCount += 1
        do {
            try await saver(image)
            message = "이미지를 사진 앱에 저장했어요."
        } catch MemoryShareSaveError.permissionDenied {
            message = "사진 저장 권한이 없어 저장하지 못했어요. 공유는 계속 사용할 수 있어요."
        } catch {
            message = "이미지 저장에 실패했어요. 공유를 사용해 주세요."
        }
    }

    func shareSheetDidDismiss() {
        isShowingShareSheet = false
        shareImage = nil
    }

    /// 명시적으로 빈 구현이다. 미리보기 닫기는 어떤 저장도 하지 않는다.
    func previewDidDismiss() {}
}

/// 고정 캔버스를 가용 화면 폭 안에서만 축소하는 미리보기 래퍼.
private struct ScaledMemoryShareCardPreview: View {
    let content: MemoryShareCardContent
    let photo: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(MemoryShareCardGeometry.aspectRatio, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let scale = min(proxy.size.width / MemoryShareCardGeometry.logicalSize.width,
                                    proxy.size.height / MemoryShareCardGeometry.logicalSize.height)
                    MemoryShareCardCanvas(content: content, photo: photo)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: MemoryShareCardGeometry.logicalSize.width * scale,
                               height: MemoryShareCardGeometry.logicalSize.height * scale,
                               alignment: .topLeading)
                }
            }
            .frame(maxWidth: MemoryShareCardGeometry.logicalSize.width)
    }
}

struct ShareCardPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let content: MemoryShareCardContent
    let photo: UIImage?
    @StateObject private var output: MemoryShareOutputController
    @State private var debugExportProof: String?

    @MainActor
    init(
        log: AttendanceLogViewState,
        photoLoader: @escaping (String) -> UIImage? = {
            #if DEBUG
            if let image = VFRecordDetailFixtures.inMemoryImage(
                for: $0,
                maxPixel: PhotoDisplayTarget.shareCard.maxPixel
            ) {
                return image
            }
            #endif
            return PhotoAttachmentService().image(for: $0, target: .shareCard)
        },
        renderer: ((MemoryShareCardContent, UIImage?) -> UIImage?)? = nil,
        saver: ((UIImage) async throws -> Void)? = nil
    ) {
        let content = MemoryShareCardContent(log: log)
        let photo = MemorySharePhotoResolver.firstReadable(
            in: content.photoLocalRefs,
            load: photoLoader
        )?.image
        let render = renderer ?? { content, photo in
            MemoryShareCardRenderer.render(content: content, photo: photo)
        }
        let save = saver ?? { image in
            try await MemorySharePhotoLibrarySaver.save(image)
        }

        self.content = content
        self.photo = photo
        _output = StateObject(
            wrappedValue: MemoryShareOutputController(
                renderer: { render(content, photo) },
                saver: save
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                ScreenHeaderView(
                    title: "추억 카드 미리보기",
                    subtitle: "이 직관 기록 한 건을 이미지로 공유하거나 사진에 저장해요."
                )

                fixtureScenarioMarker

                ScaledMemoryShareCardPreview(content: content, photo: photo)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("이미지 1200 × 1440 · 5:6")
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("memoryShare.geometry")

                #if DEBUG
                if let debugExportProof {
                    Text(debugExportProof)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.statusSuccess)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("memoryShare.exportProof")
                }
                #endif

                if let message = output.message {
                    Text(message)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("memoryShare.message")
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: VFSpacing.sm) { outputButtons }
                    VStack(spacing: VFSpacing.xs) { outputButtons }
                }

                VFSecondaryButton(title: "닫기", systemImage: "xmark") {
                    output.previewDidDismiss()
                    dismiss()
                }
                .accessibilityIdentifier("memoryShare.close")
            }
            .padding(VFSpacing.md)
            .vfTabContentPadding()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("memoryShare.root")
        }
        .navigationTitle("추억 카드")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $output.isShowingShareSheet, onDismiss: {
            output.shareSheetDidDismiss()
        }) {
            if let image = output.shareImage {
                ActivityView(items: [image])
            }
        }
        .task {
            #if DEBUG
            guard VFUITestConfiguration.activeMemoryShareScenarioIdentifier != nil,
                  debugExportProof == nil,
                  let image = MemoryShareCardRenderer.render(content: content, photo: photo),
                  let data = image.pngData(),
                  let decoded = UIImage(data: data),
                  let cgImage = decoded.cgImage else { return }
            debugExportProof = "디코딩 확인 · \(cgImage.width) × \(cgImage.height)"
            #endif
        }
        .vfScreenBackground()
    }

    @ViewBuilder
    private var outputButtons: some View {
        VFPrimaryButton(title: "공유", systemImage: "square.and.arrow.up") {
            output.prepareNativeShare()
        }
        .accessibilityIdentifier("memoryShare.share")

        VFSecondaryButton(title: "사진에 저장", systemImage: "square.and.arrow.down") {
            Task { await output.saveToPhotos() }
        }
        .accessibilityIdentifier("memoryShare.save")
    }

    @ViewBuilder
    private var fixtureScenarioMarker: some View {
        if let identifier = VFUITestConfiguration.activeMemoryShareScenarioIdentifier {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(Text(verbatim: ""))
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
