import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct PhotoAttachmentService {
    private let directoryName = "VictoryFairyPhotos"

    func savePhoto(from item: PhotosPickerItem, maxPixel: CGFloat = 1800, quality: CGFloat = 0.82) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw PhotoAttachmentError.unreadable
        }
        return try saveImage(image, maxPixel: maxPixel, quality: quality)
    }

    func saveImage(_ image: UIImage, maxPixel: CGFloat = 1800, quality: CGFloat = 0.82) throws -> String {
        let ref = UUID().uuidString
        let url = try url(for: ref)
        let resized = image.resizedForAttachment(maxPixel: maxPixel)
        guard let data = resized.jpegData(compressionQuality: quality) else {
            throw PhotoAttachmentError.unreadable
        }
        try data.write(to: url, options: [.atomic])
        return ref
    }

    func image(for ref: String) -> UIImage? {
        guard let url = try? url(for: ref) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    func compressedData(for ref: String, maxPixel: CGFloat, quality: CGFloat) throws -> Data {
        guard let image = image(for: ref),
              let data = image.resizedForAttachment(maxPixel: maxPixel).jpegData(compressionQuality: quality) else {
            throw PhotoAttachmentError.unreadable
        }
        return data
    }

    func delete(ref: String) {
        guard let url = try? url(for: ref) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func url(for ref: String) throws -> URL {
        let directory = try photosDirectory()
        return directory.appendingPathComponent(ref).appendingPathExtension("jpg")
    }

    private func photosDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}

enum PhotoAttachmentError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "사진을 처리하지 못했어요. 다른 사진을 선택해 주세요."
        }
    }
}

private extension UIImage {
    func resizedForAttachment(maxPixel: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxPixel else { return self }
        let scale = maxPixel / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        // 기본 포맷은 화면 배율(3x)로 렌더하므로 maxPixel의 3배 픽셀이 만들어진다.
        // 저장물은 화면 배율과 무관해야 하므로 scale을 1로 고정한다.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
