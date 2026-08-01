import SwiftUI

/// 개정 Pencil `08_RecordCreate_Step2`(`Dotbx`, 393×832)의 보이는 레이아웃.
///
/// **지원하는 값만 만든다.** Pencil은 날씨·먹은 것·응원 준비물도 그렸지만 그 셋은
/// 초안에도, 저장 입력에도, API에도, 백엔드에도 자리가 없다. 컨트롤만 그려 두면
/// 사용자가 적은 것이 조용히 사라지므로 화면에 올리지 않는다. 유예 결정은
/// `docs/PencilDesignImplementation.md`에 적혀 있다.
///
/// 노드 근거:
/// - `k9CIB` 2단계 콘텐츠: 세로 배치, gap 20, padding [8,24,28,24]
/// - `EPCx1` 제목 블록 gap 6: `i3FhLB` 21/900 `#14171F`, `o1ibHI` 13 `#8B909E`
/// - `mVmA3` 좌석 필드: `폼 필드`(`w93QEM`) 인스턴스, 라벨 "좌석" 13/600
/// - `mHyAe` 동행 블록 gap 8: 라벨 `D1cLHa` "함께한 사람" 13/600 `#4C5160`
/// - `lYgEL` 동행 칩 gap 8: `hzruP` 혼자 · `iVOhB` 엄마랑(선택됨) · `a9uzI` 친구랑 ·
///   `R1tLF` 직접 입력(플러스 아이콘 + 13/500, `#EAEAE6` r18)
/// - 선택된 칩: `#F2B63C` 바탕 + `#232A3C` 1.2 테두리 + `#FFFDF8` 라벨
/// - `p8jX3S` 하단 액션 gap 12, padding [8,0,0,0]:
///   `KRhcy`(`Pm0pe`) "다음 · 나의 이야기", `fnbNa` "이 단계는 건너뛸게요" 14/500
///
/// 이 단계는 전부 선택 사항이다. 막는 값이 하나도 없다.
struct RecordCreateStep2View: View {
    @Binding var draft: RecordEditorDraft
    let onBack: () -> Void
    let onNext: () -> Void
    let onSkip: () -> Void

