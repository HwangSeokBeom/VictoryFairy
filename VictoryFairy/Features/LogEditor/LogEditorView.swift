import PhotosUI
import SwiftUI

/// `AppDataStore`가 받는 저장 입력. 정본 초안(`RecordEditorDraft`)이 이 값을 만든다.
///
/// 값을 지어내지 않도록 기본값을 두지 않는다. 점수는 적히지 않았을 수 있으므로
/// 선택값이다 — 0으로 바꾸면 "0점 경기"라는 없는 사실이 저장된다.
struct LogEditorViewModel {
    var date: Date
    var favoriteTeam: String
    var opponentTeam: String
    var stadium: String
    var result: GameResult
    var ourScore: Int?
    var opponentScore: Int?
    var gameSource: String?
    var linkedKBOGameID: String?
    var officialRecordURL: String?

    init(
        date: Date,
        favoriteTeam: String,
        opponentTeam: String,
        stadium: String,
        result: GameResult,
        ourScore: Int?,
        opponentScore: Int?,
        gameSource: String? = nil,
        linkedKBOGameID: String? = nil,
        officialRecordURL: String? = nil
    ) {
        self.date = date
        self.favoriteTeam = favoriteTeam
        self.opponentTeam = opponentTeam
        self.stadium = stadium
        self.result = result
        self.ourScore = ourScore
        self.opponentScore = opponentScore
        self.gameSource = gameSource
        self.linkedKBOGameID = linkedKBOGameID
        self.officialRecordURL = officialRecordURL
    }
}

private enum KBOGameLookupState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed
}

struct LogEditorView: View {
    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var preferences: UserPreferencesStore
    @EnvironmentObject private var appData: AppDataStore
    @Environment(\.dismiss) private var dismiss
    /// 사용자가 쓴 값 전부. 새로 만들기와 수정하기가 이 하나를 함께 쓴다.
    @State private var draft: RecordEditorDraft
    /// 열었을 때의 초안. 무엇이 바뀌었는지 견주는 기준이다.
    @State private var originalDraft: RecordEditorDraft
    @State private var selectedTone = "담백하게"
    @State private var saveMessage: String?
    @State private var validationMessage: String?
    @State private var isSaving = false
    @State private var isShowingTicketOCR = false
    @State private var isShowingAIPreflight = false
    @State private var isGeneratingAIDraft = false
    @State private var aiDraft: DiaryDraftDTO?
    @State private var isShowingAIDraft = false
    @State private var pendingDraftTextToApply: String?
    @State private var isShowingAIDraftApplyChoice = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessingPhotos = false
    @State private var isShowingPhotoAnalysisSelection = false
    @State private var isAnalyzingPhotos = false
    @State private var photoAnalysis: PhotoAnalysisDTO?
    @State private var isShowingPhotoAnalysisResult = false
    @State private var kboLookupState: KBOGameLookupState = .idle
    @State private var kboLookupSource: String?
    @State private var kboLookupSourceLabel: String?
    @State private var kboLookupSourceDisclosure: String?
    @State private var kboCandidates: [KBOGameCandidateDTO] = []
    @State private var isShowingKBOCandidateSelection = false
    @State private var pendingDiaryOverwriteCandidate: KBOGameCandidateDTO?
    @State private var isShowingDiaryOverwriteConfirmation = false
    @State private var safariRoute: SafariRoute?
    @State private var didStartInitialAIPreflight = false

    private let moods = ["짜릿함", "아쉬움", "편안함", "열광적", "분노", "감동"]
    private let highlights = ["홈런", "역전승", "끝내기", "연장전", "호수비", "응원 분위기", "우천 취소"]
    private let tones = ["담백하게", "감성적으로", "유쾌하게", "SNS 캡션처럼"]
    private let companions = ["혼자", "친구", "가족", "연인", "모임"]
    private let editingLog: AttendanceLogViewState?
    private let mode: RecordEditorMode
    private let startsAIPreflightOnAppear: Bool

    /// 진입점이 쓰던 생김새를 그대로 둔다. 안쪽에서만 모드와 초안으로 옮긴다.
    init(initialDate: Date? = nil, editingLog: AttendanceLogViewState? = nil, startsAIPreflightOnAppear: Bool = false) {
        let mode: RecordEditorMode = editingLog.map { .edit(recordID: $0.id) } ?? .create(initialDate: initialDate)
        self.editingLog = editingLog
        self.mode = mode
        self.startsAIPreflightOnAppear = startsAIPreflightOnAppear
        let initialDraft = RecordEditorDraft.make(
            mode: mode,
            existingRecord: editingLog,
            preferredFavoriteTeamName: nil,
            defaultMoodTag: Self.defaultMoodTag,
            defaultHighlightTag: Self.defaultHighlightTag,
            fallbackDate: Self.fallbackCreateDate
        )
        _draft = State(initialValue: initialDraft)
        _originalDraft = State(initialValue: initialDraft)
    }

    /// 아직 아무것도 고르지 않았을 때 칩이 가리키는 값. 저장되는 사실이 아니라
    /// 목록의 첫 항목이다.
    private static let defaultMoodTag = "짜릿함"
    private static let defaultHighlightTag = "홈런"
    /// 캘린더처럼 날짜를 정해 주는 진입점이 없을 때 쓰는 시작 날짜.
    private static let fallbackCreateDate = Date.vfDate(year: 2026, month: 4, day: 12)

    /// 저장 전에 이 초안이 바뀌었는지. 시트·로딩·오류는 초안에 없으므로 섞이지 않는다.
    private var isDirty: Bool { draft.isDirty(comparedTo: originalDraft) }

