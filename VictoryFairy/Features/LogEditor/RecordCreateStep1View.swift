import SwiftUI

/// 개정 Pencil `08_RecordCreate_Step1`(`m34WD`, 393×822)의 보이는 레이아웃.
///
/// 이 화면은 **값을 그리고 고칠 뿐** 저장하지 않는다. 초안은 `RecordEditorDraft`
/// 하나뿐이고 여기서 두 번째 초안이나 DTO를 만들지 않는다. 검증은
/// `RecordEditorValidation`을 그대로 부른다.
///
/// 노드 근거:
/// - `x1EKzM` 1단계 콘텐츠: 세로 배치, gap 20, padding [8,24,28,24]
/// - `XVC6U` 제목 블록: `fiZM1` 21/900 `#14171F`, `soGHC` 13 `#8B909E`
/// - `c3ryI`·`eCkfl`·`lRsMF`·`uRoQk`: 모두 `폼 필드`(`w93QEM`) 인스턴스
/// - `mv6wU` 스코어 블록: 라벨 13/600, 점수 상자 두 개(흰 바탕 r12), 콜론, 결과 행
/// - `aI1CQ` 결과 행: `스탬프/승`(`aYRjf`) + 결과 안내 13/700 `#D99A26`
/// - `D2i66X` 하단 액션: `버튼/프라이머리`(`Pm0pe`) + `uBGhH` 14/500 `#4C5160`
///
/// 의도적 차이 — Pencil은 결과를 **고르는** 컨트롤을 그리지 않고 고른 뒤의 스탬프만
/// 그렸다. 저장은 명시적으로 고른 결과를 요구하므로(`RecordEditorValidation`),
/// 스코어 아래에 지금 편집기가 쓰던 결과 선택 컨트롤을 둔다. 고르고 나면 Pencil이
/// 그린 스탬프 + 안내 행이 그대로 나온다.
struct RecordCreateStep1View: View {
    @Binding var draft: RecordEditorDraft
    /// 새로 만들기인지 수정인지. 지금 이 화면은 새로 만들기에만 쓰인다.
    let mode: RecordEditorMode
    /// 선택 가능한 팀 이름. 저장소가 들고 있는 실제 목록을 받는다.
    let teamNames: [String]
    /// 선택 가능한 구장 이름.
    let stadiumNames: [String]
    /// 저장이 진행 중인가. 중복 저장을 막는 데 쓴다.
    let isSaving: Bool
    /// 마지막 저장 시도가 남긴 안내. 실패해도 초안은 그대로 남는다.
    let saveMessage: String?
    let onNext: () -> Void
    let onSaveMinimal: () -> Void

    /// 사용자가 진행을 시도한 횟수. 시도 전에는 안내를 띄우지 않고, 시도할 때마다
    /// 다시 첫 번째로 막힌 값으로 데려간다.
    @State private var proceedAttempts = 0
    @FocusState private var focusedScore: ScoreSide?

    private enum ScoreSide: Hashable { case ours, theirs }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    VFStepProgress(
                        titles: RecordCreateStep.allCases.map(\.accessibilityTitle),
                        currentIndex: RecordCreateStep.game.position - 1
                    )
                    .padding(.top, VFSpacing.xs)

