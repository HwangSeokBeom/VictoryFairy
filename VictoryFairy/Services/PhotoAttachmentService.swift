import CoreGraphics
import Foundation
import ImageIO
import PhotosUI
import SwiftUI
import UIKit

/// 첨부 사진을 표시하는 지점별 목표 픽셀.
/// 화면에 그려지는 최장변(pt) × 화면 배율을 넘지 않도록 잡는다.
enum PhotoDisplayTarget {
    /// 캘린더 사진 보기 셀: 최장변 54pt
    case calendarCell
    /// 피드 카드 첨부 스트립: 최장변 240pt
    case feedStrip
    /// 직관 상세 첨부 스트립: 최장변 240pt(높이 210pt)
    case detailStrip
    /// 기록 편집 화면 썸네일 격자: 92pt
    case editorThumbnail
    /// 공유 카드: 1080×1920 캔버스에 scale 1로 렌더하므로 카드 폭만큼 필요
    case shareCard

    var maxPixel: CGFloat {
        let screenScale = UIScreen.main.scale
        switch self {
        case .calendarCell: return 54 * screenScale
        case .feedStrip, .detailStrip: return 240 * screenScale
        case .editorThumbnail: return 92 * screenScale
        case .shareCard: return 1080
        }
    }
}

struct PhotoAttachmentService {
    private let directoryName = "VictoryFairyPhotos"

    func savePhoto(from item: PhotosPickerItem, maxPixel: CGFloat = 1800, quality: CGFloat = 0.82) async throws -> String {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoAttachmentError.unreadable
        }
        return try saveImageData(data, maxPixel: maxPixel, quality: quality)
    }

    /// 원본 Data에서 목표 크기로 바로 디코딩해 저장한다.
    /// 전체 비트맵(12MP면 약 49MB)을 만들지 않으므로 저장 시점 메모리 스파이크가 줄어든다.
    func saveImageData(_ data: Data, maxPixel: CGFloat = 1800, quality: CGFloat = 0.82) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = Self.downsampledCGImage(from: source, maxPixel: maxPixel) else {
            throw PhotoAttachmentError.unreadable
        }
        // kCGImageSourceCreateThumbnailWithTransform이 EXIF 방향을 이미 적용하므로 .up으로 감싼다.
        let image = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        guard let jpeg = image.jpegData(compressionQuality: quality) else {
            throw PhotoAttachmentError.unreadable
        }
        let ref = UUID().uuidString
        try jpeg.write(to: url(for: ref), options: [.atomic])
        return ref
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

    /// 표시용 이미지. 파일이 5400px여도 목표 픽셀로만 디코딩하므로 원본 크기와 무관하게 메모리가 일정하다.
    func image(for ref: String, target: PhotoDisplayTarget) -> UIImage? {
        image(for: ref, maxPixel: target.maxPixel)
    }

    func image(for ref: String, maxPixel: CGFloat) -> UIImage? {
        guard let url = try? url(for: ref),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = Self.downsampledCGImage(from: source, maxPixel: maxPixel) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }

    func image(for ref: String) -> UIImage? {
        guard let url = try? url(for: ref) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    private static func downsampledCGImage(from source: CGImageSource, maxPixel: CGFloat) -> CGImage? {
        let options: [CFString: Any] = [
            // EXIF 내장 썸네일을 쓰지 않고 원본에서 만들도록 강제한다(없으면 화질이 뭉개진다).
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            // EXIF 방향을 결과 비트맵에 적용한다(없으면 사진이 돌아간 채로 나온다).
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
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
