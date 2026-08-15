import SwiftUI

/// 세 단계 작성 흐름이 쓰는 **보조 기능 화면 상태**.
///
/// 여기에는 사용자가 쓴 기록 값이 하나도 없다. 정본 초안은 여전히
/// `RecordEditorDraft` 하나뿐이고, 이 타입은 시트가 떠 있는지·불러오는 중인지처럼
/// 저장되지 않는 일시적인 것만 들고 있다.
@MainActor
final class RecordCreateAssistanceState: ObservableObject {
    // 티켓 OCR
    @Published var isShowingTicketOCR = false

    // 경기 자동 찾기
    @Published var kboLookupState: KBOGameLookupState = .idle
    @Published var kboCandidates: [KBOGameCandidateDTO] = []
    @Published var kboLookupSource: String?
    @Published var kboLookupSourceLabel: String?
    @Published var kboLookupSourceDisclosure: String?
    @Published var isShowingKBOCandidateSelection = false
    @Published var pendingDiaryOverwriteCandidate: KBOGameCandidateDTO?
    @Published var isShowingDiaryOverwriteConfirmation = false

    // 사진 분석
    @Published var isShowingPhotoAnalysisSelection = false
    @Published var isAnalyzingPhotos = false
    @Published var photoAnalysis: PhotoAnalysisDTO?
    @Published var isShowingPhotoAnalysisResult = false

    // AI 초안
    @Published var isShowingAIPreflight = false
    @Published var isGeneratingAIDraft = false
    @Published var aiDraft: DiaryDraftDTO?
    @Published var isShowingAIDraft = false
    @Published var pendingDraftTextToApply: String?
    @Published var isShowingAIDraftApplyChoice = false

    /// 마지막 보조 동작이 남긴 안내. 실패해도 초안은 그대로다.
    @Published var message: String?

    /// AI 초안 말투. 지금 편집기가 쓰던 기본값 그대로다.
    @Published var tone = RecordEditorAssistance.tones[0]

    /// 경기 후보를 지우고 처음 상태로 돌린다. 초안은 건드리지 않는다.
    func clearKBOLookup() {
        kboLookupState = .idle
        kboCandidates = []
        kboLookupSource = nil
        kboLookupSourceLabel = nil
        kboLookupSourceDisclosure = nil
    }
}