    /// 사용자가 "직접 입력"을 고른 상태인가.
    ///
    /// 초안이 비어 있는 동안에는 초안만 봐서는 알 수 없어서 화면이 잠깐 들고 있는다.
    /// 값이 들어오면 그때부터는 초안에서 그대로 유도되므로(`selection`) 두 번째
    /// 진실 원본이 되지 않는다. 저장되지도 않는다.
    @State private var didChooseCustomEntry = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case seat, custom }

    /// Pencil이 적어 둔 빠른 선택지. 화면에 보이는 문구가 그대로 저장 값이 된다.
    /// 숨은 열거형을 따로 두지 않는다 — 저장되는 것은 지금도 문자열 하나다.
    static let quickCompanions = ["혼자", "엄마랑", "친구랑"]

    /// 지금 초안에서 유도한 선택 상태.
    enum CompanionSelection: Equatable {
        case none
        case quick(String)
        case custom
    }

    /// 초안 값 하나에서 선택 상태를 정한다. 뷰 없이 그대로 시험할 수 있다.
    ///
    /// 값이 있으면 값이 전부를 정한다 — 빠른 선택지와 정확히 같으면 그 칩이,
    /// 아니면 직접 입력이 선택된 것이다. 값이 비어 있을 때만 "직접 입력을 눌렀다"는
    /// 화면 의사가 쓰이며, 그 의사는 저장되지 않는다.
    static func companionSelection(for value: String, customEntryChosen: Bool) -> CompanionSelection {
        if value.isEmpty { return customEntryChosen ? .custom : .none }
        return quickCompanions.contains(value) ? .quick(value) : .custom
    }

    var selection: CompanionSelection {
        Self.companionSelection(for: draft.companion, customEntryChosen: didChooseCustomEntry)
    }

    private var isCustomEntryVisible: Bool { selection == .custom }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                VFStepProgress(
                    titles: RecordCreateStep.allCases.map(\.accessibilityTitle),
                    currentIndex: RecordCreateStep.details.position - 1
                )
                .padding(.top, VFSpacing.xs)

                titleBlock
                seatField
                companionBlock
            }
            .padding(.horizontal, VFSpacing.xl)
            .padding(.bottom, VFSpacing.lg)
        }
        // 날씨·먹은 것·응원 준비물을 만들지 않았으므로 이 단계는 Pencil보다 짧다.
        // 액션을 마지막 필드 바로 아래에 두면 그 아래로 화면 절반이 빈 채 남아
        // "잘린 화면"처럼 보인다. 아래에 고정하면 위는 입력, 아래는 진행이라는
        // 흔한 폼 구성이 되어 짧아진 단계가 의도된 것으로 읽힌다. 빈자리를 메우려고
        // 없는 내용을 지어내지 않는다.
        .safeAreaInset(edge: .bottom) {
            bottomActions
                .padding(.horizontal, VFSpacing.xl)
                .padding(.bottom, VFSpacing.md)
                .background(VFColor.appBackground)
        }
        .scrollDismissesKeyboard(.interactively)
        // 좌석과 직접 입력 모두 일반 키보드라 Return이 있지만, 좁은 기기에서 확실히
        // 빠져나갈 길을 함께 둔다. 1단계 숫자 키패드에서 배운 것과 같은 이유다.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") { focusedField = nil }
                    .accessibilityIdentifier("recordCreate.step2.keyboardDone")
            }
        }
        .vfScreenBackground()
        // 아래에 고정한 액션은 스크롤 뷰 밖에 있어서, `.contain`이 없으면 이 루트
        // 식별자가 그 버튼들의 식별자를 덮어쓴다(측정으로 확인).
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordCreate.step2.root")
    }

    // MARK: - 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("그날의 디테일을 더해볼까요?")
                .font(VFTypography.display)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recordCreate.step2.title")
            // 부제는 제목이 아니다. 머리글 특성을 주지 않는다.
            Text("모두 건너뛰어도 괜찮아요")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodyTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("recordCreate.step2.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 좌석

    private var seatField: some View {
        VFFormField(label: "좌석") {
            TextField("어디에서 봤나요?", text: $draft.seat)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .seat)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("좌석")
                .accessibilityIdentifier("recordCreate.field.seat")
        }
        .id(RecordEditorField.seat.rawValue)
    }

    // MARK: - 함께한 사람

    private var companionBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("함께한 사람")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .accessibilityHidden(true)

            companionOptions

            if isCustomEntryVisible {
                VFFormField(label: "직접 입력") {
                    TextField("누구와 함께였나요?", text: $draft.companion)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .custom)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // 명시적으로 하나만 준다. 자리표시자가 라벨로 겹쳐 읽히지 않는다.
                        .accessibilityLabel("함께한 사람 직접 입력")
                        .accessibilityIdentifier("recordCreate.companion.customField")
                }
            }
        }
        .id(RecordEditorField.companion.rawValue)
        // 섹션 전체가 하나의 이해 가능한 묶음으로 읽힌다. `.contain`이 없으면
        // 이 라벨이 안쪽 칩의 식별자를 덮어쓴다(1단계에서 측정으로 확인).
        .accessibilityElement(children: .contain)
        .accessibilityLabel("함께한 사람")
    }

    private var companionOptions: some View {
        // 큰 글자와 좁은 폭에서는 네 개가 한 줄에 들어가지 않는다. 줄여서 감추지 않고
        // 줄을 나눈다.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.xs) { optionButtons }
            VStack(alignment: .leading, spacing: VFSpacing.xs) {
                HStack(spacing: VFSpacing.xs) { quickButtons }
                customEntryButton
            }
            VStack(alignment: .leading, spacing: VFSpacing.xs) { optionButtons }
        }
    }

    @ViewBuilder
    private var optionButtons: some View {
        quickButtons
        customEntryButton
    }

    @ViewBuilder
    private var quickButtons: some View {
        ForEach(Self.quickCompanions, id: \.self) { option in
            companionChip(
                title: option,
                isSelected: selection == .quick(option),
                identifier: "recordCreate.companion.\(Self.identifierSuffix(for: option))"
            ) {
                // 다른 빠른 선택지를 고르면 이전 값(직접 입력 포함)을 대신한다.
                draft.companion = option
                didChooseCustomEntry = false
                focusedField = nil
            }
        }
    }

    private var customEntryButton: some View {
        Button {
            if !isCustomEntryVisible {
                // 빠른 선택지에서 넘어오면 그 값은 사용자가 다시 쓸 값으로 대체된다.
                if case .quick = selection { draft.companion = "" }
                didChooseCustomEntry = true
                focusedField = .custom
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                Text("직접 입력")
                    .font(Font.system(.footnote, design: .default).weight(.medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isCustomEntryVisible ? VFColor.bodyOnDark : VFColor.bodySecondary)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .frame(minHeight: VFControl.minimumTouchTarget)
            .background(isCustomEntryVisible ? VFColor.primaryAction : VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                    .stroke(isCustomEntryVisible ? VFColor.inkOutline : VFColor.hairline, lineWidth: 1.2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("직접 입력")
        .accessibilityAddTraits(isCustomEntryVisible ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("recordCreate.companion.custom")
    }

    /// Pencil `칩`의 선택/비선택 두 상태. 이 화면에서만 쓰므로 여기 둔다.
    private func companionChip(
        title: String,
        isSelected: Bool,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(isSelected ? VFColor.bodyOnDark : VFColor.bodySecondary)
                .lineLimit(1)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .frame(minHeight: VFControl.minimumTouchTarget)
                .background(isSelected ? VFColor.primaryAction : VFColor.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                        .stroke(isSelected ? VFColor.inkOutline : VFColor.hairline, lineWidth: 1.2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }

    /// 화면에 보이는 한국어 문구를 안정적인 ASCII 식별자로 옮긴다.
    /// 식별자는 읽히지 않으므로 내부 이름이 사용자에게 새어 나가지 않는다.
    static func identifierSuffix(for option: String) -> String {
        switch option {
        case "혼자": "alone"
        case "엄마랑": "family"
        case "친구랑": "friend"
        default: "other"
        }
    }

    // MARK: - 하단 액션

    private var bottomActions: some View {
        VStack(spacing: VFSpacing.sm) {
            // 2단계는 전부 선택 사항이라 막지 않는다. 언제나 누를 수 있다.
            VFPrimaryButton(title: "다음 · 나의 이야기") {
                focusedField = nil
                onNext()
            }
            .accessibilityLabel("다음 · 나의 이야기")
            .accessibilityHint("나의 이야기 단계로 넘어갑니다")
            .accessibilityIdentifier("recordCreate.step2.next")

            Button {
                focusedField = nil
                onSkip()
            } label: {
                Text("이 단계는 건너뛸게요")
                    .font(Font.system(.subheadline, design: .default).weight(.medium))
                    .foregroundStyle(VFColor.bodySecondary)
                    .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("이 단계는 건너뛸게요")
            .accessibilityHint("좌석과 함께한 사람은 적지 않아도 괜찮아요. 지금까지 적은 값은 그대로 남습니다.")
            .accessibilityIdentifier("recordCreate.step2.skip")
        }
        .padding(.top, VFSpacing.xs)
    }
}

#Preview("2단계 · 빈 상태") {
    RecordCreateStep2Preview(seat: "", companion: "")
}

#Preview("2단계 · 빠른 선택") {
    RecordCreateStep2Preview(seat: "3루 내야 지정석 K열 24번", companion: "엄마랑")
}

#Preview("2단계 · 직접 입력") {
    RecordCreateStep2Preview(seat: "", companion: "회사 동료들과")
}

#Preview("2단계 · AccessibilityXXXL") {
    RecordCreateStep2Preview(seat: "", companion: "친구랑")
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct RecordCreateStep2Preview: View {
    let seat: String
    let companion: String
    @State private var draft = RecordEditorDraft.make(
        mode: .create,
        defaultMoodTag: RecordCreateFlowView.newRecordMoodTag,
        defaultHighlightTag: RecordCreateFlowView.defaultHighlightTag,
        fallbackDate: Date()
    )

    var body: some View {
        RecordCreateStep2View(draft: $draft, onBack: {}, onNext: {}, onSkip: {})
            .onAppear {
                draft.seat = seat
                draft.companion = companion
            }
    }
}
