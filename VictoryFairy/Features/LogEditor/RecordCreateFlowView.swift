import SwiftUI

/// 개정 Pencil `08_RecordCreate_Step1~3`의 세 단계 흐름 껍데기.
///
/// **아직 사용자에게 열리지 않았다.** 지금 사용자에게 보이는 편집기는 여전히
/// `LogEditorView`(한 장짜리 스크롤 폼)이고, 일곱 개 제품 진입점은 그대로다.
/// 2·3단계가 없는 상태에서 이 흐름을 제품 경로에 붙이면 사용자를 빈 화면으로
/// 보내게 되므로, 이번 패스에서는 DEBUG 픽스처로만 띄운다.
///
/// 이 껍데기가 지키는 것:
/// - 초안은 `RecordEditorDraft` 하나뿐이다. 두 번째 초안도 DTO도 만들지 않는다.
/// - 현재 단계는 **메모리에만** 있다. SwiftData·서버·UserDefaults 어디에도 넣지 않는다.
/// - 다음으로 넘어가는 것만으로는 아무것도 저장되지 않는다.
/// - 저장은 기존 저장 경계(`AppDataStore.saveAttendanceLog`)만 쓴다.
struct RecordCreateFlowView: View {
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.dismiss) private var dismiss

    /// 이 흐름이 만드는 기록의 시작 날짜. 캘린더처럼 날짜를 정해 주는 진입점을 위한 것.
    let initialDate: Date?
    /// 흐름이 끝났음(취소 또는 저장 완료)을 띄운 쪽에 알린다.
    ///
    /// 제품 경로에서 화면을 닫는 것은 `dismiss()`다. 이 닫힘은 띄운 쪽이 관찰할 수
    /// 없으므로, 검증 호스트가 "끝났다"를 확인할 수 있게 통지만 함께 보낸다.
    var onFinish: (() -> Void)?

    @State private var draft: RecordEditorDraft
    /// 지금 단계. 저장하지 않는다.
    ///
    /// 시작 위치만 UI 테스트 픽스처가 정할 수 있다(Release에서는 언제나 `nil`이라
    /// 첫 단계에서 시작한다). 그 뒤의 이동은 제품 경로 그대로 흐르고, 어디에도
    /// 저장되지 않는다.
    @State private var step: RecordCreateStep =
        VFUITestConfiguration.recordCreateStagedInitialStep ?? .game
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var didFinishSaving = false
    /// 마지막 완성 시도가 1단계 검증에서 막혔는가.
    ///
    /// 막혔을 때만 1단계가 안내를 이미 띄운 채로 열린다. 저장되지 않는 화면 상태다.
    @State private var didFailFinalValidation = false

    init(initialDate: Date? = nil, onFinish: (() -> Void)? = nil) {
        self.initialDate = initialDate
        self.onFinish = onFinish
        _draft = State(initialValue: RecordEditorDraft.make(
            mode: .create(initialDate: initialDate),
            defaultMoodTag: RecordCreateFlowView.defaultMoodTag,
            defaultHighlightTag: RecordCreateFlowView.defaultHighlightTag,
            fallbackDate: Date()
        ))
    }

    /// 지금 편집기가 쓰는 기본 태그와 같은 값. 여기서 새 기본값을 만들지 않는다.
    static let defaultMoodTag = "설렘"
    static let defaultHighlightTag = "직관"

    private var mode: RecordEditorMode { .create(initialDate: initialDate) }

    var body: some View {
        Group {
            switch step {
            case .game:
                RecordCreateStep1View(
                    draft: $draft,
                    mode: mode,
                    showsValidationOnAppear: didFailFinalValidation,
                    teamNames: appData.teams.map(\.name),
                    stadiumNames: KBOSeed.stadiums,
                    isSaving: isSaving,
                    saveMessage: saveMessage,
                    onNext: { advance() },
                    onSaveMinimal: { Task { await saveMinimalRecord() } }
                )
            case .details:
                RecordCreateStep2View(
                    draft: $draft,
                    onBack: { goBack() },
                    onNext: { advance() },
                    // 건너뛰기는 같은 곳으로 가지만, 적어 둔 값을 지우지 않는다.
                    // Pencil이 지우라고 말한 적이 없고, 지우면 놀라운 동작이 된다.
                    onSkip: { advance() }
                )
            case .memory:
                RecordCreateStep3View(
                    draft: $draft,
                    isSaving: isSaving,
                    saveMessage: saveMessage,
                    onBack: { goBack() },
                    onComplete: { Task { await completeRecord() } }
                )
            }
        }
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 시트를 빠져나갈 눈에 보이는 길. 큰 글자에서는 제스처가 통하지 않는다.
            //
            // 1단계에서는 왼쪽이 취소다(그대로 둔다). 2단계부터는 Pencil 내비바가
            // 왼쪽에 뒤로 화살표를 두므로 왼쪽을 뒤로에 내주고 취소를 오른쪽으로
            // 옮긴다. 오른쪽은 Pencil이 `임시저장`을 두었던 자리이지만 그 동작은
            // 구현하지 않는다 — 그 문구는 "이어서 쓸 수 있다"는 약속인데 이어쓰기에
            // 필요한 지속 초안 소유권과 재개 의미가 아직 정해지지 않았다.
            if step == .game {
                ToolbarItem(placement: .cancellationAction) {
                    cancelButton
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("이전") { goBack() }
                        .accessibilityLabel("이전 단계")
                        .accessibilityHint("앞 단계로 돌아갑니다. 적어 둔 값은 그대로 남습니다.")
                        .accessibilityIdentifier("recordCreate.back")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    cancelButton
                }
            }
        }
        .onAppear {
            // 지금 편집기와 같은 규칙: 새로 만들 때만, 아직 비어 있을 때만 응원팀을 채운다.
            if draft.favoriteTeamName.isEmpty {
                draft.favoriteTeamName = appData.team(id: preferences.favoriteTeamID)?.name ?? ""
            }
            // UI 테스트가 요청했을 때만, 그리고 아직 사진이 없을 때만 심는다.
            // Release에서는 언제나 빈 배열이라 이 가지는 아무 일도 하지 않는다.
            if draft.photo.refs.isEmpty {
                let seeded = VFUITestConfiguration.recordCreateStagedPhotoRefs()
                if !seeded.isEmpty { draft.photo = RecordEditorPhotoDraft(originalRefs: [], refs: seeded) }
            }
        }
    }

    private var cancelButton: some View {
        Button("취소") { finish() }
            .accessibilityIdentifier("recordCreate.cancel")
            .accessibilityHint("저장하지 않고 기록 작성을 닫는다")
    }

    /// 흐름을 닫는다. 제품 경로에서는 `dismiss()`가 실제로 화면을 내린다.
    private func finish() {
        dismiss()
        onFinish?()
    }

    /// 다음 단계로. 메모리 위치만 바뀐다 — 저장도, 통신도, 영속화도 없다.
    private func advance() {
        guard let next = step.next else { return }
        step = next
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    /// "여기까지만 저장할게요" — 1단계 값만으로 **완결된 보통 기록** 하나를 만든다.
    ///
    /// 이어서 쓸 수 있는 임시 초안이 아니다. 부분 기록 타입도, 저장된 현재 단계도,
    /// 새로운 상태 값도 만들지 않는다. 2·3단계 값은 비어 있는 그대로 저장된다.
    private func saveMinimalRecord() async {
        guard !isSaving else { return }
        guard RecordEditorValidation.validate(draft, step: .game).isValid else { return }
        await save()
    }

    /// 저장 경계는 하나뿐이다. 최소 저장과 완성 저장이 같은 길을 쓴다.
    private func save() async {
        guard let saveInput = draft.makeSaveInput() else { return }
        isSaving = true
        let didSave = await appData.saveAttendanceLog(
            viewModel: saveInput,
            seat: draft.seat,
            companion: draft.companion,
            shortMemo: draft.shortMemo,
            diary: draft.diary,
            tags: draft.saveTags,
            photoLocalRefs: draft.photo.refs
        )
        isSaving = false
        saveMessage = appData.lastSaveMessage
        // `saveAttendanceLog`는 서버 동기화가 실패하면 `false`를 돌려주지만 기록은
        // 이미 기기에 저장돼 있다(지금 편집기도 그때 그대로 닫는다). 저장이 아예
        // 이뤄지지 않은 경우에만 화면에 남는다 — 초안과 사진은 그대로다.
        guard appData.lastSaveMessage != nil else { return }
        didFinishSaving = didSave
        finish()
    }

    /// "기록 완성하기" — 세 단계에서 모은 값으로 **완결된 보통 기록** 하나를 만든다.
    ///
    /// 1단계 요구 조건만 저장을 막는다. 2·3단계 값은 있으면 함께 실려 가고 없으면
    /// 비어 있는 그대로다. 저장 경계는 최소 저장과 똑같은 한 곳이다.
    private func completeRecord() async {
        guard !isSaving else { return }
        // 막히면 저장하지 않고 1단계로 되돌린다. 2·3단계 값과 사진은 그대로 남는다.
        guard RecordEditorValidation.validate(draft).isValid else {
            didFailFinalValidation = true
            step = .game
            return
        }
        didFailFinalValidation = false
        await save()
    }
}