/// 보조 기능의 시트·얼럿·비동기 작업을 한 곳에 모은 이음새.
///
/// 세 단계 흐름의 어느 단계에서 눌렀든 같은 서비스와 같은 매핑
/// (`RecordEditorAssistance`)을 쓴다. **어떤 보조 동작도 스스로 저장하지 않는다** —
/// 저장은 1단계의 최소 저장과 3단계의 완성 버튼뿐이다.
struct RecordCreateAssistanceModifier: ViewModifier {
    @Binding var draft: RecordEditorDraft
    @ObservedObject var state: RecordCreateAssistanceState
    @EnvironmentObject private var appData: AppDataStore
    @EnvironmentObject private var preferences: UserPreferencesStore

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $state.isShowingTicketOCR) {
                TicketOCRView(currentFavoriteTeamName: draft.favoriteTeamName) { suggestion in
                    // 매핑은 지금 편집기와 같은 한 곳이다. 저장하지 않는다.
                    state.message = RecordEditorAssistance.applyTicketSuggestion(suggestion, to: &draft)
                }
            }
            .sheet(isPresented: $state.isShowingKBOCandidateSelection) {
                KBOGameCandidateSelectionSheet(
                    candidates: state.kboCandidates,
                    favoriteTeamID: currentFavoriteTeamID,
                    onApply: { candidate in
                        requestKBOGameCandidateApply(candidate)
                        state.isShowingKBOCandidateSelection = false
                    },
                    onOpenOfficialLink: { _ in },
                    onManualInput: {
                        state.clearKBOLookup()
                        state.isShowingKBOCandidateSelection = false
                    }
                )
            }
            .sheet(isPresented: $state.isShowingPhotoAnalysisSelection) {
                PhotoAnalysisSelectionSheet(
                    photoLocalRefs: draft.photo.refs,
                    isAnalyzing: state.isAnalyzingPhotos
                ) { refs in
                    Task { await analyzePhotos(refs) }
                }
            }
            .sheet(isPresented: $state.isShowingPhotoAnalysisResult) {
                if let analysis = state.photoAnalysis {
                    PhotoAnalysisResultSheet(analysis: analysis) {
                        RecordEditorAssistance.applyPhotoAnalysis(analysis, to: &draft)
                        state.isShowingPhotoAnalysisResult = false
                    }
                }
            }
            .sheet(isPresented: $state.isShowingAIPreflight) {
                AIPreflightDisclosureSheet {
                    state.isShowingAIPreflight = false
                    Task { await generateAIDraft() }
                }
            }
            .sheet(isPresented: $state.isShowingAIDraft) {
                if let aiDraft = state.aiDraft {
                    AIDiaryDraftSheet(draft: aiDraft) {
                        requestApplyDraft(aiDraft.draftText)
                    } onRegenerate: {
                        state.isShowingAIDraft = false
                        Task { await generateAIDraft() }
                    } onUseTemplate: {
                        state.isShowingAIDraft = false
                        Task { await generateTemplateDraft() }
                    }
                }
            }
            .alert("작성 중인 다이어리가 있어요. 경기 정보로 덮어쓸까요?",
                   isPresented: $state.isShowingDiaryOverwriteConfirmation) {
                Button("덮어쓰기", role: .destructive) {
                    guard let candidate = state.pendingDiaryOverwriteCandidate else { return }
                    applyKBOGameCandidate(candidate, shouldOverwriteDiary: true)
                    state.pendingDiaryOverwriteCandidate = nil
                }
                Button("유지하기", role: .cancel) {
                    guard let candidate = state.pendingDiaryOverwriteCandidate else { return }
                    applyKBOGameCandidate(candidate, shouldOverwriteDiary: false)
                    state.pendingDiaryOverwriteCandidate = nil
                }
            }
            .alert("기존 다이어리를 AI 초안으로 바꿀까요?", isPresented: $state.isShowingAIDraftApplyChoice) {
                Button("바꾸기", role: .destructive) {
                    guard let text = state.pendingDraftTextToApply else { return }
                    draft.diary = text
                    state.pendingDraftTextToApply = nil
                    state.isShowingAIDraft = false
                }
                Button("이어 붙이기") {
                    guard let text = state.pendingDraftTextToApply else { return }
                    draft.diary = RecordEditorAssistance.appendingDiary(text, to: draft.diary)
                    state.pendingDraftTextToApply = nil
                    state.isShowingAIDraft = false
                }
                Button("취소", role: .cancel) {
                    state.pendingDraftTextToApply = nil
                }
            }
    }

    // MARK: - 경기 자동 찾기

    private var currentFavoriteTeamID: String? {
        KBOSeed.team(named: draft.favoriteTeamName)?.id
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
    }

    private func requestKBOGameCandidateApply(_ candidate: KBOGameCandidateDTO) {
        if RecordEditorAssistance.requiresDiaryOverwriteConfirmation(
            for: candidate, draft: draft, favoriteTeamID: currentFavoriteTeamID
        ) {
            state.pendingDiaryOverwriteCandidate = candidate
            state.isShowingDiaryOverwriteConfirmation = true
            return
        }
        applyKBOGameCandidate(candidate, shouldOverwriteDiary: false)
    }

    private func applyKBOGameCandidate(_ candidate: KBOGameCandidateDTO, shouldOverwriteDiary: Bool) {
        guard let favoriteTeamID = currentFavoriteTeamID else { return }
        state.message = RecordEditorAssistance.applyKBOGameCandidate(
            candidate,
            to: &draft,
            favoriteTeamID: favoriteTeamID,
            lookupSource: state.kboLookupSource,
            shouldOverwriteDiary: shouldOverwriteDiary
        )
        state.clearKBOLookup()
    }

    // MARK: - 사진 분석

    private func analyzePhotos(_ refs: [String]) async {
        guard !refs.isEmpty else { return }
        state.isAnalyzingPhotos = true
        defer { state.isAnalyzingPhotos = false }
        do {
            state.photoAnalysis = try await appData.analyzePhotos(localRefs: refs)
            state.isShowingPhotoAnalysisSelection = false
            state.isShowingPhotoAnalysisResult = true
            state.message = nil
        } catch {
            // 실패해도 사진과 초안은 그대로 남는다.
            state.message = "사진 분석 기능은 아직 사용할 수 없어요."
        }
    }

    // MARK: - AI 초안

    private func generateAIDraft() async {
        guard !state.isGeneratingAIDraft else { return }
        state.isGeneratingAIDraft = true
        defer { state.isGeneratingAIDraft = false }
        do {
            state.aiDraft = try await appData.createDiaryDraft(
                request: RecordEditorAssistance.makeDiaryDraftRequest(from: draft, tone: state.tone)
            )
            state.message = nil
            state.isShowingAIDraft = true
        } catch APIError.server(let code, _) where code == "AI_FEATURE_DISABLED" {
            state.message = "AI 기능이 아직 비활성화되어 있어요. 기본 문장으로 시작해볼까요?"
            await generateTemplateDraft()
        } catch APIError.server(let code, _) where code == "AI_CONFIG_MISSING" {
            state.message = "AI 설정을 확인해야 해요. 기본 문장으로 시작해볼까요?"
            await generateTemplateDraft()
        } catch APIError.server(let code, _) where code == "AI_DAILY_LIMIT_EXCEEDED" {
            state.message = "오늘 사용할 수 있는 AI 초안 횟수를 모두 사용했어요."
            await generateTemplateDraft()
        } catch {
            state.message = "AI 초안을 만들지 못했어요. 기본 문장으로 채워볼게요."
            await generateTemplateDraft()
        }
    }

    private func generateTemplateDraft() async {
        do {
            state.aiDraft = try await appData.createTemplateDraft(
                request: RecordEditorAssistance.makeTemplateDraftRequest(from: draft, tone: state.tone)
            ).diaryDraft
            state.isShowingAIDraft = true
        } catch {
            state.aiDraft = RecordEditorAssistance.localTemplateDraft(from: draft, tone: state.tone)
            state.isShowingAIDraft = true
        }
    }

    private func requestApplyDraft(_ draftText: String) {
        switch RecordEditorAssistance.diaryApplyPlan(for: draftText, existingDiary: draft.diary) {
        case .none:
            return
        case .replaceEmpty(let text):
            draft.diary = text
            state.isShowingAIDraft = false
        case .needsChoice(let text):
            state.pendingDraftTextToApply = text
            state.isShowingAIDraftApplyChoice = true
        }
    }
}

