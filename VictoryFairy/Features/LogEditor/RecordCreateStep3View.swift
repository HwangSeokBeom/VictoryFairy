import PhotosUI
import SwiftUI

/// 개정 Pencil `08_RecordCreate_Step3`(`z0G0P`, 393×904)의 보이는 레이아웃.
///
/// **지금 저장되는 값만 만든다.** Pencil은 별점(`MwBWq`)과 `0 / 500` 글자 수
/// (`XcDJt`)도 그렸지만 둘 다 초안·저장 입력·API·백엔드 어디에도 자리가 없다.
/// 컨트롤만 그려 두면 사용자가 남긴 것이 조용히 사라지므로 화면에 올리지 않는다.
///
/// 노드 근거:
/// - `wbaGx` 3단계 콘텐츠: 세로 배치, gap 20, padding [8,24,28,24]
/// - `HdGkH` 제목 블록 gap 6: `EiRpT` 21/900, `cgl9U` 13 `#8B909E`
/// - `ru50U` 사진 블록 gap 8: 라벨 `V1zl1e` "사진", `bLV8p` 사진 행 gap 10,
///   `CID6M` 추가 타일 100×100 `#EAEAE6` r12, 사진 타일 100×100 r10,
///   `F0bqq` 권한 안내(자물쇠 + "선택한 사진에만 접근해요 · 설정에서 변경")
/// - `yfyEU` 순간 필드: `폼 필드`(`w93QEM`), 라벨 "가장 기억에 남는 순간"
/// - `vemiV` 기분 블록 gap 8: 라벨 `yDRZI` "오늘의 기분", `evzoT` 칩 gap 8,
///   선택 `#F2B63C` + `#232A3C` 1.2 + `#FFFDF8` 13/700 r18,
///   비선택 `#FFFFFF` + `#E2E3E1` 1.2 + `#4C5160` 13/600 r18
/// - `MwBWq` 별점 블록 — **만들지 않음**
/// - `w2X9uy` 일기 블록 gap 8: `xIrTd` 345×120 흰색 r12, `XcDJt` "0 / 500" — 글자 수는 **만들지 않음**
/// - `lXfnL` 하단 액션: `jC97x`(`Pm0pe`) "기록 완성하기"
///
/// 이 단계는 전부 선택 사항이다. 저장을 막는 것은 1단계 요구 조건뿐이다.
struct RecordCreateStep3View: View {
    @Binding var draft: RecordEditorDraft
    /// 저장이 진행 중인가. 중복 제출을 막는다.
    let isSaving: Bool
    /// 마지막 저장 시도가 남긴 안내. 실패해도 초안과 사진은 그대로 남는다.
    let saveMessage: String?
    /// 보조 기능의 일시적인 화면 상태. 사용자가 쓴 값은 들어 있지 않다.
    @ObservedObject var assistance: RecordCreateAssistanceState
    /// "사진 분석". 지금 편집기와 같은 서비스를 부르는 것은 흐름이 한다.
    let onAnalyzePhotos: () -> Void
    /// "AI 초안". 사전 고지 시트를 여는 것은 흐름이 한다.
    let onGenerateAIDraft: () -> Void
    let onBack: () -> Void
    let onComplete: () -> Void

