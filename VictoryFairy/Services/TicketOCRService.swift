import Foundation
import CoreImage
import UIKit
@preconcurrency import Vision

struct TicketOCRRecognitionResult: Hashable {
    let text: String
    let averageConfidence: Double
}

struct TicketOCRService {
    func recognizeText(from imageData: Data) async throws -> TicketOCRRecognitionResult {
        guard let image = UIImage(data: imageData),
              let cgImage = Self.preprocessedCGImage(from: image) else {
            throw TicketOCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let candidates = observations.compactMap { $0.topCandidates(1).first }
                let text = candidates.map(\.string).joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(throwing: TicketOCRError.noText)
                } else {
                    let confidence = candidates.isEmpty
                        ? 0
                        : Double(candidates.map(\.confidence).reduce(0, +) / Float(candidates.count))
                    continuation.resume(returning: TicketOCRRecognitionResult(text: text, averageConfidence: confidence))
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]
            request.usesLanguageCorrection = true
            request.minimumTextHeight = 0.012

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: cgImage).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func preprocessedCGImage(from image: UIImage) -> CGImage? {
        let normalized = normalizedImage(image)
        let targetMaxPixel: CGFloat = 1800
        let scale = min(1, targetMaxPixel / max(normalized.size.width, normalized.size.height))
        let targetSize = CGSize(width: normalized.size.width * scale, height: normalized.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        guard let input = CIImage(image: resized) else {
            return resized.cgImage
        }

        let grayscale = input
            .applyingFilter("CIPhotoEffectMono")
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.28,
                kCIInputBrightnessKey: 0.03,
                kCIInputSaturationKey: 0
            ])
            .applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: 0.45
            ])

        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(grayscale, from: grayscale.extent) ?? resized.cgImage
    }

    private static func normalizedImage(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

enum TicketOCRError: LocalizedError {
    case invalidImage
    case noText

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "사진을 읽지 못했어요. 다른 사진을 선택해 주세요."
        case .noText:
            "티켓 정보를 인식하지 못했어요. 직접 입력해 주세요."
        }
    }
}
