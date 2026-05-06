import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class TicketOCRViewModel: ObservableObject {
    @Published var selectedItem: PhotosPickerItem?
    @Published private(set) var suggestion = TicketFieldSuggestion(rawText: "")
    @Published private(set) var isProcessing = false
    @Published var message = "티켓 사진을 선택하면 기기에서 글자를 인식해요."

    private let currentFavoriteTeamName: String
    private let service = TicketOCRService()
    private let parserRepository: TicketParserRepository

    init(currentFavoriteTeamName: String, parserRepository: TicketParserRepository = RemoteTicketParserRepository(apiClient: APIClient())) {
        self.currentFavoriteTeamName = currentFavoriteTeamName
        self.parserRepository = parserRepository
    }

    func processSelectedItem() async {
        guard let selectedItem else { return }
        do {
            guard let data = try await selectedItem.loadTransferable(type: Data.self) else {
                message = "사진을 읽지 못했어요. 다른 사진을 선택해 주세요."
                return
            }
            await processImageData(data)
        } catch {
            suggestion = TicketFieldSuggestion(rawText: "")
            message = error.localizedDescription
        }
    }

    func processImageData(_ data: Data) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            let recognition = try await service.recognizeText(from: data)
            var localSuggestion = TicketTextParser(currentFavoriteTeamName: currentFavoriteTeamName).parse(recognition.text)
            localSuggestion.confidence = recognition.averageConfidence
            if localSuggestion.isLowConfidence {
                localSuggestion.warnings.append("인식이 불확실해요.")
            }
            suggestion = localSuggestion
            do {
                let remoteSuggestion = try await parserRepository.parseOCRText(TicketParseOCRTextRequest(ocrText: recognition.text, locale: "ko-KR"))
                suggestion = localSuggestion.merged(with: remoteSuggestion)
            } catch {
                suggestion = localSuggestion
            }
            message = suggestion.hasAnyField
                ? "OCR 결과는 틀릴 수 있어요. 저장 전 꼭 확인해 주세요."
                : "티켓 정보를 인식하지 못했어요. 직접 입력해 주세요."
        } catch {
            suggestion = TicketFieldSuggestion(rawText: "")
            message = error.localizedDescription
        }
    }

    func reset() {
        selectedItem = nil
        suggestion = TicketFieldSuggestion(rawText: "")
        message = "티켓 사진을 다시 선택해 주세요."
    }
}
