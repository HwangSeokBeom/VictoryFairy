import SwiftUI

/// 다섯 개 제품 생성 경로가 세 단계 기록 작성 흐름을 여는 **하나뿐인 입구**.
///
/// 경로마다 초안을 따로 만들지 않는다. 여기서 만드는 것은 언제나 정본
/// `RecordEditorDraft` 하나이고, 지어내는 값이 없다 — 상대팀·구장·결과·점수·좌석·
/// 동행·사진·일기 어느 것도 미리 채우지 않는다. 만드는 것만으로는 아무것도 저장되지
/// 않는다.
struct RecordCreateLaunchContext: Equatable {
    /// 어느 화면에서 열렸는가.
    ///
    /// 화면에 보이지 않고 기록에도 저장되지 않는다. 경로별 동작(캘린더가 정해 준
    /// 날짜)과 UI 테스트가 "정말 그 경로에서 열렸는지"를 확인하는 데만 쓴다.
    enum Origin: String, CaseIterable {
        case home
        case feed
        case calendar
        case statisticsStadium
        case statisticsOpponent
    }

    let origin: Origin
    /// 이 경로가 정해 주는 시작 날짜. 정해 주지 않으면 흐름이 오늘을 쓴다.
    let initialDate: Date?

    private init(origin: Origin, initialDate: Date?) {
        self.origin = origin
        self.initialDate = initialDate
    }

    /// 홈의 "오늘의 직관 남기기". 날짜를 정해 주지 않는다.
    static func home() -> Self { Self(origin: .home, initialDate: nil) }
    /// 기록(피드) 탭의 추가 버튼.
    static func feed() -> Self { Self(origin: .feed, initialDate: nil) }
    /// 캘린더에서 고른 날짜로 여는 경로. 그 날짜를 그대로 넘긴다.
    static func calendar(date: Date) -> Self { Self(origin: .calendar, initialDate: date) }
    /// 구장별 통계의 빈 상태. **구장을 지어내지 않는다** — 1단계에서 직접 고른다.
    static func statisticsStadium() -> Self { Self(origin: .statisticsStadium, initialDate: nil) }
    /// 상대팀별 통계의 빈 상태. **상대팀을 지어내지 않는다.**
    static func statisticsOpponent() -> Self { Self(origin: .statisticsOpponent, initialDate: nil) }

    /// 정본 초안을 만드는 하나뿐인 길.
    ///
    /// 응원팀은 여기서 넣지 않는다 — 사용자 설정은 화면이 떠야 읽을 수 있으므로
    /// 흐름이 `onAppear`에서 지금 편집기와 똑같은 규칙으로 채운다.
    func makeDraft(today: Date) -> RecordEditorDraft {
        RecordEditorDraft.make(
            mode: .create(initialDate: initialDate),
            preferredFavoriteTeamName: nil,
            defaultMoodTag: RecordCreateFlowView.newRecordMoodTag,
            defaultHighlightTag: RecordCreateFlowView.defaultHighlightTag,
            fallbackDate: today
        )
    }

    /// UI 테스트와 캡처가 "어느 경로로 들어왔는지"를 화면에서 확인하는 표식.
    var routeIdentifier: String { "recordCreate.origin.\(origin.rawValue)" }
}

/// 개정 Pencil `08_RecordCreate_Step1~3`의 세 단계 기록 작성 흐름.
///
/// 이 흐름은 **다섯 개 제품 생성 경로**(홈·기록·캘린더·구장 통계·상대팀 통계)가
/// 쓴다. 수정하기 두 경로(홈 AI 사전 점검·기록 상세)는 그대로
/// `LogEditorView`(한 장짜리 스크롤 폼)를 쓴다 — 이 흐름에는 수정 모드가 없다.
///
/// 이 흐름이 지키는 것:
/// - 초안은 `RecordEditorDraft` 하나뿐이다. 두 번째 초안도 DTO도 만들지 않는다.
/// - 현재 단계는 **메모리에만** 있다. SwiftData·서버·UserDefaults 어디에도 넣지 않는다.
/// - 다음으로 넘어가는 것만으로는 아무것도 저장되지 않는다.
/// - 보조 기능(티켓 OCR·경기 자동 찾기·사진 분석·AI 초안)도 스스로 저장하지 않는다.
/// - 저장은 기존 저장 경계(`AppDataStore.saveAttendanceLog`)만 쓴다.
struct RecordCreateFlowView: View {
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore
    @Environment(\.dismiss) private var dismiss

    /// 이 흐름을 연 경로. 시작 날짜도 여기서 온다.
    let context: RecordCreateLaunchContext
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
    /// 보조 기능의 일시적인 화면 상태. 사용자가 쓴 값은 하나도 들어 있지 않다.
    @StateObject private var assistance = RecordCreateAssistanceState()

    init(context: RecordCreateLaunchContext, onFinish: (() -> Void)? = nil) {
        self.context = context
        self.onFinish = onFinish
        _draft = State(initialValue: context.makeDraft(today: Date()))
    }