    /// 피커가 들고 있는 일시적인 값. 초안에 들어오지 않는다.
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var photoMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case moment, diary }

    /// Pencil이 적어 둔 다섯 가지 기분. 화면에 보이는 문구가 그대로 저장 값이 된다.
    static let moods = ["벅차오름", "행복", "뿌듯", "아쉬움", "약오름"]

    /// 초안 값 하나에서 선택 상태를 정한다. 뷰 없이 그대로 시험할 수 있다.
    ///
    /// 적힌 값이 다섯 중 하나면 그 칩이 선택된 것이고, 아니면 아무 칩도 선택되지
    /// 않는다. 모르는 값이라고 지우지 않는다 — 다른 경로(지금 편집기·사진 분석)가
    /// 넣어 둔 값일 수 있다.
    static func moodSelection(for value: String) -> String? {
        moods.contains(value) ? value : nil
    }

    private var selectedMood: String? { Self.moodSelection(for: draft.moodTag) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                VFStepProgress(
                    titles: RecordCreateStep.allCases.map(\.accessibilityTitle),
                    currentIndex: RecordCreateStep.memory.position - 1
                )
                .padding(.top, VFSpacing.xs)

                titleBlock
                photoBlock
                momentField
                moodBlock
                diaryBlock
                if let message = photoMessage { notice(message, identifier: "recordCreate.step3.photoMessage") }
                if let message = assistance.message {
                    notice(message, identifier: "recordCreate.assist.message")
                }
                if let saveMessage { notice(saveMessage, identifier: "recordCreate.step3.saveMessage") }
            }
            .padding(.horizontal, VFSpacing.xl)
            // 아래 고정 액션이 차지하는 만큼 스크롤 여유를 둔다.
            //
            // `safeAreaInset`만으로는 부족했다(실측: iPhone 17 Pro에서 사진이 한 장
            // 있을 때 마지막 요소인 `AI 초안`이 y 762–803, 고정 막대가 713–764 —
            // 버튼이 막대 뒤에 깔린 채 더 스크롤되지 않았다. XCUI는 그 상태도
            // `isHittable`로 보고했다). 본문 길이와 상관없이 마지막 요소를 막대 위로
            // 올릴 수 있도록 액션 높이만큼의 여백을 직접 둔다.
            .padding(.bottom, VFControl.buttonHeight + VFSpacing.xl)
        }
        // 별점과 글자 수를 만들지 않아 이 단계도 Pencil보다 짧다. 2단계와 같은 이유로
        // 마지막 액션을 아래에 고정한다 — 위는 입력, 아래는 완성.
        .safeAreaInset(edge: .bottom) {
            completeAction
                .padding(.horizontal, VFSpacing.xl)
                .padding(.bottom, VFSpacing.md)
                .background(VFColor.appBackground)
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focusedField = nil }
                    .accessibilityIdentifier("recordCreate.step3.keyboardDone")
            }
        }
        .onChange(of: selectedPhotoItems) {
            Task { await importSelectedPhotos() }
        }
        .vfScreenBackground()
        // 아래에 고정한 액션은 스크롤 뷰 밖이라 `.contain`이 없으면 이 식별자가
        // 그 버튼의 식별자를 덮어쓴다(2단계에서 측정으로 확인).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordCreate.step3.root")
    }

    // MARK: - 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("오늘의 이야기를 남겨주세요")
                .font(VFTypography.display)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recordCreate.step3.title")
            Text("사진 한 장과 짧은 한마디면 충분해요")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodyTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("recordCreate.step3.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 사진

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("사진")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .accessibilityHidden(true)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    addPhotoTile
                    ForEach(draft.photo.refs, id: \.self) { ref in
                        photoTile(ref)
                    }
                }
                .padding(.vertical, 2)
            }

            // Pencil `F0bqq`. 사진이 어디까지 쓰이는지 사용자에게 그대로 알린다.
            HStack(spacing: 5) {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .medium))
                Text("선택한 사진에만 접근해요 · 설정에서 변경")
                    .font(VFTypography.metadata)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(VFColor.bodyTertiary)

            // 지금 편집기가 이미 가진 사진 분석. 사진 영역 안에, 부차적으로 둔다.
            assistanceAction(
                title: assistance.isAnalyzingPhotos ? "사진 분석 중" : "사진 분석",
                systemImage: "sparkle.magnifyingglass",
                identifier: "recordCreate.step3.analyzePhotos",
                hint: "고른 사진에서 분위기와 한마디를 찾아 제안해요. 저장은 하지 않아요.",
                isEnabled: !draft.photo.refs.isEmpty && !assistance.isAnalyzingPhotos,
                action: onAnalyzePhotos
            )
        }
        .id(RecordEditorField.photos.rawValue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("사진")
    }

    private var addPhotoTile: some View {
        PhotosPicker(
            selection: $selectedPhotoItems,
            maxSelectionCount: RecordEditorPhotoAttachment.remainingSlots(for: draft.photo),
            matching: .images
        ) {
            VStack(spacing: 6) {
                Image(systemName: "camera")
                    .font(.system(size: 20, weight: .medium))
                Text(isProcessingPhotos ? "사진 처리 중" : "사진 추가")
                    .font(VFTypography.badge)
                    .lineLimit(1)
            }
            .foregroundStyle(VFColor.bodySecondary)
            .frame(width: 100, height: 100)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                    .stroke(VFColor.hairline, lineWidth: 1.5)
            )
        }
        .disabled(isProcessingPhotos || RecordEditorPhotoAttachment.remainingSlots(for: draft.photo) == 0)
        .opacity(RecordEditorPhotoAttachment.remainingSlots(for: draft.photo) == 0 ? 0.55 : 1)
        .accessibilityLabel(isProcessingPhotos ? "사진 처리 중" : "사진 추가")
        .accessibilityIdentifier("recordCreate.step3.addPhoto")
    }

    private func photoTile(_ ref: String) -> some View {
        // 파일 경로는 사용자에게 아무 뜻이 없다. 몇 번째 사진인지로 말한다.
        let position = (draft.photo.refs.firstIndex(of: ref) ?? 0) + 1
        return ZStack(alignment: .topTrailing) {
            AttachmentPhotoView(ref: ref, target: .editorThumbnail)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                .accessibilityLabel("사진 \(position)")
            Button {
                // 지우는 것은 언제나 사용자의 명시적 의도다.
                draft.photo.remove(ref)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, VFColor.deepAccent.opacity(0.85))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("사진 \(position) 삭제")
            .accessibilityIdentifier("recordCreate.step3.removePhoto.\(position)")
        }
    }

    private func importSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty else { return }
        isProcessingPhotos = true
        defer {
            isProcessingPhotos = false
            selectedPhotoItems = []
        }
        let result = await RecordEditorPhotoAttachment.importItems(selectedPhotoItems, into: draft.photo)
        draft.photo = result.photo
        photoMessage = result.outcome.message
    }

    // MARK: - 가장 기억에 남는 순간

    private var momentField: some View {
        VFFormField(label: "가장 기억에 남는 순간") {
            TextField("그날 가장 오래 남은 장면은?", text: $draft.shortMemo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .moment)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("가장 기억에 남는 순간")
                .accessibilityIdentifier("recordCreate.step3.moment")
        }
        .id(RecordEditorField.shortMemo.rawValue)
    }

    // MARK: - 오늘의 기분

    private var moodBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("오늘의 기분")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: VFSpacing.xs) { moodButtons }
                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    HStack(spacing: VFSpacing.xs) { moodButtons }
                }
                VStack(alignment: .leading, spacing: VFSpacing.xs) { moodButtons }
            }
        }
        .id(RecordEditorField.moodTag.rawValue)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("오늘의 기분")
    }

    @ViewBuilder
    private var moodButtons: some View {
        ForEach(Self.moods, id: \.self) { mood in
            let isSelected = selectedMood == mood
            Button {
                // 하나만 선택된다. 다른 것을 고르면 앞의 값(모르는 값 포함)을 대신한다.
                draft.moodTag = mood
                focusedField = nil
            } label: {
                Text(mood)
                    .font(Font.system(.footnote, design: .default).weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? VFColor.bodyOnDark : VFColor.bodySecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(minHeight: VFControl.minimumTouchTarget)
                    .background(isSelected ? VFColor.primaryAction : VFColor.elevatedSurface)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isSelected ? VFColor.inkOutline : VFColor.hairline, lineWidth: 1.2)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(mood)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("recordCreate.step3.mood.\(Self.identifierSuffix(for: mood))")
        }
    }

    /// 화면에 보이는 한국어를 안정적인 ASCII 식별자로 옮긴다. 식별자는 읽히지 않는다.
    static func identifierSuffix(for mood: String) -> String {
        switch mood {
        case "벅차오름": "overwhelmed"
        case "행복": "happy"
        case "뿌듯": "proud"
        case "아쉬움": "regret"
        case "약오름": "annoyed"
        default: "other"
        }
    }

    // MARK: - 짧은 일기

    private var diaryBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("짧은 일기")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .accessibilityHidden(true)

            // 지금 편집기가 이미 가진 AI 초안. 일기 칸 **바로 위**에 한 줄로 둔다.
            //
            // 일기 칸 아래에 두었을 때는 화면 맨 끝이 되어 고정 액션 막대에 깔렸고
            // (실측: 버튼 762–803, 막대 713–764), 라벨과 한 줄에 묶었을 때는 아래
            // `TextEditor`가 그 자리를 덮어 누를 수 없었다(실측: 609–649에 보이는데도
            // `isHittable`이 거짓). 사진 분석과 같은 모양의 독립된 한 줄이 안전하다.
            aiDraftAction

            ZStack(alignment: .topLeading) {
                TextEditor(text: $draft.diary)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .padding(VFSpacing.xs)
                    .background(VFColor.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                            .stroke(VFColor.hairline, lineWidth: 1.5)
                    )
                    .focused($focusedField, equals: .diary)
                    .accessibilityLabel("짧은 일기")
                    .accessibilityIdentifier("recordCreate.step3.diary")
                if draft.diary.isEmpty {
                    Text("그날의 마음을 한두 줄로 남겨보세요")
                        .font(VFTypography.body)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .padding(.horizontal, VFSpacing.sm)
                        .padding(.vertical, VFSpacing.md)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .id(RecordEditorField.diary.rawValue)
    }

    /// 만들어진 글은 시트에서 확인하고 고칠 수 있으며, 저장되지 않는다.
    private var aiDraftAction: some View {
        assistanceAction(
            title: assistance.isGeneratingAIDraft ? "AI 초안 만드는 중" : "AI 초안",
            systemImage: "sparkles",
            identifier: "recordCreate.step3.aiDraft",
            hint: "경기 정보로 일기 초안을 만들어요. 확인하고 고친 뒤에 저장돼요.",
            isEnabled: !assistance.isGeneratingAIDraft,
            action: onGenerateAIDraft
        )
    }

    /// 부차적인 보조 동작 하나. 본문 입력보다 약하게 보이도록 같은 모양을 함께 쓴다.
    private func assistanceAction(
        title: String,
        systemImage: String,
        identifier: String,
        hint: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: VFSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(Font.system(.footnote, design: .default).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(VFColor.bodySecondary)
            .padding(.horizontal, VFSpacing.sm)
            .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget, alignment: .leading)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 안내

    private func notice(_ message: String, identifier: String) -> some View {
        Text(message)
            .font(VFTypography.supporting)
            .foregroundStyle(VFColor.bodySecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(VFSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.primaryActionPale.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .accessibilityIdentifier(identifier)
    }

    // MARK: - 기록 완성하기

    private var completeAction: some View {
        VFPrimaryButton(title: isSaving ? "저장 중" : "기록 완성하기", isEnabled: !isSaving) {
            focusedField = nil
            onComplete()
        }
        .accessibilityLabel(isSaving ? "저장 중" : "기록 완성하기")
        .accessibilityHint("적은 내용으로 직관 기록을 저장해요")
        .accessibilityIdentifier("recordCreate.step3.complete")
    }
}

#Preview("3단계 · 빈 상태") {
    RecordCreateStep3Preview(memo: "", mood: "", diary: "")
}

#Preview("3단계 · 채운 상태") {
    RecordCreateStep3Preview(memo: "9회초 역전 스리런", mood: "벅차오름", diary: "오래 기억할 하루.")
}

#Preview("3단계 · AccessibilityXXXL") {
    RecordCreateStep3Preview(memo: "", mood: "행복", diary: "")
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct RecordCreateStep3Preview: View {
    let memo: String
    let mood: String
    let diary: String
    @State private var draft = RecordEditorDraft.make(
        mode: .create,
        defaultMoodTag: "",
        defaultHighlightTag: "",
        fallbackDate: Date()
    )
    @StateObject private var assistance = RecordCreateAssistanceState()

    var body: some View {
        RecordCreateStep3View(
            draft: $draft,
            isSaving: false,
            saveMessage: nil,
            assistance: assistance,
            onAnalyzePhotos: {},
            onGenerateAIDraft: {},
            onBack: {},
            onComplete: {}
        )
        .onAppear {
            draft.shortMemo = memo
            draft.moodTag = mood
            draft.diary = diary
        }
    }
}
