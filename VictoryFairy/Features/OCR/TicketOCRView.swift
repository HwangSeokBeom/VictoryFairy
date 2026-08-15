import PhotosUI
import SwiftUI
import UIKit

struct TicketOCRView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TicketOCRViewModel
    @State private var isShowingCamera = false
    @State private var editedDate = Date()
    @State private var hasEditedDate = false
    @State private var editedFavoriteTeam = ""
    @State private var editedOpponentTeam = ""
    @State private var editedStadium = ""
    @State private var editedSeat = ""
    let onApply: (TicketFieldSuggestion) -> Void

    init(currentFavoriteTeamName: String, onApply: @escaping (TicketFieldSuggestion) -> Void) {
        _viewModel = StateObject(wrappedValue: TicketOCRViewModel(currentFavoriteTeamName: currentFavoriteTeamName))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    VFCard(background: VFColor.subtleSurface) {
                        HStack(alignment: .top, spacing: VFSpacing.sm) {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(VFColor.primaryAction)
                            Text("티켓 이미지는 서버로 전송되지 않아요. 기기에서 글자를 먼저 인식하고, 인식된 텍스트만 분석해요.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VFColor.bodySecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

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
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    confirmationCard

                    VFPrimaryButton(title: "이 정보 적용", systemImage: "checkmark") {
                        onApply(editedSuggestion)
                        dismiss()
                    }
                    .disabled(!viewModel.suggestion.hasAnyField)
                    .opacity(viewModel.suggestion.hasAnyField ? 1 : 0.45)

                    VFSecondaryButton(title: "다시 선택", systemImage: "arrow.clockwise") {
                        viewModel.reset()
                    }

                    VFSecondaryButton(title: "직접 입력", systemImage: "square.and.pencil") {
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
            .onChange(of: viewModel.suggestion) {
                syncEditedFields(with: viewModel.suggestion)
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
            .background(VFColor.deepAccent)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    private var confirmationCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("티켓에서 찾은 정보예요")
                        .font(VFTypography.sectionTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("OCR 결과는 틀릴 수 있어요. 저장 전 꼭 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                }

                if viewModel.suggestion.isLowConfidence {
                    Label("인식이 불확실해요.", systemImage: "exclamationmark.triangle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.primaryAction)
                        .padding(.horizontal, VFSpacing.sm)
                        .frame(minHeight: 30)
                        .background(VFColor.primaryAction.opacity(0.1))
                        .clipShape(Capsule())
                }

                if !viewModel.suggestion.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                        ForEach(viewModel.suggestion.warnings, id: \.self) { warning in
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(VFColor.bodySecondary)
                        }
                    }
                }

                Toggle("날짜 적용", isOn: $hasEditedDate)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .tint(VFColor.primaryAction)
                if hasEditedDate {
                    DatePicker("날짜", selection: $editedDate, displayedComponents: .date)
                        .tint(VFColor.primaryAction)
                } else {
                    Text("날짜는 현재 선택값을 유지해요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                }

                editableTeamRow(title: "응원팀", selection: $editedFavoriteTeam)
                editableTeamRow(title: "상대팀", selection: $editedOpponentTeam)
                editableTextField("구장", text: $editedStadium, placeholder: "현재 구장 유지")
                editableTextField("좌석", text: $editedSeat, placeholder: "좌석 직접 입력")

                if let confidence = viewModel.suggestion.confidence {
                    Text("인식 신뢰도 \(Int((confidence * 100).rounded()))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VFColor.bodySecondary)
                }
            }
        }
    }

    private var editedSuggestion: TicketFieldSuggestion {
        TicketFieldSuggestion(
            gameDate: hasEditedDate ? editedDate : nil,
            favoriteTeamName: editedFavoriteTeam.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            opponentTeamName: editedOpponentTeam.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            stadiumName: editedStadium.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            seatText: editedSeat.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
            confidence: viewModel.suggestion.confidence,
            warnings: viewModel.suggestion.warnings,
            teamCandidates: viewModel.suggestion.teamCandidates,
            rawText: ""
        )
    }

    private func syncEditedFields(with suggestion: TicketFieldSuggestion) {
        if let gameDate = suggestion.gameDate {
            editedDate = gameDate
            hasEditedDate = true
        } else {
            hasEditedDate = false
        }
        editedFavoriteTeam = suggestion.favoriteTeamName ?? ""
        editedOpponentTeam = suggestion.opponentTeamName ?? ""
        editedStadium = suggestion.stadiumName ?? ""
        editedSeat = suggestion.seatText ?? ""
    }

    private func editableTeamRow(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
            Menu {
                Button("비워두기") {
                    selection.wrappedValue = ""
                }
                ForEach(teamOptions, id: \.self) { team in
                    Button(team) {
                        selection.wrappedValue = team
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue.isEmpty ? "직접 입력 유지" : selection.wrappedValue)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(selection.wrappedValue.isEmpty ? VFColor.bodySecondary : VFColor.bodyPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(VFColor.bodySecondary)
                }
                .padding(VFSpacing.sm)
                .frame(minHeight: 44)
                .background(VFColor.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
            }
        }
    }

    private var teamOptions: [String] {
        let detected = viewModel.suggestion.teamCandidates
        let allTeams = KBOSeed.teams.map(\.name)
        return Array(NSOrderedSet(array: detected + allTeams)) as? [String] ?? allTeams
    }

    private func editableTextField(_ title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
            TextField(placeholder, text: text, prompt: Text(placeholder).foregroundStyle(VFColor.bodySecondary))
                .textFieldStyle(.plain)
                .foregroundStyle(VFColor.bodyPrimary)
                .tint(VFColor.primaryAction)
                .padding(VFSpacing.sm)
                .frame(minHeight: 44)
                .background(VFColor.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        }
    }

    private var legacySuggestionCard: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("추천 입력값")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)
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
                    .foregroundStyle(VFColor.bodyPrimary)
                Text(viewModel.suggestion.rawText.isEmpty ? "아직 인식된 내용이 없어요." : viewModel.suggestion.rawText)
                    .font(.footnote)
                    .foregroundStyle(VFColor.bodySecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestionRow(_ title: String, _ value: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: VFSpacing.sm) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .frame(width: 72, alignment: .leading)
            Text(value ?? "인식 안 됨")
                .font(.system(.subheadline, design: .rounded).weight(value == nil ? .regular : .semibold))
                .foregroundStyle(value == nil ? VFColor.bodySecondary : VFColor.bodyPrimary)
            Spacer()
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
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