extension View {
    /// 세 단계 흐름에 보조 기능을 붙인다. 초안은 그대로 하나다.
    func recordCreateAssistance(
        draft: Binding<RecordEditorDraft>,
        state: RecordCreateAssistanceState
    ) -> some View {
        modifier(RecordCreateAssistanceModifier(draft: draft, state: state))
    }
}

// MARK: - 1단계 · 기록 도우미

/// Pencil 1단계가 그린 값 입력 아래에 놓이는 **부차적인** 도움 영역.
///
/// 지금 편집기가 이미 가진 두 가지 — 티켓 OCR과 경기 자동 찾기 — 를 세 단계 흐름에서도
/// 쓸 수 있게 한다. 새 기능이 아니고, 새 필드도 만들지 않는다(날씨·먹은 것·응원
/// 준비물은 여전히 없다). 시각적으로도 1단계 본문보다 약하게 둔다.
struct RecordCreateStep1AssistanceSection: View {
    @ObservedObject var state: RecordCreateAssistanceState
    /// 지금 응원팀으로 경기를 찾을 수 있는가. 팀을 모르면 찾을 대상이 없다.
    let canLookUpGames: Bool
    let onFindGames: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text("기록 도우미")
                .font(Font.system(.footnote, design: .default).weight(.semibold))
                .foregroundStyle(VFColor.bodyTertiary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recordCreate.assist.sectionTitle")

            helperRow(
                title: "티켓에서 불러오기",
                detail: "티켓 사진에서 날짜·팀·구장·좌석을 찾아요. 이미지는 서버로 보내지 않아요.",
                systemImage: "ticket",
                identifier: "recordCreate.assist.ticketOCR",
                hint: "티켓 사진을 골라 인식한 값을 채워요. 저장은 하지 않아요."
            ) {
                state.isShowingTicketOCR = true
            }

            helperRow(
                title: "경기 자동 찾기",
                detail: canLookUpGames
                    ? "적어 둔 날짜의 KBO 경기를 찾아 상대팀·구장·점수를 채워요."
                    : "먼저 우리 팀을 고르면 그 날짜의 경기를 찾을 수 있어요.",
                systemImage: "baseball.diamond.bases",
                identifier: "recordCreate.assist.findGame",
                hint: "고른 날짜의 경기 정보를 찾아 채워요. 저장은 하지 않아요.",
                isEnabled: canLookUpGames && state.kboLookupState != .loading,
                action: onFindGames
            )

            if let status = lookupStatusText {
                Text(status)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("recordCreate.assist.lookupStatus")
            }

            if let message = state.message {
                Text(message)
                    .font(VFTypography.metadata)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(VFSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VFColor.primaryActionPale.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                    .accessibilityIdentifier("recordCreate.assist.message")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordCreate.assist.section")
    }

    /// 찾기 결과를 말로 알린다. 결과 없음과 실패를 구분한다.
    private var lookupStatusText: String? {
        switch state.kboLookupState {
        case .idle: nil
        case .loading: "경기 정보를 확인하는 중이에요."
        case .loaded: "이 날짜의 경기를 찾았어요. 목록에서 골라 주세요."
        case .empty: "이 날짜의 경기 정보를 찾지 못했어요. 직접 입력해 주세요."
        case .failed: "서버에서 경기 정보를 가져오지 못했어요. 직접 입력할 수 있어요."
        }
    }

    private func helperRow(
        title: String,
        detail: String,
        systemImage: String,
        identifier: String,
        hint: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VFColor.bodySecondary)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text(title)
                        .font(Font.system(.subheadline, design: .default).weight(.semibold))
                        .foregroundStyle(VFColor.bodyPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail)
                        .font(VFTypography.metadata)
                        .foregroundStyle(VFColor.bodyTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VFColor.bodyTertiary)
            }
            .padding(VFSpacing.sm)
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
}