    /// 새 기록의 기분은 **비어 있다.**
    ///
    /// 예전에는 다섯 가지 authored 선택지 어디에도 없는 값이 미리 들어가 있었다.
    /// 화면에는 아무것도 선택되지 않은 것으로 보이는데 저장에는 그 값이 실려 나갔다 —
    /// 사용자가 고르지 않은 사실이 조용히 기록되는 셈이다. 새로 만들 때는 비워 두고,
    /// 사용자가 3단계에서 고르거나 보조 기능이 넣어 줄 때만 값이 생긴다.
    /// 수정하기는 이 값을 쓰지 않는다 — 기존 기록의 기분은 그대로 유지된다.
    static let newRecordMoodTag = ""
    /// 하이라이트 기본 태그. 지금 흐름이 쓰던 값 그대로다.
    static let defaultHighlightTag = "직관"

    private var mode: RecordEditorMode { .create(initialDate: context.initialDate) }

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
                    assistance: assistance,
                    onFindGames: { Task { await lookupKBOGameCandidates() } },
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
                    assistance: assistance,
                    onAnalyzePhotos: { startPhotoAnalysis() },
                    onGenerateAIDraft: { startAIDraft() },
                    onBack: { goBack() },
                    onComplete: { Task { await completeRecord() } }
                )
            }
        }
        .overlay(alignment: .topLeading) { routeMarker }
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
        .recordCreateAssistance(draft: $draft, state: assistance)
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

    /// 어느 경로에서 열렸는지 알려 주는 표식. 읽히는 이름은 없다.
    private var routeMarker: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier(context.routeIdentifier)
            .accessibilityLabel(Text(verbatim: ""))
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

    // MARK: - 보조 기능 (저장하지 않는다)

    private var currentFavoriteTeamID: String? {
        KBOSeed.team(named: draft.favoriteTeamName)?.id
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
    }

    /// "경기 자동 찾기". 지금 편집기가 쓰는 조회 서비스를 그대로 부른다.
    ///
    /// 지금 편집기는 날짜가 바뀔 때마다 스스로 조회하지만, 이 흐름에서는 사용자가
    /// 눌렀을 때만 조회한다. 후보가 없으면 없다고 말할 뿐 경기를 지어내지 않는다.
    private func lookupKBOGameCandidates() async {
        guard let favoriteTeamID = currentFavoriteTeamID else {
            assistance.clearKBOLookup()
            return
        }
        let lookupDate = draft.date
        assistance.kboLookupState = .loading
        assistance.kboCandidates = []
        assistance.kboLookupSource = nil
        assistance.kboLookupSourceLabel = nil
        assistance.kboLookupSourceDisclosure = nil

        do {
            let response = try await appData.fetchKBOGameCandidates(date: lookupDate, favoriteTeamID: favoriteTeamID)
            guard Calendar.current.isDate(lookupDate, inSameDayAs: draft.date) else { return }
            assistance.kboLookupSource = response.source
            assistance.kboLookupSourceLabel = response.sourceLabel
            assistance.kboLookupSourceDisclosure = response.sourceDisclosure
            assistance.kboCandidates = response.items
            assistance.kboLookupState = response.items.isEmpty ? .empty : .loaded
            // 후보가 있으면 지금 편집기와 같은 선택 시트를 띄운다. 고르는 것만으로는
            // 저장되지 않는다.
            assistance.isShowingKBOCandidateSelection = !response.items.isEmpty
        } catch {
            guard Calendar.current.isDate(lookupDate, inSameDayAs: draft.date) else { return }
            assistance.clearKBOLookup()
            assistance.kboLookupState = .failed
        }
    }

    /// "사진 분석". 고른 사진이 있어야 열린다 — 지금 편집기와 같은 조건이다.
    private func startPhotoAnalysis() {
        guard !draft.photo.refs.isEmpty else {
            assistance.message = "분석할 사진을 먼저 골라 주세요."
            return
        }
        assistance.message = nil
        assistance.isShowingPhotoAnalysisSelection = true
    }

    /// "AI 초안". 지금 편집기와 같은 입력 경계를 요구하고, 같은 사전 고지를 먼저 띄운다.
    private func startAIDraft() {
        let result = RecordEditorValidation.validate(draft)
        guard result.isValid else {
            assistance.message = result.blockingMessage
            return
        }
        assistance.message = nil
        assistance.isShowingAIPreflight = true
    }

    // MARK: - 저장

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
/// 세 단계 화면 자체를 좁은 폭·큰 글자·사진 상태까지 결정적으로 시험하기 위한
/// 자리다. `#if DEBUG` 픽스처가 있을 때만 화면에 올라오며 **사용자 경로가 아니다** —
/// 사용자에게 열리는 다섯 개 생성 경로는 각자의 호스트가 시트로 띄운다.
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
                    Text("검증용 호스트예요. 사용자 경로는 각 화면의 시트가 띄웁니다.")
                        .font(VFTypography.supporting)
                        .foregroundStyle(VFColor.bodySecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(VFSpacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .vfScreenBackground()
            } else {
                NavigationStack {
                    // 날짜를 정해 주는 경로와 정해 주지 않는 경로를 같은 입구로 흉내낸다.
                    RecordCreateFlowView(
                        context: initialDate.map { .calendar(date: $0) } ?? .home()
                    ) { didFinish = true }
                }
            }
        }
    }
}

#Preview("기록 작성 흐름 · 홈") {
    let preferences = UserPreferencesStore.preview(suiteName: "RecordCreateFlowPreview")
    let appData = AppDataStore(preferences: preferences)
    return NavigationStack {
        RecordCreateFlowView(context: .home())
            .environmentObject(appData)
            .environmentObject(preferences)
    }
}