/// 스테이징 전용 호스트.
///
/// 이 흐름은 제품에서도 언제나 **시트**로 뜬다. 검증도 같은 모양이어야 취소와
/// 저장 뒤 닫힘을 그대로 시험할 수 있으므로, 여기서도 시트로 띄운다.
/// 이 호스트는 `#if DEBUG` 픽스처가 있을 때만 화면에 올라온다 — 사용자에게
/// 열리는 여덟 번째 경로가 아니다.
struct RecordCreateStagedHostView: View {
    let initialDate: Date?
    @State private var didFinish = false

    var body: some View {
        Group {
            if didFinish {
                // 취소했거나 저장이 끝난 뒤의 자리. 흐름을 빠져나왔다는 것을 검증한다.
                VStack(spacing: VFSpacing.sm) {
                    Text("흐름이 닫혔어요")
                        .font(VFTypography.sectionTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .accessibilityIdentifier("recordCreate.host.closed")
                    Text("사용자 경로가 아니다. 사용자에게 보이는 편집기는 그대로다.")
                        .font(VFTypography.supporting)
                        .foregroundStyle(VFColor.bodySecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(VFSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .vfScreenBackground()
            } else {
                NavigationStack {
                    RecordCreateFlowView(initialDate: initialDate) { didFinish = true }
                }
            }
        }
    }
}

#Preview("기록 작성 흐름 · 스테이징") {
    let preferences = UserPreferencesStore.preview(suiteName: "RecordCreateFlowPreview")
    let appData = AppDataStore(preferences: preferences)
    return NavigationStack {
        RecordCreateFlowView()
            .environmentObject(appData)
            .environmentObject(preferences)
    }
}