                    titleBlock
                    dateField
                    stadiumField
                    teamRow
                    scoreBlock
                    if let message = validationMessage { validationBanner(message) }
                    if let saveMessage { saveNotice(saveMessage) }
                    bottomActions
                }
                .padding(.horizontal, VFSpacing.xl)
                .padding(.bottom, VFSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            // 숫자 키패드에는 Return이 없다. 좁은 기기(SE 3)에서는 키패드가 화면의
            // 절반을 덮어 아래쪽 액션에 닿을 수 없으므로, 빠져나갈 길을 함께 준다.
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { focusedScore = nil }
                        .accessibilityIdentifier("recordCreate.score.done")
                }
            }
            .onChange(of: proceedAttempts) {
                guard proceedAttempts > 0, let field = validation.firstInvalidField else { return }
                withAnimation { proxy.scrollTo(field.rawValue, anchor: .center) }
            }
        }
        .vfScreenBackground()
        .accessibilityIdentifier("recordCreate.step1.root")
    }

    // MARK: - 검증

    /// 1단계에 속한 값만 본다. 2·3단계 값은 여기서 막지 않는다.
    private var validation: RecordEditorValidationResult {
        RecordEditorValidation.validate(draft, step: .game)
    }

    private var didAttemptToProceed: Bool { proceedAttempts > 0 }

    /// 저장하거나 다음으로 넘어가도 되는가.
    private var isReadyToProceed: Bool { validation.isValid && !isSaving }

    private var validationMessage: String? {
        guard didAttemptToProceed else { return nil }
        return validation.blockingMessage
    }

    private var showsScoreWarning: Bool {
        validation.warnings.contains(.scoreDisagreesWithResult)
    }

    private func errorMessage(for field: RecordEditorField) -> String? {
        guard didAttemptToProceed, validation.firstInvalidField == field else { return nil }
        return validation.blockingMessage
    }

    // MARK: - 제목

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("어떤 경기였나요?")
                .font(VFTypography.display)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recordCreate.step1.title")
            Text("필수만 적어도 충분해요")
                .font(VFTypography.supporting)
                .foregroundStyle(VFColor.bodyTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("recordCreate.step1.subtitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 경기 날짜

    private var dateField: some View {
        VFFormField(label: "경기 날짜") {
            // 라벨은 `DatePicker`가 스스로 갖는다. 여기서 한 번 더 붙이면
            // VoiceOver가 "경기 날짜, 경기 날짜"로 두 번 읽는다(실측).
            DatePicker("경기 날짜", selection: $draft.date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("recordCreate.field.date")
        }
        .id(RecordEditorField.date.rawValue)
    }

    // MARK: - 구장

    private var stadiumField: some View {
        VFFormField(label: "구장", errorMessage: errorMessage(for: .stadium)) {
            selectionMenu(
                placeholder: "구장을 선택해 주세요",
                value: draft.stadiumName,
                options: stadiumNames,
                accessibilityLabel: "구장",
                identifier: "recordCreate.field.stadium"
            ) { draft.stadiumName = $0 }
        }
        .id(RecordEditorField.stadium.rawValue)
    }

    // MARK: - 우리 팀 · 상대 팀

    private var teamRow: some View {
        // 큰 글자에서는 두 칸이 나란히 서면 이름이 잘린다. 그때만 세로로 쌓는다.
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                favoriteTeamField
                opponentTeamField
            }
            VStack(alignment: .leading, spacing: VFSpacing.sm) {
                favoriteTeamField
                opponentTeamField
            }
        }
    }

    private var favoriteTeamField: some View {
        VFFormField(label: "우리 팀", errorMessage: errorMessage(for: .favoriteTeam)) {
            selectionMenu(
                placeholder: "응원팀 선택",
                value: draft.favoriteTeamName,
                options: teamNames,
                accessibilityLabel: "우리 팀",
                identifier: "recordCreate.field.favoriteTeam"
            ) { draft.favoriteTeamName = $0 }
        }
        .id(RecordEditorField.favoriteTeam.rawValue)
    }

    private var opponentTeamField: some View {
        VFFormField(label: "상대 팀", errorMessage: errorMessage(for: .opponentTeam)) {
            selectionMenu(
                placeholder: "상대팀 선택",
                value: draft.opponentTeamName,
                options: opponentOptions,
                accessibilityLabel: "상대 팀",
                identifier: "recordCreate.field.opponentTeam"
            ) { draft.opponentTeamName = $0 }
        }
        .id(RecordEditorField.opponentTeam.rawValue)
    }

    /// 같은 팀끼리 맞붙게 두지 않는다. 지금 편집기가 쓰던 규칙 그대로다.
    private var opponentOptions: [String] {
        teamNames.filter { $0 != draft.favoriteTeamName }
    }

    /// Pencil `폼 필드`의 값 + 오른쪽 아이콘 형태. 값이 없으면 안내 문구를 보여준다.
    private func selectionMenu(
        placeholder: String,
        value: String,
        options: [String],
        accessibilityLabel: String,
        identifier: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { onSelect(option) }
            }
        } label: {
            HStack(spacing: VFSpacing.xs) {
                Text(value.isEmpty ? placeholder : value)
                    .font(VFTypography.body)
                    .foregroundStyle(value.isEmpty ? VFColor.bodyTertiary : VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(value.isEmpty ? "선택하지 않음" : value)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - 스코어 · 결과

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            Text("스코어")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodySecondary)
                .accessibilityAddTraits(.isHeader)

            // 취소된 경기에는 점수가 없다. 지금 저장 경로도 점수를 버린다.
            if draft.result != .canceled {
                scoreRow
            }

            resultChooser

            if let result = draft.result {
                resultFeedbackRow(result)
            }

            if showsScoreWarning {
                Text("점수와 결과가 서로 달라 보여요. 한 번만 확인해 주세요.")
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(VFSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VFColor.primaryActionPale.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                    .accessibilityIdentifier("recordCreate.scoreWarning")
            }
        }
        .id(RecordEditorField.result.rawValue)
    }

    private var scoreRow: some View {
        // 큰 글자에서는 두 상자와 콜론이 한 줄에 다 들어가지 않는다.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: VFSpacing.sm) {
                scoreField(side: .ours)
                Text(":")
                    .font(VFTypography.numericEmphasis)
                    .foregroundStyle(VFColor.bodyTertiary)
                    .accessibilityHidden(true)
                scoreField(side: .theirs)
            }
            VStack(spacing: VFSpacing.xs) {
                scoreField(side: .ours)
                scoreField(side: .theirs)
            }
        }
    }

    /// Pencil `우리 점수`·`상대 점수` 상자. 비어 있으면 `nil`로 남는다 — 0으로 채우지 않는다.
    private func scoreField(side: ScoreSide) -> some View {
        let isOurs = side == .ours
        let label = isOurs ? "우리 팀 점수" : "상대 팀 점수"
        let isFocused = focusedScore == side
        return VStack(spacing: VFSpacing.xxs) {
            TextField("–", text: scoreText(for: side))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(VFTypography.numericEmphasis)
                .foregroundStyle(VFColor.bodyPrimary)
                .focused($focusedScore, equals: side)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(label)
                .accessibilityIdentifier(isOurs ? "recordCreate.score.our" : "recordCreate.score.opponent")
        }
        .padding(.vertical, VFSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: VFControl.buttonHeight)
        .background(VFColor.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.field, style: .continuous)
                .stroke(isFocused ? VFColor.primaryAction : VFColor.hairline, lineWidth: isFocused ? 1.8 : 1.5)
        )
    }

    /// 빈 문자열은 `nil`이다. 숫자가 아닌 입력은 받지 않는다.
    private func scoreText(for side: ScoreSide) -> Binding<String> {
        Binding(
            get: {
                let value = side == .ours ? draft.ourScore : draft.opponentScore
                return value.map(String.init) ?? ""
            },
            set: { newValue in
                let digits = newValue.filter(\.isNumber).prefix(2)
                let parsed = digits.isEmpty ? nil : Int(digits)
                if side == .ours { draft.ourScore = parsed } else { draft.opponentScore = parsed }
            }
        )
    }

    /// 결과 선택. Pencil에는 없는 컨트롤이지만 저장이 명시적 결과를 요구한다.
    private var resultChooser: some View {
        HStack(spacing: VFSpacing.xs) {
            ForEach(GameResult.allCases) { result in
                Button {
                    draft.result = result
                    if result == .canceled {
                        // 취소된 경기는 점수를 남기지 않는다. 저장 경로와 같은 규칙이다.
                        draft.ourScore = nil
                        draft.opponentScore = nil
                        // 사라질 칸에 포커스를 남기면 키보드가 뜬 채로 남는다.
                        focusedScore = nil
                    }
                } label: {
                    Text(result.title)
                        .font(VFTypography.cardTitle)
                        .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget)
                        .foregroundStyle(draft.result == result ? VFColor.bodyOnDark : result.color)
                        .background(draft.result == result ? result.color : result.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(result.selectionLabel)
                .accessibilityAddTraits(draft.result == result ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("recordCreate.result.\(result.rawValue)")
            }
        }
    }

    /// Pencil `결과 행`. 스탬프와 한 문장이 함께 나온다.
    private func resultFeedbackRow(_ result: GameResult) -> some View {
        HStack(spacing: VFSpacing.xs) {
            VFResultStamp(result: result)
            Text(result.step1Feedback)
                .font(Font.system(.footnote, design: .default).weight(.bold))
                .foregroundStyle(VFColor.primaryActionDeep)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, VFSpacing.xxs)
        // 스탬프가 결과를 다시 읽어 중복되지 않도록 한 문장으로 합친다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(result.step1Feedback)
        .accessibilityIdentifier("recordCreate.result.feedback")
    }

    // MARK: - 안내

    private func validationBanner(_ message: String) -> some View {
        Text(message)
            .font(VFTypography.supporting)
            .foregroundStyle(VFColor.primaryActionDeep)
            .fixedSize(horizontal: false, vertical: true)
            .padding(VFSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.primaryActionPale.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
            .accessibilityIdentifier("recordCreate.validationMessage")
    }

    private func saveNotice(_ message: String) -> some View {
        Text(message)
            .font(VFTypography.supporting)
            .foregroundStyle(VFColor.bodySecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("recordCreate.saveMessage")
    }

    // MARK: - 하단 액션

    private var bottomActions: some View {
        VStack(spacing: VFSpacing.sm) {
            // 막혀 있을 때도 눌러 볼 수 있어야 무엇이 빠졌는지 알 수 있다.
            // 비활성 버튼은 이유를 말해 주지 못하므로, 아직 준비되지 않았을 때는
            // 같은 자리에 안내를 여는 버튼을 겹쳐 둔다. 접근성 요소는 언제나 하나다.
            ZStack {
                VFPrimaryButton(title: "다음 · 그날의 디테일", isEnabled: isReadyToProceed) {
                    proceedAttempts += 1
                    guard isReadyToProceed else { return }
                    onNext()
                }
                .accessibilityHidden(!isReadyToProceed)

                if !isReadyToProceed {
                    Button {
                        proceedAttempts += 1
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("다음 · 그날의 디테일")
                    .accessibilityValue("아직 채우지 않은 값이 있어요")
                }
            }
            .accessibilityIdentifier("recordCreate.next")

            Button {
                proceedAttempts += 1
                guard isReadyToProceed else { return }
                onSaveMinimal()
            } label: {
                Text("여기까지만 저장할게요")
                    .font(Font.system(.subheadline, design: .default).weight(.medium))
                    .foregroundStyle(VFColor.bodySecondary)
                    .frame(maxWidth: .infinity, minHeight: VFControl.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("여기까지만 저장할게요")
            .accessibilityHint("지금 적은 경기 정보만으로 기록을 저장해요. 그날의 디테일과 나의 이야기는 비워 둡니다.")
            .accessibilityValue(isReadyToProceed ? "" : "아직 채우지 않은 값이 있어요")
            .accessibilityIdentifier("recordCreate.saveMinimal")
        }
        .padding(.top, VFSpacing.xs)
    }
}

// MARK: - 결과가 건네는 한마디

extension GameResult {
    /// Pencil `결과 안내`(`hfTNn`)가 승리에 대해 적어 둔 문구와, 같은 목소리로 이은 나머지.
    ///
    /// 이 문구는 초안에 저장하지 않는다. 결과에서 그때그때 만들어 낸다.
    var step1Feedback: String {
        switch self {
        case .win: "오늘은 승리요정이네요!"
        case .loss: "아쉬운 날도 그대로 기록이 돼요."
        case .draw: "비긴 날도 함께한 하루예요."
        case .canceled: "경기는 취소됐지만 그날은 남아요."
        }
    }

    /// 결과 선택 버튼이 읽히는 이름. `승`·`패` 한 글자만으로는 뜻이 전해지지 않는다.
    var selectionLabel: String {
        switch self {
        case .win: "승리"
        case .loss: "패배"
        case .draw: "무승부"
        case .canceled: "경기 취소"
        }
    }
}

#Preview("1단계 · 빈 상태") {
    RecordCreateStep1Preview(result: nil, fillsTeams: false)
}

#Preview("1단계 · 승리") {
    RecordCreateStep1Preview(result: .win, fillsTeams: true)
}

#Preview("1단계 · AccessibilityXXXL") {
    RecordCreateStep1Preview(result: .win, fillsTeams: true)
        .environment(\.dynamicTypeSize, .accessibility5)
}

private struct RecordCreateStep1Preview: View {
    let result: GameResult?
    let fillsTeams: Bool
    @State private var draft = RecordEditorDraft.make(
        mode: .create,
        defaultMoodTag: "설렘",
        defaultHighlightTag: "직관",
        fallbackDate: Date()
    )

    var body: some View {
        RecordCreateStep1View(
            draft: $draft,
            mode: .create,
            teamNames: KBOSeed.teams.map(\.name),
            stadiumNames: KBOSeed.stadiums,
            isSaving: false,
            saveMessage: nil,
            onNext: {},
            onSaveMinimal: {}
        )
        .onAppear {
            draft.result = result
            if fillsTeams {
                draft.favoriteTeamName = KBOSeed.teams[0].name
                draft.opponentTeamName = KBOSeed.teams[1].name
                draft.stadiumName = KBOSeed.stadiums[0]
                draft.ourScore = 5
                draft.opponentScore = 3
            }
        }
    }
}
