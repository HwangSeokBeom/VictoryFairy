import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct ProfileImageUploadPayload {
    let data: Data
    let mimeType: String
    let previewImage: UIImage
}

struct ProfileImageProcessor {
    static let maxLongestSide: CGFloat = 512
    static let maxUploadBytes = 2_000_000

    func payload(from item: PhotosPickerItem) async throws -> ProfileImageUploadPayload {
        guard let data = try await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            throw ProfileImageProcessingError.unreadable
        }
        return try payload(from: image)
    }

    func payload(from image: UIImage) throws -> ProfileImageUploadPayload {
        let resized = image.resizedForProfileUpload(maxLongestSide: Self.maxLongestSide)
        for quality in [0.82, 0.78, 0.75] {
            guard let data = resized.jpegData(compressionQuality: quality) else {
                throw ProfileImageProcessingError.unreadable
            }
            if data.count <= Self.maxUploadBytes {
                return ProfileImageUploadPayload(data: data, mimeType: "image/jpeg", previewImage: resized)
            }
        }
        throw ProfileImageProcessingError.tooLarge
    }
}

enum ProfileImageProcessingError: LocalizedError {
    case unreadable
    case tooLarge

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "사진을 처리하지 못했어요. 다른 사진을 선택해 주세요."
        case .tooLarge:
            return "이미지 용량이 커서 업로드할 수 없어요. 다른 사진을 선택해 주세요."
        }
    }
}

private extension UIImage {
    func resizedForProfileUpload(maxLongestSide: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        let scale = longestSide > maxLongestSide ? maxLongestSide / longestSide : 1
        let targetSize = CGSize(
            width: max(1, floor(size.width * scale)),
            height: max(1, floor(size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