    private var validation: RecordEditorValidationResult { RecordEditorValidation.validate(draft) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                requiredSection
                PhotoAttachmentEditorSection(
                    photoLocalRefs: $draft.photo.refs,
                    selectedPhotoItems: $selectedPhotoItems,
                    isProcessingPhotos: isProcessingPhotos,
                    isAnalyzingPhotos: isAnalyzingPhotos,
                    onRemove: removePhoto,
                    onAnalyze: {}
                )
                DiarySectionView(
                    seat: $draft.seat,
                    companion: $draft.companion,
                    shortMemo: $draft.shortMemo,
                    diary: $draft.diary,
                    selectedMood: $draft.moodTag,
                    selectedHighlight: $draft.highlightTag,
                    selectedTone: $selectedTone,
                    moods: moods,
                    highlights: highlights,
                    tones: tones,
                    companions: companions,
                    isGeneratingAIDraft: isGeneratingAIDraft,
                    onTicketOCR: {
                        isShowingTicketOCR = true
                    },
                    onHighlightChange: {
                        draft.appliedHighlightTags = []
                    },
                    onGenerateTemplate: {
                        Task { await generateTemplateDraftForPreview() }
                    },
                    onGenerateAI: {
                        guard validateRequiredFields() else { return }
                        isShowingAIPreflight = true
                    }
                )
                if let saveMessage {
                    Text(saveMessage)
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                        .padding(VFSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VFColor.gameDraw.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                }
                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(VFColor.gameLoss)
                        .padding(VFSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VFColor.gameLoss.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                }
                VFPrimaryButton(title: isSaving ? "저장 중" : "저장하기", systemImage: "checkmark") {
                    Task {
                        await saveLog()
                    }
                }
            }
            .padding(VFSpacing.lg)
            .padding(.bottom, VFSpacing.xl)
        }
        .navigationTitle(mode.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !mode.isEditing, draft.favoriteTeamName.isEmpty {
                // 새로 만들 때만, 그리고 아직 비어 있을 때만 사용자의 응원팀을 채운다.
                // 지금 편집기가 이미 하던 일이고, 지어낸 값이 아니다.
                draft.favoriteTeamName = appData.team(id: preferences.favoriteTeamID)?.name ?? ""
                originalDraft = draft
            }
            if startsAIPreflightOnAppear, !didStartInitialAIPreflight {
                didStartInitialAIPreflight = true
                if validateRequiredFields() {
                    DispatchQueue.main.async {
                        isShowingAIPreflight = true
                    }
                }
            }
        }
        .onChange(of: draft.date) {
            Task {
                await lookupKBOGameCandidates()
            }
        }
        .sheet(isPresented: $isShowingTicketOCR) {
            TicketOCRView(currentFavoriteTeamName: draft.favoriteTeamName) { suggestion in
                applyTicketSuggestion(suggestion)
            }
        }
        .sheet(isPresented: $isShowingAIPreflight) {
            AIPreflightDisclosureSheet {
                isShowingAIPreflight = false
                Task { await generateAIDraft() }
            }
        }
        .sheet(isPresented: $isShowingAIDraft) {
            if let aiDraft {
                AIDiaryDraftSheet(draft: aiDraft) {
                    requestApplyDraft(aiDraft.draftText)
                } onRegenerate: {
                    isShowingAIDraft = false
                    Task { await generateAIDraft() }
                } onUseTemplate: {
                    isShowingAIDraft = false
                    Task { await generateTemplateDraftForPreview() }
                }
            }
        }
        .sheet(isPresented: $isShowingPhotoAnalysisSelection) {
            PhotoAnalysisSelectionSheet(photoLocalRefs: draft.photo.refs, isAnalyzing: isAnalyzingPhotos) { refs in
                Task { await analyzePhotos(refs) }
            }
        }
        .sheet(isPresented: $isShowingPhotoAnalysisResult) {
            if let photoAnalysis {
                PhotoAnalysisResultSheet(analysis: photoAnalysis) {
                    applyPhotoAnalysis(photoAnalysis)
                    isShowingPhotoAnalysisResult = false
                }
            }
        }
        .sheet(isPresented: $isShowingKBOCandidateSelection) {
            KBOGameCandidateSelectionSheet(
                candidates: kboCandidates,
                favoriteTeamID: currentFavoriteTeamID,
                onApply: { candidate in
                    requestKBOGameCandidateApply(candidate)
                    isShowingKBOCandidateSelection = false
                },
                onOpenOfficialLink: openOfficialRecord,
                onManualInput: {
                    kboLookupState = .idle
                    kboCandidates = []
                    isShowingKBOCandidateSelection = false
                }
            )
        }
        .onChange(of: selectedPhotoItems) {
            Task { await importSelectedPhotos() }
        }
        .alert("작성 중인 다이어리가 있어요. 경기 정보로 덮어쓸까요?", isPresented: $isShowingDiaryOverwriteConfirmation) {
            Button("덮어쓰기", role: .destructive) {
                guard let pendingDiaryOverwriteCandidate else { return }
                applyKBOGameCandidate(pendingDiaryOverwriteCandidate, shouldOverwriteDiary: true)
                self.pendingDiaryOverwriteCandidate = nil
            }
            Button("유지하기", role: .cancel) {
                guard let pendingDiaryOverwriteCandidate else { return }
                applyKBOGameCandidate(pendingDiaryOverwriteCandidate, shouldOverwriteDiary: false)
                self.pendingDiaryOverwriteCandidate = nil
            }
        }
        .alert("기존 다이어리를 AI 초안으로 바꿀까요?", isPresented: $isShowingAIDraftApplyChoice) {
            Button("바꾸기", role: .destructive) {
                guard let pendingDraftTextToApply else { return }
                draft.diary = pendingDraftTextToApply
                self.pendingDraftTextToApply = nil
                isShowingAIDraft = false
            }
            Button("이어 붙이기") {
                guard let pendingDraftTextToApply else { return }
                draft.diary = draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? pendingDraftTextToApply
                    : "\(draft.diary)\n\n\(pendingDraftTextToApply)"
                self.pendingDraftTextToApply = nil
                isShowingAIDraft = false
            }
            Button("취소", role: .cancel) {
                pendingDraftTextToApply = nil
            }
        }
        .sheet(item: $safariRoute) { route in
            SafariView(url: route.url)
        }
        .vfScreenBackground()
    }

    private var requiredSection: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("필수 정보")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(VFColor.bodyPrimary)

                DatePicker("경기 날짜", selection: $draft.date, displayedComponents: .date)
                    .tint(theme.primary)

                kboGameSuggestionSection

                ticketOCRPrompt

                teamSelectionBlock

                menuRow(
                    title: "상대팀",
                    value: draft.opponentTeamName,
                    icon: "person.2",
                    values: opponentTeamNames
                ) { value in
                    draft.opponentTeamName = value
                }
                menuRow(
                    title: "구장",
                    value: draft.stadiumName,
                    icon: "mappin.and.ellipse",
                    values: KBOSeed.stadiums
                ) { value in
                    draft.stadiumName = value
                }

                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("경기 결과")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    HStack(spacing: VFSpacing.xs) {
                        ForEach(GameResult.allCases) { result in
                            Button {
                                draft.result = result
                            } label: {
                                Text(result.title)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .foregroundStyle(draft.result == result ? .white : result.color)
                                    .background(draft.result == result ? result.color : result.color.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(result.title)
                        }
                    }
                }

                if draft.result != .canceled {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        Text("점수")
                            .font(VFTypography.cardTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        HStack(spacing: VFSpacing.sm) {
                            scoreStepper(title: "응원팀", value: scoreBinding(\.ourScore))
                            scoreStepper(title: "상대팀", value: scoreBinding(\.opponentScore))
                        }
                    }
                }

                if shouldShowScoreWarning {
                    Text("점수와 결과가 서로 달라 보여요. 한 번만 확인해 주세요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.gameLoss)
                        .padding(VFSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VFColor.gameLoss.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var kboGameSuggestionSection: some View {
        switch kboLookupState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: VFSpacing.sm) {
                ProgressView()
                    .tint(theme.primary)
                Text("경기 정보를 확인하는 중이에요.")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
            }
            .padding(VFSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        case .loaded:
            if kboCandidates.count == 1, let candidate = kboCandidates.first {
                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("이 날짜의 경기 정보를 찾았어요")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    kboCandidateCard(candidate)
                }
            } else {
                VStack(alignment: .leading, spacing: VFSpacing.sm) {
                    Text("이 날짜에 여러 경기가 있어요")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("기록할 경기를 선택해 주세요")
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                    HStack(spacing: VFSpacing.sm) {
                        Button {
                            isShowingKBOCandidateSelection = true
                        } label: {
                            Text("경기 선택하기")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .foregroundStyle(theme.primary.vfReadableForegroundColor)
                                .background(theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            kboLookupState = .idle
                            kboLookupSource = nil
                            kboLookupSourceLabel = nil
                            kboLookupSourceDisclosure = nil
                            kboCandidates = []
                        } label: {
                            Text("직접 입력할게요")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .foregroundStyle(VFColor.bodyPrimary)
                                .background(VFColor.elevatedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                        .stroke(VFColor.hairline, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .empty:
            kboLookupMessageCard(
                title: "이 날짜의 경기 정보를 찾지 못했어요. 직접 입력해 주세요.",
                message: "경기 정보가 없어도 직접 기록할 수 있어요.",
                systemImage: "calendar.badge.exclamationmark"
            )
        case .failed:
            kboLookupMessageCard(
                title: "서버에서 경기 정보를 가져오지 못했어요",
                message: "직접 입력할 수 있어요.",
                systemImage: "wifi.exclamationmark"
            )
        }
    }

    private var ticketOCRPrompt: some View {
        Button {
            isShowingTicketOCR = true
        } label: {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: "ticket")
                    .foregroundStyle(VFColor.primaryAction)
                    .frame(width: 36, height: 36)
                    .background(VFColor.primaryAction.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text("티켓으로 작성하기")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text("티켓 사진에서 날짜·팀·구장·좌석을 찾아볼게요.")
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("티켓 이미지는 서버로 전송되지 않아요.")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VFColor.primaryAction)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VFColor.bodySecondary)
            }
            .padding(VFSpacing.md)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("티켓으로 작성하기")
    }

    private func kboCandidateCard(_ candidate: KBOGameCandidateDTO) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.md) {
            HStack(alignment: .top, spacing: VFSpacing.sm) {
                Image(systemName: "baseball.diamond.bases")
                    .foregroundStyle(VFColor.primaryAction)
                    .frame(width: 36, height: 36)
                    .background(VFColor.primaryAction.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.matchupText)
                        .font(.system(.headline, design: .rounded).weight(.heavy))
                        .foregroundStyle(VFColor.bodyPrimary)
                    Text(candidate.stadiumName)
                        .font(.subheadline)
                        .foregroundStyle(VFColor.bodySecondary)
                    if let favoriteTeamID = currentFavoriteTeamID, !candidate.isScheduled {
                        Text("내 기록에는 \(candidate.recordScoreText(favoriteTeamID: favoriteTeamID))로 저장돼요")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(VFColor.bodyPrimary)
                    }
                    if candidate.isScheduled {
                        Text("결과는 경기 후 직접 입력해 주세요.")
                            .font(.caption)
                            .foregroundStyle(VFColor.bodySecondary)
                    }
                    SourceDisclosureView(
                        label: candidate.safeSourceLabel(fallbackSource: kboLookupSource, fallbackSourceLabel: kboLookupSourceLabel),
                        disclosure: candidate.sourceDisclosure ?? kboLookupSourceDisclosure
                    )
                }
            }

            HStack(spacing: VFSpacing.sm) {
                Button {
                    requestKBOGameCandidateApply(candidate)
                } label: {
                    Text("경기 정보 적용")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(theme.primary.vfReadableForegroundColor)
                        .background(theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    kboLookupState = .idle
                    kboLookupSource = nil
                    kboLookupSourceLabel = nil
                    kboLookupSourceDisclosure = nil
                    kboCandidates = []
                } label: {
                    Text("직접 입력할게요")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .background(VFColor.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                .stroke(VFColor.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }

            if candidate.officialRecordURL != nil {
                Text("공식 기록 보기")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VFColor.bodySecondary)
                Button {
                    openOfficialRecord(candidate)
                } label: {
                    Label("공식 기록 보기", systemImage: "safari")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .background(VFColor.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous)
                                .stroke(VFColor.hairline, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("공식 기록 보기")
            }
        }
        .padding(VFSpacing.md)
        .background(
            LinearGradient(
                colors: [VFColor.subtleSurface, VFColor.elevatedSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                .stroke(VFColor.primaryAction.opacity(0.22), lineWidth: 1)
        )
    }

    private func kboLookupMessageCard(title: String, message: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(VFColor.bodySecondary)
                .frame(width: 32, height: 32)
                .background(VFColor.elevatedSurface)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(VFColor.bodyPrimary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
            }
        }
        .padding(VFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }

    /// 규칙은 `RecordEditorValidation`이 갖는다. 화면은 결과만 그린다.
    private var shouldShowScoreWarning: Bool {
        validation.warnings.contains(.scoreDisagreesWithResult)
    }

    /// 점수 스테퍼용 이음새. 적히지 않은 점수는 0으로 보이지만, 사용자가 손대기
    /// 전까지는 초안에서 계속 비어 있다.
    private func scoreBinding(_ keyPath: WritableKeyPath<RecordEditorDraft, Int?>) -> Binding<Int> {
        Binding(
            get: { draft[keyPath: keyPath] ?? 0 },
            set: { draft[keyPath: keyPath] = $0 }
        )
    }

    private var opponentTeamNames: [String] {
        appData.teams
            .filter { $0.name != draft.favoriteTeamName }
            .map(\.name)
    }

    private func menuRow(title: String, value: String, icon: String, values: [String], onSelect: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(values, id: \.self) { option in
                Button(option) {
                    onSelect(option)
                }
            }
        } label: {
            HStack(spacing: VFSpacing.md) {
                Image(systemName: icon)
                    .foregroundStyle(theme.primary)
                    .frame(width: 32, height: 32)
                    .background(theme.primary.opacity(0.1))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: VFSpacing.xxs) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(VFColor.bodySecondary)
                    Text(value)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(VFColor.bodyPrimary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundStyle(VFColor.bodySecondary)
            }
            .padding(VFSpacing.sm)
            .background(VFColor.subtleSurface)
            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        }
    }

    private var teamSelectionBlock: some View {
        VStack(alignment: .leading, spacing: VFSpacing.sm) {
            Text("응원팀")
                .font(VFTypography.cardTitle)
                .foregroundStyle(VFColor.bodyPrimary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                ForEach(appData.teams) { team in
                    Button {
                        appData.updateFavoriteTeam(team.id)
            draft.favoriteTeamName = team.name
                        if draft.opponentTeamName == team.name {
                            draft.opponentTeamName = opponentTeamNames.first ?? draft.opponentTeamName
                        }
                        Task {
                            await lookupKBOGameCandidates()
                        }
                    } label: {
                        Text(team.name)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(team.name == draft.favoriteTeamName ? theme.textOnPrimary : VFColor.bodyPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(team.name == draft.favoriteTeamName ? theme.primary : VFColor.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var currentFavoriteTeamID: String? {
        KBOSeed.team(named: draft.favoriteTeamName)?.id
            ?? KBOSeed.normalizedTeamID(preferences.favoriteTeamID)
    }

    private func lookupKBOGameCandidates() async {
        guard let favoriteTeamID = currentFavoriteTeamID else {
            kboLookupState = .idle
            kboLookupSource = nil
            kboLookupSourceLabel = nil
            kboLookupSourceDisclosure = nil
            kboCandidates = []
            return
        }

        let lookupDate = draft.date
        kboLookupState = .loading
        kboLookupSource = nil
        kboLookupSourceLabel = nil
        kboLookupSourceDisclosure = nil
        kboCandidates = []

        do {
            let response = try await appData.fetchKBOGameCandidates(date: lookupDate, favoriteTeamID: favoriteTeamID)
            guard Calendar.current.isDate(lookupDate, inSameDayAs: draft.date) else { return }
            kboLookupSource = response.source
            kboLookupSourceLabel = response.sourceLabel
            kboLookupSourceDisclosure = response.sourceDisclosure
            kboCandidates = response.items
            kboLookupState = response.items.isEmpty ? .empty : .loaded
            isShowingKBOCandidateSelection = response.items.count > 1
        } catch {
            guard Calendar.current.isDate(lookupDate, inSameDayAs: draft.date) else { return }
            kboLookupSource = nil
            kboLookupSourceLabel = nil
            kboLookupSourceDisclosure = nil
            kboCandidates = []
            kboLookupState = .failed
        }
    }

    private func requestKBOGameCandidateApply(_ candidate: KBOGameCandidateDTO) {
        if !candidate.isScheduled,
           candidate.suggestedDiaryTemplate(favoriteTeamID: currentFavoriteTeamID).isEmpty == false,
           draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            pendingDiaryOverwriteCandidate = candidate
            isShowingDiaryOverwriteConfirmation = true
            return
        }
        applyKBOGameCandidate(candidate, shouldOverwriteDiary: false)
    }

    private func applyKBOGameCandidate(_ candidate: KBOGameCandidateDTO, shouldOverwriteDiary: Bool) {
        guard let favoriteTeamID = currentFavoriteTeamID else { return }
        let perspective = candidate.favoriteTeamPerspective(favoriteTeamID: favoriteTeamID)
        draft.date = Date.vfParseServerDate(candidate.date)
        draft.opponentTeamName = perspective.opponentTeamName
        draft.stadiumName = candidate.suggestedStadiumName
        draft.gameSource = candidate.source ?? kboLookupSource
        draft.linkedKBOGameID = candidate.gameID
        draft.officialRecordURL = candidate.officialRecordURL?.absoluteString

        if !candidate.isScheduled, let result = perspective.result {
            draft.result = result
        }
        if !candidate.isScheduled,
           let favoriteScore = perspective.favoriteTeamScore,
           let opponentScore = perspective.opponentTeamScore {
            draft.ourScore = favoriteScore
            draft.opponentScore = opponentScore
        }

        if !candidate.isScheduled {
            draft.moodTag = candidate.preferredMoodTag(for: draft.result ?? .canceled, availableMoods: moods)
            draft.highlightTag = candidate.preferredHighlightTag(availableHighlights: highlights)
            draft.appliedHighlightTags = candidate.suggestedHighlightTags
            let suggestedMemo = candidate.suggestedShortMemo(favoriteTeamID: favoriteTeamID)
            if shouldReplaceShortMemo {
                draft.shortMemo = suggestedMemo
            }
            let suggestedDiary = candidate.suggestedDiaryTemplate(favoriteTeamID: favoriteTeamID)
            if shouldOverwriteDiary || draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                draft.diary = suggestedDiary
            }
        }
        debugLogKBO("applied suggestion score=\(candidate.recordScoreText(favoriteTeamID: favoriteTeamID))")
        validationMessage = "경기 정보를 적용했어요. 저장 전 내용을 확인해 주세요."
        kboLookupState = .idle
        kboLookupSource = nil
        kboLookupSourceLabel = nil
        kboLookupSourceDisclosure = nil
        kboCandidates = []
    }

    private func openOfficialRecord(_ candidate: KBOGameCandidateDTO) {
        guard let url = candidate.officialRecordURL else { return }
        safariRoute = SafariRoute(url: url)
        debugLogKBO("official link opened=true")
    }

    private func debugLogKBO(_ message: String) {
        #if DEBUG
        print("[KBO] \(message)")
        #endif
    }

    private func saveLog() async {
        guard !isSaving else { return }
        guard validateRequiredFields() else { return }
        guard let saveInput = draft.makeSaveInput() else { return }
        isSaving = true
        if let recordID = mode.editingRecordID {
            _ = await appData.updateAttendanceLog(
                id: recordID,
                viewModel: saveInput,
                seat: draft.seat,
                companion: draft.companion,
                shortMemo: draft.shortMemo,
                diary: draft.diary,
                tags: draft.saveTags,
                photoLocalRefs: draft.photo.refs
            )
        } else {
            _ = await appData.saveAttendanceLog(
                viewModel: saveInput,
                seat: draft.seat,
                companion: draft.companion,
                shortMemo: draft.shortMemo,
                diary: draft.diary,
                tags: draft.saveTags,
                photoLocalRefs: draft.photo.refs
            )
        }
        isSaving = false
        saveMessage = appData.lastSaveMessage
        // 저장이 끝나면 이 초안이 새 기준이 된다. 편집기가 그대로 남아 있어도
        // "바뀐 것 없음"으로 시작한다.
        originalDraft = draft
        dismiss()
    }

    private func applyTicketSuggestion(_ suggestion: TicketFieldSuggestion) {
        if let gameDate = suggestion.gameDate {
            draft.date = gameDate
        }
        if let favoriteTeamName = suggestion.favoriteTeamName {
            draft.favoriteTeamName = favoriteTeamName
        }
        if let opponentTeamName = suggestion.opponentTeamName, opponentTeamName != draft.favoriteTeamName {
            draft.opponentTeamName = opponentTeamName
        }
        if let stadiumName = suggestion.stadiumName {
            draft.stadiumName = stadiumName
        }
        if let seatText = suggestion.seatText {
            draft.seat = seatText
        }
        draft.appliedHighlightTags = []
        validationMessage = "인식한 내용이 정확한지 확인해 주세요."
    }

    private func generateAIDraft() async {
        guard !isGeneratingAIDraft else { return }
        guard validateRequiredFields() else { return }
        isGeneratingAIDraft = true
        defer { isGeneratingAIDraft = false }

        do {
            aiDraft = try await appData.createDiaryDraft(request: makeDiaryDraftRequest())
            validationMessage = nil
            isShowingAIDraft = true
        } catch APIError.server(let code, _) where code == "AI_FEATURE_DISABLED" {
            validationMessage = "AI 기능이 아직 비활성화되어 있어요. 기본 문장으로 시작해볼까요?"
            await generateTemplateDraftForPreview()
        } catch APIError.server(let code, _) where code == "AI_CONFIG_MISSING" {
            validationMessage = "AI 설정을 확인해야 해요. 기본 문장으로 시작해볼까요?"
            await generateTemplateDraftForPreview()
        } catch APIError.server(let code, _) where code == "AI_DAILY_LIMIT_EXCEEDED" {
            validationMessage = "오늘 사용할 수 있는 AI 초안 횟수를 모두 사용했어요."
            await generateTemplateDraftForPreview()
        } catch {
            validationMessage = "AI 초안을 만들지 못했어요. 기본 문장으로 채워볼게요."
            await generateTemplateDraftForPreview()
        }
    }

    private func makeDiaryDraftRequest() -> DiaryDraftRequest {
        DiaryDraftRequest(
            gameDate: DateFormatter.vfAPIDate.string(from: draft.date),
            favoriteTeamName: draft.favoriteTeamName,
            opponentTeamName: draft.opponentTeamName,
            stadiumName: draft.stadiumName,
            result: (draft.result ?? .canceled).serverValue,
            scoreText: draftScoreText,
            moodTags: [draft.moodTag],
            highlightTags: [draft.highlightTag],
            companionType: sanitizedCompanionType,
            tone: selectedTone.aiToneValue,
            extraNoteSanitized: draft.shortMemo.sanitizedExtraNote,
            locale: "ko-KR"
        )
    }

    private func makeTemplateDraftRequest() -> TemplateDraftRequest {
        let request = makeDiaryDraftRequest()
        return TemplateDraftRequest(
            gameDate: request.gameDate,
            favoriteTeamName: request.favoriteTeamName,
            opponentTeamName: request.opponentTeamName,
            stadiumName: request.stadiumName,
            result: request.result,
            scoreText: request.scoreText,
            moodTags: request.moodTags,
            highlightTags: request.highlightTags,
            companionType: request.companionType,
            tone: request.tone,
            extraNoteSanitized: request.extraNoteSanitized,
            locale: request.locale
        )
    }

    private func generateTemplateDraftForPreview() async {
        guard validateRequiredFields() else { return }
        do {
            aiDraft = try await appData.createTemplateDraft(request: makeTemplateDraftRequest()).diaryDraft
            isShowingAIDraft = true
        } catch {
            aiDraft = localTemplateDraft()
            isShowingAIDraft = true
        }
    }

    private func localTemplateDraft() -> DiaryDraftDTO {
        let draft = DiaryTemplateGenerator().generate(
            favoriteTeamName: draft.favoriteTeamName,
            opponentTeamName: draft.opponentTeamName,
            stadium: draft.stadiumName,
            result: draft.result ?? .canceled,
            favoriteTeamScore: draft.result == .canceled ? nil : draft.ourScore,
            opponentTeamScore: draft.result == .canceled ? nil : draft.opponentScore,
            moodTags: [draft.moodTag],
            highlightTags: [draft.highlightTag],
            companionType: draft.companion,
            seatText: draft.seat,
            shortMemo: draft.shortMemo,
            tone: selectedTone
        )
        return DiaryDraftDTO(
            draftText: draft,
            summaryText: "기본 문장 초안",
            shareText: nil,
            hashtags: ["#승리요정", "#KBO직관"],
            model: "local-template",
            safetyNotice: "저장 전 직접 확인해 주세요.",
            warnings: []
        )
    }

    private func requestApplyDraft(_ draftText: String) {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if draft.diary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft.diary = trimmed
            isShowingAIDraft = false
        } else {
            pendingDraftTextToApply = trimmed
            isShowingAIDraftApplyChoice = true
        }
    }

    private func importSelectedPhotos() async {
        guard !selectedPhotoItems.isEmpty else { return }
        isProcessingPhotos = true
        defer {
            isProcessingPhotos = false
            selectedPhotoItems = []
        }

        let remainingSlots = max(0, 10 - draft.photo.refs.count)
        guard remainingSlots > 0 else {
            validationMessage = "사진은 최대 10장까지 추가할 수 있어요."
            return
        }

        let service = PhotoAttachmentService()
        for item in selectedPhotoItems.prefix(remainingSlots) {
            do {
                let ref = try await service.savePhoto(from: item)
                draft.photo.append(ref)
            } catch {
                validationMessage = error.localizedDescription
            }
        }
    }

    private func removePhoto(_ ref: String) {
        // 지우는 것은 언제나 사용자의 명시적 의도다. 실패나 취소로는 지워지지 않는다.
        draft.photo.remove(ref)
    }

    private func analyzePhotos(_ refs: [String]) async {
        guard !refs.isEmpty else { return }
        isAnalyzingPhotos = true
        defer { isAnalyzingPhotos = false }

        do {
            photoAnalysis = try await appData.analyzePhotos(localRefs: refs)
            isShowingPhotoAnalysisSelection = false
            isShowingPhotoAnalysisResult = true
            validationMessage = nil
        } catch APIError.server(let code, _) where code == "PHOTO_ANALYSIS_DISABLED" || code == "AI_FEATURE_DISABLED" {
            validationMessage = "사진 분석 기능은 아직 사용할 수 없어요."
        } catch {
            validationMessage = "사진 분석 기능은 아직 사용할 수 없어요."
        }
    }

    private func applyPhotoAnalysis(_ analysis: PhotoAnalysisDTO) {
        if let mood = analysis.suggestedMoodTags.first, moods.contains(mood) {
            draft.moodTag = mood
        }
        if let highlight = analysis.suggestedHighlightTags.first, highlights.contains(highlight) {
            draft.highlightTag = highlight
        }
        if let hint = analysis.diaryHintText?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
            draft.diary = draft.diary.isEmpty ? hint : "\(draft.diary)\n\n\(hint)"
        }
    }

    private var sanitizedCompanionType: String? {
        let trimmed = draft.companion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        switch trimmed {
        case "혼자": return "alone"
        case "친구": return "friends"
        case "가족": return "family"
        case "연인": return "partner"
        default: return "group"
        }
    }

    /// 한 줄 메모를 경기 정보로 덮어써도 되는가. 사용자가 쓴 글은 지우지 않는다.
    private var shouldReplaceShortMemo: Bool {
        draft.shortMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// AI 초안 요청에 실어 보내는 점수 문구. 없는 점수를 0으로 지어내지 않는다.
    private var draftScoreText: String {
        guard draft.result != .canceled else { return "취소" }
        guard let ours = draft.ourScore, let theirs = draft.opponentScore else {
            return draft.result?.title ?? ""
        }
        return "\(ours):\(theirs) \(draft.result?.title ?? "")"
    }

    /// 검증 규칙은 `RecordEditorValidation`이 갖는다. 여기서는 문구만 띄운다.
    @discardableResult
    private func validateRequiredFields() -> Bool {
        let result = validation
        validationMessage = result.blockingMessage
        return result.isValid
    }

    private func scoreStepper(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
            Stepper(value: value, in: 0...30) {
                Text("\(value.wrappedValue)")
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(VFColor.bodyPrimary)
            }
        }
        .padding(VFSpacing.sm)
        .background(VFColor.subtleSurface)
        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
    }
}

private struct KBOGameFavoritePerspective {
    let favoriteTeamName: String
    let opponentTeamID: String
    let opponentTeamName: String
    let favoriteTeamScore: Int?
    let opponentTeamScore: Int?
    let result: GameResult?
}

private extension KBOGameCandidateDTO {
    func safeSourceLabel(fallbackSource: String?, fallbackSourceLabel: String? = nil) -> String {
        KBOReviewSafeSource.visibleLabel(
            sourceLabel: sourceLabel ?? fallbackSourceLabel,
            source: source ?? fallbackSource
        )
    }

    var suggestedStadiumName: String {
        if let stadiumName = attendanceSuggestion?.stadiumName, !stadiumName.isEmpty {
            return stadiumName
        }
        return stadiumName
    }

    var matchupText: String {
        if let matchupText = attendanceSuggestion?.matchupText, !matchupText.isEmpty {
            return matchupText
        }
        return "\(shortName(teamID: homeTeamID, fallbackName: homeTeamName)) vs \(shortName(teamID: awayTeamID, fallbackName: awayTeamName))"
    }

    var scoreboardText: String {
        if isCanceled {
            return "\(matchupText) 취소"
        }
        if isScheduled {
            return "예정 경기"
        }
        guard let homeScore, let awayScore else {
            return "\(matchupText) 점수 미정"
        }
        if homeScore == awayScore {
            return "\(shortName(teamID: homeTeamID, fallbackName: homeTeamName)) \(homeScore):\(awayScore) \(shortName(teamID: awayTeamID, fallbackName: awayTeamName))"
        }
        let homeWon = homeScore > awayScore
        let winnerName = homeWon ? shortName(teamID: homeTeamID, fallbackName: homeTeamName) : shortName(teamID: awayTeamID, fallbackName: awayTeamName)
        let loserName = homeWon ? shortName(teamID: awayTeamID, fallbackName: awayTeamName) : shortName(teamID: homeTeamID, fallbackName: homeTeamName)
        let winnerScore = homeWon ? homeScore : awayScore
        let loserScore = homeWon ? awayScore : homeScore
        return "\(winnerName) \(winnerScore):\(loserScore) \(loserName)"
    }

    var isCanceled: Bool {
        let normalizedStatus = status.lowercased()
        return normalizedStatus.contains("cancel") || status.contains("취소")
    }

    var isScheduled: Bool {
        let normalizedStatus = status.lowercased()
        return normalizedStatus == "scheduled" || normalizedStatus == "pre" || status.contains("예정")
    }

    var officialRecordURL: URL? {
        let urlText = officialLinks?.kboRecordURL ?? officialLinks?.kboGameCenterURL
        guard let urlText, !urlText.isEmpty else { return nil }
        return URL(string: urlText)
    }

    func recordScoreText(favoriteTeamID: String) -> String {
        if let scoreText = attendanceSuggestion?.scoreText, !scoreText.isEmpty {
            return scoreText
        }
        let perspective = favoriteTeamPerspective(favoriteTeamID: favoriteTeamID)
        guard let result = perspective.result else {
            return isCanceled ? "취소" : (isScheduled ? "예정 경기" : "점수 미정")
        }
        guard result != .canceled else { return "취소" }
        guard let favoriteScore = perspective.favoriteTeamScore,
              let opponentScore = perspective.opponentTeamScore else {
            return result.title
        }
        return "\(favoriteScore):\(opponentScore) \(result.title)"
    }

    func favoriteTeamPerspective(favoriteTeamID: String) -> KBOGameFavoritePerspective {
        let normalizedFavoriteTeamID = KBOSeed.normalizedTeamID(favoriteTeamID) ?? favoriteTeamID
        let favoriteIsAway = normalizedFavoriteTeamID == awayTeamID
        let favoriteName = favoriteIsAway ? awayTeamName : homeTeamName
        let suggestedOpponentTeamID = attendanceSuggestion?.opponentTeamID.flatMap { KBOSeed.normalizedTeamID($0) } ?? attendanceSuggestion?.opponentTeamID
        let opponentTeamID = suggestedOpponentTeamID ?? (favoriteIsAway ? homeTeamID : awayTeamID)
        let opponentTeamName = favoriteIsAway ? homeTeamName : awayTeamName
        let favoriteTeamScore = attendanceSuggestion?.ourScore ?? (favoriteIsAway ? awayScore : homeScore)
        let opponentTeamScore = attendanceSuggestion?.opponentScore ?? (favoriteIsAway ? homeScore : awayScore)

        let result: GameResult?
        if isCanceled {
            result = .canceled
        } else if isScheduled {
            result = nil
        } else if let suggestedResult = attendanceSuggestion?.result {
            result = GameResult(serverValue: suggestedResult)
        } else if let favoriteTeamScore, let opponentTeamScore {
            if favoriteTeamScore > opponentTeamScore {
                result = .win
            } else if favoriteTeamScore < opponentTeamScore {
                result = .loss
            } else {
                result = .draw
            }
        } else {
            result = nil
        }

        return KBOGameFavoritePerspective(
            favoriteTeamName: favoriteName,
            opponentTeamID: opponentTeamID,
            opponentTeamName: opponentTeamName,
            favoriteTeamScore: favoriteTeamScore,
            opponentTeamScore: opponentTeamScore,
            result: result
        )
    }

    func preferredMoodTag(for result: GameResult, availableMoods: [String]) -> String {
        let serverTags = attendanceSuggestion?.highlightTags ?? highlightTags
        if let tag = serverTags.first(where: { availableMoods.contains($0) }) {
            return tag
        }
        let fallback: String
        switch result {
        case .win:
            fallback = "짜릿함"
        case .loss:
            fallback = "아쉬움"
        case .draw:
            fallback = "편안함"
        case .canceled:
            fallback = "아쉬움"
        }
        return availableMoods.contains(fallback) ? fallback : (availableMoods.first ?? fallback)
    }

    func preferredHighlightTag(availableHighlights: [String]) -> String {
        let serverTags = suggestedHighlightTags
        if let tag = serverTags.first(where: { availableHighlights.contains($0) }) {
            return tag
        }
        let fallback = "응원 분위기"
        return availableHighlights.contains(fallback) ? fallback : (availableHighlights.first ?? fallback)
    }

    var suggestedHighlightTags: [String] {
        let tags = attendanceSuggestion?.highlightTags.isEmpty == false ? attendanceSuggestion?.highlightTags : highlightTags
        return tags ?? []
    }

    func suggestedShortMemo(favoriteTeamID: String) -> String {
        if let shortMemo = attendanceSuggestion?.shortMemo, !shortMemo.isEmpty {
            return shortMemo
        }
        return deterministicShortMemo(favoriteTeamID: favoriteTeamID)
    }

    func suggestedDiaryTemplate(favoriteTeamID: String?) -> String {
        if let diaryTemplate = attendanceSuggestion?.diaryTemplate, !diaryTemplate.isEmpty {
            return diaryTemplate
        }
        guard let favoriteTeamID else { return "" }
        return deterministicDiaryTemplate(favoriteTeamID: favoriteTeamID)
    }

    func deterministicShortMemo(favoriteTeamID: String) -> String {
        let perspective = favoriteTeamPerspective(favoriteTeamID: favoriteTeamID)
        guard let result = perspective.result else {
            return resultSummary ?? "\(matchupText) 경기"
        }
        guard result != .canceled else {
            return "\(matchupText) 경기가 취소된 날"
        }
        guard let homeScore, let awayScore else {
            return resultSummary ?? "\(matchupText) 경기"
        }
        if homeScore == awayScore {
            return "\(homeScore):\(awayScore) 무승부였던 경기"
        }
        let homeWon = homeScore > awayScore
        let winnerName = homeWon ? shortName(teamID: homeTeamID, fallbackName: homeTeamName) : shortName(teamID: awayTeamID, fallbackName: awayTeamName)
        let winnerScore = homeWon ? homeScore : awayScore
        let loserScore = homeWon ? awayScore : homeScore
        return "\(winnerName)가 \(winnerScore):\(loserScore)으로 승리했던 경기"
    }

    func deterministicDiaryTemplate(favoriteTeamID: String) -> String {
        let perspective = favoriteTeamPerspective(favoriteTeamID: favoriteTeamID)
        let favoriteTeamName = perspective.favoriteTeamName
        let opponentTeamName = perspective.opponentTeamName
        guard let result = perspective.result else {
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName)와 \(opponentTeamName)의 경기를 직관했다. 아직 결과는 비어 있지만, 경기장의 분위기와 응원은 오래 기억에 남았다."
        }
        guard result != .canceled else {
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName) 경기를 기다렸지만 경기가 취소됐다. 아쉬움은 남았지만 다음 직관을 다시 기대하게 된 하루였다."
        }
        guard let favoriteScore = perspective.favoriteTeamScore,
              let opponentScore = perspective.opponentTeamScore else {
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName)와 \(opponentTeamName)의 경기를 직관했다. 경기장의 분위기와 응원은 오래 기억에 남았다."
        }
        let score = "\(favoriteScore):\(opponentScore)"
        switch result {
        case .win:
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName) 경기를 직관했다. \(score) 승리로 마무리되어 더 짜릿한 하루였다."
        case .loss:
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName)와 \(opponentTeamName)의 경기를 직관했다. 결과는 \(score) 패배였지만, 경기장의 분위기와 응원은 오래 기억에 남았다."
        case .draw:
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName) 경기를 직관했다. \(score) 무승부로 끝났지만, 끝까지 긴장감이 이어진 경기였다."
        case .canceled:
            return "오늘은 \(stadiumName)에서 \(favoriteTeamName) 경기를 기다렸지만 경기가 취소됐다. 아쉬움은 남았지만 다음 직관을 다시 기대하게 된 하루였다."
        }
    }

    private func shortName(teamID: String, fallbackName: String) -> String {
        KBOSeed.team(id: teamID)?.shortName ?? fallbackName
    }
}

private struct KBOGameCandidateSelectionSheet: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let candidates: [KBOGameCandidateDTO]
    let favoriteTeamID: String?
    let onApply: (KBOGameCandidateDTO) -> Void
    let onOpenOfficialLink: (KBOGameCandidateDTO) -> Void
    let onManualInput: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    VStack(alignment: .leading, spacing: VFSpacing.xs) {
                        Text("이 날짜에 여러 경기가 있어요")
                            .font(VFTypography.sectionTitle)
                            .foregroundStyle(VFColor.bodyPrimary)
                        Text("기록할 경기를 선택해 주세요")
                            .font(.subheadline)
                            .foregroundStyle(VFColor.bodySecondary)
                    }

                    ForEach(candidates) { candidate in
                        VStack(alignment: .leading, spacing: VFSpacing.sm) {
                            Button {
                                onApply(candidate)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                                    Text(candidate.safeSourceLabel(fallbackSource: nil))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.primary)
                                    Text(candidate.matchupText)
                                        .font(.system(.headline, design: .rounded).weight(.bold))
                                        .foregroundStyle(VFColor.bodyPrimary)
                                    Text(candidate.stadiumName)
                                        .font(.subheadline)
                                        .foregroundStyle(VFColor.bodySecondary)
                                    Text(candidate.scoreboardText)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VFColor.bodyPrimary)
                                    if let favoriteTeamID, !candidate.isScheduled {
                                        Text("내 기록에는 \(candidate.recordScoreText(favoriteTeamID: favoriteTeamID))로 저장돼요")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(theme.primary)
                                    }
                                    if candidate.isScheduled {
                                        Text("결과는 경기 후 직접 입력해 주세요.")
                                            .font(.caption)
                                            .foregroundStyle(VFColor.bodySecondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)

                            if candidate.officialRecordURL != nil {
                                Button {
                                    onOpenOfficialLink(candidate)
                                } label: {
                                    Label("공식 기록 보기", systemImage: "safari")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(theme.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(VFSpacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(VFColor.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous)
                                .stroke(VFColor.hairline, lineWidth: 1)
                        )
                    }

                    VFSecondaryButton(title: "직접 입력할게요", systemImage: "square.and.pencil") {
                        onManualInput()
                        dismiss()
                    }
                }
                .padding(VFSpacing.lg)
            }
            .navigationTitle("경기 선택")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }
}

struct DiarySectionView: View {
    @Binding var seat: String
    @Binding var companion: String
    @Binding var shortMemo: String
    @Binding var diary: String
    @Binding var selectedMood: String
    @Binding var selectedHighlight: String
    @Binding var selectedTone: String
    let moods: [String]
    let highlights: [String]
    let tones: [String]
    let companions: [String]
    var isGeneratingAIDraft = false
    var onTicketOCR: () -> Void = {}
    var onHighlightChange: () -> Void = {}
    var onGenerateTemplate: () -> Void = {}
    var onGenerateAI: () -> Void = {}

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                Text("선택 정보")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)

                textField("좌석", text: $seat)
                textField("한 줄 메모", text: $shortMemo)

                VStack(alignment: .leading, spacing: VFSpacing.xs) {
                    Text("직관 다이어리")
                        .font(VFTypography.cardTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $diary)
                            .frame(minHeight: 130)
                            .scrollContentBackground(.hidden)
                            .foregroundStyle(VFColor.bodyPrimary)
                            .padding(VFSpacing.xs)
                            .background(VFColor.subtleSurface)
                            .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                        if diary.isEmpty {
                            Text("오늘 경기의 분위기, 기억나는 장면을 남겨보세요.")
                                .font(.subheadline)
                                .foregroundStyle(VFColor.bodySecondary)
                                .padding(VFSpacing.md)
                                .allowsHitTesting(false)
                        }
                    }
                }

                chipGroup(title: "분위기", values: moods, selection: $selectedMood)
                chipGroup(title: "하이라이트", values: highlights, selection: $selectedHighlight, onChange: onHighlightChange)
                chipGroup(title: "말투", values: tones, selection: $selectedTone)
                chipGroup(title: "동행 유형", values: companions, selection: $companion)

                VStack(spacing: VFSpacing.sm) {
                    VFSecondaryButton(title: "기본 문장으로 채우기", systemImage: "text.badge.plus") {
                        onGenerateTemplate()
                    }
                    VFSecondaryButton(title: isGeneratingAIDraft ? "AI 초안 만드는 중" : "AI로 후기 초안 만들기", systemImage: "sparkles") {
                        onGenerateAI()
                    }
                    .disabled(isGeneratingAIDraft)
                    .opacity(isGeneratingAIDraft ? 0.55 : 1)
                }

                Text("AI 초안 생성을 위해 경기 정보 일부만 서버로 전송돼요. 사진, 정확한 위치, 동행자 실명은 기본 전송하지 않아요.")
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func textField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(VFColor.bodySecondary)
            TextField(title, text: text, prompt: Text(title).foregroundStyle(VFColor.bodySecondary))
                .textFieldStyle(.plain)
                .foregroundStyle(VFColor.bodyPrimary)
                .tint(VFColor.primaryAction)
                .padding(VFSpacing.sm)
                .background(VFColor.subtleSurface)
                .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
        }
    }

    private func chipGroup(title: String, values: [String], selection: Binding<String>, onChange: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(VFTypography.cardTitle)
                .foregroundStyle(VFColor.bodyPrimary)
            FlowLayout(spacing: VFSpacing.xs) {
                ForEach(values, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                        onChange?()
                    } label: {
                        VFChip(title: value, isSelected: selection.wrappedValue == value)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct PhotoAttachmentEditorSection: View {
    @Binding var photoLocalRefs: [String]
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let isProcessingPhotos: Bool
    let isAnalyzingPhotos: Bool
    let onRemove: (String) -> Void
    let onAnalyze: () -> Void
    private let service = PhotoAttachmentService()

    var body: some View {
        VFCard {
            VStack(alignment: .leading, spacing: VFSpacing.md) {
                HStack {
                    Text("사진")
                        .font(VFTypography.sectionTitle)
                        .foregroundStyle(VFColor.bodyPrimary)
                    Spacer()
                    Text("\(photoLocalRefs.count)/10")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VFColor.bodySecondary)
                }

                Text("사진은 우선 기기에만 저장돼요.")
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: max(0, 10 - photoLocalRefs.count), matching: .images) {
                    Label(isProcessingPhotos ? "사진 처리 중" : "사진 추가", systemImage: "photo.on.rectangle.angled")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(VFColor.bodyPrimary)
                        .background(VFColor.subtleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                }
                .disabled(isProcessingPhotos || photoLocalRefs.count >= 10)
                .opacity(photoLocalRefs.count >= 10 ? 0.55 : 1)

                if !photoLocalRefs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VFSpacing.sm) {
                            ForEach(photoLocalRefs, id: \.self) { ref in
                                ZStack(alignment: .topTrailing) {
                                    AttachmentPhotoView(ref: ref, target: .editorThumbnail)
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                                    Button {
                                        onRemove(ref)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(.white, VFColor.deepAccent.opacity(0.85))
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("사진 삭제")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct PhotoAnalysisSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let photoLocalRefs: [String]
    let isAnalyzing: Bool
    let onConfirm: ([String]) -> Void
    @State private var selectedRefs: Set<String> = []
    private let service = PhotoAttachmentService()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("사진 분석을 위해 선택한 사진이 서버로 전송돼요. 계속할까요?")
                    .font(VFTypography.body)
                    .foregroundStyle(VFColor.bodyPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: VFSpacing.sm)], spacing: VFSpacing.sm) {
                    ForEach(photoLocalRefs.prefix(10), id: \.self) { ref in
                        Button {
                            toggle(ref)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                AttachmentPhotoView(ref: ref, target: .editorThumbnail)
                                    .frame(height: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: VFRadius.md, style: .continuous))
                                Image(systemName: selectedRefs.contains(ref) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selectedRefs.contains(ref) ? VFColor.gameWin : .white)
                                    .padding(VFSpacing.xs)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("한 번에 최대 3장까지 분석할 수 있어요.")
                    .font(.caption)
                    .foregroundStyle(VFColor.bodySecondary)

                Spacer()

                VFPrimaryButton(title: isAnalyzing ? "분석 중" : "계속하기", systemImage: "checkmark") {
                    onConfirm(Array(selectedRefs.prefix(3)))
                }
                .disabled(selectedRefs.isEmpty || isAnalyzing)
                .opacity(selectedRefs.isEmpty || isAnalyzing ? 0.55 : 1)

                VFSecondaryButton(title: "취소", systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding(VFSpacing.lg)
            .navigationTitle("사진 분석")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedRefs = Set(photoLocalRefs.prefix(3))
            }
            .vfScreenBackground()
        }
    }

    private func toggle(_ ref: String) {
        if selectedRefs.contains(ref) {
            selectedRefs.remove(ref)
        } else if selectedRefs.count < 3 {
            selectedRefs.insert(ref)
        }
    }
}

struct PhotoAnalysisResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    let analysis: PhotoAnalysisDTO
    let onApply: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    Text("사진 분석 결과")
                        .font(VFTypography.sectionTitle)
                        .foregroundStyle(VFColor.bodyPrimary)

                    VFCard {
                        VStack(alignment: .leading, spacing: VFSpacing.md) {
                            if let summary = analysis.summaryText, !summary.isEmpty {
                                Text(summary)
                                    .font(VFTypography.body)
                                    .foregroundStyle(VFColor.bodyPrimary)
                            }
                            if let hint = analysis.diaryHintText, !hint.isEmpty {
                                Text(hint)
                                    .font(.subheadline)
                                    .foregroundStyle(VFColor.bodySecondary)
                            }
                            FlowLayout(spacing: VFSpacing.xs) {
                                ForEach(analysis.suggestedMoodTags + analysis.suggestedHighlightTags, id: \.self) { tag in
                                    VFChip(title: tag, tint: VFColor.deepAccent)
                                }
                            }
                        }
                    }

                    VFPrimaryButton(title: "적용하기", systemImage: "checkmark") {
                        onApply()
                    }
                    VFSecondaryButton(title: "취소", systemImage: "xmark") {
                        dismiss()
                    }
                }
                .padding(VFSpacing.lg)
            }
            .navigationTitle("사진 분석")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }
}

struct SourceDisclosureView: View {
    let label: String
    let disclosure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: VFSpacing.xxs) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(VFColor.primaryAction)
                .padding(.horizontal, VFSpacing.sm)
                .frame(minHeight: 24)
                .background(VFColor.primaryAction.opacity(0.1))
                .clipShape(Capsule())
            Text(KBOReviewSafeSource.disclosure(disclosure))
                .font(.caption2)
                .foregroundStyle(VFColor.bodySecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AIPreflightDisclosureSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: VFSpacing.lg) {
                Text("AI 초안을 만들기 전에")
                    .font(VFTypography.sectionTitle)
                    .foregroundStyle(VFColor.bodyPrimary)

                VFCard(background: VFColor.subtleSurface) {
                    VStack(alignment: .leading, spacing: VFSpacing.sm) {
                        disclosureRow("경기 정보와 선택한 분위기/하이라이트가 서버로 전송돼요.")
                        disclosureRow("사진 원본, 정확한 위치, 동행자 실명은 보내지 않아요.")
                        disclosureRow("AI 초안은 저장 전 직접 확인해 주세요.")
                    }
                }

                Spacer()

                VFPrimaryButton(title: "초안 만들기", systemImage: "sparkles") {
                    onConfirm()
                }
                VFSecondaryButton(title: "취소", systemImage: "xmark") {
                    dismiss()
                }
            }
            .padding(VFSpacing.lg)
            .navigationTitle("AI 초안")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }

    private func disclosureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: VFSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(VFColor.primaryAction)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct AIDiaryDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    let draft: DiaryDraftDTO
    let onApply: () -> Void
    let onRegenerate: () -> Void
    let onUseTemplate: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: VFSpacing.lg) {
                    Text("후기 초안이 만들어졌어요")
                        .font(VFTypography.sectionTitle)
                        .foregroundStyle(VFColor.bodyPrimary)

                    VFCard {
                        VStack(alignment: .leading, spacing: VFSpacing.md) {
                            if let summary = draft.summaryText, !summary.isEmpty {
                                labeledText(title: "요약", text: summary)
                            }
                            labeledText(title: draft.model == "local-template" || draft.model == "template" ? "기본 문장" : "AI 초안", text: draft.draftText)
                            if let shareText = draft.shareText, !shareText.isEmpty {
                                labeledText(title: "공유 문구", text: shareText)
                            }
                            if !draft.hashtags.isEmpty {
                                FlowLayout(spacing: VFSpacing.xs) {
                                    ForEach(draft.hashtags, id: \.self) { hashtag in
                                        VFChip(title: hashtag, tint: VFColor.deepAccent)
                                    }
                                }
                            }
                            if let safetyNotice = draft.safetyNotice {
                                Text(safetyNotice)
                                    .font(.caption)
                                    .foregroundStyle(VFColor.bodySecondary)
                            }
                        }
                    }

                    VFPrimaryButton(title: "적용하기", systemImage: "checkmark") {
                        onApply()
                    }
                    VFSecondaryButton(title: "다시 만들기", systemImage: "arrow.clockwise") {
                        onRegenerate()
                    }
                    VFSecondaryButton(title: "기본 문장으로 채우기", systemImage: "text.badge.plus") {
                        onUseTemplate()
                    }
                    VFSecondaryButton(title: "취소", systemImage: "xmark") {
                        dismiss()
                    }
                }
                .padding(VFSpacing.lg)
            }
            .navigationTitle("AI 후기 초안")
            .navigationBarTitleDisplayMode(.inline)
            .vfScreenBackground()
        }
    }

    private func labeledText(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: VFSpacing.xs) {
            Text(title)
                .font(VFTypography.cardTitle)
                .foregroundStyle(VFColor.bodyPrimary)
            Text(text)
                .font(VFTypography.body)
                .foregroundStyle(VFColor.bodyPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension String {
    var aiToneValue: String {
        switch self {
        case "감성적으로": "warm"
        case "유쾌하게": "playful"
        case "SNS 캡션처럼": "social"
        default: "plain"
        }
    }

    var sanitizedExtraNote: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let collapsed = trimmed.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return String(collapsed.prefix(120))
    }
}

#Preview("직관 기록 추가") {
    let preferences = UserPreferencesStore.preview(suiteName: "LogEditorPreview", favoriteTeamID: "lg-twins")
    let appData = AppDataStore(preferences: preferences)
    NavigationStack {
        LogEditorView()
    }
    .environmentObject(preferences)
    .environmentObject(appData)
}
