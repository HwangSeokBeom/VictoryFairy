import PhotosUI
import SwiftUI
import UIKit

struct TicketOCRView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TicketOCRViewModel
    @State private var isShowingCamera = false
    let onApply: (TicketFieldSuggestion) -> Void

    init(currentFavoriteTeamName: String, onApply: @escaping (TicketFieldSuggestion) -> Void) {
        _viewModel = StateObject(wrappedValue: TicketOCRViewModel(currentFavoriteTeamName: currentFavoriteTeamName))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    HStack(spacing: VFSpacing.sm) {
                        PhotosPicker(selection: $viewModel.selectedItem, matching: .images) {
                            pickerLabel("티켓 사진 선택", systemImage: "photo")
                        }
                        .disabled(viewModel.isProcessing)

                        Button {
                            isShowingCamera = true
                        } label: {
                            pickerLabel("촬영하기", systemImage: "camera")
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isProcessing || !UIImagePickerController.isSourceTypeAvailable(.camera))
                        .opacity(UIImagePickerController.isSourceTypeAvailable(.camera) ? 1 : 0.45)
                    }

                    Text(viewModel.message)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    suggestionCard
                    rawTextCard

                    VFPrimaryButton(title: "적용하기", systemImage: "checkmark") {
                        onApply(viewModel.suggestion)
                        dismiss()
                    }
                    .disabled(!viewModel.suggestion.hasAnyField)
                    .opacity(viewModel.suggestion.hasAnyField ? 1 : 0.45)

                    VFSecondaryButton(title: "다시 선택", systemImage: "arrow.clockwise") {
                        viewModel.reset()
                    }

                    VFSecondaryButton(title: "취소", systemImage: "xmark") {
                        dismiss()
                    }
                }
                .padding(VFSpacing.lg)
            }
            .navigationTitle("티켓 사진 인식")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
            .onChange(of: viewModel.selectedItem) {
                Task { await viewModel.processSelectedItem() }
            }
            .sheet(isPresented: $isShowingCamera) {
                TicketCameraPicker { image in
                    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
                    Task { await viewModel.processImageData(data) }
                }
            }
            .vfScreenBackground()
        }
    }

    private func pickerLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(VFColor.scoreboardNavy)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private var suggestionCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("추천 입력값")
                    .font(VFTypography.section)
                    .foregroundStyle(VFColor.primaryText)
                suggestionRow("경기 날짜", viewModel.suggestion.gameDate.map(DateFormatter.vfDisplayDate.string))
                suggestionRow("응원팀", viewModel.suggestion.favoriteTeamName)
                suggestionRow("상대팀", viewModel.suggestion.opponentTeamName)
                suggestionRow("구장", viewModel.suggestion.stadiumName)
                suggestionRow("좌석", viewModel.suggestion.seatText)
            }
        }
    }

    private var rawTextCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                Text("인식된 텍스트")
                    .font(VFTypography.cardTitle)
                    .foregroundStyle(VFColor.primaryText)
                Text(viewModel.suggestion.rawText.isEmpty ? "아직 인식된 내용이 없어요." : viewModel.suggestion.rawText)
                    .font(.footnote)
                    .foregroundStyle(VFColor.secondaryText)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestionRow(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: VFSpacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.secondaryText)
                .frame(width: 72, alignment: .leading)
            Text(value ?? "인식 안 됨")
                .font(.system(.subheadline, design: .rounded).weight(value == nil ? .regular : .semibold))
                .foregroundStyle(value == nil ? VFColor.secondaryText : VFColor.primaryText)
            Spacer()
        }
    }
}

struct TicketCameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onImage: onImage)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let dismiss: DismissAction
        let onImage: (UIImage) -> Void

        init(dismiss: DismissAction, onImage: @escaping (UIImage) -> Void) {
            self.dismiss = dismiss
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
